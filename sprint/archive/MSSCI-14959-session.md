# Story 103-4: Connection status indicator in TUI header

**Jira:** MSSCI-14959
**Epic:** 103 — BikeRack TUI
**Points:** 1
**Priority:** P0
**Workflow:** trivial
**Phase:** review
**Branch:** feature/103-4-connection-status-indicator-tui-header
**Repos:** pennyfarthing
**Assigned:** keith.avery@1898andco.io

## Description

TUI header displays WheelHub connection state: connected, disconnected, reconnecting. Updates within 5 seconds of state change. TUI remains responsive while disconnected.

## Acceptance Criteria

- [ ] TUI header shows connection status indicator
- [ ] Indicator displays three states: connected (green), disconnected (red), reconnecting (yellow)
- [ ] Connection status updates within 5 seconds of WheelHub state change
- [ ] TUI remains responsive while disconnected (continues rendering panels, accepts input)
- [ ] Connection status persists through panel switches

## Technical Context

### Epic Context

This is story 103-4 in Epic 103 (BikeRack TUI). The epic replaces the browser-based BikeRack dashboard with a terminal-native TUI companion built on Rich/Textual (Python). The TUI connects to WheelHub over WebSocket, renders 10 panels, and switches via `/bc` slash command.

Key dependencies:
- **103-1** (scaffold) — Base Textual app structure with layout (header, content, footer) — provides header area where connection status displays
- **103-2** (WS client) — WebSocket client with auto-reconnect — provides connection state events

This story depends on both 103-1 and 103-2 being complete.

### Architecture

**WheelHub Server Details:**
- **Entry point:** `packages/cyclist/src/bikerack.ts` (TypeScript, already built)
- **Mode detection:** `isBikeRackMode()` in `src/server.ts:64`
- **Port:** 2898 (BikeRack mode)
- **Port discovery:** `.bikerack-port` file written by WheelHub after server starts
- **WebSocket endpoint:** `ws://localhost:{port}/ws/{channel}`

**TUI Stack:**
- **Framework:** Textual (Textual widgets in Python)
- **Rendering:** Rich (tables, trees, styled output)
- **WebSocket:** websocket-client or websockets Python library

**TUI Connection Pattern (from 103-2):**
1. TUI reads port from `.bikerack-port` file
2. Connects to `ws://localhost:{port}/ws/sprint` (any channel)
3. Server immediately sends `{type:'init', ...data}`
4. Subsequent updates arrive as `{type:'update', ...data}`
5. On disconnect: auto-reconnect with 2s backoff

**Header Layout (from 103-1):**
The Textual app scaffold provides a basic layout:
```
┌─────────────────────────────────────┐
│ [Connection Status] BikeRack TUI    │  ← header area
├─────────────────────────────────────┤
│                                     │
│  Panel Content (Rich table/tree)    │  ← main content
│                                     │
├─────────────────────────────────────┤
│ Sprint | q: quit | arrows: nav     │  ← footer
└─────────────────────────────────────┘
```

Connection status indicator displays in header, left side or center.

**Connection States:**
1. **Connected** — shows green indicator + "Connected to WheelHub" or icon
2. **Disconnected** — shows red indicator + "Disconnected" or icon
3. **Reconnecting** — shows yellow indicator + "Reconnecting..." or icon

**Update Mechanism:**
The WebSocket client (103-2) emits connection state changes. The connection status widget subscribes to these events and updates the header display within 5 seconds.

### Files to Modify/Create

- `pennyfarthing_scripts/bikerack/tui.py` — Main TUI application entry point (scaffold from 103-1)
  - Likely has a `Header` widget that will display connection status
  - Connection status widget consumes events from WebSocket client

- Connection status widget — New widget to display state indicator
  - Subscribes to WS client events
  - Updates display on state change
  - Non-blocking updates (doesn't freeze TUI)

### Dependencies

- **Stories 103-1 (scaffold) and 103-2 (WS client):** Must be complete before this story
- **Existing WheelHub infrastructure:** Already handles server startup, port file writing, WS endpoint
- **Python packages:** textual, rich, websockets/websocket-client (added in 103-1/103-2)

### Key NFRs

- **NFR6:** TUI connects to WheelHub at configured port (port file discovery)
- **NFR8:** All panel updates arrive via WebSocket; no polling

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/tui.py` — `ConnectionStatus` widget with Textual reactive property, client wiring via `on_state_change` callback, WS worker
- `tests/python/test_bikerack_connection_status.py` — 14 tests covering all 5 ACs

**Tests:** 44/44 passing (GREEN) — 14 new + 15 TUI scaffold + 15 launcher
**PR:** #850 — feat(103-4): connection status indicator in TUI header
**Branch:** feature/103-4-connection-status-indicator-tui-header (pushed)

**Design decisions:**
- `ConnectionStatus` extends `Static` with `reactive[ConnectionState]` — Textual auto-watches and re-renders
- `STATE_DISPLAY` dict maps each `ConnectionState` to Rich-markup string with colored bullet
- `BikeRackApp` accepts optional `client` kwarg (backward-compatible with existing tests)
- WS client runs via `self.run_worker()` — cooperative async, TUI stays responsive
- Connection status widget is outside `#main-content` — persists through panel switches

**Handoff:** To Reviewer for code review

---

## Reviewer Assessment

**Verdict:** APPROVED

| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | [VERIFIED] | `STATE_DISPLAY` covers all 4 `ConnectionState` values | `tui.py:18-23` |
| 2 | [VERIFIED] | `watch_connection_state` uses `self.update()` — idiomatic Textual reactive | `tui.py:33-35` |
| 3 | [VERIFIED] | `BikeRackApp(client=None)` backward-compatible — 103-1 tests pass | `tui.py:47-49` |
| 4 | [VERIFIED] | Initial compose() text consistent with STATE_DISPLAY — no desync | `tui.py:53-56` |
| 5 | [VERIFIED] | `run_worker(connect(), exclusive=True)` — cooperative async, non-blocking | `tui.py:64` |
| 6 | [VERIFIED] | Widget outside `#main-content` — persists through panel switches | `tui.py:52-59` |
| 7 | [LOW] | `client` param lacks type hint (non-blocking) | `tui.py:47` |
| 8 | [LOW] | Bare `except Exception: pass` — defensible in callback path | `tui.py:71-72` |
| 9 | [VERIFIED] | 14 tests cover all 5 ACs via Textual `run_test()` | `test_bikerack_connection_status.py` |
| 10 | [VERIFIED] | No forbidden patterns, no security vectors | both files |

**Data flow traced:** `_set_state()` → callbacks → `_on_ws_state_change` → `widget.connection_state = state` → reactive watcher → `self.update(STATE_DISPLAY[state])`. Safe — display strings are a fixed dict.
**Pattern observed:** Textual reactive with `watch_` convention. Idiomatic.
**Error handling:** Callback try/except catches `NoMatches` on widget removal. Correct for callback path.
**Tests:** 44/44 GREEN. No forbidden patterns. No code smells.

**Handoff:** To SM for finish-story

---

## Workflow Tracking

**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-02-13T15:38:39Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-13 | 2026-02-13 | 0m |
| implement | 2026-02-13 | 2026-02-13T15:34:57Z | 15h+ |
| review | 2026-02-13T15:34:57Z | 2026-02-13T15:38:39Z | 3m 42s |

### Handoff History
| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| implement (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-13T15:34:57Z |
| review (reviewer) | finish (sm) | approval | PASSED | 2026-02-13T15:38:39Z |
