# Epic 102 Context — BikeRack Follow-up: Dockview Migration and Panel Fixes

## Overview
Follow-up to Epic 101 (BikeRack Mode — Decoupled WheelHub Dashboard). This epic focuses on:
1. Migrating BikeRack from a custom index page + StandalonePanel wrapper to a proper Dockview layout
2. Fixing broken panels (OTEL, Git, Portrait)
3. Replacing the settings panel for BikeRack
4. Removing the TTY panel from BikeRack

## BikeRack Background (from Epic 101)
BikeRack is a decoupled dashboard mode that allows running individual Cyclist panels in isolation. Previously implemented in Epic 101, it uses:
- `BikeRackIndex.tsx` — custom routing index page
- `StandalonePanel.tsx` — wrapper for individual panels
- Query param routing: `?panel=X` to load specific panels

## Current Architecture Problems
- BikeRack uses a custom index page instead of inheriting the Dockview layout from base Cyclist
- StandalonePanel is a workaround for single-panel display
- Several panels are broken in BikeRack mode (OTEL, Git, Portrait)
- Settings panel needs replacement for BikeRack context
- TTY panel should be removed from BikeRack

## Target Architecture (Story 102-1)
Migrate BikeRack to use proper Dockview layout:
- BikeRack should render panels in Dockview layout similar to base Cyclist's DockviewWorkspace
- Panel tabs should be navigable like base Cyclist
- StandalonePanel/?panel=X routing should still work for backward compatibility
- No regressions in base Cyclist Dockview behavior

## Key Files
- `pennyfarthing/packages/cyclist/src/public/components/DockviewWorkspace.tsx` — base Dockview layout (reference)
- `pennyfarthing/packages/cyclist/src/public/components/BikeRackIndex.tsx` — current BikeRack index page (to be replaced)
- `pennyfarthing/packages/cyclist/src/public/components/StandalonePanel.tsx` — current panel wrapper (may be deprecated)
- `pennyfarthing/packages/cyclist/src/public/App.tsx` — app routing (needs updates for BikeRack routing)

## Epic Stories
1. **102-1** (5pts, P1, refactor) — Migrate BikeRack from index page to Dockview layout
2. **102-2** (3pts, P1, feature) — Replace settings panel for BikeRack
3. **102-3** (1pt, P2, chore) — Remove TTY panel from BikeRack
4. **102-4** (2pts, P1, bug) — Investigate and fix OTEL panels not responding in BikeRack
5. **102-5** (2pts, P1, bug) — Fix broken Git panel in BikeRack
6. **102-6** (2pts, P1, bug) — Fix broken Portrait panel in BikeRack

## Acceptance Criteria for 102-1
- BikeRack renders panels in Dockview layout instead of index page
- Panel tabs are navigable like base Cyclist
- StandalonePanel/?panel=X routing still works for direct panel access
- No regressions in base Cyclist Dockview behavior
- `pnpm build` succeeds
- Existing tests pass

## Technical Considerations
- Investigate how DockviewWorkspace handles panel rendering and layout management
- Understand how base Cyclist initializes panels and manages their state
- Determine migration path for BikeRackIndex → DockviewWorkspace integration
- Plan backward compatibility for StandalonePanel routing
- Consider how to maintain separate panel state for BikeRack vs. base Cyclist
