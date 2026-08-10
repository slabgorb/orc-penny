---
story_id: "162-2"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-2: test_155_15 clean-merge tests never invoke gh pr merge — stateless MERGED fake trips the 155-29 short-circuit

## Story Details
- **ID:** 162-2
- **Jira Key:** (none — Jira not enabled for this story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-2-test-155-15-stateful-merge-fake
- **PR:** #169

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-04T19:15:04Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-04T18:40:20Z | 2026-08-04T18:41:53Z | 1m 33s |
| red | 2026-08-04T18:41:53Z | 2026-08-04T18:56:12Z | 14m 19s |
| green | 2026-08-04T18:56:12Z | 2026-08-04T18:58:47Z | 2m 35s |
| review | 2026-08-04T18:58:47Z | 2026-08-04T19:07:40Z | 8m 53s |
| green | 2026-08-04T19:07:40Z | 2026-08-04T19:12:27Z | 4m 47s |
| review | 2026-08-04T19:12:27Z | 2026-08-04T19:15:04Z | 2m 37s |
| finish | 2026-08-04T19:15:04Z | - | - |

## Sm Assessment

**Scope:** 1-pt p1 TDD story, test-infrastructure shape (like 155-30's test-polish: the deliverable is test hardening, not production code — but here the existing tests have a real fidelity hole, so a RED state DOES exist: a test asserting `gh pr merge` was invoked on the clean-merge path will fail against the current stateless fake).

**Technical approach for TEA:** In `pennyfarthing-dist/src/pf/tests/test_155_15_*.py`, the clean-merge tests stub `gh pr view` to always return state=MERGED. That trips the 155-29 short-circuit, so the production branch that actually calls `gh pr merge` is never covered by the "clean merge" tests. Convert the fake to stateful: PR starts OPEN (mergeable CLEAN), transitions to MERGED only after the fake records a `gh pr merge` invocation. Then assert the merge call actually happened on the clean path.

**Acceptance criteria:**
1. Clean-merge tests in test_155_15 use a stateful fake: view returns OPEN until the fake observes `gh pr merge`, MERGED after.
2. Clean-merge tests assert `gh pr merge` was invoked exactly once.
3. Full test_155_15 suite + sibling finish suites (155-12/29/31/32, 162-1) green against develop HEAD (04310589d, which includes the 162-1 gate reorder).

**Run mode:** Peloton-inline — agents spawned as subagents by SM, no relay markers, SM owns PR create/merge/finish.

## Delivery Findings

The clean-merge tests in `test_155_15_*.py` rely on a stateless fake that always returns `state=MERGED` from `gh pr view`. This causes the 155-29 already-merged short-circuit to fire, bypassing the actual code path that invokes `gh pr merge`. The fake needs to be stateful: PR starts OPEN, transitions to MERGED only after the fake observes a `gh pr merge` call. This gap was flagged in the 155-32 code review.

**Note:** 162-1 (merged as 04310589d) modified gate ordering in `story_finish.py`. Tests must be written against current develop HEAD.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)

- **Gap** (non-blocking): The identical stateless-fake hole survives in a sibling suite. `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_155_1_finish_verifies_merge.py:489` — `TestCleanMergeStillWorks::test_clean_merge_marks_done_and_removes_session` calls the local `_make_fake_run(merge_rc=0, pr_state="MERGED")`, whose `gh pr view` always reports MERGED, so it too trips the 155-29 short-circuit and never invokes `gh pr merge`. Particularly notable because 155-1 is the story that *made the merge load-bearing* — its one happy-path guard is the test that does not exercise the merge. Fix is mechanical: port the `pre_merge_pr_state` + `merge_calls` ledger design from 162-2's `test_155_15_*` fake. Out of scope here (162-2 scopes `test_155_15_*.py` only) — worth a 1-pt follow-up. *Found by TEA during test design.*
- **Improvement** (non-blocking): Four finish suites (155-1, 155-12, 155-15, 162-1) each carry a near-duplicate hand-rolled `_make_fake_run` plus its own `_merge_invoked` / `_requested_done` helpers, which is why a fidelity fix in one does not reach the others. A shared `pf/tests/helpers/gh_pr_fake.py` with one stateful PR fake would make this class of hole fixable once. *Found by TEA during test design.*
- **Question** (non-blocking): `test_153_4_story_mutation_on_sharded_yaml.py::TestFinishStorySuccessOnShardedYaml` fails at baseline (unchanged by this story) with `Jira sync failed: YAML updated to done but Jira transition failed` — an environment-dependent Jira dependency in a finish test. It is on the approved-baseline list, but a finish test that cannot pass without Jira credentials is permanently red locally and hides real finish regressions. Worth a story to stub the Jira boundary. *Found by TEA during test design.*

### Reviewer (code review)

- **Gap** (non-blocking): The identical stateless-fake hole survives at `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_155_1_finish_verifies_merge.py:489`. Confirmed by reading the call site: `_make_fake_run(merge_rc=0, pr_state="MERGED")` with a fixed-state view. Endorses TEA's finding — file as a 1-pt follow-up porting the `pre_merge_pr_state` + `merge_calls` design. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Consolidate the four duplicated `_make_fake_run` fakes (155-1, 155-12, 155-15, 162-1) into a shared `pf/tests/helpers/gh_pr_fake.py`. Reviewer adds two constraints for that story: (a) implement the fake as a callable dataclass with a `merge_calls` field rather than a closure plus function attribute — that removes both `type: ignore` escapes in the 162-2 version; (b) the current function-attribute ledger is a footgun when a fake is wrapped in `MagicMock(side_effect=fake)`, the pattern used in `test_155_29_finish_short_circuit_merged_pr.py` — reading `merge_calls` off the wrapper auto-creates a MagicMock whose `len()` is 0, so an exactly-once assertion would fail with a misleading message instead of erroring. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): gh PR states are bare strings everywhere — `story_finish.py` compares against literal `"MERGED"` / `"CONFLICTING"` / `"DIRTY"`, and the fake knobs `pr_state`, `pre_merge_pr_state`, `mergeable`, `merge_state_status` accept any string. A typo yields a silently impossible test world. Worth defining shared `Literal` aliases in production and importing them into the fakes. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): The fake dispatches on element membership, `if "merge" in parts`. Verified safe against every current `_run` call site in `story_finish.py` (the view probe passes fields as one comma-joined token `state,mergeable,mergeStateStatus,baseRefName`, so it cannot collide). Still positionally fragile — a future ref or branch argument equal to `merge` would inflate the ledger. Prefer `parts[:3] == ["gh", "pr", "merge"]`. Fold into the consolidation story. *Found by Reviewer during code review.*
- **Question** (non-blocking): Endorses TEA's note that `test_153_4_story_mutation_on_sharded_yaml.py` needs its Jira boundary stubbed — a finish test that is permanently red locally hides finish regressions. *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

### Deviation Justifications

1 deviation

- **Finding 2 fix diverges from the prescribed remedy**
  - Rationale: A guardrail no-op has no transition to observe — OPEN before, OPEN after. Because pre_merge_pr_state and pr_state are both OPEN in that world, the stateless and stateful fakes are observably identical there and no assertion can separate them. Sensitivity requires a world where the knobs differ.
  - Severity: minor
  - Forward impact: none — the reviewer's intent (an assertion that fails when the fake goes stateless) is met, and mutation A failures rose 7 to 9.

## Tea Assessment

**Tests Required:** Yes
**Status:** GREEN ON ARRIVAL (see Design Deviations — the RED proof is by mutation, not by a failing run)
**Commit:** 89f573b6f (GPG signed, verified `G`)

**Test file:** `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_155_15_finish_blocked_merge_no_stray_archive.py` — 22 tests, all green. Production code untouched.

### The gap, confirmed

Before this change `_make_fake_run` answered every `gh pr view` with a fixed state, so the clean-merge worlds — which need the PR to read MERGED for the post-merge `_pr_is_merged` verification — reported MERGED on the *pre-merge* probe too. `story_finish.py:658` (`elif pr_number and _view_is_merged(pr_view)`) is the 155-29 already-merged short-circuit, and that snapshot trips it. Proven with a throwaway probe against HEAD before touching anything:

```
SUCCESS: True
STEP2: [{'step': 2, 'action': 'merge_pr', 'pr': '315', 'merged': True, 'already_merged': True}]
MERGE INVOCATIONS: []
```

Four tests claiming a "clean, verified merge" never reached `gh pr merge`: `test_clean_merge_archives_marks_done_and_removes_session`, `test_clean_merge_still_archives_dialogue`, and both `TestArchiveCopyFailureReturnsResult` tests — the last two being the ones whose whole premise is that the archive copy now runs *after* the irreversible merge.

### Fake design (AC-1)

`_make_fake_run` gains `pre_merge_pr_state` (default OPEN) and a closure flag. The `state` field is now a function of history: `pre_merge_pr_state` until the fake observes a `gh pr merge` that returned 0, then `pr_state`. A non-zero merge does **not** advance the state — a denied merge does not land. `merge_rc=0` with `pr_state="OPEN"` therefore still models the guardrail no-op, so the existing abort worlds keep their meaning.

Each fake owns a `merge_calls` ledger (list of argv, in order), read via the `_merge_calls(fake)` helper. Per-instance, not per-factory — pinned by `test_ledger_is_per_fake_not_shared`, since a shared ledger would make "exactly once" meaningless.

### Ledger assertions (AC-2)

| Test | Ledger assertion |
|---|---|
| `test_clean_merge_invokes_gh_pr_merge_exactly_once` (new) | exactly 1, argv targets PR 315 |
| `test_clean_merge_step2_is_a_real_merge_not_the_short_circuit` (new) | one step-2 entry, `merged` true, `already_merged` falsy, `skipped` falsy |
| `test_clean_merge_still_archives_dialogue` | exactly 1 |
| `test_copy_failure_returns_result_not_exception` | exactly 1 |
| `test_copy_failure_does_not_transition_to_done` | exactly 1 |
| `test_no_session_copy_left_in_archive_when_merge_denied` | exactly 1 (a BLOCKED-but-mergeable PR is undetectable before the attempt) |
| `test_no_session_copy_left_in_archive_when_merge_unverified` | exactly 1 |
| `test_no_pr_finish_still_archives_and_marks_done` | zero |

New `TestFakeIsStateful` class (6 tests) pins the harness contract with no production code under it: view reads OPEN before any merge, MERGED only after a successful one, a denied merge does not advance state, the unverified world stays OPEN, the ledger captures full argv including the merge flags, and ledgers are per-fake.

### RED proof by mutation

| Mutation | Result |
|---|---|
| A — fake reverted to the pre-162-2 fixed `state` | **7 failed**, 15 passed |
| B — `story_finish.py` skips the `_run` merge call and fabricates a rc=0 result | **8 failed**, 14 passed |

Both mutations reverted; `git diff` confirmed `story_finish.py` byte-identical afterwards.

### Suite results (AC-3)

Finish-flow siblings 155-1 / 155-12 / 155-15 / 155-29 / 155-31 / 155-32 / 162-1: **98 passed**, 0 failed.
Full suite: 5458 passed, 30 failed — all 30 in the approved pre-existing baseline modules (143-9 ×13, 143-10 ×1, 153-4 ×3, independence ×2, init-justfile ×1, peloton-portrait ×10). 153-4 and 143-10 verified identical failure sets with the change stashed, so unchanged by this work.

`ruff check` clean. `ruff format --check` reports drift on this file both before and after the change — pre-existing, deliberately not reformatted to keep the diff reviewable.

### What Dev must do

**Nothing to implement.** The finish flow already merges the clean OPEN path correctly — mutation B is the evidence that the new assertions bind to real behavior rather than to nothing. Dev's job is verification only: re-run the seven finish suites, confirm 98 green, confirm no production file was touched by 89f573b6f, and hand to Reviewer.

## Dev Assessment

**Implementation Complete:** Yes — no implementation required. GREEN ON ARRIVAL confirmed independently.

**Files Changed:** none by Dev. Sole commit on the branch is TEA's 89f573b6f.

**Tests:** 98/98 passing across the seven finish suites (GREEN)
**Branch:** feat/162-2-test-155-15-stateful-merge-fake (pushed, tracking origin)

### Verification evidence

**1. Commit scope — no production file touched.** `git show --stat 89f573b6f` reports exactly one file: `pennyfarthing-dist/src/pf/tests/test_155_15_finish_blocked_merge_no_stray_archive.py`, 264 insertions / 52 deletions. Test-only, matching TEA's claim.

**2. Seven finish suites (AC-3).** 155-1, 155-12, 155-15, 155-29, 155-31, 155-32, 162-1 together: **98 passed, 0 failed** in 3.28s. Re-run after the mutation probe below: 98 passed again, 0 failed.

**3. Story file alone.** `test_155_15_finish_blocked_merge_no_stray_archive.py`: **22 passed**, 0 failed.

**4. Lint.** `ruff check` on the story file: All checks passed. `ruff format --check` reports one file would be reformatted — confirmed **pre-existing**, not introduced here: the same command run against the pre-162-2 revision of the file (extracted from 04310589d) also reports one file would be reformatted. Deliberately not reformatted, per TEA's note about keeping the diff reviewable.

**5. Mutation B spot-verified with a self-restoring probe.** Replaced the `gh pr merge` subprocess call at `story_finish.py:689` with a fabricated rc=0 `CompletedProcess`, leaving every surrounding gate intact — i.e. the exact regression shape of "a change that stops actually merging but still completes the ceremony."

Result: **8 failed, 14 passed** — reproducing TEA's reported count exactly. The failures include both new tests (`test_clean_merge_invokes_gh_pr_merge_exactly_once`, `test_clean_merge_step2_is_a_real_merge_not_the_short_circuit`) plus `test_clean_merge_archives_marks_done_and_removes_session`, which under the old stateless fake could not have failed. This is the load-bearing evidence: the new ledger assertions bind to real production behavior, not to the harness alone.

Restore was verified by content hash, not by eye — `git hash-object src/pf/sprint/story_finish.py` returned `a6ecadf096b3fc5f119608919c1c0524cfb9930f` both before the mutation and after restore, and `git status --porcelain` is empty. Production file byte-identical.

### Assessment of the story shape

TEA's green-on-arrival call is correct and I found no production defect to fix. The clean OPEN path in `finish_story` already invokes `gh pr merge` and verifies the result via `_pr_is_merged`; what was broken was the test harness's ability to observe that. The value delivered is regression detection that did not previously exist — before this commit, a change that skipped the merge outright would have passed all four tests named for a "clean, verified merge."

Nothing further to implement. Handing to Reviewer.

## Dev Assessment — Addendum (review rejection, round 2)

**Status:** Both findings fixed. Reviewer was right on both counts.
**Commit:** 9cde0087f (GPG signed, verified good signature), pushed.
**Files Changed:** `pennyfarthing-dist/src/pf/tests/test_155_15_finish_blocked_merge_no_stray_archive.py` only (+53/−6). Production still untouched.

### Finding 1 (HIGH) — clean-path happy test never read the ledger

Confirmed and fixed. `test_clean_merge_archives_marks_done_and_removes_session` bound the fake but asserted only outcomes, so the one test in the class most likely to be read as covering the happy path was still satisfiable by a run that marked the story done, archived the session and removed the session file without landing any code. Added `assert len(_merge_calls(fake)) == 1` with a message naming that failure mode.

I audited the whole file rather than patching the single cited line. Of 16 tests that call the real finish flow, 9 assert the merge actually happened and 7 do not. The 7 are all abort-world siblings where one test per world pins the invocation count and the others pin the distinct consequences — result shape, session kept, no done transition. I did not add ledger assertions to those: the claim is per-world, not per-assertion, and repeating it would add no coverage. Only the clean path had a genuine hole.

Docstring corrected, and made precise rather than merely softened. The old text claimed every clean-path test asserts the merge ledger. That was false for the test above and imprecise for `test_clean_merge_step2_is_a_real_merge_not_the_short_circuit`, which makes the same claim by reading the step-2 record instead of the ledger. New text states what each test actually does and documents the per-world convention for the abort tests.

### Finding 2 (MEDIUM) — insensitive assertion in the unverified world

Confirmed. `test_unverified_merge_world_keeps_the_pr_open` set merge_rc=0 with pr_state OPEN, and the default pre_merge_pr_state is also OPEN, so the asserted value equals both knobs. A stateless fake pinned at pr_state returns OPEN on both probes and the test passes either way.

One correction to the prescribed fix, and I want to be explicit rather than quietly diverge: capturing state before and after does not by itself restore sensitivity, and the no-op cannot be observed as a transition because there is no transition — a guardrail no-op is OPEN before and OPEN after. In that world the two implementations are observably identical, so no assertion about it can distinguish them. The coverage had to move to a world where the knobs differ.

What I did:
- `test_unverified_merge_world_keeps_the_pr_open` now captures state on both sides of the merge and asserts the pair, which is the honest statement of the no-op and strictly stronger than before, with a docstring saying it pins that pr_state governs the post-merge read so a successful merge does not imply MERGED.
- New `test_state_reads_pre_merge_knob_before_and_pr_state_after` carries the mutation sensitivity using two distinguishable values (pre OPEN, post MERGED). A fake that ignores history answers the pre-merge probe with the post-merge value and fails. Its docstring records why the no-op world structurally cannot provide this.

### Verification

Mutation A re-run with a self-restoring probe — `state` reverted to the fixed `pr_state`:

| | Before this commit | After |
|---|---|---|
| Mutation A failures | 7 failed, 15 passed | **9 failed, 14 passed** |

Both newly-guarded tests are in the failure list: `test_clean_merge_archives_marks_done_and_removes_session` (finding 1) and `test_state_reads_pre_merge_knob_before_and_pr_state_after` (finding 2). The reviewer predicted 7 to 8; the extra one is the new sibling test. As explained above, `test_unverified_merge_world_keeps_the_pr_open` is still absent from the failure list and cannot be present.

Restore verified by content hash, not inspection: `git hash-object` returned `4bdb81b676bd0b5ade5af62a092fd78bcb674bbb` both before mutation and after restore.

- Story file: **23 passed** (was 22, plus the new test)
- Seven finish suites: **99 passed, 0 failed**
- `ruff check`: All checks passed
- `ruff format --check`: still reports drift, still pre-existing (proven last round against the pre-162-2 revision), still not reformatted
- Working tree clean, branch pushed

## Design Deviations

### Dev (implementation)

- **Finding 2 fix diverges from the prescribed remedy**
  - Spec source: Reviewer rejection, finding 2 (MEDIUM), session round 2
  - Spec text: "Capture PR state before AND after the merge so the no-op is observed as a transition"
  - Implementation: Captured state on both sides as directed, but added a separate test with distinguishable knob values to carry the mutation sensitivity, rather than expecting the before/after capture to supply it.
  - Rationale: A guardrail no-op has no transition to observe — OPEN before, OPEN after. Because pre_merge_pr_state and pr_state are both OPEN in that world, the stateless and stateful fakes are observably identical there and no assertion can separate them. Sensitivity requires a world where the knobs differ.
  - Severity: minor
  - Forward impact: none — the reviewer's intent (an assertion that fails when the fake goes stateless) is met, and mutation A failures rose 7 to 9.

- Round 1 (verification-only): no deviations. Round 2 deviation logged above.

### TEA (test design)

- **No failing-test RED state:** Story shape is test-infrastructure hardening — the defect lived in the fake, not in production. Rewriting the fake and asserting against it is necessarily green on arrival. RED is proven by mutation instead, per the story's own instruction: mutation A (stateless fake) fails 7 tests, mutation B (production skips `gh pr merge`) fails 8. No production bug found on the clean OPEN path.
- **`pr_state` knob semantics narrowed:** It now means "state after a successful merge" rather than "state on every probe", with `pre_merge_pr_state` covering the before. Every existing call site passed `pr_state` explicitly and none intended the short-circuit, so no existing world changed meaning.

### Reviewer (audit)

- **ACCEPTED — no failing-test RED state.** Green-on-arrival is legitimate for this story shape and the mutation proof is adequate. SM pre-authorized it conditional on mutation evidence, and the evidence holds under independent reproduction: Reviewer re-ran mutation A (fake reverted to a fixed `state`) and got 7 failed / 15 passed, matching TEA's reported count exactly, with the file restored byte-identical by hash. Reviewer also ran a third mutation neither TEA nor Dev attempted — mutation C, duplicating the `gh pr merge` call in `story_finish.py` to model a retry-loop regression — which produced 6 failed / 16 passed with the production file restored to hash `a6ecadf096b3fc5f119608919c1c0524cfb9930f`. Mutation C is the one that proves exactly-once is load-bearing in the upper direction; A and B only prove at-least-once. Three independent mutations, three distinct failure sets: the assertions bind to real behavior.
- **ACCEPTED — `pr_state` knob semantics narrowed.** Verified by enumerating all 24 `_make_fake_run` call sites in the file. Every one passes `pr_state` explicitly and none intended the short-circuit, so no pre-existing world silently changed meaning. The 155-29 already-merged path this file used to exercise by accident is covered deliberately in `test_155_29_finish_short_circuit_merged_pr.py` (9 tests) and `test_162_1_finish_merged_before_conflict_gate.py` (15 tests), so nothing was lost by evicting it from here.
- **FLAGGED — the deliverable's own AC-2 is not met for one test.** See Reviewer Assessment finding 1. Not a deviation TEA declared, which is why it is flagged rather than accepted.
- **UNDOCUMENTED — `pre_merge_pr_state` is a dead knob.** The parameter was added with a default of OPEN and no call site anywhere passes it. It is the natural way to model an already-merged world in this file, but no test does. Harmless, and the consolidation story is the right place to either use it or drop it. Noted rather than filed.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

## Subagent Results

| # | Subagent | Status | Findings | Confirmed | Notes |
|---|----------|--------|----------|-----------|-------|
| 1 | reviewer-preflight | Complete | 0 | n/a | 98/98 green across the seven finish suites; 22/22 on the story file; `ruff check` clean; format drift pre-existing. **Challenged:** its change summary claims "dialogue archiving tests added for symmetry" — no such tests were added; the diff only adds a ledger assertion to the existing dialogue test. Paraphrase error, not a finding. |
| 2 | reviewer-test-analyzer | Complete | 4 | 4 | All four confirmed by independent verification. Finding 1 promoted to HIGH after mutation A showed the affected test survives the exact regression 162-2 exists to catch. |
| 3 | reviewer-type-design | Complete | 3 | 3 | All three downgraded to deferred: two `type: ignore` escapes from the function-attribute ledger, stringly-typed PR states, and a `landed` boolean that cannot express CLOSED-without-merge. None block; all belong to the fake-consolidation story. |
| 4 | reviewer-security | Complete | 0 | n/a | Verified independently: `_fake_run` is a pure closure with no subprocess reachability, `TestFakeIsStateful` calls it in-process, all writes rooted at pytest `tmp_path`, no credentials. No real gh command can escape. |
| 5 | reviewer-rule-checker | Complete | 0 | n/a | 18 rules, 47 instances, 0 violations. **Challenged:** it lists `test_clean_merge_archives_marks_done_and_removes_session` among the tests that gained ledger assertions. It did not — verified by reading lines 790-815 and by mutation C, under which that test passes while all six genuinely-asserting tests fail. This is the source of finding 1. |
| 6 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 8 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |

**All received: Yes** — all 5 enabled subagents returned (preflight, test-analyzer, type-design, security, rule-checker). The 4 disabled subagents are accounted for as Skipped.

## Reviewer Assessment

**Verdict:** REJECTED

The fake redesign is genuinely good work — the state machine is correct, the ledger is per-instance, the harness contract is pinned, and three independent mutations prove the assertions bind to production behavior rather than to the harness. It is rejected on one narrow but material point: the story's own AC-2 is unmet for the one pre-existing test in the clean-merge class, and the file documents a universal claim that is therefore false. The fix is about three lines.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | [TEST] [RULE] AC-2 unmet for a clean-merge test, and the module docstring's universal claim is false. `test_clean_merge_archives_marks_done_and_removes_session` binds a `fake` variable — clearly in anticipation of an assertion — but never reads the ledger. Mutation-verified: under mutation A this test passes, so it still testifies to a "clean, verified merge" in a world where no merge was attempted. That is precisely the defect class 162-2 exists to eliminate, surviving inside the fix. Meanwhile the module docstring asserts "Every clean-path test now asserts the merge ledger", which will tell the next author this file is clean when one test is not. | `pennyfarthing-dist/src/pf/tests/test_155_15_finish_blocked_merge_no_stray_archive.py:791` (test), `:18` (docstring claim) | Add `assert len(_merge_calls(fake)) == 1` after the `with patch` block, with a message. Then re-run mutation A and confirm the failure count rises from 7 to 8. |
| [MEDIUM] | [TEST] Non-falsifiable harness test. `test_unverified_merge_world_keeps_the_pr_open` sets `merge_rc=0` with `pr_state="OPEN"`, so the asserted value equals `pre_merge_pr_state` and a stateless fake answers identically. Confirmed by mutation A, under which this test passes. It does still guard a different mutation (one that forced MERGED regardless of `pr_state`), so it is not worthless — but as written it cannot detect the regression its class exists to detect. | same file, `:357` | Capture `_view_state(fake)` both before and after the merge call and assert both, so the guardrail no-op world is observed as a transition rather than a single value. |
| [LOW] | [TEST] `test_clean_merge_step2_is_a_real_merge_not_the_short_circuit` infers the merge happened from internal bookkeeping keys (`steps`, `already_merged`, `skipped`) rather than from the ledger. If production ever drops the `already_merged` key the negative assertions go vacuous. The step-record assertions are legitimately about the operator-facing report, so keep them — just anchor the merge-happened claim to the direct observation too. | same file, `:855` | Optional: add `assert len(_merge_calls(fake)) == 1` alongside the step-2 checks. |
| [LOW] | [TYPE] Dead parameter: `pre_merge_pr_state` has no call site. Related deferred [TYPE] findings — two `type: ignore` escapes from the function-attribute ledger, stringly-typed PR-state knobs, and a `landed` boolean that cannot express CLOSED-without-merge — are recorded under Delivery Findings for the fake-consolidation story rather than blocking here. | same file, `:189` | None required; noted for the consolidation story. |

**Data flow traced:** `finish_story` resolves `pr_number` from the session, the conflict gate takes one `gh pr view` snapshot at `story_finish.py:247`, the already-merged short-circuit at `:658` reads that snapshot, the auto-merge branch at `:689` runs `gh pr merge`, and `_pr_is_merged` takes a fresh view for post-merge verification. The fake sits at the `_run` boundary and answers all four probes from a single `landed` flag. State advances only on `merge_rc == 0`, so a denied merge cannot fake a landing — verified by reading the closure and by `test_denied_merge_does_not_advance_state`, which fails under mutation A.

**Pattern observed:** Good — a harness-contract test class with no production code beneath it, at `:338`. This is the right response to a fake that lied: pin the fake itself so it cannot regress silently. Two of its six tests happen to be insensitive to the stateless mutation (see the MEDIUM), but the class as a whole catches it.

**Error handling:** The abort worlds are the strong part of this diff. The review-required guardrail world at `:399` now asserts the merge was actually attempted, which is correct reasoning — a BLOCKED-but-mergeable PR is undetectable before the attempt, so without that assertion the test could have been passing via the conflict gate instead. Same for the unverified-merge world at `:506`. The `except OSError` handlers in the copy-failure tests call `pytest.fail` rather than swallowing.

**Security:** [SEC] No attack surface. Verified the fake cannot reach a subprocess, every write is rooted at pytest `tmp_path`, `shutil.copy2` is patched in the copy-failure worlds, and PR `315` / story `155-15` are synthetic fixtures. No credentials.

**Handoff:** Back to Dev for the HIGH and MEDIUM (test-only edits, no production change). The four deferred findings are recorded under Delivery Findings for SM to file as follow-ups.

## Reviewer Assessment — Addendum (delta review, round 2)

**Verdict:** APPROVED
**Reviewed:** `9cde0087f` (test-only, +53/−6, GPG signed) — delta against `89f573b6f`.

All four of Dev's claims verified independently. Both round-1 blockers are closed, both round-1 LOW findings are incidentally resolved, and no new findings.

### Finding 1 (HIGH) — CLOSED

`test_clean_merge_archives_marks_done_and_removes_session:848` now asserts `len(_merge_calls(fake)) == 1`. Verified by re-running my own mutation A (fake reverted to a fixed `state`): **7 failed → 9 failed**, with that test now present in the failure list where it was previously absent. Test file restored byte-identical by hash. Mutation C (duplicated `gh pr merge`, the retry-loop regression) independently rose **6 failed → 7 failed** with the same test newly present, so the assertion is load-bearing in both directions, not just at-least-once. The module docstring's false universal claim is corrected and the replacement is accurate: I counted the clean-path successful-merge tests and there are exactly three asserting via the ledger plus `test_clean_merge_step2_is_a_real_merge_not_the_short_circuit` asserting via the step-2 record, as the docstring now says.

**Dev's per-world audit claim verified by AST enumeration**, not by eye. 16 flow-driving tests: 9 assert the ledger, 7 do not — matching Dev's numbers exactly. Every abort world has at least one ledger-pinning test: denied merge is pinned by `test_no_session_copy_left_in_archive_when_merge_denied`, unverified by `test_no_session_copy_left_in_archive_when_merge_unverified`, copy-failure by both of its tests, and the no-PR world asserts the ledger is empty. The 7 unasserted siblings pin distinct consequences (result shape, session kept, no `done` transition, no dialogue copy) in worlds whose invocation count is already pinned. The per-world claim holds; adding the assertion to the siblings would be duplication, not coverage. Accepted.

### Finding 2 (MEDIUM) — CLOSED, and my prescribed remedy was wrong

**Dev's impossibility argument is correct and I was mistaken.** I verified it two ways. Analytically: in the OPEN/OPEN world the stateless expression `pr_state` and the stateful expression `pr_state if landed else pre_merge_pr_state` both evaluate to OPEN on every probe, and no other observable — `mergeable`, `merge_state_status`, `baseRefName`, the ledger — differs between the two implementations. The two are extensionally equal on that input, so capturing before and after cannot separate them; my prescription would have produced a longer test with identical sensitivity. Empirically: under mutation A `test_unverified_merge_world_keeps_the_pr_open` still passes, exactly as Dev's argument predicts.

Dev's substitution is strictly better than what I asked for. The existing test keeps its real job — pinning that `pr_state` governs the post-merge read, so a successful merge does not imply MERGED — and now states that job in a docstring instead of leaving it implicit. The sensitivity moves to a new test, `test_state_reads_pre_merge_knob_before_and_pr_state_after:377`, which uses distinguishable values (pre OPEN, post MERGED) and **does** appear in the mutation A failure list. That is the load-bearing check: the deviation is approved.

### Round-1 LOW findings — both incidentally resolved

- Dead parameter `pre_merge_pr_state` now has exactly one call site: the new sensitivity test. The knob is live and the test that exercises it is the one that documents why it exists.
- `test_clean_merge_step2_is_a_real_merge_not_the_short_circuit` remains ledger-free, which I flagged as optional. Now defensible on the record rather than by omission: the docstring frames it as the same claim read off the operator-facing run report instead of off the fake, which is a deliberate second vantage point. It fails under both mutation A and mutation B, so it binds.

### Verification (independent, not taken on report)

| Check | Result |
|---|---|
| Mutation A (stateless fake) | 9 failed / 14 passed — up from 7; both newly-guarded tests present; restore hash-verified |
| Mutation C (double merge, Reviewer-authored) | 7 failed / 16 passed — up from 6; `story_finish.py` restored to `a6ecadf096b3fc5f119608919c1c0524cfb9930f` |
| Story file | 23 passed |
| Seven finish suites | 99 passed / 0 failed |
| `ruff check` | All checks passed |
| Working tree | clean, `git status --porcelain` empty after every probe |

Dev's reported hash `4bdb81b676bd0b5ade5af62a092fd78bcb674bbb` matches the post-image blob in the delta diff. Production code untouched across both commits.

**Handoff:** To SM for finish-story. The five deferred findings under Delivery Findings still stand for follow-up filing — none were addressed by this rework and none should have been.