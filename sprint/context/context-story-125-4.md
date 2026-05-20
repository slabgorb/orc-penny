# Context: Story 125-4 — Add sprint provenance indicator to BikeRack TUI

**GitHub Issue:** [#1028](https://github.com/slabgorb/pennyfarthing-orchestrator/issues/1028)
**Points:** 1
**Epic:** 125 — Sprint State Engine Consolidation (PROJ-15421)

## Problem

Users cannot see which sprint context is active when working with multiple sprint contexts (focus/spike sprints vs. main orchestrator sprint). GitHub issue #1028 requests visibility into which sprint context is active. The BikeRack TUI sprint panel should display a provenance indicator (e.g., "[spike: ocsf-rs1]") when a non-default context is active, to give users clear feedback about their current sprint scope.

The underlying SprintContext data model (125-1) makes this trivial — we just need to render `context.name` and `context.type` when `is_default` is False. This story delivers the UI payoff from Move 1 of the consolidation work.

## Architecture

### Current Flow

The sprint panel receives sprint data via WebSocket (`/ws/sprint`). The payload includes:
- `sprint`: Sprint metadata (number, name, done/remaining/in-progress counts)
- `epics`: List of epics with stories
- `registry`: Sprint context metadata (optional)

The `registry` object contains:
- `name`: Context name (e.g., "ocsf-rs1")
- `type`: Context type (e.g., "focus", "spike")
- `isDefault`: Boolean flag indicating default sprint

When `isDefault` is False, the panel header should append the provenance indicator; when True, no change is visible.

### Key Files

| File | Role |
|------|------|
| `pennyfarthing-dist/pf/bikerack/sprint_panel.py` | TUI sprint panel — renders tree of epics/stories with header |
| `pennyfarthing-dist/pf/core/models.py` | SprintContext dataclass with `is_default` field |
| `packages/core/src/public/hooks/useSprint.ts` | React hook typing — SprintRegistry interface with `isDefault` |
| `packages/core/src/server/api/*.ts` | WheelHub server routes that construct sprint payload |

### Provenance Indicator Format

When `is_default` is False, the header should append a bracket section showing context type and name:
- Format: `[type:name]` (e.g., `[spike:ocsf-rs1]`)
- If both type and name are present: `[spike:ocsf-rs1]`
- If only name: `[ocsf-rs1]`
- If only type: `[spike]`

### Implementation Status

The Python TUI code (sprint_panel.py lines 320-329) **already implements** the provenance indicator display:
```python
if registry and not registry.get("isDefault", True):
    reg_type = registry.get("type", "")
    reg_name = registry.get("name", "")
    if reg_type and reg_name:
        header_text.append(f" [{reg_type}:{reg_name}]")
    elif reg_name:
        header_text.append(f" [{reg_name}]")
    elif reg_type:
        header_text.append(f" [{reg_type}]")
```

This code was likely merged as part of story 125-1 or earlier consolidation work. The feature is functionally complete and ready for testing.

## Acceptance Criteria

### AC1: Header shows context when not default
- **Given** a user is viewing the BikeRack TUI sprint panel on a non-default context (e.g., `ocsf-rs1` spike)
- **When** the sprint panel receives payload with `registry.isDefault = False, registry.type = "spike", registry.name = "ocsf-rs1"`
- **Then** the panel header displays `[spike:ocsf-rs1]` appended to the sprint number and progress bar

**Example:** `Sprint 2608  ✓10 pts  ⊙8 pts  ⟳2 pts  [dim]100%[/dim] [spike:ocsf-rs1]`

### AC2: Header shows nothing when default
- **Given** a user is viewing the BikeRack TUI sprint panel on the default main sprint
- **When** the sprint panel receives payload with `registry.isDefault = True` or `registry` is missing
- **Then** the panel header displays sprint metadata with no additional provenance indicator

**Example:** `Sprint 2608  ✓10 pts  ⊙8 pts  ⟳2 pts  [dim]100%[/dim]`

### AC3: Graceful handling of partial context data
- **Given** the payload contains `registry` with only `name` (no type)
- **When** the panel renders the header
- **Then** the header displays `[name]` without error

- **Given** the payload contains `registry` with only `type` (no name)
- **When** the panel renders the header
- **Then** the header displays `[type]` without error

### AC4: No visual regression on default sprint
- **Given** the feature is enabled
- **When** a user works on the default sprint for an extended session
- **Then** the header looks identical to the previous version (no extra brackets, no whitespace changes)

## Test Plan

1. **Default sprint flow:**
   - Launch BikeRack on orchestrator root with no sprint preference set
   - Verify sprint header shows standard format with no brackets
   - Check git panel, progress panel for any side effects

2. **Focus sprint flow:**
   - Set `sprint.active: "ocsf-rs1"` in `.pennyfarthing/config.local.yaml`
   - Launch BikeRack and verify sprint panel displays `[spike:ocsf-rs1]` in header
   - Verify epics/stories render normally below the header

3. **Edge cases:**
   - Create a context with only `name`, no `type` — verify header shows `[name]`
   - Create a context with only `type`, no `name` — verify header shows `[type]`
   - Switch between default and non-default contexts via config change — verify header updates

4. **Unblock GitHub issue:**
   - Verify issue #1028 is satisfied (users can see active sprint context)
   - Verify no regressions in git panel, progress panel, or other BikeRack panels

## Implementation Notes

The feature is already implemented in sprint_panel.py (lines 320-329). Testing and validation are the primary activities:

1. Verify the WheelHub server correctly populates the `registry` object in sprint payloads
2. Test with real focus/spike context configurations
3. Validate header formatting matches the design spec
4. Ensure the feature integrates cleanly with future sprint operations (context switching, archive, etc.)

This story unblocks GitHub issue #1028 and completes Move 1 of the Sprint State Engine consolidation roadmap.
