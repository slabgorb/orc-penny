# Session: MSSCI-14243 - Settings panel visibility toggles

## Story Information

| Field | Value |
|-------|-------|
| **ID** | MSSCI-14243 |
| **Title** | Settings panel visibility toggles for all panels |
| **Epic** | epic-76 (Dockview Panel Migration) |
| **Epic Jira** | MSSCI-14186 |
| **Points** | 3 |
| **Priority** | P1 |
| **Type** | feature |
| **Workflow** | trivial |
| **Repos** | pennyfarthing |
| **Branch** | feature/MSSCI-14243-settings-panel-visibility |
| **Status** | implement |

## Phase

**Current Phase:** implement

## Problem Statement

- Closed panels cannot be recovered without knowing the exact restore mechanism
- Some panels (AC, Bikelane Workflow, Debug) are not easily accessible
- No single place to see all available panels and their visibility state

## Target State

- New 'Panel Visibility' section in Settings below existing options
- Lists ALL registered panels with checkbox toggles
- Checkbox checked = panel visible in workspace
- Checkbox unchecked = panel hidden/closed
- Clicking checkbox immediately shows/hides the panel
- Styling consistent with existing Settings sections

## Acceptance Criteria

- [ ] All registered panels appear in Settings list
- [ ] Checkbox accurately reflects current visibility
- [ ] Toggling checkbox shows/hides panel immediately
- [ ] Hidden panels can be restored via this UI
- [ ] Styling matches existing Settings sections

## Implementation Notes

- Query PANEL_INVENTORY or equivalent registry for complete panel list
- Wire to Dockview API to add/remove panels
- Ensure ALL panels are registered (AC, Workflow, Debug, etc.)
- Persist visibility state to layout config

## Technical Context

See epic context: `sprint/context/context-epic-76.md`

Key technical details from epic:
- Dockview-react@4.13.1 is installed and in use
- Panel adapter pattern wraps existing panels for Dockview
- DockviewWorkspace.tsx is the main workspace component
- Layout persists to config.local.yaml

### Relevant Files

- `packages/cyclist/src/public/components/DockviewWorkspace.tsx` - Main workspace
- `packages/cyclist/src/public/components/panels/SettingsPanel.tsx` - Settings panel (add visibility section here)
- `packages/cyclist/src/public/styles/dockview-theme.css` - Theme customization
- Panel inventory/registry (location TBD - investigate PANEL_INVENTORY)

## Workflow: trivial

```
SM → Dev → Reviewer
```

Skips TEA phase since this is a straightforward UI feature.

## Session Log

### Setup (completed)
- Created session file
- Story context loaded from sprint YAML
- Epic context available at sprint/context/context-epic-76.md

### Implement (completed)
- **Handoff from SM to Dev** - 2026-02-04
- Workflow: trivial (SM -> Dev -> Reviewer)
- Branch ready: feature/MSSCI-14243-settings-panel-visibility

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `packages/cyclist/src/public/components/panels/SettingsPanel.tsx` - Added Panel Visibility section with checkboxes for all 13 registered panels

**Implementation Details:**
- Added imports from DockviewWorkspace (PANEL_INVENTORY, getDockviewApi, restorePanel)
- Created PANEL_DISPLAY_NAMES for human-readable panel labels
- Created PROTECTED_PANELS set to prevent hiding Message panel
- Added panelVisibility state that polls Dockview API every 500ms
- Added handlePanelToggle callback that uses restorePanel() or panel.api.close()
- Rendered Panel Visibility section with checkbox for each panel
- Protected panels (Message) have disabled checkbox with "(always visible)" note

**Tests:** Build passes, TypeScript compiles, no new test failures introduced
**PR:** #668 - feat(cyclist): Settings panel visibility toggles
**Branch:** feature/MSSCI-14243-settings-panel-visibility (pushed)

**Handoff:** To Reviewer (Leto II) for code review

### Review (completed)
- **Handoff from Dev to Reviewer** - 2026-02-04

## Reviewer Assessment

**Verdict:** APPROVED

| # | Check | Status |
|---|-------|--------|
| 1 | Data flow traced | ✅ Checkbox → handlePanelToggle → Dockview API |
| 2 | Wiring verified | ✅ Imports from DockviewWorkspace correct |
| 3 | Pattern followed | ✅ Uses toggle-setting class |
| 4 | Error handling | ✅ Silent fail acceptable |
| 5 | Security | ✅ No user input, internal API |

**Observations:**
- `[VERIFIED]` TypeScript compiles cleanly
- `[VERIFIED]` Uses existing PANEL_INVENTORY
- `[VERIFIED]` Message panel protected
- `[LOW]` 500ms polling (acceptable)
- `[LOW]` Self-hiding Settings possible (workaround exists)

**Tests:** Pre-existing failures unrelated to this PR
**PR:** #668 merged to develop

**Handoff:** To SM (Stilgar) for finish-story

### Finish (current)
- **PR #668 merged** - 2026-02-04
- Ready for SM to archive story

---

*Session created: 2026-02-04*
