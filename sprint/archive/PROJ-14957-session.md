# Story 103-2: WheelHub WebSocket client with auto-reconnect

**Story ID:** 103-2
**Jira:** PROJ-14957
**Epic:** 103 — BikeRack TUI — Terminal-Native Dashboard
**Points:** 3
**Priority:** P0
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-13T10:15:00Z
**Repos:** pennyfarthing
**Branch:** feat/103-2-wheelhub-websocket-client
**Assigned To:** keith.avery@slabgorb.io

## Acceptance Criteria

**Functional Requirements:**
- FR3: Python WebSocket client connects to WheelHub at the configured port
- FR4: Subscribes to panel channels and receives JSON payloads
- Dispatches messages to panel renderers
- Auto-reconnect on disconnect with backoff strategy

**Non-Functional Requirements:**
- NFR6: TUI remains responsive while disconnected
- NFR7: Auto-reconnect uses 2-second backoff delay (following React hook pattern)
- NFR8: Connection status updates within 5 seconds
- NFR9: WebSocket client is reusable across all panels
- NFR11: Zero server-side modifications to WheelHub
- NFR14: Port configuration sourced from .pennyfarthing/config.local.yaml

## Technical Context

### WheelHub Server Architecture
- **Server:** `packages/cyclist/src/server.ts` — Express HTTP + WebSocket
- **WebSocket setup:** `packages/cyclist/src/websocket.ts`
- **Default ports:** 1898 (Cyclist), 2898 (BikeRack mode)
- **Port discovery:** `.bikerack-port` file contains the active port

### WebSocket Channels (TUI will subscribe to these)
| Channel | Path | Message Schema |
|---------|------|---------------|
| sprint | `/ws/sprint` | `{type:'init'\|'update', currentStory, nextStory, epics, futureEpics, sprint:{number,name,done,remaining,inProgress,endDate}, metrics}` |
| git | `/ws/git` | `{type:'init'\|'update', repos:[{name,path,branch,clean,ahead,behind,developBehind,dirtyFiles:[{status,path}]}]}` |
| diffs | `/ws/diffs` | `{type:'init'\|'refresh', diffs:[]}` |
| todos | `/ws/todos` | `{type:'init'\|'update', todos:[]}` |
| story | `/ws/story` | `{type:'init'\|'update', id,title,phase,status,points,workflow,workflowType,criteria,availableWorkflows}` |
| background-tasks | `/ws/background-tasks` | `{type:'init'\|'update', tasks:[{taskId,description,subagentType,startedAt,isBackground,completedAt?,success?,result?,error?}]}` |
| spans | `/ws/spans` | `{type:'init'\|'span', span:{...}}` |
| context | `/ws/context` | `{type:'init'\|'update', context:{percent,tokens,tier}}` |
| persona | `/ws/persona` | `{...persona, isStreaming:bool}` |

### Message Pattern
1. Client connects to `ws://localhost:{port}/ws/{channel}`
2. Server immediately sends `{type:'init', ...data}` with current state
3. Subsequent updates arrive as `{type:'update', ...data}` (or `'refresh'` for diffs)

### Auto-Reconnect Pattern (from React hooks)
- 2-second delay on WebSocket close before attempting reconnect
- TUI remains functional while disconnected
- Connection status indicator displays state changes

### Existing Python Infrastructure
| Component | Location | Notes |
|-----------|----------|-------|
| Config loading | `pennyfarthing_scripts/common/config.py` | `load_pennyfarthing_config()` returns dict from `.pennyfarthing/config.local.yaml` |
| Project root | `pennyfarthing_scripts/common/config.py` | `get_project_root()` walks up looking for `.pennyfarthing/` |
| Port discovery | `pennyfarthing_scripts/bikerack/launcher.py` | `read_port_file()` reads `.bikerack-port` |

### Port Discovery Implementation
```python
from pathlib import Path
port_file = project_root / '.bikerack-port'
port = int(port_file.read_text().strip()) if port_file.exists() else 2898
```

### Dependencies Required
- `websockets` — Python WebSocket client library
- `textual` — TUI framework (may already depend on this)
- `rich` — rendering library (dependency of textual)

## TEA Assessment

**Tests Required:** Yes
**Reason:** 3-point story with async WebSocket client, reconnect logic, and multi-channel dispatch — needs thorough coverage.

**Test Files:**
- `tests/python/test_wheelhub_client.py` — 26 tests across 8 classes

**Stub File:**
- `pennyfarthing_scripts/bikerack/ws_client.py` — Interface with `WheelHubClient`, `ConnectionState`, constants

**Tests Written:** 26 tests covering 8 ACs (FR3, FR4, dispatch, reconnect, NFR6/7/8/9/14)
**Status:** RED (11 pass interface, 15 fail behavior — ready for Dev)

**Test Classes:**
| Class | Tests | Covers |
|-------|-------|--------|
| TestImportAndInterface | 7 | Module imports, class shape, constants |
| TestPortDiscovery | 3 | FR3/NFR14 — port file, default, explicit |
| TestConnection | 3 | FR3 — connect/disconnect state transitions |
| TestMessageHandling | 4 | FR4 — init/update dispatch, multi-handler, malformed JSON |
| TestAutoReconnect | 3 | NFR7 — reconnect, 2s delay, no reconnect after disconnect |
| TestConnectionState | 2 | NFR8 — state change callbacks, RECONNECTING state |
| TestMultiChannel | 2 | NFR9 — multiple channels, independent dispatch |
| TestCleanShutdown | 2 | Graceful disconnect, cancel timers, close connections |

**Implementation Notes for Dev:**
- Use `websockets` library (async) — tests mock `pennyfarthing_scripts.bikerack.ws_client.websockets`
- Each channel gets its own WebSocket connection to `ws://localhost:{port}/ws/{channel}`
- Port discovery: read `.bikerack-port` file via `project_dir`, fallback to `DEFAULT_PORT` (2898), explicit port wins
- Reconnect: `asyncio.sleep(RECONNECT_DELAY)` between attempts, state → RECONNECTING during backoff
- State callbacks: `on_state_change()` registers callbacks, fired on every state transition
- `_handlers` dict: channel name → list of handler callables
- `disconnect()` must cancel reconnect tasks and close all WS connections

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/ws_client.py` — Full WheelHubClient implementation: port discovery, multi-channel subscribe, JSON dispatch, auto-reconnect with 2s backoff, clean shutdown
- `tests/python/test_wheelhub_client.py` — Fixed recursive mock_sleep in disconnect cancellation test (captured real asyncio.sleep ref before global patch)
- `pyproject.toml` — Added `websockets>=12.0` to tui optional dependencies

**Key Implementation Detail:** Wrapped reconnect sleep in `asyncio.create_task()` to guarantee event loop yields even when `asyncio.sleep` is mocked to complete instantly. Without this, mocked sleep creates a tight infinite loop that prevents `asyncio.wait_for` timeouts from firing — tests hung for 20+ minutes.

**Tests:** 26/26 passing (GREEN) in 4.2s
**PR:** #847 — feat(103-2): WheelHub WebSocket client with auto-reconnect
**Branch:** feat/103-2-wheelhub-websocket-client (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** channel name → subscribe() → _handlers → channel_loop → ws URL → websockets.connect → recv → json.loads → handler dispatch (safe — port is int, channel is developer string)
**Pattern observed:** create_task wraps reconnect sleep for guaranteed event loop yield at `ws_client.py:138`
**Error handling:** Malformed JSON caught at `ws_client.py:126-131`, per-connection close errors caught at `ws_client.py:168-172`
**Tests:** 26/26 GREEN in 4.2s | No forbidden patterns | 9 LOW lint nits (auto-fixable)
**Handoff:** To SM for finish-story

## Phase History

| Phase | Agent | Started | Gate | Result |
|-------|-------|---------|------|--------|
| setup | sm | 2026-02-13T00:00:00Z | — | — |
| red | tea | 2026-02-13T09:00:00Z | — | — |
| green | dev | 2026-02-13T09:30:00Z | — | PASS (26/26 tests, PR #847) |
| review | reviewer | 2026-02-13T10:15:00Z | — | APPROVED |
| finish | sm | 2026-02-13T10:30:00Z | — | — |
