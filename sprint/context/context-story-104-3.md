# Story 104-3: BikeShow Client Layout Stash/Restore on Panel Focus

**Story ID:** 104-3
**Story Title:** BikeShow client layout stash/restore on panel focus
**Story Points:** TBD
**Jira Key:** MSSCI-14977
**Epic:** 104 (BikeShow/BikeRack Follow-up)
**Workflow:** tdd
**Status:** Planning

---

## Summary

The BikeShow (Cyclist) client handles `panel:focus` WebSocket events from the backend. When a `panel:focus` event arrives:

1. **First focus after reset:** If not already in single-panel view, stash the current dockview layout as "saved" state
2. **Render focused panel:** Show only the requested panel in a full-screen single-panel view
3. **Successive focuses:** Additional `/bc` calls (which trigger `panel:focus` events) preserve the original saved layout
4. **Reset focus:** When `focus: null` is received, restore the saved layout

The feature must work in both **full Cyclist mode** (App.tsx → DockviewWorkspace) and **BikeRack mode** (App.tsx → BikeRackWorkspace).

---

## Acceptance Criteria

- [ ] **AC1 - Stash on First Focus:** When a `panel:focus` event arrives and layout is not already focused, save current layout to `focusedState.savedLayout`
- [ ] **AC2 - Render Single-Panel View:** On focus, call `api.toJSON()`, clear all panels except the requested one, render it full-screen
- [ ] **AC3 - Preserve Saved Layout:** Successive `panel:focus` events for different panels preserve the original saved layout (no re-stash)
- [ ] **AC4 - Restore on Reset:** When `focus: null` is received, call `api.fromJSON()` with saved layout
- [ ] **AC5 - Works in Both Modes:** Focus/restore logic works identically in BikeRackWorkspace and full DockviewWorkspace
- [ ] **AC6 - No Persistence Side-Effect:** Focus mode layout changes (stashed, single-panel, restored) must NOT persist to `config.local.yaml` via `useLayoutPersistence`
- [ ] **AC7 - Panel Not Found:** If focused panel ID is invalid, log warning and do nothing
- [ ] **AC8 - Already Focused:** If already in focus mode for same panel ID, do nothing
- [ ] **AC9 - Component Unmount:** If component unmounts during focus, cleanly dispose focus mode without crashes
- [ ] **AC10 - WebSocket Reconnect:** Focus state persists across WebSocket reconnection

---

## Key Files to Modify

### Create
- **`pennyfarthing/packages/cyclist/src/public/hooks/useFocusPanel.ts`** — New hook for `panel:focus` WebSocket connection and state management

### Modify
- **`pennyfarthing/packages/cyclist/src/public/components/DockviewWorkspace.tsx`** — Integrate `useFocusPanel` hook into layout restoration flow
- **`pennyfarthing/packages/cyclist/src/public/components/BikeRackWorkspace.tsx`** — Same integration for BikeRack mode
- Optionally: `pennyfarthing/packages/cyclist/src/public/App.tsx` if centralized focus state is needed

---

## Architecture & Implementation Patterns

### State Machine: Layout Focus Mode

```
NORMAL
  ├─ (receive panel:focus with valid panelId)
  │   └─> [STASH: api.toJSON() → focusState.savedLayout]
  │       └─> [FOCUS: render single panel]
  │           └─> FOCUSED
  │
FOCUSED
  ├─ (receive panel:focus with different panelId)
  │   └─> [RENDER: switch to new panel, keep savedLayout]
  │       └─> FOCUSED (same saved state)
  │
  └─ (receive focus: null OR panel:reset)
      └─> [RESTORE: api.fromJSON(focusState.savedLayout)]
          └─> NORMAL
```

Key invariant: Once `focusState.savedLayout` is set, it is never overwritten until reset.

---

## Research: Existing Patterns

### Pattern 1: Layout Serialization (from DockviewWorkspace.tsx lines 427-446)

```typescript
// Restore from native Dockview serialized format
try {
  api.fromJSON(initialLayout);

  // After restoring, lock the message panel's group and hide its tab bar
  const messagePanel = api.getPanel(PANEL_INVENTORY.MESSAGE);
  if (messagePanel?.group) {
    messagePanel.group.locked = 'no-drop-target';
    messagePanel.group.model.header.hidden = true;
  }

  setIsReady(true);
  return;
} catch (err) {
  console.warn('[DockviewWorkspace] Failed to restore layout from JSON, building default:', err);
  // Fall through to build default layout
}
```

**Key:**
- Use `api.fromJSON(layout)` to restore from `SerializedDockview` format
- Use `api.toJSON()` to capture current state
- Lock center group after restore (only in full Cyclist mode, not BikeRack)
- Wrap in try/catch for robustness

### Pattern 2: WebSocket Hook Pattern (from useSprint.ts lines 73-147)

```typescript
export function useSprint(): UseSprintResult {
  const [data, setData] = useState<SprintData | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<ReturnType<typeof setTimeout>>();
  const isMountedRef = useRef(true);

  useEffect(() => {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/ws/sprint`;

    const connect = () => {
      if (!isMountedRef.current) {
        return;
      }

      try {
        wsRef.current = new WebSocket(wsUrl);

        wsRef.current.onopen = () => {
          console.debug('[useSprint] WebSocket connected');
        };

        wsRef.current.onmessage = (event) => {
          try {
            const msg = JSON.parse(event.data) as SprintMessage;
            if (msg.type === 'init' || msg.type === 'update') {
              const { type: _type, ...sprintData } = msg;
              setData((prev) => {
                if (!prev) return sprintData as SprintData;
                return { ...prev, ...sprintData } as SprintData;
              });
              setIsLoading(false);
              setError(null);
            }
          } catch (err) {
            console.error('[useSprint] Failed to parse message:', err);
          }
        };

        wsRef.current.onclose = () => {
          console.debug('[useSprint] WebSocket closed, reconnecting...');
          reconnectTimeoutRef.current = setTimeout(connect, 2000);
        };

        wsRef.current.onerror = (err) => {
          console.error('[useSprint] WebSocket error:', err);
          setError(new Error('WebSocket connection failed'));
        };
      } catch (err) {
        console.error('[useSprint] WebSocket init failed:', err);
        setError(err instanceof Error ? err : new Error('Failed to connect'));
        setIsLoading(false);
      }
    };

    connect();

    return () => {
      isMountedRef.current = false;
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, []);

  return { data, isLoading, error };
}
```

**Key patterns:**
- Use `isMountedRef` to check if component is still mounted before state updates
- Implement auto-reconnect on close (2-second timeout)
- JSON message parsing with error handling
- Cleanup WebSocket and timeouts on unmount

### Pattern 3: Panel Lookup (from DockviewWorkspace.tsx lines 592-606)

```typescript
// Find groups by their panels (groups don't have fixed names)
const changedPanel = api.getPanel(PANEL_INVENTORY.CHANGED);
const sprintPanel = api.getPanel(PANEL_INVENTORY.SPRINT);
const leftGroup = changedPanel?.group;
const rightGroup = sprintPanel?.group;

if (isSmall) {
  // Collapse sidebars at small viewport
  leftGroup?.api.setSize({ width: 0 });
  rightGroup?.api.setSize({ width: 0 });
} else {
  // Restore sidebars to configured width when viewport expands
  leftGroup?.api.setSize({ width: sidebarWidth });
  rightGroup?.api.setSize({ width: sidebarWidth });
}
```

**Key:**
- Use `api.getPanel(panelId)` to find a panel by ID
- Access group via `panel.group`
- Use optional chaining (`?.`) for safety

### Pattern 4: Panel Existence Check (from DockviewWorkspace.tsx lines 125-130)

```typescript
export function restorePanel(panelId: string): boolean {
  const api = dockviewApiRef;
  if (!api) return false;

  // If panel already exists in Dockview, nothing to restore
  if (api.getPanel(panelId)) return false;
  // ...
}
```

**Key:**
- Check if panel exists with `api.getPanel(panelId)`
- Return boolean for success/failure

### Pattern 5: Layout Persistence Hook (from useLayoutPersistence.ts lines 52-138)

```typescript
export function useLayoutPersistence(): UseLayoutPersistenceResult {
  const [layout, setLayout] = useState<SerializedDockview | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pendingLayoutRef = useRef<SerializedDockview | null>(null);

  // Load layout on mount via REST API
  useEffect(() => {
    const loadLayout = async () => {
      try {
        const response = await fetch('/api/settings/layout');
        if (response.ok) {
          const data = await response.json();
          if (data.layout && isValidDockviewLayout(data.layout)) {
            setLayout(data.layout as SerializedDockview);
          } else {
            setLayout(null);
          }
        } else {
          setLayout(null);
        }
      } catch (err) {
        console.error('[useLayoutPersistence] Failed to load layout:', err);
        setLayout(null);
        setError(err instanceof Error ? err : new Error('Failed to load layout'));
      } finally {
        setIsLoading(false);
      }
    };

    loadLayout();
  }, []);

  // Debounced save function via REST API
  const saveLayout = useCallback((newLayout: SerializedDockview) => {
    pendingLayoutRef.current = newLayout;

    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }

    debounceRef.current = setTimeout(async () => {
      const layoutToSave = pendingLayoutRef.current;
      if (!layoutToSave) return;

      setIsSaving(true);
      try {
        const response = await fetch('/api/settings/layout', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(layoutToSave),
        });

        if (!response.ok) {
          throw new Error('Failed to save layout');
        }
        setError(null);
      } catch (err) {
        console.error('[useLayoutPersistence] Failed to save layout:', err);
        setError(err instanceof Error ? err : new Error('Failed to save layout'));
      } finally {
        setIsSaving(false);
      }
    }, DEBOUNCE_DELAY);
  }, []);

  useEffect(() => {
    return () => {
      if (debounceRef.current) {
        clearTimeout(debounceRef.current);
      }
    };
  }, []);

  return { layout, isLoading, isSaving, error, saveLayout };
}
```

**Key patterns:**
- Use `useRef` for non-reactive state (WebSocket refs, debounce timers)
- Debounce with `setTimeout` to avoid excessive saves
- Track `isLoading`, `isSaving`, and `error` separately for UI feedback
- Clean up timers in cleanup function

---

## Implementation Steps

### Step 1: Create `useFocusPanel.ts` Hook

This hook will manage the `panel:focus` WebSocket connection and focus state.

**Interface:**
```typescript
interface FocusState {
  focusedPanelId: string | null;  // Current focused panel (if in focus mode)
  savedLayout: SerializedDockview | null;  // Original layout before focus
  isFocused: boolean;  // Shorthand for focusedPanelId !== null
}

interface UseFocusPanelResult {
  focusState: FocusState;
  applyFocus: (panelId: string) => void;  // Render single panel
  resetFocus: () => void;  // Restore saved layout
}

export function useFocusPanel(dockviewApi: DockviewApi | null): UseFocusPanelResult;
```

**Responsibilities:**
- Open WebSocket to `/ws/settings` (same endpoint as panel:toggle)
- Listen for `panel:focus` messages
- On focus: stash layout if not already focused, switch to single-panel view
- On reset: restore layout
- Implement auto-reconnect and unmount cleanup

### Step 2: Integrate into DockviewWorkspace

Modify `DockviewWorkspace.tsx` lines 422-522 to:
1. Call `useFocusPanel(apiRef.current)` in onReady
2. Subscribe to focus state changes
3. Apply layout restoration when needed (but NOT persist during focus)

**Pattern:**
```typescript
const focusResult = useFocusPanel(apiRef.current);

useEffect(() => {
  // If focus is active and requires restoration, handle it
  // But skip normal onLayoutChange callback during focus restore
  // to prevent persisting single-panel view to config.local.yaml
}, [focusResult.focusState]);
```

### Step 3: Integrate into BikeRackWorkspace

Apply the same `useFocusPanel` hook to BikeRackWorkspace for consistency.

### Step 4: Prevent Focus Layout from Persisting

In `DockviewWorkspace.tsx` line 525-539 (`handleLayoutChange`), add a guard:
```typescript
const handleLayoutChange = useCallback(() => {
  const api = apiRef.current;
  if (!api || !onLayoutChange) return;

  // CRITICAL: Don't persist focus mode layouts (AC6)
  if (focusResult.focusState.isFocused) {
    return;  // Skip persistence during focus
  }

  // ... rest of save logic
}, [onLayoutChange, focusResult.focusState.isFocused]);
```

---

## Edge Cases & Error Handling

### Edge Case 1: Focus on Already-Focused Panel

If `panel:focus` arrives with same `panelId` as current focused panel:
- Do nothing (already rendering that panel)
- Keep saved layout intact

**Code:**
```typescript
if (focusState.focusedPanelId === incomingPanelId) {
  console.debug(`[useFocusPanel] Already focused on panel ${incomingPanelId}`);
  return;
}
```

### Edge Case 2: Reset When Not Focused

If `focus: null` arrives but `focusState.focusedPanelId === null`:
- Do nothing
- Don't try to restore when nothing was stashed

**Code:**
```typescript
if (msg.focus === null && focusState.focusedPanelId === null) {
  return;  // Already in normal mode
}
```

### Edge Case 3: Invalid Panel ID

If focused panel doesn't exist in registry:
- Log warning
- Exit focus mode gracefully
- Restore to normal layout

**Code:**
```typescript
if (!api.getPanel(panelId)) {
  console.warn(`[useFocusPanel] Panel not found: ${panelId}`);
  setFocusState(prev => ({ ...prev, focusedPanelId: null }));
  return;
}
```

### Edge Case 4: Component Unmount During Focus

If component unmounts while in focus mode:
- Close WebSocket
- Clear timers
- Don't attempt state updates

**Handled by `isMountedRef` pattern from `useSprint`.**

### Edge Case 5: WebSocket Reconnection Preserves State

If WebSocket reconnects:
- Keep `focusState` intact (don't reset on reconnect)
- Only update when new messages arrive

**Code:**
```typescript
wsRef.current.onclose = () => {
  console.debug('[useFocusPanel] WebSocket closed, reconnecting...');
  // DON'T reset focusState here — preserve focus across reconnect
  reconnectTimeoutRef.current = setTimeout(connect, 2000);
};
```

---

## Message Protocol

### WebSocket Message Format

**Focus Event:**
```json
{
  "type": "panel:focus",
  "focus": "sprint"
}
```

**Reset Event:**
```json
{
  "type": "panel:focus",
  "focus": null
}
```

**Parser:**
```typescript
interface FocusPanelMessage {
  type: 'panel:focus';
  focus: string | null;
}

const msg = JSON.parse(event.data) as FocusPanelMessage;
if (msg.type === 'panel:focus' && msg.focus !== undefined) {
  // Handle focus event
}
```

---

## Types to Import

```typescript
import type { DockviewApi, SerializedDockview } from 'dockview-react';
```

---

## Testing Strategy (TDD)

### Test 1: Stash on First Focus
- Mock DockviewApi with `toJSON()`, `getPanel()`, `removePanel()`, `addPanel()`
- Call `useFocusPanel` hook
- Send `panel:focus` WebSocket message
- Assert `focusState.savedLayout` is set and equals result of `api.toJSON()`
- Assert single-panel view rendered (all except focused panel removed)

### Test 2: Successive Focuses Preserve Saved Layout
- Stash layout (from Test 1)
- Send second `panel:focus` for different panel
- Assert `focusState.savedLayout` unchanged from first stash
- Assert new panel rendered

### Test 3: Reset Restores Layout
- Stash and focus (from Test 1)
- Send `focus: null`
- Assert `api.fromJSON(savedLayout)` called
- Assert `focusState.focusedPanelId === null`

### Test 4: Invalid Panel ID Handled
- Send `panel:focus` with non-existent panel ID
- Assert warning logged
- Assert focus mode not entered (no stash)

### Test 5: Component Unmount Cleans Up
- Mount `useFocusPanel` with WebSocket connected
- Unmount component
- Assert `isMountedRef.current === false`
- Assert WebSocket closed
- Assert no state updates attempted

### Test 6: Focus Mode Doesn't Persist
- Stash and focus on panel
- Mock `saveLayout` callback
- Trigger dockview layout change
- Assert `saveLayout` not called during focus

---

## Files and Line References

| File | Lines | Purpose |
|------|-------|---------|
| `DockviewWorkspace.tsx` | 37-54 | PANEL_INVENTORY (panel IDs) |
| `DockviewWorkspace.tsx` | 82-95 | Panel group definitions (LEFT/RIGHT_SIDEBAR_PANELS) |
| `DockviewWorkspace.tsx` | 227-302 | `createDefaultDockviewLayout()` pattern |
| `DockviewWorkspace.tsx` | 422-522 | `onReady` handler with fromJSON/toJSON pattern |
| `DockviewWorkspace.tsx` | 525-539 | `handleLayoutChange` debounce pattern |
| `BikeRackWorkspace.tsx` | 97-140 | Simple single-group layout |
| `useSprint.ts` | 73-147 | WebSocket hook pattern (isMountedRef, reconnect, cleanup) |
| `useLayoutPersistence.ts` | 52-138 | Layout persistence pattern |
| `App.tsx` | 203-339 | App routing (BikeRack detection, DockviewWorkspace props) |

---

## Critical Constraints

1. **No Persistence During Focus** — Use `focusState.isFocused` guard in `handleLayoutChange` to skip persisting single-panel layouts to `config.local.yaml`
2. **Stash Once, Restore Exactly** — `focusState.savedLayout` is immutable once set; only reset when `focus: null`
3. **Both Modes** — Must work in BikeRackWorkspace AND DockviewWorkspace identically
4. **WebSocket Endpoint** — Use `/ws/settings` (same as panel:toggle), not a new endpoint
5. **Cleanup on Unmount** — Use `isMountedRef` to prevent state updates after unmount
6. **Message Panel Lock (Full Mode Only)** — When restoring in full Cyclist mode, re-lock message panel group after `fromJSON()`

---

## Deliverables

1. **`useFocusPanel.ts`** — New hook with full implementation
2. **`DockviewWorkspace.tsx`** — Updated with `useFocusPanel` integration and persistence guard
3. **`BikeRackWorkspace.tsx`** — Updated with `useFocusPanel` integration
4. **Unit Tests** — Test suite covering all acceptance criteria
5. **Integration Tests** — E2E test of WebSocket flow in both workspace modes
