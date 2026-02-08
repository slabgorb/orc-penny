# Epic 80: Code Markers Tool (TODOs, FIXMEs, Deprecations)

## Overview

New diagnostic tool that scans source files for TODO, FIXME, HACK, and XXX comment markers plus `@deprecated` JSDoc annotations. Cross-references each marker with `git blame` to determine age and author. Flags stale markers older than 90 days. Python backend in `pennyfarthing_scripts/codemarkers/`, Express API in Cyclist, React dialog in Cyclist frontend.

**Pattern:** Mirrors the existing hotspots module end-to-end (Python analysis -> CLI -> Express API -> React hook -> panel/dialog).

## Background

### The Hotspots Pattern

Epic 76 established a full-stack diagnostic analysis pattern with the hotspots module. Code markers follows the identical architecture:

1. **Python module** (`pennyfarthing_scripts/hotspots/`) -- async analysis engine with dataclass models, Click CLI, and formatters
2. **Express API** (`packages/cyclist/src/api/hotspots.ts`) -- thin router that shells out to `python3 -m pennyfarthing_scripts.hotspots`
3. **React hook** (`packages/cyclist/src/public/hooks/useHotspots.ts`) -- fetch wrapper with abort controller, loading/error state
4. **React panel** (`packages/cyclist/src/public/components/panels/HotspotsPanel.tsx`) -- sortable table with time window controls, shadcn components

The hotspots module totals ~820 lines of Python (across 6 files) and ~540 lines of TypeScript (across 3 files). Code markers should land at a similar or smaller footprint since git blame per-line is simpler than full numstat log parsing.

### What Already Exists

- **`pennyfarthing_scripts/hotspots/`** -- fully working reference implementation to copy patterns from
- **`pennyfarthing_scripts/common/`** -- shared utilities (`config.py` for `get_project_root()` / `load_yaml_config()`, `output.py` for colored terminal formatting)
- **`packages/cyclist/src/api/index.ts`** -- barrel export file where new routers are registered (line 9 exports `createHotspotsRouter`)
- **`packages/cyclist/src/server.ts`** -- route mounting point (line 138: `app.use('/api/hotspots', createHotspotsRouter(getProjectDir))`)
- **DebugPanel** (`packages/cyclist/src/public/components/panels/DebugPanel.tsx`, 268 lines) -- where the launcher button for code markers will be placed

## Technical Architecture

### Component Map

```
Python Backend (pennyfarthing_scripts/codemarkers/)
  ├── analyze.py     -- grep for markers + git blame per match
  ├── models.py      -- CodeMarker, DeprecationMarker, CodeMarkersResult dataclasses
  ├── cli.py         -- Click commands: analyze, stale, deprecated
  ├── formatters.py  -- table/JSON/CSV output
  ├── __init__.py    -- public API re-exports
  └── __main__.py    -- python -m entry point

Cyclist Express API (packages/cyclist/src/api/)
  └── code-markers.ts
        └── GET /api/code-markers?days=90&repo=...&type=all|stale|deprecated

Cyclist React Frontend (packages/cyclist/src/public/)
  ├── hooks/useCodeMarkers.ts          -- fetch + abort + loading state
  └── components/CodeMarkersDialog.tsx  -- shadcn Dialog, sortable table, filter tabs
```

### Data Flow

```
CodeMarkersDialog (React)
  └── useCodeMarkers hook
        └── GET /api/code-markers?days=90
              └── Express router shells out:
                    python3 -m pennyfarthing_scripts.codemarkers analyze --format json --days 90
                      ├── grep -rn "TODO|FIXME|HACK|XXX" across source files
                      ├── git blame -L <line>,<line> <file> for each match
                      ├── @deprecated detection via JSDoc regex on .ts/.tsx/.js files
                      └── Returns CodeMarkersResult JSON
```

### Key Files (Existing Reference)

| File | Lines | Purpose |
|------|-------|---------|
| `pennyfarthing_scripts/hotspots/analyze.py` | 472 | Analysis engine -- `_run_git_command()` async pattern, `_parse_git_log()`, `analyze_repo()`, `analyze_all_repos()` |
| `pennyfarthing_scripts/hotspots/models.py` | 60 | Dataclass models following ADR-0008 result pattern (`success`, `error` fields) |
| `pennyfarthing_scripts/hotspots/cli.py` | 152 | Click CLI with `_common_options` decorator, `_run_analysis()` helper, `_output_result()` formatter dispatch |
| `pennyfarthing_scripts/hotspots/formatters.py` | 109 | Table/JSON/CSV formatters using `dataclasses.asdict()` for JSON serialization |
| `pennyfarthing_scripts/hotspots/__init__.py` | 31 | Re-exports models + analysis functions in `__all__` |
| `pennyfarthing_scripts/hotspots/__main__.py` | 6 | `python -m` entry point calling Click group |
| `packages/cyclist/src/api/hotspots.ts` | 59 | Express router -- `execFile('python3', args)` with 30s timeout, JSON parse of stdout |
| `packages/cyclist/src/public/hooks/useHotspots.ts` | 113 | React hook -- `AbortController`, `useState`/`useCallback`/`useRef`, manual `refresh()` trigger |
| `packages/cyclist/src/public/components/panels/HotspotsPanel.tsx` | 365 | Sortable table, `SortableHeader` component, Badge severity coloring, Skeleton loading, time window buttons |
| `packages/cyclist/src/server.ts` | 506 | Route mounting at line 138, `getProjectDir()` helper at line 93-95 |
| `packages/cyclist/src/api/index.ts` | -- | Barrel exports -- new `createCodeMarkersRouter` export goes here |

### Key Patterns to Replicate

**Python async git subprocess** (from `hotspots/analyze.py` lines 50-72):
```python
async def _run_git_command(args: list[str], cwd: Path) -> tuple[str, str, int]:
    proc = await asyncio.create_subprocess_exec(
        "git", *args, cwd=cwd,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    return (stdout.decode("utf-8", errors="replace").strip(), ...)
```

**ADR-0008 result pattern** (from `hotspots/models.py`):
```python
@dataclass
class HotspotResult:
    success: bool
    repo_name: str
    # ... fields ...
    error: str | None = None
```

**Express router shelling to Python** (from `api/hotspots.ts` lines 6-58):
```typescript
export function createHotspotsRouter(getProjectDir: () => string): Router {
    // Build args: ['-m', 'pennyfarthing_scripts.hotspots', 'analyze', '--format', 'json', ...]
    // execFile('python3', args, { cwd: pythonPath, env: { PYTHONPATH: pythonPath }, timeout: 30000 })
}
```

**React hook with abort** (from `hooks/useHotspots.ts` lines 62-113):
```typescript
export function useHotspots(options: UseHotspotsOptions): UseHotspotsReturn {
    // AbortController pattern, fetch('/api/hotspots?...'), manual refresh()
}
```

### API Contracts

**GET /api/code-markers**

Query parameters:
- `days` (number, default 90) -- markers older than this are flagged stale
- `repo` (string, optional) -- named repo from repos.yaml
- `type` (string, default "all") -- filter: `all`, `stale`, `deprecated`

```json
// Response
{
  "success": true,
  "repo_name": "pennyfarthing-orchestrator",
  "repo_path": "/Users/.../pf-1",
  "stale_threshold_days": 90,
  "markers": [
    {
      "path": "src/server.ts",
      "line": 42,
      "marker_type": "TODO",
      "text": "TODO: refactor this into separate module",
      "author": "keithavery",
      "date": "2025-11-15T10:30:00-05:00",
      "age_days": 84,
      "is_stale": false
    }
  ],
  "deprecations": [
    {
      "path": "src/utils.ts",
      "line": 18,
      "symbol": "oldHelper",
      "text": "@deprecated Use newHelper instead",
      "caller_count": 3,
      "callers": ["src/api/stats.ts", "src/api/context.ts", "src/hooks/useLegacy.ts"]
    }
  ],
  "summary": {
    "total_markers": 47,
    "stale_markers": 12,
    "by_type": { "TODO": 30, "FIXME": 10, "HACK": 5, "XXX": 2 },
    "total_deprecations": 3,
    "deprecations_with_callers": 2
  },
  "error": null
}
```

### Proposed Models (codemarkers/models.py)

```python
@dataclass
class CodeMarker:
    path: str
    line: int
    marker_type: str          # TODO, FIXME, HACK, XXX
    text: str                 # Full comment text
    author: str = ""          # From git blame
    date: str = ""            # ISO date from git blame
    age_days: float = 0.0     # Computed from blame date
    is_stale: bool = False    # age_days > stale_threshold

@dataclass
class DeprecationMarker:
    path: str
    line: int
    symbol: str               # Function/class name
    text: str                 # @deprecated annotation text
    caller_count: int = 0     # Number of active callers/importers
    callers: list[str] = field(default_factory=list)

@dataclass
class MarkerSummary:
    total_markers: int = 0
    stale_markers: int = 0
    by_type: dict[str, int] = field(default_factory=dict)
    total_deprecations: int = 0
    deprecations_with_callers: int = 0

@dataclass
class CodeMarkersResult:
    success: bool
    repo_name: str
    repo_path: str
    stale_threshold_days: int
    markers: list[CodeMarker] = field(default_factory=list)
    deprecations: list[DeprecationMarker] = field(default_factory=list)
    summary: MarkerSummary | None = None
    error: str | None = None
```

## Stories

| Story | Title | Points | Priority | Dependencies |
|-------|-------|--------|----------|-------------|
| 80-1 | Python codemarkers module: grep + git blame | 2 | P0 | None |
| 80-2 | @deprecated detection and caller cross-reference | 2 | P1 | 80-1 |
| 80-3 | Code markers API + React hook + dialog | 1 | P0 | 80-1 |

### Story Notes

**80-1: Python codemarkers module: grep + git blame**

New module at `pennyfarthing_scripts/codemarkers/` following the hotspots module structure exactly:

- `analyze.py` -- Core engine. Use `grep -rn` (or Python regex on file contents) to find `TODO`, `FIXME`, `HACK`, `XXX` comment markers. For each match, run `git blame -L <line>,<line> --porcelain <file>` to extract author and commit date. Compute `age_days` from blame date. Flag `is_stale` when `age_days > stale_threshold_days` (default 90). Reuse `_run_git_command()` async pattern from `hotspots/analyze.py` (lines 50-72). Respect `DEFAULT_EXCLUDES` (node_modules, dist, build, lock files) matching hotspots pattern (lines 32-42).
- `models.py` -- Dataclasses following ADR-0008: `CodeMarker`, `DeprecationMarker`, `MarkerSummary`, `CodeMarkersResult` (all with `success`/`error` fields on result).
- `cli.py` -- Click group `codemarkers` with commands: `analyze` (all markers), `stale` (only stale markers), `summary` (counts by type). Reuse `_common_options` decorator pattern from `hotspots/cli.py` (lines 31-41). Options: `--repo`, `--path`, `--days`, `--top`, `--format`, `--output`, `--exclude`.
- `formatters.py` -- Table/JSON/CSV output. JSON uses `dataclasses.asdict()` matching `hotspots/formatters.py` (line 79).
- `__init__.py` -- Re-export models and `analyze_repo` in `__all__`.
- `__main__.py` -- `python -m pennyfarthing_scripts.codemarkers` entry point.

Key implementation detail: `git blame --porcelain` output includes `author` and `author-time` (Unix timestamp) lines. Parse these rather than the compact blame format.

**80-2: @deprecated detection and caller cross-reference**

Extends `analyze.py` with `@deprecated` JSDoc tag detection:

- Regex scan `.ts`, `.tsx`, `.js` files for `@deprecated` in JSDoc comments (`/** ... @deprecated ... */`).
- Extract the symbol name from the line following the JSDoc block (function/class/const declaration).
- Cross-reference callers: grep the codebase for imports of the deprecated symbol, count unique files.
- Populate `DeprecationMarker.callers` with file paths that import or reference the symbol.
- This story depends on 80-1 because it extends the same `analyze.py` engine and reuses the module infrastructure.

**80-3: Code markers API + React hook + dialog**

Three deliverables, following the hotspots frontend pattern:

1. **Express API** (`packages/cyclist/src/api/code-markers.ts`): Copy `hotspots.ts` (59 lines) and change the module invocation from `pennyfarthing_scripts.hotspots` to `pennyfarthing_scripts.codemarkers`. Add `type` query parameter (`all`, `stale`, `deprecated`). Register in `api/index.ts` barrel export. Mount in `server.ts` at `/api/code-markers`.

2. **React hook** (`packages/cyclist/src/public/hooks/useCodeMarkers.ts`): Copy `useHotspots.ts` (113 lines) pattern. TypeScript interfaces mirroring Python dataclasses. `AbortController` for request cancellation. `refresh()` callback for manual trigger. Options: `{ days, repo?, type? }`.

3. **React dialog** (`packages/cyclist/src/public/components/CodeMarkersDialog.tsx`): shadcn `Dialog` (not a dockview panel -- this is a launced-from-DebugPanel modal). Sortable table with columns: Type, File, Line, Text, Author, Age, Stale. Filter tabs: All / Stale / Deprecated. Badge severity: stale markers get `destructive` variant, deprecations with callers get `outline`. Summary bar showing total/stale/deprecated counts. Launcher button added to `DebugPanel.tsx` (268 lines, after the Token Stats section around line 262).

## Constraints

- `git blame` per line is expensive -- batch blame calls by file (blame entire file once, extract relevant lines) rather than one blame per marker
- Python module must work standalone (`python -m pennyfarthing_scripts.codemarkers analyze --path .`) without Cyclist running
- Express API timeout is 30 seconds (matching hotspots) -- large repos with thousands of markers need the blame batching optimization
- Exclude patterns must match hotspots defaults: `node_modules/*`, `dist/*`, `build/*`, `*.lock`, `*.min.js`, `*.min.css`, `*.map`, `package-lock.json`, `pnpm-lock.yaml`
- React dialog uses shadcn Dialog (Radix Portal) -- tests should check `data-state` attribute on trigger, not `title` attr (Radix portal rendering constraint documented in MEMORY.md)
- TypeScript interfaces in the hook must exactly mirror Python dataclass field names (snake_case) for clean JSON deserialization -- matching the convention in `useHotspots.ts`
- `@deprecated` caller detection (80-2) uses simple grep, not full AST analysis -- acceptable for a diagnostic tool
