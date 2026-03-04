# Epic 103: BikeRack TUI — Terminal-Native Dashboard

## Overview

Replace the browser-based Cyclist dashboard with a terminal-native TUI companion built on Rich/Textual (Python). Connects to WheelHub over WebSocket, renders panel data, and switches panels via the `/bc` slash command. The TUI runs alongside Claude Code in a tmux pane — no browser, no Electron, no React. Consumes existing WebSocket channels unchanged — zero server-side modifications.

**Priority:** P1
**Repo:** pennyfarthing
**Stories:** 27 (45 points)

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **TUI PRD** (`sprint/planning/tui-prd.md`) | Executive summary, success criteria, product scope, functional requirements |
| **BikeRack PRD** (`sprint/planning/bikerack-prd.md`) | Original BikeRack requirements, panel specifications |
| **BikeRack PRD Ideas** (`sprint/planning/bikerack-prd-ideas.md`) | 14 ideas triaged into MVP/Growth/Vision/OOS |
| **ADR-0024** (`docs/adr/0024-bikerack-mode.md`) | BikeRack mode architecture — env var gating, panel routing, port isolation |
| **ADR-0030** (`docs/adr/0030-bikerack-package-extraction.md`) | Package extraction plan — DataSource interface, BikeRack as standalone package |

## Background

The Pennyfarthing framework originally provided dashboard visibility through Cyclist, an Electron app with dockview-based panel layout. CLI-first developers who prefer Claude Code in their terminal couldn't access sprint status, git diffs, workflow state, or audit logs without opening a browser window.

BikeRack TUI solves this by rendering the same panel data in a Python-based terminal UI using Rich/Textual. The `pf bikerack start` launcher starts WheelHub in the background (with `IS_BIKERACK=1`), then launches the TUI which connects over WebSocket. Panel data flows through the same channels as the browser version — the TUI is a consumer, not a replacement for the data pipeline.

Epic 103 covers 10 MVP panels (Sprint, Git, Progress, AC, Todo, Changed, AuditLog, Background, Debug, Diffs), the launcher infrastructure, the `/bc` panel-switching command, and post-MVP polish stories fixing escape sequences, color thresholds, reconnection behavior, and installation deduplication.

## Technical Architecture

### Component Stack

```
┌─────────────────────────────────┐
│  Claude Code (user terminal)    │
│  ↕ OTEL spans                   │
├─────────────────────────────────┤
│  WheelHub (Express + WebSocket) │
│  Port 2905 / IS_BIKERACK=1     │
│  15 WS channels, 30+ API routes│
├─────────────────────────────────┤
│  BikeRack TUI (Rich/Textual)   │
│  Python, runs in tmux pane      │
│  Connects via WebSocket client  │
└─────────────────────────────────┘
```

### Key Files

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/src/pf/tui/tui.py` | Main Textual app — layout, panel rendering, WS client |
| `pennyfarthing-dist/src/pf/tui/panels/` | Individual panel implementations |
| `pennyfarthing-dist/src/pf/tui/ws_client.py` | WebSocket client with auto-reconnect |
| `pennyfarthing-dist/scripts/bikerack/` | Launcher scripts |
| `packages/core/src/server/` | WheelHub server, API routes, WS channels |

### Data Flow

1. Claude Code emits OTEL spans → WheelHub OTLP receiver
2. WheelHub file watchers monitor sprint YAML, session files, git repos
3. WheelHub pushes updates over WebSocket channels
4. TUI WebSocket client receives channel messages → updates panel state → Rich re-renders

## Cross-Epic Dependencies

**Depends on:**
- WheelHub server infrastructure (packages/core) — provides WebSocket channels and API routes
- OTEL telemetry pipeline — provides span data for debug and audit panels

**Depended on by:**
- Epic 130 (Context Gate Architecture) — TUI displays context and gate status
- ADR-0030 BikeRack extraction — TUI is the primary consumer of the extracted package
