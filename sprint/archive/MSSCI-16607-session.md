---
story_id: "150-7"
jira_key: "MSSCI-16607"
epic: "MSSCI-16564"
workflow: "tdd"
---

# Story 150-7: Reviewer subagents should always diff against base branch, not incremental

## Story Details

- **ID:** 150-7
- **Jira Key:** MSSCI-16607
- **Epic:** MSSCI-16564
- **Workflow:** tdd
- **Repos:** pennyfarthing
- **Branch:** feat/150-7-reviewer-base-branch-diff
- **PR:** #1483 - feat(reviewer): discriminated diff mode per subagent
- **Stack Parent:** none

## Story Context

### Problem
Reviewer subagents currently receive ad hoc diffs with no enforcement of what diff they're working against. Some get incremental diffs (last commit), some get partial file diffs. This causes specialists to miss cross-file interactions and systemic issues.

### Approach — Discriminated Diff Strategy
Not all subagents need the full base-branch diff. Configure per-subagent diff mode based on what each specialist actually needs:

**Full base-branch diff** (`git diff {base_branch}...HEAD`) — specialists that analyze cross-file patterns and systemic issues:
- `reviewer-security` — needs full attack surface visibility
- `reviewer-edge-hunter` — needs all boundary conditions across files
- `reviewer-test-analyzer` — needs full test-to-implementation relationship
- `reviewer-rule-checker` — needs all changed code against all project rules

**Incremental diff is sufficient** (`git diff HEAD~1` or narrower) — specialists doing localized analysis:
- `reviewer-preflight` — lint/build/test pass/fail (no diff needed at all)
- `reviewer-simplifier` — complexity in changed code only
- `reviewer-comment-analyzer` — comments in changed code only
- `reviewer-type-design` — type signatures in changed code only
- `reviewer-silent-failure-hunter` — error handling in changed code only

### Implementation Details
1. Define a `diff_mode` field per subagent (either in agent definition frontmatter or in the reviewer dispatch logic)
2. The reviewer agent's dispatch logic reads the base branch from `repos.yaml` and constructs the appropriate diff for each subagent based on its `diff_mode`
3. Subagents that need full base-branch diff get it injected into their prompt; others get the incremental diff

### Acceptance Criteria
- [ ] Each reviewer subagent has a defined diff mode (full-base or incremental)
- [ ] Reviewer dispatch constructs the correct diff per subagent's mode
- [ ] Base branch is read from repos.yaml, not hardcoded
- [ ] Full-base subagents receive `git diff {base}...HEAD`
- [ ] Incremental subagents receive narrower diff
- [ ] Preflight gets no diff injection (it runs tools, not reads diffs)
- [ ] Tests verify correct diff mode assignment per subagent

## Workflow Tracking

**Workflow:** tdd
**Phase:** green
**Phase Started:** 2026-03-20T18:42:54Z

### Phase History

| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-20T00:00:00Z | 2026-03-20T18:38:24Z | 18h 38m |
| red | 2026-03-20T18:38:24Z | 2026-03-20T18:42:54Z | 4m 30s |
| green | 2026-03-20T18:42:54Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

No upstream findings

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

### Dev (implementation)
- No deviations from spec.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/reviewer/__init__.py` - package init
- `pennyfarthing-dist/src/pf/reviewer/diff_mode.py` - diff mode registry, command construction, subagent convenience function

**Tests:** 23/23 passing (GREEN)
**Branch:** feat/150-7-reviewer-base-branch-diff (pushed)

**Handoff:** To next phase (verify or review)

### Delivery Findings
- No upstream findings during implementation.

## TEA Assessment (RED Phase)

**23 failing tests** committed at `59f7a2e88` in `test_150_7_reviewer_diff_mode.py`.

### Test Structure

| Class | Tests | What It Proves |
|-------|-------|----------------|
| `TestDiffModeRegistry` | 3 | Module exists, all 9 subagents mapped, valid mode values |
| `TestFullBaseDiffAssignment` | 4 | security, edge-hunter, test-analyzer, rule-checker → `full-base` |
| `TestIncrementalDiffAssignment` | 4 | simplifier, comment-analyzer, type-design, silent-failure-hunter → `incremental` |
| `TestPreflightNoDiff` | 1 | preflight → `none` (runs tools, not diff analysis) |
| `TestDiffConstruction` | 5 | `get_diff_command()` builds correct git commands per mode |
| `TestDiffForSubagent` | 5 | Convenience function: subagent name → diff command, with repos.yaml integration |
| `TestConsistencyWithCompletePhase` | 1 | Registry stays in sync with `_SUBAGENT_SETTING_MAP` |

### Implementation Contract for Dev

Create `pf/reviewer/diff_mode.py` with:
1. `SUBAGENT_DIFF_MODES: dict[str, str]` — maps subagent name → diff mode
2. `get_diff_command(mode, base_branch) -> list[str] | None` — builds git diff command
3. `get_diff_for_subagent(name, base_branch=None, repo_name=None) -> list[str] | None` — convenience function
4. When `base_branch` not provided, read from `pf.git.repos.get_default_branch(repo_name)`

## Reviewer Assessment

**Verdict: APPROVED**

**Branch:** `feat/150-7-reviewer-base-branch-diff`
**Tests:** 23/23 passing
**Diff reviewed:** `git diff develop...HEAD` -- 3 new files, 277 lines total

### Checklist Results

| Check | Result | Notes |
|-------|--------|-------|
| Diff mode assignments match story spec | PASS | Full-base: security, edge-hunter, test-analyzer, rule-checker. Incremental: simplifier, comment-analyzer, type-design, silent-failure-hunter. None: preflight. |
| Base branch from repos.yaml, not hardcoded | PASS | Uses `pf.git.repos.get_default_branch()` when `repo_name` provided |
| Full-base subagents get `{base}...HEAD` | PASS | Three-dot merge-base diff confirmed |
| Incremental subagents get `HEAD~1` | PASS | |
| Preflight gets no diff (None) | PASS | |
| Consistency with `_SUBAGENT_SETTING_MAP` | PASS | Test enforces exact key parity, currently 9/9 match |
| Python review checklist (13 checks) | PASS | No violations across all 3 changed files |
| Project patterns (type annotations, docstrings) | PASS | All public functions annotated, Google-style docstrings |

### Findings (non-blocking)

**F1 (low): Hardcoded fallback `"main"` at line 72.** When neither `base_branch` nor `repo_name` is provided, `get_diff_for_subagent` defaults to `"main"`. This is correct for the orchestrator repo but could silently produce wrong diffs for repos using `develop`. The caller is responsible for passing args, and this is documented, but a brief comment on the default would help future readers.

**F2 (info): No `__all__` on `diff_mode.py`.** New public module lacks `__all__`. Adding `__all__ = ["SUBAGENT_DIFF_MODES", "get_diff_command", "get_diff_for_subagent"]` would make the public API explicit. Module is small enough that this is cosmetic.

**F3 (info): `mode` parameter is stringly-typed.** `get_diff_command(mode: str, ...)` accepts only 3 valid values. A `Literal["full-base", "incremental", "none"]` type would catch typos at type-check time. Non-blocking -- test coverage makes this safe, and it matches the style of `_SUBAGENT_SETTING_MAP`.

### Summary

Clean implementation. The module is focused, well-typed, well-documented, and the test suite is thorough with good coverage of both happy paths and error cases. The consistency test linking `SUBAGENT_DIFF_MODES` to `_SUBAGENT_SETTING_MAP` is a strong guard against drift. All acceptance criteria are met. No blocking issues found.