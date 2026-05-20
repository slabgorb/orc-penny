# PRD: Sprint Data Management System

**Version:** 1.0
**Date:** 2026-02-04
**Author:** Lady Jessica (PM Agent)
**Status:** Draft

---

## Executive Summary

The Sprint Data Management System replaces fragile YAML editing with deterministic, validated operations. Currently, sprint YAML files are prone to corruption from manual edits, format drift over time, and merge conflicts due to high edit frequency. This system introduces a Python-based `yaml_io` module that guarantees format consistency, provides auto-fix capabilities, and consolidates the `/sprint` and `/story` skills into a single coherent interface.

**Key Deliverable:** A `pennyfarthing_scripts/sprint/` Python package that provides 100% deterministic YAML operations with validation, auto-fix, and atomic writes.

---

## Problem Statement

### Current Pain Points

1. **Format Corruption** - Single-quoted strings with blank lines break YAML parsing
2. **Format Drift** - Files gradually diverge from template structure over repeated edits
3. **Missing Operations** - No script to add stories; agents use `cat >>` which corrupts structure
4. **Merge Conflicts** - High edit frequency on monolithic file causes frequent conflicts
5. **Detection Without Repair** - Validator catches errors but cannot fix them

### Root Cause

ADR-0018 established "never edit YAML directly" but didn't provide complete tooling for all operations. The gap between policy and implementation creates the pain.

---

## Solution Overview

### Architecture

```
/sprint skill (skill.md)
    ↓
pennyfarthing_scripts/sprint/cli.py (Click CLI)
    ↓
pennyfarthing_scripts/sprint/yaml_io.py (Core module)
    ↓
Deterministic YAML output
```

### Key Components

| Component | Purpose |
|-----------|---------|
| `yaml_io.py` | Canonical read/write/validate/fix for all YAML operations |
| `cli.py` | Click-based CLI entry point |
| `story/add.py` | Add story to epic |
| `story/update.py` | Update story fields |
| `validate.py` | Validation with `--fix` flag |
| Pre-commit hook | Block invalid YAML at commit time |

---

## Success Criteria

### User Success

| Criterion | Measure | Threshold |
|-----------|---------|-----------|
| Agent adds story | YAML valid, format matches template | 100% |
| Human reads file | Format identical to template structure | 100% |
| Validation run | Clear pass/fail, actionable fix commands | Every run |
| No manual intervention | Operations complete without human cleanup | 100% |

### Technical Success

| Criterion | Measure | Threshold |
|-----------|---------|-----------|
| Determinism | Same input → byte-identical output | 100% |
| No format drift | File after 100 edits matches template structure | 100% |
| Round-trip integrity | Read → Parse → Write → Read = identical | 100% |
| Validation coverage | All known error types detected | 100% |
| Auto-fix coverage | All format errors auto-repairable | 100% |

### Documentation Success

| Criterion | Measure | Threshold |
|-----------|---------|-----------|
| Schema as code | Template is enforced, not advisory | Enforced |
| Skill docs accurate | `/sprint --help` matches actual behavior | 100% |
| ADR updated | ADR-0018 reflects Python implementation | On completion |
| No drift | Documentation matches implementation always | 100% |

---

## User Journeys

### J1: Agent Adds a Story

**Actor:** SM Agent
**Goal:** Add new story to epic in current sprint

```bash
/sprint story add epic-76 "TTY Panel with xterm.js" 5 --type feature --priority P1
```

**Flow:**
1. Validate epic exists
2. Generate next story ID (PROJ-XXXXX from Jira or local sequence)
3. Create properly formatted YAML block
4. Insert at correct position under epic
5. Validate entire file
6. Write atomically (temp + rename)

### J2: Agent Updates Story Status

**Actor:** Dev Agent
**Goal:** Mark story as done

```bash
/sprint story update PROJ-14211 --status done --completed 2026-02-04
```

**Flow:**
1. Find story in current sprint
2. Update status, add completed date, remove assigned_to
3. Validate and write atomically
4. Trigger Jira sync

### J3: Validation Catches Corruption

**Actor:** Pre-commit hook
**Goal:** Block corrupted YAML

```bash
/sprint validate
# ERROR: Line 245 - Single-quoted string contains blank lines
# FIX: Run `/sprint validate --fix`

/sprint validate --fix
# Fixed 1 error. File is now valid.
```

### J4: Human Hand-Edit with Validation

**Actor:** Keith
**Goal:** Bulk changes with safety net

```bash
# Edit file directly in VS Code
/sprint validate
# ✓ YAML valid
```

---

## Functional Requirements

### FR1: Deterministic YAML Serialization

The `yaml_io.py` module MUST produce byte-identical output for identical input data.

**Implementation:**
- Use `ruamel.yaml` with explicit configuration
- Fixed key ordering (defined in template)
- Block scalars (`|`) for all multiline strings
- 2-space indentation
- No trailing whitespace
- UTF-8 encoding

### FR2: Story Add Command

```bash
/sprint story add <epic-id> "<title>" <points> [options]
```

**Options:**
- `--type` (feature|bug|chore|refactor) - default: feature
- `--priority` (P0|P1|P2|P3) - default: P2
- `--workflow` (tdd|trivial|bdd) - default: auto-detect
- `--jira` - also create Jira issue

**Behavior:**
- Validate epic exists
- Generate story ID
- Insert at end of epic's stories list
- Validate entire file after insertion
- Write atomically

### FR3: Story Update Command

```bash
/sprint story update <story-id> [field updates]
```

**Field Updates:**
- `--status` (backlog|ready|in_progress|done)
- `--completed` (YYYY-MM-DD)
- `--assigned-to` (name)
- `--points` (1|2|3|5|8)
- `--priority` (P0|P1|P2|P3)

**Behavior:**
- Find story by ID
- Apply field updates
- Auto-cleanup (remove assigned_to when done)
- Validate and write atomically

### FR4: Validation Command

```bash
/sprint validate [--fix] [--file <path>]
```

**Default:** Validate `sprint/current-sprint.yaml`

**Validation Checks:**
- YAML syntax valid
- Schema valid (required fields present, correct types)
- Format consistent (indentation, key ordering, string style)
- References resolve (stories belong to existing epics)

**Fix Capabilities:**
- Convert single-quoted strings to block scalars
- Fix indentation
- Normalize key ordering
- Remove trailing whitespace

### FR5: Pre-commit Hook

```yaml
# .pre-commit-config.yaml
- repo: local
  hooks:
    - id: sprint-yaml-validate
      name: Validate Sprint YAML
      entry: python -m pennyfarthing_scripts.sprint.cli validate
      language: python
      files: ^sprint/.*\.yaml$
```

**Behavior:**
- Exit 0 if valid
- Exit 1 with actionable error message if invalid
- Run in < 2 seconds

### FR6: Atomic Writes

All write operations MUST use atomic write pattern:

```python
def atomic_write(path: Path, content: str) -> None:
    temp = path.with_suffix('.tmp')
    temp.write_text(content, encoding='utf-8')
    temp.replace(path)  # Atomic on POSIX
```

---

## Non-Functional Requirements

### NFR1: Performance

| Operation | Target |
|-----------|--------|
| Validation | < 500ms |
| Story add | < 1s |
| Story update | < 1s |
| Pre-commit total | < 2s |

### NFR2: Compatibility

- Python 3.11+
- Works on macOS (primary) and Linux (CI)
- No interactive prompts (CI-compatible)

### NFR3: Error Messages

All errors MUST include:
- Line number (if applicable)
- Field path (e.g., `epics[1].stories[3].description`)
- Fix command (e.g., `Run /sprint validate --fix`)

### NFR4: Backwards Compatibility

- Existing bash scripts continue to work during migration
- `/story` skill becomes alias to `/sprint story`
- No breaking changes to YAML schema

---

## Technical Design

### Module Structure

```
pennyfarthing_scripts/
└── sprint/
    ├── __init__.py
    ├── cli.py              # Click CLI entry point
    ├── yaml_io.py          # Core deterministic YAML module
    ├── validate.py         # Validation logic
    ├── schema.py           # Dataclasses for sprint/epic/story
    ├── story/
    │   ├── __init__.py
    │   ├── add.py          # /sprint story add
    │   ├── update.py       # /sprint story update
    │   └── finish.py       # /sprint story finish
    └── tests/
        ├── test_yaml_io.py
        ├── test_validate.py
        └── test_story_add.py
```

### Key Dataclasses

```python
@dataclass
class Story:
    id: str
    title: str
    points: int
    status: Literal['backlog', 'ready', 'in_progress', 'done']
    priority: Literal['P0', 'P1', 'P2', 'P3']
    type: Literal['feature', 'bug', 'chore', 'refactor']
    description: str | None = None
    acceptance_criteria: list[str] = field(default_factory=list)
    workflow: str | None = None
    jira: str | None = None
    completed: str | None = None
    assigned_to: str | None = None

@dataclass
class Epic:
    id: str
    title: str
    description: str | None
    priority: Literal['P0', 'P1', 'P2', 'P3']
    status: Literal['in_progress', 'done']
    stories: list[Story]
    jira: str | None = None

@dataclass
class Sprint:
    name: str
    number: int
    jira_sprint_id: int
    goal: str
    start_date: str
    end_date: str
    status: Literal['active', 'closed']
    epics: list[Epic]
```

### yaml_io.py Core Functions

```python
def read_sprint(path: Path) -> Sprint:
    """Parse sprint YAML into validated dataclass."""

def write_sprint(path: Path, sprint: Sprint) -> None:
    """Write sprint with canonical formatting. Atomic."""

def validate_sprint(path: Path) -> list[ValidationError]:
    """Return list of errors (empty = valid)."""

def fix_sprint(path: Path) -> FixResult:
    """Apply auto-fixes. Returns what was fixed."""

def canonical_dump(data: dict) -> str:
    """Serialize dict to canonical YAML string."""
```

---

## Scope

### MVP (This Epic)

1. ✅ `yaml_io.py` with deterministic read/write/validate/fix
2. ✅ `/sprint story add` command
3. ✅ `/sprint story update` command
4. ✅ `/sprint validate --fix` command
5. ✅ Pre-commit hook
6. ✅ All sprint YAML files use same format

### Growth (Future)

- Sharded YAML (one file per epic)
- Full bash script migration to Python
- `/story` skill deprecated
- Custom git merge driver

### Out of Scope

- Database backend (stay with YAML)
- UI for sprint management
- Real-time collaboration

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| YAML corruption during migration | Medium | High | Validate before/after every operation |
| Performance regression | Low | Medium | Benchmark against current bash scripts |
| Jira sync breaks | Medium | Medium | Graceful degradation, retry logic |
| Format drift returns | Low | High | Pre-commit hook enforces validation |

---

## Dependencies

### Required

- `ruamel.yaml` - YAML library with round-trip preservation
- `click` - CLI framework
- `pydantic` or `dataclasses` - Data validation

### Existing

- `pennyfarthing_scripts` infrastructure
- Pre-commit framework
- Jira CLI (`jira-cli`)

---

## Migration Plan

### Phase 1: Build Core (Week 1)

1. Implement `yaml_io.py` with tests
2. Implement `/sprint validate --fix`
3. Fix current `sprint/current-sprint.yaml` corruption

### Phase 2: Add Operations (Week 2)

1. Implement `/sprint story add`
2. Implement `/sprint story update`
3. Update skill documentation

### Phase 3: Enforcement (Week 3)

1. Add pre-commit hook
2. Update ADR-0018
3. Deprecate bash scripts (soft)

---

## Appendix: Format Specification

### Key Ordering

Sprint-level keys (in order):
1. `sprint` (containing: number, name, jira_sprint_id, jira_sprint_name, goal, start_date, end_date, status)
2. `epics`

Epic keys (in order):
1. `id`
2. `type`
3. `title`
4. `description`
5. `priority`
6. `status`
7. `repos`
8. `jira`
9. `stories`

Story keys (in order):
1. `id`
2. `jira`
3. `title`
4. `description`
5. `points`
6. `priority`
7. `type`
8. `status`
9. `workflow`
10. `repos`
11. `acceptance_criteria`
12. `assigned_to`
13. `started`
14. `completed`

### String Style Rules

| Field | Style |
|-------|-------|
| Single-line (title, id, status) | Plain or single-quoted |
| Multi-line (description) | Block scalar (`\|`) |
| Acceptance criteria items | Plain |
