# Story Context: 79-2 - Migrate HotspotsPanel into HotspotsDialog

## Summary

Move the HotspotsPanel content into a new `HotspotsDialog` component that wraps itself in the `ToolDialog` wrapper from story 79-1. Remove all dockview panel registration for `hotspots` from `DockviewWorkspace.tsx`, `App.tsx`, and `panels/index.ts`. The `useHotspots` hook and its types remain unchanged -- `HotspotsDialog` imports and uses them directly.

## Current State

### HotspotsPanel (`HotspotsPanel.tsx`)

Located at `packages/cyclist/src/public/components/panels/HotspotsPanel.tsx` (365 lines). Contains:

- **`SortableHeader`** sub-component (lines 21-50): Renders sortable column headers with active/direction state and `aria-sort` attribute.
- **`FileTable`** sub-component (lines 52-115): Sortable table of `FileHotspot[]` with columns Score, Changes, Fixes, Authors, Churn, File. Uses `useMemo` for sorting (line 63), renders Badge with color variants based on score thresholds (line 94).
- **`DirTable`** sub-component (lines 117-188): Sortable table of `DirectoryHotspot[]` with field mapping (line 132) to translate file-centric sort fields to directory equivalents.
- **`HotspotsPanel`** main component (lines 190-363): State management for `days` (default 90), `viewMode` (files/dirs), `sortField`, `sortDirection`. Uses `useHotspots` hook (line 196). Flattens multi-repo results via `repoResults` memo (lines 210-226), merges `allFiles` (lines 229-235) and `allDirs` (lines 237-243). Renders controls bar (time window buttons, view toggle, Analyze button), summary stats, and the appropriate table.

### Panel Registration (5 locations to modify)

1. **`DockviewWorkspace.tsx`** (line 52): `HOTSPOTS: 'hotspots'` in `PANEL_INVENTORY`
2. **`DockviewWorkspace.tsx`** (line 94): `PANEL_INVENTORY.HOTSPOTS` in `RIGHT_SIDEBAR_PANELS` array
3. **`DockviewWorkspace.tsx`** (line 112): `hotspots: 'Hotspots'` in `PANEL_TITLES`
4. **`DockviewWorkspace.tsx`** (line 673): `hotspots: 'Hotspots'` in `panelDisplayNames`
5. **`App.tsx`** (line 45): `HotspotsPanel` import from `'./components/panels'`
6. **`App.tsx`** (line 71): `registerPanelComponent(PANEL_INVENTORY.HOTSPOTS, HotspotsPanel)`
7. **`panels/index.ts`** (line 21): `export { HotspotsPanel } from './HotspotsPanel'`

### useHotspots Hook

Located at `packages/cyclist/src/public/hooks/useHotspots.ts` (113 lines). Exports:
- Types: `FileHotspot`, `DirectoryHotspot`, `HotspotRepoResult`, `HotspotData`, `UseHotspotsOptions`, `UseHotspotsReturn`
- Hook: `useHotspots(options)` -- manages `data`, `isLoading`, `error` state, fetches `GET /api/hotspots?days=N`, returns `{ data, isLoading, error, refresh }`

This hook is NOT modified by this story. `HotspotsDialog` will import it the same way `HotspotsPanel` does.

## Target State

After implementation:

1. **New file:** `packages/cyclist/src/public/components/dialogs/HotspotsDialog.tsx` -- contains the migrated hotspot UI (controls, tables, sub-components) wrapped in `ToolDialog`
2. **Removed registration:** `HOTSPOTS` removed from `PANEL_INVENTORY`, `RIGHT_SIDEBAR_PANELS`, `PANEL_TITLES`, `panelDisplayNames`
3. **Removed imports:** `HotspotsPanel` removed from `App.tsx` imports and registration
4. **Removed export:** `HotspotsPanel` removed from `panels/index.ts`
5. **Optional:** `HotspotsPanel.tsx` can either be deleted or left as a deprecated stub. Prefer deletion since the file is fully replaced by `HotspotsDialog.tsx`.
6. **Layout compatibility:** Users with saved dockview layouts that include `hotspots` will have `fromJSON()` (line 435 of `DockviewWorkspace.tsx`) silently skip the unregistered panel ID. The `closedPanels` set may accumulate `hotspots` as a ghost entry, but the restore menu filters against `panelDisplayNames` (line 723) which will no longer include it.

## Key Files

### Files to Create

| File | Location | What It Does |
|------|----------|--------------|
| `HotspotsDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/dialogs/HotspotsDialog.tsx` | Hotspot analysis dialog wrapping ToolDialog |

### Files to Modify

| File | Location | What Changes |
|------|----------|--------------|
| `DockviewWorkspace.tsx` | `pennyfarthing/packages/cyclist/src/public/components/DockviewWorkspace.tsx` | Remove `HOTSPOTS` from `PANEL_INVENTORY` (line 52), `RIGHT_SIDEBAR_PANELS` (line 94), `PANEL_TITLES` (line 112), `panelDisplayNames` (line 673) |
| `App.tsx` | `pennyfarthing/packages/cyclist/src/public/App.tsx` | Remove `HotspotsPanel` import (line 45), remove `registerPanelComponent(PANEL_INVENTORY.HOTSPOTS, HotspotsPanel)` (line 71) |
| `index.ts` | `pennyfarthing/packages/cyclist/src/public/components/panels/index.ts` | Remove `export { HotspotsPanel } from './HotspotsPanel'` (line 21) |
| `dialogs/index.ts` | `pennyfarthing/packages/cyclist/src/public/components/dialogs/index.ts` | Add `HotspotsDialog` export |

### Files to Optionally Delete

| File | Location | Why |
|------|----------|-----|
| `HotspotsPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/HotspotsPanel.tsx` | Fully replaced by HotspotsDialog |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `HotspotsPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/HotspotsPanel.tsx` | Source of all rendering logic, sub-components, and state management to extract |
| `useHotspots.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useHotspots.ts` | Hook interface and types -- HotspotsDialog imports these unchanged |
| `ToolDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/dialogs/ToolDialog.tsx` | Wrapper component created in 79-1 |
| `ConfirmDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ConfirmDialog.tsx` | Reference for controlled dialog pattern with `open`/`onOpenChange` props |

## Technical Approach

### 1. Create `HotspotsDialog.tsx`

Extract the rendering logic from `HotspotsPanel.tsx`. The new component structure:

```tsx
import React, { useState, useMemo, useCallback } from 'react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip';
import { Skeleton } from '@/components/ui/skeleton';
import { ToolDialog } from './ToolDialog';
import { useHotspots, FileHotspot, DirectoryHotspot, HotspotRepoResult } from '../../hooks/useHotspots';

// Re-export SortableHeader, FileTable, DirTable (moved from HotspotsPanel.tsx)
// These sub-components are identical to their HotspotsPanel versions.

export interface HotspotsDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function HotspotsDialog({ open, onOpenChange }: HotspotsDialogProps): React.ReactElement {
  // All state from HotspotsPanel.tsx lines 191-194 moves here
  const [days, setDays] = useState<number>(90);
  const [viewMode, setViewMode] = useState<ViewMode>('files');
  const [sortField, setSortField] = useState<SortField>('hotspot_score');
  const [sortDirection, setSortDirection] = useState<SortDirection>('desc');

  const { data, isLoading, error, refresh } = useHotspots({ days });

  // Flatten, merge, render logic identical to HotspotsPanel lines 198-361

  return (
    <ToolDialog open={open} onOpenChange={onOpenChange} title="Hotspots">
      <TooltipProvider delayDuration={300}>
        {/* Controls, summary, tables -- same structure as HotspotsPanel */}
      </TooltipProvider>
    </ToolDialog>
  );
}
```

Key design decisions:
- All state lives inside `HotspotsDialog`. When the dialog is closed, Radix unmounts the content, which destroys the hook state. This is intentional -- each open starts fresh (the data is fetched on demand via the Analyze button, not automatically on mount).
- The `useHotspots` hook does NOT auto-fetch on mount (note line 112 of `useHotspots.ts`: it returns `refresh` as the trigger, with no `useEffect` for auto-fetch). So opening the dialog shows the "Click Analyze" empty state, and the user triggers analysis manually.
- Sub-components (`SortableHeader`, `FileTable`, `DirTable`) move into `HotspotsDialog.tsx` as private functions, or can be extracted into a shared `hotspots/` sub-directory if reuse is anticipated.

### 2. Remove panel registration from DockviewWorkspace.tsx

Four removals:

```tsx
// Line 52: Remove from PANEL_INVENTORY
HOTSPOTS: 'hotspots',  // DELETE this line

// Line 94: Remove from RIGHT_SIDEBAR_PANELS
PANEL_INVENTORY.HOTSPOTS,  // DELETE this line

// Line 112: Remove from PANEL_TITLES
hotspots: 'Hotspots',  // DELETE this line

// Line 673: Remove from panelDisplayNames
hotspots: 'Hotspots',  // DELETE this line
```

### 3. Remove panel registration from App.tsx

```tsx
// Line 45: Remove from panel imports
HotspotsPanel,  // DELETE from import list

// Line 71: Remove registration call
registerPanelComponent(PANEL_INVENTORY.HOTSPOTS, HotspotsPanel);  // DELETE this line
```

### 4. Remove export from panels/index.ts

```tsx
// Line 21: Remove barrel export
export { HotspotsPanel } from './HotspotsPanel';  // DELETE this line
```

### 5. Add export to dialogs/index.ts

```tsx
export { ToolDialog } from './ToolDialog';
export type { ToolDialogProps } from './ToolDialog';
export { HotspotsDialog } from './HotspotsDialog';
export type { HotspotsDialogProps } from './HotspotsDialog';
```

### 6. Delete HotspotsPanel.tsx

Remove `packages/cyclist/src/public/components/panels/HotspotsPanel.tsx` entirely. It is fully replaced by `HotspotsDialog.tsx`.

### 7. Testing

- **Unit tests** for `HotspotsDialog`:
  - Verify dialog renders when `open={true}` with title "Hotspots"
  - Verify controls (time window buttons, view toggle, Analyze button) render
  - Verify `onOpenChange(false)` is called on close
  - Verify `useHotspots` hook is called with correct days param
  - Verify loading skeleton renders during fetch
  - Verify error state renders with retry button
- **Verify panel removal:**
  - `PANEL_INVENTORY` no longer has `HOTSPOTS`
  - `RIGHT_SIDEBAR_PANELS` array length is 7 (was 8)
  - No `registerPanelComponent` call for `HOTSPOTS`
- **Layout compatibility test:** Verify `fromJSON()` with a saved layout containing `hotspots` panel ID does not throw

## Acceptance Criteria

- `HotspotsDialog` component exists at `components/dialogs/HotspotsDialog.tsx`
- Dialog uses `ToolDialog` wrapper with title "Hotspots"
- All hotspot functionality works: time window controls, file/dir toggle, sortable tables, Analyze button
- `HOTSPOTS` removed from `PANEL_INVENTORY`, `RIGHT_SIDEBAR_PANELS`, `PANEL_TITLES`, `panelDisplayNames`
- `HotspotsPanel` import and `registerPanelComponent` call removed from `App.tsx`
- `HotspotsPanel` export removed from `panels/index.ts`
- `HotspotsPanel.tsx` deleted
- Saved layouts with `hotspots` panel ID degrade gracefully (no errors)
- `useHotspots` hook and its types are unchanged
- Unit tests pass

## Dependencies

### Depends On

- **79-1** (Create ToolDialog shared component) -- HotspotsDialog wraps itself in ToolDialog

### Depended On By

- **79-3** (Add tool launcher row to DebugPanel) -- DebugPanel imports and opens HotspotsDialog
- **79-5** (Expand artifact exclusions + client filters) -- adds client-side filter toggles inside HotspotsDialog

## Risks / Open Questions

1. **State loss on close:** Radix Dialog unmounts content when closed. This means fetched hotspot data, sort state, and time window selection are lost when the dialog closes. If users want to close and reopen the dialog without re-fetching, the `useHotspots` state would need to be lifted above the dialog (into DebugPanel or a context). For now, the simple approach (state inside dialog) is acceptable since hotspot analysis is an on-demand operation, not a continuous view.

2. **Sub-component extraction:** `SortableHeader`, `FileTable`, and `DirTable` are currently private to `HotspotsPanel.tsx`. When moving to `HotspotsDialog.tsx`, decide whether to keep them inline (simplest) or extract to separate files for testability. Inline is recommended to keep the story scoped.

3. **Existing HotspotsPanel tests:** If there are existing tests for `HotspotsPanel`, they need to be migrated or rewritten for `HotspotsDialog`. The test setup changes because the component is now a dialog (rendered in a Radix portal) rather than a direct panel.

4. **Tooltip provider nesting:** `HotspotsPanel` wraps its entire render in `<TooltipProvider delayDuration={300}>` (line 274). Inside `ToolDialog`, this is within a Radix Dialog portal. Verify that Radix Tooltip works correctly inside a Radix Dialog portal -- both use portals, so z-index stacking may need attention.

5. **CSS class migration:** `HotspotsPanel` uses CSS classes like `.hotspots-panel`, `.hotspots-controls`, `.hotspots-table`, etc. These styles (defined in the Cyclist CSS) still apply inside the dialog, but verify that the wider `max-w-5xl` layout works well with the existing table CSS that was designed for a sidebar panel width.
