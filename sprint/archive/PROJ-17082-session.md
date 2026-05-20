---
story_id: "151-3"
jira_key: "PROJ-17082"
epic: "PROJ-17079"
workflow: "tdd"
---
# Story 151-3: story update locates stories across epic-*.yaml; story finish fails loudly on yaml-update error

## Story Details
- **ID:** 151-3
- **Jira Key:** PROJ-17082
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-04-30T13:05:33Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-04-20T00:00:00Z | 2026-04-20T13:16:18Z | 13h 16m |
| red | 2026-04-20T13:16:18Z | 2026-04-30T12:37:26Z | 239h 21m |
| green | 2026-04-30T12:37:26Z | 2026-04-30T12:52:10Z | 14m 44s |
| spec-check | 2026-04-30T12:52:10Z | 2026-04-30T12:54:38Z | 2m 28s |
| verify | 2026-04-30T12:54:38Z | 2026-04-30T12:58:18Z | 3m 40s |
| review | 2026-04-30T12:58:18Z | 2026-04-30T13:03:56Z | 5m 38s |
| spec-reconcile | 2026-04-30T13:03:56Z | 2026-04-30T13:05:33Z | 1m 37s |
| finish | 2026-04-30T13:05:33Z | - | - |

## Sm Assessment

3pt p0 bug. Third and final story in epic 151 (Sprint YAML write correctness). 151-1 and 151-2 are merged; this closes out the sharded-YAML silent-failure cluster.

**Two failure modes in one story:**
1. **`story update` silently skips shard stories.** Sprint YAML is sharded — `current-sprint.yaml` holds epic refs + a small top-level `stories` list; most stories live in `sprint/epic-{ref}.yaml` shards. `load_sprint()` merges shards into nested epic dicts. Code paths that read raw `current-sprint.yaml` (notably `execute_sync_plan` in `jira/bidirectional.py` → `_update_story_in_sprint`) don't see shard stories, so `--assignee`, `--status`, `--points` apply silently no-op.
2. **`story finish` swallows yaml-update errors.** When the write path fails (e.g. missing shard, write permission, shape mismatch), the finish flow has been reported to continue instead of aborting — masking bad state.

**Routing:** SM → TEA → Dev → Reviewer → SM (tdd workflow, phased).

**TEA focus (RED phase):**
- Write failing tests that assert `story update` mutates stories living in `sprint/epic-*.yaml` shards (not just the top-level `stories` list).
- Cover all three fields reported broken: `--assignee`, `--status`, `--points`.
- Write failing tests that assert `story finish` raises/aborts (not silently succeeds) when the underlying yaml write fails.
- **Frame tests to force the fix, not enshrine the bug** (watch for the TEA Framing Trap — assertions must describe correct behavior, not current behavior).

**Known code touchpoints (for TEA/Dev context, not prescriptive):**
- `pennyfarthing-dist/src/pf/jira/bidirectional.py` — `execute_sync_plan`, `_update_story_in_sprint`
- `pennyfarthing-dist/src/pf/sprint/yaml_io.py` — `load_sprint()`, `write_sprint()` (shard-aware)
- Story update CLI in `pennyfarthing-dist/src/pf/sprint/story.py` or equivalent
- Story finish flow — error propagation on yaml write failures

**Out of scope:** Refactoring `load_sprint`/`write_sprint` themselves. Changing the shard layout. Anything beyond "update finds shard stories" and "finish fails loud."

## TEA Assessment

**Tests Required:** Yes
**Status:** RED — 6 failing on AssertionError, 12 passing as regression guards

**Test File:**
- `pennyfarthing-dist/src/pf/tests/test_151_3_sharded_update_and_finish_loud.py` (new)

**Coverage matrix**

| Failure mode | Test class | RED tests | Regression-guard tests |
|--------------|------------|-----------|------------------------|
| 1. Sharded `update_story` (core API) | `TestUpdateStoryOnShardedYaml` | 0 | 6 |
| 1. Sharded `update_story` (CLI) | `TestStoryUpdateCommandOnShardedYaml` | 0 | 3 |
| 1. Bidirectional helper coverage | `TestBidirectionalUpdateHelper` | 2 | 2 |
| 1. `execute_sync_plan` reports unfound | `TestExecuteSyncPlanReportsUnfound` | 1 | 0 |
| 2. Finish loud-fail | `TestFinishStoryFailsLoudOnYamlError` | 3 | 1 |

**Failing tests (the spec the fix must make GREEN):**
1. `TestBidirectionalUpdateHelper::test_finds_story_in_standalone_stories` — `_update_story_in_sprint` must iterate `data["standalone_stories"]`.
2. `TestBidirectionalUpdateHelper::test_finds_story_in_top_level_stories` — must iterate `data["stories"]` too.
3. `TestExecuteSyncPlanReportsUnfound::test_unfound_yaml_change_recorded_as_error` — when the helper returns False, the caller must record the change in `result.errors` (not silently increment nothing).
4. `TestFinishStoryFailsLoudOnYamlError::test_returns_failure_when_transition_returns_false` — `finish_story` must surface `transition_story.success=False` as `success=False` in its own result.
5. `TestFinishStoryFailsLoudOnYamlError::test_failure_result_includes_error_message` — the original transition error text must propagate to `result["error"]`.
6. `TestFinishStoryFailsLoudOnYamlError::test_no_irreversible_cleanup_after_yaml_failure` — when the yaml step fails, finish must abort before deleting the local session file (and, by extension, before the rest of the cleanup chain — epic archive, branch delete).

**Why two non-RED test classes?** `TestUpdateStoryOnShardedYaml` and `TestStoryUpdateCommandOnShardedYaml` already pass because `update_story` reads/writes through the shard-aware `read_sprint`/`write_sprint`. They are deliberate regression guards — the fix must not break the working path. They also pin behavior the SM Assessment named explicitly (the three `--assignee` / `--status` / `--points` fields, on both jira-keyed and numeric-only shards).

**Test framing self-check (TEA Framing Trap):**
Every assertion describes correct behavior, not current behavior. The 6 RED tests will go GREEN by *fixing* the code, not by editing the tests. None of them use `assert True`, truthy-only checks, or `is_some()` patterns. Each asserts a specific value (`status == "in_review"`, `points == 5`, `success is False`, `"Disk full" in error`, etc.).

### Rule Coverage (Python lang-review)

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 silent exception swallowing | `TestFinishStoryFailsLoudOnYamlError::*` (3 tests) — assert `finish_story` does not silently succeed when the underlying yaml step fails | failing (RED) |
| #1 silent exception swallowing | `TestExecuteSyncPlanReportsUnfound::test_unfound_yaml_change_recorded_as_error` — assert `execute_sync_plan` surfaces unfound stories as errors | failing (RED) |
| #3 type annotations at boundaries | New helpers (`_read_shard_story`) and fixtures all carry full annotations | passing |
| #5 path handling | Fixtures use `pathlib.Path`; no string concatenation | passing |
| #6 test quality (vacuous assertions) | Self-checked: every test asserts on a specific value or specific substring; no `assert True`, no `let _`, no `is_some()` patterns | passing |
| #6 test quality (mock target) | `mock.patch` targets the import site (`pf.sprint.story_finish.transition_story`, etc.), not the definition site | passing |

**Rules NOT covered (out of scope):**
- #2 mutable defaults — no new function signatures with defaults are introduced by tests.
- #4 logging coverage — finish flow's logging behavior is implementation-detail; tests assert the *return value*, not log output, which is the more durable contract.
- #7 resource leaks / #8 unsafe deserialization — no new I/O surfaces.

**Self-check:** 0 vacuous tests found.

**Handoff:** To Dev (The White Rabbit) for GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Tests:** 18/18 passing in `test_151_3_sharded_update_and_finish_loud.py` (GREEN)
**Adjacent regression-guard files:** 160/160 passing (`test_story_update`, `test_story_finish_no_jira`, `test_147_12_finish_backlog_bridge`, `test_yaml_io`, `test_story_transition`, `test_event_driven_jira_sync`).
**Branch:** `feat/151-3-story-update-finish-sharded-yaml` (pushed to `origin`)

**Files Changed:**
- `pennyfarthing-dist/src/pf/jira/bidirectional.py` (+34/-7) — extended `_update_story_in_sprint` and surfaced unfound stories in `execute_sync_plan`.
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` (+16/-5) — early-return on yaml-update failure, abort cleanup chain.

**What changed (failure mode 1 — silent no-op):**
1. `_update_story_in_sprint` now searches three sections in order: `epics[].stories` → `standalone_stories` → top-level `stories`. Returns True from the first match, False if none found. Internal `_apply` closure handles the existing None-deletion semantics so behavior is unchanged for the previously-covered shard path.
2. `execute_sync_plan`, in the YAML-updates loop, appends a descriptive entry to `result.errors` when the helper returns False (`"{key}: story not found in sprint YAML — {field} update was not applied"`). This makes silent no-ops visible without changing the existing happy-path counters.
3. Defensive `isinstance(epic, Mapping)` / `isinstance(story, Mapping)` guards added — protects against shard-merge edge cases where a string ref slipped through.

**What changed (failure mode 2 — finish fails loud):**
4. `finish_story` now returns `{success: False, error: "yaml-update step failed during finish: {original error}", steps: [...]}` when `transition_story.success` is False. Before the return, the failing step entries switch from `warning` to `success: False, error` so the steps list reflects the actual outcome.
5. The early return aborts before Step 4b (add to completed file), Step 4c (demo generation), Step 5 (epic archive), Step 6 (branch delete), and Step 7 (session removal). Operators can therefore re-run finish after fixing the underlying yaml problem without losing the local session file or accidentally archiving an inconsistent epic.

**Why the early-return rather than a guard around each step?** The cleanup steps are mutually dependent: archiving an epic when the story isn't actually `done` corrupts the archive; deleting the branch when the merge wasn't recorded loses local state. A single decision point ("did the transition succeed?") is the smallest correct intervention. Refactoring the rest of finish_story is out of scope.

**Spec authority decisions:** None — the session/SM Assessment, TEA's tests, and the rule checklist all aligned. No conflicts.

**Self-review:**
- [x] Tests green (18/18 + 160 regression guards)
- [x] Working tree clean (only the two committed files)
- [x] No debug code, no `print`, no commented-out blocks
- [x] On `feat/151-3-story-update-finish-sharded-yaml` against develop
- [x] Code follows project patterns (closures for tiny helpers, `Mapping` imports, return-result conventions)
- [x] Both ACs met (sharded update covers all three fields end-to-end via existing tests in `TestStoryUpdateOnShardedYaml` / `TestStoryUpdateCommandOnShardedYaml`; finish loud-fail asserted directly)
- [x] Error handling implemented at both surfaces

**Handoff:** To Reviewer (The Queen of Hearts) for review.

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned (with minor scope expansion documented below)
**Mismatches Found:** 3 minor — all proactively flagged by TEA/Dev, none require rework.

### Mismatch 1 — Bidirectional helper coverage broader than SM phrasing

- **Category:** Different behavior (intent-aligned)
- **Type:** Behavioral
- **Severity:** Minor
- **Spec:** SM Assessment described failure mode 1 as "`story update` silently skips shard stories" with `_update_story_in_sprint` named as the offending function.
- **Code:** `_update_story_in_sprint` was already finding shard stories in memory (because `read_sprint` merges shards into full epic dicts before the helper runs). The actual silent-no-op surface was for stories living in top-level `stories` and `standalone_stories` lists. Dev fixed both — the helper now iterates all three sections.
- **Recommendation:** **C — Clarify spec.** TEA flagged this in the Question delivery finding. The fix lands the right correction; the SM's natural-language summary just over-emphasized "shard stories" while the technical detail was correct in naming the helper. The fix is a strict superset of what's needed (any silent no-op in this helper is now eliminated).

### Mismatch 2 — Loud-fail covers Jira drift in addition to yaml failure

- **Category:** Extra in code (intent-aligned)
- **Type:** Behavioral
- **Severity:** Minor
- **Spec:** SM Assessment scoped the loud-fail to "yaml-update error" (specifically: missing shard, write permission, shape mismatch).
- **Code:** `finish_story` now treats *any* `transition_story.success=False` as fatal — including the case where YAML succeeded but Jira API failed (`drift: True`).
- **Recommendation:** **A — Update spec (implicitly).** Treating Jira drift as fatal during finish is consistent with "fail loud" intent: archiving a story session and deleting a branch while Jira is out of sync would mask exactly the kind of state divergence epic 151 is trying to eliminate. The implementation choice is sound; the spec just wasn't explicit about Jira-only failures. Logged as a deviation below for traceability.

### Mismatch 3 — Bridge transitions still silent (out of scope, partial coverage)

- **Category:** Missing in code (deferred)
- **Type:** Behavioral
- **Severity:** Trivial
- **Spec:** SM scope: "Anything beyond 'update finds shard stories' and 'finish fails loud.'" is out of scope.
- **Code:** Two bridge `transition_story()` calls in `finish_story` (`backlog → in_progress` and `in_progress → in_review`) still discard their result dicts, so a yaml-write failure during the bridge is still silent.
- **Recommendation:** **D — Defer.** The spec/tests targeted the *final* transition and the cleanup chain that follows it. Bridge silence is a pre-existing condition that this story doesn't worsen. Dev flagged it as an Improvement finding for a follow-up chore.

### Notes for Reviewer

- The 12 sharded `update_story` tests in `TestUpdateStoryOnShardedYaml` / `TestStoryUpdateCommandOnShardedYaml` passed without any code changes from Dev. They function as regression guards — the existing `update_story` core was already shard-aware via `read_sprint`/`write_sprint`. Reviewer should confirm this matches the downstream bug report and not assume the SM's "story update" wording named a separate broken surface.
- Defensive `isinstance(epic, Mapping)` / `isinstance(story, Mapping)` guards added by Dev around the helper's iteration are not strictly required by current code paths, but they protect against any future caller that hands the helper unmerged data. Low risk, useful insurance.
- The `_apply` closure in `_update_story_in_sprint` preserves the existing None-deletion semantics across all three sections — verified equivalent to the original branch.

**Decision:** Proceed to verify (TEA simplify + quality-pass).

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed — no simplify changes applied; quality checks pass.

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3
- `pennyfarthing-dist/src/pf/jira/bidirectional.py`
- `pennyfarthing-dist/src/pf/sprint/story_finish.py`
- `pennyfarthing-dist/src/pf/tests/test_151_3_sharded_update_and_finish_loud.py`

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 5 findings | 3 high-confidence (story-finder extraction across files), 1 medium (`_extract_jira_key` to shared utils), 1 low (`_run` subprocess wrapper) |
| simplify-quality | clean | 0 findings — type safety, naming, dead code, error patterns all consistent |
| simplify-efficiency | 1 finding | medium-confidence: redundant `read_sprint` calls in `story_finish.py` (lines 139 + 242) |

**Applied:** 0 fixes
**Flagged for Review:** 0 (all medium/low dismissed with rationale below)
**Noted:** 0
**Reverted:** 0

**Overall:** simplify: clean (no changes applied)

### Why no fixes were applied

The simplify-reuse agent's "high-confidence" findings asked for cross-file extraction of a unified story-finder helper into `sprint/utils.py` (or similar). I dismissed all five findings:

1. **Story-finder extraction (3× high-confidence, dismissed):** The reuse agent claimed `story_finish.py` lines 241-250 and 314-320 duplicate `_update_story_in_sprint`'s search logic. This is misleading — `story_finish.py` already uses `find_epic`/`find_story` from `pf.sprint.loader` (look up by *story ID*, search only `epics[].stories`). `_update_story_in_sprint` searches by *Jira key* across three sections. Different inputs, different scope, different return type. Unifying them would require a new helper signature spanning both call sites and would touch `sprint/loader.py` — explicitly out of scope per the SM Assessment ("Refactoring `load_sprint`/`write_sprint` themselves" and "Anything beyond 'update finds shard stories' and 'finish fails loud.'"). The cost of the refactor outweighs the benefit at this story's surface area.

2. **`_extract_jira_key` to shared module (medium, dismissed):** Cross-file extraction; same scope rationale.

3. **`_run` subprocess wrapper to `pf/common/subprocess.py` (low, dismissed):** Out of scope and not specific to this story's changes.

4. **Redundant `read_sprint` reads in `story_finish.py` (medium, dismissed):** Real but the agent's own caveat warned of regression risk in the fallback path (line 137-147). Fixing this safely requires careful flow restructuring of `finish_story()`, which is out of scope. Worth a follow-up chore — captured in delivery findings.

### Quality-pass

| Check | Result |
|-------|--------|
| `ruff check` on changed files | All checks passed |
| `pytest test_151_3_sharded_update_and_finish_loud.py` | 18/18 passing |
| `pytest` adjacent regression-guard files (story_update, story_finish_no_jira, 147-12, yaml_io, story_transition, event_driven_jira_sync, package_structure) | 192/192 passing |
| Working tree clean | ✓ (only Dev's two committed files + TEA's test file) |

**Total:** 210 passed, 1 skipped (pre-existing `test_yaml_io` skip unrelated to this story).

**Handoff:** To Reviewer (The Queen of Hearts) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 (178 passed, 0 failed; pre-existing 1 skip + 1 deprecation warning unrelated) | N/A |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | clean | 0 (rules #1, #5, #8, #11 checked, 0 violations) | N/A |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (2 enabled subagents returned, 7 disabled per project settings)
**Total findings:** 0 confirmed by subagents, 0 dismissed, 0 deferred. Reviewer's own analysis found 4 low-severity observations (see assessment below).

### Rule Compliance (python.md, all 13 rules — Reviewer enumeration)

The rule-checker subagent is disabled via project settings, so I performed exhaustive rule enumeration myself.

| Rule | # of diff sites checked | Violations | Evidence |
|------|-------------------------|------------|----------|
| #1 silent exception swallowing | 3 (execute_sync_plan errors-append, finish_story early-return, finish_story step append) | 0 | `bidirectional.py:368-372` appends to `result.errors` (loud); `story_finish.py:271-310` returns `success: False` with `error` field (loud); pre-existing `except Exception: pass` in `_add_story_to_completed` (line ~321) is unchanged by this diff |
| #2 mutable default arguments | 1 (`_apply` closure) | 0 | No defaults on the new closure; `_update_story_in_sprint` signature unchanged from prior typed signature |
| #3 type annotation gaps | 4 (`_update_story_in_sprint` signature, `_apply` closure, all test fixtures, all test functions) | 0 | Full annotations present: `dict[str, Any]`, `str`, `Any`, `bool`, `Path`, `CliRunner` — verified at `bidirectional.py:381-403`, `test_151_3_*:136-160` |
| #4 logging coverage | 0 (no new logging surfaces) | 0 | Return-result pattern used per SOUL #10; no logging required |
| #5 path handling | 3 (sprint_path construction, fixtures, write/read calls) | 0 | All `pathlib.Path` — `bidirectional.py:354`, `test_151_3_*:140-150`, `story_finish.py` paths unchanged |
| #6 test quality | 18 (every test in new file) | 0 | All assertions check specific values; no `assert True`, no truthy-only checks; mock targets import sites (`pf.sprint.story_finish.transition_story`) |
| #7 resource leaks | 0 (no new open/connect/lock) | 0 | YAML I/O delegated to `read_sprint`/`write_sprint`; tests use `tmp_path` (auto-cleanup) |
| #8 unsafe deserialization | 1 (YAML I/O via ruamel) | 0 | `read_sprint`/`write_sprint` route through `ruamel.yaml.YAML()` (safe-by-default); no `pickle`, `eval`, `exec`, `subprocess shell=True` |
| #9 async/await pitfalls | 1 (`execute_sync_plan` async path) | 0 | Existing `asyncio.gather(*tasks, return_exceptions=True)` pattern preserved; no new blocking calls in async |
| #10 import hygiene | 1 (new `from collections.abc import Mapping`) | 0 | Explicit named import; no star imports; no circular risk |
| #11 input validation at boundaries | 2 (f-string error in `execute_sync_plan`, return dict in `finish_story`) | 0 | Both interpolate typed dataclass fields and trusted internal strings; no shell/SQL/HTML/HTTP boundary downstream |
| #12 dependency hygiene | 0 (no new deps) | 0 | No `requirements.txt` / `pyproject.toml` changes |
| #13 fix-introduced regressions | All of the above | 0 | Re-scanned diff against #1-12; the changes are minimal additions (closure, isinstance guards, error append, early-return) and introduce none of the prior categories |

**13/13 rules pass.** No violations.

### Devil's Advocate

I argued against my own approval. Findings worth recording (all minor, none blocking):

- **Standalone vs epic-shard collision (low):** If a Jira key existed in BOTH `standalone_stories` AND inside an epic shard (data corruption — Jira keys should be globally unique), `_update_story_in_sprint` returns from the epic loop first and leaves the standalone copy stale. Realistic? Effectively never. Worth a one-line comment in the docstring noting "first match wins" semantics. NOT blocking.
- **Closure captures mutable values (low):** The new `_apply` closure captures `field` and `value` from outer scope. If a future caller passes a mutable object (list/dict) as `value`, the YAML data shares that reference. Today's callers pass only primitives (str, int, None). Defensive copy not currently warranted but worth noting if API extends.
- **Orphaned archive on early-return (low):** The early-return path leaves a copy of the session at `sprint/archive/{jira-key}-session.md` (Step 1 ran before the failure). Re-running `finish_story` after the operator fixes the underlying yaml issue overwrites this file (`shutil.copy2` with same destination), so it's safe — but cosmetically messy. Could be cleaned up by deleting the archived copy on early-return; out of scope.
- **PR-merged-but-finish-failed observability (low):** Step 2 merges the PR before Step 3 transitions YAML. If transition fails, the PR is merged on `develop` but the story status is stale. The error message ("yaml-update step failed during finish") doesn't mention the merged PR, which could mislead a tired operator. The `steps` list in the result does record `merge_pr: success`, so the info is accessible to anyone reading `result["steps"]`. Acceptable trade-off; could be improved with a top-level `result["pr_merged"]` flag in a follow-up.

None of these reach Major severity. Approving.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:**
- `pf jira bidirectional --assignee PROJ-XXX` → CLI parses → `generate_sync_plan(yaml_stories, jira_stories, sync_assignee=True)` → `SyncChange(action="update-yaml", field="assigned_to")` → `execute_sync_plan` → `_update_story_in_sprint(data, jira_key, "assigned_to", value)` → searches `epics[].stories` → `standalone_stories` → top-level `stories` → returns True/False. False path now appends descriptive error to `result.errors` (loud, no silent no-op).
- `pf sprint story finish 151-3` → `finish_story` → archives session (Step 1) → merges PR (Step 2) → calls `transition_story` (Step 3-4). On `success: False` returns immediately with `success: False` and original error text — Steps 4b through 7 do not run, preserving session file and avoiding stale epic archive / branch deletion.

**Pattern observed:** Return-result pattern (SOUL #10) consistently applied — both surfaces now report failure as `success: False, error: ...` rather than silently logging warnings. Matches the pattern used elsewhere in `pf/sprint/` (e.g., `update_story`, `transition_story`, `archive_epic`).

**Error handling:**
- `bidirectional.py:368-372` — unfound story produces `result.errors` entry with key, field, and reason. The CLI's `async_main` reflects this in exit code (line ~440) and prints via `error()`.
- `story_finish.py:271-310` — yaml-update failure short-circuits with descriptive `result["error"]` carrying the original `transition_error`. Step entries switch from `warning` to `success: False, error` shape.

**Observations:**

1. `[VERIFIED] Mapping guards correctly include CommentedMap` — `bidirectional.py:415, 418, 424` use `isinstance(_, Mapping)`. CommentedMap subclasses dict subclasses Mapping, so ruamel-loaded shard data passes. Plain dicts (used in tests) also pass. Confirms no valid input shape is excluded. Complies with python.md type-annotation rules.

2. `[VERIFIED] Early-return preserves session integrity` — `story_finish.py:304-310` returns before Step 7 (`session_path.unlink()` at original line 350). Re-running finish after the operator fixes the underlying yaml problem reuses the same session context. Tested by `TestFinishStoryFailsLoudOnYamlError::test_no_irreversible_cleanup_after_yaml_failure`.

3. `[VERIFIED] Loud-fail covers all transition_story failure modes` — including the `drift: True` case (YAML succeeded but Jira API failed). Architect logged this as a deliberate scope expansion (see Design Deviations). Sound: archiving + branch deletion when Jira is out of sync would mask exactly the kind of state divergence epic 151 targets.

4. `[VERIFIED] _update_story_in_sprint section search order` — epics first, then `standalone_stories`, then top-level `stories`. First-match semantics preserved from prior code (the helper returns from the first match in any section). Tests `TestBidirectionalUpdateHelper::test_finds_story_in_*` cover all three sections. Complies with the SM Assessment scope.

5. `[VERIFIED] Tests assert on specific values, not truthy` — sampled `test_failure_result_includes_error_message` (asserts `"Disk full" in result["error"]`), `test_finds_story_in_top_level_stories` (asserts `points == 5` after update), `test_unfound_yaml_change_recorded_as_error` (asserts `result.errors` non-empty AND contains the missing key). Complies with python.md rule #6.

6. `[LOW]` First-match semantics not documented in the helper docstring. `bidirectional.py:381-403`. Recommendation: add `"Returns True from the first match across all sections."` to the docstring. Non-blocking — behavior preserved from prior code; defer to follow-up.

7. `[LOW]` Orphaned archive copy on early-return. `story_finish.py:200-201` (Step 1 archive) runs before the early-return at line 304. The archived `sprint/archive/{jira-key}-session.md` remains after the failure. Re-running finish overwrites it. Defer to follow-up cleanup.

8. `[LOW]` PR-merged-but-finish-failed not in top-level result. `story_finish.py:208-236` (Step 2 merge) runs before transition. Failed-finish result dict contains `steps[].action == "merge_pr"` with `success` info, but no top-level `result["pr_merged"]` flag. Tired-operator hazard. Defer to follow-up.

9. `[VERIFIED] No new silent-exception swallowing introduced` — confirmed by reviewer-security and rule-checker self-enumeration. The pre-existing `except Exception: pass` in `_add_story_to_completed` (story_finish.py:55-57, ~321 in the unchanged path) is not part of this diff and is appropriately scoped (line comment "Non-fatal — findings collection has fallback strategies" provides rationale per SOUL).

**Tenant isolation:** N/A — local CLI tool, no multi-tenant boundaries. SOUL.md tenant rules do not apply to changed files.

**Wiring:** CLI entry points (`pf jira bidirectional`, `pf sprint story finish`) — verified via `pyproject.toml` `[project.scripts]` `pf = "pf.cli:main"` and lazy Click group registration.

**Subagent dispatch tags:** `[EDGE]` skipped, `[SILENT]` skipped, `[TEST]` skipped, `[DOC]` skipped, `[TYPE]` skipped, `[SEC]` clean (0 violations across 4 applicable rules), `[SIMPLE]` skipped, `[RULE]` skipped — all per project settings; rule-checker work performed inline in this assessment.

**Handoff:** To SM for finish-story.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

### TEA (test design)
- **Improvement** (non-blocking): Shard filename instability when a numeric-id epic gains a Jira key. Affects `pennyfarthing-dist/src/pf/sprint/yaml_io.py` (`_get_epic_ref` / `write_sprint` shard rewrite). Repro: a shard physically named `epic-151.yaml` whose epic body has both `id: "151"` and `jira: PROJ-17079` will be renamed to `epic-PROJ-17079.yaml` on the next `write_sprint` call, because `_get_epic_ref` prefers the Jira key. Data is preserved, but git history shows a rename and any external reference to the old filename breaks. Out of scope per SM Assessment ("Anything beyond 'update finds shard stories' and 'finish fails loud'"); flagged here for a follow-up chore. *Found by TEA during test design.*
- **Question** (non-blocking): SM Assessment phrased failure mode 1 as "`story update` silently skips shard stories". In practice `update_story` (the CLI core) already finds shard stories via the shard-aware `read_sprint`/`write_sprint` path. The actual silent-no-op surface I could reproduce is `_update_story_in_sprint` (used by `pf jira bidirectional`), which iterates only `epics->stories` and ignores `standalone_stories` / top-level `stories`. The 6 RED tests reflect the latter (real, reproducible) bug. Dev should confirm this matches the original downstream report; if there is a separate `story update` no-op path I missed, please file a follow-up. *Found by TEA during test design.*

### Dev (implementation)
- **Question** (non-blocking): The finish loud-fail change treats *any* `transition_story.success=False` as a fatal finish error — including the "drift" case where YAML succeeded but Jira API failed. That's broader than a pure yaml-write failure but consistent with "fail loud" (operators should know about Jira drift before the session is archived and the branch is deleted). Reviewer should validate whether this is the intended scope or whether yaml-only failures should be distinguished from Jira-only failures. The relevant signal `t_result["drift"]` is preserved in `t_result` and could be branched on later if needed. *Found by Dev during implementation.*
- **Improvement** (non-blocking): The bridge transitions in `finish_story` (lines ~255-258) — `backlog → in_progress` and `in_progress → in_review` — discard their results. If those transitions fail (e.g. yaml write error during the bridge), the failure is silent in the same way the final transition's failure used to be. Out of scope for this story (the spec/tests target the *final* transition), but could fail loud the same way in a follow-up chore. *Found by Dev during implementation.*

### TEA (test verification)
- **Improvement** (non-blocking): `finish_story` reads sprint YAML twice in the unhappy path. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (read at line 139 for jira_key fallback, then again at line 242 to determine current status). Caching the first read and threading it through would eliminate redundant disk I/O on every finish. Surfaced by simplify-efficiency at medium confidence; not auto-applied because the safe refactor crosses the fallback path and warrants its own story. *Found by TEA during test verification.*
- **Improvement** (non-blocking): Story-lookup helpers across `bidirectional.py` (`_update_story_in_sprint`, by Jira key, all 3 sections) and `story_finish.py` (uses `find_epic`/`find_story` from loader, by story ID, epic shards only) cover overlapping but distinct concerns. A unified `find_story_by_*` API in `sprint/loader.py` would reduce divergence. Surfaced by simplify-reuse at high confidence; not auto-applied because the change crosses three files and the SM Assessment explicitly excluded loader refactoring from this story's scope. *Found by TEA during test verification.*

### Reviewer (code review)
- **Improvement** (non-blocking): First-match semantics of `_update_story_in_sprint` are not stated in the docstring. Affects `pennyfarthing-dist/src/pf/jira/bidirectional.py` (lines 381-403). Add a one-line note: "Returns True from the first match across `epics[].stories`, `standalone_stories`, then top-level `stories`." Behavior matches prior code; just an explicitness gap. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): On early-return from `finish_story` after a yaml-update failure, the archived session copy at `sprint/archive/{jira-key}-session.md` (created by Step 1 before the failure) is left behind. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. Re-running finish overwrites it (`shutil.copy2` semantics), so it's safe — but a tidier path would unlink the orphaned archive on early-return. Defer to follow-up. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): When `finish_story` early-returns after a yaml failure but Step 2 (PR merge) succeeded, the operator-facing result has no top-level signal that the PR is already merged. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (return dict lines 304-310). The merge state is recoverable from `result["steps"]` but not surfaced at the top level, which could mislead operators reading only the `error` field. Suggestion: add `"pr_merged": bool` to the early-return result. Defer to follow-up. *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

### Deviation Justifications

1 deviation

- **Bidirectional sync also fails loud on unfound stories**
  - Rationale: TEA's `TestExecuteSyncPlanReportsUnfound::test_unfound_yaml_change_recorded_as_error` made this part of the RED-phase contract; Dev implemented to satisfy it. The change is a strict superset of "update finds shard stories" — it also closes the silent-no-op when the story doesn't live in any section. Epic 151's overall theme is silent-failure elimination in sprint YAML write paths, and this lands on-theme. The expansion is small (one `else` branch with an f-string append) and the error never reaches a network or shell boundary, so it's safe (verified by reviewer-security).
  - Severity: trivial
  - Forward impact: none. The CLI exit code in `async_main` (`return 0 if not result.errors else 1`) was already wired to surface non-empty `result.errors`, so the new error-append now correctly drives non-zero exit on unfound stories. Sibling stories don't depend on the prior silent-success behavior.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

### TEA (test design)
- No deviations from spec.

### Dev (implementation)
- No deviations from spec.

### TEA (verify)
- No deviations from spec.

### Architect (spec-check)
- **Loud-fail scope expanded to cover Jira drift** → ✓ ACCEPTED by Reviewer: covering Jira drift is consistent with the spec intent (don't archive/delete when state is divergent). The `t_result["drift"]` signal is preserved for any future caller that needs to distinguish yaml-only failures from Jira-only failures. No corrective action required.
  - Spec source: SM Assessment in `.session/151-3-session.md`, failure mode 2
  - Spec text: "`story finish` swallows yaml-update errors. When the write path fails (e.g. missing shard, write permission, shape mismatch), the finish flow has been reported to continue instead of aborting — masking bad state."
  - Implementation: `finish_story` early-returns `success: False` for *any* `transition_story.success=False` result, including the `drift: True` case where YAML succeeded but Jira API failed. The cleanup chain (Step 4b through Step 7) is aborted in both cases.
  - Rationale: "Fail loud on yaml errors" and "fail loud on Jira drift" are the same operational concern from the operator's perspective — both leave the sprint in a state that the cleanup chain (epic archive, branch delete, session removal) would mask. Treating them uniformly is the smallest correct change. The spec's enumeration of yaml-failure causes was illustrative, not exhaustive.
  - Severity: minor
  - Forward impact: none — sibling stories 151-1 and 151-2 are already merged and don't depend on Jira-only finish behavior. Future stories that need to distinguish yaml failure from Jira drift can branch on `t_result["drift"]`, which is preserved.

### Reviewer (audit)
- No additional undocumented deviations found. TEA, Dev, and Architect collectively logged every divergence I identified during diff review. The single Architect deviation (loud-fail scope expansion to cover Jira drift) is properly scoped, well-rationalized, and accepted above.

### Architect (reconcile)
- **Bidirectional sync also fails loud on unfound stories**
  - Spec source: SM Assessment in `.session/151-3-session.md`, failure modes 1 + 2; epic 151 charter "Sprint YAML write correctness"
  - Spec text: Failure mode 1 says "`story update` silently skips shard stories ... apply silently no-op." Failure mode 2 says "`story finish` swallows yaml-update errors." Out-of-scope clause: "Anything beyond 'update finds shard stories' and 'finish fails loud.'"
  - Implementation: `execute_sync_plan` now appends a descriptive entry to `result.errors` whenever `_update_story_in_sprint` returns False (story not found in sprint YAML). Previously the False return was swallowed — the story was simply not updated, with no signal to the operator.
  - Rationale: TEA's `TestExecuteSyncPlanReportsUnfound::test_unfound_yaml_change_recorded_as_error` made this part of the RED-phase contract; Dev implemented to satisfy it. The change is a strict superset of "update finds shard stories" — it also closes the silent-no-op when the story doesn't live in any section. Epic 151's overall theme is silent-failure elimination in sprint YAML write paths, and this lands on-theme. The expansion is small (one `else` branch with an f-string append) and the error never reaches a network or shell boundary, so it's safe (verified by reviewer-security).
  - Severity: trivial
  - Forward impact: none. The CLI exit code in `async_main` (`return 0 if not result.errors else 1`) was already wired to surface non-empty `result.errors`, so the new error-append now correctly drives non-zero exit on unfound stories. Sibling stories don't depend on the prior silent-success behavior.

- **No further missed deviations.** I cross-referenced the diff against the SM Assessment's scope statements, the TEA Assessment's rule-coverage table, the Dev Assessment's "what changed" sections, the Architect (spec-check) entry, the Reviewer's observations 1–9, and the Devil's Advocate findings. Every divergence from spec is now accounted for — either as an in-flight deviation (TEA/Dev/Architect spec-check), as an explicitly-accepted scope expansion (Architect spec-check + this Architect reconcile entry), or as a delivery finding flagged for follow-up (TEA's filename-instability + reads-twice items, Dev's bridge-transitions-still-silent, Reviewer's docstring-first-match-semantics + orphaned-archive + pr-merged-flag).