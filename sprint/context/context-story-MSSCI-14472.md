# Story Context: 84-3 - Per-dimension drill-through from health gauge

## Summary

Wire the health gauge's dimension breakdown items so that clicking a dimension opens the corresponding observatory tool dialog. When a user taps a dimension like "TODO/FIXME Density" in the expanded gauge breakdown, it opens the CodeMarkersDialog (TODOs tab). This connects the composite health score to actionable detail views, completing the Observatory drill-down UX. Depends on 84-2 for the gauge component and on epic 79 story 79-3 for the dialog infrastructure in DebugPanel.

## Current State

### HealthGauge component (from 84-2)

After story 84-2 is implemented, `packages/cyclist/src/public/components/HealthGauge.tsx` will render:

- A radial SVG gauge with composite score 0-100
- A dimension breakdown list (when expanded) showing each dimension's name, weight, and score
- Currently no click handlers on individual dimension rows

The gauge component will be mounted in `DebugPanel.tsx` between the opening div and "Context Usage" heading.

### DebugPanel current state

`packages/cyclist/src/public/components/panels/DebugPanel.tsx` (268 lines) currently has:

- Lines 1-15: imports (React, Button, Badge, Separator)
- Lines 93-130: `DebugPanel` component with `useState` for context, tokenStats, breakdownExpanded
- Lines 135-266: JSX rendering context usage and token stats
- No dialog state, no dialog components, no observatory tool dialog imports

After story 84-2, DebugPanel will also import and render `HealthGauge`.

### Observatory tool dialogs (from epic 79 story 79-3)

Epic 79 story 79-3 establishes the "tool launcher row" in DebugPanel, which mounts observatory tool dialogs and provides state setters to open them. These dialogs do not exist yet (they will be created by epic 79 story 79-3). The expected pattern, based on the epic 84 context document (lines 342-358), maps 8 dimensions to 6 distinct dialog components:

| Dimension | Dialog Component | Behavior |
|-----------|-----------------|----------|
| Churn Concentration | `HotspotsDialog` | Opens with default view |
| TODO/FIXME Density | `CodeMarkersDialog` | Opens with TODOs tab active |
| Complexity | `ComplexityDialog` | Opens with default view |
| Test Coverage Gaps | `HotspotsDialog` | Opens with filtered view (untested files) |
| Dead Code | `DeadCodeDialog` | Opens with default view |
| Deprecation Debt | `CodeMarkersDialog` | Opens with Deprecated tab active |
| Dependency Freshness | `DependenciesDialog` | Opens with default view |
| Agent Context Efficiency | `AgentLoadDialog` | Opens with default view |

Currently none of these dialog components (`HotspotsDialog`, `CodeMarkersDialog`, `ComplexityDialog`, `DeadCodeDialog`, `DependenciesDialog`, `AgentLoadDialog`) exist in the codebase. They will be created by their respective epics (79-83). Epic 79 story 79-3 specifically creates the tool launcher row in DebugPanel that mounts these dialogs and manages their open state.

### Radix Dialog pattern

Per the project memory (MEMORY.md): Radix Dialog renders in a portal, so tests cannot check `title` attributes -- they must check `data-state` on triggers instead. Dialogs use the shadcn `Dialog` component from `packages/cyclist/src/public/components/ui/`. The 17 shadcn components are installed at `src/public/components/ui/`.

## Target State

After implementation:

1. **`HealthGauge.tsx`** accepts an `onDimensionClick(dimensionName: string)` callback prop
2. Each dimension row in the expanded breakdown is clickable and calls `onDimensionClick` with the dimension name (e.g., `"churn"`, `"todo_density"`, `"complexity"`)
3. **`DebugPanel.tsx`** maps dimension names to dialog open state setters provided by the tool launcher row (from epic 79 story 79-3)
4. Clicking a dimension opens the correct dialog:
   - `"churn"` and `"test_gaps"` open HotspotsDialog (with different initial views)
   - `"todo_density"` and `"deprecation_debt"` open CodeMarkersDialog (with different active tabs)
   - `"complexity"` opens ComplexityDialog
   - `"dead_code"` opens DeadCodeDialog
   - `"dependency_freshness"` opens DependenciesDialog
   - `"agent_context"` opens AgentLoadDialog
5. If a dialog component is not available (epic not implemented yet), clicking the dimension is a no-op or shows a tooltip saying "Tool not available"
6. Each dimension row has a visual affordance (cursor, hover effect) indicating it is clickable

## Key Files

### Files to Modify

| File | Path | Lines | What Changes |
|------|------|-------|--------------|
| `HealthGauge.tsx` | `pennyfarthing/packages/cyclist/src/public/components/HealthGauge.tsx` | Created in 84-2 | Add `onDimensionClick` prop, add click handlers to dimension breakdown rows, add cursor/hover styles |
| `DebugPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/DebugPanel.tsx` | Modified in 84-2 | Add dimension-to-dialog mapping handler, pass `onDimensionClick` to HealthGauge, wire to dialog state setters |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| Epic 84 context | `sprint/context/context-epic-84.md` | Dimension-to-dialog mapping table (lines 342-358), `onDimensionClick` prop design (line 358) |
| Story 84-2 context | `sprint/context/context-story-84-2.md` | HealthGauge component design, DebugPanel modifications |
| `useHealthScore.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useHealthScore.ts` | `DimensionScore` interface with `name` field (created in 84-2) |
| `DebugPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/DebugPanel.tsx` | Current layout, where HealthGauge is mounted (modified in 84-2) |
| shadcn Dialog | `pennyfarthing/packages/cyclist/src/public/components/ui/dialog.tsx` | Radix Dialog component pattern for portal rendering |

## Technical Approach

### 1. Add `onDimensionClick` prop to HealthGauge

Extend the HealthGauge component props:

```tsx
interface HealthGaugeProps {
  onDimensionClick?: (dimensionName: string) => void;
}

export function HealthGauge({ onDimensionClick }: HealthGaugeProps): React.ReactElement {
  // ... existing gauge rendering ...

  // In the dimension breakdown list:
  {data?.dimensions.map((dim) => (
    <button
      key={dim.name}
      className="dimension-row"
      onClick={() => onDimensionClick?.(dim.name)}
      disabled={!dim.available}
      data-testid={`dimension-${dim.name}`}
      style={{ cursor: onDimensionClick ? 'pointer' : 'default' }}
    >
      <span className="dimension-label">{dim.label}</span>
      <span className="dimension-score">
        {dim.available ? `${dim.score?.toFixed(1)}` : 'N/A'}
      </span>
      <span className="dimension-weight">{(dim.weight * 100).toFixed(0)}%</span>
    </button>
  ))}
}
```

Each dimension row changes from a `<div>` to a `<button>` with:
- `onClick` calling `onDimensionClick(dim.name)`
- `disabled` when the dimension has no cached data (`available: false`)
- Visual affordance: `cursor: pointer`, hover background color change
- `data-testid` for testing

### 2. Create dimension-to-dialog mapping in DebugPanel

Define a mapping function in DebugPanel that translates dimension names to dialog opener calls:

```tsx
// In DebugPanel, after dialog state is set up by epic 79 story 79-3:
const handleDimensionClick = useCallback((dimensionName: string) => {
  switch (dimensionName) {
    case 'churn':
      setHotspotsDialogOpen?.(true);
      break;
    case 'todo_density':
      setCodeMarkersDialogOpen?.({ open: true, tab: 'todos' });
      break;
    case 'complexity':
      setComplexityDialogOpen?.(true);
      break;
    case 'test_gaps':
      setHotspotsDialogOpen?.({ open: true, filter: 'untested' });
      break;
    case 'dead_code':
      setDeadCodeDialogOpen?.(true);
      break;
    case 'deprecation_debt':
      setCodeMarkersDialogOpen?.({ open: true, tab: 'deprecated' });
      break;
    case 'dependency_freshness':
      setDependenciesDialogOpen?.(true);
      break;
    case 'agent_context':
      setAgentLoadDialogOpen?.(true);
      break;
  }
}, [/* dialog setters */]);
```

The exact dialog state setter APIs depend on how epic 79 story 79-3 implements the tool launcher row. The mapping above uses optional chaining (`?.`) so it degrades gracefully when dialog components are not yet available.

### 3. Pass handler to HealthGauge

```tsx
<HealthGauge onDimensionClick={handleDimensionClick} />
```

### 4. Handle unavailable dialogs gracefully

Since epics 80-83 may not be implemented when this story ships, some dialog components may not exist. The `handleDimensionClick` function should check whether the dialog setter function is available before calling it. If not available, either:
- Do nothing (silent no-op)
- Show a transient tooltip: "Run the [tool name] analysis first"

The recommended approach is the silent no-op with a CSS visual cue (reduced opacity, no cursor pointer) on dimensions whose dialogs are not wired up. This avoids adding tooltip infrastructure for a transitional state.

### 5. Add styles for clickable dimension rows

```css
.dimension-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 4px 8px;
  border: none;
  background: transparent;
  width: 100%;
  cursor: pointer;
  border-radius: 4px;
  transition: background-color 0.15s;
  font-size: inherit;
  color: inherit;
  text-align: left;
}

.dimension-row:hover:not(:disabled) {
  background-color: var(--bg-hover, rgba(255, 255, 255, 0.05));
}

.dimension-row:disabled {
  opacity: 0.5;
  cursor: default;
}
```

## Acceptance Criteria

- Clicking a dimension row in the expanded HealthGauge breakdown calls `onDimensionClick` with the dimension name string
- DebugPanel maps dimension names to the correct dialog openers:
  - `"churn"` opens HotspotsDialog
  - `"todo_density"` opens CodeMarkersDialog (TODOs tab)
  - `"complexity"` opens ComplexityDialog
  - `"test_gaps"` opens HotspotsDialog (filtered to untested files)
  - `"dead_code"` opens DeadCodeDialog
  - `"deprecation_debt"` opens CodeMarkersDialog (Deprecated tab)
  - `"dependency_freshness"` opens DependenciesDialog
  - `"agent_context"` opens AgentLoadDialog
- Clicking a dimension with `available: false` is a no-op (button is disabled)
- Clicking a dimension whose dialog is not yet implemented (epic not shipped) is a no-op (graceful degradation via optional chaining)
- Dimension rows have visual click affordance (pointer cursor, hover background)
- Disabled dimension rows have reduced opacity and default cursor
- Each dimension row has a `data-testid` attribute (`dimension-{name}`) for testing
- Radix Dialog portal rendering works correctly (tests check `data-state` on triggers, not `title` attributes)

## Dependencies

### Depends On

- **84-2** (Health score API + gauge component) -- creates the `HealthGauge.tsx` component and mounts it in DebugPanel. This story modifies that component to add click handlers
- **Epic 79 story 79-3** (Tool launcher row in DebugPanel) -- establishes the dialog mounting infrastructure in DebugPanel (dialog components, open state, state setters). Without this, the dimension click handlers have nothing to call. The drill-through feature degrades gracefully (no-op clicks) if 79-3 is not complete, but the full UX requires it
- **Epics 80-83** (Observatory tool dialogs) -- each epic creates the dialog component for its tool. Until a dialog is implemented, clicking that dimension is a no-op

### Depended On By

- Nothing directly depends on this story. It is the terminal leaf of epic 84

## Risks / Open Questions

1. **Dialog API shape unknown**: The `handleDimensionClick` mapping assumes specific dialog state setter APIs (e.g., `setCodeMarkersDialogOpen({ open: true, tab: 'todos' })`). The actual API depends on how epic 79 story 79-3 implements the tool launcher row. If the dialog setters use a simpler API (just `setOpen(true)` with no tab/filter control), then CodeMarkersDialog and HotspotsDialog cannot be opened to a specific tab/view, and the drill-through loses specificity. Coordinate with epic 79 to ensure dialog openers accept initial state parameters.

2. **Two dimensions share HotspotsDialog**: Both "Churn Concentration" and "Test Coverage Gaps" open HotspotsDialog, but with different initial views. This requires HotspotsDialog to accept an initial filter or view mode prop. If HotspotsDialog only supports a single default view, both dimensions will open the same view, which is acceptable but less useful.

3. **Two dimensions share CodeMarkersDialog**: Both "TODO/FIXME Density" and "Deprecation Debt" open CodeMarkersDialog, but with different active tabs. This requires CodeMarkersDialog to accept an `initialTab` prop. Same coordination concern as above.

4. **Ordering of implementation**: This story is 1 point and P1, meaning it can be deferred. If shipped before epic 79 story 79-3, all dimension clicks will be no-ops. The code is valid but provides no user value. Consider sequencing this story after 79-3 to ensure the drill-through works on at least the hotspots dimension.

5. **Accessibility**: Changing dimension rows from `<div>` to `<button>` improves keyboard accessibility (focusable, Enter/Space activates). Disabled buttons should have `aria-disabled="true"` and the dimension breakdown should be navigable with arrow keys for screen reader users. Consider wrapping the breakdown in a `role="list"` with dimension rows as `role="listitem"`.

6. **Testing Radix portals**: Per project memory, Radix Dialog renders in a portal. Tests for the drill-through should: (a) click a dimension row, (b) verify the dialog trigger's `data-state` changes to `"open"`, and (c) verify the dialog content appears in the DOM (via portal). Do not assert on `title` attributes of dialog elements.
