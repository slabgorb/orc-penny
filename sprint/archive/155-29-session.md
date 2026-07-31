---
story_id: "155-29"
jira_key: null
epic: "PROJ-155"
workflow: "tdd"
---
# Story 155-29: finish_story: make post-merge aborts retryable — short-circuit Step 2 when _pr_is_merged() is already true (from 155-16 review)

## Story Details
- **ID:** 155-29
- **Jira Key:** none
- **Workflow:** tdd
- **Points:** 2
- **Priority:** p1
- **Status:** backlog
- **Repos:** pennyfarthing
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-31T16:47:27Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-31T16:25:36Z | 2026-07-31T16:26:54Z | 1m 18s |
| red | 2026-07-31T16:26:54Z | 2026-07-31T16:36:06Z | 9m 12s |
| green | 2026-07-31T16:36:06Z | 2026-07-31T16:39:09Z | 3m 3s |
| review | 2026-07-31T16:39:09Z | 2026-07-31T16:47:27Z | 8m 18s |
| finish | 2026-07-31T16:47:27Z | - | - |

## Technical Context

### Story Background
This story addresses a design gap in the `finish_story` flow when retrying post-merge aborts. Currently, if a merge succeeds but a later step (e.g., step 3, step 4) fails, re-running `pf sprint story finish` restarts from the merge step even though the PR is already merged. This creates redundant work and risk.

The solution: add an early check in Step 2 (`merge_pr`) — before attempting the merge, call `_pr_is_merged()`. If the PR is already merged, short-circuit Step 2 and proceed directly to the downstream steps (3+). This makes post-merge aborts safely retryable without re-attempting the merge.

### Acceptance Criteria
1. Step 2 (`merge_pr` call site in `story_finish.py`) calls `_pr_is_merged()` before attempting merge
2. If already merged, short-circuit the merge attempt and proceed to Step 3
3. Test coverage for the short-circuit path (already-merged PR with Step 2+ failure scenarios)

### Related Issues
- From 155-16 code review feedback
- Affects `pennyfarthing-dist/src/pf/story_finish.py` (merge_pr function and finish_story orchestration)

## Branch Strategy
**Branch Strategy:** gitflow (feat/155-29-post-merge-abort-retryable)
**Repository:** pennyfarthing (off develop)

## Sm Assessment

Setup complete. Session file created with story context. Ready for TEA RED phase.

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_29_finish_short_circuit_merged_pr.py` (new) — 8 tests: 4 RED + 4 green-on-arrival guards
- `pennyfarthing-dist/src/pf/tests/test_155_1_finish_verifies_merge.py` (adjusted) — 5 tests pre-adjusted fix-agnostically (see Deviations); all green on HEAD

**Tests Written:** 8 covering 3 ACs
**Status:** RED (4 failing on AssertionError — verified by direct scoped run AND testing-runner; 43 sibling finish-family tests green, incl. the 5 adjusted)

**The bug reproduced:** after a post-merge abort (archive OSError / 155-16 status-read guard / transition failure), re-running `pf sprint story finish` re-attempts `gh pr merge` on the already-merged PR; gh exits non-zero ("already merged"), the rc!=0 abort fires, and finish is permanently wedged.

**RED tests (TestAlreadyMergedShortCircuit):**
1. `test_already_merged_pr_skips_merge_attempt` — AC-1: merge never invoked when `gh pr view` reports MERGED (merge_rc=0 deliberately: even a tolerant gh must not be asked)
2. `test_finish_completes_when_pr_already_merged` — AC-2: realistic retry (gh rc=1 "already merged") completes: done transition + session removed
3. `test_retry_after_post_merge_abort_completes` — AC-2/AC-3 end-to-end: run 1 merges then aborts on failed done-transition; run 2 must complete
4. `test_short_circuit_step_record_is_truthful` — step-2 entry records merged/already_merged truthy, never `skipped`, never success:False

**Green guards (TestUnmergedPathUnchanged, intentional-green):**
- OPEN PR still gets a real merge (stateful OPEN→MERGED fake) and completes
- genuine merge failure (rc=1, stays OPEN) still aborts, session kept
- `gh pr view` probe error falls through to the merge attempt — never treated as "already merged" (rule #1 pin), 155-1 backstop still aborts
- human merge mode: no merge attempt, no done transition, MERGED view answer must not flip it into the auto path

**Designed interface for Dev** (in test-file docstring): in the auto-mode `elif pr_number:` branch, before `gh pr merge`: `if _pr_is_merged(pr_number): steps.append({"step": 2, "action": "merge_pr", "pr": pr_number, "merged": True, "already_merged": True})` else existing merge+verify. Tests bind only to: merged/already_merged truthy, pr named, not skipped, not success:False.

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 no silent swallow (probe error must not open a false-done hole) | `test_precheck_probe_error_falls_through_to_merge` | passing (guard) |
| #6 test quality (patch-where-used, no vacuous asserts) | all — `story_finish._run`/`transition_story` patched where used; self-checked | n/a (self-check) |

**Rules checked:** 2 of 13 applicable (fix adds no new I/O, async, paths, or deps — remaining rules have no surface in this story)
**Self-check:** 0 vacuous tests found

**Handoff:** To B.A. (Dev) for GREEN — commit `f64823cfd` on `feat/155-29-post-merge-abort-retryable`

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — 19-line pure insertion: new `elif pr_number and _pr_is_merged(pr_number):` arm ABOVE the existing auto-merge arm, recording `{"step": 2, "action": "merge_pr", "pr": pr_number, "merged": True, "already_merged": True}` and falling through to Steps 3+. The load-bearing merge+verify code is untouched (zero diff on that arm).

**Why this shape:**
- Implements TEA's designed interface verbatim; a separate `elif` (rather than if/else inside the merge arm) keeps the diff a pure insertion.
- Human-mode branch remains first in the chain, so the pre-check never probes `gh pr view` in human mode (human-mode guard passes structurally).
- Reuses `_pr_is_merged` (155-1) — returns False on any probe error, so an unverifiable PR state falls through to the real merge attempt and the post-merge verification backstop. No second probe written (SOUL #2).
- Composes with the 155-12 pre-gate: a MERGED PR reports `mergeable: UNKNOWN`, which `_pr_block_reason` treats as do-not-block, so the short-circuit is reached.

**Tests:** 8/8 story tests passing (GREEN); 82-test finish-flow batch via testing-runner (test_155_1/12/15/16, no_jira, 151_3) all green; wider 157-test batch (adds 155_3/4/6/9, 147_12, demo_hook, 160_3, archive_epic) all green; `ruff check` clean. Post-runner `git diff` verified clean (only my insertion).
**Branch:** feat/155-29-post-merge-abort-retryable (pushed, commits f64823cfd + 94a4b96d7)

**Handoff:** To Colonel Lynch (Reviewer) for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 120/120 tests, ruff clean, tree clean, no debug code, 2 commits pushed |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered directly: enumerated all 6 paths through the Step-2 elif chain (human±PR, auto merged/unmerged/probe-error/no-PR); CLOSED-PR and deleted-branch retry paths traced (see Devil's Advocate) |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered directly: new arm adds no try/except; `_pr_is_merged` error→False is the safe fall-through direction (pinned by `test_precheck_probe_error_falls_through_to_merge`); no new swallow |
| 4 | reviewer-test-analyzer | Yes | findings | 5 | confirmed 5 (1 MEDIUM + 4 LOW, all non-blocking), dismissed 0; mutation table: 4/5 mutations killed, 1 survivor (unread `already_merged` key pin gap) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — domain covered directly: new 10-line comment block verified accurate against `_pr_is_merged` source (error→False, lines 188-193); test docstrings match shipped behavior |
| 6 | reviewer-type-design | Yes | findings | 2 | confirmed 2 LOW non-blocking (ad-hoc step-dict shapes gain a 5th variant; `already_merged` has no runtime consumer); verified sole steps consumer is sprint/cli.py:493-497 reading only step/action/warning/error |
| 7 | reviewer-security | Yes | clean | 1 informational | confirmed at LOW: stale session `**PR:**` line could name a different merged PR — pre-existing trust boundary shared by the real merge path, not widened by this diff. No injection (digits-only pr_number, list-argv), no truthfulness regression, TOCTOU moot (MERGED is monotonic) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — domain covered directly: 19-line pure insertion, one condition + one steps.append, no dead code, no abstraction added |
| 9 | reviewer-rule-checker | Yes | clean | 0 violations | all 13 python.md checks + SOUL #2/#10/#14 pass with line evidence; single `gh pr merge` call site repo-wide (no #13 asymmetry); 1 perf observation folded into the existing consolidation finding |

**All received:** Yes (5 returned, 4 disabled with domains covered directly)
**Total findings:** 8 confirmed (0 blocking — 2 MEDIUM, 6 LOW/informational), 0 dismissed, 0 deferred without decision

## Reviewer Assessment

**Verdict:** APPROVED

**Binding evidence (classifier-safe, no tree revert):** test commit `f64823cfd` precedes impl commit `94a4b96d7`; RED state (exactly the 4 short-circuit tests failing on AssertionError) was verified at the test commit by TEA's direct scoped run AND testing-runner. Mutation testing independently re-proved binding: removing the pre-check arm kills exactly those 4 tests; inverting the condition kills 15/18 across both files. Tree verified clean after the analyzer's authorized mutation runs (`git status` empty, `git diff HEAD` empty, HEAD unchanged, 18/18 re-run green).

**Data flow traced:** session `**PR:** #999` → `_extract_pr_number` regex `#(\d+)` (digits only) → list-argv `gh pr view <n> --json state` → `json.loads(...).get("state") == "MERGED"` strict equality → short-circuit records truthful step-2 entry → existing Steps 1/3-7. Safe: no shell, no interpolation, gh JSON trusted only as much as the pre-existing merge path already trusts it.

**Observations (tagged):**
1. [VERIFIED] The short-circuit gate is the identical load-bearing verification 155-1 uses post-merge — `story_finish.py:430` calls the same `_pr_is_merged` (lines 180-194) as line 480; `done` is unreachable without a confirmed MERGED state on every path. Complies with epic-155 truthfulness and SOUL #2 (no duplicate probe). [SEC][RULE]
2. [VERIFIED] Probe-error fall-through: `_pr_is_merged` returns False on gh rc≠0 or JSON error (188-193), so an unverifiable state takes the real merge attempt and hits the 155-1 backstop — pinned by `test_precheck_probe_error_falls_through_to_merge`. No silent-failure hole (python #1). [SILENT][TEST]
3. [VERIFIED] Step-record truthfulness (SOUL #14): the entry sets `merged: True, already_merged: True`, never `skipped` — enforced by `test_short_circuit_step_record_is_truthful` (mutations 2 and 5 killed). CLI consumer (sprint/cli.py:493-497) reads only step/action/warning/error, renders "2. merge_pr" cleanly. [TYPE][RULE]
4. [VERIFIED] Human-mode isolation: the human branch precedes the new elif, so human mode never probes and never short-circuits into auto-done — pinned by `test_human_mode_untouched_no_merge_attempt`. [EDGE]
5. [MEDIUM][TEST] OR-based assertion at test_155_29:545 (`merged is True or already_merged is True`) lets mutation "delete `already_merged`, keep `merged`" survive. Behavior is fully pinned; only the audit-trail key is loosely pinned, and nothing consumes it at runtime. Non-blocking test polish — same class as backlog story 155-30 (pin key presence); routed there via Delivery Finding rather than a rework cycle.
6. [MEDIUM][TEST] No test combines branch-resolved PR (`gh pr list --head` fallback) with already-merged. Both sources converge on the same `pr_number` before the elif, so coverage is structural rather than explicit — confirmed non-blocking; folded into the same test-polish finding.
7. [LOW][TYPE] Step-2 dicts are five ad-hoc shapes with no TypedDict union — pre-existing convention this diff extends consistently (new entry is a superset of the line-500 success shape). Non-blocking design note.
8. [LOW][TEST][SIMPLE] Stateful OPEN→MERGED fake duplicated between test_155_1 and test_155_29; `_requested_done` carries a loose `"done" in call.args` fallback (pre-existing helper convention). Consolidation nits, non-blocking.
9. [LOW][SEC] Stale session PR number could short-circuit against a different merged PR — pre-existing trust boundary (the real merge path consumes the same value verbatim); not widened. Documented-acceptable.
10. [LOW][EDGE][DOC] Dry-run preview still says "Merge PR #N (squash, delete branch)" for an already-merged PR — pre-existing, out of AC, cosmetic; noted in findings.

**Error handling:** no new raise, no new catch; `finish_story`'s no-throw contract preserved (rule-checker verified SOUL #10 with line evidence). A CLOSED-not-merged PR returns False from the pre-check → merge attempt → gh refuses rc≠0 → loud abort (correct).

**Pattern observed:** guard-reuse insertion — new elif arm reuses the existing verified predicate rather than adding a second probe, at story_finish.py:430. Good pattern; zero diff on the load-bearing merge arm.

### Rule Compliance

| python.md check | Instances in diff | Verdict |
|---|---|---|
| #1 silent exceptions | new elif arm (430), `_pr_is_merged` call site | compliant — no new catch; error→False is fall-through-to-merge, pinned by guard test |
| #2 mutable defaults | 2 new test factory fns (scalar kw-only defaults) | compliant |
| #3 annotations at boundaries | no new public fns; test helpers annotated anyway | compliant |
| #4 logging | module imports no logging | N/A |
| #5 path handling | no path ops in diff | N/A |
| #6 test quality | all 8 new + 5 adjusted tests, every assertion checked; patch targets verified (function-local `get_pr_merge_mode` import → definition-site patch is correct) | compliant, with the MEDIUM OR-assertion polish noted above |
| #7 resource leaks | subprocess via existing `_run` wrapper | compliant |
| #8 unsafe deserialization | `json.loads` on gh stdout (trusted local tool), narrow except | compliant |
| #9 async | none | N/A |
| #10 import hygiene | no new imports | compliant |
| #11 input validation | pr_number digits-only, validated upstream; no new boundary | compliant |
| #12 dependency hygiene | no dep changes | N/A |
| #13 fix-introduced regression | repo-wide grep: exactly one `gh pr merge` call site; guard applied at the single point of truth — no one-path asymmetry | compliant |
| SOUL #2 / #10 / #14 | probe reuse / no-throw / truthful record | compliant (rule-checker line evidence) |

### Devil's Advocate

Assume this is broken. The nastiest scenario: the pre-check trusts a session-file PR number that points at the WRONG pull request — say a copy-pasted session from a sibling story whose PR already merged. The short-circuit would then bless this story as done while its own code never landed. True — but trace the pre-fix behavior: the same wrong number went straight into `gh pr merge`, which would merge the wrong PR outright (strictly worse), or fail as already-merged and wedge. The diff narrows nothing here; the trust boundary is the session file itself, which is the framework's coordination layer by design. Second attack: gh returns MERGED for a PR that isn't — that requires gh itself to lie on rc=0 with valid JSON, which is the same trust the 155-1 verification already stakes the `done` transition on; no new reliance. Third: retry where run 1 deleted the branch and the session lacks a PR field — `gh pr list --head` filters to open PRs, resolves nothing, `pr_number=None`, Step 2 "skipped," finish completes without any merge verification. That path exists TODAY and is the explicitly accepted product decision from 155-1 (`test_no_pr_finish_still_succeeds_verify_does_not_overreach`, Keith 2026-06-04); in the retry world the PR genuinely is merged, so the outcome is truthful — but it's worth naming that the no-PR acceptance is what backstops this corner, not the new code. Fourth: could gh report a merged PR as DIRTY and false-block the retry at the 155-12 pre-gate before the short-circuit is reached? Real-gh evidence (155-12 review) says merged PRs report UNKNOWN/UNKNOWN → no block; even if gh misbehaved, the block is loud and retryable, not corrupting. Fifth: TOCTOU — MERGED is monotonic on GitHub; no reversal exists. I could not construct a scenario where the diff records `done` for genuinely unmerged code that the pre-existing accepted paths didn't already permit.

**Handoff:** To Faceman (SM) for finish-story

## Delivery Findings

### TEA (test design)

- **Question** (non-blocking): human merge mode completes steps 4b–7 (including session removal) while leaving the story `in_review` — after the human merges, there is no session left for a finish retry to complete the `done` transition. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (human-mode step ordering; may deserve its own story if the resume path is undefined). *Found by TEA during test design.*
- **Improvement** (non-blocking): once the fix lands, Step 2 in auto mode will issue two `gh pr view` calls back-to-back for unmerged PRs (`_pr_block_reason` + the new `_pr_is_merged` pre-check). A single combined `--json state,mergeable,mergeStateStatus` probe could serve both; tests do not pin call counts, so Dev may consolidate freely. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (optional consolidation). *Found by TEA during test design.*

### Dev (implementation)

- **Improvement** (non-blocking): declined TEA's optional gh-call consolidation — kept `_pr_block_reason` and the `_pr_is_merged` pre-check as separate probes (minimal diff; same deferral 155-12's Dev made). A future story could fold state/mergeable/mergeStateStatus into one `gh pr view` call shared by both helpers. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (probe consolidation). *Found by Dev during implementation.*

### Reviewer (code review)

- **Improvement** (non-blocking): confirmed Dev's probe-consolidation deferral; the rule-checker's extra-`gh pr view`-call perf observation folds into that same future consolidation, not new work. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (probe consolidation). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): pin the `already_merged` report key with its own assertion — the OR-form `merged is True or already_merged is True` at test_155_29:545 lets a delete-`already_merged` mutation survive; also add the branch-resolved-PR + already-merged combination test. Same class as backlog story 155-30 (pin key presence in failure-result tests) — fold into 155-30's pass rather than filing new work. Affects `pennyfarthing-dist/src/pf/tests/test_155_29_finish_short_circuit_merged_pr.py` (split the OR into two pinned asserts; one new combo test). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): dry-run preview (story_finish.py:358) still reports "Merge PR #N (squash, delete branch)" for an already-merged PR — `_pr_is_merged` is never consulted in dry-run mode. Cosmetic, pre-existing, out of this story's ACs. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (optionally consult the pre-check in dry-run to preview "already merged — will skip"). *Found by Reviewer during code review.*
- **Question** (non-blocking): the deleted-branch + no-session-PR retry corner completes via the accepted no-PR path (155-1 product decision) rather than the new short-circuit — `gh pr list --head` only returns open PRs, so a merged PR whose branch was deleted resolves to no PR. Outcome is truthful in the retry world, but the backstop is the no-PR acceptance, not verification. Worth a `--state merged` fallback in PR resolution if the no-PR acceptance is ever revisited (relates to the 155-5 sidecar's check_pr_status merged-PR fallback). Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (PR resolution fallback). *Found by Reviewer during code review.*

## Design Deviations

### TEA (test design)
- **Green-on-arrival guard tests included beyond the literal ACs**
  - Spec source: session AC-3 ("test coverage for the short-circuit path")
  - Spec text: "Test coverage for the short-circuit path (already-merged PR with Step 2+ failure scenarios)"
  - Implementation: 4 additional intentional-green guards (unmerged path, genuine failure, probe-error fall-through, human mode)
  - Rationale: the fix's dangerous failure mode is over-application — skipping the load-bearing merge for unmerged/unverifiable PRs; guards make that unimplementable
  - Severity: minor
  - Forward impact: gate/Reviewer must read these 4 as intentionally green, not spurious
- **Sibling test file `test_155_1_finish_verifies_merge.py` modified during RED**
  - Spec source: context-story-155-29.md, Scope ("Out of scope: unrelated changes")
  - Spec text: "In scope: the behavior described by the story title."
  - Implementation: 5 tests pre-adjusted — 4 abort tests now pin `pr_state="OPEN"` (previously relied on the fake's default MERGED, an inconsistent world the new pre-check legitimately turns into success); `test_merges_pr_resolved_by_branch` now uses a stateful OPEN→MERGED fake
  - Rationale: without pre-adjustment, Dev's correct fix breaks 5 sibling tests for the wrong reason; adjustments are fix-agnostic and verified green on HEAD (sidecar pattern `midflow-seam-shares-call-order-with-sibling-guards`)
  - Severity: minor
  - Forward impact: Dev must NOT revert these; Reviewer should treat them as part of the 155-29 contract
- **Step-record truthfulness pinned beyond the ACs**
  - Spec source: epic 155 charter ("Finish/merge/archive truthfulness")
  - Spec text: ACs specify only "short-circuit the merge attempt and proceed"
  - Implementation: `test_short_circuit_step_record_is_truthful` requires the step-2 entry to record merged/already_merged truthy and forbids `skipped`
  - Rationale: a short-circuit reported as "skipped" makes the finish report lie about a landed merge — the exact bug class this epic exists to remove
  - Severity: minor
  - Forward impact: constrains Dev's step-entry shape (documented in the designed interface)

### Dev (implementation)
- No deviations from spec — TEA's designed interface implemented verbatim.

### Reviewer (audit)
- **Green-on-arrival guard tests included beyond the literal ACs** → ✓ ACCEPTED by Reviewer: the guards are what make the fix's over-application unimplementable; mutation 4 (inverted pre-check) confirms they bite — 15/18 killed.
- **Sibling test file `test_155_1_finish_verifies_merge.py` modified during RED** → ✓ ACCEPTED by Reviewer: verified necessary and fix-agnostic — the four `merge_rc=1` tests previously simulated an inconsistent world (merge fails, PR reports MERGED) that the correct fix legitimately reinterprets; `pr_state="OPEN"` is the honest simulation of their original intent, and the stateful fake keeps `test_merges_pr_resolved_by_branch` exercising the merge it exists to assert. Test-analyzer independently confirmed the adjusted tests still bind.
- **Step-record truthfulness pinned beyond the ACs** → ✓ ACCEPTED by Reviewer: SOUL #14 enforcement, exactly this epic's charter; mutations 2 and 5 (key deletion / skipped-swap) are killed by the pin.
- Dev logged no deviations — verified: implementation matches TEA's designed interface verbatim (diff read line-by-line).