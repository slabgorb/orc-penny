# Context: Story 121-1 — Improve BikeRack TUI debug panel refresh rate for real-time token usage tracking

**GitHub Issue:** slabgorb/pennyfarthing-orchestrator#[pending]
**Jira:** PROJ-15392
**Points:** 2
**Epic:** 121 — Debug Panel and Brownfield Tools Fixes
**Status:** done (2026-02-20)
**Workflow:** trivial

## Problem

The BikeRack TUI debug panel's token usage metrics lag behind actual context consumption, making it hard for agents to track burn rate during long sessions. The bottleneck is the WebSocket broadcast interval (2000ms debounce) that decides how often context and token stats are pushed to subscribers. This 2-second lag accumulates over long conversations, causing the TUI panel to show outdated percentages and token counts relative to what the agent is actually consuming.

The issue occurs because:
- Context usage is only refreshed every 2 seconds (`CONTEXT_DEBOUNCE_MS = 2000`)
- Token stats arrive from OTEL metrics but don't trigger context refresh in sync
- The TUI's `debug_panel.py` receives stale data via WebSocket, making it unreliable for tracking burn rate
- The TUI debug panel subscribes to `/ws/context` and `/ws/token-stats` channels (see `ws_client.py`)

## Architecture

### Current Flow (Pre-Fix)

```
Agent executes tool (Bash, Edit, etc.)
  ↓
OTEL span emitted (token counts from Claude API)
  ↓
WheelHub otlp-receiver.ts receives metric
  ↓
Token stats listener triggered
  ↓
[PROBLEM] Context is NOT refreshed in sync with token stats
  ↓
/ws/context broadcast happens on 2000ms debounce only
  ↓
TUI debug_panel.py receives stale data
```

### Updated Flow (Post-Fix)

```
Agent executes tool (Bash, Edit, etc.)
  ↓
OTEL span emitted (token counts from Claude API)
  ↓
WheelHub otlp-receiver.ts receives metric
  ↓
addTokenStatsListener callback fires
  ↓
[FIX 1] Context refresh triggered immediately
[FIX 2] Debounce reduced to 500ms (4x faster)
  ↓
/ws/context broadcast happens on 500ms debounce
  ↓
TUI debug_panel.py receives near-real-time data
```

### Key Components

| File | Lines | Role |
|------|-------|------|
| `pennyfarthing-dist/pf/bikerack/debug_panel.py` | 248 | TUI debug panel — subscribes to `/ws/context` and `/ws/token-stats` channels via `ws_client.py` |
| `pennyfarthing-dist/pf/bikerack/ws_client.py` | 203 | TUI WebSocket client — connects to WheelHub channels |
| `packages/cyclist/src/websocket.ts` | ~1300 | WebSocket server setup; debounce timers; broadcast logic (server-side fix) |
| `packages/cyclist/src/otlp-receiver.ts` | ~500 | OTEL metric ingestion; token stats tracking; listener registry |
| `packages/cyclist/src/api/token-stats.ts` | ~50 | Token stats REST API and broadcast function |
| `packages/cyclist/src/api/context.ts` | ~150 | Context usage calculation (calls check-context.sh) |

### Debounce Constants

| Constant | Before | After | Purpose |
|----------|--------|-------|---------|
| `CONTEXT_DEBOUNCE_MS` | 2000 | 500 | Interval for refreshing context % and token counts |
| `STORY_DEBOUNCE_MS` | — | 100 | Interval for story/sprint file watcher broadcasts |
| `SETTINGS_DEBOUNCE_MS` | — | 100 | Interval for settings broadcast |

### Listener Chain

The fix adds `addTokenStatsListener()` in websocket.ts to bind token stats arrival to context refresh:

```typescript
addTokenStatsListener(() => {
  if (contextClients.size > 0) {
    if (contextDebounceTimer) {
      clearTimeout(contextDebounceTimer);
    }
    contextDebounceTimer = setTimeout(() => {
      const projectDir = getProjectDir();
      const context = getContextUsage(projectDir);
      broadcastContextUpdate(context);
      contextDebounceTimer = null;
    }, CONTEXT_DEBOUNCE_MS);
  }
});
```

This ensures:
1. **Sync with token metrics** — context refresh is triggered when token stats arrive
2. **Debounce protection** — still batches multiple rapid events into 500ms windows
3. **Empty client check** — avoids expensive `getContextUsage()` if no one is listening

## Acceptance Criteria

### AC1: TUI debug panel updates token metrics within 500ms of token burn
- **Given** the agent is executing a long-running task with the TUI debug panel visible
- **When** the BikeRack TUI is running (`pf bikerack start`)
- **Then** token counts and context % in `debug_panel.py` update within 500ms of each API call completing
- **Verification** — Manual: run `pf bikerack start`, execute tool calls (Bash, Edit, Read, etc.), verify token meter updates smoothly in the debug panel

### AC2: No regression in other subscribers
- **Given** the WebSocket broadcast loop is running
- **When** multiple consumers subscribe to `/ws/context` (TUI, React GUI, or other clients)
- **Then** no race conditions or dropped messages occur
- **Verification** — Automated: run stress test with 10+ concurrent context subscribers

### AC3: Debounce still prevents spam
- **Given** rapid token events (>1000 events/sec from batch operations)
- **When** context refresh is requested
- **Then** broadcasts are batched into 500ms windows (max 2 broadcasts/sec)
- **Verification** — Manual: check `~/.pennyfarthing/logs/` for broadcast frequency

## Implementation Notes

### What Was Fixed

The fix is two-part:

1. **Debounce reduction** (line 190 of websocket.ts)
   - Changed `CONTEXT_DEBOUNCE_MS` from 2000 to 500
   - 4x faster refresh rate with the same debounce protection
   - Cost: slightly higher CPU on context.py calls (still cheap: ~50ms each)

2. **Token stats listener** (lines 680-695 of websocket.ts)
   - New callback registered with `addTokenStatsListener()`
   - Triggers debounced context refresh when OTEL metrics arrive
   - Ensures context % stays in sync with token burn rate
   - Requires import of `addTokenStatsListener` from otlp-receiver.ts

### Why This Works

- **OTEL metrics are the source of truth** — token counts come from Claude API responses, not from running `check-context.sh`
- **Debounce still needed** — even with 500ms, we protect against hammer-like behavior (e.g., 10 rapid edits)
- **No breaking changes** — all existing APIs stay the same; only timing changes

### Commit

```
fab9dc529 feat(121-1): improve debug panel refresh rate for real-time token tracking

Reduce CONTEXT_DEBOUNCE_MS from 2000ms to 500ms for 4x faster context
updates. Add token stats listener to trigger debounced context refresh
on OTLP metric arrival, not just tool events.
```

Modified: `packages/cyclist/src/websocket.ts` (+19 lines)

## Testing Notes

### Manual Testing (TUI Focus)

1. Start BikeRack TUI: `pf bikerack start`
2. Execute a tool (e.g., `Bash ls`) and watch the debug panel for token meter updates
3. Token stats should appear within ~1-2 seconds (was ~2-4 seconds before)
4. Run a long task (e.g., `npm run build`) and verify smooth token % updates in the TUI panel
5. Verify the TUI responds to rapid-fire tool calls without lag or dropped updates

### Performance

- **Context calculation time** — ~50ms (runs `check-context.sh`)
- **Broadcast frequency** — max 2/sec (500ms debounce)
- **TUI client impact** — negligible; `debug_panel.py` renders only on WebSocket message arrival

## Related Stories

- **121-2** — Add code quality tools trigger (separate BikeRack feature)
- **121-3** — Fix footer keybinding labels (separate BikeRack TUI fix)
- **121-4** — Fix git cache busting (separate git issue)
- **PROJ-12800** — Token count breakdown (context injected components)
- **PROJ-12782** — Token stats formatting (earlier WebSocket performance work)
