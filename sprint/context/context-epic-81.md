# Epic 81: Dead Code Detection

## Overview

Two-layer diagnostic tool for finding unused and orphaned code across the monorepo. Layer 1: git-based stale file detection (files with zero commits in a configurable time window). Layer 2: unused export detection for TypeScript via ts-prune. Python backend in `pennyfarthing_scripts/deadcode/`. Cyclist integration via Express API, React hook, and dialog. Diagnostic only — does NOT auto-delete.

**Prior work:** Epic 80 (hotspots module) established the pattern for git-analysis Python modules with Cyclist API integration. Dead code detection reuses the same architecture: async git subprocess calls, dataclass result models, Click CLI, Express router, React hook.

## Background

### The Problem

As the Pennyfarthing monorepo grows, dead code accumulates in two forms:

1. **Stale files** — files that exist in the repo but have received zero commits in a long window (e.g., 180 days). These are candidates for deletion or archival.
2. **Unused exports** — TypeScript modules that export symbols consumed by nothing. These increase bundle size, confuse navigation, and rot silently.

Neither category is currently surfaced. Developers must manually grep or rely on IDE hints. A centralized diagnostic gives the team a single view of cleanup targets without the risk of auto-deletion.

### What Already Works

The hotspots module (`pennyfarthing_scripts/hotspots/`) provides a proven pattern:

- **Async git subprocess** — `_run_git_command()` in `analyze.py` (line 50) wraps `asyncio.create_subprocess_exec` for non-blocking git calls
- **Dataclass result models** — `models.py` follows ADR-0008 (`{success, data?, error?}` pattern) with `@dataclass` classes
- **Click CLI** with shared options decorator — `cli.py` uses `_common_options()` (line 31) to DRY up repeated flags
- **Express router** — `hotspots.ts` calls `python3 -m pennyfarthing_scripts.hotspots` via `execFile` with JSON output
- **React hook** — `useHotspots.ts` provides `{data, isLoading, error, refresh}` with AbortController cleanup
- **Server mount** — `server.ts` line 138: `app.use('/api/hotspots', createHotspotsRouter(getProjectDir))`

### Why Two Layers

Stale file detection (Layer 1) catches files that simply stopped being touched — config files, old utilities, abandoned features. Unused export detection (Layer 2) catches a different class: actively-maintained files that export symbols nobody imports. Together they cover both the "forgotten file" and "orphaned API surface" cases.

## Technical Architecture

### Component Map

```
Layer 1: Stale File Detection (Python)
  pennyfarthing_scripts/deadcode/
    ├── analyze.py          # git ls-files + git log --name-only --since=N
    │     ├── _run_git_command()           # reuse pattern from hotspots/analyze.py:50
    │     ├── get_all_tracked_files()      # git ls-files
    │     ├── get_recently_changed_files() # git log --name-only --since=N days
    │     └── find_stale_files()           # set difference: tracked - recently changed
    ├── models.py           # StaleFile, UnusedExport, DeadCodeResult dataclasses
    ├── cli.py              # Click group: pf deadcode stale / exports / all
    ├── formatters.py       # table, JSON, CSV output (mirrors hotspots/formatters.py)
    ├── __init__.py         # Public API re-exports
    └── __main__.py         # python -m pennyfarthing_scripts.deadcode

Layer 2: Unused Export Detection (Python wrapping ts-prune)
  pennyfarthing_scripts/deadcode/analyze.py
    ├── find_unused_exports()  # run ts-prune or tsc, parse output
    └── _parse_ts_prune_output()  # regex parse ts-prune stdout

Cyclist Integration (TypeScript)
  packages/cyclist/src/
    ├── api/dead-code.ts           # Express router: GET /api/dead-code
    │     └── execFile('python3', ['-m', 'pennyfarthing_scripts.deadcode', ...])
    ├── public/hooks/useDeadCode.ts  # React hook: useDeadCode({days, repo?})
    └── public/components/DeadCodeDialog.tsx  # Modal listing stale files + unused exports

Server Mount (server.ts)
  app.use('/api/dead-code', createDeadCodeRouter(getProjectDir))
```

### Key Files (Existing — Reference Implementations)

| File | Lines | Purpose |
|------|-------|---------|
| `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` | 472 | Analysis engine pattern — async git, parsing, scoring |
| `pennyfarthing/pennyfarthing_scripts/hotspots/models.py` | 60 | Dataclass result models with ADR-0008 pattern |
| `pennyfarthing/pennyfarthing_scripts/hotspots/cli.py` | 152 | Click CLI with shared options, async run, formatters |
| `pennyfarthing/pennyfarthing_scripts/hotspots/formatters.py` | 109 | Table/JSON/CSV output formatters |
| `pennyfarthing/pennyfarthing_scripts/hotspots/__init__.py` | 31 | Public API re-exports with `__all__` |
| `pennyfarthing/pennyfarthing_scripts/hotspots/__main__.py` | 6 | Module entry point |
| `pennyfarthing/packages/cyclist/src/api/hotspots.ts` | 59 | Express router — execFile python3, JSON parse |
| `pennyfarthing/packages/cyclist/src/public/hooks/useHotspots.ts` | 113 | React hook — fetch, abort, state management |
| `pennyfarthing/packages/cyclist/src/server.ts` | 506 | API mount point (line 138 for hotspots) |
| `pennyfarthing/packages/cyclist/src/api/index.ts` | — | Re-exports `createHotspotsRouter` (line 9) |

### Key Files (New — To Be Created)

| File | Purpose |
|------|---------|
| `pennyfarthing/pennyfarthing_scripts/deadcode/__init__.py` | Public API: `StaleFile`, `UnusedExport`, `DeadCodeResult`, `find_stale_files`, `find_unused_exports` |
| `pennyfarthing/pennyfarthing_scripts/deadcode/__main__.py` | `python -m pennyfarthing_scripts.deadcode` entry |
| `pennyfarthing/pennyfarthing_scripts/deadcode/models.py` | Dataclasses: `StaleFile`, `UnusedExport`, `DeadCodeResult`, `MultiRepoDeadCodeResult` |
| `pennyfarthing/pennyfarthing_scripts/deadcode/analyze.py` | Core engine: stale file detection (Layer 1) + unused export detection (Layer 2) |
| `pennyfarthing/pennyfarthing_scripts/deadcode/cli.py` | Click group: `stale`, `exports`, `all` subcommands |
| `pennyfarthing/pennyfarthing_scripts/deadcode/formatters.py` | Table/JSON/CSV output |
| `pennyfarthing/packages/cyclist/src/api/dead-code.ts` | Express GET router |
| `pennyfarthing/packages/cyclist/src/public/hooks/useDeadCode.ts` | React hook |
| `pennyfarthing/packages/cyclist/src/public/components/DeadCodeDialog.tsx` | Diagnostic dialog UI |

### API Contracts

**GET /api/dead-code?days=180&repo=pennyfarthing&layer=all**

Query parameters:
- `days` — stale threshold in days (default: 180)
- `repo` — single repo name from repos.yaml (optional; defaults to project root)
- `layer` — `stale`, `exports`, or `all` (default: `all`)

```json
// Response (success)
{
  "success": true,
  "repo_name": "pennyfarthing",
  "repo_path": "/Users/dev/Projects/pf-1/pennyfarthing",
  "time_window_days": 180,
  "stale_files": [
    {
      "path": "src/legacy/old-util.ts",
      "last_commit_date": "2025-06-15T10:30:00+00:00",
      "days_since_last_commit": 237,
      "size_bytes": 1420
    }
  ],
  "unused_exports": [
    {
      "path": "src/utils/helpers.ts",
      "export_name": "formatLegacyDate",
      "line_number": 42
    }
  ],
  "stale_file_count": 12,
  "unused_export_count": 8,
  "error": null
}

// Response (error)
{
  "success": false,
  "error": "git ls-files failed: not a git repository"
}
```

### Data Models

```python
@dataclass
class StaleFile:
    path: str
    last_commit_date: str       # ISO 8601
    days_since_last_commit: int
    size_bytes: int = 0

@dataclass
class UnusedExport:
    path: str
    export_name: str
    line_number: int = 0

@dataclass
class DeadCodeResult:
    success: bool
    repo_name: str
    repo_path: str
    time_window_days: int
    stale_files: list[StaleFile] = field(default_factory=list)
    unused_exports: list[UnusedExport] = field(default_factory=list)
    stale_file_count: int = 0
    unused_export_count: int = 0
    error: str | None = None

@dataclass
class MultiRepoDeadCodeResult:
    success: bool
    repo_results: list[DeadCodeResult] = field(default_factory=list)
    error: str | None = None
```

### Git Commands (Layer 1)

```bash
# All tracked files in repo
git ls-files

# Files changed within the window
git log --name-only --since="180 days ago" --all --pretty=format:""

# Stale files = set(ls-files) - set(log --name-only)
```

Both commands reuse the `_run_git_command()` async subprocess pattern from `hotspots/analyze.py` line 50.

### ts-prune Integration (Layer 2)

ts-prune is not currently installed in the monorepo (no `ts-prune`, `ts-unused-exports`, `knip`, or `unimported` found in any `package.json`). Story 81-2 must add it as a devDependency or use raw `tsc` analysis as a fallback.

```bash
# Option A: ts-prune (preferred, requires install)
npx ts-prune --project tsconfig.json

# Option B: tsc-based (no extra deps)
tsc --noEmit --declaration --emitDeclarationOnly 2>&1 | grep "is declared but"
```

ts-prune output format: `path/to/file.ts:42 - exportName` — parsed by `_parse_ts_prune_output()`.

## Stories

| Story | Title | Points | Priority | Dependencies |
|-------|-------|--------|----------|-------------|
| 81-1 | Python deadcode module: stale file detection | 2 | P0 | None |
| 81-2 | Unused export detection via ts-prune | 2 | P1 | 81-1 (module structure) |
| 81-3 | Dead code API + React hook + dialog | 1 | P0 | 81-1 |

### Story Notes

**81-1**: Create `pennyfarthing_scripts/deadcode/` module mirroring the hotspots structure. Files: `__init__.py`, `__main__.py`, `models.py`, `analyze.py`, `cli.py`, `formatters.py`. Core logic: `git ls-files` to get all tracked files, `git log --name-only --since=N days ago --all --pretty=format:""` to get recently changed files, then set difference produces stale files. Enrich each stale file with `last_commit_date` (via `git log -1 --format=%aI -- <file>`) and `size_bytes` (via `Path.stat()`). Use `_run_git_command()` async pattern from `hotspots/analyze.py` (line 50). Apply `DEFAULT_EXCLUDES` list (node_modules, dist, lock files) matching the hotspots pattern (line 32). CLI: Click group with `stale` subcommand, `_common_options()` decorator for `--days`, `--top`, `--format`, `--output`, `--exclude`, `--repo`, `--path`, `--branch`. Support `--format json` for API consumption. Register in `pennyfarthing_scripts/cli.py` alongside existing `hotspots` group. Use `get_project_root()` from `pennyfarthing_scripts/common/config.py` (line 14) and `load_yaml_config()` (line 68) for multi-repo support.

**81-2**: Add `find_unused_exports()` to `analyze.py`. Install `ts-prune` as a devDependency in the root `package.json` or relevant `packages/*/package.json`. Run `ts-prune --project <tsconfig>` via `asyncio.create_subprocess_exec`, parse stdout line-by-line (format: `path:line - exportName`). Populate `UnusedExport` model instances. If ts-prune is not available at runtime, gracefully degrade: return `DeadCodeResult` with empty `unused_exports` and a warning in `error` field. CLI: add `exports` subcommand to the Click group. Also add an `all` subcommand that runs both layers. The `--tsconfig` option specifies which tsconfig to use (default: `tsconfig.json`). Note: Cyclist has dual tsconfigs (`tsconfig.json` for Node, `tsconfig.vite.json` for React) — may need to run ts-prune twice.

**81-3**: Create Express router at `packages/cyclist/src/api/dead-code.ts` following `hotspots.ts` pattern (59 lines). Factory function `createDeadCodeRouter(getProjectDir)` returns a `Router`. Single `GET /` handler calls `python3 -m pennyfarthing_scripts.deadcode all --format json --days <days>`. Add `--layer` passthrough for `stale`/`exports`/`all`. Set `PYTHONPATH` to the `pennyfarthing/` directory (same as hotspots.ts line 29–33). 30-second timeout. Export from `api/index.ts` and mount in `server.ts` as `app.use('/api/dead-code', createDeadCodeRouter(getProjectDir))`. Create `useDeadCode.ts` hook mirroring `useHotspots.ts` (113 lines): `useState`/`useCallback`/`useRef`/`useEffect`, AbortController cleanup, `fetch('/api/dead-code?...')`. Types: `StaleFile`, `UnusedExport`, `DeadCodeData`, `UseDeadCodeOptions`, `UseDeadCodeReturn`. Create `DeadCodeDialog.tsx` — shadcn Dialog with two tabs (Stale Files, Unused Exports), sortable tables, file count badges. Diagnostic only: no delete buttons.

## Constraints

- **Diagnostic only** — no auto-deletion, no file modification. Results are read-only reports.
- **ts-prune availability** — not currently installed; Layer 2 must handle missing dependency gracefully (empty result + warning, not crash).
- **Dual tsconfig in Cyclist** — `tsconfig.json` (Node main process) vs `tsconfig.vite.json` (React frontend). ts-prune may need to run against both.
- **Async git subprocess** — reuse `_run_git_command()` pattern; do not use synchronous `subprocess.run`.
- **ADR-0008 result pattern** — all models return `{success, data?, error?}` dataclasses, never raise exceptions.
- **DEFAULT_EXCLUDES** — must filter out `node_modules/*`, `dist/*`, `*.lock`, etc. to avoid noise (mirrors `hotspots/analyze.py` line 32).
- **execFile timeout** — Express router must set 30-second timeout on `execFile` call (matches hotspots.ts line 35).
- **`PYTHONPATH`** — Express router must set `PYTHONPATH` to the `pennyfarthing/` directory so Python can find `pennyfarthing_scripts` (matches hotspots.ts line 33).
- **Large repos** — `git ls-files` can return thousands of files; stale file enrichment (`git log -1` per file) should be batched or parallelized to stay within the 30-second API timeout.
- **React hook cleanup** — AbortController must abort in-flight fetch on unmount (matches `useHotspots.ts` line 104–110).
