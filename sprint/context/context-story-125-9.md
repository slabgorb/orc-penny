# Context: Story 125-9 — Extend sprints.yaml with managed focus context fields

**GitHub Issue:** slabgorb/pennyfarthing-orchestrator#28
**Jira:** PROJ-15430
**Points:** 2
**Priority:** P3
**Epic:** 125 — Sprint State Engine Consolidation (PROJ-15421)
**Workflow:** trivial

## Problem

The sprint registry (`sprint/sprints.yaml`) maps focus context names to file paths and metadata, but it is a **flat, dumb registry** with no lifecycle awareness. It cannot answer key questions:

- **Who** is focused on a spike or feature branch?
- **When** did the focus start?
- **Is the focus still active** or did it end?
- **What parent planning** triggered the focus? (links back to orchestrator epics)

Today, focus contexts are invisible. They live in gitignored per-user config (`config.local.yaml`), and the registry records only the target file path, type, and description. When someone `pf sprint use spike-name`, no one knows they did it. When a spike ends, it remains registered indefinitely as "active."

This blocks Move 5 of the Sprint State Engine consolidation (sprint-state-consolidation-proposal.md): **Managed focus contexts as first-class objects** that the team can track and reason about.

## Architecture

### Current sprints.yaml Structure

The registry lives at `sprint/sprints.yaml` and is optional. When present, it maps sprint names to their configuration:

```yaml
# sprint/sprints.yaml (current)
sprints:
  main:
    file: current-sprint.yaml
    type: project
    description: Main project sprint

  ocsf-rs1:
    file: ../spike-ocsf-rs1/sprint/current-sprint.yaml
    type: spike
    description: OCSF log source research spike
    context_root: ../spike-ocsf-rs1/sprint/context/
    session_root: ../spike-ocsf-rs1/.session/
    repos: [spike-ocsf-rs1]
```

### Key Files

| File | Role |
|------|------|
| `sprint/sprints.yaml` | Sprint registry — name → config mapping |
| `pennyfarthing-dist/pf/sprint/loader.py` | Registry loading (`load_sprint_registry()`, `switch_sprint()`) |
| `pennyfarthing-dist/pf/sprint/validator.py` | Schema validation — required and optional fields |
| `pennyfarthing-dist/pf/core/resolver.py` | Resolution logic — `resolve_sprint_context()` |
| `.pennyfarthing/config.local.yaml` | Per-user preference (gitignored) — `sprint.active` key |

### Registry Resolution Flow

1. User runs `pf sprint use spike-name` or reads sprint data
2. `loader.py` calls `resolve_sprint_context(project_root)`
3. Resolver checks for `sprint.active` preference in `config.local.yaml`
4. If set, looks up the name in `sprints.yaml` and loads the mapped sprint file
5. Returns `SprintContext` object with resolved paths

### Proposal: Extended Schema

The proposal (Move 5) extends each registry entry with lifecycle fields:

```yaml
# sprint/sprints.yaml (extended)
sprints:
  main:
    file: current-sprint.yaml
    type: project
    description: Main project sprint
    # No special fields — this is the default

  ocsf-rs1:
    file: ../spike-ocsf-rs1/sprint/current-sprint.yaml
    type: spike
    description: OCSF log source research spike
    context_root: ../spike-ocsf-rs1/sprint/context/
    session_root: ../spike-ocsf-rs1/.session/
    repos: [spike-ocsf-rs1]

    # NEW FIELDS (this story)
    created: '2026-02-10'                          # When the focus started
    owner: michael.pursifull@slabgorb.io          # Who initiated the focus
    participants: [michael.pursifull]              # Who's currently focused here
    status: active                                 # active | completed | abandoned
    parent_epic: PROJ-15200                       # Links back to orchestrator planning
```

### Backward Compatibility

The new fields are **optional**. Existing entries without them remain valid:

- `main` entry never needs the new fields (it's always the default)
- Spike entries created before this story don't have the new fields — they're populated manually or by automation when known
- Validators allow entries that lack any/all of the new fields
- `loader.py` treats missing fields as `None` or empty list

## Acceptance Criteria

### AC1: sprints.yaml schema extended
- **Given** a sprints.yaml with spike entries
- **When** those entries include `created`, `owner`, `participants`, `status`, and `parent_epic` fields
- **Then** all fields are recognized and loaded without error

### AC2: Backward compatibility preserved
- **Given** existing sprints.yaml entries without the new fields
- **When** the schema validator runs
- **Then** entries validate successfully (no errors for missing optional fields)

### AC3: Schema validation updated
- **Given** the validator running on sprints.yaml
- **When** entries have the new fields present
- **Then** validation checks:
  - `created` is ISO date format (YYYY-MM-DD) or absent
  - `status` is one of: `active`, `completed`, `abandoned`, or absent
  - `owner` is a valid email or absent
  - `participants` is a list of emails or absent
  - `parent_epic` is a valid Jira key (PROJECT-NUMBER) or absent

### AC4: loader.py handles new fields
- **Given** loading a registry entry with the new fields
- **When** `load_sprint_registry()` or `switch_sprint()` is called
- **Then** the entry dict includes the new fields as-is (no transformation)

## Implementation Notes

1. **Backward compatibility is critical.** Do not make any new field required. Treat all five as optional at both load and validation time. Existing files must continue to work unchanged.

2. **Validation is lenient but strict on values.** If a field is present, validate its format. If absent, don't require it.

3. **Schema changes are minimal:**
   - Add the five fields to `REQUIRED_REGISTRY_FIELDS` or a new set (e.g., `OPTIONAL_REGISTRY_FIELDS`)
   - Update `validate_registry()` or create a new function
   - Document field semantics in docstrings

4. **loader.py doesn't need changes** — it already returns the raw dict from YAML, so the new fields will flow through automatically once validation allows them.

5. **SprintContext (125-1) dataclass may need updates** in `core/resolver.py` to carry these fields, but that can happen in a follow-up story (125-10) that uses them for CLI commands. For now, just ensure the schema and validation layer is ready.

6. **Date format:** ISO format `YYYY-MM-DD` (same as sprint.start_date / sprint.end_date). Validation regex already exists in validator.py as `ISO_DATE_PATTERN`.

7. **Email validation:** `owner` and `participants` should accept email addresses. A simple regex or library validation is fine. If unsure, allow any non-empty string and let downstream commands do stricter validation.

8. **Jira key format:** `parent_epic` is a Jira ticket reference. Validate using the existing `JIRA_KEY_PATTERN` in validator.py (PROJECT-NUMBER format, e.g., PROJ-15200).

## Relationship to Other Work

- **Move 1 (125-1, 125-2):** SprintContext resolution already complete. New fields are metadata that downstream CLI commands (125-10) will use.
- **Move 5 (125-10):** Will use `owner`, `participants`, and `status` to build `pf sprint focus` commands.
- **Validation framework:** Extends existing patterns used for sprint YAML validation (dates, Jira keys, statuses).
- **No database changes:** This is pure YAML schema extension. No persistence layer changes.

## Testing Strategy

1. **Unit tests for validation:**
   - Valid entry with all new fields
   - Valid entry with no new fields (backward compat)
   - Valid entry with partial new fields
   - Invalid `created` date format
   - Invalid `status` value
   - Invalid `owner` (if strict email validation added)
   - Invalid `participants` (non-list or non-email)
   - Invalid `parent_epic` (Jira key format)

2. **Integration test:**
   - Load a real sprints.yaml with mixed old and new entries
   - Assert loader returns both types without error
   - Assert validator passes

3. **Manual:**
   - Run `pf sprint status` with extended registry
   - Run `pf sprint validate` on extended registry
   - Verify existing focus switching still works (`pf sprint use spike-name`)
