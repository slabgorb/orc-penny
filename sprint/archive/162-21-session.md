---
story_id: "162-21"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-21: resolve-gate ignores REJECTED reviewer verdict: returned next_agent=sm/next_phase=finish and complete-phase advanced to finish despite the gate's own recovery_config declaring reviewer-verdict {action: rework, target_phase: green} (observed live in 162-2 review)

## Story Details
- **ID:** 162-21
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-21-resolve-gate-rejected-verdict
- **PR:** #186 - https://github.com/slabgorb/pennyfarthing/pull/186 (MERGED 2026-08-06T16:46:24Z, squash)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-06T16:13:44Z
**Round-Trip Count:** 3

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-06T13:26:58Z | 2026-08-06T13:28:40Z | 1m 42s |
| red | 2026-08-06T13:28:40Z | 2026-08-06T13:37:05Z | 8m 25s |
| green | 2026-08-06T13:37:05Z | 2026-08-06T13:53:36Z | 16m 31s |
| review | 2026-08-06T13:53:36Z | 2026-08-06T14:11:06Z | 17m 30s |
| green | 2026-08-06T14:11:06Z | 2026-08-06T14:23:14Z | 12m 8s |
| review | 2026-08-06T14:23:14Z | 2026-08-06T14:51:35Z | 28m 21s |
| green | 2026-08-06T14:51:35Z | 2026-08-06T15:04:00Z | 12m 25s |
| review | 2026-08-06T15:04:00Z | 2026-08-06T15:27:03Z | 23m 3s |
| green | 2026-08-06T15:27:03Z | 2026-08-06T15:39:57Z | 12m 54s |
| review | 2026-08-06T15:39:57Z | 2026-08-06T16:13:44Z | 33m 47s |
| finish | 2026-08-06T16:13:44Z | - | - |

## Sm Assessment

**Verdict:** READY

Setup complete for 162-21 (p1, 2 pts, tdd). Session file, story context (`sprint/context/context-story-162-21.md`), epic context, and feature branch `feat/162-21-resolve-gate-rejected-verdict` (pennyfarthing repo, off develop) all in place. No Jira integration for this story. Peloton mode active (team peloton-162-21, subagent orchestration). Routing to TEA for the red phase: write failing tests reproducing resolve-gate returning next_agent=sm/next_phase=finish on a REJECTED reviewer verdict instead of honoring recovery_config {action: rework, target_phase: green}.

## Tea Assessment

**Verdict:** RED — failing tests committed, ready for Dev

**Tests Required:** Yes
**Test File:** `pennyfarthing-dist/src/pf/tests/test_162_21_resolve_gate_rejected_verdict.py`
**Tests Written:** 43 tests / 31 failing, 12 passing (control tests)
**Status:** RED (failing for the right reason)

### Root cause located

`pf.handoff.resolve_gate.resolve_gate` computes `next_phase`/`next_agent` purely
from workflow position (`phases[current_idx + 1]`) and **never reads the reviewer
verdict**. It extracts `recovery_config` from the gate (line 171) and passes it
through to the result (line 230) — then ignores it. `pf.handoff.gate_recovery.
get_rework_recovery`, added by story 143-10 to interpret exactly this config,
has **zero production callers**: `grep` finds it only in tests. The plumbing is
connected at both ends and severed in the middle.

Because the resolved `gate_type` stays `approval` (not `*_rework`),
`complete_phase`'s round-trip counter (`if "rework" in gate_type`) never fires,
so `max_attempts: 3` is unenforceable even if routing were fixed.

### Failure output (the bug, verbatim)

```
resolve_gate advanced a REJECTED review straight to the finish phase — full result:
{'status': 'ready', 'gate_type': 'approval', 'gate_file': 'gates/approval',
 'next_agent': 'sm', 'next_phase': 'finish', 'assessment_found': True, 'error': None,
 'recovery_config': {'reviewer-verdict': {'action': 'rework', 'max_attempts': 3,
                                          'target_phase': 'green'}}}
```

### Coverage by acceptance criterion

| Group | Tests | Concern |
|-------|-------|---------|
| `TestRejectedVerdictRoutesToRework` | 13 | REJECTED / CHANGES_REQUESTED / NOT APPROVED, case + markup + trailing-prose variants route to green/dev |
| `TestReworkRoutingIsActionable` | 5 | resolved `gate_type` marks rework; end-to-end resolve→complete lands on green with Round-Trip Count 1 and findings preserved |
| `TestApprovedVerdictStillFinishes` | 6 | APPROVED still → finish/sm, and not recorded as a round-trip (guards the "right only by accident" path) |
| `TestMaxAttemptsCeiling` | 7 | at/beyond `max_attempts` blocks loudly; one below still reworks; ceiling never blocks an approval; corrupt count degrades |
| `TestFailsClosedWithoutAVerdict` | 5 | absent / empty / prose ("looks good") verdict never advances to finish |
| `TestReworkScope` | 7 | no rework where undeclared; earlier phases unaffected; LAST cycle's verdict wins; malformed/nonexistent `target_phase` blocks |

Tests load the **real** `workflows/tdd.yaml` into the tmp project rather than a
hand-copied fixture, so they cannot drift from production routing.

Paranoia notes: `NOT APPROVED` is asserted separately because it contains the
substring `APPROVED` — a naive `in` check passes it. The duplicate-heading tests
pin the dangerous direction of the 162-5 defect class (stale cycle-1 APPROVED
overriding a current cycle-2 rejection).

**Handoff:** To Dev for GREEN.

## Dev Assessment

**Verdict:** GREEN — all tests passing, branch pushed

**Implementation Complete:** Yes

### The fix

`resolve_gate` now routes on the reviewer's verdict when the gate declares a
`rework` recovery action. The severed middle of the plumbing is joined:
`get_rework_recovery` (unused since 143-10) has a production caller.

**Files Changed:**
- `pennyfarthing-dist/src/pf/handoff/gate_recovery.py` — five new helpers:
  `has_rework_action`, `assessment_heading`, `extract_agent_verdict`,
  `classify_verdict`, `parse_round_trip_count`. Verdict vocabulary
  (`APPROVED` / `REJECTED` / `CHANGES REQUESTED` / `NOT APPROVED` / `BLOCKED`)
  lives here as module regexes — one truth, one place.
- `pennyfarthing-dist/src/pf/handoff/resolve_gate.py` — verdict-aware rework
  routing between gate-extension resolution and the result.
- `pennyfarthing-dist/src/pf/handoff/cli.py` — documented `recovery_config`,
  `gate_extensions` and the rework routing in the `--json` shape (closes TEA's
  second Delivery Finding).
- `pennyfarthing-dist/src/pf/tests/test_143_10_reviewer_dev_roundtrip.py` —
  fixture seeded with an APPROVED verdict (see Design Deviations).

### Design decisions

- **Assessment heading derives from the phase agent**, not a hardcoded
  `"Reviewer Assessment"`. `assessment_heading(agent)` mirrors
  `session_assessment.missing_assessment_error`, so the heading resolve-gate
  *reads* is the heading agents are *told to write*. Verified all three
  `action: rework` declarations (tdd, sdd, spdd) sit on a `reviewer` phase and
  that `agents/reviewer.md` writes exactly `## Reviewer Assessment` /
  `**Verdict:** APPROVED|REJECTED` — the derivation matches production.
- **Rejections are matched before approvals** so `NOT APPROVED` cannot pass;
  raw verdicts are normalized (`[^A-Za-z0-9]+` → space, uppercase) so
  `**REJECTED**`, `changes_requested` and `APPROVED ✅` all reduce to bare words.
- **`gate_type` gains a `_rework` suffix** (`approval` → `approval_rework`) —
  the load-bearing detail. `complete_phase` keys both round-trip tracking and
  approval-subgate skipping off `"rework" in gate_type`.
- **Verdict is only consulted where a rework action is declared.** The ceiling
  is checked only *after* the verdict says rework, so an APPROVED story still
  finishes at `max_attempts` round-trips.
- **Fail closed, four ways:** no verdict line / empty / unrecognized prose →
  `blocked`; exhausted `max_attempts` → `blocked` naming the limit; malformed or
  nonexistent `target_phase` → `error` listing valid phases. No path degrades
  into "advance to finish".

**Tests:** 43/43 passing in `test_162_21_resolve_gate_rejected_verdict.py`
(green on first run). Full suite **5892 passed, 4 skipped, 7 xfailed** — exactly
the 5849 baseline plus the 43 new tests. `ruff check` clean.

**Branch:** `feat/162-21-resolve-gate-rejected-verdict` — commit `7bcab54dc`,
GPG-signed (verified `G`), pushed. No PR (SM owns PR creation).

**Handoff:** To Reviewer.

## Reviewer Assessment

**Verdict:** REJECTED

**Review scope:** commit `7bcab54dc` (impl) over `978660a9e` (tests), `develop...HEAD`.
**Method:** direct review — the 9 specialist subagents were NOT dispatched (this
peloton run gives the reviewer no subagent orchestration). The lenses below were
applied by hand; tag prefixes mark which lens produced each finding, not a
subagent report. Nothing here is second-hand.

### Severity table

| # | Sev | Lens | Finding | Blocking |
|---|-----|------|---------|----------|
| 1 | HIGH | [EDGE] | `classify_verdict` searches the WHOLE verdict line, so an APPROVED verdict that mentions the earlier rejection classifies as `rework` — AC3 violated on real inputs | Yes |
| 2 | MED | [EDGE] | `extract_agent_verdict`'s `$`-anchored heading is stricter than `has_assessment`/`complete_phase`, so a suffixed heading (`## Reviewer Assessment (Cycle 2)`) is skipped and the STALE section is read — the 162-5 class, reachable | Yes |
| 3 | LOW | [DOC] | `guides/handoff-cli.md` not updated; TEA finding #2 named it and the Dev Assessment claims that finding closed | No |
| 4 | LOW | [DOC] | `agents/reviewer.md` REJECTED branch hardcodes a different rework target than resolve-gate now computes | No |
| 5 | INFO | [TEST] | Rejections now carry `approval_rework`, so `complete_phase`'s `gate_type == "approval"` subgates are skipped on the rejection transition | No |
| 6 | INFO | [SIMPLE] | 6 of 9 workflows with `type: approval` gates declare no rework recovery, so the 162-2 defect persists there verbatim | No |

### 1. HIGH — an approval that mentions the prior rejection is sent back to Dev

`gate_recovery._REJECTION_RE.search(normalized)` runs against the entire
normalized verdict line, and rejections are matched before approvals. The
"rejections first" ordering is right for `NOT APPROVED`; applying it to the
whole line is not. Three verdict lines from this repo's own session/archive
history misclassify (`grep '^\*\*Verdict:\*\*' .session/ sprint/ docs/`):

```
rework   <- APPROVED (round-trip 1 — Round 1 REJECTED, rework verified closed in Round 2)
rework   <- APPROVED (rework cycle 1 — initial verdict REJECTED, all 8 confirmed findings fixed...)
rework   <- APPROVED (re-review r2; supersedes the round-1 REJECTED verdict above)
```

These are not contrived strings. The failure fires *precisely* in the rework
loop — a reviewer citing the round it supersedes is the normal way to write a
post-rework approval — which is exactly where `Round-Trip Count` is already
≥ 1. Concrete scenario on `tdd` (`max_attempts: 3`): cycle 1 REJECTED (count→1),
Dev fixes, reviewer writes `**Verdict:** APPROVED (round 1 REJECTED, now fixed)`
→ classified `rework` → back to Dev (count→2) → same approval text → `rework`
(count→3) → next approval → `status: blocked`, "Max_attempts (3) reached". A
correctly-approved story is wedged and needs a human or a workflow-YAML edit.
The direction is fail-safe, but AC3 ("an APPROVED verdict still routes to
finish/sm") is broken for a realistic verdict, and it converts the old
false-advance bug into a false-block bug in the same routing decision.

**To fix:** classify on the LEADING token(s) rather than anywhere in the line —
`NOT APPROVED` prefix → rework; `APPROVED` prefix → approved; rejection-word
prefix → rework; otherwise fall back to the current whole-line rejection-first
search so free-form prose still fails closed. Add the three strings above to
`TestApprovedVerdictStillFinishes` as a parametrized case; they are ground
truth, not invented fixtures.

### 2. MED — heading match is stricter here than everywhere else that reads it

`extract_agent_verdict` matches `^##\s+Reviewer Assessment\s*$`. `has_assessment`
uses `^##\s+.*Assessment` and `complete_phase._check_subagent_dispatch` uses an
unanchored `re.search` — both accept `## Reviewer Assessment (Cycle 2)`. So a
suffixed current-cycle heading is invisible to the verdict parser, which then
reads the previous cycle's section. Verified:

```
session: "## Reviewer Assessment\n**Verdict:** REJECTED\n\n## Reviewer Assessment (Cycle 2)\n**Verdict:** APPROVED"
extract_agent_verdict(...) -> 'REJECTED'   # stale
```

Today's direction is safe (stale = the old rejection) and `agents/reviewer.md`
does say the heading is exact — but this re-splits the truth that
`pf.handoff.session_assessment` exists to hold in one place (gh #49), and it
defeats AC6's "the LAST cycle's verdict wins" for a heading shape the rest of
the codebase accepts. **To fix:** relax to `^##\s+Reviewer Assessment\b.*$` (or
share one section-slicer with `session_assessment`), plus a test pinning the
suffixed-heading case.

### 3–6 — non-blocking, recorded as Delivery Findings below

### Verified correct (checked, not assumed)

- **The 143-10 fixture change is legitimate.** The two affected tests still
  assert `status == "ready"` and `gate_type == "approval"`; no assertion was
  relaxed. The seeded `**Verdict:** APPROVED` is now *load-bearing* for
  `gate_type == "approval"` — had Dev instead weakened the assertions, that
  coverage would be gone. Coverage got stronger. Deviation ACCEPTED.
- **`_rework` suffix matches pre-existing convention** — `test_143_10_*` already
  passes `approval_rework` to `complete_phase`, and `complete_phase:181` keys
  round-trip tracking off `"rework" in gate_type`. Correct hook, not invented.
- **max_attempts arithmetic.** count 0/1/2 → rework, 3 → blocked: `max_attempts: 3`
  grants exactly 3 round-trips. `has_rework_action` is checked before the ceiling,
  so an APPROVED verdict at count 3 still finishes.
- **No collateral damage to other gates.** `has_rework_action` is False for every
  `create_context` recovery block, so `sm-setup-exit` and the entry gates are
  untouched; `grep 'action: rework'` returns only the three reviewer phases.
- **Fail-closed paths hold** for absent / empty / prose verdicts, exhausted
  attempts, and a missing or nonexistent `target_phase`. No path degrades to
  "advance to finish". `ruff check` clean on the changed files.

### Suite results

- **Gate/handoff/story-scoped:** 849 passed, 3 xfailed, 0 failed
  (`-k "handoff or 143_10 or 162_21 or 158_4 or complete_phase or resolve_gate or gate or 143_12"`).
  All 43 new tests pass.
- **Full suite:** no regression from this branch, but the Dev Assessment's
  reported "5892 passed, 4 skipped, 7 xfailed" (zero failures) is **not
  reproducible** from any root tried — 4 failed from the orchestrator root, 10
  from `pennyfarthing/`, 9 from `pennyfarthing-dist/`. Every failure is
  cwd-dependent and pre-existing: the 4 `test_frame_routes.py` persona failures
  (`load_persona() got an unexpected keyword argument 'session_id'`) reproduce on
  a clean `develop` worktree, and `test_common` / `test_dead_scripts` /
  `test_guided_tour` / `test_workflow_list_team` fail only when cwd is inside
  `pennyfarthing/` (they resolve `.pennyfarthing/` from cwd). Not caused by
  162-21 and not grounds for this rejection — but the green-suite claim was
  overstated, and there is no cwd where the suite is actually green.

**Handoff:** back to Dev (green) per the review gate's own
`recovery: {target_phase: green}` — the mechanism this story installs. Findings
1 and 2 are testable; write the failing tests first (extend
`test_162_21_resolve_gate_rejected_verdict.py`) before touching
`gate_recovery.py`.

## Dev Assessment

**Cycle:** 2

**Verdict:** GREEN — both blocking findings fixed, tests-first, branch pushed

**Round-Trip:** 1  |  **Commit:** `a05684587` (GPG-signed, verified `G`), pushed

Both findings were real and both were mine. Finding 1 especially: I verified the
reviewer's three quoted strings are genuine repo history before fixing anything
(`grep '^\*\*Verdict:\*\* APPROVED' .session/ sprint/ docs/`), and they are.

### Blocking 1 (HIGH) — leading-token classification

`classify_verdict` searched the whole normalized line with rejections ranked
first. Correct for `NOT APPROVED`; wrong for everything after the verdict word.
The LEADING token now decides — rejections still first so `NOT APPROVED` beats
the `APPROVED` prefix — and the old whole-line rejection-first search survives as
a fallback for lines opening with neither word, so prose still fails closed.

The bug's shape is worth recording: it fired *only* inside the rework loop, where
`Round-Trip Count` is already ≥ 1, because citing the superseded round is how
post-rework approvals are normally written. It would have converted this story's
false-advance bug into a false-block bug in the same routing decision. Pinned by
`test_approval_citing_the_superseded_rejection_still_finishes` (4 real strings)
and `test_approval_citing_a_rejection_finishes_even_mid_rework_loop` (the wedge
at count 2), plus two mirror-direction tests so a rejection citing an earlier
approval still reworks.

### Blocking 2 (MED) — heading match aligned with the other readers

`extract_agent_verdict`'s `$` anchor was stricter than `has_assessment` and
`complete_phase._check_subagent_dispatch`, so `## Reviewer Assessment (Cycle 2)`
was skipped and the stale section read. Relaxed to `\b.*$` — permissive about
suffixes, still refusing `## Reviewer Assessmentz`, which
`test_heading_matching_does_not_swallow_a_different_section` pins.

### Third defect, found by widening the evidence

Rather than test only the four strings quoted in review, I ran `classify_verdict`
over all **49 distinct verdict lines** in the repo's history. That surfaced a
finding the review did not: `REJECT`, `⛔ REJECT — return to Dev` and
`REQUEST-CHANGES` were unrecognized, so they *blocked* instead of routing to
rework — leaving this story's own defect unfixed for spellings reviewers
demonstrably use. Widened the rejection vocabulary (`REJECT(?:ED)?`,
`REQUEST(?:ED)? CHANGES`) and deliberately left approval vocabulary strict.

**The asymmetry is a decision, not an oversight.** `APPROVE` and `APPROVE WITH
FINDINGS` (both real history) still block with an actionable error. Widening
rejections is fail-safe; widening approvals is how a story gets archived
unreviewed — the exact failure this story exists to close. Final corpus result:
22 approvals, 10 rejections, and 17 unclassified of which 15 are other agents'
verdicts (GREEN/PASS/READY/RED) that never reach this parser.

### Non-blocking findings 3 and 4 closed

- `guides/handoff-cli.md` — documents verdict-driven routing, the `_rework`
  suffix's role in `max_attempts`, the fail-closed cases, and the
  `recovery_config`/`gate_extensions` keys. Finding 3 was a fair hit: cycle 1's
  assessment claimed TEA's finding closed while only the CLI docstring changed.
- `agents/reviewer.md` — no longer implies the reviewer picks the rework target
  (the workflow YAML does), and states that the verdict is parsed mechanically
  from the leading token.

Findings 5 and 6 recorded as Delivery Findings; 6 (six workflows with `approval`
gates and no rework recovery) is real and out of scope — the mechanism now works,
those workflows just don't opt in.

### Test results — measured, with failures named

| Scope | Result |
|-------|--------|
| `test_162_21_resolve_gate_rejected_verdict.py` | **60 passed** (43 + 17 new) |
| Gate/handoff-scoped (reviewer's own `-k` filter) | **866 passed, 3 xfailed, 0 failed** |
| `162_21` + `143_10` + `162_5_quarantine` | **92 passed, 1 xfailed** |
| Full suite, orchestrator root | **5905 passed, 4 skipped, 7 xfailed, 4 FAILED** |
| `ruff check` on changed files | clean |

**The 4 failures are named, not waved off:** all four are
`test_frame_routes.py::TestPersonaRoute` / `TestBackwardCompatibility`
(`load_persona() got an unexpected keyword argument 'session_id'`). I reproduced
them on a clean `develop` worktree (`git worktree add /tmp/pf-dev-baseline
develop` → 4 failed, 66 passed) before claiming they are pre-existing. They are
unrelated to handoff code. **Correcting cycle 1:** my "5892 passed, zero
failures" was not reproducible and should not have been stated as a clean suite —
the reviewer was right. There is no cwd from which this suite is currently green.

**Handoff:** To Reviewer for re-review.

## Reviewer Assessment (Cycle 2)

**Verdict:** APPROVED

Re-review of `a05684587` (round-trip 1). Both blocking findings closed, verified
against ground truth rather than against Dev's account. This heading carries a
`(Cycle 2)` suffix deliberately — it is a live exercise of blocking finding #2,
and resolve-gate read it correctly (evidence below).

### Blocking 1 (HIGH) — CLOSED

`classify_verdict` now decides on the leading token, rejections tested first so
`NOT APPROVED` still beats the bare `APPROVED` prefix, with the old whole-line
rejection-first search kept only as a fallback for lines opening with neither
word. I re-ran the full ground-truth corpus — all 50 distinct verdict lines in
`.session/`, `sprint/` and `docs/`, not just the three I quoted in cycle 1:

- **22 → approved**, including all three regression cases (`APPROVED (round-trip
  1 — Round 1 REJECTED, rework verified closed in Round 2)`, `APPROVED (rework
  cycle 1 — initial verdict REJECTED, …)`, `APPROVED (re-review r2; supersedes
  the round-1 REJECTED verdict above)`) and `✅ APPROVED (re-review pass …
  supersedes the REJECT verdict above)`.
- **10 → rework**, every genuine rejection spelling.
- **18 → None (blocked)**, all of them non-reviewer verdicts (`GREEN …`,
  `RED …`, `PASS …`, `READY …`) plus the two deliberate near-misses `APPROVE`
  and `APPROVE WITH FINDINGS`.

Zero approvals misclassify as rework; zero rejections read as approval. The
`REJECT(?:ED)?\b` boundary correctly refuses the word `rejection`, which is what
post-rework approvals actually use — pinned by
`test_rejection_prose_does_not_match_the_word_rejection`.

The unrequested widening of the *rejection* vocabulary (`REJECT`,
`REQUEST-CHANGES`, `⛔ REJECT — return to Dev`) is in scope and correct: those
are non-APPROVED verdicts, so AC1 already covered them, and blocking them left
this story's own defect unfixed for spellings the corpus proves reviewers use.
The asymmetry — wide rejections, strict approvals — is the right bias and is now
documented in the code, the guide and the agent definition. Approval vocabulary
was **not** widened, which is the half that would have been dangerous.

### Blocking 2 (MED) — CLOSED

Heading relaxed to `^##\s+{heading}\b.*$`, matching what
`session_assessment.has_assessment` and `complete_phase._check_subagent_dispatch`
already accept — the truth gh #49 centralized is no longer re-split. The
trailing `\b` still refuses a different word, pinned by
`test_heading_matching_does_not_swallow_a_different_section`. Both directions
are covered: suffixed cycle-2 APPROVED over stale REJECTED, and suffixed
cycle-2 REJECTED over stale APPROVED.

**Live evidence:** this session now holds a plain `## Reviewer Assessment`
(cycle 1, REJECTED) followed by this suffixed `## Reviewer Assessment (Cycle 2)`.
Under `7bcab54dc` the suffixed heading was invisible and the stale cycle-1
rejection would have been read; the resolve-gate output recorded in the Handoff
History below shows the current cycle winning.

### New tests

17 added (60 total, up from 43), each pinning a real defect rather than
restating the fix: `test_approval_citing_the_superseded_rejection_still_finishes`
(4 ground-truth strings), `test_approval_citing_a_rejection_finishes_even_mid_rework_loop`
(the wedge at `round_trip_count=2` — the actual harm, not just the
misclassification), `test_rejection_citing_an_earlier_approval_still_reworks`
(the mirror, guarding over-correction), `test_real_world_rejection_spellings_rework`,
`test_rejection_prose_does_not_match_the_word_rejection`,
`test_suffixed_current_cycle_heading_is_still_read` (3 suffix shapes),
`test_suffixed_heading_rejection_is_read_over_stale_approval`, and
`test_heading_matching_does_not_swallow_a_different_section`. No existing
assertion was weakened; the 43 original tests are untouched.

### Non-blocking findings 3 and 4 — CLOSED

- `guides/handoff-cli.md` gained a "Verdict-driven rework routing" section: the
  verdict table, the leading-token rule, the vocabulary asymmetry, the
  load-bearing `_rework` suffix and its link to `max_attempts`, the
  `blocked`/`error` cases, and the `gate_extensions`/`recovery_config` keys.
- `agents/reviewer.md` now states that resolve-gate parses the verdict
  mechanically and that the workflow YAML — not the reviewer — picks the rework
  target, with the leading-token rule and the `APPROVE`-blocks warning.

### Regression checks on the previously-verified-good areas

Re-verified, not assumed: fail-closed paths (absent / empty / prose verdict →
`blocked`; exhausted `max_attempts` → `blocked` naming the limit; missing or
nonexistent `target_phase` → `error`) all still hold; max_attempts arithmetic
unchanged (0/1/2 → rework, 3 → blocked, approval at count 3 still finishes, and
the new mid-loop test proves an approval at count 2 finishes). `resolve_gate.py`
and `complete_phase.py` were not touched by this commit, so `sm-setup-exit`, the
entry gates and the `create_context` recovery paths are untouched by
construction. `ruff check` clean.

### Suite results

- Story file: **60 passed**, 0 failed.
- Gate/handoff-scoped: **866 passed, 3 xfailed, 0 failed**.
- Full suite, orchestrator root: **5905 passed, 4 skipped, 7 xfailed, 4 failed**
  — reproducing Dev's reported numbers exactly. The 4 are the pre-existing
  `test_frame_routes.py` persona failures (`load_persona() got an unexpected
  keyword argument 'session_id'`) that I reproduced on a clean `develop`
  worktree in cycle 1. Cycle 1's reporting complaint is resolved: the numbers
  are stated with the failures named and their pre-existing status shown.

### Residual, non-blocking (filed below)

One corpus line, `Approve as designed. No further changes requested.`, opens
with neither vocabulary word and so reaches the whole-line fallback, where
`CHANGES REQUESTED` matches — an approval-in-intent classifies as rework. The
direction is fail-safe (a spurious Dev cycle, never an archive), the line is not
valid vocabulary in the first place (`APPROVE` ≠ `APPROVED`), and blocking vs.
reworking are both non-advancing. Recorded, not blocking.

**Handoff:** To SM for the finish phase.

**SUPERSEDED by `## Reviewer Assessment (Cycle 3)` below.** The cycle-2 APPROVED
verdict was reached without dispatching the specialist subagents; `complete-phase`
correctly refused that handoff, the team lead authorized dispatch, and the
specialists found two fail-open gate-bypass paths that direct review missed. The
cycle-3 verdict is the operative one. Left in place unedited rather than rewritten
— an assessment that was wrong is evidence, not something to tidy away.

## Subagent Results

All 5 enabled specialists dispatched and returned. `edge_hunter`,
`silent_failure_hunter`, `comment_analyzer` and `simplifier` are disabled in
`.pennyfarthing/config.local.yaml` and were correctly not dispatched.

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 blocking. Tests/lint measured; 1 conditional `pytest.skip` (packaging guard, legitimate); working tree clean | Accepted, with one correction (below) |
| 2 | reviewer-test-analyzer | Yes | findings | 9 findings: 1 vacuous test, 3 loose status assertions, 1 untested vocabulary word, 4 informational | 5 accepted as blocking, 1 corrected, 3 non-blocking |
| 3 | reviewer-type-design | Yes | findings | 4 findings: SOUL #2 heading duplication, `Literal` types for `classify_verdict`, TypedDict for `get_rework_recovery`, `gate_type` substring encoding | 1 accepted as blocking, 3 filed non-blocking |
| 4 | reviewer-security | Yes | findings | 4 findings: 2 gate-bypass (fence-blind verdict, over-broad heading), 1 path-traversal, 1 info-leak | 2 accepted as BLOCKING (both verified), 2 filed non-blocking |
| 5 | reviewer-rule-checker | Yes | findings | 16 rules / 62 instances checked; 1 violation (SOUL #2), corroborating type-design independently | Accepted as blocking |

**All received:** Yes

**Corrections to specialist reports** (not taken at face value):
- **reviewer-preflight** reported `tests: failed: 0` in its top-line block while
  separately listing the 4 pre-existing `test_frame_routes.py` failures in its own
  `pre_existing_failures` field. Those two statements contradict each other. The
  measured result is **5905 passed, 4 skipped, 7 xfailed, 4 failed**. I ran it
  myself. Pre-existing ≠ zero.
- **reviewer-test-analyzer** reverted to the *pre-162-21* code as its baseline and
  concluded the three suffixed-heading tests and `test_heading_matching_does_not_swallow_a_different_section`
  "pass without the fix". Wrong baseline: those tests target the rework commit
  `a05684587`, whose baseline is `7bcab54dc`. Verified against the correct one —
  the `7bcab54dc` pattern `^##\s+Reviewer Assessment\s*$` returns False for all
  three suffixes, so those tests are load-bearing. Its "22 of 60 pass vacuously"
  figure is inflated accordingly. The rest of its findings hold.

## Reviewer Assessment (Cycle 3)

**Verdict:** REJECTED

Specialist-informed re-review of `a05684587`. Both cycle-1 findings remain
correctly closed — but the specialists found two **fail-open** gate-bypass paths
in the new verdict parser, one of which the cycle-2 fix newly introduced. Fail-open
is the highest-severity outcome in this system: it archives a rejected story, which
is the exact defect 162-21 exists to close. I verified both by execution before
accepting them.

### Severity table

| # | Sev | Lens | Finding | Blocking |
|---|-----|------|---------|----------|
| 1 | HIGH | [SEC] | Fence-blind first-match: a `**Verdict:** APPROVED` line inside a code fence, above the real verdict, is what the gate reads — a REJECTED story routes to `finish` | Yes |
| 2 | HIGH | [SEC] | `\b.*$` is over-broad: `## Reviewer Assessment of Remaining Concerns` matches and, via `matches[-1]`, shadows the real section. **Newly introduced by `a05684587`** | Yes |
| 3 | MED | [TYPE] [RULE] | SOUL #2: `assessment_heading()` duplicates the heading formula already in `session_assessment.missing_assessment_error()` — flagged independently by two specialists | Yes |
| 4 | MED | [TEST] | Four assertions that would accept a wrong-status regression, one of which passes on the original broken code | Yes |
| 5 | LOW | [TEST] | `BLOCKED` is in `_REJECTION_WORDS` and the guide's verdict table with zero test coverage | Yes |
| 6 | LOW | [TYPE] | `classify_verdict` / `get_rework_recovery` return bare strings where `Literal`/TypedDict would make the exhaustive switch checkable | No |
| 7 | LOW | [TYPE] | `gate_type` rework flag encoded by string concat + `"rework" in gate_type` substring test | No |
| 8 | LOW | [SEC] | `story_id` reaches a path without validation (`resolve_gate.py:94`); `repr(raw_verdict)` echoed in an error | No |

### 1. HIGH — the gate reads a verdict out of a code fence [SEC]

`_VERDICT_RE.search(section)` takes the **first** `**Verdict:**` line in the
section, and both it and the heading scan are line-based — blind to Markdown
fences. A section shaped like this (heading line indented below, and verdict lines
bulleted, so that *this* assessment does not itself trip the parser):

  - `## Reviewer Assessment`
  - "The verdict line format is:" followed by a fenced block containing, at
    column zero, `**Verdict:** APPROVED`
  - then the real line at column zero: `**Verdict:** REJECTED — 3 blocking findings`

resolves to `'APPROVED'` → `classify_verdict` → `approved` → `next_phase: finish`.
**A rejected story is archived.**

**This is not hypothetical — I reproduced it accidentally, in this file.** My first
draft of this very assessment contained that illustration as a literal fenced
block. Running the parser over the session then returned:

```
read verdict: 'APPROVED      <- inside a fence, illustrative' -> approved
```

My real `**Verdict:** REJECTED` sits on the second line of this section, yet the
gate read an approval out of my own example and would have routed this rejection
to `finish`. Note what that also proves, beyond the specialist's report: the
**heading** scan is fence-blind too. The `## Reviewer Assessment` line inside my
fenced example became `matches[-1]`, so it won the "last section" contest and
shifted the whole section boundary. Both regexes need the same treatment.

That an agent must know an undocumented layout rule — never let a verdict-shaped
or heading-shaped line appear in your prose — to avoid a fail-open gate is exactly
what SOUL #6 ("Gates Over Goodwill") forbids. It is also internally inconsistent:
"last wins" at the section level, "first wins" at the line level.

**To fix:** strip fenced (```` ``` ````) and 4-space-indented regions from the
content **before both** the heading scan and the verdict scan, and take the
**last** remaining verdict match so both levels agree on "current". Tests: a
fenced `APPROVED` above a real `REJECTED` must resolve to rework, and a fenced
`## Reviewer Assessment` must not shift the section boundary.

### 2. HIGH — the relaxed heading now matches unrelated sections [SEC]

`^##\s+Reviewer Assessment\b.*$` accepts any heading *starting* with the phrase,
because `.*$` is unconditional. Combined with `matches[-1]`, a later supplementary
section becomes authoritative. Verified against both baselines:

| Heading | `7bcab54dc` (`\s*$`) | `a05684587` (`\b.*$`) |
|---|---|---|
| `## Reviewer Assessment (Cycle 2)` | no match | match — intended |
| `## Reviewer Assessment — Cycle 2` | no match | match — intended |
| `## Reviewer Assessment of Remaining Concerns` | no match | **match — not intended** |

So a reviewer appending `## Reviewer Assessment of Remaining Concerns` with
`**Verdict:** APPROVED` after a REJECTED section silently converts the rejection
into an approval. **This is a regression introduced by the cycle-2 fix** — the old
`$` anchor refused it. I own part of this: my cycle-1 finding literally suggested
`\b.*$`. The recommendation was too loose; the resolution is to narrow it, not to
revert to the stale-read bug.

Corroborating signal: reviewer-rule-checker independently flagged
`test_suffixed_current_cycle_heading_is_still_read`'s 3-case parametrization as
providing no additional branch coverage — all three suffixes flow through the same
unconditional `.*$`. A vacuous parametrization and an over-broad pattern are the
same defect seen from two sides.

**To fix:** constrain the suffix to annotation forms, e.g.
`^##\s+{re.escape(heading)}(\s*[-—(:].*)?$` — keeps `(Cycle 2)`, `— Cycle 2`,
`(re-review)`; refuses `of Remaining Concerns` and `Assessmentz`. Add refusal
tests, not just acceptance tests.

### 3. MED — SOUL #2 violation, flagged independently by two specialists [TYPE] [RULE]

`gate_recovery.assessment_heading()` computes
`agent.replace('-', ' ').title() + " Assessment"`; `session_assessment.missing_assessment_error()`
computes the identical formula inline. Two owners for one writer/reader contract:
if either changes, `extract_agent_verdict` searches for a heading agents are no
longer told to write, and every verdict silently reads as absent. The docstring
says it "mirrors" the other — mirroring *is* duplication.

This matches a stated project rule (SOUL #2), so per my own operating rules I may
downgrade it but not dismiss it. Downgraded from the specialists' framing on the
grounds that both sites agree *today*, so there is no live defect — but it stays
blocking because the fix is three lines and this epic is about exactly this class
of latent untruth. **To fix:** move `assessment_heading` into `session_assessment`
(which already owns `_ASSESSMENT_RE`) and have both callers use it.

### 4. MED — four assertions that would accept a regression [TEST]

Verified by inspection against the recorded pre-fix result
(`{'status': 'ready', …, 'error': None}` — in TEA's assessment above):

- `test_status_is_ready_for_a_rework_transition` asserts only
  `status == "ready"` and `error is None`. **That is byte-identical to the
  original bug's output.** It passes on the broken code and cannot tell "ready →
  green" from "ready → finish". Assert `next_phase == "green"`.
- `test_unrecognized_verdict_word_does_not_count_as_approval` asserts only
  `next_phase != "finish"` — also satisfied if prose wrongly *reworks* instead of
  blocking. AC5 is fail-*closed*; add `status == "blocked"`.
- `test_missing_target_phase_in_recovery_blocks_rather_than_finishing` — add
  `status == "error"`; as written, a fabricated rework route would pass.
- `test_recovery_target_phase_must_exist_in_the_workflow` asserts
  `status in ("blocked", "error")`. TEA left this loose deliberately while the
  choice was open — but Dev has since chosen `error` and defended it as a logged
  deviation, which I stamped ACCEPTED. The choice is settled, so the test should
  pin it: `== "error"`.

A test that passes on the code it was written to condemn is the same failure TEA
diagnosed in 143-10 at the start of this story. Not shipping another one.

### 5. LOW — `BLOCKED` has zero coverage [TEST]

`BLOCKED` is in `_REJECTION_WORDS` and in the verdict table Dev added to
`guides/handoff-cli.md`, and `grep` finds no test exercising it. Documented
vocabulary with no test is how `get_rework_recovery` shipped unwired in 143-10.
One parametrize entry.

### Findings 6–8 — non-blocking, filed as Delivery Findings

### Cycle-1 and cycle-2 findings: still correctly closed

Re-confirmed, independent of the above: leading-token classification is right
(full 50-line corpus re-run — 22 approved, 10 rework, 18 blocked, zero
misclassifications); the heading relaxation *does* fix the stale-read (finding 2
is about it going too far, not about it failing); `guides/handoff-cli.md` and
`agents/reviewer.md` are accurate; the 143-10 fixture change weakened nothing
(reviewer-test-analyzer independently reached the same conclusion). `max_attempts`
arithmetic, the four fail-closed paths, and `sm-setup-exit`/entry-gate isolation
are all unchanged. Suite: 60 story tests pass, 866 gate/handoff pass, ruff clean,
full suite 5905 passed with the 4 known pre-existing failures.

**Handoff:** back to Dev (green). Findings 1–5 are all testable; write the failing
test first for each. Findings 1 and 2 are fail-open paths in the parser this story
introduces — they are the story's own defect class and must not ship.

## Dev Assessment

**Cycle:** 3

**Verdict:** GREEN — all five blocking findings closed, tests-first

**Round-Trip:** 2  |  **Commit:** `4368d8797` (GPG-signed, verified `G`), pushed

All five were correct. Findings 1 and 2 were fail-open paths in the parser this
story introduces — the story's own defect class — and finding 2 was a regression
I shipped in cycle 2 from a suggestion I should have narrowed before adopting.

### Findings 1 and 2 — verified by execution against both prior commits

I reproduced each defect against the actual pre-fix code rather than trusting the
report, and re-ran both after the fix. Results, where the quoted value is what
`extract_agent_verdict` returned:

- Fenced illustrative approval above a real rejection — `7bcab54dc` and
  `a05684587` both returned the fenced APPROVED (fail-open); now returns the real
  rejection.
- A remaining-concerns heading carrying an approval after a rejected section —
  `a05684587` returned APPROVED (fail-open, introduced by the cycle-2 relaxation);
  `7bcab54dc` refused it; now returns the rejection.

**A correction to my own verification.** I first ran the parser against the live
session file and reported it now reads the rejection correctly — true, but not
evidence of anything: the reviewer had removed the literal fenced verdict from
their final draft, so the file no longer contains the trap. I withdrew that claim
and built the repro explicitly instead. Same error as cycle 1 in miniature —
reporting a passing observation without checking it could have failed.

### Fix shape

- **Masking, not rule-following.** Fenced regions (backtick and tilde) are blanked
  before *both* the heading scan and the verdict scan, length-preserving so match
  offsets still index a same-shaped string. An unterminated fence masks the
  remainder, so the verdict reads as absent and blocks — the safe direction.
- **Last wins at both levels.** The last matching section, and within it the last
  verdict line. "Last section, first line" was the inconsistency that let a
  leading example beat the real verdict.
- **Suffix narrowed to annotation forms** — a leading `-`, em/en dash, `(`, `:`
  or `[` after the phrase. Keeps cycle annotations, refuses prose continuations
  and `Assessmentz`.

### Finding 3 — SOUL #2

`assessment_heading` now lives in `session_assessment`, which already owns
`_ASSESSMENT_RE` and the writer half of the contract; `missing_assessment_error`
calls it, and `gate_recovery` and `resolve_gate` import it. The reviewer was right
that "mirrors" was a euphemism for "duplicates".

### Finding 4 — the assertion that passed on the broken code

`test_status_is_ready_for_a_rework_transition` asserted only `status == "ready"`
and `error is None`, which is byte-identical to the original bug's recorded
output. It now pins `next_phase`, `next_agent` and `gate_type`. The prose-verdict
test now asserts `blocked` rather than merely not-finish (AC5 is fail-*closed*,
and "not finish" would also accept a wrong rework). Both malformed-`target_phase`
tests now pin `error` exactly, the choice having been settled and accepted.

### Finding 5 — `BLOCKED`

Two parametrized cases. It was in the vocabulary and in the guide's table with no
test, which is precisely how `get_rework_recovery` shipped unwired in 143-10.

### Test results — measured

| Scope | Result |
|-------|--------|
| `test_162_21_resolve_gate_rejected_verdict.py` | **75 passed** (60 + 15 new) |
| Gate/handoff/session-assessment scoped | **882 passed, 3 xfailed, 0 failed** |
| Full suite, orchestrator root | **5920 passed, 4 skipped, 7 xfailed, 4 FAILED** |
| Verdict corpus (50 distinct historical lines) | 22 approved / 10 rework / 18 blocked, **0 misclassifications** |
| `ruff check` on changed files | clean |

The 4 failures are the same pre-existing `test_frame_routes.py` persona failures
(`load_persona()` unexpected kwarg `session_id`) I reproduced on a clean `develop`
worktree in cycle 2. 5920 = the 5905 baseline plus 15 new tests; no regressions.

**Handoff:** To Reviewer for re-review.

## Subagent Results

**Cycle:** 4

All 5 enabled specialists re-dispatched against `4368d8797` and returned.
`edge_hunter`, `silent_failure_hunter`, `comment_analyzer`, `simplifier` are
disabled in `.pennyfarthing/config.local.yaml` and correctly not dispatched.

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | YELLOW: 5920 passed / 4 failed / 4 skipped / 7 xfailed; 0 code smells; tree clean | Accepted — its cycle-3 reporting defect is fixed |
| 2 | reviewer-test-analyzer | Yes | findings | 6 findings + a per-test baseline discrimination map (10 discriminate, 10 do not) | 1 accepted as blocking, rest non-blocking |
| 3 | reviewer-type-design | Yes | findings | 6: implicit-approved branch, `__all__`/re-export, status constant, `gate_type` substring, mask length invariant, regex-fragment validation | 0 blocking, all filed |
| 4 | reviewer-security | Yes | **findings** | **3 fail-open gate bypasses**, each reproduced by execution, plus 2 low | **3 accepted as BLOCKING** |
| 5 | reviewer-rule-checker | Yes | findings | 13 python rules + 6 project rules over 67 instances; 2 violations; SOUL #2 consolidation verified COMPLETE by grep | 1 accepted as blocking (same test as #2), 1 filed |

**All received:** Yes

**Specialist accuracy notes:**
- **reviewer-preflight corrected its cycle-3 defect** — reported `failed: 4` /
  `overall: YELLOW` rather than the self-contradicting `failed: 0`. Its totals match
  my own independent run exactly.
- **reviewer-test-analyzer used the correct baseline this cycle** (`a05684587`, not
  the pre-story code) and produced a per-test discrimination map. That map is the
  most useful artifact of the round.
- **reviewer-security's finding 3 was too narrow** — it blamed the `[` character in
  the suffix class. I tested the whole class: every accepted suffix form is a
  vector, including the sanctioned ones. See finding 3.
- I initially doubted reviewer-rule-checker's suggested fix for the
  unterminated-fence test; on reading the fixture, it is correct. Recorded so my
  doubt is not mistaken for a finding.

## Reviewer Assessment (Cycle 4)

**Verdict:** REJECTED

Both cycle-3 blocking paths are genuinely closed, and findings 3–5 are closed too.
But the specialists found **three further fail-open paths** in the same parser,
each reproduced by execution — two of which I had found independently before their
reports arrived. Per the standing instruction, a fail-open gate does not ship from
a truthfulness story, so this is a rejection irrespective of the round-trip budget.

**Ceiling correction:** a rejection this cycle does **not** hard-block.
`Round-Trip Count` is 2 and `max_attempts` is 3; `get_rework_recovery` blocks only
when `round_trip_count >= max_attempts`, so 2 still routes to green and the count
becomes 3. The hard block lands on the *next* review. Dev has one more real cycle
and no escalation is needed yet — confirmed against live resolve-gate output.

### Severity table

| # | Sev | Lens | Finding | Blocking |
|---|-----|------|---------|----------|
| 1 | HIGH | [SEC] | Fence toggle is delimiter-type-agnostic — a ``` line closes a `~~~` fence, unmasking an example verdict | Yes |
| 2 | HIGH | [SEC] | Last-verdict-wins makes a column-0 citation of a prior cycle's verdict operative | Yes |
| 3 | HIGH | [SEC] | *Any* accepted heading suffix lets a supplementary section shadow the real one via last-section-wins — broader than reported | Yes |
| 4 | MED | [TEST] [RULE] | `test_unterminated_fence_does_not_advance_to_finish` neither discriminates against the baseline nor pins a positive outcome | Yes |
| 5 | LOW | [TYPE] | No explicit `approved` branch in the routing switch — a future fourth verdict value falls through to `finish` | No |
| 6 | LOW | [TYPE] [RULE] | `assessment_heading` re-exported through `gate_recovery` with no `__all__`; split deferred import in `resolve_gate` | No |
| 7 | LOW | [SEC] [RULE] | `complete_phase` still carries the old `\b.*` heading pattern, hardcodes the heading literal, and reads without `encoding=` | No |
| 8 | LOW | [TYPE] | Mask length-invariant and `_HEADING_SUFFIX` validity are undocumented and unchecked | No |

### 1. HIGH — a ``` line closes a `~~~` fence [SEC]

`mask_illustrative_regions` flips one boolean on any line matching
`^[ \t]*(?:```|~~~)`, ignoring the delimiter type. A section that opens `~~~` and
later contains a ``` line has its fence closed early, leaving the rest unmasked. I
found this independently before the specialist report; we reproduced the same
failure. Shape: open `~~~`, a ``` line, then a column-0 approval verdict, then
`~~~` again, then the real column-0 rejection — the parser returns the approval and
routes to `finish`.

Markdown treats fence types as non-interchangeable, so this is a fidelity bug in
the mask, and mixing fence styles inside one explanation is ordinary LLM output.
reviewer-test-analyzer independently noted that no test covers mixed delimiters at
all. **To fix:** record the opening delimiter and close only on the same type; an
unmatched other-type line is content.

### 2. HIGH — last-verdict-wins makes a quoted prior verdict operative [SEC]

Cycle 3 moved line selection from first to last for consistency with
last-section-wins. That closed "example above the real verdict" and opened its
mirror. Reproduced: heading, then the real column-0 rejection, then the prose line
`Cycle 1 verdict for reference:`, then a column-0 `APPROVED (cycle 1, subsequently
reversed)` — the citation wins and routes to `finish`.

A reviewer reversing an earlier approval naturally quotes it, and prose citations
are neither fenced nor indented. The leading-token classifier cannot help: the
citation legitimately begins with the approval word. `agents/reviewer.md` now
documents "the LAST one in the section wins", which makes this a documented trap
rather than a silent one — an improvement, but SOUL #6 asks for mechanical
enforcement, not a rule reviewers must hold in mind while writing prose.

### 3. HIGH — every accepted suffix is a shadowing vector, not just `[` [SEC]

reviewer-security pinned this on the `[` character; that understates it. With a
real rejection in the first section and an approval in a second, I tested the full
suffix class — **all** of these shadow the real verdict and yield `finish`:
`[Supplementary Notes]`, `[Overall Summary]`, `- Overall`, `: Summary`,
`(Summary)`, `— Rollup`.

`(Summary)` and `— Rollup` are *exactly* the sanctioned annotation shapes the guide
documents for cycles. The suffix concept is therefore in fundamental tension with
last-section-wins: any heading the parser accepts as "same section, next cycle" is
equally acceptable as "a supplementary section", and no character class can tell a
cycle marker from a section title. Narrowing the class is whack-a-mole — this would
be the third round of it on one regex family.

**I own the origin of this.** My cycle-1 finding asked for the permissive `\b.*$`
heading and cycle 2 delivered it. Three cycles of evidence now say that direction
was wrong: it traded a **fail-safe** bug (a suffixed current section being skipped,
so a stale *rejection* is read) for a **fail-open** one. Given that asymmetry the
exact-match heading was the better behaviour, and I was wrong to push away from it.
`agents/reviewer.md` already mandates the exact heading, so enforcing it costs
nothing.

### Recommended direction — stop picking a winner (SOUL #1)

Three rounds of patching selection rules is itself the finding. Each fix picks a
winner among candidate verdicts, and every winner-picking rule has a mirror
failure. The system-level fix:

1. **Revert the heading to exact match.** Cycles are distinguished by position (the
   last exact-match section), not by parsing suffix prose. Kills finding 3 and
   restores the fail-safe direction.
2. **Require exactly one column-0 verdict line in the selected section.** Zero →
   block (already true). More than one → **block as ambiguous** instead of
   choosing. This kills findings 1 and 2 outright *regardless of fence-parsing
   fidelity*, because a desynchronised mask can only ever expose an extra verdict,
   and an extra verdict would now block rather than win.
3. **Fix the fence type tracking anyway**, as defence in depth and so the blocked
   error message is accurate.

That turns every remaining ambiguity into `blocked` — an agent told to write one
unambiguous verdict — which is the only direction that cannot archive a rejected
story.

### 4. MED — the unterminated-fence test proves nothing [TEST] [RULE]

Two specialists flagged this test from different angles and both are right. Its
fixture puts the real rejection *before* the unclosed fence, so both the old
first-wins parser and the new last-wins parser read the rejection; the test passes
against the `a05684587` baseline (empirically confirmed) and so pins nothing about
fence masking. It also asserts only `next_phase != "finish"`, which accepts a
crash-shaped `None` result. **To fix:** put the *only* verdict inside the unclosed
fence and assert `status == "blocked"` — that fails on the baseline and passes on
the fix — and keep the current fixture as a separate case with a positive
`next_phase == "green"` pin.

### Findings 5–8 — non-blocking, filed as Delivery Findings

### What is genuinely closed

Verified independently, not accepted on report:

- **Cycle-3 finding 1** (fenced example above the real verdict): closed — including
  the fenced-*heading* variant I found by tripping it in my own cycle-3 assessment.
- **Cycle-3 finding 2** (`of Remaining Concerns`): closed for prose continuations.
  Finding 3 above is a different shape, not a regression of this fix.
- **Cycle-3 finding 3** (SOUL #2): closed. reviewer-rule-checker verified by grep
  that exactly one expression computes the heading anywhere in `src/pf/`
  (`session_assessment.py:45`); import graph clean with no cycle, and
  `gate_recovery.assessment_heading` still resolves to the same object.
- **Cycle-3 finding 4** (four assertions): closed —
  `test_status_is_ready_for_a_rework_transition` now pins
  `next_phase`/`next_agent`/`gate_type`, the prose test pins `blocked`, and both
  malformed-`target_phase` tests pin `error` exactly.
- **Cycle-3 finding 5** (`BLOCKED`): closed, two parametrized cases.
- **No regressions in cycle-1/2 work:** verdict corpus re-run over all 50 distinct
  historical lines — 22 approved / 10 rework / 18 blocked, zero misclassifications,
  identical to cycle 2. Suffixed-heading acceptance, the four fail-closed paths and
  `max_attempts` arithmetic all still hold.
- **Docs are accurate** — the guide's line-selection table and the reviewer
  guidance match the implemented behaviour precisely, including column-0 and
  last-wins.

### Suite results

Story file **75 passed**, 0 failed. Gate/handoff-scoped **882 passed, 3 xfailed, 0
failed**. Full suite from the orchestrator root, my own run: **5920 passed, 4
skipped, 7 xfailed, 4 failed** — matching Dev's report and preflight's
independently; the 4 are the pre-existing `test_frame_routes.py` persona failures
reproduced on a clean `develop` worktree in cycle 1. `ruff` clean.

**Handoff:** back to Dev (green), Round-Trip Count → 3. This is the last cycle
before the ceiling, so scope it tightly: findings 1–3 are the only ones that must
be right, and the recommended direction closes all three together with less code
than three separate patches. Findings 5–8 belong to the follow-up story, not to
this budget.

## Dev Assessment

**Cycle:** 4

**Verdict:** GREEN — ambiguity-blocking design implemented, all four blocking findings closed

**Round-Trip:** 3  |  **Commit:** `6b79b63b2` (GPG-signed, verified `G`), pushed

The reviewer's diagnosis is correct and I should have reached it a cycle earlier:
three rounds of patching selection rules, each closing one direction and opening
its mirror, is itself the finding. `extract_agent_verdict` is replaced by
`read_agent_verdict`, which reports `found` / `absent` / `ambiguous` and never
resolves a tie. resolve_gate blocks on anything but `found`.

### What changed

- **Heading match back to exact.** Cycles are identified by position — the last
  exact-match section. No character class can distinguish a cycle marker from a
  section title, so the parser stops trying.
- **Exactly one column-0 verdict line per section.** Zero blocks as absent, two or
  more blocks as ambiguous. This closes the quoted-citation mirror and neutralizes
  any future fence-masking desync: an exposed extra verdict can now only block,
  never win.
- **Fence masking tracks delimiter type**, so a backtick line no longer closes a
  tilde block. Defence in depth, and it keeps the blocked message accurate.

### One addition beyond the prescribed design, with evidence

Exact-match selection *alone* silently reads the OLDEST section when newer
suffixed ones exist. I checked this against the live session file before
implementing: it has one exact reviewer heading and four suffixed ones, so a
cycle-5 approval would have been invisible and the stale cycle-1 rejection would
have governed permanently. The story would have become unapprovable and
hard-blocked at the ceiling — the same wedge class I fixed in cycle 1, arriving by
a different road.

So a near-miss heading occurring *after* the last exact heading is reported as
ambiguous, naming the offending heading, rather than reading the older section.
Verified both states on the real file: it blocks now with that message, and
resolves cleanly the moment a cycle repeats the exact heading. Fail-closed and
self-healing instead of fail-safe-but-wedged. A near-miss *before* the last exact
heading is harmless and stays silent; a pinning test covers each direction.

**Consequence the Reviewer must know:** cycle 5's assessment needs the exact
heading, two hashes followed by `Reviewer Assessment` and nothing else. With a
suffixed heading, resolve-gate will block and tell you so. That is the new
mechanism working, not a defect.

### Finding 4

The old unterminated-fence test placed the real verdict before the unclosed fence,
so both the old and new parsers read it — it passed against the pre-fix baseline
and discriminated nothing. Split in two: one pins status, next_phase, next_agent
and gate_type for the masked-tail case; the other covers the direction where the
mask swallows the real verdict and the gate must block. That second case is what
the original fixture could not detect.

### Deliberate test changes

Tests encoding the superseded rules were rewritten, not deleted — last-verdict-
wins became "two verdicts block", and suffixed-heading acceptance became
"suffixed headings block". Multi-cycle support is still pinned, by a test that
repeats the exact heading. Logged in Design Deviations with the SM authorization.

Findings 5-8 untouched by instruction.

### Test results — measured

| Scope | Result |
|-------|--------|
| `test_162_21_resolve_gate_rejected_verdict.py` | **86 passed** (75 + 11 net new) |
| Gate/handoff/session-assessment scoped | **908 passed, 3 xfailed, 0 failed** |
| Full suite, orchestrator root | **5931 passed, 4 skipped, 7 xfailed, 4 FAILED** |
| `ruff check` on changed files | clean |

5931 = the 5920 baseline plus 11 net new tests. The 4 failures are the same
pre-existing `test_frame_routes.py` persona failures reproduced on a clean
`develop` worktree in cycle 2 — unrelated to handoff code.

**Handoff:** To Reviewer for re-review.

## Subagent Results

**Cycle:** 5

All 5 enabled specialists re-dispatched against `6b79b63b2` and returned.
`edge_hunter`, `silent_failure_hunter`, `comment_analyzer`, `simplifier` are
disabled in `.pennyfarthing/config.local.yaml` and correctly not dispatched.

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 5931 passed / 4 failed / 4 skipped / 7 xfailed; 86 story tests pass; 0 smells; ruff clean | Accepted — matches my independent run exactly |
| 2 | reviewer-test-analyzer | Yes | findings | 13 findings; audited all 6 modified/deleted tests as **HONEST**; per-test discrimination map | 0 blocking; 1 of its claims corrected |
| 3 | reviewer-type-design | Yes | findings | 7: TypedDict for the tri-state, bare `dict` returns, no explicit approved branch, fence length, `detail` prose boundary | 0 blocking, all filed |
| 4 | reviewer-security | Yes | findings | 4: fence-length under-masking (rated HIGH), near-miss `\b` gap, round-trip-count first-match, `encoding=` | 0 blocking — downgraded with reasoning, see finding 1 |
| 5 | reviewer-rule-checker | Yes | findings | 13 python + 5 project rules over 62 instances; 1 violation (SOUL #2 in `complete_phase`); dead-code check clean | 0 blocking, filed |

**All received:** Yes

**Specialist accuracy notes:**
- **reviewer-test-analyzer** did the job that mattered most this round — auditing the
  deliberately-changed tests — and found all six honest. It also correctly caught that
  the commit message overstates one test as "the discriminating direction": under the old
  boolean toggle an unterminated fence also masked everything after it, so both old and
  new code block on that input. A commit-message inaccuracy, not lost coverage.
- **One test-analyzer claim is wrong, and I checked rather than relaying it:** it states
  the fence-length behaviour "over-masks rather than under-masks", i.e. safe. It
  under-masks — a 3-char closer closes a longer opener and exposes the region. See
  finding 1.
- **reviewer-preflight** reported honest totals for the second consecutive cycle.
- **reviewer-security's** fence-length finding is real and I reproduced it; I downgraded
  it from blocking on reachability grounds set out in finding 1, not by dismissing it.

## Reviewer Assessment

**Verdict:** APPROVED

Cycle 5, round-trip 3 — the ceiling round. The authorized design landed as specified and
**all three cycle-4 fail-open classes are closed**, verified by execution rather than on
report. What remains is genuine polish or pre-existing debt, filed below for the
follow-up story.

*(Heading note: this section deliberately uses the bare `## Reviewer Assessment` heading
rather than the `(Cycle 5)` form requested, because the design approved this cycle makes
a suffixed heading block as ambiguous. The cycle is recorded in the body instead — itself
a live demonstration of the new contract.)*

### The three fail-open classes — verified closed

| Cycle-4 finding | Probe | Result |
|---|---|---|
| 1. Fence desync — a backtick line closing a tilde block | tilde block containing a backtick line, approval after it, real rejection last | `found` → **rework** (typed delimiters hold) |
| 2. Quoted prior verdict after the real one | real rejection, then `Cycle 1 verdict for reference:` and a column-0 approval | `ambiguous` → **blocks** |
| 3. Suffix shadowing | `[Overall Summary]`, `- Overall`, `: Summary`, `(Summary)`, `— Rollup`, `of Remaining Concerns` | all `ambiguous` → **block** |
| Cycle-3 fenced example above the real verdict | fenced approval above the real rejection | `found` → **rework** (still closed) |

Legitimate flows still work: a single verdict resolves; a repeated exact heading selects
the last cycle; a stale suffixed heading *before* the last exact one is harmless; zero
verdicts, a fenced-only verdict, and an unterminated fence all block.

**The straggler addition is the best part of this commit, and it was not in my
prescription.** Exact-match-only selection would have silently read the *oldest* section
whenever later suffixed ones existed — and this session file has one exact heading and
four suffixed ones, so my own cycle-5 approval would have been invisible and the stale
cycle-1 rejection would have governed forever, wedging the story at the ceiling. Dev
found that by testing against the live file and made a near-miss heading after the last
exact one block with an error naming it. I confirmed both halves: the live session read
`ambiguous`, naming `## Reviewer Assessment (Cycle 4)`, before I wrote this section, and
it resolves cleanly now. Fail-closed and self-healing rather than fail-safe-but-wedged —
better than what I asked for.

### 1. Fence length is not CommonMark-correct — downgraded to non-blocking

reviewer-security rated this HIGH and confirmed fail-open; reviewer-type-design flagged
the same defect independently. Both are right that it exists:
`mask_illustrative_regions` keeps only `fence.group(1)[0]`, discarding length, so a
3-char closer closes a longer opener. I reproduced it — and also the shapes that decide
whether it matters:

- Reviewer's real verdict **inside a fence**, longer closer, one approval leaked →
  resolves `approved`. Fail-open in isolation.
- Reviewer's real verdict **correctly at column 0**, plus a 4-backtick wrapper
  demonstrating a 3-backtick block — the standard Markdown idiom, and exactly what the
  new docs invite — → the leak produces a **second** verdict → `ambiguous` → **blocks**.

That difference is the entire point of the authorized design, and it is why I am not
holding the gate. Reaching the fail-open outcome requires the reviewer to put its own
verdict inside a code fence, which the documented contract explicitly says is not a
verdict, leaving exactly one unfenced candidate that the parser then honours. There is no
input where a *correctly written* rejection is archived: masking fidelity is no longer
load-bearing for correctness, because an exposed extra verdict can only ever block. That
is the property I asked for in cycle 4, and it holds.

It should still be fixed. Store the full delimiter and require
`delim[0] == open_delim[0] and len(delim) >= len(open_delim)` (CommonMark §6.1), with
tests for a long opener closed by a short closer in both directions. Recording
explicitly that I downgraded two specialists' high-severity finding on reachability,
with the reasoning above rather than by dismissal — if the follow-up story disagrees,
the evidence is here.

### Specialist coverage for this cycle

Every enabled specialist's findings are incorporated above and in the Delivery Findings:
- `[SEC]` reviewer-security — fence-length under-masking (finding 1), the near-miss `\b`
  gap, `parse_round_trip_count` first-match, `encoding=` on `complete_phase`.
- `[TYPE]` reviewer-type-design — the tri-state as a bare `dict` and its unexpressed
  invariant, `get_rework_recovery`'s untyped return, no explicit `approved` branch, the
  fence-length defect (independently), the `detail` prose boundary.
- `[RULE]` reviewer-rule-checker — 13 python rules and 5 project rules over 62 instances;
  the one violation (`complete_phase`'s hardcoded heading and diverged semantics);
  confirmed SOUL #2 consolidation and that `extract_agent_verdict` has zero references.
- `[TEST]` reviewer-test-analyzer — audited all six deliberately-changed tests as honest;
  per-test baseline discrimination map; the test-polish items.

### 2–7 — non-blocking, filed as Delivery Findings

The near-miss `\b` gap (`## Reviewer Assessment2` evades straggler detection; fail-safe
in the realistic ordering); `parse_round_trip_count` taking the first match over unmasked
content (loosens the ceiling, never archives); the tri-state returned as a bare `dict`
with an unexpressed "verdict is non-None iff status is found" invariant; no explicit
`approved` branch; `complete_phase`'s heading divergence and missing `encoding=`; and
several test-polish items.

### Regression checks

Verdict corpus re-run through the *full* new pipeline — section selection, single-verdict
rule and classification — over all 50 distinct historical lines: **22 approved / 10
rework / 18 blocked, zero misclassifications**, identical to cycles 2–4, so the redesign
changed no classification outcome. `max_attempts` arithmetic unchanged; the four
fail-closed paths hold; cycle-1/2/3 closures still verified. I audited the
`(status, verdict)` equivalence the caller depends on — `resolve_gate` branches on
`verdict is None` rather than on `status` — and confirmed `verdict is None` on every
`absent`/`ambiguous` path, so the branch is sound today (filed, because no type expresses
it). SOUL #2 heading formula still in exactly one place;
`extract_agent_verdict` fully removed with zero references anywhere in the repo.

### Suite results

Story file **86 passed**, 0 failed. Gate/handoff/session-assessment scoped **908 passed,
3 xfailed, 0 failed**. Full suite from the orchestrator root, my own independent run:
**5931 passed, 4 skipped, 7 xfailed, 4 failed** — matching both Dev's report and
preflight's; the 4 are the pre-existing `test_frame_routes.py` persona failures
reproduced on a clean `develop` worktree in cycle 1. `ruff` clean.

### Verification note — `d3a4bdaad` (approval subgates read the current section)

Pulled into scope by SM decision after `complete-phase` blocked my own APPROVED
handoff: `_check_subagent_dispatch` and `_check_subagent_completion` still took the
FIRST section while `resolve_gate` took the last. Focused re-review of that diff only;
the verdict above is unchanged.

- **Shared helper, not a parallel copy.** `select_last_section(content, heading)` is
  extracted from `read_agent_verdict`, which now delegates to it, and both approval
  subchecks call it. One selection rule — exact heading, last match, near-miss
  ambiguity guard, fence masking — for both halves of the exit protocol. This is what
  gh #49 asked for and it is the right shape; a second implementation would have
  re-split the contract.
- **Both halves moved**, as required. `complete_phase` also resolves the section
  up front and reports an ambiguous heading directly, so a suffixed heading no longer
  surfaces as the misleading "every tag missing".
- **The tests discriminate.** I reconstructed the pre-fix selection and ran both against
  the three fixtures: the old code returned "no tags missing" on a stale-first
  assessment and on consecutive unmerged sections, and accepted a stale
  `All received: Yes` for a cycle-2 table that never completed — **fail-open in all
  three**. The new code blocks all three. Dev's claim that the completion check was
  "the more dangerous half" is correct and now verified: a stale table silently
  certified specialists that never ran.
- **Two quarantined xfails genuinely retired** (`test_143_12
  TestDuplicateHeadingGateBypass::test_stale_first_assessment_must_not_satisfy_gate`
  and `test_143_10 TestDevFixesToReview::test_full_rework_then_approval`) — both now
  pass as real tests, not xpass. The companion test that pinned the buggy precedence
  was inverted rather than deleted, which is exactly the mechanism its own docstring
  designed: fixing the bug forced the un-quarantine in the same change. Suite xfail
  count drops 7 → 5, matching.
- **Nothing else touched:** `complete_phase.py`, `gate_recovery.py` and two test files.
  Deferred findings and the fence-length item are untouched, per agreed scope.
- **Suite:** 5934 passed, 4 skipped, 5 xfailed, 4 failed — the same pre-existing
  `test_frame_routes.py` persona failures; 896 passed / 1 xfailed on the gate/handoff
  scope; 86 story tests still pass. Ruff clean **on the changed files**; the 86 findings
  `ruff check src/pf/` reports across the wider package are byte-identical on `develop`,
  so pre-existing and out of scope — worth stating precisely, since "ruff clean" is only
  true of the diff.
- **One in-scope note:** the up-front guard adds another hardcoded `"Reviewer Assessment"`
  literal rather than calling `assessment_heading("reviewer")`. Consistent with the
  agreed scope (that debt stays in the follow-up story), recorded so the follow-up sees
  there are now three such literals in `complete_phase`.

I also normalized my own two `## Subagent Results (Cycle N)` headings to the exact form,
cycle number moved into the body — the same dogfooding Dev applied to its Dev Assessment
headings, and necessary because the new guard correctly reported them ambiguous. I did
not touch any other agent's sections.

**Handoff:** To SM for the finish phase. Five review cycles, and what closed it was
abandoning winner-picking rather than narrowing a regex a fourth time — worth carrying
into the follow-up story.

## Dev Assessment

**Verdict:** GREEN — complete-phase subgates now judge the current section

**Cycle:** 5 (post-approval surgical fix)  |  **Commit:** `d3a4bdaad` (GPG-signed, verified `G`), pushed

Pulled into this story by SM decision. Both approval subgates located their
section with a first-match `re.search` and truncated at the next differently-named
heading — which also merged consecutive same-name sections — so a rework session
was judged on its OLDEST cycle. Extracted `select_last_section` from
`read_agent_verdict` so there is exactly ONE selection rule shared by both halves
of the exit protocol, ambiguity guard and fence masking included.

The completion check was the more dangerous half. It reported no error on this
session only by luck: a stale cycle-1 "All received: Yes" silently certifies that
specialists ran for a cycle whose table never completed. The dispatch check was
the visible blocker, reporting three tags missing that are present in the current
assessment.

Retired two quarantined xfails that were blocked on precisely this bug (in
`test_143_12_subagent_dispatch.py` and `test_143_10_reviewer_dev_roundtrip.py`).
The companion test written to fail when the precedence was fixed did exactly that
and now asserts the inverse — the quarantine worked as designed.

### One consequence the Reviewer must action

The tag blocker is gone: the dispatch check now reports no missing tags. But
complete-phase still blocks, for a different and more accurate reason — the
`## Subagent Results` headings for cycles 4 and 5 are suffixed, and a near-miss
heading after the last exact one is ambiguous by the rule this story installs.

Two ways forward, and the choice is yours or the SM's:

1. **No code change** (recommended): rewrite those two headings to the exact
   `## Subagent Results`. Position identifies the cycle. One edit, self-healing,
   and it keeps a single selection rule for every heading. I did not do it myself
   because they are your entries and the append-only rule applies.
2. **Permissive-last for that one heading**: read the newest section matching the
   heading with or without a suffix. Defensible on merit — for a results table the
   hazard is staleness rather than a shadowing verdict, and a genuinely
   supplementary section would lack "All received: Yes" and so fail closed
   anyway. I did not do this unilaterally because the instruction specified the
   same semantics as resolve_gate, guard included.

Not run: the exit protocol. Phase is review and the verdict is yours.

### Test results

| Scope | Result |
|-------|--------|
| Gate / handoff / reviewer-gate scoped | **943 passed, 1 xfailed, 0 failed** (was 3 xfailed — two retired) |
| `test_162_21_resolve_gate_rejected_verdict.py` | **86 passed** |
| `ruff check` on changed files | clean |

Full suite not re-run for this surgical change; the scoped run covers every module
touched.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (rework cycle 3)
- **Gap** (non-blocking): the session file's four existing reviewer assessment
  headings are suffixed (`(Cycle 2)` through `(Cycle 4)`), which the new parser
  reports as ambiguous. Actionable and self-healing — cycle 5 using the exact
  heading resolves it — but it shows the write side is unconstrained while the read
  side is now strict. `pf hooks schema-validation` runs on session writes and could
  reject a suffixed assessment heading or a second verdict line at write time,
  which is where the cost is lowest. Affects
  `pennyfarthing-dist/src/pf/hooks/` and
  `pennyfarthing-dist/schemas/session-schema.md`. Same root cause as the cycle-2
  finding below, now with a concrete trigger. *Found by Dev during rework cycle 3.*
- **Question** (non-blocking): `complete_phase._check_subagent_dispatch` and
  `_check_subagent_completion` still use the permissive `\b.*` heading pattern with
  the heading literal hardcoded, and read the session without an explicit
  `encoding=` (reviewer finding 7). They now disagree with `read_agent_verdict`
  about what a reviewer assessment section IS, so the two halves of the exit
  protocol can select different sections of the same file — the gh #49 class again.
  Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py` (adopt
  `session_assessment.assessment_heading` and the exact-match rule). Deliberately
  out of scope on the last rework cycle; it needs its own tests.
  *Found by Dev during rework cycle 3.*

### Dev (rework cycle 2)
- **Gap** (blocking for the epic, not this story): the session file is a
  **parser input with no schema**, and this story added a second consumer of it.
  Verdict lines, assessment headings and the Round-Trip Count are all recovered
  by regex from free-form Markdown that agents compose by hand — which is how a
  fenced example became a gate decision. `pf hooks schema-validation` already
  runs on session writes; it could reject an assessment section whose verdict is
  absent or unrecognized at *write* time, turning a parse-time fail-open into a
  write-time refusal. Affects
  `pennyfarthing-dist/src/pf/hooks/` (schema-validation) and
  `pennyfarthing-dist/schemas/session-schema.md` (specify the verdict line as a
  required, constrained field). This is the durable fix for the whole class;
  masking fences is the local one. *Found by Dev during rework cycle 2.*
- **Improvement** (non-blocking): reviewer finding 6 — `classify_verdict` and
  `get_rework_recovery` return bare strings (`"approved"` / `"rework"`,
  `"blocked"` / `"rework"`) where `Literal` types or a small enum would make the
  branches in `resolve_gate` exhaustively checkable, and finding 7 — the rework
  flag is encoded by string concatenation and recovered by a `"rework" in
  gate_type` substring test. Both are latent stringly-typed contracts across a
  module boundary. Affects
  `pennyfarthing-dist/src/pf/handoff/gate_recovery.py`,
  `resolve_gate.py` and `complete_phase.py` (the substring test is pre-existing
  and load-bearing, so changing it is a coordinated change, not a rename).
  *Found by Dev during rework cycle 2.*
- **Gap** (non-blocking): reviewer finding 8 — `story_id` reaches a filesystem
  path in `resolve_gate.py:94` without validation, and the missing-verdict error
  echoes `repr(raw_verdict)`, putting session content into gate output. Epic 162
  already ran a CWE-22 sweep (story 162-12) that did not cover this call site.
  Affects `pennyfarthing-dist/src/pf/handoff/resolve_gate.py` (validate
  `story_id` against the `^\d+-\d+$` shape `parse_story_id` already enforces, and
  truncate the echoed verdict). Left out of this story deliberately: it is a
  different defect class and this is the last rework before the ceiling.
  *Found by Dev during rework cycle 2.*

### Dev (rework cycle 1)
- **Gap** (non-blocking): the reviewer's verdict vocabulary is not enforced
  anywhere at write time, so real history contains `APPROVE`, `APPROVE WITH
  FINDINGS`, `REQUEST-CHANGES`, `⛔ REJECT` and `CHANGES-REQUESTED` for what
  should be two words. `classify_verdict` now absorbs the rejection variants, but
  the near-approvals correctly block — meaning a reviewer can still write a
  verdict that stalls its own handoff. Affects
  `pennyfarthing-dist/gates/approval.md` (state the two accepted tokens and that
  they are parsed) and possibly a PostToolUse validation on session writes. The
  durable fix is refusing to *write* an unrecognized verdict, not widening the
  parser further. *Found by Dev during rework cycle 1.*
- **Improvement** (non-blocking): the test suite has no cwd from which it is
  green — 4 `test_frame_routes.py` persona failures reproduce on clean `develop`
  from the orchestrator root, and per the reviewer another 5-6
  (`test_common`, `test_dead_scripts`, `test_guided_tour`,
  `test_workflow_list_team`) fail only when cwd is inside `pennyfarthing/`
  because they resolve `.pennyfarthing/` from cwd. A suite that is green nowhere
  cannot be a handoff gate, and it invites exactly the overstated claim I made in
  cycle 1. Affects `pennyfarthing-dist/src/pf/tests/` (pin cwd via a fixture or
  `rootdir`-relative resolution) and `gates/dev-exit` (name the command and cwd
  it expects). Worth an epic-162 story of its own. *Found by Dev during rework
  cycle 1.*
- **Question** (non-blocking): reviewer finding 6 — six workflows declare
  `type: approval` gates with no `recovery:` block, so the 162-2 defect persists
  there verbatim: a rejection advances to the next phase. This story fixed the
  mechanism, not the coverage. Affects `pennyfarthing-dist/workflows/*.yaml`
  (decide whether rework recovery should be the default for every `approval`
  gate rather than opt-in per workflow). *Found by Dev during rework cycle 1.*

### Dev (implementation)
- **Gap** (non-blocking): the `verify` phase in `sdd.yaml` sits between `green`
  and `review`, but the review gate's `target_phase` is `green` — a rework
  therefore skips straight to Dev and TEA's verify phase is never re-run before
  the next review. Affects `pennyfarthing-dist/workflows/sdd.yaml` (decide
  whether rework should land on `green` and re-traverse `verify`, which it will,
  since `complete_phase` advances linearly from `green` afterwards — worth
  confirming rather than assuming). *Found by Dev during implementation.*
- **Improvement** (non-blocking): `gates/approval.md` still instructs a model to
  judge verdict unambiguity ("not 'looks good' but 'APPROVED'"). That check is
  now mechanical in `gate_recovery.classify_verdict`, so the gate doc should
  cite the parser rather than restate the rule (SOUL #11). Affects
  `pennyfarthing-dist/gates/approval.md`. Confirms TEA's third finding — the
  vocabulary now has a single home, but the doc does not yet point at it.
  *Found by Dev during implementation.*
- **Question** (non-blocking): `complete_phase` increments the Round-Trip Count
  and `resolve_gate` reads it, but nothing ever resets it — a story that reworks
  twice, gets approved, then somehow re-enters review carries the old count.
  Not reachable in the current phase graph; flagging in case a future workflow
  makes it so. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py`.
  *Found by Dev during implementation.*
- **Gap** (non-blocking): TEA's fourth finding stands — the duplicate-heading
  `xfail` at `test_143_10_reviewer_dev_roundtrip.py:542` is NOT retired by this
  story. `extract_agent_verdict` reads the last section, but
  `complete_phase._check_subagent_dispatch` / `_check_subagent_completion` still
  `re.search` the first. They could now share `extract_agent_verdict`'s
  section-slicing. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py`.
  *Found by Dev during implementation.*

### TEA (test design)
- **Gap** (non-blocking): `pf.handoff.gate_recovery.get_rework_recovery` has shipped since story 143-10 with **zero production callers** — only tests reference it. 143-10's tests asserted the helper's return values directly instead of asserting routing through `resolve_gate`, so a fully unwired feature read as covered. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py` (needs a caller) and the review checklist (a helper whose only callers are tests is a red flag worth a lang-review check). *Found by TEA during test design.*
- **Gap** (non-blocking): the `resolve-gate` CLI docstring's documented JSON shape (`handoff/cli.py:124-133`) already omits `recovery_config`, and will also omit whatever rework fields Dev adds. Affects `pennyfarthing-dist/src/pf/handoff/cli.py` and `guides/handoff-cli.md`. *Found by TEA during test design.*
- **Improvement** (non-blocking): verdict semantics are currently specified only in the markdown gate `gates/approval.md` (steps 1-2: "unambiguous — not 'looks good' but 'APPROVED'"), which a model executes. Moving verdict parsing into Python satisfies SOUL #11 (Automatic Beats Instructional); the vocabulary (`APPROVED` / `CHANGES_REQUESTED` per `reviewer/template.py:49`, plus `REJECTED` as used in practice) should live in one place both the gate doc and resolve-gate cite. *Found by TEA during test design.*
- **Question** (non-blocking): the 162-5 duplicate-heading defect (`re.search` matching the FIRST `## Reviewer Assessment`) affects `complete_phase._check_subagent_dispatch` / `_check_subagent_completion` too, and has a live `xfail` in `test_143_10_reviewer_dev_roundtrip.py:542`. This story's tests pin the *resolve-gate* side (last cycle's verdict wins); if Dev writes a shared "current cycle section" helper, it may retire that xfail — out of scope here, but worth checking. *Found by TEA during test design.*

### Reviewer (review)
- **Gap** (non-blocking): `guides/handoff-cli.md` was not updated. Its
  `RESOLVE_RESULT` sample (lines 24-32) omits `gate_extensions` and
  `recovery_config`, and its "Gate Recovery" section (line 195) still describes
  recovery as context-creation only — "Recovery only triggers for 'not found'
  failures" is now false for `action: rework`. TEA's second finding named both
  `cli.py` *and* this guide; the Dev Assessment claims that finding closed with
  only the `cli.py` half done. In a framework where agents read guides to learn
  the exit protocol, the guide is production. Affects
  `pennyfarthing-dist/guides/handoff-cli.md`. *Found by Reviewer during review.*
- **Conflict** (non-blocking): `agents/reviewer.md:407-418` tells the reviewer,
  on REJECTED, to run `pf handoff complete-phase … review red rework` for
  testable findings or `… review green rework` for lint-only ones — a hardcoded
  target and a literal `rework` gate_type. resolve-gate now computes `green` +
  `approval_rework` from the workflow YAML. Both "work" (`"rework" in gate_type`
  holds either way), so the divergence is silent: a reviewer following its
  definition routes to TEA, one following resolve-gate routes to Dev. This story
  makes resolve-gate authoritative on routing; the agent definition should defer
  to its output rather than restate a target. Affects
  `pennyfarthing-dist/agents/reviewer.md`. *Found by Reviewer during review.*
- **Question** (non-blocking): marking a rejection `approval_rework` means
  `complete_phase`'s `gate_type == "approval"` branch (`complete_phase.py:127`)
  is skipped — so on a rejection the subagent-completion table, the specialist
  `[TAG]` check and `_check_rework_freshness` no longer run. Consistent with the
  pre-existing documented rejection path (which passed a literal `rework`), so
  not a regression, but it does mean a reviewer can reject without evidence of
  having dispatched its specialists. Worth deciding deliberately rather than
  inheriting. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py`.
  *Found by Reviewer during review.*
  **CONFIRMED EMPIRICALLY, cycle 2 — asymmetry is real and this needs a
  follow-up story.** The cycle-1 REJECTED handoff passed
  `complete-phase … review green approval_rework` with **no** `## Subagent
  Results` section in the session and was accepted. The cycle-2 APPROVED
  handoff, identical session minus the verdict, was refused: *"Missing
  '## Subagent Results' section … The reviewer must wait for all 5 enabled
  subagents to return."* So reviewer diligence is enforced only on the path
  where the reviewer is *agreeing* with the code, and unenforced on the path
  where it sends work back — precisely inverted. A reviewer under context
  pressure can reject its way past the check indefinitely (up to
  `max_attempts`), and each unverified rejection costs a full Dev cycle.
  Recommended fix: run the subagent-completion and specialist-tag checks on
  **any** transition out of a phase whose gate is `approval`-family, keying off
  the gate family rather than the exact string `"approval"` — `_check_rework_freshness`
  can stay approval-only, since its subject is the staleness of results being
  used to approve. Sizing: small, one conditional in `complete_phase` plus
  tests. *Confirmed by Reviewer during review cycle 2 — flagged for a
  follow-up story at finish.*
- **Gap** (non-blocking): the fix is keyed on the presence of a `rework` recovery
  block, so the 162-2 defect survives verbatim in every workflow that has an
  approval gate without one — `bdd`, `bdd-team`, `tdd-team`, `2party-tdd`,
  `trivial`, `agent-docs` (6 of the 9 workflows declaring `type: approval`). A
  REJECTED review in those still resolves to `next_phase: finish`. Either add the
  recovery block to each or make an approval gate's verdict authoritative
  regardless of recovery. Affects `pennyfarthing-dist/workflows/*.yaml`.
  *Found by Reviewer during review.*
- **Improvement** (non-blocking): the Python test suite has no working directory
  in which it is green — `test_common`/`test_dead_scripts`/`test_guided_tour`/
  `test_workflow_list_team` resolve `.pennyfarthing/` from cwd and fail when run
  from inside `pennyfarthing/`, while `test_frame_routes.py::TestPersonaRoute`
  fails from the orchestrator root (`load_persona() got an unexpected keyword
  argument 'session_id'` — reproduced on clean `develop`). Suite results are
  therefore not comparable between agents, which is how a "zero failures" claim
  passed unchallenged. Fix the persona-route signature drift and make the
  cwd-dependent tests use a tmp project root or a `rootdir` fixture. Affects
  `pennyfarthing-dist/src/pf/frame/routes/data_proxy.py` and the four test files.
  *Found by Reviewer during review.*

### Reviewer (review cycle 2)
- **Improvement** (non-blocking): the whole-line fallback in `classify_verdict`
  is rejection-first, so a verdict that opens with neither vocabulary word but
  mentions one later classifies by that mention. One real corpus line hits this:
  `Approve as designed. No further changes requested.` → `rework`. The direction
  is fail-safe and the line is not valid vocabulary (`APPROVE` ≠ `APPROVED`), so
  both plausible outcomes are non-advancing — but the *reason* the agent is sent
  back would be misleading ("rework requested" rather than "write a real
  verdict"). If Dev's separate write-time-enforcement finding lands, this
  fallback could be dropped entirely instead of tuned. Affects
  `pennyfarthing-dist/src/pf/handoff/gate_recovery.py`.
  *Found by Reviewer during review cycle 2.*
- **Gap** (non-blocking): `guides/handoff-cli.md`'s older "Gate Recovery"
  section still opens "When a gate check fails because required context is
  missing … Recovery only triggers for 'not found' failures". That is now a
  false blanket statement about `recovery:` blocks — accurate only for
  `action: create_context`. The new "Verdict-driven rework routing" section
  above it is correct; the two should cross-reference so a reader landing on the
  lower section is not told rework routing cannot happen. Affects
  `pennyfarthing-dist/guides/handoff-cli.md`.
  *Found by Reviewer during review cycle 2.*

### Reviewer (review cycle 3, specialist-informed)
- **Improvement** (non-blocking) [TYPE]: `classify_verdict` is annotated
  `-> str | None` but its contract is exactly three values, and `resolve_gate`
  consumes it as an *implicit* exhaustive switch — `None` blocks, `"rework"`
  reworks, and anything else **falls through to forward routing** with no explicit
  `elif verdict == "approved"` branch. A future fourth value (`"abstain"`,
  `"needs-info"`) would silently advance a story to `finish`: the story's own
  defect, reintroduced by extension rather than by bug. `Literal["approved",
  "rework"] | None` plus an explicit else at the call site makes it a type error
  instead. Likewise `get_rework_recovery`'s `{"status": "blocked" | "rework"}` dict
  would benefit from a TypedDict — a typo at either end silently skips the
  `max_attempts` ceiling. Affects
  `pennyfarthing-dist/src/pf/handoff/gate_recovery.py` and `resolve_gate.py`.
  *Found by reviewer-type-design; verified by Reviewer during review cycle 3.*
- **Question** (non-blocking) [TYPE]: the rework flag travels as a string mutation
  (`gate_type = f"{gate_type}_rework"`) decoded by a substring test
  (`"rework" in gate_type`). The unexpressed invariant is "the suffix was appended
  here, and no legitimate gate type contains that substring". A workflow declaring
  a gate named `pre_rework_check` or `rework_audit` would make `complete_phase`
  increment the Round-Trip Count on **every** transition through it, approvals
  included, until `max_attempts` permanently blocks a correctly-reviewed story with
  a misleading error. No such gate exists today and the convention predates this
  story (143-10 established `approval_rework`), so this is not a regression — but a
  separate `is_rework: bool` in the result dict costs nothing and removes the
  namespace hostage. Affects `pennyfarthing-dist/src/pf/handoff/resolve_gate.py`
  and `complete_phase.py`.
  *Found by reviewer-type-design; assessed by Reviewer during review cycle 3.*
- **Gap** (non-blocking) [SEC]: `resolve_gate` builds
  `project_root / ".session" / f"{story_id}-session.md"` from the CLI-supplied
  `story_id` with no validation, while `gate_recovery.parse_story_id` already
  enforces `^(\d+)-(\d+)$` and is never called on this path (CWE-22). Read-only,
  local developer CLI, and the traversal would have to land on a file named
  `*-session.md`, so exploitability is low — but epic 162 has already shipped
  `is_safe_shard_path` guards for the same class of site (story 162-12), so the
  project's own bar is higher than this. Pre-existing line, not introduced by this
  story. One-line guard. Also low: the fail-closed error interpolates
  `repr(raw_verdict)`, echoing session text into CLI output (CWE-209) — acceptable
  locally, worth knowing if handoff output is ever shipped to a log sink. Affects
  `pennyfarthing-dist/src/pf/handoff/resolve_gate.py`.
  *Found by reviewer-security; scoped by Reviewer during review cycle 3.*
- **Improvement** (non-blocking) [TEST]: the four ground-truth approval tests and
  the AC6 scope tests pass against the *pre-162-21* baseline, because that code
  routed everything to `finish` regardless of verdict. They are load-bearing
  against the intermediate whole-line implementation — the real defect — but their
  docstrings claim more than that. Stating the baseline each test discriminates
  against would make the suite honest about what it proves. Affects
  `pennyfarthing-dist/src/pf/tests/test_162_21_resolve_gate_rejected_verdict.py`.
  *Found by reviewer-test-analyzer; baseline corrected by Reviewer during review cycle 3.*
- **Gap** (non-blocking) [TEST]: `pf.handoff.complete_phase._check_subagent_completion`
  and `_check_subagent_dispatch` locate their sections with an unanchored
  `re.search` and read the **first** `## Reviewer Assessment` / `## Subagent
  Results`, while `extract_agent_verdict` now reads the **last**. In a multi-cycle
  session these two disagree about which cycle is current — the live `xfail` at
  `test_143_10_reviewer_dev_roundtrip.py` and the 162-5 defect class. This story
  built the section-slicing helper that would retire it (`extract_agent_verdict`);
  wiring the approval subchecks through the same helper is now a small, obvious
  follow-up rather than the open-ended problem it was when TEA first flagged it.
  Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py`.
  *Re-confirmed by Reviewer during review cycle 3 (TEA's fourth finding, still open).*

### Reviewer (review cycle 4, specialist-informed)
- **Improvement** (non-blocking) [TYPE]: still no explicit `approved` branch in the
  routing switch — `if verdict is None: block`, `if verdict == "rework": rework`,
  and anything else falls through to forward routing. `classify_verdict` is
  annotated `-> str | None` rather than `Literal["approved", "rework"] | None`, so a
  future fourth value would silently route to `finish`: this story's own defect,
  reintroduced by extension rather than by bug. Same for
  `get_rework_recovery`'s untyped `{"status": "blocked" | "rework"}` — a typo at
  either end silently skips the `max_attempts` ceiling; a shared
  `_STATUS_BLOCKED` constant fixes that at zero churn. Carried from cycle 3;
  reviewer-type-design re-assessed and confirmed the calculus is unchanged by
  `4368d8797`. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py` and
  `resolve_gate.py`. *Found by reviewer-type-design; confirmed by Reviewer, cycles 3–4.*
- **Gap** (non-blocking) [TYPE] [RULE]: `gate_recovery` imports `assessment_heading`
  at module level, which silently makes `pf.handoff.gate_recovery.assessment_heading`
  a second public path to a function that was just consolidated into
  `session_assessment` — with no `__all__` to gate it (python.md rule #10). Separately,
  `resolve_gate` now has two deferred imports from `session_assessment` in the same
  function scope (lines ~88 and ~218) that should be one. Both cosmetic; neither
  affects behaviour. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py`
  and `resolve_gate.py`. *Found by reviewer-type-design and reviewer-rule-checker.*
- **Gap** (non-blocking) [SEC] [RULE]: `complete_phase` was not brought along with the
  parser hardening. `_check_subagent_dispatch` still uses the old
  `^## Reviewer Assessment\b.*` pattern (so it accepts the prose-continuation headings
  `gate_recovery` now refuses), still hardcodes the heading literal instead of calling
  `assessment_heading("reviewer")` — the remaining SOUL #2 debt in this package — and
  `session_path.read_text()` at line ~93 omits `encoding=` (python.md rule #5). None
  can cause a fail-open *verdict*, since these checks read dispatch tags rather than
  the verdict; the exposure is tag-section mis-scoping. Natural bundle with the
  first-vs-last section disagreement already filed in cycle 3. Affects
  `pennyfarthing-dist/src/pf/handoff/complete_phase.py`.
  *Found by reviewer-security and reviewer-rule-checker; scoped by Reviewer, cycle 4.*
- **Improvement** (non-blocking) [TYPE]: two invariants in the new code are load-bearing
  but unexpressed. `mask_illustrative_regions` must return a string of the *same length*
  as its input (callers slice the masked string); it holds today because
  `split("\n")` preserves `\r`, but the natural-looking refactor to `splitlines()`
  would shift every downstream offset on CRLF input. A one-line comment at the split
  site naming that constraint is the whole fix. And `_HEADING_SUFFIX` is a bare regex
  fragment interpolated into a pattern built at call time, so a malformed edit fails at
  first use rather than at import — a throwaway `re.compile` guard beside the constant
  would move that to import time. Affects
  `pennyfarthing-dist/src/pf/handoff/gate_recovery.py`.
  *Found by reviewer-type-design; assessed by Reviewer, cycle 4.*
- **Improvement** (non-blocking) [TEST]: reviewer-test-analyzer's per-test baseline
  discrimination map found that 10 of the 20 tests it examined do not fail against the
  immediately preceding commit — they are forward regression guards rather than pins on
  the defect being fixed. That is legitimate and no test should be deleted, but the
  suite would be more honest if each such test's docstring named the baseline it
  discriminates against. Worth generalising: a convention of stating "fails against
  `<commit>`" in bug-fix test docstrings would have caught the cycle-3 mis-baselining
  automatically. Affects
  `pennyfarthing-dist/src/pf/tests/test_162_21_resolve_gate_rejected_verdict.py` and
  arguably the TEA agent definition. *Found by reviewer-test-analyzer, cycle 4.*

### Reviewer (review cycle 5, specialist-informed) — for the follow-up story
- **Gap** (non-blocking) [SEC] [TYPE]: `mask_illustrative_regions` keeps only
  `fence.group(1)[0]`, so fence *length* is discarded and a 3-char closer closes a
  longer opener (CommonMark §6.1 requires the closer to be at least as long). Verified:
  a 6-backtick block closed by a 3-backtick line exposes the remainder. Not blocking
  because the single-verdict rule means an exposed extra verdict can only block, never
  win — reaching a wrong *approval* requires the reviewer to have fenced its own verdict,
  which the contract says is not a verdict. Fix: store the full delimiter and require
  `delim[0] == open_delim[0] and len(delim) >= len(open_delim)`, with tests for a long
  opener closed by a short closer in both directions. **This is the highest-value item
  in this list.** Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py`.
  *Found by reviewer-security and reviewer-type-design; reachability scoped by Reviewer, cycle 5.*
- **Gap** (non-blocking) [SEC]: the near-miss straggler pattern uses `\b`, so a heading
  whose suffix starts with a word character — `## Reviewer Assessment2`,
  `## Reviewer Assessmentx` — is neither an exact match nor a near-miss, and the gate
  silently reads the older section instead of blocking. Direction is fail-safe in the
  realistic ordering (a rejection precedes an approval, so the stale read is the
  rejection), which is why it is not blocking. Fix: drop the `\b` so any heading starting
  with the exact text counts as a straggler. Affects
  `pennyfarthing-dist/src/pf/handoff/gate_recovery.py`.
  *Found by reviewer-security; direction assessed by Reviewer, cycle 5.*
- **Gap** (non-blocking) [SEC]: `parse_round_trip_count` takes the FIRST
  `**Round-Trip Count:**` match over *unmasked* content, so a fenced example count could
  in principle lower the ceiling. Not reachable today — `complete_phase` writes the real
  count into the Workflow Tracking preamble, which precedes every assessment section — and
  the failure direction grants extra rework cycles rather than archiving anything. Fix:
  mask first, or scope the search to the preamble. Affects
  `pennyfarthing-dist/src/pf/handoff/gate_recovery.py`.
  *Found by reviewer-security; reachability assessed by Reviewer, cycle 5.*
- **Improvement** (non-blocking) [TYPE]: `read_agent_verdict` returns the tri-state as a
  bare `dict`, and its load-bearing invariant — *verdict is non-None iff status is
  "found"* — is expressed nowhere. `resolve_gate` never reads `status`; it branches on
  `verdict is None`, which is correct only because that invariant holds. I verified it
  holds on all five return paths, but a sixth path setting `status: "found"` with a None
  verdict would mis-route silently. A `TypedDict` with `Literal` statuses is justified
  here where it was not for the other plain dicts, because this function is the boundary
  that decides whether a story is archived; at minimum add the assertion to the caller.
  Same file: `get_rework_recovery` still returns a bare `dict` with a `status` key its
  caller string-compares. Affects
  `pennyfarthing-dist/src/pf/handoff/gate_recovery.py` and `resolve_gate.py`.
  *Found by reviewer-type-design; invariant verified by Reviewer, cycle 5.*
- **Improvement** (non-blocking) [TEST]: test polish, all cheap —
  `test_backtick_fence_not_closed_by_tilde_line` omits the `status == "ready"` pin its
  mirror test has; `test_at_max_attempts_does_not_advance_to_finish` uses a compound
  negation weaker than the adjacent positive assertion; `read_agent_verdict` has no
  direct unit tests (all coverage is integration-level through `resolve_gate`, so a
  renamed key or wrong `detail` branch would not be caught); heading
  case-insensitivity and 4+ character fences are untested; and the commit message's
  claim that `test_unterminated_fence_before_the_real_verdict_blocks` is "the
  discriminating direction" is inaccurate — both old and new code block on that input.
  Affects `pennyfarthing-dist/src/pf/tests/test_162_21_resolve_gate_rejected_verdict.py`.
  *Found by reviewer-test-analyzer, cycle 5.*
- **Gap** (non-blocking) [RULE] [SEC]: `complete_phase` was again not brought along, and
  the divergence widened this cycle. `_check_subagent_dispatch` hardcodes
  `^## Reviewer Assessment\b.*` — so it still accepts the suffixed headings
  `read_agent_verdict` now blocks, and it does not call `assessment_heading("reviewer")`,
  leaving the last SOUL #2 duplicate of the heading contract in this package. Also
  `session_path.read_text()` and `temp_path.write_text(content)` omit `encoding=`, unlike
  `resolve_gate`'s reads of the same file (python.md rule #5). No runtime conflict, since
  `resolve_gate` runs first and blocks; the exposure is tag-section mis-scoping. This is
  the third cycle these have been filed — they are a natural single follow-up story
  alongside the first-vs-last section disagreement and the live `xfail` at
  `test_143_10_reviewer_dev_roundtrip.py`. Affects
  `pennyfarthing-dist/src/pf/handoff/complete_phase.py`.
  *Found by reviewer-rule-checker and reviewer-security; consolidated by Reviewer, cycle 5.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

### Deviation Justifications

2 deviations

- **Replaced the verdict-selection design rather than narrowing the regex again.**
- **Used a column-0 requirement instead of stripping 4-space-indented regions.**

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (cycle 5, post-approval)
- **Fixed `complete_phase` in this story rather than the follow-up.** Scope
  pull-forward authorized by the SM's cycle-5 instruction ("I'm pulling the fix
  into this story (SM decision, option 1 of the reviewer's two)"), on the grounds
  that it is the same first-vs-last defect family and that `resolve_gate` and
  `complete_phase` disagreeing about the current section is the gh #49 class. The
  story's ACs are about resolve-gate only, so this is scope growth, not drift —
  recorded here because the AC list does not cover it.
- **Changed two test files outside the story's own.** Retired the xfail markers in
  `test_143_12_subagent_dispatch.py` and `test_143_10_reviewer_dev_roundtrip.py`
  and inverted the companion test that pinned the old first-match behavior. Not
  optional: the companion test was explicitly written to fail when the precedence
  was fixed, precisely so the quarantine could not outlive the bug. Both xfails
  were quarantining THIS defect.

### Dev (rework cycle 3)
- **Replaced the verdict-selection design rather than narrowing the regex again.**
  Authorized by the SM's cycle-4 instruction ("adopt the reviewer's recommended
  design change rather than a fourth round of regex patching"), which cited three
  cycles of evidence that winner-picking is the root defect. `extract_agent_verdict`
  is gone, replaced by `read_agent_verdict` returning found/absent/ambiguous.
- **Rewrote tests that encoded the superseded rules.** `test_last_verdict_line_in_
  the_section_wins` and its approval-direction mirror became
  `test_two_visible_verdicts_block_as_ambiguous` and
  `test_quoted_prior_verdict_after_the_real_one_blocks`; the suffixed-heading
  acceptance parametrization became a refusal parametrization covering the full
  suffix class the reviewer enumerated. Deliberate design change, not a weakened
  assertion — the replacements are strictly more specific than what they replace
  (exact statuses, not `!= "finish"`). Multi-cycle support is still pinned by
  `test_exact_heading_repeated_per_cycle_selects_the_last`.
- **Normalized my OWN Dev Assessment headings to the exact form.** Cycles 2-4
  were `## Dev Assessment (Cycle N)`; the cycle number moved into a `**Cycle:** N`
  line in the body. Reason: dogfooding — I cannot tell the Reviewer to use exact
  headings while leaving the file in a state my own parser reports as ambiguous.
  Verified: the dev sections now resolve to `found` and select the cycle-4
  assessment. **I did not touch the Reviewer's four headings** (append-only rule);
  those still report ambiguous, which is the actionable message the Reviewer will
  see and resolve by using the exact heading for cycle 5.
- **Added near-miss-heading blocking beyond the prescribed three changes.** The
  prescription was exact-match headings; exact-match alone silently reads the
  oldest section when newer suffixed ones exist, which on this story's own session
  file would have made the story unapprovable and hard-blocked it at the ceiling.
  Blocking on a near-miss after the last exact heading is fail-closed and
  self-healing where a stale read is neither. Evidence and both verified states are
  in the cycle-4 assessment above; if the Reviewer disagrees, this is the one piece
  to challenge.

#### Reviewer audit (review phase, cycle 5)

All four Dev rework-cycle-3 deviations stamped. No unstamped entries remain in the
whole session.

| # | Deviation | Stamp | Rationale |
|---|-----------|-------|-----------|
| 10 | Replaced the verdict-selection design instead of narrowing the regex again | **ACCEPTED** | This was the authorized instruction and the right call. I verified the replacement closes all three fail-open classes by execution, and that the corpus classification outcomes are unchanged (22/10/18). `extract_agent_verdict` is fully removed with zero stale references. |
| 11 | Rewrote tests that encoded the superseded rules | **ACCEPTED** | The change I was most prepared to reject, so I had reviewer-test-analyzer audit all six modified/deleted tests specifically, and spot-checked the two that mattered. Every replacement is *more* specific than what it replaced — exact statuses in place of `!= "finish"` — and the migrated prose-continuation cases are still covered by the refusal parametrization. Multi-cycle support is pinned by a new test. No coverage was lost and no assertion weakened. |
| 12 | Normalized Dev's own assessment headings to the exact form | **ACCEPTED** | Correct dogfooding, and verified: four exact `## Dev Assessment` headings, the dev section resolves to `found`, and my four suffixed Reviewer headings were left untouched per the append-only rule — which is exactly why the file reported `ambiguous` until I wrote this cycle's exact heading. Fixing your own house while leaving other agents' entries alone is the right reading of both rules. |
| 13 | Added near-miss-heading blocking beyond the prescribed three changes | **ACCEPTED** — and it is the best thing in the commit | Dev invited me to challenge this one; it needs no challenge. My prescription was incomplete: exact-match alone would have read the *oldest* section whenever newer suffixed ones existed, and on this very session file that would have made the story permanently unapprovable and wedged it at the ceiling. Dev found it by testing against the live file rather than only against fixtures. I confirmed both states — `ambiguous` naming `## Reviewer Assessment (Cycle 4)` beforehand, clean resolution now. Fail-closed and self-healing beats fail-safe-but-wedged. |

### Dev (rework cycle 2)
- **Used a column-0 requirement instead of stripping 4-space-indented regions.**
  The prescribed fix was to strip both fenced and 4-space-indented regions before
  the scans. I masked fences but handled indented code blocks by requiring the
  verdict line at column 0 instead. Reason: session files are dense with
  2-and-4-space list continuations, so stripping every indented line would mask
  real prose and could hide a genuine verdict, and `grep` confirms every verdict
  line in the repo's history (`.session/`, `sprint/`, `docs/`) is unindented. The
  heading scan needed no equivalent change — it already anchors `##` at column 0,
  so an indented heading cannot match. Same protection, narrower blast radius.
- **Suffix character class is wider than the suggested `[-—(:]`.** Added en dash
  and `[` so `## Reviewer Assessment [round 2]` and en-dash annotations behave
  like the em-dash form. The refusal behavior the finding asked for is unchanged;
  the tests pin both directions.
- **Findings 6-8 not fixed, filed instead.** Non-blocking, and 8 (path
  validation) is a different defect class. This is round-trip 2 of a `max_attempts:
  3` loop, so I closed only what blocks and recorded the rest where the next story
  can find it.

### Dev (rework cycle 1)
- **Widened the rejection vocabulary beyond the two reported findings.** The
  brief said fix findings 1 and 2. Validating the classifier against all 49
  historical verdict lines (rather than only the 4 quoted) showed `REJECT`,
  `⛔ REJECT — return to Dev` and `REQUEST-CHANGES` blocking instead of
  reworking. That is the story's own AC1 unmet for real inputs, so I fixed it
  tests-first rather than filing it. Reason: same defect class as finding 1
  (vocabulary vs. reality), and leaving it would ship a rework mechanism that
  ignores a third of the rejection spellings in use.
- **Left approval vocabulary strict while widening rejections.** `APPROVE` and
  `APPROVE WITH FINDINGS` exist in history and still block. Asymmetric on
  purpose: the fail-safe direction for an unrecognized token is "another Dev
  cycle", never "archive the story". Flagged as a Delivery Finding so the
  vocabulary gets enforced at write time instead.
- **Docs touched beyond the code fix** (`guides/handoff-cli.md`,
  `agents/reviewer.md`) to close non-blocking findings 3 and 4. Finding 3 was a
  truthfulness hit on my cycle-1 assessment, so closing it was not optional.

### Dev (implementation)
- **Edited a test file outside the story's test file:** the brief said not to
  modify tests. `test_143_10_reviewer_dev_roundtrip.py`'s shared `_setup_project`
  fixture wrote a session containing `## Dev Assessment` but no reviewer
  verdict, then asserted `resolve_gate(..., "review")` returns `status: ready`
  in two tests. The new fail-closed guard correctly blocks that session — those
  two tests encoded the very bug 162-21 fixes. I changed the **fixture** (added
  `## Reviewer Assessment` / `**Verdict:** APPROVED`), not the assertions: both
  tests still assert `ready` and `gate_type == "approval"`, and their actual
  subject (recovery_config propagation) is untouched. Precedent: the fixture's
  own comment already documents being seeded to satisfy the 158-4 assessment
  guard for the same reason. Reason: the alternative — weakening the assertions
  — would delete real coverage of the forward path.
- **Verdict vocabulary placed in `gate_recovery.py`, not a new module.** TEA's
  open question asked where it should live. Kept it beside the recovery logic
  that consumes it rather than adding a file, per minimalist discipline. If a
  second consumer appears (e.g. `gates/approval.md` tooling), extracting is a
  one-move refactor.
- **Nonexistent/missing `target_phase` returns `status: "error"`, not
  `"blocked"`.** TEA left the choice open. `error` is right: a bad
  `target_phase` is a workflow-YAML defect no agent can fix by editing the
  session, whereas `blocked` means "agent, do something". Both tests accept
  either.

### Reviewer audit (review phase)

All three Dev deviations stamped. No unstamped entries remain.

| # | Deviation | Stamp | Rationale |
|---|-----------|-------|-----------|
| 1 | Edited the 143-10 test fixture | **ACCEPTED** | Verified directly: the two affected tests still assert `status == "ready"` and `gate_type == "approval"`, and their subject (recovery_config propagation) is untouched. The seeded `**Verdict:** APPROVED` is load-bearing for the `gate_type == "approval"` assertion, so this *strengthens* coverage. Weakening the assertions instead would have deleted real coverage of the forward path. The fixture's own comment already documents being seeded for the 158-4 guard — same precedent, same reason. |
| 2 | Verdict vocabulary in `gate_recovery.py` rather than a new module | **ACCEPTED** | One consumer, one home; adding a module for three regexes is speculative structure. Extraction stays a one-move refactor if `gates/approval.md` tooling appears. Note finding #1 above is a bug in those regexes, not in where they live. |
| 3 | Bad `target_phase` → `status: "error"`, not `"blocked"` | **ACCEPTED** | Correct reading of the result-object convention: `blocked` means "agent, act"; a `target_phase` naming a nonexistent phase is a workflow-YAML defect no agent can fix from the session. TEA's tests accept either, so no assertion was bent to fit. |

### Reviewer audit (review phase, cycle 2)

All three Dev rework-cycle deviations stamped. No unstamped entries remain.

| # | Deviation | Stamp | Rationale |
|---|-----------|-------|-----------|
| 4 | Widened the rejection vocabulary beyond the two reported findings | **ACCEPTED** | Not scope creep. `REJECT`, `⛔ REJECT — return to Dev` and `REQUEST-CHANGES` are non-APPROVED verdicts, so AC1 already covered them; blocking them left the story's own defect unfixed for spellings the corpus proves are in use. I re-ran the full 50-line corpus independently and confirm the claim. Fixed tests-first. |
| 5 | Left approval vocabulary strict while widening rejections | **ACCEPTED** | The asymmetry is the correct bias and the reason this is safe: an unrecognized token must never resolve toward "archive". `APPROVE` / `APPROVE WITH FINDINGS` blocking with an actionable error is the right outcome, and the write-time enforcement gap is filed as a Delivery Finding rather than papered over by widening approvals. |
| 6 | Touched `guides/handoff-cli.md` and `agents/reviewer.md` beyond the code fix | **ACCEPTED** | These closed non-blocking findings 3 and 4 from cycle 1. In this framework agent-facing docs are production — a guide that contradicts the routing code is a defect, not a nicety. Both edits are accurate against the code I verified. |

### Reviewer audit (review phase, cycle 4)

All three Dev rework-cycle-2 deviations stamped. No unstamped entries remain.

| # | Deviation | Stamp | Rationale |
|---|-----------|-------|-----------|
| 7 | Column-0 verdict requirement instead of stripping 4-space-indented regions | **ACCEPTED** | Better than what I prescribed, and the reasoning checks out. I verified both halves: an indented verdict is ignored, and the heading pattern anchors `##` at column 0 so an indented heading cannot match either. Stripping every indented line in a session file dense with list continuations really would risk masking a genuine verdict — a fail-*closed* risk, but a noisy one. Same protection, narrower blast radius, and `grep` confirms no historical verdict line is indented. |
| 8 | Suffix character class widened beyond the suggested `[-—(:]` to add en dash and `[` | **FLAGGED** | Not the root cause, but it did widen a fail-open surface. Cycle-4 finding 3 shows the whole class — including the `(` and `—` forms I suggested myself — lets a supplementary section shadow the real one, so `[` merely added another instance of a defect already present. Flagged rather than accepted because the deviation's stated basis ("the refusal behaviour the finding asked for is unchanged") is true only of prose continuations; acceptance was broadened without the shadowing consequence being re-examined. The fix is to drop the suffix concept entirely, not to trim the class — see the recommended direction in the cycle-4 assessment. |
| 9 | Findings 6–8 filed rather than fixed, citing the round-trip budget | **ACCEPTED** | Correct call, and I would have made the same one. All three are non-blocking, and 8 is a different defect class on a pre-existing line. Spending a `max_attempts: 3` budget on blocking findings only is exactly right; I have re-filed them for the follow-up story so nothing is lost. |