---
story_id: "155-15"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-15: finish marks story done + archives when auto-merge is blocked/denied (e.g. review-required guardrail) instead of aborting or holding in_review

## Story Details
- **ID:** 155-15
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch Strategy:** gitflow (feat/155-15)
- **Merged PR:** #143 — squash-merged to develop @ d804d01a3 (verified state=MERGED, mergedAt 2026-07-10T10:04:32Z). Merged manually from the pennyfarthing repo context because `finish_story` runs `gh pr merge` from the orchestrator root and cannot resolve a PR in the inlined sub-repo — see Delivery Findings (finish-flow repo-context bug).

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-10T09:55:11Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-10T09:04:31Z | 2026-07-10T09:06:09Z | 1m 38s |
| red | 2026-07-10T09:06:09Z | 2026-07-10T09:20:39Z | 14m 30s |
| green | 2026-07-10T09:20:39Z | 2026-07-10T09:26:47Z | 6m 8s |
| review | 2026-07-10T09:26:47Z | 2026-07-10T09:39:54Z | 13m 7s |
| red | 2026-07-10T09:39:54Z | 2026-07-10T09:43:27Z | 3m 33s |
| green | 2026-07-10T09:43:27Z | 2026-07-10T09:45:12Z | 1m 45s |
| review | 2026-07-10T09:45:12Z | 2026-07-10T09:55:11Z | 9m 59s |
| finish | 2026-07-10T09:55:11Z | - | - |

## Story Context

### Technical Approach

**Bug Class:** "done while PR open" (155-1 failure mode)

When `pf sprint story finish` executes, a silent merge failure must not cause the story to be marked done with an archived session. The current bug: the `merge_pr` step silently fails when a guardrail (e.g. review-required, classifier denial) blocks auto-merge via `gh pr merge`, yet finish continues and archives the session and marks story done anyway.

**Expected behavior:**
- Distinguish "merge blocked/denied" from "no PR present"
- No-PR-exists is legitimately allowed to succeed and mark done
- Merge blocked/denied must NOT mark done; instead abort with clear error or hold in `in_review`
- Session must remain active so state truthfully reflects the open PR

**Investigation targets:**
1. The finish flow orchestration in `pf sprint story finish` (Python package)
2. The `merge_pr` step implementation — why is failure silent?
3. Existing test `test_no_pr_finish_still_succeeds` — review the accepted path that fires on blocked/denied merge
4. The merge guardrail detection logic — distinguish blocked from absent

**Repo:** pennyfarthing (framework)

**Acceptance Criteria:**
- When auto-merge is denied/blocked, finish does NOT mark story done
- Session remains active (not archived/removed)
- Clear error message distinguishes merge-blocked from no-PR
- Test coverage for "merge blocked" case (separate from "no PR" case)

## Sm Assessment

**Routing:** 155-15 (p1, 3pts, bug) → TDD phased workflow → TEA owns RED phase next.

**Why this story now:** Highest-priority available story (p1, tied with 155-14). It is the flagship truthfulness bug of epic-155: `pf sprint story finish` records `done` and archives/removes the session even when the PR never merged because an environment guardrail (review-required / classifier denial) silently blocked `gh pr merge`. This is the "done while PR open" class (155-1), confirmed in the field on story 155-5 / PR #137. Fixing it stops the finish flow from lying about completion state — directly serves SOUL #14 (Prove the Work) and the finish-truthfulness charter.

**Scope for TEA (RED):** Write failing tests that pin the correct behavior:
1. Merge blocked/denied (guardrail) → story NOT marked `done`, session NOT archived/removed, held `in_review` or aborted with clear error.
2. No-PR-present → still succeeds (preserve `test_no_pr_finish_still_succeeds` intent) — this path must remain green.
3. The two paths must be distinguishable — a blocked/denied merge is NOT the same signal as an absent PR.

**Guardrails:** Framework repo (`pennyfarthing/`), branch `feat/155-15`, base `develop`. Return result objects, no throws. Locate the finish orchestration + `merge_pr` step + existing `test_no_pr_finish_still_succeeds`.

**Handoff target:** TEA (Captain Murdock) for RED phase.

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_15_finish_blocked_merge_no_stray_archive.py` — 7 tests covering the "+ archives" half of the blocked/denied-merge bug.

**Tests Written:** 7 tests. **Status:** RED — 2 failing (the new behavior), 5 passing regression guards.

**Root cause pinned (for Dev/GREEN):** In `story_finish.py::finish_story` the step order is `archive_session` (step 1, L396-398) BEFORE `gh pr merge` + `_pr_is_merged` verification (step 2, L423-472). The pre-merge gate `_pr_block_reason` (L189-218) only hard-blocks a *definitively CONFLICTING/DIRTY* PR. A **review-required guardrail** reports `mergeable=MERGEABLE` + `mergeStateStatus=BLOCKED` — neither CONFLICTING nor DIRTY — so it falls through the gate; step 1 copies the session into `sprint/archive/`, then step 2 discovers the merge is blocked and aborts. Sibling 155-1 already made the merge load-bearing (no `done`, session not removed), so the "marks done" symptom is covered — the remaining, currently-failing symptom is the **stray archive copy** left in `sprint/archive/{id}-session.md`.

**Contract the tests pin (behavior, not mechanism):**
1. Blocked/denied merge (`gh pr merge` non-zero, review-required) → `success: False`, **no** file in `sprint/archive/`, `.session` file kept, no `done` transition. *(FAILING — stray archive)*
2. Merge returns 0 but PR never reaches `MERGED` (guardrail no-op) → same abort, **no** stray archive. *(FAILING — stray archive)*
3. No-PR finish is NOT a blocked merge → still archives + marks done + removes session (over-reach guard). *(passing)*
4. Clean verified merge → still archives + marks done + removes session (happy-path regression). *(passing)*

**Suggested GREEN approach (Dev's call):** Either move `archive_session` to AFTER the merge is verified `MERGED`, or extend the pre-merge gate to recognize `mergeStateStatus == BLOCKED` (review-required) and abort cleanly before any irreversible step — mirroring the existing CONFLICTING abort convention (return `{success: False, error: ...}`, consistent with `_pr_block_reason`). Prefer abort-with-clear-message over silent `in_review` hold, for consistency with siblings. Keep the no-PR and clean paths green.

### Rule Coverage

| Rule (python lang-review) | Test(s) | Status |
|------|---------|--------|
| #6 test-quality (meaningful assertions, correct mock target) | all 7 tests assert concrete file-state / result / transition outcomes; `_run` patched where *used* (`pf.sprint.story_finish._run`) | pass (self-check) |
| #1 silent-exceptions (indirect — Dev fix must not swallow the block) | `test_result_is_failure_when_merge_denied` asserts loud `success: False` | failing→enforces |
| #5 path-handling (indirect — archive path correctness) | `_archived_session_files` globs `sprint/archive/*-session.md` | failing→enforces |

**Rules checked:** test-quality self-check applied — 0 vacuous assertions (no `assert True`, no bare truthy on always-None, all mocks patch at use-site). Behavior rules (#1/#5) enforced indirectly via the abort/no-stray-archive assertions; the remaining lang-review checks target Dev's implementation diff, not test-only changes.
**Self-check:** 0 vacuous tests found.

**Handoff:** To Dev (Sergeant B.A. Baracus) for GREEN implementation.

## Dev Assessment

**Status:** GREEN — 74/74 finish-suite tests pass (7 story tests + 67 sibling finish tests). Branch `feat/155-15` pushed to `origin`.

**Change (1 file, minimal):** `pennyfarthing-dist/src/pf/sprint/story_finish.py` — reordered `finish_story` so **Step 2 (merge + `_pr_is_merged` verification) runs before Step 1 (archive_session/archive_dialogue)**. Step report labels (`1`/`1b`/`2`) kept for stability; only execution order changed.

**Why this over the pre-gate alternative:** Extending the pre-merge `_pr_block_reason` gate to catch `mergeStateStatus == BLOCKED` would fix only the *pre-detectable* case. The second failing test models a merge that returns 0 but leaves the PR `OPEN` (guardrail no-op) — that only aborts at the *post-merge* `_pr_is_merged` check, which sits after the archive. Moving the archive after merge verification is the single change that covers **both** abort paths. Consistent with the existing 155-1 convention (merge is load-bearing; abort returns `{success: False, error}` and runs no irreversible step) — now extended to archiving.

**Behavior after fix:**
- Blocked/denied merge (non-zero `gh pr merge`) or un-landed merge (0 but PR not `MERGED`) → abort before archive: **no** stray `sprint/archive/*-session.md`, `.session` kept, story held un-`done`.
- No-PR finish and clean verified merge → still archive as before (guards green).
- CONFLICTING PRs still short-circuit in the earlier pre-merge gate (155-12 green).

**Full-suite note (non-blocking):** `pytest pennyfarthing-dist/src/pf/tests/` shows 30 pre-existing failures **unrelated to this change** — confirmed by re-running with the change stashed: identical failures at baseline. They are environmental: no Jira configured (`test_153_4::test_finish_by_jira_key_from_backlog_completes_ceremony` — "Jira transition failed"), and missing tmux/portrait/init assets (`test_peloton_portrait_panes`, `test_init_justfile`, `test_independence`). This change touches only the archive/merge ordering in `story_finish.py`; it does not touch Jira/transition/tmux paths.

**Handoff:** To Reviewer (Colonel Decker) for adversarial review.

## Delivery Findings

No upstream findings.

### Reviewer (code review)
- **Gap** (non-blocking): Human-merge mode (`get_pr_merge_mode() == "human"`) archives AND removes the session (step 7) while holding the story `in_review`, even though the human has not merged the PR yet. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (human-mode branch + step 7 removal). Pre-existing, NOT introduced by this diff and out of 155-15's auto-merge scope — but it is the same truthfulness class this epic targets. *Found by Reviewer during code review.* → candidate follow-up story in epic 155.
- **Gap** (non-blocking): `finish_story` is invoked with no try/except at the CLI boundary (`pennyfarthing-dist/src/pf/sprint/cli.py:468`); any unhandled exception from `finish_story` surfaces as a raw traceback rather than a clean `ClickException`. Relevant to the HIGH finding below. *Found by Reviewer during code review.*
- **Bug** (non-blocking, round 2, → filed as **155-17**): if the session `copy2` succeeds but the dialogue `copy2` then raises `OSError`, finish aborts (loud, not-done) but leaves a stray `sprint/archive/*-session.md` behind, and the `except` misattributes the failed step to `archive_session` even when the dialogue copy failed. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (archive except block ~L500-508 — clean up partial archive on failure; attribute step to the copy that actually failed). Out of 155-15's blocked-merge AC and near-zero probability, so not blocking. *Found by Reviewer (corroborated by reviewer-type-design + reviewer-test-analyzer) during round-2 re-review.*

### SM (finish)
- **Bug** (blocking-for-automation, → filed as **155-18**): `finish_story` runs `gh pr merge`/`gh pr view` from the orchestrator `project_root`, so for a story whose repo is the inlined `pennyfarthing/` sub-repo it targets the WRONG GitHub repository ("Could not resolve to a PullRequest with the number of 143") and cannot merge or verify the PR. Discovered finishing 155-15: PR #143 lives in `slabgorb/pennyfarthing` but finish ran gh from `slabgorb/pennyfarthing-orchestrator`. Notably, 155-15's own fix behaved correctly — finish ABORTED truthfully rather than marking done with an unmerged PR. Workaround for THIS story: merged #143 manually from the pennyfarthing context (verified MERGED @ d804d01a3), then completed bookkeeping via the no-PR path. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_run` gh calls need the story-repo cwd, resolved via repos.yaml). *Found by SM during finish.*

## Design Deviations

### TEA (test design)
- No deviations from spec. Tests cover every AC in the session context directly (blocked→not-done, session kept, clear/loud failure, distinct from no-PR, coverage for the blocked case separate from the no-PR case).
  → ✓ ACCEPTED by Reviewer: agrees — tests map 1:1 to ACs. (But coverage is incomplete on two axes; see REJECTED findings TEST-1/TEST-2 — that is a coverage gap, not a spec deviation.)

### Dev (implementation)
- No deviations from spec. Implemented the minimal change the failing tests demanded (archive-after-merge reordering); all ACs met, no scope beyond the tests.
  → ✗ FLAGGED by Reviewer: the reorder met the stated ACs but introduced an unlogged behavioral change — moving the unguarded `shutil.copy2` past the irreversible `gh pr merge --delete-branch` widened the blast radius of a copy failure (SOUL #10 no-throw is now violated on the archive step). See REJECTED finding TYPE-1. This should have been logged as a deviation with a forward-impact note.

### Reviewer (audit)
- **Undocumented behavioral change:** Dev's reorder is spec-compliant for the happy/abort paths but silently changed the failure semantics of `archive_session` (now throws past the no-throw boundary after an irreversible merge). Not logged by Dev. Severity: HIGH (see TYPE-1).
  → **RESOLVED (round 2):** Dev round-2 wrapped the archive block in `try/except OSError` returning a result dict; the no-throw contract (SOUL #10) is restored and the change is now explicitly documented in-code (`story_finish.py:482-489`). ✓ ACCEPTED. Residual partial-archive edge deferred to 155-17.
## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A (62 tests green, ruff clean, no smells, no new failures) |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | Disabled via settings (edge paths assessed by Reviewer: abort branches enumerated; human-mode noted) |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | Disabled via settings (assessed by Reviewer: no new swallowed errors; TYPE-1 is the opposite — an un-guarded throw) |
| 4 | reviewer-test-analyzer | Yes | findings | 5 | confirmed 2 (TEST-1 dialogue gap, TEST-2 unverified asymmetry), deferred 3 (2 LOW nits + human-mode coverage) |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings (assessed by Reviewer: reorder comments accurate; "report stability" comment now slightly misleading re print-order) |
| 6 | reviewer-type-design | Yes | findings | 2 | confirmed 1 (TYPE-1 unguarded copy2 after merge — HIGH), confirmed 1 as LOW (steps order cosmetic) |
| 7 | reviewer-security | Yes | clean | none | N/A (no injection/traversal/secret-leak; net security improvement) |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings (assessed by Reviewer: minimal reorder, no over-engineering; test copy-paste noted as LOW) |
| 9 | reviewer-rule-checker | Yes | clean | none | N/A (all 13 python.md checks pass; SOUL #10/#14 pass — see Rule Compliance for the one nuance) |

**All received:** Yes (5 enabled returned, 4 disabled pre-filled)
**Total findings:** 1 confirmed HIGH, 2 confirmed MEDIUM, 3 confirmed LOW; 1 deferred (human-mode, out of scope)

## Rule Compliance

Rubric = `pennyfarthing-dist/gates/lang-review/python.md` (13 checks) + SOUL.md. Diff = 2 files (`story_finish.py` reorder, new test file).

| Rule | Applies to | Verdict |
|------|-----------|---------|
| #1 silent exceptions | `story_finish.py` demo-generate `except` (L602) | PASS — pre-existing, intentionally non-fatal, unchanged by diff |
| #3 type annotations | test methods, helpers | PASS — all 7 tests `-> None`; private helpers exempt |
| #5 path handling | `archive_dir / archive_name` (L481) | PASS — pathlib join; `archive_name` from regex-validated jira_key or YAML-verified story_id |
| #6 test quality | new test file (7 tests) | PASS — no vacuous asserts; mock targets correct (`_run`, `get_pr_merge_mode` patched at source since imported at call-time). NOTE: `_requested_done` has a dead `to_status` kwarg branch (real param is `target_status`) — LOW, harmless |
| #8 unsafe deserialization | gh subprocess calls | PASS — list-form argv, no `shell=True` (all 8 call sites verified by reviewer-security) |
| SOUL #10 return-results-never-throw | every `finish_story` return path | **FAIL on the archive step** — 8/9 irreversible steps return `{success, error}` dicts; the reordered `shutil.copy2` (L482) is the one throw-capable step, now positioned AFTER the irreversible merge. See TYPE-1. |
| SOUL #14 prove-the-work | the fix itself | PASS (intent) — archiving now gated on verified merge; no stray archive that lies about completion. This is the substantive win. |

## Reviewer Observations

- **[TYPE][HIGH]** Unguarded `shutil.copy2` moved past the irreversible merge — `story_finish.py:482`. A copy `OSError` throws past `finish_story`'s no-throw contract into an unhandled traceback at `cli.py:468` (verified: no try/except there), leaving the PR merged + branch deleted but story `in_review`, Jira open, session not removed. Regression in blast radius directly caused by this diff.
- **[TEST][MEDIUM]** Dialogue-archive path (Step 1b, `story_finish.py:485-489`) has ZERO coverage — no test writes a `*-dialogue.md`. A future refactor decoupling 1b from 1 could leave a stray dialogue archive on abort with nothing failing. `test_155_15_...py:126`.
- **[TEST][MEDIUM]** `TestUnverifiedMergeLeavesNoStrayArchive` (`:325`) asserts only success=False + no-stray-archive; unlike the denied-merge class it never asserts session-kept or not-transitioned-to-done, though the module docstring claims both abort paths do. Asymmetric coverage.
- **[TYPE][LOW]** `steps` list now emits non-monotonic labels (2,1,1b,3,…) and the CLI renderer (`cli.py:483`) prints in list order → real-run report shows out-of-order step numbers and diverges from the `--dry-run` preview (still 1,1b,2,…). Cosmetic; no consumer keys on order (verified).
- **[TEST][LOW]** Copy-paste duplication across the 4 `TestBlockedMergeLeavesNoStrayArchive` tests (`:227`) — parametrize/fixture would trim ~60 lines. Nit.
- **[TEST][LOW]** `_requested_done` dead `to_status` kwarg branch (`:204`) references a param name the real `transition_story` doesn't have (`target_status`). Harmless today; stale helper.
- **[VERIFIED]** No injection/path-traversal/secret-leak — all gh/git calls list-form, `archive_name` from `^PROJ-\d+$`-validated key or YAML-verified id; corroborated by reviewer-security (8 subprocess sites, 0 violations). Complies with python.md #5/#8/#11.
- **[VERIFIED]** Result-dict shape stable across all 9 return paths (`success`/`story_id`/`jira_key`/`error`/`steps`); reorder changes `steps` *content* on abort paths (intentional — no archive entry), not the shape. Corroborated by reviewer-type-design + rule-checker.
- **[VERIFIED]** No downstream consumer reads the archived session copy — demo (L570-594), epic-archive (L596-601), git-cleanup (L603-615), session-removal (L617-620) do not depend on archive existing; the archive-before-merge invariant was never load-bearing. Reorder breaks nothing downstream.
- **[DOC]** Reorder comments are accurate; the "kept labelled step 1 for report stability" comment (L478) is now slightly misleading since only the LABEL is stable, not the print order. Minor, ties to the LOW [TYPE] finding.
- **[SILENT]** No new swallowed errors introduced; the change's problem is the opposite (an un-guarded throw — TYPE-1). [EDGE] abort branches fully enumerated; only human-mode remains unpinned (deferred, out of scope). [SIMPLE] change is minimal, no over-engineering.

## Devil's Advocate

Argue the code is broken. The change's own thesis — "don't archive what you didn't finish" — is undermined by the very reordering that implements it. Before this diff, `shutil.copy2` was the FIRST irreversible-ish action, so if the filesystem hiccuped (archive dir read-only after a `umask` change, disk full on a laptop mid-sprint, the session file yanked by a concurrent `pf` invocation, an antivirus lock on macOS), the failure happened before anything shipped: annoying, but the tree was untouched. After this diff, the copy is the LAST thing before the state-machine transition, and it runs immediately after `gh pr merge --squash --delete-branch` has irreversibly landed the code and destroyed the branch. So the single most likely place for an `OSError` now sits precisely on the far side of the point of no return. A stressed filesystem doesn't just produce a stray archive anymore — it produces a *merged, branch-deleted, traceback-crashed* finish where the sprint YAML still says `in_review` and Jira is still open. The operator's mental model ("finish either completes or cleanly aborts") is now false: there is a third state, "shipped but crashed," and nothing surfaces it as a structured result because `cli.py:468` re-raises. A confused user re-running `pf sprint story finish` after that crash hits a *different* path (PR now MERGED, so `_pr_is_merged` passes, archive retried) — probably recovers, but only by luck, not design. A malicious or careless actor can't exploit this (paths are validated, no injection), so the risk is operational, not security. What about the tests? They mock `shutil`/`_run` and never touch a real filesystem, so they can NEVER catch the copy-failure regression — the suite is green precisely because it doesn't test the thing the reorder made worse. And the dialogue path (Step 1b) is invisible to every test, so "no stray archive" is proven only for `*-session.md`, not `*-dialogue.md`. Verdict: the fix is correct for its ACs and a genuine truthfulness win, but it trades a benign stray-file failure mode for a malignant dangling-ship failure mode, and its own test suite is structurally blind to that trade. That is a finding, not a nit.

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] [TYPE] | Unguarded `shutil.copy2` now runs after the irreversible `gh pr merge --delete-branch`; an `OSError` throws past the no-throw contract (SOUL #10) into an unhandled traceback at `cli.py:468`, leaving a merged/branch-deleted PR with the story stuck `in_review` and session un-removed | `story_finish.py:481-489` (throw), `cli.py:468` (no guard) | Wrap the Step 1/1b archive block in try/except; on `OSError` return `{success: False, story_id, jira_key, error, steps}` — matching the loud-but-clean abort used for merge/verify/transition failures. Add a failing test (copy2 raises → result dict, not exception). |
| [MEDIUM] [TEST] | Dialogue-archive path (Step 1b) has zero coverage; a future decoupling could leak a stray `*-dialogue.md` on abort undetected | `test_155_15_...py:126` (no dialogue fixture) | Add a dialogue-file variant: assert `sprint/archive/*-dialogue.md` empty on both abort paths, non-empty on clean merge. |
| [MEDIUM] [TEST] | Unverified-merge abort class asserts less than the denied-merge class (no session-kept / not-done), contradicting the module docstring | `test_155_15_...py:325` | Add `test_session_file_kept_when_merge_unverified` + `test_does_not_transition_to_done_when_merge_unverified`, or parametrize both abort shapes uniformly. |
| [LOW] [TYPE] | `steps` labels non-monotonic on real run; diverges from `--dry-run` preview | `story_finish.py:406-489`, `cli.py:483` | Optional: sort steps by label before printing, or align dry-run order. Not blocking. |
| [LOW] [TEST] | Copy-paste across 4 blocked-merge tests | `test_155_15_...py:227` | Optional: parametrize/fixture. |
| [LOW] [TEST] | `_requested_done` dead `to_status` branch (real param `target_status`) | `test_155_15_...py:204` | Optional: drop or rename branch. |

**Dispatch tags present:** [TYPE] [TEST] [SEC] [RULE] confirmed from enabled subagents; [EDGE] [SILENT] [DOC] [SIMPLE] assessed by Reviewer (subagents disabled via settings — see Subagent Results).

**Rationale:** The core fix is correct and a real truthfulness win (blocked/denied merge no longer leaves a stray session archive; all ACs met; security & rule checks clean). But the reorder introduces a HIGH regression in failure semantics — it moves the one throw-capable step past the irreversible merge, and neither the function nor the CLI boundary guards it, so a copy failure produces a merged-but-`in_review` dangling state (SOUL #10 + #14 violation) that the mocked test suite is structurally unable to catch. This is exactly the "finish lies about state" class epic-155 exists to kill, reintroduced through the back door. Cheap to fix (try/except + one test) and belongs with this change. Rejecting.

**Handoff:** Back to TEA for RED rework — add failing tests for (1) archive copy failure → result dict not exception, (2) dialogue-file no-stray-archive on both abort paths, (3) unverified-merge abort symmetry — then Dev wraps the archive block in try/except to make them green.
## TEA Assessment (rework — round 2)

**Trigger:** Reviewer REJECTED round 1 (HIGH: unguarded `shutil.copy2` after irreversible merge; 2 MEDIUM coverage gaps).

**Tests added (3 new + guards), file `test_155_15_finish_blocked_merge_no_stray_archive.py`:**
- **`TestArchiveCopyFailureReturnsResult`** (2 tests) — **RED driver.** Patches `pf.sprint.story_finish.shutil.copy2` to raise `OSError` on the clean-verified-merge path; asserts `finish_story` returns `{success: False, error}` and does NOT transition to `done`, instead of letting the `OSError` propagate. **Currently FAILING** (OSError propagates) — pins reviewer HIGH TYPE-1.
- **`TestBlockedMergeDoesNotArchiveDialogue`** (3 tests) — regression guards for reviewer MEDIUM TEST-1: no stray `*-dialogue.md` on either abort path; dialogue still archived on clean merge. Pass now; lock the Step-1b coverage gap.
- **`TestUnverifiedMergeLeavesNoStrayArchive`** extended (+2 tests) — reviewer MEDIUM TEST-2: session-kept + not-done symmetry with the denied-merge class. Pass now.
- Cleaned the `_requested_done` dead `to_status` branch (reviewer LOW; real param is `target_status`).

**Status:** RED — 2 failing (copy-failure path), 12 passing. Verified: `pytest test_155_15_...py -q` → 2 failed, 12 passed.

**GREEN instructions for Dev:** Wrap the Step 1/1b archive block (`story_finish.py:481-489`) in `try/except OSError` (or broad `except (OSError, shutil.Error)`), returning `{success: False, story_id, jira_key, error: f"...archive failed: {exc}...", steps}` — matching the loud-but-clean abort convention already used for merge/verify/transition failures. Do NOT swallow (python.md #1); surface the error in the result. That makes both copy-failure tests green while keeping all 12 others green.

**Optional (LOW, Dev's call, non-blocking):** the `steps` report order is non-monotonic on real runs (2,1,1b,3,…) and diverges from `--dry-run`; sort-before-print or relabel if desired — not required for GREEN.

**Handoff:** To Dev (Sergeant B.A. Baracus) for GREEN rework.
## Dev Assessment (rework — round 2)

**Status:** GREEN — story file 14/14 pass; full finish suite green except 3 pre-existing `test_153_4` Jira-transition failures (confirmed identical with this fix stashed — environmental, no Jira configured). Ruff clean. Pushed to `origin/feat/155-15` (0558c6fec).

**Fix (reviewer HIGH TYPE-1):** Wrapped the Step 1/1b archive block in `try/except OSError` (`story_finish.py:481-513`). On a copy failure it appends a failed `archive_session` step and returns `{success: False, story_id, jira_key, error, steps}` — no `done` transition, no session removal. This restores SOUL #10 (no-throw) for the one irreversible-adjacent step the reorder had exposed, matching the loud-but-clean abort used for merge/verify/transition failures. Error is surfaced in the result, not swallowed (python.md #1).

**Reviewer MEDIUM coverage gaps:** addressed by TEA's rework tests (dialogue no-stray-archive on both abort paths + clean-merge archive; unverified-merge session-kept/not-done symmetry) — all green against this code.

**Reviewer LOW (steps ordering):** left as-is (non-blocking, cosmetic; keeping dry-run/real label parity). Noted for optional future polish.

**Resolves the FLAGGED deviation:** the previously-undocumented failure-semantics change (archive throwing past the no-throw boundary) is now explicitly guarded and returns a result dict.

**Handoff:** To Reviewer (Colonel Decker) for re-review.
## Subagent Results (round 2 — re-review of rework)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A (69 green: 14/14 story, 55/55 siblings; ruff clean; 3 test_153_4 failures pre-existing/Jira) |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | Disabled via settings (edge assessed by Reviewer: copy-failure edge on dialogue path found + filed 155-17) |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | Disabled via settings (assessed: OSError surfaced, not swallowed — python.md #1 satisfied) |
| 4 | reviewer-test-analyzer | Yes | findings | 2 | confirmed both MEDIUMs RESOLVED; NEW: partial-archive-on-dialogue-copy-failure (HIGH-confidence but out-of-AC → deferred to 155-17); 1 LOW deferred |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings (assessed: new guard comment accurate; steps-order tradeoff now documented in-code) |
| 6 | reviewer-type-design | Yes | findings | 1 | confirmed HIGH TYPE-1 RESOLVED (OSError sufficient, shape consistent, scope tight); NEW LOW step-misattribution → deferred to 155-17 |
| 7 | reviewer-security | Carried | clean | none | N/A — delta is `except OSError` (no new subprocess/path/injection surface); round-1 security clearance stands |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings (assessed: guard minimal; test copy-paste dup remains LOW, non-blocking) |
| 9 | reviewer-rule-checker | Carried | clean | none | N/A — delta adds a specific `except OSError` (not bare) returning a result dict; python.md #1/#3/#5 + SOUL #10 all still satisfied |

**All received:** Yes (3 re-run enabled returned; security + rule-checker carried from round 1 as delta is orthogonal to their domains; 4 disabled)
**Total findings:** 0 confirmed blocking; 2 deferred to follow-up 155-17 (partial-archive-on-copy-failure + step misattribution); LOWs non-blocking

## Rule Compliance (round 2 delta)

| Rule | Applies to | Verdict |
|------|-----------|---------|
| #1 silent exceptions | new `except OSError as exc` (L500) | PASS — specific exception (not bare); error appended to `steps` AND returned in result. Not swallowed. |
| #3 type annotations | new tests | PASS — all `-> None`; helpers annotated |
| #5 path handling | `archive_dir / archive_name` inside try (L490) | PASS — pathlib, unchanged |
| SOUL #10 return-results-never-throw | archive step | **PASS (fixed)** — the one throw-capable step now returns `{success: False, error, steps}` on `OSError`; parity with merge/verify/transition aborts restored |
| SOUL #14 prove-the-work | fix + coverage | PASS — no stray archive on the blocked/denied merge AC; the residual partial-archive edge (out of AC) is tracked as 155-17, not swept under |

## Reviewer Observations (round 2)

- **[TYPE][RESOLVED]** HIGH TYPE-1 fixed — `story_finish.py:489-518` wraps both `copy2` calls in `try/except OSError`, returns result dict. Verified `OSError` covers PermissionError/FileNotFoundError/ENOSPC/shutil.Error/SameFileError (all OSError subclasses). No unguarded throw remains between archive and the done-transition (next block has its own guard).
- **[TEST][RESOLVED]** Both MEDIUM coverage gaps closed — dialogue no-stray-archive on both abort paths + clean-merge archive (`TestBlockedMergeDoesNotArchiveDialogue`), and unverified-merge session-kept/not-done symmetry. Copy-failure tests mechanically sound (correct mock target, non-vacuous, actually exercises the no-throw contract).
- **[EDGE][DEFERRED→155-17]** Partial stray: if session copy succeeds then dialogue copy raises OSError, a stray `*-session.md` is left + the except misattributes the step to `archive_session`. Out of this story's AC (merge succeeded, not a blocked/denied merge), near-zero probability, LOUD failure, story NOT marked done. Filed as follow-up 155-17, not blocking.
- **[TYPE][LOW]** steps report order still non-monotonic (2,1,1b,3,…); now explicitly documented in-code (L477-480); no consumer keys on order. Acceptable.
- **[SIMPLE][LOW]** Test copy-paste across the two 4-test abort classes remains; harmless parametrize-candidate. Non-blocking.
- **[VERIFIED]** No new security/rule surface — `except OSError` adds no subprocess/path/injection vector; error string echoes only the exception message (no secrets). python.md #1 satisfied (specific catch, surfaced).
- **[SILENT][DOC]** No swallowed errors; guard comment (L482-489) accurately explains the no-throw rationale and the after-merge positioning.

## Devil's Advocate (round 2)

Argue it's still broken. The fix closes the front door but leaves a window cracked: the "no stray archive on ANY abort" spirit of epic-155 is not fully honored, because the except handler runs AFTER the session copy already landed on disk. Inject a disk-full precisely between the session copy and the dialogue copy and you get exactly what this epic exists to eliminate — a `sprint/archive/155-15-session.md` sitting there while finish returns failure. Worse, the error says "archive_session failed" when the session archive actually SUCCEEDED and it was the dialogue that failed — a diagnostic lie that would send an operator debugging the wrong file. A programmatic consumer reading `result["steps"]` sees two contradictory `step: 1` entries. So the code technically satisfies "no-throw" while quietly violating "no-stray-archive" and "accurate diagnostics." Counter: this requires a merge to have SUCCEEDED (so it is categorically not the blocked/denied-merge scenario the story's ACs govern), a dialogue file to exist, and a filesystem to fail between two adjacent copies to the same directory — a conjunction so unlikely that pinning it in THIS story would be gold-plating outside scope. And crucially the failure is loud and the story is NOT marked done — the tracker stays truthful about completion, which is the load-bearing invariant. The residue is a leftover file and a mislabeled step, both recoverable, both now tracked in 155-17. The window is real but small, named, and scheduled — not ignored. Verdict: not a blocker; the story delivers its ACs and the fix is sound. The remaining edge is honest follow-up work, not a reason to loop the pipeline a third time.

## Reviewer Assessment (round 2)

**Verdict:** APPROVED

**Data flow traced:** blocked/denied `gh pr merge` (non-zero) or unverified merge (rc 0, PR≠MERGED) → abort before archive → no stray `sprint/archive/*-session.md` or `*-dialogue.md`, `.session` kept, story not marked done. Clean verified merge → archive session+dialogue → done → session removed. Archive `copy2` OSError → `{success: False, error}`, no done transition (safe because the no-throw contract is restored and the CLI boundary at `cli.py:468` never sees an unhandled exception).

**Pattern observed:** load-bearing-step-then-guarded-abort, consistent across all irreversible steps in `finish_story` (merge, verify, transition, and now archive) — `story_finish.py:442-452, 463-472, 489-518, 584-590`.

**Error handling:** every irreversible step returns a structured result dict on failure; `OSError` on archive is specific (not bare) and surfaced in both `steps` and top-level `error` (python.md #1, SOUL #10).

**Round-1 findings disposition:** HIGH TYPE-1 fixed; MEDIUM TEST-1/TEST-2 fixed; LOW dead-branch fixed; LOW steps-order documented+accepted; LOW copy-paste accepted.

**Deferred (non-blocking):** 155-17 — partial-archive + step-misattribution on dialogue-copy OSError.

**Dispatch tags:** [TYPE] [TEST] resolved from re-run subagents; [SEC] [RULE] carried (delta orthogonal); [EDGE] [SILENT] [DOC] [SIMPLE] assessed by Reviewer (disabled via settings).

**Handoff:** To SM for finish-story.