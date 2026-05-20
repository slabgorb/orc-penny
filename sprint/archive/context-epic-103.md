# Epic 103: BikeRack TUI — Terminal-Native Dashboard

**Jira:** PROJ-14951
**ADR:** 0024
**Repo:** pennyfarthing
**PRDs:** `sprint/planning/bikerack-prd.md` (browser mode), `sprint/planning/tui-prd.md` (TUI mode)

## Overview

Replace the browser-based BikeRack dashboard with a terminal-native TUI companion built on Rich/Textual (Python). Connects to WheelHub over WebSocket, renders 10 panels, switches via `/bc` slash command. Consumes existing WebSocket channels unchanged — zero server-side modifications.

## Existing Infrastructure

### What Already Exists (BikeRack Browser Mode — Epics 101/102)

The browser-based BikeRack is **already implemented** and provides the architectural foundation this TUI replaces:

| Component | File | Status |
|-----------|------|--------|
| WheelHub BikeRack entry | `packages/cyclist/src/bikerack.ts` | Done |
| Mode detection | `isBikeRackMode()` in `src/server.ts:64` | Done |
| StandalonePanel router | `src/public/components/StandalonePanel.tsx` | Done |
| BikeRackWorkspace (Dockview) | `src/public/components/BikeRackWorkspace.tsx` | Done |
| BikeRackIndex (panel listing) | `src/public/components/BikeRackIndex.tsx` | Done |
| Python launcher | `pennyfarthing_scripts/bikerack/launcher.py` | Done |
| Python CLI | `pennyfarthing_scripts/bikerack/cli.py` | Done |
| `pf bikerack start/stop/status` | registered in `pennyfarthing_scripts/cli.py:69` | Done |

**Key insight:** The TUI epic does NOT need to touch WheelHub, launcher, or mode detection. It builds a Python TUI client that connects to the already-running WheelHub server.

### WheelHub Server Architecture

- **Server:** `packages/cyclist/src/server.ts` — Express HTTP + WebSocket
- **WebSocket setup:** `packages/cyclist/src/websocket.ts`
- **Default port:** 1898 (Cyclist), 2898 (BikeRack mode)
- **Port discovery:** `.cyclist-port` or `.bikerack-port` file

### WebSocket Channels (from `websocket.ts`)

| Channel | Path | Message Schema | TUI Panel |
|---------|------|---------------|-----------|
| sprint | `/ws/sprint` | `{type:'init'\|'update', currentStory, nextStory, epics, futureEpics, sprint:{number,name,done,remaining,inProgress,endDate}, metrics}` | SprintPanel |
| git | `/ws/git` | `{type:'init'\|'update', repos:[{name,path,branch,clean,ahead,behind,developBehind,dirtyFiles:[{status,path}]}]}` | GitPanel |
| diffs | `/ws/diffs` | `{type:'init'\|'refresh', diffs:[]}` | DiffsPanel |
| todos | `/ws/todos` | `{type:'init'\|'update', todos:[]}` | TodoPanel |
| story | `/ws/story` | `{type:'init'\|'update', id,title,phase,status,points,workflow,workflowType,criteria,availableWorkflows}` | WorkflowPanel, ACPanel |
| background-tasks | `/ws/background-tasks` | `{type:'init'\|'update', tasks:[{taskId,description,subagentType,startedAt,isBackground,completedAt?,success?,result?,error?}]}` | BackgroundPanel |
| spans | `/ws/spans` | `{type:'init'\|'span', span:{...}}` | AuditLogPanel |
| context | `/ws/context` | `{type:'init'\|'update', context:{percent,tokens,tier}}` | (header) |
| persona | `/ws/persona` | `{...persona, isStreaming:bool}` | (header) |

**Channels NOT used by TUI:** `/ws/claude` (disabled in BikeRack), `/ws/bell`, `/ws/hooks`, `/ws/settings`, `/ws/welcome`, `/ws/livereload`, `/ws/pty`, `/ws/stats`, `/ws/token-stats`

### Message Pattern

All channels follow the same pattern:
1. Client connects to `ws://localhost:{port}/ws/{channel}`
2. Server immediately sends `{type:'init', ...data}` with current state
3. Subsequent updates arrive as `{type:'update', ...data}` (or `'refresh'` for diffs)

### Existing React Panel Hooks (Reference for Data Contract)

These show exactly what data TUI panels need to consume:

| Hook | File | Channel |
|------|------|---------|
| `useStory()` | `src/public/hooks/useStory.ts` | `/ws/story` |
| `useSprint()` | `src/public/hooks/useSprint.ts` | `/ws/sprint` |
| `useGitStatus()` | `src/public/hooks/useGitStatus.ts` | `/ws/git` |

All use standard WebSocket with auto-reconnect (2s delay on close).

### Existing Python Infrastructure

| Component | Location | Notes |
|-----------|----------|-------|
| Config loading | `pennyfarthing_scripts/common/config.py` | `load_pennyfarthing_config()` returns dict from `.pennyfarthing/config.local.yaml` |
| Project root | `pennyfarthing_scripts/common/config.py` | `get_project_root()` walks up looking for `.pennyfarthing/` |
| Port discovery | `pennyfarthing_scripts/bikerack/launcher.py` | `read_port_file()` reads `.bikerack-port` |
| Jira client | `pennyfarthing_scripts/jira/client.py` | REST/CLI wrapper |
| Click CLI | `pennyfarthing_scripts/cli.py` | Entry point, `pf` command |

**What does NOT exist in Python yet:**
- No WebSocket client library usage
- No Rich/Textual usage
- No TUI framework code

## Key Directories

- `pennyfarthing/packages/cyclist/src/` — WheelHub server (TypeScript, reference only)
- `pennyfarthing/packages/cyclist/src/public/hooks/` — React hooks showing data contracts
- `pennyfarthing/packages/cyclist/src/public/components/panels/` — React panels (reference for layout)
- `pennyfarthing/pennyfarthing_scripts/bikerack/` — Existing Python launcher
- `pennyfarthing/pennyfarthing_scripts/common/` — Config, output utilities

## Architecture Decisions

### TUI Stack
- **Rich** — table/tree rendering, syntax highlighting, diff formatting
- **Textual** — TUI framework (app shell, layout, key bindings, event loop)
- **websockets** or **websocket-client** — WS connection to WheelHub

### Panel Pattern
9 of 10 MVP panels share a common pattern:
1. Connect to WebSocket channel
2. Parse JSON `{type:'init'|'update', ...payload}`
3. Render as Rich table/tree in Textual widget
4. Auto-update on new messages

Only DiffsPanel needs specialized rendering (syntax-highlighted diffs via `rich.syntax`).

### `/bc` Command
Registered as a Pennyfarthing slash command skill (following `/sprint` pattern). `/bc show <panel>` sends a panel-switch message to the TUI via WheelHub or direct IPC. Panel switches < 200ms.

### Port Discovery
```python
from pathlib import Path
port_file = project_root / '.bikerack-port'
port = int(port_file.read_text().strip()) if port_file.exists() else 2898
```

### Config Access
```python
from pennyfarthing_scripts.common.config import load_pennyfarthing_config
config = load_pennyfarthing_config()
theme = config.get('theme', 'default')
```

## Stories

| ID | Title | Pts | Priority | Status | Workflow | Jira |
|----|-------|-----|----------|--------|----------|------|
| 103-1 | Textual app scaffold with basic layout | 2 | P0 | backlog | tdd | PROJ-14956 |
| 103-2 | WheelHub WebSocket client with auto-reconnect | 3 | P0 | backlog | tdd | PROJ-14957 |
| 103-3 | `pf bikerack` launcher command | 2 | P0 | backlog | tdd | PROJ-14958 |
| 103-4 | Connection status indicator in TUI header | 1 | P0 | backlog | trivial | PROJ-14959 |
| 103-5 | Base panel abstraction (channel subscription + Rich rendering) | 3 | P0 | backlog | tdd | PROJ-14960 |
| 103-6 | SprintPanel implementation | 2 | P0 | backlog | tdd | PROJ-14961 |
| 103-7 | `/bc` slash command skill registration | 2 | P0 | backlog | tdd | PROJ-14962 |
| 103-8 | Panel persistence (extend ERB mechanism) | 2 | P1 | backlog | trivial | PROJ-14963 |
| 103-9 | Panel header chrome (current panel indicator, Nerd Font icons) | 1 | P1 | backlog | trivial | PROJ-14964 |
| 103-10 | GitPanel (multi-repo status) | 2 | P0 | backlog | tdd | PROJ-14965 |
| 103-11 | WorkflowPanel (phase diagram, agent flow) | 2 | P1 | backlog | trivial | PROJ-14966 |
| 103-12 | ACPanel (acceptance criteria checklist) | 1 | P1 | backlog | trivial | PROJ-14967 |
| 103-13 | TodoPanel (task checklist) | 1 | P1 | backlog | trivial | PROJ-14968 |
| 103-14 | ChangedPanel (file list with status) | 1 | P1 | backlog | trivial | PROJ-14969 |
| 103-15 | AuditLogPanel (scrolling event log) | 1 | P1 | backlog | trivial | PROJ-14970 |
| 103-16 | BackgroundPanel (task status) | 1 | P1 | backlog | trivial | PROJ-14971 |
| 103-17 | DebugPanel (log viewer) | 1 | P1 | backlog | trivial | PROJ-14972 |
| 103-18 | DiffsPanel — Rich diff rendering with syntax highlighting | 3 | P0 | backlog | tdd | PROJ-14973 |
| 103-19 | Large diff handling (truncation/pagination) | 2 | P1 | backlog | tdd | PROJ-14974 |

**Total:** 33 points across 19 stories

## Critical Path

```
103-1 (scaffold) ──┐
103-2 (WS client) ─┼─→ 103-5 (base panel) ─→ 103-6 (SprintPanel, proves vertical slice)
103-3 (launcher)  ─┘                        ├→ 103-10 (GitPanel)
                                            ├→ 103-18 (DiffsPanel)
                                            └→ 103-11..17 (remaining panels)

103-7 (/bc command) — independent, can parallel with panel work
103-4 (connection status) — depends on 103-1 + 103-2
103-8 (persistence) — after at least one panel works
103-9 (header chrome) — after 103-1
103-19 (large diffs) — after 103-18
```

## Dependencies

- **Blocked by:** Nothing — all WheelHub infrastructure exists
- **New Python deps:** `textual`, `rich` (likely already a `textual` dep), `websockets`
- **No Node.js changes** — TUI is pure Python consuming existing WS channels

## Implementation Constraints

1. **Zero server changes** — TUI is a pure consumer of existing WheelHub WebSocket channels (NFR11)
2. **Same data pipeline** — panels render the exact same JSON payloads as React panels
3. **Port file protocol** — `.bikerack-port` written by WheelHub after `listen()` callback (CE-3)
4. **Single source of truth for config** — `.pennyfarthing/config.local.yaml` (NFR14)
5. **Panel persistence shared** — extends existing ERB mechanism (NFR12)
6. **`/bc` follows `/sprint` skill pattern** — no custom infrastructure (NFR13)

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Panel polish creep | Primary | Ship all 10 at functional quality first |
| WheelHub data format assumptions | Medium | Read React hook implementations for exact payloads |
| DiffsPanel large diffs | Medium | Cap size initially; `rich` has built-in diff support |
| Textual/Rich learning curve | Low | Well-documented libraries, common pattern across panels |
| WebSocket reconnect edge cases | Medium | Follow existing React hook reconnect pattern (2s delay) |
