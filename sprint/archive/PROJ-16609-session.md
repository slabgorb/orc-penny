---
story_id: "150-9"
jira_key: "PROJ-16609"
epic: "PROJ-16564"
workflow: "tdd"
---
# Story 150-9: Reviewer subagents need full file context, not just diffs

## Story Details
- **ID:** 150-9
- **Jira Key:** PROJ-16609
- **Epic:** PROJ-16564
- **Workflow:** tdd
- **Repos:** pennyfarthing
- **Branch:** feat/150-9-subagent-full-file-context
- **Stack Parent:** none

## Story Context

### Problem
Some reviewer subagents receive only diff hunks, which is insufficient for cross-file pattern analysis. When a subagent sees only `+field: String` in a diff, it can't determine if the surrounding type already has validation, if the pattern is consistent with other types in the file, or if invariants are maintained across related files.

From orc-ax experience, 4 subagents need full file reads (not just diffs):
- `reviewer-security` — needs to see full type definitions to check trust boundaries
- `reviewer-edge-hunter` — needs surrounding code to find boundary conditions
- `reviewer-test-analyzer` — needs full test files to assess coverage completeness
- `reviewer-rule-checker` — needs full files to check every rule against every function

The other 5 subagents work fine with just diffs.

### Approach — Per-Subagent File Context Mode
Extend the `pf.reviewer.diff_mode` module (from 150-7) with a `file_context` field that indicates whether a subagent should also receive full file contents for changed files.

1. Add `SUBAGENT_FILE_CONTEXT: dict[str, bool]` mapping each subagent to whether it needs full file context
2. Add `get_changed_files(base_branch: str) -> list[str]` utility to get list of changed files from diff
3. Add `needs_file_context(subagent_name: str) -> bool` convenience function
4. The reviewer agent reads this config when spawning subagents and includes full file contents for those that need it

### Acceptance Criteria
- [ ] Each subagent has a defined file_context mode (True/False)
- [ ] security, edge-hunter, test-analyzer, rule-checker require full file context
- [ ] simplifier, comment-analyzer, type-design, silent-failure-hunter, preflight do not
- [ ] get_changed_files() returns file paths from diff against base branch
- [ ] needs_file_context() returns correct boolean per subagent
- [ ] Tests verify all assignments and utility functions

## Workflow Tracking
**Workflow:** tdd
**Phase:** red
**Phase Started:** 2026-03-20T22:00:22Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-20T00:00:00Z | 2026-03-20T22:00:22Z | 22h |
| red | 2026-03-20T22:00:22Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

## Reviewer Assessment

**Verdict: APPROVED**

### Spec Compliance

1. **File context assignments match story spec** -- security, edge-hunter, test-analyzer, rule-checker are True; simplifier, comment-analyzer, type-design, silent-failure-hunter, preflight are False. Matches acceptance criteria exactly.

2. **Registry consistency with SUBAGENT_DIFF_MODES** -- `SUBAGENT_FILE_CONTEXT` keys are identical to `SUBAGENT_DIFF_MODES` keys (all 9 subagents). Tests enforce this with `set(SUBAGENT_FILE_CONTEXT.keys()) == set(SUBAGENT_DIFF_MODES.keys())`.

3. **`needs_file_context()` and `get_changed_files()`** -- Both implemented per spec. `needs_file_context()` raises KeyError for unknown subagents. `get_changed_files()` returns file paths from git diff.

### Security Review (subprocess)

- **No `shell=True`** -- uses list form `["git", "diff", ...]`, safe from command injection (CWE-78).
- **No user input interpolation** -- `base_branch` is passed as a single list element via f-string into the arg list (not shell-interpolated). The three-dot syntax `{base_branch}...HEAD` is a single argument to git. An adversarial base_branch value would cause a git error, not command injection, because `shell=False`.
- **`check=True`** -- CalledProcessError propagated on failure rather than silently swallowed.
- **`capture_output=True`** -- stdout/stderr captured, not leaked to parent process output.

### Python Lang-Review Checklist (13 checks)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1 | Silent exception swallowing | PASS | No try/except blocks |
| 2 | Mutable default arguments | PASS | Only `None` defaults |
| 3 | Type annotations at boundaries | PASS | All public functions fully annotated (params + return) |
| 4 | Logging | PASS | No logging module used; errors propagate via exceptions |
| 5 | Path handling | PASS | No path manipulation |
| 6 | Test quality | PASS | Specific assertions, correct mock.patch targets (patching where used in `pf.reviewer.diff_mode.subprocess.run`), parametrized tests cover distinct code paths |
| 7 | Resource leaks | PASS | subprocess.run auto-closes; no open() calls |
| 8 | Unsafe deserialization | PASS | No pickle/eval/yaml.load |
| 9 | Async pitfalls | PASS | No async code |
| 10 | Import hygiene | PASS | No star imports; `subprocess` is stdlib, no circular risk |
| 11 | Input validation | PASS | Not a user-facing boundary; internal API |
| 12 | Dependency hygiene | PASS | Only stdlib `subprocess` added |
| 13 | Fix-introduced regressions | PASS | No fix commits to re-scan |

### Test Coverage

21 tests covering:
- Registry existence and shape (3 tests)
- True/False assignments per subagent (9 parametrized tests)
- `needs_file_context()` convenience function (4 tests including KeyError)
- `get_changed_files()` with mocked subprocess (5 tests: normal, empty lines, cwd, empty diff, error propagation)

### Notes

- Clean, minimal implementation. No over-engineering.
- Module docstring could be updated to mention file context (currently only mentions diff mode), but this is cosmetic and non-blocking.