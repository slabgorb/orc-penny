---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-03-success
  - step-04-journeys
  - step-05-domain (skipped)
  - step-06-innovation (skipped)
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
inputDocuments:
  - sprint/planning/bikerack-prd.md
  - sprint/planning/bikerack-prd-ideas.md
  - docs/adr/0024-bikerack-mode.md
  - sprint/planning/pf-architecture.md
workflowType: 'prd'
documentCounts:
  briefCount: 0
  researchCount: 0
  brainstormingCount: 1
  projectDocsCount: 3
classification:
  projectType: CLI Tool (TUI)
  domain: Developer Experience (DX) / Agent Infrastructure
  complexity: Medium
  projectContext: brownfield
---

# Product Requirements Document — BikeRack TUI

**Author:** Keith Avery
**Date:** 2026-02-12

## Executive Summary

BikeRack TUI replaces the browser-based Cyclist dashboard with a terminal-native companion that runs alongside Claude Code. A developer runs `pf bikerack`, gets Claude Code in one terminal pane and a live TUI dashboard in another — no browser, no Electron, no React. The TUI connects to the existing WheelHub server over WebSocket, rendering the same panel data as the browser version using Rich/Textual in Python.

**Differentiator:** Multi-repo git status, diffs, sprint data, and workflow state visible at a glance in the terminal — something impossible in a single status line and previously requiring a browser window.

**Target user:** Solo developer using Pennyfarthing with Claude Code in a modern terminal (iTerm2, Kitty, WezTerm).

## Success Criteria

### User Success

- `pf bikerack` launches Claude Code + live TUI dashboard — no browser required
- `/bc show <panel>` switches the TUI to any panel without leaving Claude Code
- Multi-repo git status, diffs, and sprint data visible at a glance
- Jira story status, transitions, and sprint context surfaced directly in the TUI
- TUI updates in real-time as Claude works

### Business Success

- Replaces browser-based BikeRack entirely — eliminates React/Electron dependency for dashboards
- Single Python stack — tighter `pf` CLI integration, no context-switching to browser
- Lowers adoption barrier: everything in the terminal
- Jira workflow stays terminal-native

### Technical Success

- TUI connects to WheelHub over WebSocket — same data pipeline as browser panels
- Built into `pf` CLI using Rich/Textual (Python)
- `/bc` registered as Pennyfarthing slash command following existing skill patterns
- Existing WheelHub WebSocket channels and API routes consumed unchanged

### Measurable Outcomes

| Metric | Target | Measurement |
|--------|--------|-------------|
| Panel render latency | < 500ms from WebSocket event to TUI update | Manual timing |
| Panel coverage | 10 MVP panels implemented, 3 assessed and deferred/cut | Panel audit |
| Multi-repo visibility | Git status for 2+ repos visible in GitPanel | Visual verification |
| `/bc` responsiveness | Panel switch in < 200ms | Manual timing |
| WheelHub compatibility | Zero server-side changes | Code review |

## Product Scope

### MVP (Phase 1)

**Strategy:** Problem-solving MVP — deliver the core value (terminal-native dashboard) with minimal surface area. Ship all panels at functional quality before polishing any single panel.

**Core Deliverables:**
1. **`pf bikerack` launcher** — starts WheelHub + Claude CLI + TUI
2. **`/bc` slash command** — panel switching from inside Claude Code (follows `/sprint` pattern)
3. **WheelHub WebSocket client** — connects to existing channels
4. **10 TUI panels** — SprintPanel default on launch, panel persistence across sessions
5. **Nerd Font icons** — status glyphs, branch icons, checkmarks throughout
6. **Inline image support** — iTerm2/Kitty/Sixel protocol for future PortraitPanel readiness

**User Journeys Supported:** First Launch, Sprint Planning, Disconnect/Reconnect

### Panel Roster

| Panel | Key | Data Source | TUI Effort | Status | Notes |
|-------|-----|-------------|------------|--------|-------|
| **SprintPanel** | `sprint` | `/ws/sprint` | Format API | **MVP** | Jira status, points, velocity — default on launch |
| **GitPanel** | `git` | `/ws/git` | Format API | **MVP** | Key differentiator: multi-repo status |
| **DiffsPanel** | `diffs` | `/ws/diffs` | Redesign | **MVP** | Syntax-highlighted diffs via `rich` |
| **TodoPanel** | `todos` | `/ws/todos` | Format API | **MVP** | Checklist |
| **WorkflowPanel** | `workflow` | `/ws/workflow` | Format API | **MVP** | Phase diagram, agent flow |
| **AuditLogPanel** | `audit` | `/ws/audit` | Format API | **MVP** | Scrolling event log |
| **ChangedPanel** | `changed` | `/ws/changed` | Format API | **MVP** | File list with status indicators |
| **ACPanel** | `ac` | `/ws/ac` | Format API | **MVP** | Acceptance criteria checklist |
| **BackgroundPanel** | `background` | `/ws/background` | Format API | **MVP** | Task list with status |
| **DebugPanel** | `debug` | `/ws/debug` | Format API | **MVP** | Log viewer |
| **PortraitPanel** | `portrait` | `/ws/portrait` | Format API | **Growth** | Inline portrait image, agent name, badge, quote |
| **BikeLanePanel** | `bikelane` | `/ws/bikelane` | Redesign | **Deferred** | Not mature enough yet |
| **SettingsPanel** | `settings` | config files | Redesign | **Deferred** | Config editing via YAML is fine for now |
| **TTYPanel** | `tty` | `/ws/tty` | Redesign | **Cut** | Terminal-in-terminal doesn't translate |

**Pattern:** 9 of 10 MVP panels share a common pattern (subscribe to WebSocket channel, format payload as Rich table/tree). Only DiffsPanel needs specialized rendering.

### Growth (Phase 2)

1. **PortraitPanel** — inline portrait image (iTerm2/Kitty/Sixel), agent name, badge, quote
2. **Split view** — two panels side-by-side
3. **Panel history / back navigation**
4. **Jira deep integration** — story transitions, comment creation from TUI
5. **Tandem Workflow journey** support

### Vision (Phase 3)

1. **Multi-panel tiled layout**
2. **Direct data reading** — bypass WheelHub for local-only data
3. **Capture & replay in TUI**

### Out of Scope

- **Browser-based panels** — TUI replaces this
- **React components** — Python TUI renders natively
- **MessagePanel** — CLI owns the conversation
- **HotspotsPanel** — deprecated
- **Dockview/Electron** — no Electron dependency
- **One-shot / scriptable output** — existing `pf` CLI covers this
- **Shell completion** — not needed; panel switching via `/bc` inside Claude Code

### Risk Mitigation

| Risk | Level | Mitigation |
|------|-------|------------|
| Panel polish creep | **Primary** | Ship all 10 panels at functional quality first, then iterate |
| WheelHub data format assumptions | Medium | Read existing React panel implementations to understand exact payloads |
| DiffsPanel rendering for large diffs | Medium | Cap diff size initially; `rich` has built-in diff support |
| Solo developer capacity | Medium | 9 Format API panels share a common pattern — build first one well, rest are variations |

## User Journeys

### Journey 1: CLI Developer — First Launch

Keith runs `pf bikerack` — WheelHub starts in the background, Claude CLI launches in his terminal. In a second terminal pane, the TUI opens showing SprintPanel with current sprint status. He starts working with Claude — `/dev` activates the White Rabbit. He types `/bc show git` and the TUI switches to GitPanel showing status across both repos. As Claude edits files, he hits `/bc show diffs` — syntax-highlighted diffs in terminal. He never left his terminal, never opened a browser.

**Capabilities revealed:** Launcher, TUI panel viewer, `/bc` command, multi-repo git, real-time updates.

### Journey 2: Tandem Workflow (Growth)

Keith is in `tdd-tandem`. The PortraitPanel shows the inline portrait image, agent name, badge, and quote for the primary agent, with the backseat agent below. As agents hand off, the display updates. `/bc show workflow` shows the phase diagram with current position highlighted.

**Capabilities revealed:** PortraitPanel (inline image, name/badge/quote), workflow visualization, real-time agent detection.

### Journey 3: Sprint Planning

Keith runs `/bc show sprint` to review the current sprint. Points, velocity, Jira statuses — all in a clean terminal table. He switches to `/bc show ac` to check acceptance criteria for the next story. No browser, no Jira web UI needed for the overview.

**Capabilities revealed:** Sprint data tables, Jira integration, acceptance criteria.

### Journey 4: Disconnect / Reconnect

Keith closes the TUI terminal pane. Claude keeps running. He opens a new terminal, relaunches the TUI — it reconnects to WheelHub, panels show current state. No data lost.

**Capabilities revealed:** TUI independence from Claude session, WebSocket reconnection, state recovery.

### Journey Traceability

| Journey | Phase | Key FRs |
|---------|-------|---------|
| First Launch | MVP | FR1, FR5, FR6, FR13, FR14, FR21 |
| Tandem Workflow | Growth | FR16 + PortraitPanel |
| Sprint Planning | MVP | FR10, FR11, FR12 |
| Disconnect/Reconnect | MVP | FR2, FR3, FR4, FR9 |

## Technical Architecture

- **TUI Framework:** Rich + Textual (Python)
- **Icon Support:** Nerd Fonts assumed — status glyphs, branch icons, checkmarks
- **Image Support:** Inline image protocol (iTerm2/Kitty/Sixel) — portrait images render natively, no ASCII art fallback
- **Config:** Reads `.pennyfarthing/config.local.yaml` for theme; WheelHub port from existing config
- **Panel Persistence:** Extends existing Cyclist (ERB) panel saving mechanism — single source of truth
- **Default Panel:** SprintPanel on launch
- **Command Architecture:**
  - `pf bikerack` — launcher (starts WheelHub + Claude CLI + TUI)
  - `/bc show <panel>` — Pennyfarthing slash command (skill), follows `/sprint` pattern
  - No standalone TUI commands — all panel switching via `/bc` inside Claude Code

## Functional Requirements

### Application Lifecycle

- **FR1:** Developer can launch a TUI dashboard alongside a Claude Code session with a single command
- **FR2:** Developer can close the TUI without affecting the running Claude Code session
- **FR3:** Developer can relaunch the TUI and reconnect to an active WheelHub session
- **FR4:** TUI can detect and display its connection status to WheelHub

### Panel Navigation

- **FR5:** Developer can view one panel at a time in the TUI
- **FR6:** Developer can switch the displayed panel from within Claude Code via `/bc show <panel>`
- **FR7:** TUI displays SprintPanel by default on launch
- **FR8:** TUI persists the last viewed panel across sessions
- **FR9:** Developer can identify which panel is currently displayed

### Sprint & Planning Visibility

- **FR10:** Developer can view current sprint status including story counts, point totals, and velocity
- **FR11:** Developer can view Jira story statuses within sprint context
- **FR12:** Developer can view acceptance criteria for the active story

### Code & Repository Visibility

- **FR13:** Developer can view git status across multiple repositories simultaneously
- **FR14:** Developer can view file diffs with syntax highlighting
- **FR15:** Developer can view a list of changed files with status indicators

### Workflow & Agent Visibility

- **FR16:** Developer can view current workflow phase and agent progression
- **FR17:** Developer can view background task statuses
- **FR18:** Developer can view a task/todo checklist

### System Observability

- **FR19:** Developer can view a scrolling audit log of system events
- **FR20:** Developer can view debug log output

### Real-Time Data

- **FR21:** All panel data updates automatically when the underlying data changes
- **FR22:** Panel data reflects current system state without requiring manual refresh

## Non-Functional Requirements

### Performance

- **NFR1:** Panel render latency < 500ms from WebSocket event to TUI update
- **NFR2:** Panel switch via `/bc show <panel>` completes in < 200ms
- **NFR3:** TUI startup to first panel rendered in < 3 seconds (assuming WheelHub already running)
- **NFR4:** TUI memory footprint stays under 100MB during normal operation
- **NFR5:** Large diffs (> 1000 lines) render without blocking the TUI event loop

### Reliability

- **NFR6:** TUI detects WheelHub disconnection within 5 seconds and displays connection status
- **NFR7:** TUI automatically reconnects to WheelHub when connection is restored, without user intervention
- **NFR8:** TUI remains responsive (input accepted, status visible) while disconnected from WheelHub
- **NFR9:** No data loss on reconnect — panels refresh to current state after reconnection
- **NFR10:** TUI process exits cleanly on SIGINT/SIGTERM without orphaned processes

### Integration

- **NFR11:** Zero WheelHub server-side changes required — TUI consumes existing WebSocket channels and API routes unchanged
- **NFR12:** Panel persistence uses the same storage mechanism as the ERB (Cyclist) version — single source of truth
- **NFR13:** `/bc` skill follows existing Pennyfarthing skill registration patterns — no custom infrastructure
- **NFR14:** TUI reads theme and port configuration from existing `.pennyfarthing/config.local.yaml` — no TUI-specific config files
