# Epic 76: Sprint Data Management System (MSSCI-14253)

## Overview

Python-based `yaml_io` module for deterministic sprint YAML operations. Replaces ad-hoc bash script write patterns with validated, atomic, auto-fixing commands.

**Current state:** 15 bash scripts using inconsistent YAML write patterns (yq, heredoc, sed), 11 Python modules that only read
**Target state:** Unified Python `yaml_io` module with deterministic serialization, validation, and atomic writes

## Background

### The Problem

Sprint YAML management has grown organically. Read operations are solid (Python `loader.py`, bash `yq` queries), but write operations are fragile:

- `archive-story.sh` uses shell `>>` redirection (not atomic, can lose data on interrupt)
- `new-sprint.sh` generates YAML via heredoc (no validation of output)
- `sprint-metrics.sh` parses YAML with `grep`/`sed` (breaks on format changes)
- `promote-epic.sh` uses temp files but inconsistent patterns
- Python modules have no write capability at all — `archive.py` is a stub

ADR-0018 says "never directly edit sprint YAML" but the scripts themselves use inconsistent, fragile write patterns. This epic fixes the plumbing.

### Success Criteria (Epic-Level)

- 100% determinism: same input produces byte-identical output
- 100% round-trip integrity: read → write → read = identical
- All format errors auto-repairable via `--fix`
- Atomic writes prevent partial file corruption

## Technical Architecture

### Where Code Lives

```
pennyfarthing/pennyfarthing_scripts/
├── sprint/
│   ├── yaml_io.py          # NEW (76-1): Core read/write/serialize module
│   ├── validate_cmd.py     # NEW (76-2): /sprint validate command
│   ├── story_add.py        # NEW (76-3): /sprint story add command
│   ├── story_update.py     # NEW (76-4): /sprint story update command
│   ├── loader.py           # EXISTING: Read-only queries (keep, yaml_io wraps this)
│   ├── validator.py        # EXISTING: Validation logic (extend for format checks)
│   ├── cli.py              # MODIFY: Register new commands
│   └── __init__.py         # MODIFY: Export new public API
```

### Existing Infrastructure to Build On

| Component | Location | Relevance |
|-----------|----------|-----------|
| `loader.py` | `sprint/loader.py` | Read patterns, `load_sprint()`, `find_epic()`, `find_story()` |
| `validator.py` | `sprint/validator.py` | 406 lines of validation (schema, required fields, status values) |
| `config.py` | `common/config.py` | `get_project_root()`, `load_yaml_config()` |
| `output.py` | `common/output.py` | Colored console output helpers |
| `sprint-template.yaml` | `sprint/sprint-template.yaml` | Canonical key ordering reference |
| `conftest.py` | `tests/conftest.py` | Pytest fixtures: `valid_sprint_data`, `valid_story`, `valid_epic` |

### Dependencies

**Already available:**
- `pyyaml>=6.0` (declared in `pyproject.toml`, used everywhere)
- `click>=8.0` (CLI framework)
- `pytest>=8.0` (testing)
- `pathlib` (stdlib, all path ops use `Path`)

**New dependency needed:**
- `ruamel.yaml` — required for deterministic serialization (comment preservation, key ordering, block scalar control). PyYAML's `yaml.dump()` doesn't support fixed key ordering or block scalar style control. Must be added to `pyproject.toml`.

### Key Design Decisions

#### 1. ruamel.yaml vs PyYAML

Story 76-1 description mandates `ruamel.yaml` for deterministic serialization. This is correct — PyYAML cannot:
- Preserve key ordering (sorts alphabetically with `sort_keys=True`, random without)
- Control block scalar style per-field (description needs `|`, title needs plain)
- Preserve comments (sprint template has section comments)

**Impact:** New dependency. All existing `yaml.safe_load()` callers continue working — `yaml_io` is additive, not a replacement for reads.

#### 2. Canonical Key Ordering

From `sprint-template.yaml`, the canonical field order:

**Sprint:** `name` → `jira_sprint_id` → `jira_sprint_name` → `goal` → `start_date` → `end_date` → `status`

**Epic:** `id` → `type` → `title` → `description` → `priority` → `status` → `repos` → `jira` → `points` → `marker` → `stories`

**Story:** `id` → `jira` → `title` → `description` → `points` → `priority` → `status` → `in_sprint` → `assigned_to` → `started` → `repos` → `workflow` → `acceptance_criteria` → `completed` → `pr` → `delivered_in` → `notes`

#### 3. Atomic Write Pattern

```python
def write_sprint(path: Path, data: CommentedMap) -> None:
    """Atomic write: temp file in same directory + os.replace()"""
    tmp = path.with_suffix('.yaml.tmp')
    with open(tmp, 'w') as f:
        yaml.dump(data, f)
    os.replace(tmp, path)  # atomic on POSIX
```

#### 4. Sprint Dataclass vs Dict

The existing codebase uses plain `dict` everywhere (loader.py, validator.py, all CLI code). Using `ruamel.yaml`'s `CommentedMap` preserves ordering and comments naturally. No need for custom dataclasses — stay consistent with existing patterns.

### Testing Strategy

**Test location:** `pennyfarthing/pennyfarthing_scripts/tests/` (existing pytest infrastructure)

**Run tests:**
```bash
cd pennyfarthing && python -m pytest pennyfarthing_scripts/tests/ -v
```

**Existing fixtures in conftest.py:**
- `project_root` — project root path
- `sprint_yaml_path` — path to current-sprint.yaml
- `valid_sprint_data` / `valid_story` / `valid_epic` — sample data

## Story Breakdown

### 76-1: Core yaml_io module (5 pts, P0, TDD)
**Jira:** MSSCI-14254

Foundation module. Everything else depends on this.

**Deliverables:**
- `yaml_io.py` with `read_sprint()`, `write_sprint()`, `canonical_dump()`
- Round-trip tests proving byte-identical output
- Atomic write tests (verify temp file + rename pattern)

**Key files:**
- Create: `pennyfarthing_scripts/sprint/yaml_io.py`
- Create: `pennyfarthing_scripts/tests/test_yaml_io.py`
- Modify: `pennyfarthing/pyproject.toml` (add `ruamel.yaml` dependency)

**Technical notes:**
- `read_sprint(path)` returns `ruamel.yaml.CommentedMap` (preserves ordering/comments)
- `canonical_dump(data)` applies template key ordering, block scalars for multiline, 2-space indent
- Must handle both `current-sprint.yaml` and `sprint/archive/*.yaml` file formats

---

### 76-2: Sprint validate command (3 pts, P0, TDD)
**Jira:** MSSCI-14255

CLI command wrapping existing `validator.py` + new format validation.

**Deliverables:**
- `/sprint validate` command with `--fix` flag
- Format drift detection (indentation, key ordering, string style)
- Error messages with line numbers and field paths

**Key files:**
- Create: `pennyfarthing_scripts/sprint/validate_cmd.py`
- Create: `pennyfarthing_scripts/tests/test_validate_cmd.py`
- Modify: `pennyfarthing_scripts/sprint/cli.py` (register command)
- Modify: `pennyfarthing_scripts/sprint/validator.py` (extend with format checks)

**Technical notes:**
- Existing `validator.py` has schema validation (required fields, types, status values)
- New: format validation (key ordering vs template, indentation, string style)
- `--fix` reads with `yaml_io.read_sprint()` → `yaml_io.write_sprint()` to canonicalize
- Error format: `epics[1].stories[3].description: wrong string style (expected block scalar)`

---

### 76-3: Sprint story add command (3 pts, P0, TDD)
**Jira:** MSSCI-14256

Add stories to sprint YAML programmatically.

**Deliverables:**
- `/sprint story add <epic-id> "<title>" <points>` command
- Auto-generates next story ID within epic
- Validates epic exists, writes atomically

**Key files:**
- Create: `pennyfarthing_scripts/sprint/story_add.py`
- Create: `pennyfarthing_scripts/tests/test_story_add.py`
- Modify: `pennyfarthing_scripts/sprint/cli.py` (register command)

**Technical notes:**
- ID generation: find max story seq in epic, increment (e.g., `76-6` → `76-7`)
- Insert at end of epic's stories list
- Full validation after insertion (call `validator.validate_full_sprint()`)
- Options: `--type`, `--priority`, `--workflow`, `--jira`

---

### 76-4: Sprint story update command (2 pts, P1, TDD)
**Jira:** MSSCI-14257

Update story fields by ID.

**Deliverables:**
- `/sprint story update <story-id> [field updates]` command
- Auto-cleanup: remove `assigned_to` when status=done
- Finds story across all epics

**Key files:**
- Create: `pennyfarthing_scripts/sprint/story_update.py`
- Create: `pennyfarthing_scripts/tests/test_story_update.py`
- Modify: `pennyfarthing_scripts/sprint/cli.py` (register command)

**Technical notes:**
- Search all epics for story ID (use existing `loader.find_story()` pattern)
- Status transition validation: `backlog → ready → in_progress → done`
- Auto-set `completed` date when status=done
- Auto-remove `assigned_to` when status=done

---

### 76-5: Pre-commit hook for YAML validation (2 pts, P1, trivial)
**Jira:** MSSCI-14258

Git hook that validates sprint YAML before commit.

**Deliverables:**
- Pre-commit hook script
- Runs in <2 seconds
- Clear error messages with fix commands

**Key files:**
- Create: pre-commit hook (location TBD — `.githooks/` or `.husky/`)
- Uses: `pennyfarthing_scripts/sprint/validate_cmd.py` (from 76-2)

**Technical notes:**
- Only validate `sprint/*.yaml` files that are staged (`git diff --cached --name-only`)
- Non-interactive (no prompts, clear exit codes)
- Error message includes: `Run '/sprint validate --fix' to repair`

---

### 76-6: Migrate existing YAML files (2 pts, P1, trivial)
**Jira:** MSSCI-14259

Run `--fix` on all existing files to canonicalize format.

**Deliverables:**
- All sprint YAML files pass validation
- ADR-0018 updated with Python implementation notes

**Key files:**
- Modify: `sprint/current-sprint.yaml` (reformatted)
- Modify: `sprint/future.yaml` (reformatted)
- Modify: `sprint/archive/*.yaml` (reformatted)
- Modify: `pennyfarthing/docs/adr/0018-sprint-yaml-script-access.md`

**Technical notes:**
- This is a "run the tool we built" story
- Verify round-trip: save backup, fix, diff, confirm only formatting changes
- Update ADR-0018 to reference Python `yaml_io` module

## Dependency Graph

```
76-1 (yaml_io) ──┬──→ 76-2 (validate) ──→ 76-5 (pre-commit hook)
                  │                    └──→ 76-6 (migrate files)
                  ├──→ 76-3 (story add)
                  └──→ 76-4 (story update)
```

**76-1 is the critical path.** All other stories import from `yaml_io`.

## Risks

| Risk | Mitigation |
|------|------------|
| ruamel.yaml learning curve | Well-documented library, straightforward API |
| Breaking existing reads | yaml_io is additive — existing `loader.py` unchanged |
| Key ordering drift from template | Tests compare against template ordering |
| Multiline string edge cases | Comprehensive test suite with real sprint YAML fixtures |

## References

- [ADR-0018: Sprint YAML Script Access Pattern](/pennyfarthing/docs/adr/0018-sprint-yaml-script-access.md)
- [Sprint Template](/sprint/sprint-template.yaml)
- [Existing validator](/pennyfarthing/pennyfarthing_scripts/sprint/validator.py)
- [Existing loader](/pennyfarthing/pennyfarthing_scripts/sprint/loader.py)
- [ruamel.yaml documentation](https://yaml.readthedocs.io/)
