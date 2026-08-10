---
story_id: "162-59"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-59: parse_round_trip_count discards the unreadable tri-state

## Story Details
- **ID:** 162-59
- **Jira Key:** (no Jira — kanban-only project)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-59-unreadable-counter-tristate
- **PR:** #192

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-07T20:52:14Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-07T20:02:01Z | 2026-08-07T20:03:30Z | 1m 29s |
| red | 2026-08-07T20:03:30Z | 2026-08-07T20:17:41Z | 14m 11s |
| green | 2026-08-07T20:17:41Z | 2026-08-07T20:29:25Z | 11m 44s |
| review | 2026-08-07T20:29:25Z | 2026-08-07T20:52:14Z | 22m 49s |
| finish | 2026-08-07T20:52:14Z | - | - |

## Story Context

**Problem:** `parse_round_trip_count` returns only `["count"]` which is `0` for `unreadable`, discarding the tri-state that `read_round_trip_count` carefully distinguishes. This allows a corrupt counter to bypass freshness guards.

**Measurement (from 162-47 review F4):** Replacing the counter value `1` with `one` (unparseable) makes a completed rework round resolve `ready → green` again, defeating both 162-47's new B3 freshness guard AND the pre-existing `max_attempts` ceiling.

**Root Cause:** The tri-state invariant exists because "'I cannot read the counter' is not 'there was no rework'" (story 162-28), but `resolve_gate` does not check for the `unreadable` status.

**Scope:**
- Locate and extend `resolve_gate` to block on `status == "unreadable"`
- Ensure both `read_round_trip_count` (in `pf/handoff/`) and `parse_round_trip_count` (in `pf/handoff/`) work in concert
- Verify B3 freshness guard and `max_attempts` ceiling cannot be bypassed by corruption

**Technical Details:**
- Functions involved: `read_round_trip_count()` / `parse_round_trip_count()` in `pf/handoff/gate_recovery.py` and `complete_phase.py`
- Gate affected: `resolve_gate` in `pf/handoff/resolve_gate.py` must check tri-state
- Related defects: 162-47 F4 (security), 162-28 (tri-state architecture), 162-50 (counter writer)

## Sm Assessment

**Story:** 162-59 (2 pts, p1, tdd, `[SEC][EDGE]`) — a corrupt round-trip counter buys unlimited rework rounds. Ranked first among the 162-47 follow-ups by both Dev and Reviewer independently.

**Why this is p1 and not polish:** the counter is the input to two independent controls, and a single unparseable byte disarms both — 162-47's new freshness guard (a completed rework round resolves `ready → green` again) and the pre-existing attempt ceiling. The tri-state exists specifically to prevent this: 162-28 introduced `unreadable` as distinct from `absent` on the stated principle that *"I cannot read the counter" is not "there was no rework."* One consumer then flattened it back. This is a fail-OPEN in the machinery that decides whether rejected work can advance.

**Measurement to reproduce (from 162-47 review F4, do not take on trust — re-measure):** replace `1` with `one` in the counter line of a session with a completed rework round; observe `resolve_gate` returning `ready`/`green`.

**Scope shape:** the defect is one consumer discarding a distinction its producer already makes. The obvious fix (`resolve_gate` blocks on `unreadable`) is the Reviewer's suggested shape, NOT a probed one — TEA should pin the observable invariant and let Dev choose the mechanism. Two questions worth answering with measurement rather than assumption:
1. **Is `resolve_gate` the only consumer that flattens the tri-state?** If `parse_round_trip_count`'s return shape is the actual defect, fixing one caller leaves the next one to rediscover it — the same "one truth, one place" argument that carried 162-29 and 162-47's A3/A5. Sweep the callers before choosing where the fix lands.
2. **Does blocking on `unreadable` create a wedge?** A session with a genuinely corrupt counter must still be recoverable by a human — a guard that blocks forever with no diagnosis is a different failure. Pin the error message naming the line and the remedy.

**Boundary — related but NOT this story:** 162-50 covers the counter WRITER's tri-state; 162-63 covers B3 counting headings rather than rulings; 162-60 covers heading case-sensitivity (including `_PREAMBLE_END_RE`, which also affects which counter line is operative). Do not sweep those in — cross-reference them if measurement shows overlap.

**Risk note:** this is the machinery that runs the pipeline's own exit protocol. Dev must trace their own handoff path against their change before running it — a guard that blocks its author's exit is either wrong or needs the assessment to carry the new required shape (162-47 datapoint: `green`'s `dev_exit` gate has no recovery block, so verdict logic is unreachable from there — verify that still holds).

**Routing:** phased tdd, TEA first. Peloton-inline mode — agents return to SM, no relay markers.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (35 failing — ready for Dev)

### Re-measurement (first-hand, not taken on trust)

Reproduced F4 against the real `workflows/tdd.yaml` (`max_attempts: 3`) at
4b8035d2d, one completed rework round, one exact `## Reviewer Assessment`
section, rejection verdict. Counter value → reader status → `resolve_gate`:

| counter line value | `read_round_trip_count` | `resolve_gate` |
|---|---|---|
| `1` | found/1 | blocked (AC-B3 freshness) |
| `3` | found/3 | blocked (max_attempts ceiling) |
| `one` | unreadable/0 | **ready / approval_rework / dev / green** |
| `three` | unreadable/0 | **ready / approval_rework / dev / green** |
| `3.` / `1_000` / `-3` / empty | unreadable/0 | **ready / approval_rework / dev / green** |
| `1 (after rework)` | unreadable/0 | **ready / approval_rework / dev / green** |
| HTML comment / backticks / fence / indented | unreadable/0 | **ready / approval_rework / dev / green** |
| absent | absent/0 | ready (correct — initial review) |

F4 CONFIRMED, and wider than reported: every HIDING form 162-28 was written to
defeat works again through this consumer, not just the unparseable-value form.
One byte disarms both controls at once.

### Scope question 1 — is `resolve_gate` the only flattener, or is the return shape the defect?

Swept every consumer by AST, not grep. The return shape is the defect:

- `parse_round_trip_count` has **exactly one** production call site —
  `resolve_gate.py:279`, the one that must not flatten.
- `complete_phase._parse_rework_cycle` (the sibling flattener) has **zero**
  production call sites. The freshness guard uses the tri-state
  `_read_rework_cycle` instead.

So the flat accessors' only remaining job in production is to commit this
defect, and one of the two already demonstrates the drift: the docstring on
`parse_round_trip_count` still claims `_parse_rework_cycle` delegates to it. It
does not — it delegates to `_read_rework_cycle`. AC4 therefore pins *no
production module consumes the flattened count* rather than *fix line 279*, and
leaves Dev free to delete the accessors or keep them test-only.

Where the hole comes from architecturally: the tri-state check exists **once**,
in `_check_approval_requirements`, scoped to the bare `approval` gate type. The
rework path resolves as `approval_rework` and so routes around it — and
`resolve_gate` blocks before `complete_phase` is ever reached.

### Scope question 2 — does blocking on `unreadable` wedge a session?

No, measured. Same session, counter repaired to a plain integer with two
rulings against one recorded round-trip, resolves `ready` / `approval_rework` /
`dev` / `green`. The remedy is a one-line hand edit, which is already live
practice. Two conditions, both pinned as tests:

1. The block must name the field, the session file, and a remedy that says what
   a readable counter looks like (`To fix:` is the house convention every other
   `resolve_gate` stop follows). Precedent text exists at
   `complete_phase.py:766` for the identical state.
2. A genuinely `absent` counter must keep resolving — a first-cycle rejection
   has no counter at all, and conflating the two would wedge every rejection in
   the pipeline.

Verified the risk note still holds: `red`/`tests_fail` and `green`/`dev_exit`
have no `recovery` block, so `has_rework_action` is false and the verdict and
counter logic is unreachable from either. Dev's guard cannot block its own exit,
and neither can mine.

### Acceptance Criteria

- **AC1 — the observable invariant.** With a rework verdict and an operative
  counter line that is present but unreadable, `resolve_gate` must not hand out
  a rework round: not `status: ready`, no `_rework` suffix on the resolved gate
  type (`complete_phase` keys the counter increment and the ceiling off it), and
  no forward routing in either direction. Mechanism is Dev's.
- **AC2 — both controls stay armed.** The corruption must not reach past the
  AC-B3 freshness guard or the `max_attempts` ceiling. Each is paired with a
  control case proving that control, and only that control, was the operative
  blocker before corruption.
- **AC3 — diagnose, do not wedge.** The block names the field, the file and a
  remedy; repairing the counter resolves the gate normally.
- **AC4 — one truth, one place.** No production module consumes the flattened
  count; production branches on `status`.
- **AC5 — no over-blocking.** Absent counter still an initial review; readable
  counter still routes rework; an approval over a corrupt counter is still
  stopped by the freshness subcheck.

### Test Files

- `pennyfarthing-dist/src/pf/tests/test_162_59_unreadable_counter_tristate.py` —
  49 tests: AC1 over 10 corruption forms plus all 10 approval-gated `review`
  phases discovered from the shipped workflow YAML (no hardcoded list, per
  162-47 AC-A7); AC2 with proof-of-blocker controls; AC3 diagnostic contract and
  the anti-wedge repair round trip; AC4 AST sweep for flattening call sites; AC5
  over-blocking controls. Ten fixture-integrity tests assert each corruption
  really reads `unreadable` and not `absent`, so the suite cannot rot into one
  that passes for the wrong reason.
- `pennyfarthing-dist/src/pf/tests/test_162_21_resolve_gate_rejected_verdict.py`
  — de-vacuumed in place. `test_unparseable_round_trip_count_does_not_crash`
  asserted `status in ("ready", "blocked")` and `next_phase != "finish"`, which
  sanctioned the exact fail-open it stood over: it could not tell the defect
  from the fix. Now asserts the gate does not advance, keeping the original
  no-crash subject.

### RED evidence (fail for the right reason)

`35 failed, 6332 passed, 4 skipped` full suite, serial, from the orchestrator
root. Baseline was `6318 passed / 4 skipped / 0 failed`, and it reconciles
exactly: 6318 + 15 new passing controls − 1 (the de-vacuumed test moving from
pass to fail) = 6332. No collateral regressions.

Every AC1/AC2 failure lands on the single invariant assertion — *"an unreadable
round-trip counter bought a rework round"* — with the full result dict showing
`status: ready, gate_type: approval_rework, next: dev/green`. Not import
errors, not fixture errors. AC3 failures are the diagnostic assertions finding
`error: None` because the gate resolved instead of blocking. AC4 fails naming
`handoff/resolve_gate.py:279 -> parse_round_trip_count()`. The 15 passing tests
are the fixture-integrity preconditions, the two proof-of-blocker controls, and
the three over-blocking controls — all must stay green.

Related families run clean: `162-21 / 162-25 / 162-28 / 162-47 / 143-10` →
`1 failed, 375 passed`, the one failure being the intended de-vacuumed test.

`ruff check` and `ruff format --check` clean on both touched files. Commit
`d07343fe7`, GPG signed.

### Interface Dev must satisfy

`resolve_gate` must consult the counter's tri-state rather than its flattened
count on the rework path. Suggested shape, not mandated:

```python
reading = gr.read_round_trip_count(session_content)
if reading["status"] == "unreadable":
    return _stop("blocked", f"...{reading['detail']}... To fix: ...")
round_trips = reading["count"]
```

Constraints measured, not assumed:

- The check belongs on the rework path (inside `if verdict == "rework"`) or
  earlier; the approve path is already covered downstream by
  `_check_rework_freshness`, and AC5 pins that so a fix cannot cost it.
- `absent` must keep flowing through — the tri-state's whole point.
- The error must carry `To fix:` plus the field name, the session path, and
  language about the counter being on its own line as a plain integer outside
  fences, comments and backticks. `reading["detail"]` already supplies the
  *why*.
- AC4 means the flat accessors must have no production callers when Dev is
  done. `reading["count"]` is enough for the AC-B3 and ceiling messages, so no
  flat call is needed.

**Handoff:** To Dev for GREEN.

## Dev Assessment

**Status:** GREEN (6367 passed / 4 skipped / 0 failed — full suite, serial, orchestrator root)
**Commit:** `ea24c61e0`, GPG signed, pushed. Three files, +47/−7.

### Implementation

One production change, on the rework path in `resolve_gate.py`. It branches on
the counter's `status` exactly as the verdict check twenty lines above it does,
blocks `unreadable` with a diagnostic, and takes `count` from the same reading
thereafter. TEA's suggested shape held up under measurement, so I adopted it
rather than inventing one — no flat call is needed anywhere downstream, as TEA
predicted: the AC-B3 message and the ceiling message both read `round_trips`
after the block.

### Per-AC disposition

- **AC1 — the observable invariant: FIXED.** All 10 corruption forms and all 10
  approval-gated `review` phases discovered from the shipped YAML now return
  `blocked` with `gate_type: approval` (no `_rework` suffix, so `complete_phase`
  neither increments the counter nor keys the ceiling off it) and no routing in
  either direction.
- **AC2 — both controls stay armed: FIXED.** The block sits ahead of both, so
  neither the freshness guard nor the ceiling is reached with a corrupt counter.
  The two proof-of-blocker controls stayed green throughout, so the guard is
  demonstrably what stops these cases and not a session that would have blocked
  anyway.
- **AC3 — diagnose, do not wedge: FIXED.** The error names the field, the
  session path, carries `To fix:`, and says what a readable counter looks like
  (own line, plain integer, nothing after it, outside fence/comment/backticks/
  indentation) — wording modelled on the existing precedent for the identical
  state in `complete_phase`, so the two stops read alike. `detail` from the
  reading supplies the *why*, which differs between the unparseable and the
  hidden forms. The repair round trip passes: same session, counter restored,
  resolves `ready` / rework / dev / green.
- **AC4 — one truth, one place: FIXED.** Zero production call sites to either
  flat accessor. The AST sweep is now a standing regression guard.
- **AC5 — no over-blocking: FIXED (all three controls green).** `absent` flows
  through untouched, a readable counter still routes rework, and the approve
  path's freshness subcheck is unchanged — I did not touch
  `_check_approval_requirements`.

### The flat accessors: KEPT, marked not-for-production (not deleted)

Both are now uncallable from production by test, and documented as such. My
reasoning for keeping rather than deleting:

1. **The trap is already mechanically armed against.** AC4's AST sweep fails on
   the first production call to either. That is a stronger guarantee than
   deletion, because it also covers a future re-introduction under a new name
   pattern if the `lossy` set is extended — deletion protects only against
   calling *these two* symbols.
2. **Deletion would destroy other stories' coverage without a test asking for
   it.** `_parse_rework_cycle` has 10+ assertions across `test_150_8`,
   `test_143_12` and `test_162_28`, and in `test_143_12` the function *is* the
   subject ("returns 0 on every real session"). `parse_round_trip_count` carries
   8 more in `test_162_28` pinning masking and last-in-preamble-wins. Rewriting
   them all to `read_round_trip_count(...)["count"]` is churn in tests I do not
   own, in service of an AC that does not require it.
3. **Deleting only one of the pair would be worse than either option** — it
   leaves an asymmetry a reader has to explain.

TEA's stronger remedy — the lang-review checklist entry *a tri-state reader must
not ship a flattening convenience accessor* — is the durable fix for the class,
and it is recorded as a Delivery Finding against
`.pennyfarthing/gates/lang-review/python.md` rather than swept in here.

### In-scope cleanups taken

Both stale docstrings, not just the one TEA flagged. `parse_round_trip_count`
claimed to be "the single reader" with `_parse_rework_cycle` delegating to it;
`_parse_rework_cycle` made the mirror-image claim about delegating to
`parse_round_trip_count`. Neither is true — it delegates to its own
`_read_rework_cycle` — so the pair of docstrings vouched for each other's
safety in a loop while the flattening they described was the defect. Both now
lead with the not-for-production marker and the reason.

TEA's Finding 4 (`find_operative_round_trip_line` taking the last *parseable*
preamble match) I deliberately did NOT fix. Measured fail-safe today, and it is
a reader/writer divergence — the writer is 162-50's subject, and changing the
reader alone is how the two halves get further apart. Cross-referenced, not
touched.

### Mutation evidence (five mutations, each reverted)

| Mutation | Expected | Observed |
|---|---|---|
| Guard disabled (`if False`) | AC1/AC2/AC3 fail | 34 failed / 102 passed — TEA's exact RED count for the pair |
| `== "unreadable"` → `!= "found"` (over-block) | AC5 absent-counter control fails | 1 failed / 48 passed, precisely that control |
| `To fix:` removed from the message | AC3 diagnostic fails | 10 failed / 39 passed |
| `count` read back through the flat accessor | AC4 sweep fails | 1 failed, naming the call site |
| — full restore after each | all green | 49/49, then 136/136 with 162-21 |

Every load-bearing line is pinned by a test that fails without it, and the
over-block mutation confirms the guard is scoped to `unreadable` alone rather
than to "anything that is not found".

### Safety: traced my own exit path BEFORE running it

Re-verified TEA's finding and widened it. `has_rework_action` is only true where
a gate's recovery block declares `action: rework`, and in the shipped `tdd.yaml`
that is the `review` gate alone: `red`/`tests_fail` and `green`/`dev_exit` have
no recovery block at all, and `setup`/`sm_setup_exit` has one whose two entries
are `create_context`, not rework. So the guard's entire reachable surface is the
Reviewer's phase. It cannot block its author's exit, nor TEA's, nor SM's setup.

### Test counts

- New file alone: **49 passed** (was 34 failed / 15 passed at RED).
- With `test_162_21` (the de-vacuumed test): **136 passed**.
- Related families (`162-21 / 162-25 / 162-28 / 162-47 / 143-10 / 150-8 /
  143-12 / 162-49`): **478 passed, 0 failed** — including every existing test
  of both flat accessors, which is what makes the keep-them decision safe.
- Full suite, serial, orchestrator root: **6367 passed, 4 skipped, 0 failed**,
  180s. Reconciles exactly against TEA's RED: 6332 + 35 = 6367. No collateral
  regressions and no tests weakened.
- `ruff check` clean across all of `pf/handoff/`; `ruff format --check` clean on
  all three touched files.

### For the Reviewer to scrutinise

1. **The keep-vs-delete call on the flat accessors** is the one judgment in this
   change. AC4 permits either; my reasoning is above and I would not argue hard
   against deletion if you think the AST guard is too indirect a defence.
2. **Placement.** The guard is inside `if verdict == "rework"`, not earlier. That
   means a corrupt counter under an APPROVED verdict is still not stopped by
   `resolve_gate` — it is stopped one step later by
   `_check_approval_requirements`, which AC5 pins. Deliberate (TEA measured the
   approve path as already covered, and blocking earlier would have needed its
   own wedge analysis), but it does leave the tri-state check in two places for
   two paths rather than one place for both. Whether that is the right seam is
   worth a second opinion.
3. **The error text duplicates the remedy** that `complete_phase.py`'s
   equivalent stop already carries. Two hand-maintained copies of one remedy is
   the drift class this epic keeps closing; I did not extract it because no test
   demanded it and the two messages differ in framing. Candidate follow-up.
4. **162-50 is now load-bearing on this guard.** The writer still resets a
   corrupt counter to 1 by inserting a second line beside it. On the rework route
   my guard blocks before the writer runs, which masks that defect rather than
   fixing it — so 162-50 should not be deprioritised on the strength of this
   story.

**Handoff:** To Reviewer.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)

- **Gap** (non-blocking): the counter WRITER resets a corrupt counter to 1 rather than failing. `complete_phase.py:190` locates the operative line via `find_operative_round_trip_line`; when that line is present but unparseable the locator returns `None`, so the `else` arm INSERTS a fresh `Round-Trip Count: 1` line after `Phase Started` and leaves the corrupt line sitting above it. Net effect: a corrupt counter silently becomes 1 and the session ends up with two counter lines. Affects `pennyfarthing/pennyfarthing-dist/src/pf/handoff/complete_phase.py` (the insert arm needs the same tri-state distinction the readers make). **This is 162-50's subject** — recorded here only because the same measurement surfaced it, and because AC1's guard incidentally protects this path on the rework route by blocking before the writer runs. *Found by TEA during test design.*
- **Gap** (non-blocking): stale docstring on `parse_round_trip_count`. It claims "`complete_phase._parse_rework_cycle` delegates here rather than forking its own pattern"; `_parse_rework_cycle` in fact delegates to `_read_rework_cycle`. The one-truth-one-place claim the docstring makes for itself is no longer true of the flat accessor, and it reads as reassurance that the flattening is safe. Affects `pennyfarthing/pennyfarthing-dist/src/pf/handoff/gate_recovery.py:768-788` (docstring, and likely the function itself under AC4). *Found by TEA during test design.*
- **Improvement** (non-blocking): the flat/tri-state accessor pair is a repeatable trap. Two lossy accessors (`parse_round_trip_count`, `_parse_rework_cycle`) sit beside their tri-state producers with names that read as the obvious choice, and each has zero or one legitimate production caller. `VerdictReading` avoided this by having no flat accessor at all — `resolve_gate` branches on `status` directly (`resolve_gate.py:256`), with an assert pinning the invariant. Worth considering the same shape for the counter, and worth a lang-review checklist entry: *a tri-state reader must not ship a flattening convenience accessor.* Affects `.pennyfarthing/gates/lang-review/python.md`. *Found by TEA during test design.*
- **Question** (non-blocking): `find_operative_round_trip_line` takes the last **parseable** match in the preamble, not the last match. Measured: with `Round-Trip Count: three` written below a stale `Round-Trip Count: 3`, the reader reports found/3 and blocks — fail-safe, so not a defect today. But it means the reader and the writer can disagree about which line is operative when an unparseable line is the most recent one, which is the class of divergence 162-47 AC-A3 set out to close. Cross-reference for 162-50. *Found by TEA during test design.*

### Dev (implementation)

- **Improvement** (non-blocking): the lang-review checklist entry TEA proposed is the durable fix for the class this story only instanced. Carrying it forward explicitly because I chose to KEEP the two flat accessors rather than delete them, which leaves the shape in the tree: *a tri-state reader must not ship a flattening convenience accessor; if one exists for tests, production must be swept for it.* The AST sweep in `test_162_59` is the pattern to copy — it is generic over a name set, so a third lossy accessor added later is one line of test change away from being guarded. Affects `.pennyfarthing/gates/lang-review/python.md`. *Found by Dev during implementation.*
- **Improvement** (non-blocking): the remedy text for an unreadable counter now exists in two hand-maintained copies — `resolve_gate.py` (this change) and `complete_phase.py` for the identical state on the approve path. They agree today because I modelled mine on the precedent, but two copies of one remedy is the drift class 162-21 and 162-47's A3 both closed elsewhere. A shared constant or a small formatter in `gate_recovery.py` beside the reader would put the remedy next to the thing that knows why it failed. Affects `pennyfarthing/pennyfarthing-dist/src/pf/handoff/resolve_gate.py` and `complete_phase.py`. *Found by Dev during implementation.*
- **Question** (non-blocking): the tri-state counter check now exists in two places for two paths — `resolve_gate` for the rework path, `_check_approval_requirements` for the approve path — rather than once for both. That is the same "check exists once, scoped to one gate type, and the other path routes around it" shape that CAUSED this defect (TEA's architectural root). It is not a defect now, because both paths are covered and both are pinned by tests, but the seam is worth an architect's eye before a third path is added. Affects `pennyfarthing/pennyfarthing-dist/src/pf/handoff/`. *Found by Dev during implementation.*
- **Gap** (non-blocking): 162-50 should not be deprioritised on the strength of this story. The writer still resets a corrupt counter to 1 by inserting a second counter line beside the corrupt one (TEA's Finding 1). On the rework route my AC1 guard blocks before the writer is reached, so the writer defect is now MASKED rather than fixed — a session can still reach the writer with a corrupt counter by any path that does not go through the rework verdict. Affects `pennyfarthing/pennyfarthing-dist/src/pf/handoff/complete_phase.py:190`. *Found by Dev during implementation.*

### Reviewer (code review)

- **Gap** (non-blocking): **162-50 must fix BOTH halves, and the reader half is the one nobody has named.** `read_round_trip_count` checks `find_operative_round_trip_line` FIRST and only falls through to its two `unreadable` arms when *no* parseable line exists — so when a parseable and a corrupt counter line are BOTH present in the preamble the reading is `found`, the corrupt line is never reported, and this story's new guard is silently INERT. Measured: session carrying `Round-Trip Count: 1` and `Round-Trip Count: one` reads `found/1` and resolves `ready / approval_rework / dev / green`. That two-line state is precisely what 162-50's writer CREATES (it inserts a fresh counter beside the corrupt one instead of replacing it) — measured: after one direct `complete_phase(..., "rework")` the session holds both lines, and the reader then reports `found/1` permanently, resetting an unknown true count to 1. So the guard is one-shot and self-erasing on that route. Fixing the writer to REPLACE rather than insert is necessary but **not sufficient**: the reader must also prefer a co-present corruption signal over a first-match `found`. Affects `pennyfarthing/pennyfarthing-dist/src/pf/handoff/gate_recovery.py:740-744` (reader precedence) and `complete_phase.py:190` (writer). *Found by Reviewer; corroborated by `[SEC]`.*
- **Gap** (non-blocking): **the enforcement point is not the mutation point, on a route with no guard at all.** `resolve_gate` is an advisory pre-check; `complete_phase` is what mutates the session and increments the counter, and on the rework route it validates neither readability nor the ceiling. Measured with the *documented* Reviewer command from `agents/reviewer.md:469/475` — `pf handoff complete-phase {id} {wf} review green rework` — gate_type is the literal `rework`, which is **not** approval-family, so no approval subcheck runs at all; the call returns `success`, advances the phase, and writes a second counter line. With `approval_rework` the same holds because the freshness subcheck is scoped to the bare `approval` string. Pre-existing in mechanism (this diff touches `complete_phase.py` only in a docstring; the writer and `cli.py` are byte-identical to `origin/develop`), and the ceiling was equally unenforceable at the mutator before this story. Named here because it bounds what AC1 can claim and is the natural home for the architect review Dev requested. Affects `pennyfarthing/pennyfarthing-dist/src/pf/handoff/complete_phase.py:174-205`. *Found by Reviewer; corroborated by `[SEC]` and `[TYPE]`.*
- **Gap** (non-blocking): **a homoglyph or invisible character in the counter LABEL lands on `absent`, which routes.** The story's threat model is 162-28's doctrine that hiding the line is worse than deleting it because the document still renders intact. One more class does exactly that and is *not* closed: mutating the label rather than the value makes both `ROUND_TRIP_COUNT_RE` and `COUNTER_LINE_RE` miss, so the reading is `absent` — the one status the fix deliberately routes on. Measured end-to-end at `max_attempts` saturation (counter value 3, REJECTED verdict), all four resolving `ready / approval_rework / dev / green`: U+2011 non-breaking hyphen in "Round-Trip", U+200B ZWSP, U+00A0 NBSP, U+FF1A fullwidth colon. Zero delta from this diff (identical before and after — pre-existing regexes, unchanged), so not a regression, but it is the fix's own advertised threat class and the emitted remedy actively misleads here: it tells the operator to write `Round-Trip Count: N`, which is what a homoglyph label already looks like. Suggest NFKC-fold + strip Cf/Cc before matching, or a deliberately loose counter-shaped near-miss detector that fails closed. Sibling to 162-60 (heading case-sensitivity). Warrants its own story. Affects `pennyfarthing/pennyfarthing-dist/src/pf/handoff/gate_recovery.py:703-706`. *Found by `[SEC]`; verified first-hand by Reviewer.*
- **Improvement** (non-blocking): **the AC4 AST sweep guards two names, not the defect shape.** `_flattening_call_sites` matches call nodes against the literal set `{"parse_round_trip_count", "_parse_rework_cycle"}`, but both accessors *are* nothing but `read_round_trip_count(c)["count"]` and `_read_rework_cycle(c)["count"]`. I re-implemented the matcher against synthetic sources: it CATCHES a direct import call and a module-attribute call under any alias; it MISSES an aliased import, `getattr`, a rebound local, and inline `read_round_trip_count(s)["count"]` — the last re-commits this story's defect verbatim with the test still green. Scope is also narrower than "production": `PF_SRC` is `src/pf` only, so shipped `src/pf_launcher.py` and the five `.py` files under `pennyfarthing-dist/scripts/` are never walked, and `if "tests" in path.parts` exempts any directory named `tests` at any depth. No such site exists today (verified). Also a silent-zero: `assert hits == []` passes identically whether 382 files or zero were scanned, and files skipped for `SyntaxError`/`UnicodeDecodeError` are swallowed without record. Suggest flagging any production `ast.Subscript` of `"count"` on a call to either tri-state reader, widening the root, and adding a scanned-count floor plus a positive control. Affects `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_59_unreadable_counter_tristate.py:362-412`. *Found by `[TEST]` and `[RULE]` independently; verified first-hand by Reviewer.*
- **Improvement** (non-blocking): **the two remedy copies already disagree, on three axes — and the older one is the deficient one.** Confirming Dev's own flagged item 3 with the measurement it lacked. NEW (`resolve_gate.py:300`) — quoted with the surrounding `**` elided throughout this section, see the environment note in the Assessment: `…on its own line as 'Round-Trip Count: N' in the session preamble, a plain integer with nothing after it, outside any code fence, HTML comment, backticks or indented block.` PRE-EXISTING (`complete_phase.py:775`): `…on its own line as 'Round-Trip Count: N', outside any code fence, HTML comment or backticks, with nothing after the number.` The old copy omits (1) the preamble location — and a counter placed below the first `## … Assessment` heading reads `absent`, so the freshness guard then reports "No rework cycle — initial review" on a session that has reworked; (2) "indented block", contradicting its own `_read_rework_cycle` detail string ten lines away; (3) "a plain integer", so `-3` / `2.0` / `1_000` survive a literal repair. The new string is the more correct of the two on all three axes; the defect is that it was added as a second hand-maintained copy when `_FRESHNESS_ROUTES` twenty lines from the divergent string is the shared-constant precedent. Extract one shared remedy beside the reader that knows why it failed. Affects `pennyfarthing/pennyfarthing-dist/src/pf/handoff/complete_phase.py:775-779` and `resolve_gate.py:300-303`. *Found by `[RULE]`; both strings and the `absent` consequence verified first-hand by Reviewer.*
- **Improvement** (non-blocking): **the new guard is the only unclosed switch in a function that argues three times for closed ones.** The sibling verdict check 36 lines above fails CLOSED (`if reading["status"] != "found": return _unreadable_verdict(...)`), and two further switches in the same function carry explicit error arms for unknown values, each commented with why the open form was the defect. The counter check is `if counter["status"] == "unreadable"`, so any status that is neither `unreadable` nor the intended `found`/`absent` falls through to `round_trips = counter["count"]`. I enumerated all four returns of `read_round_trip_count`: no fourth status is reachable today, and `count` is hard-coded 0 on every non-`found` return — which is the point: a future fourth state lands on `round_trips = 0`, bit-for-bit this story's defect. `!= "found"` alone would be wrong (`absent` must keep flowing, and that mutation fails exactly the AC5 control). The closed form is `if counter["status"] not in ("found", "absent"): return _stop("error", …)` alongside the unreadable arm. Affects `pennyfarthing/pennyfarthing-dist/src/pf/handoff/resolve_gate.py:292`. *Found by `[TYPE]`; return-path enumeration verified first-hand by Reviewer.*
- **Improvement** (non-blocking): **three test-strength gaps, none of which weakens a shipped behaviour.** (a) The branch-specific `detail` is unpinned: nothing asserts it reaches `result["error"]` — I removed the `{counter['detail']}` interpolation and **136/136 still passed**, yet it is the only part of the message distinguishing "the value is malformed" from "the line is hidden in a fence", which are different repairs. Suggest `assert read_round_trip_count(session)["detail"] in result["error"]`. (b) The 10-workflow discovery sweep has no local non-empty guard; `test_162_47` guards emptiness with `pytest.skip(allow_module_level=True)`, so an empty discovery raised through `test_162_59`'s import would SKIP the entire 49-test file — all five ACs vanishing quietly rather than one test failing loudly. Discovery is live at 10 today (verified). Suggest a local `assert len(APPROVAL_REVIEW_GATES) >= 8`. (c) The AC5 approve-path control calls `_check_approval_requirements(session, "approval")` with the gate_type supplied by the test, so it proves the subcheck fires when handed the literal it needs rather than that production computes that literal. Affects `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_59_unreadable_counter_tristate.py`. *Found by `[TEST]`; (a) verified first-hand by Reviewer via source mutation.*
- **Question** (non-blocking): the `detail` string is inaccurate for the indented corruption form. `    Round-Trip Count: 3` reaches the *first* unreadable arm and reports "its value does not parse as a plain integer ending the line" — but `3` parses fine; what fails is the column-0 anchor. The composed message therefore says the value is unparseable and separately tells the human to un-indent. Harmless today (the remedy names indentation, so the operator still acts correctly) and `test_162_59:117` pins only that `detail` is non-empty, so the wrong detail is now sanctioned. A third arm, or reordering the checks, would fix it. Affects `pennyfarthing/pennyfarthing-dist/src/pf/handoff/gate_recovery.py:744-763`. *Found by Reviewer during branch-coverage measurement.*
- **Question** (non-blocking): `find_operative_round_trip_line` is a THIRD accessor with the same lossy shape the story set out to neutralise — `re.Match | None`, where `None` means both "no counter line" and "a counter line I cannot read". It has two production consumers: `read_round_trip_count`, which *recovers* the tri-state by independently recomputing `mask_illustrative_regions` + `preamble_end` (the locator already computed both internally) and re-searching; and `complete_phase:190`, the writer, which does not recover it at all. One distinction computed twice by different code can drift, and AC4's sweep cannot see this accessor because it is not in the `lossy` name set. The collapse that fixes 162-50 and this together: make the LOCATOR the tri-state producer and reduce `read_round_trip_count` to a projection over it. Affects `pennyfarthing/pennyfarthing-dist/src/pf/handoff/gate_recovery.py:589-605`. *Found by `[TYPE]`; consumer enumeration and the duplicate computation verified first-hand by Reviewer.*
- **Improvement** (non-blocking): `parse_round_trip_count` is documented "NOT FOR PRODUCTION USE" yet remains a bare public module-level name — no `__all__` anywhere in `pf/handoff/`, no underscore prefix, no `@deprecated`, no `warnings.warn`. Its sibling `_parse_rework_cycle` is already underscore-private, so the pair is asymmetric in exactly the way Dev's own rationale 3 argued against. Renaming to `_parse_round_trip_count` costs six test-line edits (zero production callers) and removes a public API surface that contradicts its own docstring. This is the cheap half of the lang-review checklist entry TEA and Dev both proposed. Affects `pennyfarthing/pennyfarthing-dist/src/pf/handoff/gate_recovery.py:768`. *Found by `[RULE]` and `[TYPE]`.*
- **Question** (non-blocking): none of the type apparatus in this module is enforced — no mypy/pyright dependency, no `[tool.mypy]`, no CI. `RoundTripReading.status` genuinely is `Literal["found","absent","unreadable"]`, but nothing rejects a typo'd comparand or the fall-through above, so the TypedDicts are documentation rather than a control. Worth deciding deliberately: either add mypy scoped to `pf/handoff/` so the Literal work pays off, or stop treating the TypedDicts as a guarantee. Affects `pennyfarthing/pyproject.toml`. *Found by `[TYPE]`.*
- **Improvement** (non-blocking): `_assert_no_rework_round` asserts `result["next_phase"] != "finish"` three lines after asserting `result["next_phase"] is None` — the second can never fail. Ironically the same vacuous shape this diff correctly removed from `test_162_21`. One line to delete. Affects `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_59_unreadable_counter_tristate.py:171`. *Found by `[RULE]`.*
- **Gap** (non-blocking): four of the fourteen error sites in `resolve_gate.py` do not meet the module's own `To fix:` convention — `:122` (explicit `next:` target not found) carries no remedy at all despite being the same class as `:350` which does it correctly; `:56` and `:81` drop the clause conditionally when the available/valid list is empty; `:182` propagates a `gate_file.py` message that has no `To fix:` string. All pre-existing, and the NEW site at `:293` is the most complete message in the function. Worth a small sweep story. Affects `pennyfarthing/pennyfarthing-dist/src/pf/handoff/resolve_gate.py`, `gate_file.py`. *Found by `[RULE]`.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)

- **Fix location left open rather than pinned to `resolve_gate`:** the story context says "Locate and extend `resolve_gate` to block on `status == "unreadable"`". Tests pin the observable invariant plus AC4 (no production consumer of the flattened count) instead. Reason: the SM assessment asked for the caller sweep before choosing where the fix lands, and the sweep showed the flat accessor has exactly one production caller — the defective one. Naming `resolve_gate` alone would leave the loaded accessor in place for the next consumer. → ✓ ACCEPTED — SM's assessment asked for exactly this sweep before choosing the seam, so this is compliance with the spec's own instruction rather than a departure from it. I re-verified the sweep independently: `parse_round_trip_count` and `_parse_rework_cycle` have **zero** production call sites across `src/pf/`, `pennyfarthing-dist/scripts/`, and the orchestrator tree; the only production `["count"]` subscripts are status-guarded or inside the lossy accessors themselves. Pinning the invariant rather than the line is the stronger contract.
- **Corruption surface widened beyond the reported `1` → `one`:** tests cover 10 forms including every hiding vector (HTML comment, backticks, fence, indentation). Reason: measurement showed all of them reach the same fail-open, so the reported form is one instance of a class rather than the defect itself. → ✓ ACCEPTED — directly justified by measurement, and I reproduced it first-hand: simulating the pre-fix flat read, **all 10** forms return `ready / approval_rework / dev / green`; post-fix **all 10** return `blocked / approval / None / None`. 162-47's F4 reported only the unparseable-value form, so TEA's "wider than reported" claim is CONFIRMED — the four hiding vectors 162-28 was written to defeat all worked again through this consumer.
- **A pre-existing test was modified, not merely extended:** `test_162_21`'s `test_unparseable_round_trip_count_does_not_crash` asserted `status in ("ready", "blocked")`, which permitted the fail-open. De-vacuumed in place per the RED-phase rule on vacuous tests; its original no-crash subject is preserved. → ✓ ACCEPTED — the old pair was provably unable to distinguish defect from fix (`next_phase != "finish"` is satisfied by `green`, which is where the fail-open routed). The repair discriminates: under my guard-disabled mutation this test FAILS, and it still fails loudly on a raise, so the original no-crash subject survives. Modifying rather than extending was correct — leaving a test that sanctions the defect beside one that forbids it is the state 162-47's F4 was found in.
### Dev (implementation)

- **Flat accessors kept and marked test-only rather than deleted**
  - Spec source: session file, TEA Assessment AC4 and Delivery Finding 3 (Improvement)
  - Spec text: "Dev may delete them or keep them test-only; production must branch on `status`" — and TEA's Improvement finding argues the pair is "a repeatable trap" worth removing on the `VerdictReading` model, which ships no flat accessor at all
  - Implementation: both accessors retained, docstrings rewritten to lead with NOT FOR PRODUCTION USE and to point at the AC4 AST sweep as the enforcement
  - Rationale: AC4 explicitly permits either, and the AST sweep is a stronger and more general guard than deletion. Deleting would have required rewriting 18+ assertions across `test_150_8`, `test_143_12` and `test_162_28` — tests I do not own, one of which (`test_143_12`) has `_parse_rework_cycle` as its literal subject. Churn in other stories' coverage in service of an AC that does not require it.
  - Severity: minor
  - Forward impact: minor — the durable class-level fix (the lang-review checklist entry) is recorded as a Dev Delivery Finding rather than implemented here, so the shape remains in the tree until that lands
  - → ✓ ACCEPTED (outcome agreed; one premise corrected). AC4 explicitly permits either, the churn argument is real (I confirmed the existing assertions across `test_150_8` / `test_143_12` / `test_162_28`, and in `test_143_12` `_parse_rework_cycle` genuinely is the subject), and the 478-test related-families run is what makes keeping safe. **But rationale 1 does not hold as stated:** the AST sweep is not categorically "a stronger guarantee than deletion". I re-implemented its exact matching logic against synthetic sources — it CATCHES a direct import call and a module-attribute call under any alias, but MISSES `from … import parse_round_trip_count as p; p(s)`, `getattr(gr, "…")(s)`, a rebound local, and — the one that matters — inline `gr.read_round_trip_count(s)["count"]`, which re-commits this story's defect verbatim while the sweep stays green. It is stronger than deletion on exactly one axis (re-introduction under a new name added to the `lossy` set) and weaker on several others. The keep decision still stands on the churn argument alone. Free hardening nobody took: rename to `_parse_round_trip_count` — zero production callers, its sibling is already underscore-private, and today a bare public name contradicts its own "NOT FOR PRODUCTION USE" docstring. Six test lines, not eighteen. Routed as a follow-up, not a rework.

- **Tri-state check added to the rework path only, not hoisted to cover both paths**
  - Spec source: session file, TEA Interface section
  - Spec text: "The check belongs on the rework path (inside `if verdict == 'rework'`) or earlier"
  - Implementation: placed inside `if verdict == "rework"`; the approve path continues to rely on `_check_approval_requirements`'s freshness subcheck one step later
  - Rationale: the permitted-and-simplest placement, and AC5 pins the approve path's existing defence so it cannot be lost. Hoisting would have needed its own wedge analysis on a path TEA measured as already covered.
  - Severity: minor
  - Forward impact: minor — the counter's tri-state is now consulted in two places for two paths rather than once for both; logged as a Dev Delivery Finding (Question) for an architect's eye before a third path is added
  - → ✓ ACCEPTED. Two places is the right call *now*, and not merely the permitted-and-simplest one: the two controls answer different questions. `resolve_gate` guards ROUTING (may a rejected verdict buy a round-trip); `_check_rework_freshness` guards ATTESTATION FRESHNESS (are the results being used to APPROVE from the current cycle), and `complete_phase.py:316-322` documents the rework exclusion as deliberate (162-47 AC-A8). Neither substitutes for the other, so hoisting would merge two contracts, not deduplicate one. I verified the approve path by EXECUTION rather than reading: `_check_approval_requirements(session, "approval")` over a corrupt counter returns the "Cannot determine the rework cycle" problem, and with `has_rework_action` stripped the archive route still blocks at `complete_phase` one step later. **Two facts for the architect that neither TEA nor Dev stated, and which are the real content of this deviation:** (1) the approve-path defence hangs on `gate_type == "approval"` being an EXACT match while `is_approval_family` is a PREFIX match — coverage is complete today only because all 17 shipped gates declare exactly `type: approval`, so a future `approval_foo` gets the dispatch checks but silently not the tri-state one; (2) the genuine third path already exists and is not either of these two — the WRITER (`complete_phase.py:190`), reachable with `gate_type` values that are not approval-family at all. Both belong in the architect follow-up Dev asked for.

- **Second stale docstring corrected beyond the one flagged**
  - Spec source: session file, TEA Delivery Finding 2 (Gap)
  - Spec text: names only `gate_recovery.py:768-788`'s docstring as stale
  - Implementation: also corrected `complete_phase._parse_rework_cycle`'s docstring, which made the mirror-image false claim (that it reads the counter "through `gate_recovery.parse_round_trip_count`")
  - Rationale: the two docstrings vouched for each other's safety in a loop. Fixing one would have left the other still asserting a delegation that does not exist, and pointing at the function I had just marked not-for-production.
  - Severity: cosmetic
  - Forward impact: none
  - → ✓ ACCEPTED — and correctly widened beyond what TEA flagged. I checked both corrected claims against the function bodies rather than the prose: `_parse_rework_cycle` really is `return _read_rework_cycle(session_content)["count"]`, and `_read_rework_cycle` really does delegate the real counter to `gate_recovery.read_round_trip_count`. So the new docstrings are accurate and the old pair was mutually false. Fixing only one would have left the survivor pointing at a function that had just been marked not-for-production — the loop Dev describes is real, not rhetorical. One residual, non-blocking: the NEW `parse_round_trip_count` docstring claims the AC4 sweep "fails on any production call to this function", which my evasion probe shows is not literally true (aliased import / `getattr` / rebound name all pass). A docstring that overstates a safety guarantee is the same shape as the defect this story fixed; worth a one-line softening whenever the sweep is next touched.
## Subagent Results

Harness note: the `reviewer-*` subagent types were not registered in this session's
agent registry (`Agent type 'reviewer-preflight' not found`). Each specialist was
therefore run as a `general-purpose` subagent carrying its own definition file
verbatim, with the READ-ONLY / report-don't-fix override and its `PROJECT_RULES` /
`LANG_REVIEW_RULES` populated. All five enabled specialists returned full domain
reports in their required output format; the four disabled ones were covered
directly by the Reviewer. No subagent mutated the working tree (verified clean
after every return: `git status --short` empty, `git diff HEAD --stat` empty,
HEAD still `ea24c61e0`, guard symbol still present).

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 discrepancies, 0 smells | ACCEPTED — all 6 claimed numbers CONFIRMED by measurement, including the exact full-suite 6367/4/0 |
| 2 | reviewer-test-analyzer | Yes | findings | 9 (1 high, 4 medium, 4 low) | ACCEPTED with severity downgrades — verified the two load-bearing claims first-hand (unpinned `detail`; AST sweep evasion); all are test-strength gaps, none a shipped defect |
| 3 | reviewer-type-design | Yes | findings | 7 (1 high, 5 medium, 1 low) | ACCEPTED, high downgraded — its "hold the branch" finding is the pre-existing writer path, explicitly fenced off by SM as 162-50's subject; the third-lossy-accessor observation is the best structural insight of the review |
| 4 | reviewer-security | Yes | findings | 5 (4 high, 1 medium) | ACCEPTED with one CHALLENGE and severity downgrades — all four "auth-bypass" findings verified reproducible but all PRE-EXISTING with zero or bounded delta; challenge recorded below |
| 5 | reviewer-rule-checker | Yes | findings | 5 violations across 19 rules / 118 instances | ACCEPTED, one premise challenged — independently confirmed the zero-production-call-sites claim; its 13c remedy-divergence measurement is the concrete backing Dev's flagged item 3 lacked |
| 6 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — covered directly by Reviewer (10 corruption forms × pre/post, both `detail` branches, preamble boundary, co-present-lines, homoglyph labels, `has_rework_action` false) |
| 7 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — covered directly by Reviewer (no `try`/`except` added; the fix converts a silent coercion into a loud result object; the one swallowed `except Exception: pass` in the file is pre-existing telemetry) |
| 8 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — covered directly by Reviewer (both corrected docstrings checked against their function bodies; one residual overstatement found and logged) |
| 9 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — covered directly by Reviewer (the guard is 26 lines of which 13 are rationale comment; no dead code, no over-engineering; one vacuous assertion found) |

All received: Yes (5 enabled returned in full via the harness substitution noted above; 4 disabled, domains covered directly by the Reviewer)

## Reviewer Assessment

**Verdict:** APPROVED

**Blocking findings:** none. **Non-blocking findings:** 12 recorded as Delivery Findings (3 Gap, 6 Improvement, 3 Question).

### What I verified by measurement rather than by reading

Every number Dev claimed was re-measured and matched exactly: new file 49/49; with `test_162_21` 136/136; related families 478 passed / 0 failed; full suite serial from the orchestrator root **6367 passed / 4 skipped / 0 failed**, reconciling as TEA's 6332 + 35; `ruff check` clean across `pf/handoff/`, `ruff format --check` clean on all five touched files. No discrepancies. Zero code smells. Working tree clean throughout `[RULE]`.

**The defect and the fix, first-hand.** I simulated the pre-fix flat read in-process (patching the reader to return `status: found` with the flattened count — bit-for-bit the old behaviour) and ran all ten corruption forms both ways. Pre-fix: **all ten** resolve `ready / approval_rework / dev / green`. Post-fix: **all ten** resolve `blocked / approval / None / None`. TEA's re-measurement table is confirmed in full, and its "wider than 162-47's F4 reported" claim is confirmed — F4 named only the unparseable-value form, while all four hiding vectors 162-28 was written to defeat (HTML comment, backticks, fence, indentation) worked again through this consumer. AC5's controls hold: a genuinely `absent` counter still reads `absent` and still resolves `ready / approval_rework / dev / green`, so first-cycle rejections are not wedged; the repair round-trip works; and both `unreadable` branches of the reader are exercised (7 forms via "value does not parse", 3 via "inside an illustrative region").

**Dev's mutation table, re-run by me** — patching the `resolve_gate` source in memory and injecting it under its own module name, so the repo was never touched. Guard disabled → **34 failed / 102 passed**, Dev's exact figure. `To fix:` removed → **10 failed**, exact. Over-block `== "unreadable"` → `!= "found"` → **1 failed / 48 passed** at Dev's scope, and the single failure is exactly `test_a_genuinely_absent_counter_is_still_an_initial_review`; across the file pair it fails **42** tests, so the over-block is far more heavily pinned than Dev reported. Two corrections to the table's completeness, in my own interest of stating them plainly: the flat-accessor mutation is not testable by my in-memory method (the AC4 sweep reads source from disk), so I discharged it differently — by re-implementing the sweep's matcher against synthetic sources, which confirms it does catch that call shape; and a sixth mutation I added, **removing the `{counter['detail']}` interpolation, kills zero tests** (136/136 still pass), which is finding (a) below.

**Dev's safety claim, confirmed and widened.** `has_rework_action` is true for exactly **10 phases across all 35 shipped workflows**, every one of them named `review`. So the guard's entire reachable surface is the review phase; it cannot block Dev's exit, TEA's, or SM's setup. One precision on Dev's wording: one of the ten (`agent-docs`) is owned by `tech-writer`, not `reviewer` — the surface is "the review phase", not "the Reviewer's phase". Doesn't change the conclusion. And **I am the proof**: this rejection-capable gate is the code path under review, and my own APPROVED exit runs through the sibling branch of it `[TYPE]`.

**Both docstring corrections are accurate.** Checked against the function bodies, not the prose: `_parse_rework_cycle` really is `return _read_rework_cycle(...)["count"]`, and `_read_rework_cycle` really does delegate to `gate_recovery.read_round_trip_count`. The old pair was mutually false. Widening beyond TEA's single flag was right.

### The four things Dev asked me to scrutinise

**1 — Keep vs delete the flat accessors: I agree with KEEP, but one premise is wrong.** The AST sweep is *not* categorically "a stronger guarantee than deletion". I re-implemented its matcher: it catches a direct import call and a module-attribute call under any alias, but misses an aliased import, `getattr`, a rebound local, and inline `read_round_trip_count(s)["count"]` — which re-commits this exact defect while staying green. It is stronger than deletion on precisely one axis (re-introduction under a new name added to the `lossy` set) and weaker on several others; its scope also excludes `src/pf_launcher.py` and the five `.py` files under `scripts/`. So the AST guard *is* somewhat too indirect — but the keep decision survives on the churn argument alone, which I verified is real (18+ assertions, and `test_143_12` genuinely has `_parse_rework_cycle` as its subject). The free hardening nobody took: rename to `_parse_round_trip_count`. Zero production callers, the sibling is already underscore-private, six test-line edits, and it retires a bare public name that contradicts its own "NOT FOR PRODUCTION USE" docstring `[RULE]` `[TYPE]` `[TEST]`.

**2 — Two places for two paths: acceptable now; the hoist is NOT required.** And for a better reason than "permitted and simplest": the two controls answer different questions. `resolve_gate` guards *routing*; `_check_rework_freshness` guards *attestation freshness*, and `complete_phase.py:316-322` documents the rework exclusion as deliberate (162-47 AC-A8). Hoisting would merge two contracts rather than deduplicate one. I verified the approve path by execution, not reading: a corrupt counter under APPROVED yields the "Cannot determine the rework cycle" problem, and with `has_rework_action` stripped the archive route still blocks at `complete_phase` one step later — which corrects `[SEC]`'s claim that such a gate "archives the story" (it stops, just not in `resolve_gate`). Two facts for the architect that neither TEA nor Dev stated: the approve-path defence hangs on `gate_type == "approval"` being an **exact** match while `is_approval_family` is a **prefix** match — complete today only because all 17 shipped gates declare exactly `type: approval`; and the genuine third path already exists and is neither of these two — it is the writer `[RULE]` `[TYPE]`.

**3 — The duplicated remedy: confirmed, and the two copies already disagree on three axes.** The older `complete_phase` copy omits the preamble location (and a counter moved below the first assessment heading reads `absent`, after which the freshness guard reports "No rework cycle — initial review" on a session that has reworked), omits "indented block" (contradicting a detail string ten lines away in its own call graph), and omits "a plain integer" (so `-3` / `2.0` / `1_000` survive a literal repair). Dev's new string is the *more* correct of the two on all three axes — so this is not a defect Dev introduced, it is a divergence Dev's copy exposed. `_FRESHNESS_ROUTES`, twenty lines from the divergent string, is the shared-constant precedent. Follow-up, not rework `[RULE]`.

**4 — 162-50 is load-bearing, the masking is acceptable, and the review's most valuable output is that 162-50 as currently scoped is INCOMPLETE.** Masking is fine: blocking before the writer is correct defence-in-depth at the layer AC1 owns, SM explicitly fenced the writer off, and nothing in this diff removes anything 162-50 needs. Two concrete things it *does* change for 162-50, both worth carrying forward. (i) **162-50's RED must drive `complete_phase` directly**, because `resolve_gate` now blocks first on the rework route — a test that goes through the sanctioned path can no longer reach the writer. (ii) **Fixing the writer to replace-not-insert is necessary but not sufficient.** `read_round_trip_count` checks the locator *first* and only falls through to its `unreadable` arms when no parseable line exists — so with a parseable and a corrupt line both present the reading is `found` and this story's guard is silently inert. Measured: `found/1`, resolving `ready / approval_rework / dev / green`. That two-line state is exactly what the writer creates, so on the un-guarded route the guard is one-shot and self-erasing, converting an unknown true count into 1 and resetting the ceiling. The reader must prefer a co-present corruption signal over a first-match `found` `[SEC]`.

### Why this is an approval and not a rejection

The residuals are real and I reproduced every one of them, but not one is a fail-open **introduced** by this diff, and not one can reintroduce F4 through the sanctioned path. Judged by blast radius rather than by finding class:

- The writer/mutation-point gap and the reader's `found` precedence are **pre-existing** — this diff touches `complete_phase.py` only in a docstring, and the writer and `cli.py` are byte-identical to `origin/develop`. The ceiling was equally unenforceable at the mutator before this story. They are 162-50's subject by SM's explicit boundary, and were flagged by TEA (Finding 1) and Dev (Finding 4) before I arrived `[SEC]` `[TYPE]`.
- The homoglyph-label class has **zero delta**: identical before and after the fix, pre-existing regexes, unchanged. It belongs to the fix's advertised threat class and deserves its own story, but it is not a regression `[SEC]`.
- The preamble-scoping and default-open-switch findings are pre-existing-by-design (162-47 AC-A3) and presently unreachable respectively `[TYPE]`.
- Every test finding is a *strength* gap, not a weakened behaviour. Nothing was made vacuous; one genuinely vacuous test was repaired, and the ten fixture-integrity guards are the strongest anti-rot discipline I have seen in this epic — I confirmed they are not tautological (hand-written literals, independently reaching `unreadable`) `[TEST]`.

The diff is strictly monotonic: ten corruption forms that bought unlimited rework rounds now block with the most complete diagnostic message in the function, and nothing that resolved before now over-blocks.

### Rule compliance (`gates/lang-review/python.md`, 13 checks + 6 project rules)

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| 1 | Silent exception swallowing | PASS | No `try`/`except` added. The test's `except (SyntaxError, UnicodeDecodeError): continue` is specific and `pragma`-commented. `resolve_gate.py:374`'s `except Exception: pass` is pre-existing telemetry, unchanged. The fix's whole nature is converting a silent coercion into a loud result object. |
| 2 | Mutable default arguments | PASS | 6 instances checked; all defaults immutable, helper kwargs keyword-only. |
| 3 | Type annotation gaps at boundaries | PASS | 8–9 instances. `RoundTripReading.status` verified to be a real `Literal["found","absent","unreadable"]` TypedDict field, so the new branch is type-checkable. Advisory note: `_read_rework_cycle -> dict` is the one tri-state contract in the module still untyped (pre-existing, private). |
| 4 | Logging coverage and correctness | PASS (0 instances) | None of the three modules imports `logging`/`structlog`; errors travel in result dicts. |
| 5 | Path handling | PASS | 7 instances; every read/write passes `encoding="utf-8"`, all joins use `Path`/`/`. The new message's `.session/{story_id}-session.md` is display text, not a path operation, matching `:108`/`:159`. |
| 6 | Test quality | PASS with 1 minor | 49 cases checked. Genuine de-vacuuming in `test_162_21`; real proof-of-blocker controls; AST sweep over grep. One vacuous assertion INTRODUCED (`next_phase != "finish"` after `is None`) — one line, logged. |
| 7 | Resource leaks | PASS | All I/O via `read_text`/`write_text`; no sockets, locks, tempfiles, subprocesses. |
| 8 | Unsafe deserialization | PASS | `yaml.safe_load` pre-existing; `ast.parse` parses without executing; no `eval`/`exec`/`pickle`/`shell=True`. |
| 9 | Async/await pitfalls | PASS (0 instances) | No async constructs in any changed file. |
| 10 | Import hygiene | PASS with 1 note | No star imports, no cycles (function-local imports break the `complete_phase`↔`gate_recovery` cycle). Note: no `__all__` anywhere in `pf/handoff/`, so a function documented "NOT FOR PRODUCTION USE" remains a bare public name. |
| 11 | Input validation at boundaries | PASS — this diff IS the hardening | The session file is agent-authored input at a control boundary; the new branch fails CLOSED on `unreadable` instead of coercing to 0, while `absent` deliberately still flows. ReDoS measured linear (400 KB adversarial inputs, 7–51 ms). |
| 12 | Dependency hygiene | PASS (0 instances) | No dependency or packaging files in the diff. |
| 13 | Fix-introduced regressions (meta) | PASS with deferrals | Not a one-code-path violation — the two paths are two distinct controls, approve-path coverage verified by execution. The story's zero-production-call-sites claim independently CONFIRMED across `src/pf/`, `scripts/`, non-Python and the orchestrator tree. Same-class-left-behind: the third lossy accessor (the locator) and the divergent remedy pair, both logged and both pre-existing or out-of-scope. |
| A | Result objects, don't throw | PASS | New code returns through the existing `_result` builder; raises nothing, and deliberately did not copy the pre-existing `assert` pattern beside it. |
| B | `pennyfarthing-dist` source of truth / runtime paths / no symlink edits / Python only | PASS | All 5 files under `pennyfarthing-dist/`; no `pennyfarthing-dist/` string in runtime output; test writes to `.pennyfarthing/`, not the dist path. |
| C | Match model to task | PASS (0 instances) | No agent definition, `models.yaml`, or model frontmatter touched. |
| D | 162-28 principle: "cannot read" ≠ "no rework" | PASS | This is the principle enforced. All 5 production consumers of the tri-state readers branch on `status` before touching `count`; the converse (`absent` still routes) is upheld and pinned. |
| E | Proposed rule: no flattening convenience accessor | PARTIAL (proposed, not shipped) | Sweep clause satisfied. First clause knowingly not satisfied — AC4 permits keeping; the `_`-rename is the cheap close. Labelled proposed-not-shipped; not counted against this diff. |
| F | Every `resolve_gate` stop carries `To fix:` + field + file + remedy | PASS for the new site | 14 sites audited: the NEW site is the most complete message in the function. 4 pre-existing sites non/partially compliant (`:122`, `:56`, `:81`, `:182`) — logged as a sweep follow-up. |

### Deviation audit

All 6 logged deviations stamped in `## Design Deviations`: **6 ACCEPTED, 0 FLAGGED, 0 undocumented additions found.** TEA's three are all directly justified by measurement I reproduced. Dev's three are accepted with two rationale corrections recorded in place (the AST-sweep-beats-deletion premise, and the fuller architectural content of the two-places placement). No deviation changed an acceptance criterion or weakened a control.

### Recommended follow-ups

1. **Fold into 162-50 (raise its scope, do not deprioritise):** the writer must REPLACE not insert, **and** `read_round_trip_count` must stop preferring a first-match `found` over a co-present corruption signal. Fixing only the writer leaves the guard self-erasing. Its RED must drive `complete_phase` directly.
2. **New story — counter label normalisation:** NFKC-fold and strip `Cf`/`Cc` before matching, or add a fail-closed near-miss detector, so a homoglyph or zero-width label reads `unreadable` rather than `absent`. Sibling to 162-60.
3. **New story — architect review of the counter seam** (the one Dev asked for): the exact-match vs prefix-match asymmetry between `gate_type == "approval"` and `is_approval_family`, the mutation-point-vs-enforcement-point split, and whether the locator should become the single tri-state producer with both readers as projections over it.
4. **Small chore — extract one shared remedy constant** beside the reader, retiring the divergent pair (pattern: `_FRESHNESS_ROUTES`).
5. **Small chore — test hardening:** pin `detail` propagation; add a local non-empty assertion on the discovered workflow set (a fail, not an inherited module skip); add a scanned-count floor and positive control to the AST sweep; delete the vacuous `next_phase != "finish"` line.
6. **Small chore — `_`-rename `parse_round_trip_count`**, plus the lang-review checklist entry TEA and Dev both proposed.
7. **Small sweep — `To fix:` convention** at the four non-compliant `resolve_gate`/`gate_file` error sites.

### Environment finding — the `pf` CLI in this workspace does NOT run this branch's code

Discovered while running my own exit protocol, and it matters for how much weight
anyone puts on gate results from this run. The installed CLI
(`/Users/keithavery/.local/bin/pf`, a `uv` tool install) imports `pf` from
**`/Users/keithavery/Projects/op-1/pennyfarthing/`** — a different checkout
entirely — and that copy has no `preamble_end`, i.e. it predates 162-47's AC-A3
preamble scoping. Consequence: its `read_round_trip_count` scans the whole file,
so two bare prose mentions of the counter field in this very assessment were read
as a present-but-unparseable operative counter and `complete-phase` correctly
refused me with the 162-28 message. Worth recording how it resolved, because my
first attempt was wrong: backticking the quotations did NOT clear it — under that
old reader the second arm then fired ("inside an illustrative region"), because it
searches the raw whole file and the masked whole file, so *any* occurrence of the
bold-colon token anywhere in the document makes the session unreadable, quoted or
not. The only way through was to elide the surrounding `**` from the token in my
own prose (six occurrences, all in text I added). Nothing was weakened to pass the
gate — only my own field-name formatting changed. Note that on THIS branch's
reader none of this would have arisen: the preamble scoping means prose below the
first assessment heading is out of scope entirely, which is 162-47 AC-A3 doing
precisely the job it was written for.

Three things follow. (1) Every measurement in this assessment was taken against
**this branch's** source, executed directly out of
`pennyfarthing/pennyfarthing-dist/src` — not through the CLI — so none of it is
affected. (2) The `resolve-gate` / `complete-phase` invocations in this run
exercised the OLD checkout, so they are not evidence about this branch's gate
behaviour; treat them as workflow bookkeeping only. My claim that a REJECT would
route through the code under review still holds for the branch source, but I
could not have demonstrated it through this CLI. (3) This is worth a story on its
own: an orchestrator whose `pf` runs a stale sibling checkout will silently
validate the wrong code for every gate in every story, and the failure mode is
invisible — the CLI reports version 13.4.0 either way. Recommend `pf doctor`
assert that the resolved `pf` package path is inside the workspace's own
`pennyfarthing/pennyfarthing-dist/src`.

`[TEST]` `[TYPE]` `[SEC]` `[RULE]`

**Handoff:** To SM.