# Story Context: PROJ-14243

## Settings Panel Visibility Toggles for All Panels

**Epic:** PROJ-14186 (Dockview Panel Migration)
**Points:** 3 | **Workflow:** trivial | **Priority:** P1

## Overview

Add a "Panel Visibility" section to Settings that shows all registered panels with checkboxes to show/hide them. This exposes existing panel management capabilities through the Settings UI.

## Key Files

| File | Purpose |
|------|---------|
| `packages/cyclist/src/public/components/panels/SettingsPanel.tsx` | **Primary change** - add Panel Visibility section |
| `packages/cyclist/src/public/components/DockviewWorkspace.tsx` | Panel inventory, titles, API access |
| `packages/cyclist/src/public/hooks/useLayoutPersistence.ts` | Layout persistence (already handles this) |

## Implementation Details

### 1. Panel Registry (DockviewWorkspace.tsx)

**PANEL_INVENTORY** (lines 34-51):
```typescript
export const PANEL_INVENTORY = {
  CHANGED: 'changed',
  DIFFS: 'diffs',
  DEBUG: 'debug',
  AUDIT_LOG: 'audit-log',
  TTY: 'tty',
  MESSAGE: 'message',      // Sacred center - cannot close
  SPRINT: 'sprint',
  WORKFLOW: 'workflow',
  AC: 'ac',
  TODO: 'todo',
  BACKGROUND: 'background',
  GIT: 'git',
  SETTINGS: 'settings',
} as const;
```

**PANEL_TITLES** (lines 95-109):
```typescript
const PANEL_TITLES: Record<string, string> = {
  changed: 'Changed',
  diffs: 'Diffs',
  debug: 'Debug',
  'audit-log': 'Audit Log',
  tty: 'Terminal',
  message: 'Message',
  sprint: 'Sprint',
  workflow: 'Workflow',
  ac: 'AC',
  todo: 'Todo',
  background: 'Background',
  git: 'Git',
  settings: 'Settings',
};
```

### 2. Dockview API Access (DockviewWorkspace.tsx)

**Get API reference** (lines 72-79):
```typescript
export function getDockviewApi(): DockviewApi | null {
  return dockviewApiRef;
}
```

**Closed panels tracking** (line 112):
```typescript
const closedPanels = new Set<string>();
```

**Restore panel** (lines 124-164):
```typescript
export function restorePanel(panelId: string): boolean {
  const api = dockviewApiRef;
  if (!api || !closedPanels.has(panelId)) return false;

  api.addPanel({
    id: panelId,
    component: 'PanelAdapter',
    params: { panelId },
    title: PANEL_TITLES[panelId] || panelId,
  });

  closedPanels.delete(panelId);
  return true;
}
```

**Get closed panels** (lines 117-119):
```typescript
export function getClosedPanels(): string[] {
  return Array.from(closedPanels);
}
```

### 3. Existing Checkbox Pattern (SettingsPanel.tsx)

Follow the existing pattern from lines 301-321:
```tsx
<label className="toggle-setting">
  <input
    type="checkbox"
    checked={settings.workflow?.bell_mode || false}
    onChange={(e) => handleToggle('workflow', 'bell_mode', e.target.checked)}
    disabled={saving}
  />
  Bell Mode
  <span className="setting-description">Description text...</span>
</label>
```

### 4. Implementation Approach

1. **Import from DockviewWorkspace:**
   - `PANEL_INVENTORY`, `PANEL_TITLES`
   - `getDockviewApi()`, `getClosedPanels()`, `restorePanel()`

2. **Add state for panel visibility:**
   - Query `getDockviewApi()?.panels` for visible panels
   - Query `getClosedPanels()` for hidden panels
   - Update on toggle

3. **Toggle handler:**
   - **Show panel:** Call `restorePanel(panelId)`
   - **Hide panel:** Call `api.getPanel(panelId)?.api.close()`

4. **Exclude MESSAGE panel** - sacred center cannot be closed

5. **No backend changes needed** - layout persistence already handles panel state

## Acceptance Criteria

- [ ] All registered panels appear in Settings list (except MESSAGE)
- [ ] Checkbox accurately reflects current visibility
- [ ] Toggling checkbox shows/hides panel immediately
- [ ] Hidden panels can be restored via this UI
- [ ] Styling matches existing Settings sections (`.toggle-setting` class)

## Notes

- Layout persistence via `/api/settings/layout` already saves panel state
- The `closedPanels` Set in DockviewWorkspace tracks closed panels in memory
- Panel close events are tracked via `onDidRemovePanel` callback (line 546-551)
