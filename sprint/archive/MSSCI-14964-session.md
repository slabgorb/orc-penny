# Story 103-9: Panel header chrome (current panel indicator, Nerd Font icons)

## Story Details
- **ID:** 103-9
- **Jira:** MSSCI-14964
- **Workflow:** tdd
- **Epic:** 103 (BikeRack TUI — Terminal-Native Dashboard)
- **Points:** 1
- **Priority:** P1
- **Assignee:** Keith Avery
- **Repos:** pennyfarthing

## Description
Panel name displayed in header/footer with Nerd Font icon per panel type. Developer can see which panel is active at a glance.

## Acceptance Criteria
- [ ] Panel header displays current panel name
- [ ] Nerd Font icon shown per panel type
- [ ] Visual indicator updates when panel focus changes
- [ ] Header chrome renders correctly in Textual layout
- [ ] Tests verify header display and icon assignment

## Workflow Tracking
**Workflow:** tdd
**Phase:** red
**Phase Started:** 2026-02-14T12:03:48Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-14T12:02:06Z | 2026-02-14T12:03:48Z | 1m 42s |
| red | 2026-02-14T12:03:48Z | - | - |

## Context
### Epic Background
This is part of Epic 103 (BikeRack TUI — Terminal-Native Dashboard), which replaces the browser-based BikeRack dashboard with a terminal-native TUI companion built on Textual/Rich (Python). The TUI connects to WheelHub over WebSocket and renders 10 panels.

**Key infrastructure:**
- WheelHub server exists (packages/cyclist/src/server.ts)
- WebSocket channels established (sprint, git, diffs, todos, story, background-tasks, spans, context, persona)
- Panel abstraction exists (103-5, base panel)
- Textual app scaffold in place (103-1)

### Story Dependencies
**Blocked by:**
- 103-1: Textual app scaffold with basic layout (provides Textual app structure)

**Enables:**
- Remaining panel implementation stories (103-10 through 103-18)

### Technical Notes
- **Repo location:** pennyfarthing/packages/cyclist/src/components/ (BikeRack components)
- **Panel enum:** Define Nerd Font icon mapping per panel type
- **Textual layout:** Header or footer widget in app container
- **Panel types:** MessagePanel, ChangedPanel, DiffsPanel, SprintPanel, BikeLanePanel, ACPanel, AcceptanceCriteriaPanel, SettingsPanel, DebugPanel, GitPanel, BackgroundPanel, TodoPanel, AuditLogPanel, TTYPanel, WorkflowPanel, HotspotsPanel (from Epic 103 context)

## Session History
- Created by sm-setup on 2026-02-14
- Branch: feat/103-9-panel-header-chrome
