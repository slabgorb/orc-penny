# Story Context: MSSCI-14259

## Migrate Existing YAML Files to Canonical Format

**Epic:** MSSCI-14253 (Sprint Data Management System)
**Points:** 2 | **Workflow:** trivial | **Priority:** P1

## Overview

Run `/sprint validate --fix` on all sprint YAML files, verify formatting matches the template, and update ADR-0018 to reflect the Python implementation.

## Technical Approach

This is an operational "run the tools we built" story. The `validate_sprint_yaml(path, fix=True)` function from 76-2 handles canonicalization by reading with `read_sprint()` and writing back with `write_sprint()` — applying canonical key ordering, block scalars, 2-space indent, no trailing whitespace, and atomic writes.

The migration must be safe and verifiable. Each file is validated first (read-only), backed up, then fixed. After fixing, structural comparison (parsing both before/after with `yaml.safe_load` and comparing data structures) confirms only formatting changed. The second deliverable is updating ADR-0018 to document the Python module architecture alongside the existing bash scripts.

## Files to Modify

| File | Change |
|------|--------|
| `sprint/current-sprint.yaml` | Canonicalize key ordering, block scalars, indentation |
| `sprint/future.yaml` | Canonicalize (non-standard structure, may need assessment) |
| `sprint/completed.yaml` | Canonicalize (non-standard structure) |
| `sprint/archive/*.yaml` | Canonicalize all archive files |
| `pennyfarthing/docs/adr/0018-sprint-yaml-script-access.md` | Add Python module architecture, deterministic serialization |

## Migration Procedure

1. Inventory all sprint YAML files (9 files across `sprint/` and `sprint/archive/`)
2. Run `validate_sprint_yaml(path, fix=False)` on each to establish baseline
3. Categorize by structure type (standard, completed-stories, consolidated archive, non-standard)
4. Back up originals to `.bak` files
5. Run `validate_sprint_yaml(path, fix=True)` starting with standard-format files
6. Diff originals vs fixed — confirm only formatting changes
7. Verify data integrity: `yaml.safe_load(original) == yaml.safe_load(fixed)`
8. Run validation again to confirm all clean
9. Remove backups, commit

## ADR-0018 Update Plan

- **Decision section:** Note Python modules supplement bash scripts; core principle unchanged
- **Add Python module architecture:** `yaml_io.py`, `validate_cmd.py`, `cli.py`, etc.
- **Add Deterministic Serialization section:** Document canonical format guarantees
- **Update References:** Add links to new Python modules, keep bash script references

## Verification Strategy

- Parse before/after with `yaml.safe_load()` and compare data structures
- Post-fix validation: zero format issues on all files
- Visual diff review for each file
- Special attention to JSON archive file (`sprint-12-completed-epics.yaml`) — converts to YAML

## Dependencies

- **76-1 (yaml_io):** Complete and passing — provides `read_sprint`, `write_sprint`
- **76-2 (validate_cmd):** Complete and passing — provides `validate_sprint_yaml(fix=True)`
- No dependency on 76-3, 76-4, or 76-5

## Risks

- Non-standard archive structures may fail schema validation (acceptable, format still canonicalizes)
- JSON archive file converts to YAML (expected, verify data integrity)
- Unknown keys preserved at end of mappings (confirmed by `_sort_mapping` behavior)
- Comments may shift during key reordering (acceptable for section headers)
