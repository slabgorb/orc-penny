# Epic 70: Flexible Workspace - Technical Context

## Overview

Transform Cyclist from fixed panel positions to a flexible, dockable layout system. Users can drag panels between sidebars, reorder tabs, and have layouts remembered per-project.

## Architecture

### Current State

- Cyclist is Electron-based vanilla JS (`packages/cyclist/src/public/`)
- Single `styles.css` file (~2400 lines)
- Epic 69 establishing React + Tailwind build pipeline
- `App.tsx` is placeholder - components will be added incrementally

### Target Architecture

```
+------------------+---------------------------+------------------+
| Left Sidebar     |      Message View         | Right Sidebar    |
| (panels/tabs)    |      (SACRED CENTER)      | (panels/tabs)    |
|                  |                           |                  |
| [draggable]      |      [fixed position]     | [draggable]      |
| [collapsible]    |                           | [collapsible]    |
| [resizable]      |                           | [resizable]      |
+------------------+---------------------------+------------------+
```

**Constraints:**
- Message view is **sacred** - never moves, rejects drops
- Sidebars are optional and collapsible
- Panels can be moved between sidebars
- Panels can be tabbed within a sidebar
- Layout saved per-project in `.pennyfarthing/config.local.yaml`

## Panel Inventory

These existing panels must be supported:

| Panel | Default Position | Purpose |
|-------|------------------|---------|
| Changed | Left | Show modified files |
| Diffs | Left | File diffs with navigation |
| Debug | Left | OTEL span viewer |
| Sprint | Right | Story/sprint status |
| Progress | Right | Todos + BikeLane workflow |
| Background | Right | Background task monitoring |
| Git | Right | Git status per repo |
| Settings | Right | Theme picker, input settings |

## Library Decision: FlexLayout vs Dockview

Story 70-1 must evaluate and choose:

| Library | Pros | Cons |
|---------|------|------|
| **FlexLayout** | VS Code-like, mature, React-native | Heavier bundle, more config |
| **Dockview** | Modern, lightweight, TypeScript | Newer, less battle-tested |

**Evaluation criteria:**
1. React integration quality
2. Fixed center panel support (sacred message view)
3. Tab reordering + cross-sidebar drag
4. Serialization for layout persistence
5. Bundle size
6. Accessibility (keyboard navigation)

## Key Files

| File | Purpose |
|------|---------|
| `packages/cyclist/src/public/App.tsx` | Root React component |
| `packages/cyclist/src/public/index.tsx` | React bootstrap |
| `packages/cyclist/src/public/styles.css` | Existing vanilla CSS (bridge during migration) |
| `.pennyfarthing/config.local.yaml` | Layout persistence target |

## Dependencies

```json
{
  "dependencies": {
    "flexlayout-react": "^0.7.x",  // OR
    "dockview": "^4.x"
  }
}
```

Package location: `packages/cyclist/package.json`

## Integration Points

### WheelHub Communication

Panels receive data via WebSocket from WheelHub server (`packages/cyclist/src/server.ts`). The docking system must:
- Maintain existing panel→data bindings
- Support lazy panel rendering (don't render collapsed panels)
- Preserve panel state across layout changes

### Tailwind Integration

Epic 69 sets up Tailwind. Docking library styles should:
- Respect CSS variables for theming
- Use Tailwind utilities where possible
- Not conflict with existing vanilla CSS during migration

## Acceptance Criteria (Story 70-1)

1. FlexLayout or Dockview integrated and rendering
2. Message view fixed center, cannot be moved
3. Left sidebar with tabs (Changed, Diffs, Debug)
4. Right sidebar with tabs (Sprint, Progress, Background, Git, Settings)
5. Panels can be collapsed individually
6. Basic resize handles functional

## Related Stories

- **70-2:** Panel Drag-and-Drop (drag between sidebars, ghost preview)
- **70-3:** Layout Persistence (save/restore to config.local.yaml)

## References

- UX Spec: `docs/planning/ux-design-specification.md` (sections 11, 18, 20)
- Epic breakdown: `docs/planning/cyclist-react-migration-epics.md`
- FlexLayout: https://github.com/nicr/FlexLayout
- Dockview: https://github.com/mathuo/dockview
