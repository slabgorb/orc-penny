# Context: Story 120-6 — Sprint panel ignores active sprint preference

**GitHub Issue:** 1898andCo/pennyfarthing#1028

## Problem

The TUI SprintPanel hardcodes `sprint/current-sprint.yaml` as the data source. When a user switches to a named sprint via `pf sprint use <name>`, CLI agents correctly load the selected sprint but the TUI continues showing the default.

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

## Fix Scope

1. **sprint-data.ts**: Read config, resolve through registry, load correct file, inject provenance metadata — **DONE** (PR #1044 branch, merged to develop)
2. **SprintPanel.tsx + useSprint.ts**: Show provenance in header (sprint name, type, source path) — **NEEDS REDO**
3. **sprint_panel.py**: Show provenance in BikeRack TUI header — **NEEDS REDO**
4. **Tests**: Registry resolution, fallback, config change detection — **DONE** (18 tests in 120-6-sprint-registry-resolution.test.ts)

## Previous Attempt — PR #1044 (closed without merge)

First implementation of AC2/AC3 display was incomplete. Issues found in post-mortem:

| # | Issue | Severity |
|---|-------|----------|
| 1 | **Source path not displayed** — AC says "source path" but only name + type rendered | Medium |
| 2 | **Python bare dict access** — `registry['type']` instead of `.get('type', '')`, KeyError on malformed payload | Low |
| 3 | **No CSS/layout for provenance section** — bare `<section>` with no flex/gap styling | Low |
| 4 | **No render tests** — data layer tested but display layer untested | Medium |
| 5 | **Rich markup injection** — f-string in `Text.from_markup()` without escaping bracket chars | Low |
| 6 | **Phantom fields** — `contextRoot`/`sessionRoot` piped through entire stack but never rendered | Design gap |

### Requirements for next attempt

- Render all three provenance fields: sprint name, type, and source path (contextRoot or resolved file)
- Source path as tooltip or truncated display — full filesystem path is too long for header
- Python: use `.get()` for registry fields, escape values before Rich markup
- React: add CSS for `[data-section="sprint-source"]` (flex row, gap, alignment)
- Write render tests: mount `EnhancedSprintPanel` with mock registry data, assert provenance section
- Decide: either use `contextRoot`/`sessionRoot` in display or remove from the type
