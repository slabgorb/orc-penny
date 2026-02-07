# Story Context: 79-3 - Add tool launcher row to DebugPanel

## Summary

Add a "Tools" section to the bottom of `DebugPanel.tsx` (below the existing Token Stats section) with a button row that opens observatory tool dialogs. The first button is "Hotspots" which opens `HotspotsDialog`. Future buttons (dependency audit, bundle analysis) are added as placeholder-ready slots. Dialog open/close state is managed via `useState` in `DebugPanel`.

## Current State

### DebugPanel Layout

Located at `packages/cyclist/src/public/components/panels/DebugPanel.tsx` (268 lines). The panel has two sections:

1. **Context Usage** (lines 137-222): `<h4>Context Usage</h4>`, context bar, tier badge, token breakdown, injected context collapsible
2. **Token Stats** (lines 226-262): `<Separator className="my-3" />`, `<h4>Token Stats</h4>`, stat cards for input/output/cache/cost

The component ends at line 264 with a closing `</div>`. There is no third section and no Tools area currently.

Current imports (lines 11-14):
```tsx
import React, { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
```

The component uses `useState` for `context`, `tokenStats`, and `breakdownExpanded` state (lines 94-96).

### HotspotsDialog (from 79-2)

After story 79-2, `HotspotsDialog` exists at `packages/cyclist/src/public/components/dialogs/HotspotsDialog.tsx` and exports:
- `HotspotsDialog` component with `{ open: boolean; onOpenChange: (open: boolean) => void }` props
- Exported from `dialogs/index.ts`

### Current Panel-to-Dialog Flow

No observatory tool dialogs exist in DebugPanel currently. The pattern being established by this story is:
- Button in DebugPanel triggers `setState(true)`
- Dialog component receives `open` and `onOpenChange` as controlled props
- Same pattern as `ApprovalModal` in `App.tsx` (lines 222-257) which uses `useState` for request/open state

## Target State

After implementation:

1. `DebugPanel.tsx` has a new "Tools" section after Token Stats
2. The section contains:
   - A `<Separator>` divider
   - An `<h4>Tools</h4>` heading
   - A button row with a "Hotspots" button
3. Clicking "Hotspots" opens `HotspotsDialog`
4. Dialog state (`hotspotsOpen`) lives in `DebugPanel` via `useState`
5. `HotspotsDialog` is imported from `../dialogs/HotspotsDialog`
6. The structure is extensible -- adding future tool buttons means adding another `useState` + `Button` + Dialog import

## Key Files

### Files to Modify

| File | Location | What Changes |
|------|----------|--------------|
| `DebugPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/DebugPanel.tsx` | Add Tools section after line 262 (end of Token Stats), add `useState` for dialog open state, import HotspotsDialog |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `DebugPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/DebugPanel.tsx` | Understand current layout, imports, styling patterns |
| `HotspotsDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/dialogs/HotspotsDialog.tsx` | Component to import; understand props interface |
| `ConfirmDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ConfirmDialog.tsx` | Reference for controlled dialog state pattern in a parent component |

## Technical Approach

### 1. Add dialog state to DebugPanel

Add a `useState` for the hotspots dialog open state alongside existing state (after line 96):

```tsx
const [hotspotsOpen, setHotspotsOpen] = useState(false);
```

### 2. Add HotspotsDialog import

Add to the import section (after line 14):

```tsx
import { HotspotsDialog } from '../dialogs/HotspotsDialog';
```

### 3. Add Tools section to the JSX

Insert after the Token Stats closing (after line 262, before the closing `</div>` on line 264):

```tsx
      <Separator className="my-3" />

      <h4>Tools</h4>
      <div className="tools-launcher" data-testid="tools-launcher">
        <Button
          variant="outline"
          size="sm"
          onClick={() => setHotspotsOpen(true)}
          data-testid="tool-hotspots-button"
        >
          Hotspots
        </Button>
      </div>

      <HotspotsDialog
        open={hotspotsOpen}
        onOpenChange={setHotspotsOpen}
      />
```

Key design decisions:
- The `HotspotsDialog` component is rendered inside `DebugPanel` but the actual dialog renders in a Radix portal (outside the panel DOM). So even though `DebugPanel` is in a dockview sidebar, the dialog overlays the entire viewport correctly.
- Using `variant="outline"` and `size="sm"` to match the existing button styling in DebugPanel (consistent with the breakdown toggle button at line 157-163).
- The `tools-launcher` class provides a hook for CSS styling of the button row (spacing, flex layout).
- Future tools add more buttons and more `useState` hooks, each with their own dialog component.

### 4. Add CSS for the tools section

In the Cyclist stylesheet (wherever `.debug-panel` styles are defined), add:

```css
.tools-launcher {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 0.5rem;
}
```

This ensures buttons wrap gracefully if multiple tools are added.

### 5. Testing

Write/update tests for `DebugPanel`:
- Verify the "Tools" heading renders (`screen.getByText('Tools')`)
- Verify the "Hotspots" button renders (`screen.getByTestId('tool-hotspots-button')`)
- Verify clicking the "Hotspots" button opens the dialog
- Verify `HotspotsDialog` receives `open={true}` after button click
- Verify the dialog can be closed (sets `hotspotsOpen` back to false)

## Acceptance Criteria

- DebugPanel has a "Tools" section below Token Stats
- A `<Separator>` divides Token Stats from Tools
- "Hotspots" button is visible in the Tools section
- Clicking "Hotspots" opens `HotspotsDialog`
- The dialog can be closed and reopened
- Dialog renders correctly over the full viewport (not constrained to the dockview panel)
- The Tools section layout handles future button additions gracefully
- Unit tests pass

## Dependencies

### Depends On

- **79-1** (Create ToolDialog shared component) -- HotspotsDialog uses ToolDialog
- **79-2** (Migrate HotspotsPanel into HotspotsDialog) -- HotspotsDialog must exist for DebugPanel to import it

### Depended On By

- No direct dependents; this is the final P0 story that completes the dialog infrastructure

## Risks / Open Questions

1. **Radix portal inside dockview panel:** The `HotspotsDialog` component is rendered inside `DebugPanel`'s JSX tree, which lives inside a dockview panel. However, Radix Dialog renders its content in a portal (`document.body`), so the dialog should appear correctly over the entire viewport. Verify that dockview's CSS (z-index, overflow) does not interfere with the Radix portal overlay.

2. **Multiple dialog state management:** For the first tool (Hotspots), a single `useState` is fine. When 3-5 tools are added, having separate `useState` hooks per tool is verbose but simple. An alternative is a `useReducer` with a `openTool: string | null` state. The simple approach (separate `useState` per tool) is recommended for now to keep the code straightforward.

3. **DebugPanel scroll context:** DebugPanel is inside a dockview sidebar panel which may have its own scroll container (the `.dockview-panel-content` wrapper at line 191 of `DockviewWorkspace.tsx`). Adding the Tools section increases the panel's content height. If the sidebar is short, the Tools section may be hidden below the fold. The dockview panel content area should scroll naturally, but verify.

4. **Button styling consistency:** The "Hotspots" button uses `variant="outline"` to match the Analyze button pattern in the old HotspotsPanel. Consider whether `variant="secondary"` or a custom style would better distinguish tool launcher buttons from other controls in DebugPanel.
