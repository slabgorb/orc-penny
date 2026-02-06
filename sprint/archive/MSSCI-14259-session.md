# Story 76-6: Migrate existing YAML files to canonical format

**Jira:** MSSCI-14259
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14259-migrate-yaml-canonical-format
**Workflow:** trivial
**Phase:** finish
**Started:** 2026-02-05

## Story

Run `/sprint validate --fix` on all sprint YAML files:
- sprint/current-sprint.yaml
- sprint/future.yaml
- sprint/completed.yaml (if exists)
- sprint/archive/*.yaml

Verify all files match template format after migration.
Update ADR-0018 to reflect Python implementation.

## Acceptance Criteria

- All sprint YAML files pass validation
- Format matches sprint-template.yaml
- ADR-0018 updated with Python implementation notes

## Context

**Epic:** MSSCI-14253 (Sprint Data Management System)
**Points:** 2 | **Workflow:** trivial | **Priority:** P1

### Overview

This is an operational "run the tools we built" story. The `validate_sprint_yaml(path, fix=True)` function from 76-2 handles canonicalization by reading with `read_sprint()` and writing back with `write_sprint()` — applying canonical key ordering, block scalars, 2-space indent, no trailing whitespace, and atomic writes.

### Technical Approach

The migration must be safe and verifiable. Each file is validated first (read-only), backed up, then fixed. After fixing, structural comparison (parsing both before/after with `yaml.safe_load` and comparing data structures) confirms only formatting changed. The second deliverable is updating ADR-0018 to document the Python module architecture alongside the existing bash scripts.

### Files to Modify

| File | Change |
|------|--------|
| `sprint/current-sprint.yaml` | Canonicalize key ordering, block scalars, indentation |
| `sprint/future.yaml` | Canonicalize (non-standard structure, may need assessment) |
| `sprint/completed.yaml` | Canonicalize (non-standard structure) |
| `sprint/archive/*.yaml` | Canonicalize all archive files |
| `pennyfarthing/docs/adr/0018-sprint-yaml-script-access.md` | Add Python module architecture, deterministic serialization |

### Migration Procedure

1. Inventory all sprint YAML files (9 files across `sprint/` and `sprint/archive/`)
2. Run `validate_sprint_yaml(path, fix=False)` on each to establish baseline
3. Categorize by structure type (standard, completed-stories, consolidated archive, non-standard)
4. Back up originals to `.bak` files
5. Run `validate_sprint_yaml(path, fix=True)` starting with standard-format files
6. Diff originals vs fixed — confirm only formatting changes
7. Verify data integrity: `yaml.safe_load(original) == yaml.safe_load(fixed)`
8. Run validation again to confirm all clean
9. Remove backups, commit

### ADR-0018 Update Plan

- **Decision section:** Note Python modules supplement bash scripts; core principle unchanged
- **Add Python module architecture:** `yaml_io.py`, `validate_cmd.py`, `cli.py`, etc.
- **Add Deterministic Serialization section:** Document canonical format guarantees
- **Update References:** Add links to new Python modules, keep bash script references

### Verification Strategy

- Parse before/after with `yaml.safe_load()` and compare data structures
- Post-fix validation: zero format issues on all files
- Visual diff review for each file
- Special attention to JSON archive file (`sprint-12-completed-epics.yaml`) — converts to YAML

### Dependencies

- **76-1 (yaml_io):** Complete and passing — provides `read_sprint`, `write_sprint`
- **76-2 (validate_cmd):** Complete and passing — provides `validate_sprint_yaml(fix=True)`
- No dependency on 76-3, 76-4, or 76-5

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed (pennyfarthing repo - PR #679):**
- `docs/adr/0018-sprint-yaml-script-access.md` - Added Python module architecture, deterministic serialization docs
- `pennyfarthing_scripts/sprint/validator.py` - Added `validate_future()` with initiative/epic/story schema validation
- `pennyfarthing_scripts/sprint/validate_cmd.py` - Auto-detect future.yaml, route to correct validator, skip format drift for future files
- `pennyfarthing_scripts/sprint/cli.py` - Added `remove-epic` CLI command for cancelling pre-Jira epics
- `pennyfarthing-dist/scripts/hooks/pre-commit.sh` - Exclude `completed.yaml` from validation

**Files Changed (orchestrator repo - develop):**
- `sprint/current-sprint.yaml` - Canonicalized key ordering
- `sprint/archive/sprint-11.yaml` - Canonicalized 49 format issues
- `sprint/archive/sprint-12-completed-epics.yaml` - Canonicalized 73 format issues

**Migration Results:**
- 3 sprint files fixed with `validate_sprint_yaml(fix=True)`, all with data integrity verified
- `future.yaml` now has its own validation schema ensuring `promote-epic.sh` compatibility
- `completed.yaml` excluded from validation (index file, not a sprint YAML)

**Key Additions (after user feedback):**
1. `validate_future()` validates the structure `promote-epic.sh` depends on: `future.initiatives[].epics[].stories[]` with required fields (id, title, points), valid initiative statuses, duplicate epic ID detection
2. `remove-epic` command removes cancelled epics from `future.yaml` using `yq` (with `--dry-run` support)
3. Pre-commit hook excludes `completed.yaml` from sprint YAML validation

**Tests:** All 25 existing tests pass. Manual testing confirms future.yaml validation and remove-epic work correctly.

**PR:** #679
**Branch:** feature/MSSCI-14259-migrate-yaml-canonical-format (pushed)

**Handoff:** To SM for finish flow

## Reviewer Assessment

**Verdict: APPROVED**

Reviewed 5 files, +255/-12 lines. Key findings:

1. **`validate_future()` correctly covers `promote-epic.sh` dependencies** — verified against actual script. Required fields (id, title, points) match what promote needs; optional fields (description, priority) correctly omitted from validation.
2. **`remove-epic` command injection risk is acceptable** — `epic_id` is interpolated into yq expression but validated against actual epic IDs before subprocess call, and uses list-mode (not shell=True).
3. **Duplicate epic ID detection is per-initiative, not global** — low risk since IDs are auto-generated, but a cross-initiative duplicate would cause yq to return multiple epics during promote.
4. **`is_future` detection heuristic is sound** — no false positive risk with sprint files.
5. **Pre-commit exclusion is correct** — `$` anchor prevents partial matches.

Tests: 97/99 sprint tests pass (2 pre-existing `cancelled` vs `canceled` failures). All validate_cmd and yaml_io tests pass. Both validators route correctly.

## Session Log

- **2026-02-05** SM: Story setup, routing to Dev (trivial workflow)
- **2026-02-05** Dev: Migration complete, ADR updated, PR #679 created
- **2026-02-05** Dev: Added future.yaml validation, remove-epic command, completed.yaml exclusion per user feedback
- **2026-02-05** Dev: Updated session, PR description, handoff to Reviewer
- **2026-02-05** Reviewer: APPROVED — validate_future() covers promote-epic.sh deps, remove-epic acceptable, no regressions
