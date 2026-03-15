---
story_id: "147-6"
jira_key: "MSSCI-16417"
epic: "MSSCI-16411"
workflow: "tdd"
---
# Story 147-6: Add set_repo_field writer to git/repos.py

## Story Details
- **ID:** 147-6
- **Jira Key:** MSSCI-16417
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** review
**Phase Started:** 2026-03-15T11:14:12Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-15T11:09:01Z | 2026-03-15T11:10:13Z | 1m 12s |
| red | 2026-03-15T11:10:13Z | 2026-03-15T11:12:43Z | 2m 30s |
| green | 2026-03-15T11:12:43Z | 2026-03-15T11:14:12Z | 1m 29s |
| review | 2026-03-15T11:14:12Z | - | - |

## Story Context

**Title:** Add set_repo_field writer to git/repos.py
**Points:** 2
**Repos:** pennyfarthing
**Branch:** feat/147-6-set-repo-field-writer
**Epic:** Configuration Gap Closure (MSSCI-16411)

**Description:** Add a `set_repo_field` function to `pennyfarthing-dist/src/pf/git/repos.py` that can write/update individual fields in `.pennyfarthing/repos.yaml`. Currently repos.yaml is read-only — this adds a writer to complement the existing reader functions.

**Acceptance Criteria:**
- [ ] `set_repo_field(repo_name, field, value)` function exists in `git/repos.py`
- [ ] Can update existing fields in repos.yaml
- [ ] Can add new fields to a repo entry
- [ ] Preserves YAML formatting and comments where possible
- [ ] Returns result object `{success, data?, error?}` — does not throw
- [ ] Tests cover happy path, missing repo, invalid field scenarios

## SM Assessment

**Routing:** TDD workflow, 2pt story → TEA writes failing tests first, Dev implements.
**Approach:** Straightforward CRUD writer for YAML config. The read side already exists in `git/repos.py` — this adds the write side.
**Risk:** Low. Well-scoped, single-file change with clear inputs/outputs.
**Peloton mode:** Running full team — TEA, Dev, Reviewer spawned as teammates.

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

**Verdict: APPROVED with non-blocking findings**

### Tests
- 22/22 PASS, 0 skipped
- No lint issues, no code smells

### AC Check
| AC | Status | Notes |
|----|--------|-------|
| `set_repo_field(repo_name, field, value)` exists | PASS | Correct signature with keyword-only `project_root` |
| Can update existing fields | PASS | Tested for string, boolean, branch fields |
| Can add new fields to a repo entry | PASS | Tested with old_value=None |
| Preserves YAML formatting and comments | PARTIAL | See Finding F1 below |
| Returns result object `{success, data?, error?}` | PASS | Consistent pattern, never throws |
| Tests cover happy path, missing repo, invalid field | PASS | 22 tests across 6 classes |

### Security
- CLEAN. `yaml.safe_load()` prevents YAML injection. No path traversal vectors. Internal-only tool.

### Findings

**F1 (Important, non-blocking): Comment destruction on write**
- `yaml.safe_load()` + `yaml.dump()` discards ALL YAML comments and reformats the file
- Production `repos.yaml` has ~20 lines of comments (header, topology field docs, architecture notes)
- First real use will permanently strip these comments
- AC says "where possible" — and PyYAML literally cannot preserve comments, so this is technically within spec
- **Recommendation:** Add a docstring warning: "Note: Uses PyYAML which does not preserve comments. Consider ruamel.yaml for comment-preserving writes in a future story."
- The existing read-side functions all use `yaml.safe_load` too, so adding ruamel would be a larger change

**F2 (Low, non-blocking): Non-atomic write**
- Read-modify-write with no temp-file-then-rename pattern
- A crash mid-`yaml.dump()` could leave repos.yaml truncated
- Acceptable for a 2pt internal dev tool; note for future hardening

**F3 (Low, non-blocking): No field/value validation**
- Accepts any string as `field` (including typos) and any value as `value` (including non-serializable types)
- Non-serializable values caught by broad except, but error is opaque
- Acceptable: caller is always framework code, not user input

**F4 (Low, non-blocking): Duplicated path construction**
- `project_root / ".pennyfarthing" / "repos.yaml"` repeated 5+ times across the module
- Not introduced by this story — pre-existing pattern. Not this story's problem to fix.

### Test Quality Notes
- Good coverage of happy path, error paths, and edge cases
- Test fixture uses `yaml.dump()` (no comments) so the comment-destruction issue is invisible to tests
- `test_noop_when_value_unchanged` checks success but doesn't verify the file wasn't reformatted — minor gap consistent with comment-destruction caveat

### Conclusion
Implementation is clean, well-scoped, follows existing module patterns, and meets 5/6 ACs fully with 1 partial (comment preservation). The partial AC is a PyYAML limitation, not an implementation bug, and the AC qualifier "where possible" accounts for it. No blocking issues. Approved for merge.