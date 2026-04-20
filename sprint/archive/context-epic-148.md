# Epic 148: TUI-tmux Fixer

## Overview

Fixes and improvements for TUI tmux pane management, discoverability, and reliability. This epic addresses bugs in the BikeRack TUI's tmux integration and adds new capabilities for automated team pane orchestration.

## Architecture

**TUI tmux panes** are managed through `pf tmux` commands and tracked in `.pennyfarthing/tmux-panes.json`. Panes have roles (`claude`, `tui`, `agent`, `worker`) with protected panes that cannot be killed by automated cleanup.

| Component | File | Purpose |
|-----------|------|---------|
| Pane management | `pennyfarthing-dist/src/pf/tmux/` | tmux pane lifecycle, discovery, registry |
| Pane registry | `.pennyfarthing/tmux-panes.json` | Tracks panes with state, role, protection |
| BikeRack TUI | `pennyfarthing-dist/src/pf/bikerack/` | Textual-based TUI panels |
| Frame server | `pennyfarthing-dist/src/pf/frame/` | FastAPI server (OTLP, WebSocket, API) |
| WheelHub API | `pennyfarthing-dist/src/pf/wheelhub/` | API routes for GUI/TUI |

## Key Files

- `pennyfarthing-dist/src/pf/tmux/panes.py` — pane spawning, listing, killing
- `pennyfarthing-dist/src/pf/tmux/registry.py` — pane registry read/write
- `pennyfarthing-dist/src/pf/bikerack/portrait_panel.py` — agent portrait display
- `pennyfarthing-dist/src/pf/bikerack/git_panel.py` — git status tree display
- `pennyfarthing-dist/src/pf/bikerack/settings_panel.py` — settings UI
- `pennyfarthing-dist/src/pf/frame/websocket.py` — WebSocket for OTEL/signals

## Guardrails

- **Python-first:** All TUI logic is Python (Textual). React is GUI-only (ADR-0034).
- **Return results:** Functions return `{success, data?, error?}`, don't throw.
- **Pane protection:** `claude` and `tui` panes are protected — never auto-kill.
- **Registry as truth:** `.pennyfarthing/tmux-panes.json` is the authoritative pane list.

## Story Status

| Story | Title | Pts | Status |
|-------|-------|-----|--------|
| 148-1 | Extend tmux for pane discoverability | 3 | done |
| 148-2 | Portrait pane does not follow agent choice | 2 | done |
| 148-3 | Portrait pane shows description instead of catchphrase | 2 | backlog |
| 148-4 | Git pane should allow collapsing dirty trees | 2 | backlog |
| 148-5 | Audit log pane not recording OTEL traces via WebSocket | 3 | done |
| 148-6 | Debug pane not receiving signals from WebSocket | 3 | done |
| 148-7 | Settings page rework for new settings | 3 | backlog |
| 148-8 | Peloton mode — spawn team panes and run TDD workflow | 5 | in_progress |
