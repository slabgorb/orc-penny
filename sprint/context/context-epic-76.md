# Epic 76: Dockview Panel Migration

## Overview

Replace hand-rolled panel management with Dockview library in Cyclist.

**Current state:** Custom 1,042-line DockingWorkspace.tsx with bugs
**Target state:** Dockview-based workspace with proper panel docking

## Background

`dockview-react@4.13.1` is already installed but unused. Migration enables:
- Floating panels (pop-out windows)
- Split views within regions
- Panel maximization
- Better drag-and-drop UX
- Full ARIA accessibility

## Technical Details

See `/pennyfarthing/docs/adr/0019-dockview-migration.md` for full implementation plan.

### Files to Delete
- `packages/cyclist/src/public/components/DockingWorkspace.tsx` (~1,042 lines)

### Files to Create
- `packages/cyclist/src/public/components/DockviewWorkspace.tsx` - New Dockview-based workspace
- `packages/cyclist/src/public/styles/dockview-theme.css` - Theme customization

### Files to Modify
- `packages/cyclist/src/public/App.tsx` - Switch to DockviewWorkspace

### Key Patterns

#### Panel Adapter Pattern
Existing panels work unchanged - just wrap them for Dockview:

```typescript
import { IDockviewPanelProps } from 'dockview-react';

const panelComponents: Record<string, ComponentType> = {
  message: MessagePanel,
  sprint: SprintPanel,
  progress: ProgressPanel,
  // ... etc
};

function PanelAdapter({ params }: IDockviewPanelProps<{ panelId: string }>) {
  const Component = panelComponents[params.panelId];
  return Component ? (
    <ErrorBoundary panelName={params.panelId}>
      <Component />
    </ErrorBoundary>
  ) : null;
}
```

#### Sacred Center (MessagePanel)
```typescript
// MessagePanel cannot be closed or moved
const messagePanel = api.getPanel('message');
messagePanel?.group?.locked = true;
```

## Stories

### MSSCI-14001: Replace DockingWorkspace with Dockview (8 points)
Single-pass replacement of the hand-rolled panel system.

## Success Criteria

- DockingWorkspace.tsx deleted (1,042 lines removed)
- DockviewWorkspace.tsx renders all 9 panels
- MessagePanel locked in center (cannot close/move)
- Panels draggable between sidebars
- Layout persists to config.local.yaml
- Responsive collapse at <1024px works
- Theme matches current Cyclist design
- All existing panel functionality preserved
- Tests pass

## References

- [Dockview Documentation](https://dockview.dev/)
- [Dockview React Guide](https://dockview.dev/docs/components/dockview)
- [ADR-0019: Dockview Migration](/pennyfarthing/docs/adr/0019-dockview-migration.md)
