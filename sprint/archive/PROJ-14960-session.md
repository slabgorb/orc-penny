# Story 103-5: Base panel abstraction (channel subscription + Rich rendering)

**Jira:** PROJ-14960
**Epic:** 103 — BikeRack TUI
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** story/103-5-base-panel-abstraction
**Assigned:** keith.avery@slabgorb.io

## Description

Base panel class that panels inherit from. Handles: subscribe to WebSocket channel by key, receive JSON payload, call render method, display Rich output in main content area. Real-time updates when new data arrives. Panels implement render() with Rich tables/trees.

FRs: FR5, FR21, FR22
NFRs: NFR1

## Acceptance Criteria

- [ ] Base panel class exists with channel subscription capability
- [ ] Panels receive JSON payloads from WebSocket channels
- [ ] render() method produces Rich output (tables/trees)
- [ ] Main content area displays rendered output
- [ ] Real-time updates when new data arrives on channel
- [ ] Panel subclasses can override render() with custom Rich rendering
- [ ] Base class handles subscribe/unsubscribe lifecycle

## Technical Context

### What Exists

**Stories 103-1 through 103-4 have been completed:**

1. **Textual app scaffold (103-1)** — `BikeRackApp` class with Header, main VerticalScroll container, and Footer
   - Location: `pennyfarthing/pennyfarthing_scripts/bikerack/tui.py`
   - Key components: `BikeRackApp` (Textual App shell), `ConnectionStatus` widget (reactive state for connection indicator)

2. **WheelHub WebSocket client (103-2)** — `WheelHubClient` with auto-reconnect pattern
   - Location: `pennyfarthing/pennyfarthing_scripts/bikerack/ws_client.py`
   - Key features:
     - `WheelHubClient.subscribe(channel, handler)` — register message handlers for channels
     - `WheelHubClient.connect()` — async connect loop with 2s reconnect backoff
     - `WheelHubClient.on_state_change(callback)` — register state transition callbacks
     - `ConnectionState` enum: DISCONNECTED, CONNECTING, CONNECTED, RECONNECTING
     - Port discovery: reads `.bikerack-port` file or falls back to 2898

3. **Launcher command (103-3)** — `pf bikerack start/stop/status` CLI
   - Location: `pennyfarthing/pennyfarthing_scripts/bikerack/cli.py`, `launcher.py`
   - Starts WheelHub, launches Claude CLI, discovers port via `.bikerack-port` file

4. **Connection status indicator (103-4)** — Displays connection state in header
   - TUI already wired up with client callbacks and displays state

### WebSocket Channel Contract

From `pennyfarthing/packages/cyclist/src/websocket.ts`, all channels follow the pattern:

1. Client connects to `ws://localhost:{port}/ws/{channel}`
2. Server immediately sends `{type:'init', ...data}` with current state
3. Subsequent updates arrive as `{type:'update', ...data}` (or `'refresh'` for diffs)

**Key channels for panels:**
- `/ws/sprint` — sprint metadata, story list, velocity, epics
- `/ws/git` — multi-repo status (branch, ahead/behind, dirty files)
- `/ws/todos` — todo list
- `/ws/story` — current story details, phase, workflow, criteria
- `/ws/diffs` — file diffs
- `/ws/background-tasks` — background task queue
- `/ws/spans` — audit log entries

All React hooks in `pennyfarthing/packages/cyclist/src/public/hooks/` (useStory, useSprint, useGitStatus) show exact data contracts.

### Panel Pattern (from Epic Context)

9 of 10 panels share common pattern:
1. Connect to WebSocket channel via client.subscribe()
2. Parse JSON {type:'init'|'update', ...payload}
3. Render as Rich table/tree in Textual widget
4. Auto-update on new messages

### Key Libraries

- **Textual** — TUI framework (app, widgets, layout, events)
- **Rich** — table/tree rendering, syntax highlighting
- **websockets** — WebSocket client (already used by `WheelHubClient`)

### Existing Patterns

**Textual Widget Pattern:**
- Inherit from `Static` or container widget
- Use `reactive` for state tracking (e.g., `ConnectionStatus`)
- Override `render()` or `compose()` for display
- Handle updates via event handlers or `watch_*` methods

**WebSocket Handler Pattern:**
- Callable `handler(message_dict)` receives parsed JSON
- Register via `client.subscribe(channel, handler)`
- Handler runs async in WheelHub connect loop

## Key Files

### Existing (Reference/Integration)

| File | Purpose |
|------|---------|
| `pennyfarthing/pennyfarthing_scripts/bikerack/tui.py` | BikeRackApp shell, ConnectionStatus widget — already has main VerticalScroll container (id="main-content") |
| `pennyfarthing/pennyfarthing_scripts/bikerack/ws_client.py` | WheelHubClient, subscribe/connect/on_state_change API |
| `pennyfarthing/pennyfarthing_scripts/bikerack/launcher.py` | Port discovery, lifecycle management |
| `pennyfarthing/packages/cyclist/src/websocket.ts` | WheelHub channel definitions and message schema (reference) |
| `pennyfarthing/packages/cyclist/src/public/hooks/*.ts` | React hook implementations showing exact data contracts (reference) |

### New (To Create)

| File | Purpose |
|------|---------|
| `pennyfarthing/pennyfarthing_scripts/bikerack/base_panel.py` | BasePanel abstract class — handles subscribe, lifecycle, render() contract |
| Tests (TDD red phase) | Unit tests for BasePanel subscription, message handling, Rich output |

## Progress

- [x] Story started
- [x] Tests written (TDD red phase)
- [ ] Implementation complete (TDD green phase)
- [ ] Code reviewed
- [ ] Story finished

## Notes

### Design Implications

**BasePanel class should:**
1. Accept channel name and optional handler in `__init__`
2. Implement `on_mount()` to subscribe to channel via client
3. Provide abstract `render(payload)` method returning Rich.Text/Table/Tree
4. Handle message handler callback to trigger re-render on Textual side
5. Provide `on_unmount()` to unsubscribe (cleanup)
6. Expose last received payload for re-rendering on demand

**Integration with BikeRackApp:**
- Client instance passed to app, then to panels via dependency injection or global
- Main content area (VerticalScroll id="main-content") replaced when panel changes
- Panel instances created/destroyed as needed, not pre-instantiated

### TDD Strategy

**Red phase (write failing tests):**
1. Test BasePanel initialization
2. Test subscribe callback registration
3. Test message parsing and render() invocation
4. Test Rich output generation (verify Table/Tree structure)
5. Test lifecycle (on_mount, on_unmount, cleanup)
6. Test unsubscribe on destroy

**Green phase (implement):**
1. Skeleton BasePanel class with required methods
2. WheelHubClient integration
3. Rich output rendering
4. Textual widget lifecycle hooks

### Dependencies

- No new external deps (textual, rich, websockets already exist)
- Blocked by: Stories 103-1, 103-2 (DONE)
- Blocks: Stories 103-6 through 103-18 (all other panels depend on BasePanel)

### Channel Discovery

Panels will need to know which channel to subscribe to. Options:
1. Hard-code in each panel subclass (simple, not flexible)
2. Constructor parameter (flexible, requires instantiation knowledge)
3. Class attribute (clean, discoverable)

Recommend approach 3 for clarity and testability.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core abstraction — every panel depends on this. Must be solid.

**Test Files:**
- `pennyfarthing/tests/python/test_bikerack_base_panel.py` — 32 tests across 9 test classes

**Tests Written:** 32 tests covering all 7 ACs
- AC1 (exists/structure): 5 tests
- AC2 (channel subscription): 5 tests
- AC3 (Rich rendering): 5 tests
- AC4 (display in app): 2 tests (async Textual pilot)
- AC5 (real-time updates): 3 tests
- AC6 (subclass pattern): 3 tests
- AC7 (lifecycle): 5 tests
- Edge cases: 4 tests

**Status:** RED — 19 failing on NotImplementedError, 13 passing (imports/structure/rendering). Zero import errors.

**Stub:** `pennyfarthing/pennyfarthing_scripts/bikerack/base_panel.py` — compiles, raises NotImplementedError in on_mount/on_unmount/handle_message.

**Key design decisions baked into tests:**
1. `channel` as class attribute (not constructor param)
2. `render_panel(payload)` returns Rich renderables (Table, Text, Tree)
3. `handle_message(dict)` stores `_last_payload` and triggers `render_panel`
4. `on_mount()` subscribes via `client.subscribe(channel, handler)`
5. `on_unmount()` cleans up — messages ignored after unmount
6. No-client panels mount without crashing (graceful degradation)

**Handoff:** To Dev (Winchester) for green phase implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/pennyfarthing_scripts/bikerack/base_panel.py` — replaced NotImplementedError stubs with working lifecycle (on_mount subscribes, handle_message stores+renders, on_unmount disables)

**Tests:** 32/32 passing (GREEN)
**PR:** #853 — feat(103-5): BasePanel channel subscription + Rich rendering
**Branch:** story/103-5-base-panel-abstraction (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** WS JSON → channel_loop → handle_message → _last_payload + render_panel → self.update (safe — same event loop, linear flow)
**Pattern observed:** `channel` as class attribute at `base_panel.py:23` — clean, discoverable, no constructor pollution
**Wiring verified:** `client.subscribe(channel, handle_message)` at `base_panel.py:35` matches `WheelHubClient.subscribe` at `ws_client.py:92`
**Error handling:** None/empty/no-client guards at `base_panel.py:47` — all covered by edge case tests

| Severity | Observation | Location |
|----------|-------------|----------|
| [MEDIUM] | Bare `except Exception: pass` swallows all update errors | `base_panel.py:51-54` |
| [MEDIUM] | No client unsubscribe on unmount (WheelHubClient has no API) | `base_panel.py:37-39` |
| [LOW] | No type annotation on `client` parameter | `base_panel.py:25` |

**Tests:** 32/32 GREEN — preflight confirmed
**Handoff:** To SM for finish-story
