# Story 104-2: WheelHub config file watch + panel focus broadcast

**Jira Key:** PROJ-14976
**Story Points:** 5
**Workflow:** tdd
**Branch:** feature/104-2-wheelhub-focus-broadcast

## Story

WheelHub server watches `config.local.yaml` for `focus` key changes. On change, broadcast `panel:focus` event over WebSocket to all connected clients with the target panel name (or null for reset).

## Acceptance Criteria

1. **New `/ws/focus` WebSocket endpoint** — clients connect and receive initial focus state from config.local.yaml (or null if not set)
2. **Config watcher extension** — extend existing config.local.yaml watcher (line 1172–1197) to track `focus` key changes
3. **Debounced broadcasts** — broadcast `panel:focus` events with 100ms debounce to prevent spam
4. **Change detection** — track `lastKnownFocus` to avoid broadcasting when value hasn't actually changed
5. **No spurious broadcasts** — only broadcast on actual focus change, not on every file write

## Key Files to Modify

### `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/websocket.ts`

#### 1. Add focus client set (after line 161):
```javascript
// Focus WebSocket clients (PROJ-14976: WheelHub panel focus broadcast)
const focusClients = new Set<WebSocket>();
```

#### 2. Add focus debounce timer and last known state (after line 184):
```javascript
// Focus broadcast debounce and tracking
let focusDebounceTimer: ReturnType<typeof setTimeout> | null = null;
let lastKnownFocus: string | null = null;
const FOCUS_DEBOUNCE_MS = 100; // Debounce for focus changes
```

#### 3. Add focus client getter (after line 300):
```javascript
export function getFocusClients(): Set<WebSocket> {
  return focusClients;
}
```

#### 4. Add focus broadcast function (after line 1624):
```javascript
/**
 * Broadcast panel focus change to all connected clients
 * Exported for use by config watcher
 */
export function broadcastFocusUpdate(focus: string | null): void {
  const message = JSON.stringify({ type: 'update', focus });
  for (const client of focusClients) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  }
}
```

#### 5. Add focus WebSocket server creation (after line 433):
```javascript
// WebSocket server for focus at /ws/focus (PROJ-14976: WheelHub panel focus broadcast)
const focusWss = new WebSocketServer({ noServer: true });
```

#### 6. Add focus upgrade route (after line 512):
```javascript
} else if (pathname === '/ws/focus') {
  focusWss.handleUpgrade(request, socket, head, (ws) => {
    focusWss.emit('connection', ws, request);
  });
```

#### 7. Add focus connection handler (after line 1197):
```javascript
// Handle focus WebSocket connections (PROJ-14976: WheelHub panel focus broadcast)
focusWss.on('connection', async (ws: WebSocket) => {
  console.log('[WebSocket] Focus client connected');
  focusClients.add(ws);

  // Send initial focus state on connection
  try {
    // Read current focus value from config.local.yaml
    let currentFocus: string | null = null;
    const configPath = join(projectDir, '.pennyfarthing', 'config.local.yaml');
    if (existsSync(configPath)) {
      try {
        const content = fs.readFileSync(configPath, 'utf-8');
        const parsed = parse(content) as Record<string, unknown>;
        if (parsed?.focus !== undefined) {
          currentFocus = typeof parsed.focus === 'string' ? parsed.focus : null;
        }
      } catch (err) {
        console.error('[WebSocket] Failed to parse config.local.yaml for focus:', err);
      }
    }
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'init', focus: currentFocus }));
    }
  } catch (err) {
    console.error('[WebSocket] Error reading initial focus state:', err);
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'init', focus: null }));
    }
  }

  // Remove client on disconnect
  ws.on('close', () => {
    console.log('[WebSocket] Focus client disconnected');
    focusClients.delete(ws);
  });

  // Handle errors gracefully
  ws.on('error', () => {
    focusClients.delete(ws);
  });
});
```

#### 8. Extend config watcher (replace lines 1172–1197):

Replace the existing settings file watcher block with:

```javascript
// Set up settings file watcher for config.local.yaml changes
// This enables real-time bidirectional sync between ControlBar and SettingsPanel
// Also broadcasts focus updates for panel focus broadcast (PROJ-14976)
if (existsSync(join(projectDir, '.pennyfarthing'))) {
  try {
    watch(join(projectDir, '.pennyfarthing'), { recursive: false }, (eventType, filename) => {
      if (!filename || filename !== 'config.local.yaml') return;

      // Debounce rapid changes
      if (settingsDebounceTimer) {
        clearTimeout(settingsDebounceTimer);
      }
      if (focusDebounceTimer) {
        clearTimeout(focusDebounceTimer);
      }

      settingsDebounceTimer = setTimeout(async () => {
        try {
          const settings = await getSettingsForWebSocket(projectDir);
          broadcastSettingsUpdate(settings);
        } catch (err) {
          console.error('[WebSocket] Failed to broadcast settings update:', err);
        }
        settingsDebounceTimer = null;
      }, SETTINGS_DEBOUNCE_MS);

      focusDebounceTimer = setTimeout(() => {
        try {
          const configPath = join(projectDir, '.pennyfarthing', 'config.local.yaml');
          if (existsSync(configPath)) {
            try {
              const content = fs.readFileSync(configPath, 'utf-8');
              const parsed = parse(content) as Record<string, unknown>;
              const focus = typeof parsed?.focus === 'string' ? parsed.focus : null;

              // Only broadcast if focus value actually changed
              if (focus !== lastKnownFocus) {
                console.log('[WebSocket] Focus changed:', lastKnownFocus, '->', focus);
                lastKnownFocus = focus;
                broadcastFocusUpdate(focus);
              }
            } catch (err) {
              console.error('[WebSocket] Failed to parse config.local.yaml for focus:', err);
            }
          }
        } catch (err) {
          console.error('[WebSocket] Failed to broadcast focus update:', err);
        }
        focusDebounceTimer = null;
      }, FOCUS_DEBOUNCE_MS);
    });
    console.log('[WebSocket] Settings and focus file watchers set up for config.local.yaml');
  } catch (err) {
    console.error('[WebSocket] Failed to set up settings/focus file watcher:', err);
  }
}
```

#### 9. Add required imports (if not already present):

At the top of the file, ensure `parse` is imported from `yaml`:
```javascript
import { parse, stringify } from 'yaml';
```

Ensure `fs` is imported:
```javascript
import fs from 'fs';
```

## Implementation Patterns

### Client Set Pattern
From lines 139–161, all WebSocket client sets follow this pattern:
```typescript
const storyClients = new Set<WebSocket>();
const gitClients = new Set<WebSocket>();
// ... export getter
export function getStoryClients(): Set<WebSocket> {
  return storyClients;
}
```

### WebSocket Server Creation
From lines 380–436, each endpoint creates a noServer WebSocketServer:
```typescript
const storyWss = new WebSocketServer({ noServer: true });
const gitWss = new WebSocketServer({ noServer: true });
```

### Upgrade Route Pattern
From lines 466–473, routes are registered in the upgrade handler:
```typescript
} else if (pathname === '/ws/story') {
  storyWss.handleUpgrade(request, socket, head, (ws) => {
    storyWss.emit('connection', ws, request);
  });
} else if (pathname === '/ws/git') {
  gitWss.handleUpgrade(request, socket, head, (ws) => {
    gitWss.emit('connection', ws, request);
  });
}
```

### Connection Handler Pattern
From lines 752–777 (settings) and 614–635 (story):
```typescript
settingsWss.on('connection', async (ws: WebSocket) => {
  console.log('[WebSocket] Settings client connected');
  settingsClients.add(ws);

  // Send initial data on connection
  try {
    const settings = await getSettingsForWebSocket(getProjectDir());
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'init', settings }));
    }
  } catch (err) {
    console.error('[WebSocket] Error fetching initial settings:', err);
  }

  // Remove client on disconnect
  ws.on('close', () => {
    console.log('[WebSocket] Settings client disconnected');
    settingsClients.delete(ws);
  });

  // Handle errors gracefully
  ws.on('error', () => {
    settingsClients.delete(ws);
  });
});
```

### Broadcast Function Pattern
From lines 1595–1602 (settings) and 1604–1613 (context):
```typescript
export function broadcastSettingsUpdate(settings: unknown): void {
  const message = JSON.stringify({ type: 'update', settings });
  for (const client of settingsClients) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  }
}
```

### Config Watcher Pattern
From lines 1172–1197 (existing settings watcher):
```typescript
if (existsSync(join(projectDir, '.pennyfarthing'))) {
  try {
    watch(join(projectDir, '.pennyfarthing'), { recursive: false }, (eventType, filename) => {
      if (!filename || filename !== 'config.local.yaml') return;

      // Debounce rapid changes
      if (settingsDebounceTimer) {
        clearTimeout(settingsDebounceTimer);
      }

      settingsDebounceTimer = setTimeout(async () => {
        try {
          const settings = await getSettingsForWebSocket(projectDir);
          broadcastSettingsUpdate(settings);
        } catch (err) {
          console.error('[WebSocket] Failed to broadcast settings update:', err);
        }
        settingsDebounceTimer = null;
      }, SETTINGS_DEBOUNCE_MS);
    });
  } catch (err) {
    console.error('[WebSocket] Failed to set up settings file watcher:', err);
  }
}
```

## Design Notes

### No separate watcher needed
The existing config.local.yaml watcher (lines 1172–1197) watches the entire `.pennyfarthing/` directory. Extend this single watcher to handle both settings and focus changes rather than creating a second watcher. This avoids race conditions and duplicate file reads.

### Track lastKnownFocus to prevent spurious broadcasts
The focus debounce handler should compare the new focus value to `lastKnownFocus` before broadcasting. Only broadcast if the value actually changed. This prevents repeated broadcasts when the file is touched but not modified.

### Debounce separately from settings
Use a separate `focusDebounceTimer` to allow settings broadcasts and focus broadcasts to happen at different times. This follows the pattern used for context updates (see lines 1040–1050).

### Initial state on connect
When a client connects, send the current focus value from config.local.yaml. If the file doesn't exist or has no `focus` key, send `null`. This matches the pattern from settings (lines 758–762).

### Message format
- Initial: `{ type: 'init', focus: 'panel-name' | null }`
- Update: `{ type: 'update', focus: 'panel-name' | null }`

This follows the pattern from other WebSocket endpoints (story, settings, context).

### No new files required
All changes are in websocket.ts. No helpers or separate modules needed—the pattern is purely additive to existing code.
