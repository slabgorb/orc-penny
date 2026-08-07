---
story_id: "162-47"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-47: Verdict-parse and gate follow-ups from 162-21 review (cycle-5 findings)

## Story Details
- **ID:** 162-47
- **Jira Key:** (no Jira — kanban-only project)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-47-verdict-parse-gate-followups
- **PR:** #191

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-07T16:55:24Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-07T15:08:08.614995+00:00 | 2026-08-07T15:10:34Z | 2m 25s |
| red | 2026-08-07T15:10:34Z | 2026-08-07T15:35:39Z | 25m 5s |
| green | 2026-08-07T15:35:39Z | 2026-08-07T16:06:46Z | 31m 7s |
| review | 2026-08-07T16:06:46Z | 2026-08-07T16:31:12Z | 24m 26s |
| green | 2026-08-07T16:31:12Z | 2026-08-07T16:44:47Z | 13m 35s |
| review | 2026-08-07T16:44:47Z | 2026-08-07T16:55:24Z | 10m 37s |
| finish | 2026-08-07T16:55:24Z | - | - |

## Sm Assessment

**Story:** 162-47 (3 pts, p1, tdd) — verdict-parse and gate-machinery hardening. Two finding clusters; full inventory with source pointers in `sprint/context/context-story-162-47.md`.

**Why this story now:** the 162-49 run just hit three LIVE instances of this defect family (one-error-per-attempt gate discovery, Cycle-N false-attestation wording, stale round-1 verdict re-read that nearly double-advanced the phase mid-rework). This story de-risks the ceremony for every remaining story in the epic.

**Scope shape:** Cluster A is the 162-21 cycle-5 review tail (8 items: CommonMark fence-length in `mask_illustrative_regions`, near-miss heading word-boundary gap, `parse_round_trip_count` masking, tri-state invariant, `complete_phase` heading literals + missing `encoding=`, test polish, rework recovery for the six approval-gate workflows still carrying the 162-2 defect, approval-only subagent check). Cluster B is the three 162-49-run ACs on the story record. TEA derives formal ACs from both; where the source review probed a fix shape, the tests pin the PROBED shape.

**Risk notes for TEA:**
- This code is the machinery the pipeline itself runs on — regressions here corrupt sessions, not just outputs. The existing test files around `resolve_gate`/`complete_phase` (162-21/25/28 families) are dense; extend, don't duplicate.
- The stale-verdict AC (Cluster B item 3) needs a design decision (round-trip counter vs verdict-staleness vs require-cycle-2-verdict) — TEA should pin the OBSERVABLE invariant (no double phase-advance; a completed rework round never re-routes to rework) and leave mechanism latitude to Dev, unless measurement shows one shape is forced.
- The approval-only subagent check (A8) and the six-workflow rework recovery (A7) touch workflow YAMLs as well as Python — check both layers.
- 3 pts: full TEA→Dev→Reviewer pipeline.

**Routing:** phased tdd, TEA first. Peloton-inline mode — agents return to SM, no relay markers.

## TEA Assessment

**Tests Required:** Yes

**Status:** RED — 77 failing tests, 302 passing in the scoped run (all 216 pre-existing gate/handoff tests still green). Full suite from the orchestrator root: 6236 passed, 4 skipped, 77 failed — every failure is one of mine.

**Commit:** `173266147` (GPG-signed, verified `G`), on `feat/162-47-verdict-parse-gate-followups`.

### Acceptance criteria derived from the two clusters

Cluster A — the 162-21 cycle-5 review tail. Where that review recorded a probed
fix shape, the tests pin the PROBED shape and quote it in the module docstring.

| AC | Requirement | Probed shape carried |
|----|-------------|----------------------|
| A1 | A fence closer must match the opener's type AND be at least as long (CommonMark §6.1) | `delim[0] == open_delim[0] and len(delim) >= len(open_delim)`, "with tests for a long opener closed by a short closer in both directions" |
| A2 | A heading that merely STARTS with the exact text is a straggler, whatever follows | drop the `\b` from the near-miss pattern |
| A3 | The operative round-trip counter is read from the session preamble; reader and writer agree | "mask first, or scope the search to the preamble" (masking landed in 162-28; scoping did not) |
| A4 | The verdict tri-state invariant is expressed in the type AND enforced at the caller; the classification switch is exhaustive | `TypedDict` with `Literal` statuses, "at minimum add the assertion to the caller" |
| A5 | `complete_phase` derives the reviewer heading from `assessment_heading()` and declares `encoding=` on every text read/write | one heading formula, one place (SOUL #2); python.md rule #5 |
| A6 | Two vacuous pre-existing assertions repaired; `read_agent_verdict` gets direct unit coverage; heading case-insensitivity and 4+ char fences covered | the four named test-polish items |
| A7 | Every approval-gated `review` phase routes a rejection as rework, with a valid earlier target and a positive attempt limit | "add the recovery block to each" (option 1 of two) |
| A8 | The subagent-completion, specialist-tag and heading-ambiguity checks run on any transition out of an approval-FAMILY gate; the freshness guard stays approval-only | carried verbatim, including the deliberate freshness exclusion |

Cluster B — the three live 162-49 incidents, formalised:

| AC | Requirement |
|----|-------------|
| B1 | When several approval requirements are unmet, one error names all of them |
| B2 | The Cycle-N requirement names targeted re-verification as an accepted route and asks the reviewer which method was used |
| B3 | A reviewer verdict already routed to rework never earns a second rework round — no double phase-advance. Observable invariant only; mechanism left to Dev |

### Test Files

- `pennyfarthing-dist/src/pf/tests/test_162_47_verdict_parse.py` — A1-A4 and the unit half of A6 (45 tests, 18 RED)
- `pennyfarthing-dist/src/pf/tests/test_162_47_gate_parity.py` — A5, A8, B1, B2 (34 tests, 19 RED)
- `pennyfarthing-dist/src/pf/tests/test_162_47_rework_routing.py` — A7, B3 (60 tests, 40 RED)
- `pennyfarthing-dist/src/pf/tests/test_162_21_resolve_gate_rejected_verdict.py` — **modified**: two pre-existing vacuous assertions de-vacuumed in place (A6). Both still pass; they now discriminate.

Harness note: the three new files import the real-`tdd.yaml` loader and project
scaffolding from the 162-21 file rather than re-declaring them. A second copy of
that harness is the divergence this story exists to remove.

### Fail-for-the-right-reason evidence (measured, not asserted)

Three of the RED failures are confirmed fail-OPENs, not style nits:

1. **A1 archives a rejected story.** A reviewer's real `REJECTED` inside a
   6-backtick wrapper, closed by the inner 3-backtick line, resolves to
   `{status: ready, gate_type: approval, next_agent: sm, next_phase: finish}`.
   The 162-21 Reviewer downgraded this on reachability, arguing it needs the
   reviewer to fence its own verdict — which is precisely what the 4-backtick
   documentation idiom invites, and the probe confirms the consequence.
2. **A8 accepts an unverified rejection.** `complete_phase` with
   `gate_type=approval_rework` and NO `## Subagent Results` section at all
   returns `{status: success}`. The byte-identical approval is refused.
3. **A5 crashes.** Under a `US-ASCII` default encoding, `complete_phase` raises
   `UnicodeDecodeError: 'ascii' codec can't decode byte 0xe2 in position 1291`
   at `complete_phase.py:95` on a session containing an em dash — i.e. on every
   assessment in this repo. The subprocess probe self-skips where the platform
   cannot be forced off UTF-8.

Plus the two headline invariants:

4. **B3 double phase-advance, end to end.** `resolve_gate` → `complete_phase` →
   `resolve_gate` on one rejection: the second resolve returns
   `{status: ready, next_phase: green, gate_type: approval_rework}` and the
   counter reaches 2 on a single verdict.
5. **A7 in every unfixed workflow.** `trivial` returns
   `('approval', 'finish', 'sm')` for `REJECTED` and `APPROVED` alike — the
   162-2 signature. Same for `bdd`, `bdd-team`, `tdd-team`, `2party-tdd`,
   `agent-docs` and `kitchen-sink`. Prose that is not a verdict at all
   (`looks good to me`) also advances to finish in those seven.

Every RED assertion was read back individually; none fails on an import error,
a fixture typo or a message-format coincidence.

### Designed interface Dev must satisfy

Two places where the source review named an outcome but not a shape, so TEA
designed one:

1. **A3 preamble boundary.** The operative counter is the one appearing BEFORE
   the first `## … Assessment` heading. The reader and the writer must both use
   that scope — a reader that narrows while the writer keeps rewriting the last
   match anywhere would freeze the real counter and disarm the freshness guard,
   which is the 162-28 defect. Test:
   `test_the_writer_increments_the_preamble_counter_not_a_later_one`.
2. **B3 rework-staleness signal.** Mechanism is Dev's choice (round-trip counter
   vs verdict staleness vs requiring the cycle-2 verdict). The tests pin only
   the observable contract, in both directions:
   - one exact reviewer section + one recorded round-trip → `blocked`
   - two exact sections + one recorded round-trip → `ready` / `green`
   - two exact sections + two recorded round-trips → `blocked`
   - approvals unaffected at any counter value
   - the block message names the section to add and the word `cycle` or `round`

Everything else is derived from a probed shape and the tests say which.

### Rule coverage

`.pennyfarthing/gates/lang-review/python.md` rule #5 (explicit `encoding=`) is
enforced by an AST sweep over `pf/handoff/*.py`, not by a spot check. SOUL #2
(one truth, one place) is enforced twice — an AST check that no hardcoded
reviewer-heading literal survives in `complete_phase.py`, and a behavioural
check that redirecting the shared formula moves both halves of the exit
protocol. Test-quality self-check: no `let _ =`-equivalents, no `assert True`,
no bare `is_not_none` where a value is available; every assertion carries the
observed result in its message.

**Handoff:** To Dev for implementation.

## Dev Assessment

**Implementation Complete:** Yes

**Tests:** GREEN. Scoped run (the three new files plus the two families they extend — `test_162_47_verdict_parse.py`, `test_162_47_gate_parity.py`, `test_162_47_rework_routing.py`, `test_162_21_resolve_gate_rejected_verdict.py`, `test_162_28_freshness_tag_predicate.py`): 299 passed, 0 failed. Full suite from the orchestrator root, SERIAL, one process: **6314 passed, 4 skipped, 0 failed** in 170s — `test_pypi_packaging.py` included in that count. All 77 of TEA's RED tests now pass; no test in the repo fails.

**Commit:** `32d3797ed` (GPG-signed, verified `G`), pushed to `origin/feat/162-47-verdict-parse-gate-followups`. No PR — SM owns that.

**Lint/format:** `ruff check` clean and `ruff format --check` clean on all nine touched Python files. Seven of them were already format-dirty at HEAD (verified by running the same check against the HEAD blobs under the repo's `line-length = 100`); they were formatted as part of this commit, so the diff carries mechanical reflow noise that predates the story. Logged as a Delivery Finding.

**`pf validate`:** 0 errors from anything this story touched; `pf validate workflow` reports 35 passed / 13 warnings, all pre-existing "unknown gate type" warnings. The 358 errors in the full `pf validate` run are pre-existing orchestrator PRD/ADR schema drift.

### Disposition per AC

| AC | Disposition | Implementation |
|----|-------------|----------------|
| A1 | FIXED | `_mask` keeps the whole delimiter; a closer must satisfy `delim[0] == open_delim[0] and len(delim) >= len(open_delim)`. Both directions covered — a short closer no longer closes a long opener, and a longer closer still closes (the `>=`, not `==`, that the review warned about). |
| A2 | FIXED | `\b` dropped from `select_last_section`'s near-miss pattern. Three pre-existing 162-21 assertions asserted the opposite contract and were flipped — see the Conflict finding and the Design Deviation. |
| A3 | FIXED | New `preamble_end` + `find_operative_round_trip_line` in `gate_recovery`. **One locator, shared:** `read_round_trip_count` reads through it and `complete_phase` rewrites what it returns, so reader and writer cannot drift. Preamble = text before the first `## … Assessment` heading, computed on MASKED text so a fenced heading cannot move the boundary. |
| A4 | FIXED | `SectionSelection`, `VerdictReading`, `RoundTripReading`, `ReworkRecovery` TypedDicts with `Literal` statuses. `resolve_gate` now branches on `status`, asserts the invariant at the caller, and has explicit arms for both an unknown `classify_verdict` value and an unknown `get_rework_recovery` status — neither can reach forward routing. |
| A5 | FIXED | `complete_phase` imports `assessment_heading` at module level and derives the reviewer heading from it in both subgates and every error message; `_APPROVAL_AGENT = "reviewer"` names the subject. `encoding="utf-8"` added to all seven bare `read_text`/`write_text` calls across `complete_phase.py`, `cli.py` and `gate_runner.py` (the AST sweep is now clean for the whole package, including TEA's two extra lines). |
| A6 | FIXED (no Dev work needed) | TEA's de-vacuumed assertions and new unit coverage all pass unchanged. Verified the two repaired tests still discriminate under the new code. |
| A7 | FIXED | Rework recovery blocks added to all **seven** workflows: `trivial` → `implement`, `bdd`/`bdd-team`/`tdd-team`/`2party-tdd`/`kitchen-sink` → `green`, `agent-docs` → `implement`. `max_attempts: 3` throughout, matching `tdd`/`sdd`/`spdd`. |
| A8 | FIXED | New public `is_approval_family(gate_type)` — `"approval"` or `approval_*`. Heading-ambiguity, subagent-completion and specialist-tag checks run for the whole family; `_check_rework_freshness` is still gated on `gate_type == "approval"`, the probed fix's deliberate exclusion. `dev_exit` and friends are untouched. |
| B1 | FIXED (amended in rework round 1) | `_check_approval_requirements` returns a list of complete actionable sentences; `_format_unmet` renders them as one numbered, blank-line-separated error. **The round-1 claim "a satisfied requirement is never named" was false as shipped** — with an ambiguous heading the tag check named all eight tags while all eight were present (review F1). It is true now, and pinned by a regression test. |
| B2 | FIXED | One `_FRESHNESS_ROUTES` constant appended to all three freshness messages: names targeted re-verification as accepted, calls it stronger evidence than a fresh sweep, drops the bare "after re-running all enabled subagents" imperative, and asks the reviewer to state which method it used. `agents/reviewer.md` and `gates/approval.md` reworded to match, so the instruction and the gate cannot drift. |
| B3 | FIXED | Mechanism: exact reviewer sections must OUTNUMBER the recorded round-trips (`count_exact_sections` vs `parse_round_trip_count`), checked after the `max_attempts` ceiling so an exhausted loop still blocks on the ceiling. Approvals bypass it entirely. One AC-A3 fixture collided with this and was adjusted — see the Conflict finding. |

### Exit-path self-check

This story edits the machinery that runs its own exit protocol, so the green→review transition was traced against the new code before running it: `tdd.yaml`'s `green` gate is `dev_exit` with no `recovery:` block, so `has_rework_action` is false and none of A4/B3 is reached; `is_approval_family("dev_exit")` is false, so none of A8/B1 is reached. The A3 writer change is inert on a non-rework gate type. My own exit is unaffected by every guard added here.

### What Reviewer should scrutinise

1. **The two AC-vs-test conflicts.** A2 vs three pre-existing 162-21 assertions, and B3 vs AC-A3's own integration test. Both are recorded as Conflict findings with Design Deviations. I resolved both in the new AC's favour and edited the older assertions; that is the judgment call most worth a second opinion. The A2 case in particular changes behaviour a prior story deliberately pinned.
2. **B3's chosen mechanism.** Ruling-count vs round-trip-count makes `resolve-gate` non-idempotent across a completed rework round. That is the AC, but it is a real behavioural change for anyone who re-runs the gate to inspect it.
3. **A2's blast radius — measured, not assumed.** Swept every `^## … Assessment…` heading in `.session/` and `sprint/archive/`. Live `.session/` has zero suffixed assessment headings. The archive has 59 suffixed reviewer headings, but **every one begins with a space or `(`** — a word boundary — so all of them already blocked under the old `\b` pattern. A2 only widens the rule to suffixes starting with a word character (`Assessment2`, `Assessmentz`), and that form appears nowhere in the repo's history. Net behavioural change on real sessions: none. Worth re-confirming independently, since this was the main risk I weighed when flipping the older assertions.
4. **The reformat noise.** Seven files carry `ruff format` reflow unrelated to the story. The substantive changes are easy to lose in it; `git diff -w` and the per-hunk comments help.
5. **The `assert` in `resolve_gate`.** A5/A4 put a runtime assertion in the production path. It is unreachable while the invariant holds (the `status != "found"` return precedes it) and would vanish under `python -O`, so it documents rather than enforces. The enforcement is the status branch above it.
6. **The zero-enabled-subagents gap** (Delivery Finding): with all toggles off, the completion check still demands the section and says "all 0 enabled subagents". Now reachable on the rework path too. Deliberately not fixed — no AC covers it.

### Rework round 1 — response to the REJECTED verdict

Three blocking items, all accepted without argument; F1 and F3 were both real and both my doing. Everything re-measured first-hand rather than taken on the Reviewer's word — including the two findings I was asked to correct rather than fix.

| Item | Disposition | What changed |
|------|-------------|--------------|
| F1 — aggregation names a SATISFIED requirement | **FIXED** | `_check_subagent_dispatch` no longer returns `required_tags` wholesale for an unidentifiable section. On `ambiguous` it searches the new `gate_recovery.candidate_section_region` — the last exact heading plus the near-miss headings after it, stopping at the first non-candidate `##`. On `absent` it still returns every tag, which is truthful (no section, no tags). |
| F2 — the join corrupts the message | **FIXED** | New `_format_unmet`: a single problem verbatim; several rendered as "N approval requirements are unmet — fix all of them:" plus numbered, blank-line-separated entries. The markdown example table survives intact. |
| F3 — false case-insensitivity doc row | **FIXED (doc only, per SM's scope call)** | The row now describes the two halves of the heading contract disagreeing about case as an **open defect**, states both measured behaviours, and tells agents to write the exact case. TEA's Question is explicitly **left open**, and the "closing TEA's open Question" claim is retracted in the Design Deviations. Parser untouched. |
| F10 — A8 rationale overstates the fixtures | **CORRECTED (rationale only)** | The coverage claim is withdrawn in the Design Deviations, with the measurement that disproves it. |

**Why F1's obvious fix was wrong.** Both remedies the review suggested — "skip the dispatch problem when the selection is not `found`" and "restore the short-circuit for the ambiguous case" — break TEA's `test_all_four_requirements_can_be_reported_in_one_error`, which pins an ambiguous heading being reported *together with* genuinely-missing tags. Measured: suppressing the tag check on ambiguity fails that test plus two of mine. So the fix had to make the tag report TRUTHFUL under ambiguity rather than silent. Searching the candidate sections does that in both directions — a tag present in either candidate is not named, a tag in neither still is.

The region deliberately stops at the first non-candidate heading instead of running to EOF. Reading to EOF would have swapped F1's fail-CLOSED report for a fail-OPEN one, letting a `[SEC]` mention in `## Delivery Findings` vouch for the assessment. That direction has its own regression test.

**Mutation-verified — five mutations, each caught by the intended test:**

| Mutation | Result |
|----------|--------|
| ambiguous branch → `return required_tags` (round-1 behaviour) | `test_an_ambiguous_heading_does_not_report_present_tags_as_missing` fails |
| ambiguous branch → `return set()` (the naive fix) | `test_all_four_requirements_can_be_reported_in_one_error` + 2 of mine fail |
| candidate region runs to EOF | `test_a_tag_outside_the_candidate_sections_does_not_satisfy_the_check` fails |
| `_format_unmet` → space join | `test_the_aggregated_error_keeps_its_entries_legible` fails |
| `is_approval_family` → exact-string (to test F10's claim) | `test_162_47_gate_parity` 13 failed; 143-10 / 162-28 / 162-21 **0** failed across 163 tests |

**F3 re-measured myself**, three probes against the real `tdd.yaml`: a lowercase-only reviewer heading → `blocked` / "No assessment found" (`_ASSESSMENT_RE.flags` confirms no `IGNORECASE`); a correctly-cased REJECTED followed by a lowercase `## reviewer assessment` carrying APPROVED → `ready → finish`, rejection silently superseded; cased-only control → `ready → green`. The report is accurate in both directions, so the doc row resting on it had to go.

**Also cleaned up while in there:** the exact-heading and near-miss regexes were being rebuilt in three places once AC-B3 added `count_exact_sections`. They are now `_exact_heading_re` / `_near_miss_heading_re`, one definition each — the same SOUL #2 argument A5 applies to the heading string. The stale comment F1 called out ("otherwise the tag check reports every tag missing…") is replaced with one describing what the code now does, plus a note on `_check_approval_requirements` that removing the short-circuit made each subcheck responsible for its own truthfulness.

**Tests:** scoped run over the seven affected files 348 passed / 0 failed. **Full suite from the orchestrator root, SERIAL: 6318 passed, 4 skipped, 0 failed** (172s) — 6314 plus the four new regression tests. `ruff check` and `ruff format --check` clean on all three touched Python files.

**Not touched, per SM:** F4–F9 and F11–F13 are SM's to file. F5 (`_PREAMBLE_END_RE` case-sensitivity) is the same inconsistency as F3 and I would expect it to travel with F3's story; F4 (`parse_round_trip_count` discarding `unreadable`, which B3 inherits) is the one I would rank first of the ten.

**Handoff:** To Reviewer for re-review of the three blocking items.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | Confirmed scoped 299/0, ruff clean, `pf validate workflow` 35/13, all 7 YAML recovery targets valid+earlier; flagged Dev's "9 touched Python files" is 11 | Accepted; count corrected in Finding F9 |
| 2 | reviewer-test-analyzer | Yes | findings | (a)(b)(c) flips/fixture edits still discriminate under mutation; (d) A8 NOT verified through the 17 collateral call sites; (e) under-asserted B1 test, "targeted" word-coupling | Accepted; F6, F10, F11 |
| 3 | reviewer-type-design | Yes | findings | `ReworkRecovery(total=False)` docstring overstates static checkability; `or {}` type lie; assert is documentation; `is_approval_family` prefix predicate; `_PREAMBLE_END_RE` case-sensitivity | Accepted; F5, F7, F8 |
| 4 | reviewer-security | Yes | findings | Case-variant heading override (verdict supersession); unreadable-counter → rework farming; encoding gap outside `handoff/` | Partially accepted — override re-verified as PRE-EXISTING, severity re-attributed; F3, F4, F12 |
| 5 | reviewer-rule-checker | Yes | findings | 13/13 python.md rules PASS on production code; 2 pre-existing rule-5 test-file gaps; YAML schema conformant; SC-4 doc-accuracy PASS | Accepted except SC-4 — **Challenged**, see F3 |
| 6 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 8 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |

All received: Yes

Enabled set measured from this repo's `workflow.reviewer_subagents` (5 on, 4 off); required tags are `[TEST] [TYPE] [SEC] [RULE]`. The freshness subgate reports "No rework cycle — initial review", so no cycle tag is required on this transition.

**Challenged:** rule-checker's SC-4 marked the new "heading matching is case-insensitive" doc row ACCURATE. It is accurate about the parser and false end-to-end — measured below (F3). Its verdict was reached by reading `select_last_section`'s flags, not by running a session through the gate.

## Reviewer Assessment

**Verdict:** REJECTED

Three blocking defects, all introduced by this branch's own AC work, all small and local. Everything else measures clean and the substance of the story is good: the five fail-opens TEA established are genuinely closed, and I confirmed each by measurement rather than by reading the diff.

### Measurement summary

Every Dev claim re-run first-hand, from the orchestrator root, serial:

| Claim | Result |
|-------|--------|
| Scoped 299 / 0 | **CONFIRMED** — 326/0 over the six touched test files (299 over Dev's five) |
| Full suite SERIAL 6314 passed / 4 skipped / 0 failed | **CONFIRMED** — `6314 passed, 4 skipped, 37 warnings in 171.68s` |
| ruff check + format clean | **CONFIRMED** — `All checks passed!`, `11 files already formatted` (11 files, not 9) |
| `pf validate workflow` 35 passed / 13 pre-existing warnings | **CONFIRMED** — all 13 are `unknown gate type` on phases this branch did not touch |
| Recovery blocks in all 7 workflow YAMLs | **CONFIRMED** — plus every target verified to exist and be earlier in phase order |

The five fail-opens, each probed directly:

1. **A1 fenced verdict — CLOSED.** A 6-backtick wrapper closed by an inner 3-backtick line no longer exposes its contents; the real `REJECTED` stays operative. Reverting the length check to a type-only comparison fails 3 tests including `test_a_short_closer_cannot_leak_an_approval_past_a_fenced_rejection`. The `>=` direction is right too — a 5-tick closer still closes a 3-tick opener.
2. **A8 unverified rejection — CLOSED.** An `approval_rework` transition with no results section is refused. Proven load-bearing twice: a mutation of `is_approval_family` back to the exact-string check made my own no-table rework probe return `success`, and 5 of 10 tests in `TestRejectionsAreEnforcedLikeApprovals` fail under it.
3. **A5 ASCII crash — CLOSED.** Under `LC_ALL=C` with `locale.getpreferredencoding(False) == 'US-ASCII'`, `complete_phase` returns `success` and an em dash survives the round-trip. `develop` carried 5 bare `read_text`/`write_text` calls in that module.
4. **B3 double phase-advance — CLOSED.** `resolve` → `complete` → `resolve` on one rejection: the second resolve blocks, counter reaches 1 not 2. Removing the rulings-vs-round-trips guard fails 5 tests.
5. **A7 rejection routing — CLOSED in all 10 workflows.** Probed each shipped YAML directly: `REJECTED` → rework to a valid earlier phase, `APPROVED` → forward, and prose that is not a verdict (`looks good to me`) → blocked. The 162-2 signature is gone everywhere.

**B3 collateral (specifically probed, since non-idempotence is the AC):** crash-recovery is safe. Repeated `resolve-gate` before `complete-phase` still reworks (3× identical). A `complete-phase` refused by A8 leaves the counter untouched, so the retry still reworks. A genuine cycle-2 section reworks again. The non-idempotence is confined to exactly the case the AC names.

**A2 blast radius — independently confirmed.** `git grep` across all 400+ refs in *both* repos finds zero `^## …Assessment<word-char>` headings; all 305 suffixed assessment headings in live `.session/` and `sprint/archive/` begin with a space. Dev's claim holds.

### Blocking findings

**F1 — B1's aggregation names a requirement that is SATISFIED, re-opening the 162-21 diagnostic defect.** `[TEST]`
`complete_phase.py:_check_approval_requirements` accumulates unconditionally. When the heading is ambiguous, `_check_subagent_dispatch` returns `required_tags` wholesale (its `selected["status"] != "found"` arm), so the aggregated error reports all eight specialist tags missing *while every one of them is present in the file*. Measured on a session with a full table, all tags, and one straggler heading: the error names the straggler **and** `missing specialist subagent tags: [DOC], [EDGE], [RULE], [SEC], [SILENT], [SIMPLE], [TEST], [TYPE]`.

This is the exact outcome the pre-existing short-circuit prevented, and the comment justifying it is still in the new code verbatim — "otherwise the tag check reports every tag missing when the real problem is a suffixed heading (story 162-21)" — now describing behaviour that no longer exists. It also contradicts Dev's own stated invariant: "Aggregation is additive only — a satisfied requirement is never named."

Direction is fail-closed, so nothing advances unreviewed. It is blocking because it charges a reviewer a wasted cycle chasing tags that are already there — the precise discovery cost B1 exists to remove. Fix: skip the dispatch problem when `select_last_section` did not return `found`, or restore the short-circuit for the ambiguous case.

**F2 — B1's join corrupts the aggregated message.** `[TEST]`
`" ".join(unmet)` fuses multi-line entries. The completion error ends in a two-line markdown example table, so the next requirement is spliced onto the table's last row: `| 1 | reviewer-preflight | Yes | clean | none | N/A | Reviewer Assessment missing specialist subagent tags: …`. With three requirements unmet the result is one unbroken paragraph containing a malformed table row. B1 replaced five legible sequential errors with one less-legible aggregate. Fix: `"\n\n".join(unmet)`, ideally numbered.

**F3 — the new "heading matching is case-insensitive" doc row is false end-to-end, and it sanctions a verdict-supersession fail-open.** `[SEC]` `[RULE]`
`guides/handoff-cli.md` now states: "`## reviewer assessment` satisfies the gate. A deliberate tolerance, not an accident". Two measurements against it:

- **False in one direction.** On a session whose only reviewer heading is lowercase, `resolve_gate` returns `blocked` with *"No assessment found in session file"* — `session_assessment._ASSESSMENT_RE` is case-**sensitive**, so `has_assessment()` fails before the case-insensitive reader is ever consulted. The documented tolerance does not exist on that path.
- **Dangerous in the other.** A lowercase `## reviewer assessment` carrying `APPROVED`, appended after a correctly-cased section carrying `REJECTED`, is selected as the operative section: `resolve_gate` returns `ready → finish`. The rejection is silently superseded, and because the heading is a case variant rather than a suffix, A2's straggler rule does not catch it.

The parser behaviour is **pre-existing** — I ran the identical input against a `develop` worktree and got byte-identical results, so this is not a regression and is not Dev's defect. What this branch adds is documentation blessing it as deliberate, and the closure of TEA's open Question on that basis ("closing TEA's open Question"). The story that exists to close verdict-parse fail-opens should not be the one that ratifies one. Fix: either add `re.IGNORECASE` to `_ASSESSMENT_RE` and `_PREAMBLE_END_RE` so the tolerance is real and coherent, or drop the tolerance and the doc row. Either way TEA's Question stays open and gets its own story.

### Non-blocking findings

**F4 — `parse_round_trip_count` discards the `unreadable` tri-state, so a corrupt counter buys rework rounds.** `[SEC]` `[EDGE]` `read_round_trip_count` distinguishes `unreadable` from `absent` precisely because, in its own words, "'I cannot read the counter' is not 'there was no rework' (story 162-28)". `parse_round_trip_count` returns only `["count"]`, which is `0` for `unreadable`. Measured: replacing `1` with `one` in the counter line makes a completed rework round resolve to `ready → green` again, defeating both B3 and the `max_attempts` ceiling. The ceiling half is pre-existing; B3 is new and inherits the hole. Fix: have `resolve_gate` block on `status == "unreadable"`.

**F5 — `_PREAMBLE_END_RE` is case-sensitive while every sibling heading match is `IGNORECASE`.** `[TYPE]` If the *first* assessment heading in a session is lowercase, `preamble_end` returns `len(content)` and any column-0 counter line in agent prose becomes operative (measured: reads the forged `9` instead of the real `1`). Latent rather than live — in a real session the first heading is SM's, generated from the formula — but it is the same inconsistency as F3 and should be fixed with it.

**F6 — B3 counts headings, not rulings.** `[TEST]` `count_exact_sections` counts heading lines. A reviewer who appends a corrected assessment instead of editing in place has two sections against one round-trip and is handed a free extra rework round. Security's stronger attack (an *empty* duplicate heading) correctly blocks on an absent verdict, so this is a narrow case, but counting sections that contain a verdict line would close it.

**F7 — the bare `assert` in `resolve_gate` vs project rule 6 ("return result objects, don't throw").** `[TYPE]` `[RULE]` I am not dismissing this, per the rule-matching stance — I am downgrading it. The `status != "found"` return above it is the real enforcement and satisfies AC-A4; the assert is unreachable while `read_agent_verdict` upholds its invariant, and vanishes under `python -O`. But an `AssertionError` escaping `resolve_gate` would violate rule 6, so the defensive arm should be a `_stop("error", …)` like the two exhaustiveness arms beside it, which would also make it survive `-O`.

**F8 — `ReworkRecovery(total=False)` does not deliver the checkability its docstring claims.** `[TYPE]` With `total=False`, `status` is optional, so a type checker cannot verify the caller's switch is exhaustive — the guarantee lives in the implementation, not the type. Relatedly `... or {}` presents an empty dict as a `ReworkRecovery`. Behaviour is safe (the unknown-status arm catches it). A two-TypedDict discriminated union would model the divergent payloads properly.

**F9 — the approval subgates are reviewer-specific but keyed on gate TYPE, not on the phase's agent.** `[EDGE]` `agent-docs`' `review` phase is owned by `tech-writer` and `kitchen-sink`'s `accept` phase by `pm`; both carry `type: approval`, so both demand a `## Reviewer Assessment` section and nine reviewer subagents that those agents never dispatch. **Not a regression** — I ran `agent-docs` against a `develop` worktree and it was already blocked on both verdicts; this branch strictly improves its routing (`REJECTED` → `implement` instead of `finish`). This is the escape TEA predicted in its A7 deviation, now demonstrated twice, and it shows the discriminator should be the phase's agent rather than its name. Worth its own story.

**F10 — Dev's A8 rationale overstates what the collateral fixtures do.** `[TEST]` The deviation claims making them compliant "keeps the new enforcement live through 17 existing call sites". Under an `is_approval_family` mutation those three files show **zero** failures — the tables keep those tests from failing, they do not verify A8. The enforcement is genuinely tested, but only in `test_162_47_gate_parity.py`. The decision was still the right one; the justification needs correcting.

**F11 — two test-quality gaps.** `[TEST]` `test_a_missing_table_and_missing_tags_are_reported_together` passes `SOME_TAGS` (missing `[SILENT]`, `[SEC]`, `[SIMPLE]`) but asserts only `[SEC]`, so a first-tag-wins implementation would satisfy it. The B2 tests couple to the literal word `targeted`, which breaks on a synonym-level rewording.

**F12 — the encoding sweep stops at `pf/handoff/*.py`.** `[SEC]` `[RULE]` Session files are read without `encoding=` in `patch_mode.py:386,407`, `gates/spec_check.py:60`, `peloton/workflow_driver.py:215,217`, `findings/aggregate.py:177,255`, `findings/capture.py:134`, `findings/pr_body.py:33`, `bmad/sync.py:332,393`. Same rule #5, same trust boundary. Out of scope by TEA's AC and correctly so; I did not verify security's package-wide count of 415.

**F13 — friction from the new gate shape, as first consumer.** `[SIMPLE]` B1 helps only after you have already failed once; the requirement set is still discoverable only by tripping it. I measured mine up front by calling `_get_enabled_subagents` and `_check_rework_freshness` directly, which an agent should not have to do. A `pf handoff requirements <story> <gate-type>` dry-run would remove the residual cost B1 halves. B2 and A8 did not bind on this transition (approval gate, no rework cycle), so their wording changes are untested by my own exit.

### Rule compliance

`.pennyfarthing/gates/lang-review/python.md`, verified against the diff:

| # | Rule | Verdict |
|---|------|---------|
| 1 | No silent exception swallowing | PASS — no new bare excepts |
| 2 | No mutable default arguments | PASS — `masker=` defaults are function refs |
| 3 | Type annotations at public boundaries | PASS — 4 new TypedDicts, all new functions annotated (see F8 on their strength) |
| 4 | Logging coverage | N/A — no logging in scope |
| 5 | Explicit `encoding=` on text I/O | PASS in all production files; 31 pre-existing gaps remain in two touched *test* files, and package-wide gaps remain (F12) |
| 6 | Test quality | PASS with two gaps (F11) |
| 7 | No resource leaks | PASS — `mkstemp` fd closed, temp unlinked on failure |
| 8 | No unsafe deserialization | PASS — `yaml.safe_load` throughout |
| 9 | Async pitfalls | N/A |
| 10 | Import hygiene | PASS — module-level, no cycles |
| 11 | Input validation at boundaries | N/A — internal library modules |
| 12 | Dependency hygiene | N/A — no manifest changes |
| 13 | No fix-introduced regressions | **FAIL** — F1 regresses the 162-21 diagnostic behaviour |

Project rules: 1/3/4/9 PASS (all changes under `pennyfarthing-dist/`, nothing under `.pennyfarthing/` or `node_modules/`); 2 PASS (no sprint YAML); 6 PASS with F7 noted; 5/7/8/10 N/A. Framework rules PASS — Python only, no script duplication. SOUL #2 PASS: an AST sweep confirms no bare `Reviewer Assessment` literal survives in `complete_phase.py`, and the heading is derived from `assessment_heading()`; note the *agent* is still the literal `_APPROVAL_AGENT = "reviewer"` even though `complete_phase` already computes `from_agent` three lines earlier, which is what F9 turns on. Both commits GPG-verified (`G`).

### Deviation audit

TEA (8) — **all accepted.** B1-as-behaviour and B2-as-wording are both well-argued and I would have chosen the same; A7 option 1 is forced (option 2 yields no `target_phase`, and I confirmed a missing target returns `error` rather than falling through); A5's widening to `pf/handoff/*.py` is right, though the boundary is arbitrary (F12); A6 repair-in-place is correct — leaving weak siblings would be false coverage; A3's preamble definition and A4's dual test are both mutation-verified load-bearing. One note on A7's scoping-to-phases-named-`review`: TEA flagged that a reviewer-verdict gate on a differently-named phase would escape, and F9 shows the inverse escape is already live.

Dev (7) — **six accepted, one partially rejected.**
1. **Three 162-21 assertions flipped — ACCEPT.** The contracts are genuinely mutually unsatisfiable, story scope outranks a prior story's test, and the fail-open/fail-closed direction argument is correct. Verified the flipped tests still discriminate: restoring the `\b` fails 21 tests, and the modified tests fail under a `has_rework_action` mutation, so they still catch the 162-21 stale-verdict fail-open rather than having been hollowed out.
2. **`test_one_below_max_attempts_still_reworks` fixture — ACCEPT.** Ceiling still pinned from both sides under an off-by-one mutation.
3. **A3 forged-counter fixture given a second section — ACCEPT.** Still discriminates the reader defect: 4 A3 tests fail under a preamble-scoping mutation, and the added section is what isolates the ceiling from the staleness guard.
4. **A8 collateral made compliant — ACCEPT the decision, REJECT the rationale.** Compliant fixtures are the truthful ones; but see F10.
5. **B2 wording only, no new field — ACCEPT.**
6. **B3 ruling-count mechanism — ACCEPT** with F4 and F6 as follow-ups.
7. **Documentation beyond the ACs — PARTIALLY REJECT.** Six of the seven added claims I verified as accurate. The case-insensitivity row is the exception (F3), and TEA's Question should not be recorded as closed.

Pre-existing failures excluded from attribution: the 9 workflow-discovery failures that appear only from non-root cwds (162-54) — my full-suite run from the orchestrator root had 0 failures. The `origin/develop` prunable worktree inside the repo is a local artifact, not from this branch.

### To clear the rejection

F1 and F2 are edits to `_check_approval_requirements` and its caller. F3 is a decision plus a doc edit (and, if the tolerance is kept, `re.IGNORECASE` on two patterns). Add regression tests for F1 (an ambiguous heading must not report present tags as missing) and F2 (entries separated, table intact). F4–F13 are follow-up stories; F3's underlying parser behaviour and F9 both deserve their own, since they are pre-existing fail-opens of the same family this epic is working through.

**Handoff:** To SM — rejected, returning to Dev for the three blocking items.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): the source review counted **six** workflows carrying the 162-2 defect; discovery over the shipped workflow files finds **seven**. `workflows/kitchen-sink/workflow.yaml` declares a reviewer `review` phase with `type: approval` and no recovery block, and it fails all four A7 routing probes exactly like the named six. It was missed because the review enumerated only top-level `*.yaml` and kitchen-sink is a directory workflow. Affects `pennyfarthing-dist/workflows/kitchen-sink/workflow.yaml` (in scope for A7 as written — the tests discover rather than hardcode, so a workflow added later cannot reintroduce this unnoticed). *Found by TEA during test design.*
- **Improvement** (non-blocking): `2party-tdd`'s `review` phase advances into its own rework chain unconditionally — the linear next phase is `review-fix-tea`, so an APPROVED review walks the fix loop just as a rejection does. That is the mirror of the 162-2 defect (verdict ignored, forward direction) and A7 does not close it: adding a rework recovery block makes the rejection path explicit but leaves approval routed into `review-fix-tea`. Needs either an `next:` on the review phase or a restructure. Kept out of A7's ACs as a distinct defect rather than folded in. Affects `pennyfarthing-dist/workflows/2party-tdd.yaml`. *Found by TEA during test design.*
- **Gap** (non-blocking): two more `read_text()` calls in the same package omit `encoding=` — `handoff/cli.py:325` and `handoff/gate_runner.py:76`. Same python.md rule #5, same module family, two lines. A5's AST sweep covers `pf/handoff/*.py` rather than `complete_phase.py` alone so they land with it; recorded because the source review named only `complete_phase`. Affects `pennyfarthing-dist/src/pf/handoff/cli.py` and `gate_runner.py`. *Found by TEA during test design.*
- **Improvement** (non-blocking): `select_last_section`'s docstring lists its `Args` out of signature order — `masker` (the third parameter) is documented before `content` and `heading`. Cosmetic, but this is the single selection rule every reader of a session file goes through, so its docstring is load-bearing documentation. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py`. *Found by TEA during test design.*
- **Question** (non-blocking): `read_agent_verdict` and `select_last_section` match the section heading case-INSENSITIVELY, which no test pinned and no guide states. TEA pinned the current behaviour rather than changing it (`test_heading_matching_is_case_insensitive`), but it is worth a deliberate decision: `## reviewer assessment` satisfying the gate is either a helpful tolerance or a second spelling of a contract that is supposed to have exactly one. Affects `pennyfarthing-dist/guides/handoff-cli.md` (undocumented either way). *Found by TEA during test design.*

### Dev (implementation)
- **Conflict** (non-blocking, RESOLVED in this phase): AC-A2 and two pre-existing 162-21 tests were mutually unsatisfiable. A2's probed shape makes any heading STARTING with the phrase a straggler (parametrised over suffixes `2 x _cycle2 5final II`); `test_heading_matching_does_not_swallow_a_different_section` and two params of `test_a_genuinely_different_heading_is_simply_not_a_candidate` asserted the opposite for `Assessmentz` and `Assessments`. Since `x`/`II` and `z`/`s` are the same character class, no predicate satisfies both. Resolved in A2's favour and the older assertions flipped — see the Design Deviation. Affects `pennyfarthing-dist/src/pf/tests/test_162_21_resolve_gate_rejected_verdict.py`. *Found by Dev while implementing A2.*
- **Conflict** (non-blocking, RESOLVED in this phase): AC-B3 and AC-A3's own integration test were mutually unsatisfiable as written. `test_a_forged_high_counter_cannot_wedge_the_rework_loop` asserted `ready` for one reviewer section against one recorded round-trip; B3's pinned contract asserts `blocked` for exactly that shape. Any mechanism meeting B3's four-way contract blocks it. The A3 fixture was given a second exact section, which preserves what it discriminates (a prose `9` read as operative would still trip the ceiling). Affects `pennyfarthing-dist/src/pf/tests/test_162_47_verdict_parse.py`. *Found by Dev while implementing B3.*
- **Gap** (non-blocking): AC-A8's blast radius reached three test files TEA did not adjust — `test_143_10_reviewer_dev_roundtrip.py` (11 `approval_rework` call sites) and `test_162_28_freshness_tag_predicate.py` (3), whose sessions carry no `## Subagent Results` table, plus 3 in `test_162_21`. TEA anticipated this for its own files via the `no_subagents_required` fixture. All were fixed by making the fixtures compliant rather than by disabling the toggles, so the new enforcement stays live through them — see the Design Deviation. *Found by Dev while implementing A8.*
- **Gap** (non-blocking): with every reviewer subagent toggled OFF, `_check_subagent_completion` still demands the `## Subagent Results` section and emits "wait for all **0** enabled subagents to return" — a requirement with no content and a nonsensical message. Not touched here (no AC covers it, and relaxing it would weaken enforcement in the common case), but under A8 this now fires on the rework path too, so more sessions will meet it. A guard that skips the section requirement when `enabled_names` is empty would be the fix. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py`. *Found by Dev while adjusting 162-28's fixtures.*
- **Improvement** (non-blocking): seven of the nine Python files this story touched were already `ruff format`-dirty at HEAD (`complete_phase.py`, `gate_recovery.py`, `gate_runner.py`, `resolve_gate.py`, and the 143-10/162-21/162-28 test files) under the repo's `line-length = 100`. They were formatted as part of this commit, which adds mechanical reflow noise to the diff. Nothing enforces `ruff format` in CI or in a gate — the `lang-review/python.md` rules are agent-read. A pre-commit hook or a dev-exit check would stop the drift accumulating. *Found by Dev while satisfying the format requirement.*

### Reviewer (review)
- **Gap** (non-blocking): the approval subgates in `complete_phase` are reviewer-specific but keyed on the gate TYPE rather than the phase's agent, so `agent-docs`' `review` phase (agent `tech-writer`) and `kitchen-sink`'s `accept` phase (agent `pm`) demand a `## Reviewer Assessment` section and nine reviewer subagents they never dispatch. Measured identical on a `develop` worktree, so PRE-EXISTING and not attributable to this story — which in fact improves `agent-docs`' routing. `complete_phase` already computes `from_agent`; using it in place of `_APPROVAL_AGENT` plus skipping the subagent checks for non-reviewer agents is the shape. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py`. *Found by Reviewer while probing A7 across all 10 shipped workflows.*
- **Gap** (non-blocking): a case-variant reviewer heading silently supersedes an operative verdict — a lowercase `## reviewer assessment` carrying an approval, appended after a correctly-cased rejection, resolves to `ready → finish`. Conversely a session whose ONLY reviewer heading is lowercase blocks with "No assessment found", because `session_assessment._ASSESSMENT_RE` is case-sensitive while `select_last_section` is not. Verified byte-identical on `develop`, so PRE-EXISTING; this story's documentation of the tolerance is what makes it in-scope (see Reviewer Assessment F3). Affects `pennyfarthing-dist/src/pf/handoff/session_assessment.py` and `gate_recovery.py`. *Found by Reviewer, from a reviewer-security lead, re-verified against a develop worktree.*
- **Gap** (non-blocking): `parse_round_trip_count` collapses the `unreadable` tri-state to `0`, so a counter line whose value does not parse defeats both AC-B3's freshness guard and the pre-existing `max_attempts` ceiling — measured: a completed rework round resolves to `ready → green` again after the counter value is corrupted. The tri-state exists specifically to prevent this conflation (story 162-28). Affects `pennyfarthing-dist/src/pf/handoff/resolve_gate.py`. *Found by Reviewer while probing B3 collateral.*
- **Improvement** (non-blocking): the approval gate's requirement set is still discoverable only by tripping it — AC-B1 reduces five sequential failures to one, but not to zero. A `pf handoff requirements <story> <gate-type>` dry-run that lists the requirements and which ones the current session already meets would remove the remainder. As first consumer of the new shape I resorted to calling `_get_enabled_subagents` and `_check_rework_freshness` directly to size my own exit. Affects `pennyfarthing-dist/src/pf/handoff/cli.py`. *Found by Reviewer while preparing its own exit.*
- **Question** (non-blocking): nothing enforces `ruff format` in CI or in a gate, which is why seven files arrived at this story already format-dirty and the diff carries unrelated reflow. Dev raised it as an Improvement; recording the decision question — a `dev_exit` gate check or a pre-commit hook — so it is not lost with the story. Affects `pennyfarthing-dist/gates/`. *Found by Reviewer while reading the diff.*

## Impact Summary

**Upstream Effects:** 2 findings (1 Gap, 0 Conflict, 1 Question, 0 Improvement)
**Blocking:** None

- **Gap:** the source review counted **six** workflows carrying the 162-2 defect; discovery over the shipped workflow files finds **seven**. `workflows/kitchen-sink/workflow.yaml` declares a reviewer `review` phase with `type: approval` and no recovery block, and it fails all four A7 routing probes exactly like the named six. It was missed because the review enumerated only top-level `*.yaml` and kitchen-sink is a directory workflow. Affects `pennyfarthing-dist/workflows/kitchen-sink/workflow.yaml`.
- **Question:** `read_agent_verdict` and `select_last_section` match the section heading case-INSENSITIVELY, which no test pinned and no guide states. TEA pinned the current behaviour rather than changing it (`test_heading_matching_is_case_insensitive`), but it is worth a deliberate decision: `## reviewer assessment` satisfying the gate is either a helpful tolerance or a second spelling of a contract that is supposed to have exactly one. Affects `pennyfarthing-dist/guides/handoff-cli.md`.

### Downstream Effects

Cross-module impact: 2 findings across 2 modules

- **`pennyfarthing-dist/guides`** — 1 finding
- **`pennyfarthing-dist/workflows/kitchen-sink`** — 1 finding

### Deviation Justifications

6 deviations

- **Three pre-existing 162-21 assertions flipped to A2's contract.**
  - Rationale: the two contracts are mutually exclusive, not merely different in emphasis — `x` and `II` (must block) sit in the same character class as `z` and `s` (must not), so no predicate satisfies both. Story scope outranks a prior story's test (spec-authority hierarchy), and the direction matters: the `\b` hole is fail-OPEN (a newer cycle invisible to both patterns, so a stale verdict governs), while over-broad straggler detection is fail-CLOSED (a blocked gate naming the offending heading).
  - Severity: major
  - Forward impact: any session with an oddly-named heading that starts with an assessment heading now blocks where it previously resolved. Agents are told to repeat the exact heading, so this should only surface on malformed sessions.
- **`test_one_below_max_attempts_still_reworks` given two extra reviewer sections.**
  - Rationale: at one ruling the case measures B3's staleness guard, not the ceiling it was written for. Its subject (2 < `max_attempts` 3 must not block) is unchanged; only the fixture's freshness is.
  - Severity: minor
  - Forward impact: none — the ceiling boundary is still pinned from both sides by the adjacent tests.
- **AC-A3's `test_a_forged_high_counter_cannot_wedge_the_rework_loop` given a second reviewer section.**
  - Rationale: the two ACs collide at this fixture; A3's subject is the READER (a prose `9` must not become operative) and it still discriminates — with the forged value read, `max_attempts: 3` blocks on the ceiling; with preamble scoping it does not. Three unit tests in the same class cover the reader directly, so no coverage is lost.
  - Severity: minor
  - Forward impact: none.
- **A8's collateral fixtures made COMPLIANT rather than exempted.**
  - Rationale: a real `approval_rework` handoff carries both, so the compliant fixture is the truthful one; toggling the settings off would have made those paths assert nothing about the session shape at all. All nine rows are present so the outcome does not depend on the local `workflow.reviewer_subagents` settings, which are partially disabled in this repo.
  - Severity: minor
  - Forward impact: any new test reusing these harnesses inherits a compliant reviewer handoff.
- **B2 implemented as the message rewording only; no new session field.**
  - Rationale: a new required field invalidates every currently-compliant session for a defect whose harm is wording. The disclosure is requested in the instruction, where the pressure actually lands.
  - Severity: minor
  - Forward impact: none.
- **B3 mechanism chosen: ruling count vs round-trip count.**
  - Rationale: it reuses the section-identity rule the whole module already selects by, needs no new session field, and holds symmetrically in both directions of the contract. Verdict-staleness by position would have needed a second notion of "current", which is the duplication this story removes.
  - Severity: minor
  - Forward impact: `resolve-gate` is no longer idempotent across a completed rework round — re-running it mid-rework blocks instead of re-routing. That is the AC, and it is what the block message explains.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **B1 pinned as behaviour, not documentation.** The AC offered "report all unmet requirements at once **or** document the full set in the gates guide". Tests pin only the behavioural half. Reason: the discovery cost the 162-49 run paid was borne by an agent reading an error message, not a guide — documentation does not reduce it, and a guide listing the five requirements is a second copy of the contract free to drift from the code (the failure class this whole story is cleaning up).
- **B2 pinned as message wording plus a "which method" prompt, not a new required field.** The AC offered "reword the requirement **or** add a re-run-vs-targeted-verification disclosure field". A new required field would invalidate every currently-compliant session and every fixture in the 162-28 family, for a defect whose harm is a wording that invites false attestation. The assertions (`targeted` named; the bare "after re-running all enabled subagents" imperative gone; the reviewer asked to state which method it used) hold under EITHER probed shape, so Dev may still add the field if it prefers.
- **A7 pinned to probed option 1 (declare a recovery block per gate), not option 2.** The review offered "or make an approval gate's verdict authoritative regardless of recovery". Option 2 alone yields no `target_phase`, so the rework branch has nowhere to route and `resolve_gate` returns `error` — it cannot satisfy the routing AC by itself. `tdd`, `sdd` and `spdd` already use option 1, so option 1 is also the consistent shape. The Python-layer tests are still mechanism-free (they assert routing outcomes); only the YAML-layer tests require the declaration.
- **A7 discovery scoped to approval-gated phases NAMED `review`.** `2party-tdd` puts `type: approval` on six further SM/Dev phases that are human sign-off checkpoints with no agent assessment to read; demanding a rework recovery there would be meaningless. There is no structural discriminator in the YAML (all fifteen use `gate: {type: approval, file: gates/approval}`), so the phase name is the discriminator. Recorded because it means a future reviewer-verdict approval gate on a differently-named phase would escape these tests.
- **A5's encoding AC widened from `complete_phase.py` to `pf/handoff/*.py`.** The review named `complete_phase` only. The AST sweep covers the package because it is the same rule, the same module family and two extra lines; see the Delivery Finding.
- **A6 repaired in place rather than duplicated.** `test_backtick_fence_not_closed_by_tilde_line` and `test_at_max_attempts_does_not_advance_to_finish` were edited inside `test_162_21_resolve_gate_rejected_verdict.py`, with the reason recorded in each docstring. Adding stronger siblings would have left the weak assertions in the suite as false coverage.
- **A3's "preamble" defined by TEA.** The review said "scope the search to the preamble" without saying where it ends. Pinned as the text before the first `## … Assessment` heading, and pinned symmetrically on the writer. See the designed-interface section of the TEA Assessment.
- **A4's tri-state invariant tested at the caller as well as in the type.** The review's minimum was "add the assertion to the caller"; the maximum was a `TypedDict` with `Literal` statuses. Both are pinned — the type by an annotation check, the enforcement by two monkeypatched readings (`ambiguous` and `absent`, each carrying a verdict word) that must block rather than route. The annotation check alone would have been satisfiable without closing the mis-route.

### Dev (implementation)
- **Three pre-existing 162-21 assertions flipped to A2's contract.**
  - Spec source: TEA Assessment AC-A2 ("A heading that merely STARTS with the exact text is a straggler, whatever follows"), pinned by `test_a_suffix_starting_with_a_word_character_is_a_straggler[2|x|_cycle2|5final|II]`
  - Spec text: probed shape — "drop the `\b` from the near-miss pattern"
  - Implementation: dropped the `\b`, then rewrote `test_heading_matching_does_not_swallow_a_different_section` as `test_an_extended_word_heading_after_the_last_exact_one_blocks` (now asserting `blocked` for `Assessments` and `Assessmentz`) and narrowed `test_a_genuinely_different_heading_is_simply_not_a_candidate` to headings that do not start with the phrase (`## Dev Assessment`, `## Reviewer Summary`, `## Assessments`). Both files carry the reasoning in their docstrings.
  - Rationale: the two contracts are mutually exclusive, not merely different in emphasis — `x` and `II` (must block) sit in the same character class as `z` and `s` (must not), so no predicate satisfies both. Story scope outranks a prior story's test (spec-authority hierarchy), and the direction matters: the `\b` hole is fail-OPEN (a newer cycle invisible to both patterns, so a stale verdict governs), while over-broad straggler detection is fail-CLOSED (a blocked gate naming the offending heading).
  - Severity: major
  - Forward impact: any session with an oddly-named heading that starts with an assessment heading now blocks where it previously resolved. Agents are told to repeat the exact heading, so this should only surface on malformed sessions.
- **`test_one_below_max_attempts_still_reworks` given two extra reviewer sections.**
  - Spec source: TEA Assessment AC-B3, designed-interface item 2 ("two exact sections + two recorded round-trips → blocked")
  - Spec text: "a reviewer verdict that has already been routed to rework must never be handed a second rework round"
  - Implementation: the fixture now carries three rulings against `round_trip_count=2` instead of one.
  - Rationale: at one ruling the case measures B3's staleness guard, not the ceiling it was written for. Its subject (2 < `max_attempts` 3 must not block) is unchanged; only the fixture's freshness is.
  - Severity: minor
  - Forward impact: none — the ceiling boundary is still pinned from both sides by the adjacent tests.
- **AC-A3's `test_a_forged_high_counter_cannot_wedge_the_rework_loop` given a second reviewer section.**
  - Spec source: TEA Assessment AC-B3 vs AC-A3 (both in this story)
  - Spec text: A3's assertion was `status == "ready"` at one section / one round-trip; B3 pins `blocked` for that shape
  - Implementation: the reviewer body now opens a second exact `## Reviewer Assessment` section.
  - Rationale: the two ACs collide at this fixture; A3's subject is the READER (a prose `9` must not become operative) and it still discriminates — with the forged value read, `max_attempts: 3` blocks on the ceiling; with preamble scoping it does not. Three unit tests in the same class cover the reader directly, so no coverage is lost.
  - Severity: minor
  - Forward impact: none.
- **A8's collateral fixtures made COMPLIANT rather than exempted.**
  - Spec source: TEA Assessment AC-A8; TEA's own `no_subagents_required` fixture as precedent
  - Spec text: "run the subagent-completion and specialist-tag checks on any transition out of a phase whose gate is `approval`-family"
  - Implementation: `test_162_21`'s `_SESSION_TEMPLATE`, `test_143_10`'s `_make_session` and `test_162_28`'s `_write_rework` gained a full nine-row Subagent Results table (and, where missing, the `[RULE]` tag) instead of patching the reviewer-subagent toggles off.
  - Rationale: a real `approval_rework` handoff carries both, so the compliant fixture is the truthful one; toggling the settings off would have made those paths assert nothing about the session shape at all. All nine rows are present so the outcome does not depend on the local `workflow.reviewer_subagents` settings, which are partially disabled in this repo.
  - Severity: minor
  - Forward impact: any new test reusing these harnesses inherits a compliant reviewer handoff.
  - **CORRECTED (rework round 1, review finding F10).** The original rationale claimed this "keeps the new enforcement live through 17 existing call sites". That is measurably false and I have re-measured it myself: under an `is_approval_family` mutation back to the exact-string check, `test_143_10` (27), `test_162_28` (49) and `test_162_21` (87) show **zero** failures, while `test_162_47_gate_parity` shows 13. The compliant tables keep those 163 tests from failing for a reason unrelated to their subject; they do not verify A8. A8's enforcement is verified solely in `test_162_47_gate_parity.py`. The decision stands on the truthfulness argument alone — which is the argument that actually carried it — and the coverage claim is withdrawn.
- **B2 implemented as the message rewording only; no new session field.**
  - Spec source: TEA Design Deviation on B2 ("Dev may still add the field if it prefers")
  - Spec text: "reword the requirement **or** add a re-run-vs-targeted-verification disclosure field"
  - Implementation: one shared `_FRESHNESS_ROUTES` constant appended to all three freshness messages; `agents/reviewer.md` and `gates/approval.md` updated to match. No new required field.
  - Rationale: a new required field invalidates every currently-compliant session for a defect whose harm is wording. The disclosure is requested in the instruction, where the pressure actually lands.
  - Severity: minor
  - Forward impact: none.
- **B3 mechanism chosen: ruling count vs round-trip count.**
  - Spec source: TEA Assessment AC-B3 ("mechanism left to Dev")
  - Spec text: the four-way observable contract on sections vs recorded round-trips
  - Implementation: `resolve_gate` blocks the rework branch when `count_exact_sections(session, heading) <= parse_round_trip_count(session)`, after the `max_attempts` ceiling so an exhausted loop still reports the ceiling.
  - Rationale: it reuses the section-identity rule the whole module already selects by, needs no new session field, and holds symmetrically in both directions of the contract. Verdict-staleness by position would have needed a second notion of "current", which is the duplication this story removes.
  - Severity: minor
  - Forward impact: `resolve-gate` is no longer idempotent across a completed rework round — re-running it mid-rework blocks instead of re-routing. That is the AC, and it is what the block message explains.
- **Documentation updated beyond the ACs.** `gates/approval.md`, `agents/reviewer.md` and `guides/handoff-cli.md` now state the approval-family scope (A8), the fresh-verdict rule (B3), the CommonMark fence rule (A1), the prefix-match straggler rule (A2), the preamble counter scope (A3) and the targeted-re-verification route (B2). TEA's B1 deviation argued against documentation *as a substitute* for behaviour; these are additions alongside the behaviour, aimed at the same discovery cost the story exists to remove. No test requires them.
  - **CORRECTED (rework round 1, review finding F3).** The original version of this entry also claimed the guide "records heading case-insensitivity as a deliberate tolerance, closing TEA's open Question". Both halves were wrong. I re-measured the parser myself: a session whose only reviewer heading is lowercase returns `blocked` / "No assessment found" (`_ASSESSMENT_RE` is case-SENSITIVE, so the precondition fails before the case-insensitive reader runs), while a lowercase `## reviewer assessment` carrying APPROVED appended after a correctly-cased REJECTED returns `ready → finish` — the rejection silently superseded, and A2's straggler rule cannot catch a case variant because the heading is not a prefix extension. So the documented tolerance did not exist in one direction and was a fail-open in the other. The doc row now describes the disagreement as an open defect and tells agents to write the exact case; **TEA's Question is NOT closed** and is left open for its own story. The parser is deliberately not changed here (SM's scope call). Confirmed pre-existing, not introduced by this branch.
## Subagent Results

**Cycle: 1**

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | Cycle-1 results carried forward; re-verified by targeted probe — full suite 6318/4/0 serial, scoped 330/0, ruff clean on all 3 touched files, commit `03486f5c5` GPG `G` | Accepted |
| 2 | reviewer-test-analyzer | Yes | clean | Cycle-1 findings carried forward; re-verified by targeted probe — all 4 new cycle-2 tests mutation-checked, each caught by exactly one intended test | Accepted |
| 3 | reviewer-type-design | Yes | clean | Cycle-1 findings carried forward (F5/F7/F8 unchanged, routed as follow-ups); the one new public helper re-verified by targeted probe over 8 boundary cases | Accepted |
| 4 | reviewer-security | Yes | clean | Cycle-1 findings carried forward; re-verified the fail-OPEN direction of the new helper by targeted probe — region stops before the first non-candidate heading, fenced tags stay masked | Accepted |
| 5 | reviewer-rule-checker | Yes | clean | Cycle-1 findings carried forward; re-verified rule 5 and rule 13 against the cycle-2 diff by targeted probe — rule 13 now PASSES | Accepted |
| 6 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 8 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |

All received: Yes

**Method disclosure (AC-B2):** targeted re-verification, not a fresh generalist sweep. The cycle-2 diff is 4 files and 209 lines against a finding set I characterised myself one round ago, so I re-probed each recorded finding directly rather than re-dispatching five specialists over the same ground: I re-ran the full suite and the scoped suite, mutation-tested all four cycle-2 changes plus the consolidated regexes, probed the new helper over eight boundary cases including its fail-open direction, empirically tested both of my own rejected fix proposals, and re-ran my cycle-1 A1/A2 probes to confirm the regex consolidation changed no behaviour. Every claim below is a first-hand measurement from this cycle. This is the route AC-B2 added and I am its first consumer; the disclosure is the point.

## Reviewer Assessment

**Verdict:** APPROVED

All three blocking findings are fixed and I verified each by measurement. The fix for F1 is better than either remedy I proposed, and Dev was right that both of mine were wrong — I confirmed that empirically rather than taking it on trust.

**Specialist attribution, cycle 2** — carried forward from cycle 1 and re-verified by targeted probe (see the method disclosure above), plus the new cycle-2 observations:
- `[TEST]` — the four new regression tests, all mutation-checked and each caught by exactly one intended test; F17 (a test now pinning behaviour the guide calls an open defect); F11 from cycle 1 still open.
- `[TYPE]` — F15 (the new helper is public but carries a precondition nothing enforces); F16 (`_ANY_SECTION_HEADING_RE` matches only `##`); F5/F7/F8 from cycle 1 unchanged and routed.
- `[SEC]` — re-probed the fail-OPEN direction of `candidate_section_region`: the region stops at the first non-candidate `##`, fenced tags stay masked, and on `ambiguous` the gate always errors regardless, so the helper cannot create a fail-open in its only call site. F3's underlying parser defect and F4 remain, both routed.
- `[RULE]` — python.md rule 13 flips FAIL to PASS with F1 repaired; rule 5 unchanged; the exact/near-miss regex consolidation strengthens SOUL #2; F14 (the aggregate counting one problem twice).

### Cycle-2 verification

| Claim | Result |
|-------|--------|
| Full suite SERIAL from root 6318 / 4 skipped / 0 failed | **CONFIRMED** — `6318 passed, 4 skipped, 36 warnings in 178.20s` |
| Scoped 348 / 0 | **CONFIRMED** — 330/0 over the six touched files (Dev's 348 spans a wider set; no failures either way) |
| ruff check + format clean on 3 touched files | **CONFIRMED** — `All checks passed!`, `3 files already formatted` |
| `03486f5c5` GPG-signed | **CONFIRMED** — verified `G` |

**F1 — FIXED, and the fix is sound.** With an ambiguous heading and all eight tags present, the error now names only the ambiguity; the tag requirement is no longer falsely reported. With tags genuinely absent it names exactly the three missing from `SOME_TAGS` (`[SEC]`, `[SILENT]`, `[SIMPLE]`). Truthful in both directions.

**Dev's claim that both my proposals were wrong — VERIFIED, and I was wrong.** I implemented each and ran the suite. My "skip dispatch when selection isn't found" → 3 failures; my "restore the short-circuit" → 4 failures. Both break `test_all_four_requirements_can_be_reported_in_one_error`, which pins an ambiguous heading being reported *together* with genuinely-missing tags — I had read that test as compatible with suppression and it is not. `candidate_section_region` keeps the aggregate complete *and* makes it truthful, which neither of my suggestions did. Correct call.

**The new public helper — probed over 8 boundary cases, all correct.** A tag only in `## Delivery Findings` does not satisfy the check (the region stops at the first non-candidate `##`); a tag only inside a code fence stays masked; `###` subsections correctly do not terminate the region; multiple consecutive stragglers are all included; an absent exact heading returns `""` so every tag is reported; a straggler *above* the last exact heading yields `found` rather than `ambiguous`, so the region is not consulted. I also confirmed `select_last_section`'s `found` branch returns masked text, so the two branches of `_check_subagent_dispatch` are consistent with each other.

**One structural point that lowers the risk of this helper materially:** on `ambiguous`, `_check_approval_requirements` always appends the ambiguity problem, so `unmet` is never empty and the gate always errors. The candidate search therefore affects only the *message*, never the outcome — it cannot create a fail-open in its only call site. Measured, not assumed.

**Mutation-checked, each caught by exactly one intended test** — matching Dev's own probe results:

| Mutation | Result |
|----------|--------|
| Region runs to EOF (the fail-OPEN direction) | 1 failed — `test_a_tag_outside_the_candidate_sections_does_not_satisfy_the_check` |
| Region returns `""` (revert to declaring every tag missing) | 1 failed — `test_an_ambiguous_heading_does_not_report_present_tags_as_missing` |
| `_format_unmet` back to `" ".join` | 1 failed — `test_the_aggregated_error_keeps_its_entries_legible` |
| Consolidated `_exact_heading_re` loses its `$` anchor | 23 failed across four files |

**F2 — FIXED.** A single problem renders verbatim; several render numbered and blank-line separated under a count header, with the markdown example table intact.

**F3 — FIXED at the scope SM set.** The row now states both measured behaviours, calls the disagreement an open defect, and tells agents to write the exact case. TEA's Question is explicitly left open and the "closes TEA's Question" claim is retracted in the Design Deviations with the disproving measurement. Dev re-measured the parser independently and reached the same result I did. Parser untouched by SM's call — correct, it is pre-existing and belongs in its own story.

**F10 — CORRECTED.** The coverage claim is withdrawn with the measurement that disproves it (0 failures across 163 tests in the three collateral files under an `is_approval_family` mutation, against 13 in `test_162_47_gate_parity`). The decision now rests on the truthfulness argument, which is the one that carried it.

**Regression check on cycle 1's work.** The exact/near-miss regex consolidation is a real SOUL #2 improvement (three rebuild sites → one definition each). I re-ran my cycle-1 A1 and A2 probes against the consolidated code: byte-identical behaviour — the 6-backtick wrapper still holds, a 5-tick closer still closes a 3-tick opener, and all five straggler forms still block. Rule 13 (no fix-introduced regressions) now **PASSES**.

### New non-blocking observations

**F14 — the aggregate can count one problem twice.** With no `## Subagent Results` section at all, the error reports "3 approval requirements are unmet" where items 1 and 3 are both "no Subagent Results section" — the completion check and the freshness check each report it with a different remedy. Not wrong, and item 3 adds the cycle-tag context, but the count overstates the number of distinct problems. Cosmetic; worth a line in whichever story picks up F4.

**F15 — `candidate_section_region` is public but single-purpose.** Its docstring says "For use ONLY when `select_last_section` reports `ambiguous`", which is adequate, but nothing enforces it and a future caller using it for an outcome decision would get a genuinely over-broad region. Consider making it private or returning a type that carries the precondition.

**F16 — `_ANY_SECTION_HEADING_RE` matches only `##`, so an intervening `#` H1 does not terminate the region.** Unreachable in practice (a session has one H1, at the top) and harmless; `^#{1,2}[ \t]` would close it for free.

**F17 — `test_heading_matching_is_case_insensitive` now pins behaviour the guide calls an open defect.** The test is accurate about what the code does, and the guide correctly says not to rely on it, so there is no contradiction — but the test's docstring should say it pins a defect pending F3's story, or a future reader will read it as a sanctioned contract. One comment.

### Friction with the new gate shape (still the first consumer)

**The cycle tag is off by one from the reviewer's notion of a cycle.** This is review cycle 2, and the tag the gate demands is `**Cycle: 1**` — it tracks completed round-trips, not review rounds. The gate's own error text names the right number, so it is discoverable, but `agents/reviewer.md` telling the reviewer to "tag the new table with the cycle number" invites writing the round number. Worth one clarifying clause in the guide: the tag is the round-trip count, which is the number of *completed* rework dispatches.

**A correction to the exit guidance I was given.** I was told the two-section state would force me to neutralize cycle 1's bold verdict line to a backticked form, because the parser wants exactly one such line. That premise is wrong, and I measured it before editing: the one-verdict rule is **per-section**, not file-wide. `select_last_section` returns only the last section and `read_agent_verdict` scans only that, so with two sections and one bold verdict line each, the reading is `{status: found, verdict: APPROVED}` — unambiguous. Cycle 1's record therefore stays verbatim, which is the better outcome: a rejection's evidence should not have to be defaced to let the story move. Worth stating plainly in `guides/handoff-cli.md`, since the natural reading of "exactly one verdict line per section" is ambiguous about scope and the safe-looking workaround is lossy.

**B3's exit shape worked as designed and cost nothing.** Appending a second section is the honest action anyway — a new cycle deserves its own ruling. F6 (B3 counts headings, not rulings) remains the design weakness, but nothing in this exit aggravated it.

### Rule compliance

python.md: 13/13 now PASS or N/A — rule 13 flips from FAIL to PASS with F1 repaired; rule 5 unchanged (production clean, pre-existing test-file gaps remain, package-wide gaps are F12). Project rules 1/2/3/4/9 PASS — all three changed files under `pennyfarthing-dist/`, nothing under `.pennyfarthing/`. Rule 6 PASS, with F7's `assert` unchanged and still a routed follow-up. SOUL #2 strengthened by the regex consolidation. Commit `03486f5c5` GPG-verified `G`.

### Deviation audit, cycle 2

No new deviations logged, and none needed — the rework stayed inside the remedies SM scoped. Both cycle-1 corrections (F3's documentation deviation, F10's A8 rationale) are recorded as amendments to the original entries with the disproving measurements attached rather than as quiet edits, which is the right form. My cycle-1 partial rejection of the documentation deviation is now satisfied; my cycle-1 rationale objection to the A8 deviation is now satisfied. All other cycle-1 deviations stand as accepted.

Outstanding follow-ups F4–F9 and F11–F17 are non-blocking and SM's to file. I agree with Dev's ranking: F4 first (`parse_round_trip_count` discarding `unreadable`, which B3 inherits — it defeats both the freshness guard and the `max_attempts` ceiling), and F5 travelling with F3's parser story since it is the same case inconsistency.

**Handoff:** To SM — approved, ready for PR.