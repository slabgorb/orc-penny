# Epic 79: Dialog Infrastructure + Hotspot Refactor

**Jira:** PROJ-14440
**Priority:** P1
**Repos:** pennyfarthing

## Description
Create shared ToolDialog component, migrate HotspotsPanel into a dialog launched from Debug panel, remove Hotspots as a standalone dockview panel. Add tool launcher button row to DebugPanel. Fix hotspot analysis to skip orchestrator repos and filter non-code artifacts (dotfiles, images, config, generated files).

## Stories
- 79-1: Create ToolDialog shared component (1pt, P0)
- 79-2: Migrate HotspotsPanel into HotspotsDialog (2pt, P0)
- 79-3: Add tool launcher row to DebugPanel (1pt, P0)
- 79-4: Hotspot: skip orchestrator repos by type (2pt, P1)
- 79-5: Hotspot: expand artifact exclusions + client filters (2pt, P1)
