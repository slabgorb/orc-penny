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

1. **sprint-data.ts**: Read config, resolve through registry, load correct file, inject provenance metadata
2. **SprintPanel.tsx**: Show provenance in header (sprint name, type, source path)
3. **Tests**: Registry resolution, fallback, config change detection
