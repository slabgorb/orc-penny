# Context: Story 120-6 — Sprint panel ignores active sprint preference

**GitHub Issue:** 1898andCo/pennyfarthing#1028
**Points:** 5 (resized from 3)

## Problem

The TUI SprintPanel hardcodes `sprint/current-sprint.yaml` as the data source. When a user switches to a named sprint via `pf sprint use <name>`, CLI agents correctly load the selected sprint but the TUI continues showing the default.

## Acceptance Criteria

### AC1: TUI loads selected sprint

- **Given** `config.local.yaml` has `sprint.active` set to a named sprint
- **When** the TUI Sprint panel loads or refreshes
- **Then** it displays epics, stories, and progress from the selected sprint file

### AC2: Provenance header shows active sprint identity

- **Given** a non-default sprint is active (loaded via registry)
- **When** the Sprint panel renders
- **Then** the header shows the sprint **name** and **type** as a badge
- **Note:** Source path display deferred — long-term this should be a user preference. For now, name + type is sufficient to answer "which sprint am I on?"

### AC3: Default fallback works

- **Given** no `sprint.active` preference OR `sprint.active` is `"default"`
- **When** the Sprint panel loads
- **Then** it loads `sprint/current-sprint.yaml` as before
- **And** no provenance badge is shown (default sprint needs no label)

### AC4: Switching sprints updates the TUI

- **Given** user runs `pf sprint use <other-name>` while TUI is running
- **When** `config.local.yaml` changes
- **Then** the TUI Sprint panel updates to show the newly selected sprint
- **Note:** The WS server already re-reads sprint data on a polling interval. Verify that `getSprintData()` re-reads config on each call (no caching of resolved path). Add a test. If polling interval causes visible delay, that's acceptable for now.

## Design Decisions (resolved 2026-02-21)

| # | Decision | Choice | Rationale |
|---|----------|--------|-----------|
| 1 | Split into multiple stories? | **No — single story, 5 pts** | One issue, one story. Points increased to reflect actual scope. |
| 2 | What does "source path" mean in UI? | **Drop from AC, show name + type only** | Name + type answer "which sprint am I on?" Source path is a power-user need; long-term should be a user preference (settings toggle). |
| 3 | Live-switching in scope? | **Yes** | OP explicitly described switch-back behavior. Verify existing polling handles it; add test. |
| 4 | `contextRoot`/`sessionRoot` display? | **Keep in type, don't display** | Future designs around streaming/filtering events will consume these fields. Not for panel display. |

## Sprint Registry System

1. `sprint/sprints.yaml` — maps sprint names to file paths and metadata (type, description)
2. `.pennyfarthing/config.local.yaml` → `sprint.active` — per-user preference (gitignored)
3. Python `pf/sprint/loader.py` → `load_sprint()` — reference implementation of resolution logic

Resolution order: config preference → registry lookup → resolve path → load YAML. Falls back to `sprint/current-sprint.yaml`.

## Root Cause

`packages/cyclist/src/sprint-data.ts` line ~303: `getSprintData()` hardcodes `const currentSprintPath = join(projectDir, 'sprint', 'current-sprint.yaml')`.

## Key Files

| File | Role |
|------|------|
| `packages/cyclist/src/sprint-data.ts` | Sprint data loading — **fix here** |
| `packages/core/src/public/components/panels/SprintPanel.tsx` | UI display — add provenance header |
| `packages/core/src/public/hooks/useSprint.ts` | WebSocket hook feeding SprintPanel |
| `packages/cyclist/src/websocket.ts` | WS server at `/ws/sprint` |
| `pennyfarthing-dist/pf/sprint/loader.py` | Reference implementation (Python) |
| `pennyfarthing-dist/pf/sprint/cli.py` | `pf sprint use/list/active` commands |
| `pennyfarthing-dist/pf/bikerack/sprint_panel.py` | BikeRack TUI panel — add provenance to header |

## Implementation Status

### Done (on branch `feat/120-6-sprint-panel-active-sprint-preference`)

- **sprint-data.ts**: `resolveSprintFile()` reads config, resolves through registry, injects `registry` metadata into `SprintData`. Covers AC1 + AC3.
- **Tests**: 18 tests in `120-6-sprint-registry-resolution.test.ts` (registry resolution, fallback, config change detection)

### Remaining

| Task | AC | Notes |
|------|----|-------|
| Add `SprintRegistry` type to `useSprint.ts` | AC2 | Mirror backend type so React has it |
| Render provenance in `SprintPanel.tsx` | AC2 | Badge for type, text for name. CSS: flex row, gap, alignment. Only when `data.registry` present. |
| Render provenance in `sprint_panel.py` | AC2 | Append `[type:name]` to header. Use `.get()` for safety. Escape values before Rich markup. |
| Render test for React provenance | AC2 | Mount `EnhancedSprintPanel` with mock data containing `registry`, assert provenance section renders |
| Verify live-switching works | AC4 | Confirm `getSprintData()` re-reads config each call (no path caching). Add integration test simulating config change between calls. |

## Previous Attempt — PR #1044 (closed without merge)

First implementation of AC2 display was incomplete. Issues found in post-mortem:

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | **No render tests** — data layer tested but display layer untested | Medium | Must fix |
| 2 | **Python bare dict access** — `registry['type']` instead of `.get('type', '')` | Low | Must fix |
| 3 | **Rich markup injection** — f-string in `Text.from_markup()` without escaping bracket chars | Low | Must fix |
| 4 | **No CSS/layout for provenance section** — bare `<section>` with no flex/gap styling | Low | Must fix |
| 5 | **Source path not displayed** — AC said "source path" but only name + type rendered | N/A | Resolved: source path dropped from AC per design decision #2 |
| 6 | **Phantom fields** — `contextRoot`/`sessionRoot` piped through but never rendered | N/A | Resolved: kept intentionally per design decision #4 |
