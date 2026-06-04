---
story_id: "155-1"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-1: Finish flow marks story done while PR stays open — merge_pr no-op (gh #71/#60)

## Story Details
- **ID:** 155-1
- **Jira Key:** (none — Jira not enabled)
- **Workflow:** tdd
- **Stack Parent:** none (stack root)

## Workflow Tracking
**Workflow:** tdd
**Repos:** pennyfarthing
**Phase:** finish
**Phase Started:** 2026-06-04T10:10:07Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-04T09:20:24.537846Z | 2026-06-04T09:24:03Z | 3m 38s |
| red | 2026-06-04T09:24:03Z | 2026-06-04T09:30:18Z | 6m 15s |
| green | 2026-06-04T09:30:18Z | 2026-06-04T10:02:59Z | 32m 41s |
| review | 2026-06-04T10:02:59Z | 2026-06-04T10:10:07Z | 7m 8s |
| finish | 2026-06-04T10:10:07Z | - | - |

## SM Assessment

**Story:** 155-1 — Finish flow marks story done while PR stays open (merge_pr silent no-op). p1 bug, 3pts, TDD, repo `pennyfarthing` (gitflow → `develop`).

**Setup complete:**
- Branch `feat/155-1-finish-flow-merge-pr-noop` created off `develop` in `pennyfarthing/`.
- Session + epic/story context written. Story context enriched with ground truth from gh #71/#60 and confirmed root cause in `story_finish.py:237–290` (Step 2 merges only when `pr_number` set, only warns on failure, and `transition_story(..., "done")` runs at L287–288 with no guard that the merge actually landed).
- `**Repos:**` line added to session (issue #71 flagged sm-setup had dropped it).
- Jira: explicitly skipped — local kanban, no Jira sprint integration.
- Merge gate: clear (no open PRs in either repo).

**Handoff to TEA (Igor):** RED phase. Target failing tests:
1. Finish must NOT flip status to `done` / archive / remove session while the PR is OPEN/unmerged.
2. `merge_pr` must find+merge an open PR even when `pr_number` is unset (by head branch), or fail loud.
3. A merge no-op/failure must surface a non-zero/explicit error, not a silent "Complete".

See `sprint/context/context-story-155-1.md` for full technical approach, references, and ACs.

<!-- CYCLIST:HANDOFF:/tea -->

## TEA Assessment

**Tests Required:** Yes
**Reason:** p1 data-integrity bug; behavior is testable in isolation with mocked `gh`.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_1_finish_verifies_merge.py` — finish must verify the PR actually merged before transitioning the story to `done`.

**Tests Written:** 10 tests (8 failing = RED, 2 passing = intentional regression guards)
**Status:** RED confirmed — scoped run `uv run pytest src/pf/tests/test_155_1_finish_verifies_merge.py -q` → `8 failed, 2 passed`, no collection errors. Failures are on assertions, not imports.

**Coverage by behavior (maps to ACs in context-story-155-1.md):**
| Behavior | Test(s) | Status |
|----------|---------|--------|
| Failed `gh pr merge` (rc≠0) aborts finish | `test_returns_failure_when_gh_merge_returns_nonzero` | failing |
| Merge-failure result carries an error msg | `test_failure_result_mentions_the_pr` | failing |
| Session NOT removed on merge failure | `test_session_not_removed_when_merge_fails` | failing |
| No `done` transition on merge failure | `test_does_not_transition_to_done_when_merge_fails` | failing |
| merge rc 0 but PR OPEN → abort (verify state) | `test_aborts_when_pr_state_is_not_merged` | failing |
| Session kept when PR not merged | `test_session_kept_when_pr_not_merged` | failing |
| No `done` transition when PR not merged | `test_does_not_transition_to_done_when_pr_not_merged` | failing |
| Unresolvable PR in auto mode → not marked done | `test_does_not_mark_done_when_no_pr_resolvable` | failing |
| Out-of-band PR resolved by branch → merged (guard) | `test_merges_pr_resolved_by_branch` | passing (already-working fallback) |
| Clean verified merge → done + session removed (guard) | `test_clean_merge_marks_done_and_removes_session` | passing |

### Rule Coverage

| Rule (python.md) | Test(s) | Status |
|------------------|---------|--------|
| #1 Silent exception swallowing / SOUL "No Silent Fallbacks" — merge step must not warn-and-proceed | all 8 abort tests | failing |
| #6 Test quality — no vacuous assertions | self-check (below) | pass |
| #10 (SOUL) Return Results, Don't Throw — failure surfaced as `{success: False, error}` | `test_returns_failure_*`, `test_failure_result_mentions_the_pr` | failing |

**Rules checked:** 3 of applicable lang-review/SOUL rules have coverage (the bug is squarely rule #1).
**Self-check:** 0 vacuous tests — every test has a meaningful assertion with a value check (no `assert True`, no `let _ =`, no bare truthy on always-None).

### Verification Contract for Dev (GREEN)
1. In `auto` merge mode, after `gh pr merge`, a non-zero return must **abort** finish: return `{success: False, error}`, do NOT transition to `done`, do NOT remove the session.
2. After a 0-return merge, **verify** the PR actually landed via `gh pr view <pr> --json state`; treat any state other than `MERGED` as a hard failure (same abort behavior). This is the load-bearing fix for the silent no-op.
3. In `auto` mode with no PR resolvable (not in session, none found by `gh pr list --head <branch>`), do NOT silently flip to `done`.
4. Keep `_run`-issued `gh` calls qualified through `story_finish._run` so the test's command-dispatch mock intercepts them. Do NOT shell out via a different helper.
5. `human` merge mode is already correct (leaves story `in_review`) — do not regress it.

**Handoff:** To Dev (Ponder Stibbons) for implementation (GREEN).

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — Step 2 (Merge PR) rewritten for auto mode: a non-zero `gh pr merge` aborts finish (`success: False`, error, no irreversible cleanup); after a 0-return merge, finish confirms the PR via new `_pr_is_merged()` (`gh pr view <pr> --json state`) and aborts unless `state == MERGED`. Added `import json`. Human merge mode and the no-PR path are unchanged.
- `pennyfarthing-dist/src/pf/tests/test_155_1_finish_verifies_merge.py` — new test suite (10 tests). Revised the no-PR test per the product decision (see deviation).
- `pennyfarthing-dist/src/pf/tests/test_demo_finish_hook.py` — synced the shared `_run` mock to return `{"state":"MERGED"}` so the new `gh pr view` call passes (these tests carry PR #999; demo behavior under test is unchanged).
- `pennyfarthing-dist/src/pf/tests/test_story_finish_no_jira.py` — synced one mock for the same reason (session carries PR #42).

**Tests:** 116 finish-related tests passing (GREEN). Scoped runs only (full suite avoided — `test_git_utils.py` leaks a branch checkout). `test_155_1_finish_verifies_merge.py` → 10/10. Ruff clean on changed files; mypy not installed in venv (not a local gate).
**Branch:** `feat/155-1-finish-flow-merge-pr-noop` (pushed to origin)

**Product decision applied (2026-06-04, Keith):** the verify-merged guard applies **only when a PR exists**. A no-PR auto-finish keeps prior behavior (marks done). Both reported bugs (#71/#60) involved a PR that existed but did not merge, which is fully covered.

**Self-review:**
- [x] Wired into the live finish flow (`finish_story` Step 2) — not a side helper.
- [x] Follows project patterns: returns `{success, error, steps}` (SOUL #10), no silent fallback (SOUL "Fix the System"), `gh` calls qualified through `story_finish._run`.
- [x] ACs met (merge-failure abort, verify-merged, session/done guards); no-PR scoped per decision.
- [x] Error handling: loud failure with PR number + reason in `error`.

**Handoff:** To Reviewer (Granny Weatherwax) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 116 passed/0 failed, 0 smells, ruff clean | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 10 | confirmed 1 (MED), downgraded/noted 6 (LOW), dismissed 1, deferred 2 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 5 | confirmed 2 (1 MED in-scope, 1 LOW), deferred 3 (pre-existing) |
| 4 | reviewer-test-analyzer | Yes | findings | 7 | confirmed 3 (MED coverage gaps), noted 2 (LOW), dismissed 2 (no-action) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 1 | confirmed 1 (LOW, hardening), 1 rule VERIFIED safe |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (5 enabled returned, 4 disabled via `workflow.reviewer_subagents`)
**Total findings:** 7 confirmed (0 Critical/High in-scope, 3 Medium, 4 Low), 5 deferred to follow-up/155-2, 3 dismissed/VERIFIED.

## Reviewer Assessment

**Verdict:** APPROVED

The fix is correct and achieves the story's intent: `finish_story` no longer silently marks a story `done` when the merge failed or did not land. The auto-mode abort paths (story_finish.py:281-302, 303-322) return `{success: False, error}` before any irreversible transition, and `_pr_is_merged` (L110-124) confirms `state == MERGED` via `gh pr view`, failing safe (returns False) on gh error / bad JSON / non-MERGED. Preflight is fully green (116 passed). **No Critical or High finding is introduced by this diff.** All confirmed findings are Medium/Low; the one architecturally significant issue (gh `cwd`) is pre-existing and routed to 155-2.

**Data flow traced:** session file `**PR:** #N` → `_extract_pr_number` (regex `#(\d+)`, digits-only) → `gh pr merge N` → `gh pr view N --json state` → `state == "MERGED"` gate → `transition_story(..., "done")`. Untrusted input (`pr_number`) is numeric-only at the source, so it cannot inject argv flags. Safe.

**Confirmed findings (none blocking):**
- `[SILENT]` **MED** — `_pr_is_merged` conflates a `gh pr view` *infrastructure* failure (auth/network/rate-limit, rc≠0) with "PR not merged", emitting the misleading abort message "PR is not in MERGED state". Still fails *safe* (aborts, never marks done), so non-blocking — but the diagnostic misleads an operator. Recommend a distinct error when `gh pr view` itself errors. (story_finish.py:118-119, 303-322)
- `[SILENT]`/`[EDGE]` **LOW** — Step 1 archives the session (shutil.copy2, L244-247) *before* the Step 2 merge guard, so an abort leaves a stale archive copy and the comment "run no irreversible cleanup" (L279) slightly overpromises. The copy is idempotent on re-run (same name, overwritten) and the live session is preserved, so no data loss. Recommend tightening the comment or moving archive after the merge guard.
- `[TEST]` **MED** — human-merge-mode path (L259-273) has no test in the new suite; behavior is unchanged from prior code but the new `pr_number=None` human branch is uncovered.
- `[TEST]` **MED** — `gh pr view` returncode-failure branch (`_pr_is_merged` L118-119) is untested; `_make_fake_run` hardcodes view rc=0.
- `[TEST]` **MED** — `test_merges_pr_resolved_by_branch` asserts the out-of-band PR was *merged* but not that it was *verified* (`gh pr view` called on it) — the core contract is unasserted on that one path.
- `[SEC]` **LOW** — the branch-resolved PR number (`gh pr list --jq .[0].number`, L202) and `branch` (fed to `--head`, L199) are not validated numeric / safe before reaching subprocess argv. `_run` is list-form (no shell=True) so no code-exec; exploitation needs write access to the local session file. Recommend `re.fullmatch(r"\d+", ...)` on the resolved number and a `--` guard on `--head`. (Session-sourced `pr_number` is already digits-only — VERIFIED safe.)
- `[EDGE]` **LOW** — `json.loads(result.stdout)` then `.get("state")` would raise `AttributeError` (not in the caught tuple) if gh ever returned a JSON scalar/array; and `state == "MERGED"` is case-sensitive. gh's `--json state` always returns an uppercase-enum object, so low risk; recommend an `isinstance(data, dict)` guard for robustness.

**Dispatch tags:** `[EDGE]` edge-hunter (confirmed above), `[SILENT]` silent-failure-hunter (confirmed above), `[TEST]` test-analyzer (confirmed above), `[SEC]` security (confirmed above), `[DOC]` comment-analyzer — subagent disabled via settings, `[TYPE]` type-design — subagent disabled, `[SIMPLE]` simplifier — subagent disabled, `[RULE]` rule-checker — subagent disabled.

### Rule Compliance (python.md lang-review)
- **#1 Silent exception swallowing** — COMPLIANT (improved). The fix's whole purpose is to remove a silent fallback; new abort paths surface `{success: False, error}`. `_pr_is_merged`'s `except (json.JSONDecodeError, ValueError)` is narrow and returns a safe default. No bare `except`, no `except: pass` introduced.
- **#3 Type annotations at boundaries** — COMPLIANT. `_pr_is_merged(pr_number: str) -> bool` fully annotated.
- **#6 Test quality** — COMPLIANT. New tests assert specific values (success bool, error substring, done-transition presence/absence, session existence). No `assert True`, no bare truthy on always-None, no skips. Two helper-robustness nits noted (substring dispatch, `_requested_done` redundant branch) — LOW, non-blocking.
- **#8 Unsafe deserialization / subprocess injection** — COMPLIANT. List-form subprocess throughout (no shell=True); `json.loads` on gh's own machine output, guarded. argv-injection mitigated (numeric pr_number); hardening recommended for the branch-resolved path (LOW).
- **#5 Path handling** — N/A (no new path manipulation).
- **#7 Resource leaks** — N/A (subprocess via shared `_run`, no file handles opened).

### Devil's Advocate
Argue this code is broken. The strongest case: **it works in tests but not in the dogfood**. Every test mocks `gh`; none exercises the real `cwd`/repo-resolution. In this orchestrator, `finish_story` runs with `project_root = get_project_root()` = orchestrator root, and the `gh pr merge`/`gh pr view`/`gh pr list` calls pass **no `cwd`**, so `gh` resolves the repo from the process working directory — the orchestrator repo — while a `pennyfarthing/` story's PR lives in `slabgorb/pennyfarthing`. Result: `gh pr merge <n>` targets the wrong repo, returns non-zero, and my new guard *aborts* the finish. So for the very story under review (155-1, repo pennyfarthing), `pf sprint story finish 155-1` run from the orchestrator root will likely abort rather than complete. A confused user would read "PR #N merge failed … refusing to mark done" and not realise the real cause is wrong-repo resolution, not an unmergeable PR. A malicious user with write access to a session file could craft a `Branch:` value to redirect `gh pr list --head` to a different PR. Under a stressed filesystem, the Step-1 archive `shutil.copy2` can raise unguarded (disk full / permissions), propagating an exception instead of a structured result — violating SOUL #10 for that one path. And `gh pr view` returning lowercase `"merged"` on an enterprise/REST path would spuriously abort a genuinely merged PR. **What survives this scrutiny:** the cwd issue is pre-existing (the old `gh pr merge` already lacked `cwd`) and is 155-2's domain — my change does not introduce it and makes the failure *louder/safer* (abort vs silent-done, which is strictly better for data integrity). The archive-raises and case-sensitivity paths are real but low-probability robustness gaps, not correctness bugs in the happy/abort paths. None rise to Critical/High *for this diff*. The cwd consequence is documented below as a blocking finding for 155-2 and surfaced to the user.

**Handoff:** To SM for finish-story.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): The `gh #71` branch-resolution fallback (`gh pr list --head <branch>`) already exists at `story_finish.py:179-184`, so part of #71 is fixed; the remaining bug is purely the missing post-merge verification + abort guard. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (Step 2). *Found by TEA during test design.*
- **Question** (non-blocking): What is the correct finish behavior for a story that legitimately has **no PR** (direct-commit/trivial workflows) in `auto` mode? The tests assert "do not silently mark done when nothing merged," but a no-PR workflow may want a different path. Dev/Reviewer to confirm the intended contract. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by TEA during test design.*

### Dev (implementation)
- **Resolved** (non-blocking): TEA's open Question above was decided by Keith on 2026-06-04 — no-PR auto-finish keeps prior behavior (marks done); the verify-merged guard applies only when a PR exists. No further action; documented in deviation below. *Found by Dev during implementation.*
- **Improvement** (non-blocking): `gh pr view`/`gh pr merge` now run unmocked in any finish test with a PR-bearing session; several predating tests used a blanket `_run` mock with empty stdout. Consider a shared `gh`-dispatching `_run` fake fixture in a conftest to avoid each finish test re-stubbing it. Affects `pennyfarthing-dist/src/pf/tests/` (finish tests). *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (blocking for **155-2**, not 155-1): `gh pr merge`/`gh pr view`/`gh pr list` in `finish_story` pass no `cwd`, so `gh` resolves the repo from the process working directory. With `project_root` = orchestrator root, finishing a `pennyfarthing/` story targets the wrong repo — `gh pr merge` fails and the new guard aborts. Pre-existing (old `gh pr merge` also lacked `cwd`); the repo-aware fix belongs with the topology work in 155-2. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (gh calls need `cwd`/`--repo` resolved from the story's repo via repos.yaml, as `_git_cleanup` already resolves). *Found by Reviewer during code review.*
- **Improvement** (non-blocking, fast-follow): Add three tests to `test_155_1_finish_verifies_merge.py` — (1) human-merge-mode does not call `gh pr view` and does not transition to `done`; (2) `gh pr view` returncode≠0 aborts finish; (3) out-of-band path asserts `gh pr view` was called on the branch-resolved PR. Affects `pennyfarthing-dist/src/pf/tests/test_155_1_finish_verifies_merge.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_pr_is_merged` should distinguish a `gh pr view` infra failure (rc≠0) from a genuine non-MERGED state, and guard `json.loads` output with `isinstance(data, dict)` / case-insensitive state compare. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py:110-124`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking, pre-existing): Step 5 (`pf sprint epic archive`, L375-379), `_git_cleanup` git calls (L148-152), and the Jira-key fallback (L169-176) all discard subprocess results / swallow exceptions and report success regardless. Not introduced by this story. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** 2 findings (0 Gap, 0 Conflict, 0 Question, 2 Improvement)
**Blocking:** None

- **Improvement:** The `gh #71` branch-resolution fallback (`gh pr list --head <branch>`) already exists at `story_finish.py:179-184`, so part of #71 is fixed; the remaining bug is purely the missing post-merge verification + abort guard. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`.
- **Improvement:** `gh pr view`/`gh pr merge` now run unmocked in any finish test with a PR-bearing session; several predating tests used a blanket `_run` mock with empty stdout. Consider a shared `gh`-dispatching `_run` fake fixture in a conftest to avoid each finish test re-stubbing it. Affects `pennyfarthing-dist/src/pf/tests/`.

### Downstream Effects

Cross-module impact: 2 findings across 2 modules

- **`pennyfarthing-dist/src/pf`** — 1 finding
- **`pennyfarthing-dist/src/pf/sprint`** — 1 finding

### Deviation Justifications

4 deviations

- **Verification mechanism specified as `gh pr view --json state`**
  - Rationale: This is the mechanism both gh #71/#60 explicitly recommend and the only `gh` query that reports merge state hermetically; the test mock dispatches on `view` in the command.
  - Severity: minor
  - Forward impact: Dev must use `gh pr view ... --json state` (not `mergedAt`-only or a git-log probe) for tests to pass as written.
- **Ambiguous no-PR case asserted as failure**
  - Rationale: Aligns with "no silent done"; flagged as a Question in Delivery Findings for Dev/Reviewer to confirm against direct-commit workflows.
  - Severity: minor
  - Forward impact: If a no-PR auto-finish is a legitimate path, this test must be revisited.
- **Revised TEA's no-PR test to assert accepted behavior (success), not failure**
  - Rationale: Both reported bugs (#71/#60) involved a PR that existed but did not merge; the no-PR case was never the reported defect. Preserving 151-3 avoids a behavior regression to legitimate no-PR/direct-commit finishes.
  - Severity: minor
  - Forward impact: No-PR auto-finish still marks done — the open question (should it?) is deferred, recorded in Delivery Findings.
- **Synced two predating finish tests' mocks to model the new `gh pr view` call**
  - Rationale: adding a new external `gh pr view` call legitimately requires PR-bearing finish tests to model it; leaving the mock empty would make the verify (correctly) treat the PR as unmerged
  - Severity: minor
  - Forward impact: future finish tests with a PR-bearing session must stub `gh pr view --json state` → MERGED (see Delivery Findings improvement re: shared fixture)

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Verification mechanism specified as `gh pr view --json state`**
  - Spec source: context-story-155-1.md, Technical Approach #2 / Acceptance Criteria
  - Spec text: "after merge_pr, assert the PR is MERGED ... if not, abort"
  - Implementation: Tests pin the verification contract to `gh pr view <pr> --json state` returning `{"state": ...}` rather than leaving the mechanism open.
  - Rationale: This is the mechanism both gh #71/#60 explicitly recommend and the only `gh` query that reports merge state hermetically; the test mock dispatches on `view` in the command.
  - Severity: minor
  - Forward impact: Dev must use `gh pr view ... --json state` (not `mergedAt`-only or a git-log probe) for tests to pass as written.
- **Ambiguous no-PR case asserted as failure**
  - Spec source: context-story-155-1.md, Scope / gh #71
  - Spec text: "surface a non-zero exit / explicit warning when merge_pr finds nothing to merge"
  - Implementation: `test_does_not_mark_done_when_no_pr_resolvable` asserts `success: False` when no PR is resolvable in auto mode.
  - Rationale: Aligns with "no silent done"; flagged as a Question in Delivery Findings for Dev/Reviewer to confirm against direct-commit workflows.
  - Severity: minor
  - Forward impact: If a no-PR auto-finish is a legitimate path, this test must be revisited.

### Dev (implementation)
- **Revised TEA's no-PR test to assert accepted behavior (success), not failure**
  - Spec source: TEA test `test_does_not_mark_done_when_no_pr_resolvable`; conflicting merged test `test_151_3::test_success_path_unchanged`
  - Spec text: TEA asserted `success: False` for a no-PR auto-finish; the merged 151-3 test asserts `success: True` for the same scenario (identical preconditions, opposite expectations)
  - Implementation: Per product decision (Keith, 2026-06-04, "Allow it"), scoped the verify-merged guard to the PR-exists path only. Renamed the test to `test_no_pr_finish_still_succeeds_verify_does_not_overreach` and flipped its assertion to `success: True` + done-transition requested. Source `else: skipped` (no-PR) branch left unchanged.
  - Rationale: Both reported bugs (#71/#60) involved a PR that existed but did not merge; the no-PR case was never the reported defect. Preserving 151-3 avoids a behavior regression to legitimate no-PR/direct-commit finishes.
  - Severity: minor
  - Forward impact: No-PR auto-finish still marks done — the open question (should it?) is deferred, recorded in Delivery Findings.
- **Synced two predating finish tests' mocks to model the new `gh pr view` call**
  - Spec source: existing tests `test_demo_finish_hook.py`, `test_story_finish_no_jira.py`
  - Spec text: those tests used a blanket `_run` mock with empty stdout and PR-bearing sessions
  - Implementation: changed their `_run` mock stdout to `{"state": "MERGED"}` so the new verification passes; no assertion logic changed (their intent — demo behavior / jira-project finish — is preserved)
  - Rationale: adding a new external `gh pr view` call legitimately requires PR-bearing finish tests to model it; leaving the mock empty would make the verify (correctly) treat the PR as unmerged
  - Severity: minor
  - Forward impact: future finish tests with a PR-bearing session must stub `gh pr view --json state` → MERGED (see Delivery Findings improvement re: shared fixture)

### Reviewer (audit)
- **TEA: "Verification mechanism specified as `gh pr view --json state`"** → ✓ ACCEPTED by Reviewer: pinning to `gh pr view --json state` is the correct, hermetic mechanism recommended by gh #71/#60; the implementation matches and is the only state-reporting query.
- **TEA: "Ambiguous no-PR case asserted as failure"** → ✓ ACCEPTED by Reviewer: correctly raised as a Question and superseded by the product decision below; no residual issue.
- **Dev: "Revised TEA's no-PR test to assert accepted behavior (success)"** → ✓ ACCEPTED by Reviewer: aligns with Keith's 2026-06-04 decision and preserves merged 151-3 behavior; both reported bugs (#71/#60) had a PR, so scoping the guard to the PR-exists path is sound. The deferred "should a no-PR auto-finish ever be allowed?" question is recorded as a non-blocking finding, not a defect.
- **Dev: "Synced two predating finish tests' mocks to model the new `gh pr view` call"** → ✓ ACCEPTED by Reviewer: a new external `gh` call legitimately requires PR-bearing finish tests to model it; the edits change only the mock stdout, not assertion intent. Verified no original assertion was weakened.
- No undocumented deviations found. The implementation matches the logged deviations and the story scope.