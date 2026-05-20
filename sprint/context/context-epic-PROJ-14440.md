# Epic 79: Dialog Infrastructure + Hotspot Refactor

## Overview

Move observatory tools (starting with Hotspots) out of dockview sidebar panels and into on-demand dialogs launched from DebugPanel. This reduces permanent sidebar clutter (Hotspots is a right-sidebar tab that most users open rarely), creates a reusable ToolDialog component for future observatory tools, and fixes hotspot analysis quality issues (orchestrator repos pollute results, non-code artifacts inflate scores).

**Why now:** The right sidebar has 8 tabs (Sprint, Workflow, AC, Todo, Subagents, Git, Hotspots, Settings). Hotspots is the least-used -- users run analysis occasionally, not continuously. Pulling it into a dialog frees a tab slot, and the ToolDialog pattern sets up future observatory tools (dependency audit, bundle analysis, etc.) to launch the same way.

## Background

### Current State

HotspotsPanel is a full dockview panel registered in `PANEL_INVENTORY`, `RIGHT_SIDEBAR_PANELS`, and `PANEL_TITLES` in DockviewWorkspace.tsx. It is imported and registered via `registerPanelComponent(PANEL_INVENTORY.HOTSPOTS, HotspotsPanel)` in App.tsx. The panel renders a sortable table with time-window controls (30d/60d/90d), file/directory view toggle, and an Analyze button that calls `GET /api/hotspots`.

The API route (`/api/hotspots`) shells out to `python3 -m pennyfarthing_scripts.hotspots analyze --format json`. The Python analysis engine discovers repos via `repos.yaml`, runs `git log --numstat` on each, and computes weighted hotspot scores (bug fixes 35%, changes 30%, authors 20%, churn 10%, recency 5%).

Two quality problems exist:
1. **Orchestrator repos pollute results.** `repos.yaml` lists both `orchestrator` (type: orchestrator) and `pennyfarthing` (type: framework). The orchestrator repo's sprint YAML edits and session files dominate the hotspot rankings, hiding real code hotspots in the framework.
2. **Non-code artifacts inflate scores.** `DEFAULT_EXCLUDES` in `analyze.py` covers `node_modules/`, `dist/`, lock files, and minified assets, but misses `*.yaml`, `*.md`, `*.json` config files, `*.snap` test snapshots, and image/font assets that frequently churn without indicating code quality issues.

### Existing Dialog Patterns

Cyclist has two dialog patterns:
- **shadcn Dialog** (`ui/dialog.tsx`, 120 lines) -- Radix `@radix-ui/react-dialog` primitives (Dialog, DialogContent, DialogHeader, DialogTitle, etc.) with standard max-w-lg sizing.
- **ConfirmDialog** (`ConfirmDialog.tsx`, 168 lines) -- built on shadcn AlertDialog with `useConfirmDialog` hook for promise-based confirm/cancel flow. Uses `AlertDialogContent` which has fixed max-w-lg sizing.
- **ApprovalModal** -- permission approval dialog mounted in App.tsx, uses shadcn Dialog primitives with WebSocket subscription.

None of these support the wider layout (max-w-5xl) needed for data tables.

## Technical Architecture

### Component Map

```
DebugPanel (left sidebar tab)
  |-- Context Usage (existing)
  |-- Token Stats (existing)
  |-- [NEW] Tools section
  |     |-- "Hotspots" button --> opens HotspotsDialog
  |     |-- (future tool buttons)
  |
  v
ToolDialog (new shared wrapper)
  |-- shadcn Dialog + DialogContent with max-w-5xl
  |-- DialogHeader with title
  |-- children slot for tool content
  |
  v
HotspotsDialog (new, replaces HotspotsPanel)
  |-- ToolDialog wrapper
  |-- Reuses HotspotsPanel internals (controls, tables, hooks)
  |-- [NEW] Client-side filter toggles (79-5)
  |
  v
useHotspots hook --> GET /api/hotspots
  |
  v
WheelHub server.ts --> /api/hotspots router
  |-- execFile("python3", ["-m", "pennyfarthing_scripts.hotspots", ...])
  |-- [NEW] passes --skip-type orchestrator (79-4)
  |
  v
pennyfarthing_scripts.hotspots CLI
  |-- [NEW] --skip-type option (79-4)
  |-- analyze_all_repos() reads repos.yaml, [NEW] filters by type
  |-- analyze_repo() runs git log, computes scores
  |-- [NEW] expanded DEFAULT_EXCLUDES (79-5)
```

### Key Files

| File | Lines | Purpose | Stories |
|------|-------|---------|---------|
| `packages/cyclist/src/public/components/panels/DebugPanel.tsx` | 268 | Context usage + token stats panel; add Tools section at bottom | 79-3 |
| `packages/cyclist/src/public/components/panels/HotspotsPanel.tsx` | 365 | Current panel with SortableHeader, FileTable, DirTable, controls | 79-2 |
| `packages/cyclist/src/public/hooks/useHotspots.ts` | 113 | React hook: fetch `/api/hotspots`, abort controller, types (FileHotspot, DirectoryHotspot, HotspotRepoResult, HotspotData) | 79-2 |
| `packages/cyclist/src/api/hotspots.ts` | 59 | Express router, shells out to Python CLI; `createHotspotsRouter(getProjectDir)` | 79-4 |
| `packages/cyclist/src/public/components/DockviewWorkspace.tsx` | 741 | `PANEL_INVENTORY` (line 36), `RIGHT_SIDEBAR_PANELS` (line 87), `PANEL_TITLES` (line 99), panel restore menu (line 661) | 79-2 |
| `packages/cyclist/src/public/App.tsx` | 308 | Panel registration (line 71: `registerPanelComponent(PANEL_INVENTORY.HOTSPOTS, HotspotsPanel)`), panel imports | 79-2 |
| `packages/cyclist/src/public/components/panels/index.ts` | 25 | Barrel export for HotspotsPanel (line 21) | 79-2 |
| `packages/cyclist/src/public/components/ui/dialog.tsx` | 120 | shadcn Dialog primitives (Dialog, DialogContent max-w-lg, DialogHeader, DialogTitle, etc.) | 79-1 |
| `packages/cyclist/src/public/components/ConfirmDialog.tsx` | 168 | Existing dialog pattern with `useConfirmDialog` hook; reference for hook-based dialog state | 79-1 |
| `packages/cyclist/src/server.ts` | -- | WheelHub Express server; mounts hotspots router at line 138 | 79-4 |
| `pennyfarthing_scripts/hotspots/analyze.py` | 472 | Core analysis engine; `DEFAULT_EXCLUDES` (line 32), `analyze_repo()` (line 260), `analyze_all_repos()` (line 420) | 79-4, 79-5 |
| `pennyfarthing_scripts/hotspots/cli.py` | 152 | Click CLI; `_common_options` decorator (line 31), `_run_analysis()` (line 44), `analyze` command (line 131) | 79-4 |
| `pennyfarthing_scripts/hotspots/models.py` | 60 | Dataclasses: `FileHotspot`, `DirectoryHotspot`, `HotspotResult`, `MultiRepoHotspotResult` | 79-4 |
| `repos.yaml` | 31 | Repo config with `type` field per repo (orchestrator, framework) | 79-4 |

All paths are relative to `pennyfarthing/` unless noted otherwise.

### API Contracts

**GET /api/hotspots** (existing)
```
Query params:
  days    - Time window (default 90)
  repo    - Single repo name (optional)

Response: HotspotData | MultiRepoHotspotResult (JSON)
```

**GET /api/hotspots** (after 79-4)
```
Query params:
  days      - Time window (default 90)
  repo      - Single repo name (optional)
  skip_type - Repo type to exclude (default: "orchestrator")
```

The API router in `hotspots.ts` will pass `--skip-type` to the Python CLI. The Python CLI's `analyze_all_repos()` will read `repos.yaml`, check each repo's `type` field, and skip repos matching the skip type.

### Scoring Weights (analyze.py)

| Weight | Factor | Value |
|--------|--------|-------|
| `WEIGHT_BUG_FIXES` | Bug fix commit concentration | 0.35 |
| `WEIGHT_CHANGES` | Raw change frequency | 0.30 |
| `WEIGHT_AUTHORS` | Distinct author count | 0.20 |
| `WEIGHT_CHURN` | Lines added + deleted | 0.10 |
| `WEIGHT_RECENCY` | Inverse age within window | 0.05 |

### Current DEFAULT_EXCLUDES (analyze.py line 32)

```python
DEFAULT_EXCLUDES = [
    "node_modules/*",
    "dist/*",
    "build/*",
    "*.lock",
    "*.min.js",
    "*.min.css",
    "*.map",
    "package-lock.json",
    "pnpm-lock.yaml",
]
```

## Stories

| Story | Title | Points | Priority | Dependencies |
|-------|-------|--------|----------|-------------|
| 79-1 | Create ToolDialog shared component | 1 | P0 | None |
| 79-2 | Migrate HotspotsPanel into HotspotsDialog | 2 | P0 | 79-1 |
| 79-3 | Add tool launcher row to DebugPanel | 1 | P0 | 79-1, 79-2 |
| 79-4 | Hotspot: skip orchestrator repos by type | 2 | P1 | None |
| 79-5 | Hotspot: expand artifact exclusions + client filters | 2 | P1 | 79-2, 79-4 |

### Story Notes

**79-1: Create ToolDialog shared component**

New file: `components/dialogs/ToolDialog.tsx`. Wraps shadcn Dialog (`ui/dialog.tsx`) with:
- `max-w-5xl` on `DialogContent` (overriding the default `max-w-lg`) for data-table-width content
- `DialogHeader` with configurable title via prop
- `open` / `onOpenChange` controlled props (same pattern as `ConfirmDialog.tsx`)
- Children slot for tool-specific content
- `80vh` max-height with internal scroll so large tables don't overflow viewport

Reference the existing `Dialog`, `DialogContent`, `DialogHeader`, `DialogTitle` exports from `ui/dialog.tsx` (lines 109-120). Do not modify the shadcn primitive itself -- override sizing via className prop on `DialogContent`.

**79-2: Migrate HotspotsPanel into HotspotsDialog**

New file: `components/dialogs/HotspotsDialog.tsx`. Extract the rendering logic from `HotspotsPanel.tsx` (the `HotspotsPanel` function at line 190, plus `FileTable`, `DirTable`, `SortableHeader` sub-components) into a dialog that wraps itself in `ToolDialog`.

Removal checklist for the dockview panel registration:
1. `DockviewWorkspace.tsx` line 52: remove `HOTSPOTS: 'hotspots'` from `PANEL_INVENTORY`
2. `DockviewWorkspace.tsx` line 94: remove `PANEL_INVENTORY.HOTSPOTS` from `RIGHT_SIDEBAR_PANELS`
3. `DockviewWorkspace.tsx` line 112: remove `hotspots: 'Hotspots'` from `PANEL_TITLES`
4. `DockviewWorkspace.tsx` line 673: remove `hotspots: 'Hotspots'` from `panelDisplayNames`
5. `App.tsx` line 45: remove `HotspotsPanel` from panel imports
6. `App.tsx` line 71: remove `registerPanelComponent(PANEL_INVENTORY.HOTSPOTS, HotspotsPanel)`
7. `panels/index.ts` line 21: remove `export { HotspotsPanel } from './HotspotsPanel'`
8. Consider keeping `HotspotsPanel.tsx` for backward compatibility or delete it entirely

The `useHotspots` hook (`hooks/useHotspots.ts`) and its types (`FileHotspot`, `DirectoryHotspot`, `HotspotRepoResult`, `HotspotData`) stay unchanged -- `HotspotsDialog` will import and use them directly.

Layout migration note: users with saved dockview layouts (via `useLayoutPersistence`) will have `hotspots` in their serialized panel list. The `DockviewReact.fromJSON()` call in `DockviewWorkspace.tsx` (line 435) will silently skip unregistered panel IDs, so no explicit migration is needed. The `closedPanels` set may accumulate `hotspots` as a ghost entry; the restore menu filters against `panelDisplayNames` which will no longer include it.

**79-3: Add tool launcher row to DebugPanel**

Add a "Tools" section to `DebugPanel.tsx` after the Token Stats section (after line 262). Structure:
- `<Separator>` divider
- `<h4>Tools</h4>` heading
- Button row with a "Hotspots" button that opens `HotspotsDialog`

The dialog state (`open` boolean) lives in `DebugPanel` via `useState`. The button triggers `setOpen(true)`, and `HotspotsDialog` receives `open` + `onOpenChange` props. Future tools (dependency audit, bundle analysis) will add more buttons to this row.

Import chain: `DebugPanel.tsx` imports `HotspotsDialog` from `../dialogs/HotspotsDialog`.

**79-4: Hotspot: skip orchestrator repos by type**

Three-layer change:

1. **Python CLI** (`cli.py`): Add `--skip-type` option to `_common_options` (line 31). Pass it through `_run_analysis()` (line 44) into `analyze_all_repos()`.

2. **Python engine** (`analyze.py`): Add `skip_types: list[str] | None = None` parameter to `analyze_all_repos()` (line 420). After reading `repos.yaml` (line 441), filter repos whose `type` field matches any value in `skip_types`. The `repos.yaml` already has `type: orchestrator` and `type: framework` fields (see `repos.yaml` lines 7-8, 14-15).

3. **Cyclist API** (`api/hotspots.ts`): Add `--skip-type` `orchestrator` to the args array (line 15) by default. Optionally accept `skip_type` query param to override. This ensures the Cyclist UI never shows orchestrator churn in hotspot results.

**79-5: Hotspot: expand artifact exclusions + client filters**

Two-part change:

1. **Server-side** (`analyze.py`): Expand `DEFAULT_EXCLUDES` (line 32) to include:
   - `*.yaml`, `*.yml` (config/sprint files)
   - `*.md` (documentation)
   - `*.json` (config, but NOT `*.ts`/`*.tsx` -- those are code)
   - `*.snap` (test snapshots)
   - `*.svg`, `*.png`, `*.jpg`, `*.gif`, `*.ico` (images)
   - `*.woff`, `*.woff2`, `*.ttf`, `*.eot` (fonts)
   - `.session/*`, `sprint/*` (orchestrator-specific paths)
   - `coverage/*`, `.nyc_output/*` (test coverage output)

2. **Client-side** (`HotspotsDialog.tsx`): Add filter toggle checkboxes above the table:
   - "Show tests" (include/exclude `*.test.*`, `*.spec.*`, `__tests__/*`)
   - "Show styles" (include/exclude `*.css`, `*.scss`)
   - "Show config" (include/exclude remaining config patterns)

   These are client-side filters on the already-fetched data (filter the `allFiles` / `allDirs` arrays in the component). They do not require API changes.

## Constraints

- **Radix Dialog renders in a portal** -- tests cannot check `title` attribute directly; use `data-state` on trigger or `role="dialog"` queries (same gotcha as ApprovalModal and shadcn Tooltip)
- **Radix Dialog removes DOM on close** -- content is not just hidden, it is unmounted. The `useHotspots` hook state must live in `HotspotsDialog` (or above it) so data survives close/reopen within a session
- **Layout persistence** -- removing HOTSPOTS from PANEL_INVENTORY means saved layouts referencing `hotspots` will have a dangling panel ID. Dockview's `fromJSON` handles this gracefully (skips unknown IDs), but the `closedPanels` set and restore menu need to not show `hotspots` as restorable
- **Python `repos.yaml` parsing** -- `analyze_all_repos()` currently reads `repos.yaml` via `load_yaml_config()` and iterates the top-level keys directly (line 447). The actual `repos.yaml` nests repos under a `repos:` key. Verify that `load_yaml_config` returns the inner dict or adjust accordingly
- **`execFile` timeout** -- the hotspots API router has a 30-second timeout (line 34 of `hotspots.ts`). Skipping orchestrator repos reduces analysis time, but expanded excludes should not significantly impact performance since `_should_exclude` uses `fnmatch` which is O(patterns * files)
- **`components/dialogs/` directory does not exist yet** -- story 79-1 must create it
