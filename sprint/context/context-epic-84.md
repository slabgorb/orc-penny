# Epic 84: Composite Health Score

## Overview

Single 0-100 codebase health score displayed as a radial gauge in the DebugPanel header. Weighted composite aggregated from all Codebase Observatory tool dimensions: churn (15%), TODO density (15%), complexity (15%), test gaps (15%), dead code (10%), deprecation debt (10%), dependency freshness (10%), agent context efficiency (10%). Calculates from cached tool results rather than re-running all analysis tools. Python backend in `pennyfarthing_scripts/healthscore/`, thin Express API in Cyclist, React gauge component in DebugPanel.

**Total points:** 5
**Priority:** P2
**Marker:** cyclist
**Repo:** pennyfarthing
**Design doc:** `docs/planning/codebase-observatory.md` (section 9)

## Background

### The Composite Scoring Model

The Codebase Observatory (epics 79-83) delivers six diagnostic tools, each analyzing a different dimension of code health. Epic 84 synthesizes these into a single at-a-glance metric. The score inverts each tool's raw signal into a "health" orientation (higher = healthier) and applies a weighted sum.

The health score is a **derived metric** -- it never runs analysis itself. Each observatory tool caches its results (hotspots, code markers, dead code, agent load, complexity, dependencies), and the health score module reads those cached outputs to compute the composite. When a tool has not been run yet (no cached data), its dimension is excluded and the remaining weights are renormalized to sum to 100%.

This graceful degradation means the health gauge is useful from day one: even if only hotspots and code markers have been run, it produces a partial score from those two dimensions. As more tools are run, the score becomes more comprehensive.

### Weight Table and Scoring Formula

| Dimension | Signal | Weight | Inversion | Source Tool (Epic) |
|-----------|--------|--------|-----------|-------------------|
| Churn concentration | Avg hotspot score of top-10 files (0-100) | 15% | `100 - avg_hotspot_score` | Hotspots (79) |
| TODO/FIXME density | Markers per KLOC | 15% | `max(0, 100 - density * 20)` | Code Markers (80) |
| Complexity | % of files exceeding complexity threshold | 15% | `100 - (pct_exceeding * 100)` | Complexity (83) |
| Test coverage gaps | % of recently changed files without test files | 15% | `100 - (pct_untested * 100)` | Hotspots + heuristic (79) |
| Dead code ratio | Stale files / total tracked files | 10% | `100 - (ratio * 100)` | Dead Code (81) |
| Deprecation debt | Deprecated-but-used call count | 10% | `max(0, 100 - debt_count * 5)` | Code Markers (80) |
| Dependency freshness | % of deps at latest major version | 10% | Direct (already 0-100 healthy) | Dependencies (83) |
| Agent context efficiency | Avg FULL-tier tokens across all agents | 10% | `max(0, 100 - (avg_tokens / 80))` | Agent Load (82) |

**Composite formula:**

```
active_weights = {w for w in weights if dimension has cached data}
normalization_factor = sum(active_weights)

health_score = sum(
    (weight / normalization_factor) * dimension_score
    for weight, dimension_score in active_dimensions
)
```

The result is clamped to 0-100 and rounded to one decimal place. This follows the same `round(min(raw * 100, 100.0), 1)` pattern used by `calculate_hotspot_score()` in `pennyfarthing_scripts/hotspots/analyze.py` (line 198).

### Dependency on Epics 79-83

This epic sits at the top of the Observatory dependency tree. Each upstream epic provides a data source:

| Epic | Tool | Data Consumed by Health Score |
|------|------|------------------------------|
| 79 | Hotspots (refactored) | Top-10 file hotspot scores, changed-files-without-tests heuristic |
| 80 | Code Markers | Marker count, KLOC estimate, deprecated-but-used count |
| 81 | Dead Code | Stale file count, total tracked file count |
| 82 | Agent Load | Per-agent FULL-tier token counts |
| 83 | Complexity + Dependencies | Files-exceeding-threshold count, outdated dependency percentage |

All upstream tools write their results as JSON to a cache location. The health score module reads from this cache rather than importing and calling each tool directly.

## Technical Architecture

### Component Map

```
Python Backend (pennyfarthing_scripts/)
  healthscore/
    __init__.py          — Public API exports
    __main__.py          — python -m pennyfarthing_scripts.healthscore
    analyze.py           — Core scoring engine, cache reader, weight normalization
    models.py            — DimensionScore, HealthScoreResult dataclasses
    cli.py               — Click CLI: healthscore analyze --format json

  Cache reads from:
    hotspots/            — HotspotResult (Epic 79)
    codemarkers/         — CodeMarkerResult (Epic 80)
    deadcode/            — DeadCodeResult (Epic 81)
    complexity/          — ComplexityResult (Epic 83)
    dependencies/        — DependencyResult (Epic 83)

Express API (packages/cyclist/src/)
  api/health-score.ts    — GET /api/health-score, shells out to Python
  api/index.ts           — Export createHealthScoreRouter
  server.ts              — Mount at /api/health-score (line ~138 area)

React Frontend (packages/cyclist/src/public/)
  hooks/useHealthScore.ts        — Fetch + polling hook
  components/HealthGauge.tsx     — Radial gauge component (green/yellow/red)
  components/panels/DebugPanel.tsx — Mounts HealthGauge in header
```

### Key Files (Existing, to be Modified)

| File | Path | Lines | Change |
|------|------|-------|--------|
| DebugPanel | `packages/cyclist/src/public/components/panels/DebugPanel.tsx` | 268 | Add HealthGauge component in header area (above "Context Usage" heading) |
| server.ts | `packages/cyclist/src/server.ts` | 506 | Mount `createHealthScoreRouter(getProjectDir)` at `/api/health-score` |
| API index | `packages/cyclist/src/api/index.ts` | 39 | Export `createHealthScoreRouter` |
| hotspots analyze.py | `pennyfarthing_scripts/hotspots/analyze.py` | 472 | Reference for scoring pattern (weights, normalization, `calculate_hotspot_score`) |
| hotspots models.py | `pennyfarthing_scripts/hotspots/models.py` | 60 | Reference for dataclass result pattern (ADR-0008: `success`, `error`) |
| hotspots API | `packages/cyclist/src/api/hotspots.ts` | 59 | Reference for Express-to-Python shell-out pattern (`execFile` with `python3 -m`) |
| useHotspots hook | `packages/cyclist/src/public/hooks/useHotspots.ts` | 113 | Reference for React hook pattern (fetch + abort + state) |

### Key Files (New)

| File | Path | Purpose |
|------|------|---------|
| `__init__.py` | `pennyfarthing_scripts/healthscore/__init__.py` | Public exports: `HealthScoreResult`, `DimensionScore`, `calculate_health_score` |
| `__main__.py` | `pennyfarthing_scripts/healthscore/__main__.py` | Entry point for `python -m pennyfarthing_scripts.healthscore` |
| `analyze.py` | `pennyfarthing_scripts/healthscore/analyze.py` | Core engine: read cached tool outputs, compute per-dimension scores, weighted aggregate |
| `models.py` | `pennyfarthing_scripts/healthscore/models.py` | `DimensionScore` and `HealthScoreResult` dataclasses |
| `cli.py` | `pennyfarthing_scripts/healthscore/cli.py` | Click CLI group with `analyze` command, `--format json/table` |
| `health-score.ts` | `packages/cyclist/src/api/health-score.ts` | Express router: GET /, shells out to Python CLI |
| `useHealthScore.ts` | `packages/cyclist/src/public/hooks/useHealthScore.ts` | React hook with 60-second polling interval |
| `HealthGauge.tsx` | `packages/cyclist/src/public/components/HealthGauge.tsx` | SVG radial gauge with score, color bands, dimension breakdown |

### API Contracts

**GET /api/health-score**

```json
// Response (all dimensions available)
{
  "success": true,
  "score": 72.3,
  "grade": "C",
  "dimensions": [
    {
      "name": "churn",
      "label": "Churn Concentration",
      "weight": 0.15,
      "raw_value": 45.2,
      "score": 54.8,
      "available": true
    },
    {
      "name": "todo_density",
      "label": "TODO/FIXME Density",
      "weight": 0.15,
      "raw_value": 1.3,
      "score": 74.0,
      "available": true
    },
    {
      "name": "complexity",
      "label": "Complexity",
      "weight": 0.15,
      "raw_value": 0.12,
      "score": 88.0,
      "available": true
    },
    {
      "name": "test_gaps",
      "label": "Test Coverage Gaps",
      "weight": 0.15,
      "raw_value": 0.25,
      "score": 75.0,
      "available": true
    },
    {
      "name": "dead_code",
      "label": "Dead Code",
      "weight": 0.10,
      "raw_value": 0.05,
      "score": 95.0,
      "available": true
    },
    {
      "name": "deprecation_debt",
      "label": "Deprecation Debt",
      "weight": 0.10,
      "raw_value": 3,
      "score": 85.0,
      "available": true
    },
    {
      "name": "dependency_freshness",
      "label": "Dependency Freshness",
      "weight": 0.10,
      "raw_value": 0.68,
      "score": 68.0,
      "available": true
    },
    {
      "name": "agent_context",
      "label": "Agent Context Efficiency",
      "weight": 0.10,
      "raw_value": 3200,
      "score": 60.0,
      "available": true
    }
  ],
  "available_dimensions": 8,
  "total_dimensions": 8,
  "cached_at": "2026-02-07T14:30:00Z",
  "cache_ttl_seconds": 300
}
```

```json
// Response (partial data — some tools not yet run)
{
  "success": true,
  "score": 65.1,
  "grade": "D",
  "dimensions": [
    {
      "name": "churn",
      "label": "Churn Concentration",
      "weight": 0.15,
      "raw_value": 45.2,
      "score": 54.8,
      "available": true
    },
    {
      "name": "todo_density",
      "label": "TODO/FIXME Density",
      "weight": 0.15,
      "raw_value": null,
      "score": null,
      "available": false
    }
  ],
  "available_dimensions": 4,
  "total_dimensions": 8,
  "cached_at": "2026-02-07T14:30:00Z",
  "cache_ttl_seconds": 300
}
```

```json
// Response (error)
{
  "success": false,
  "error": "Failed to compute health score: no cached tool results found"
}
```

**Grade bands:**

| Grade | Score Range | Gauge Color |
|-------|------------|-------------|
| A | 90-100 | Green (`#22c55e`) |
| B | 75-89 | Green-yellow (`#84cc16`) |
| C | 60-74 | Yellow (`#eab308`) |
| D | 40-59 | Orange (`#f97316`) |
| F | 0-39 | Red (`#ef4444`) |

### Python Module Pattern

Follow the established pattern from `pennyfarthing_scripts/hotspots/`:

- **models.py**: Dataclasses with `success: bool` and `error: str | None` fields per ADR-0008
- **analyze.py**: Async functions using `asyncio`, returns result objects (never throws)
- **cli.py**: Click command group with `--format json/table`, `--output` file option
- **`__init__.py`**: Re-exports public symbols
- **`__main__.py`**: Delegates to `cli.py` for `python -m` invocation

The health score `analyze.py` differs from hotspots in one key way: it reads cached JSON files from other tools rather than running `git` commands directly. The cache location should be a well-known path under the project directory (e.g., `.pennyfarthing/cache/observatory/`).

### Express API Pattern

Follow `packages/cyclist/src/api/hotspots.ts` (59 lines):

```typescript
// api/health-score.ts — same pattern as hotspots.ts
export function createHealthScoreRouter(getProjectDir: () => string): Router {
  const router = Router();

  router.get('/', (req, res) => {
    const projectDir = getProjectDir();
    const args = ['-m', 'pennyfarthing_scripts.healthscore', 'analyze', '--format', 'json'];
    const pythonPath = join(projectDir, 'pennyfarthing');

    execFile('python3', args, {
      cwd: pythonPath,
      env: { ...process.env, PYTHONPATH: pythonPath },
      timeout: 15000,  // shorter than hotspots (30s) — reading cache is fast
    }, (err, stdout, stderr) => { /* parse JSON, return result */ });
  });

  return router;
}
```

### React Hook Pattern

Follow `packages/cyclist/src/public/hooks/useHotspots.ts` (113 lines):

- `useHealthScore()` hook with `AbortController` for request cancellation
- Returns `{ data, isLoading, error, refresh }`
- Adds 60-second auto-polling interval (health score changes slowly)
- Fetch from `/api/health-score`

### Gauge Component

`HealthGauge.tsx` renders as an SVG radial gauge:

- 180-degree arc (semicircle) with color gradient matching grade bands
- Score number centered in the arc
- Grade letter below the number
- Dimension count indicator: "6/8 dimensions" if partial
- Click handler to expand dimension breakdown (for story 84-3 drill-through)

Placed in DebugPanel between the panel heading and the "Context Usage" section (line ~137 area in current `DebugPanel.tsx`).

## Stories

| Story | Title | Points | Priority | Dependencies |
|-------|-------|--------|----------|-------------|
| 84-1 | Health score Python module | 2 | P0 | Epics 79-83 (data sources), particularly 79 (hotspots cache) and 80 (code markers cache) |
| 84-2 | Health score API + gauge component | 2 | P0 | 84-1 |
| 84-3 | Per-dimension drill-through from health gauge | 1 | P1 | 84-2, Epic 79 story 79-3 (tool launcher row in DebugPanel) |

### Story Notes

**84-1: Health score Python module**

New module at `pennyfarthing_scripts/healthscore/` with the standard 6-file structure (`__init__.py`, `__main__.py`, `analyze.py`, `models.py`, `cli.py`, plus `formatters.py` if needed).

Key implementation details:
- `models.py`: `DimensionScore` dataclass (name, label, weight, raw_value, score, available) and `HealthScoreResult` dataclass (success, score, grade, dimensions list, available_dimensions, total_dimensions, cached_at, cache_ttl_seconds, error)
- `analyze.py`: `calculate_health_score(project_root: Path) -> HealthScoreResult` reads cached JSON from `.pennyfarthing/cache/observatory/{tool}.json`. Each tool's Express API should write its result to this cache path after a successful run. The health score module itself also caches its computed result, reusing it within a 5-minute TTL window (checked via `cached_at` timestamp in the cache file)
- Default weight configuration as module-level constants (matching the table above). Optionally overridable via a `healthscore` section in `.pennyfarthing/config.local.yaml`
- Per-dimension scoring functions that invert raw signals into 0-100 health scores
- Weight renormalization when dimensions are unavailable: divide each active weight by `sum(active_weights)` so the composite always sums to 100

Follows the hotspots pattern: `analyze.py` defines scoring weights as module-level constants (see `WEIGHT_BUG_FIXES = 0.35` etc. in `pennyfarthing_scripts/hotspots/analyze.py` lines 25-29).

**84-2: Health score API + gauge component**

Three deliverables:
1. **Express API** (`packages/cyclist/src/api/health-score.ts`): `createHealthScoreRouter(getProjectDir)` following the `execFile` + `python3 -m` pattern from `api/hotspots.ts`. Mount in `server.ts` at `/api/health-score`. Add export to `api/index.ts`. Timeout 15 seconds (reading cache is fast)
2. **React hook** (`packages/cyclist/src/public/hooks/useHealthScore.ts`): Same fetch/abort/state pattern as `useHotspots.ts`. Adds 60-second `setInterval` for auto-refresh since the health score is a dashboard-level metric
3. **HealthGauge component** (`packages/cyclist/src/public/components/HealthGauge.tsx`): SVG radial gauge. Green/yellow/red coloring based on grade bands. Shows score, grade letter, and dimension availability. Mounted in `DebugPanel.tsx` header area above "Context Usage". Uses shadcn color tokens where possible for theme consistency

The gauge shows `--/100` with a grey arc when no data is available. When partial data exists, the arc fills proportionally and a footnote reads "N of 8 dimensions".

**84-3: Per-dimension drill-through from health gauge**

Clicking a dimension in the expanded health gauge breakdown opens the corresponding observatory tool dialog. This wires the gauge breakdown items to the dialog openers established by epic 79 (story 79-3: tool launcher row in DebugPanel).

Mapping:
| Dimension | Opens Dialog |
|-----------|-------------|
| Churn Concentration | HotspotsDialog |
| TODO/FIXME Density | CodeMarkersDialog (TODOs tab) |
| Complexity | ComplexityDialog |
| Test Coverage Gaps | HotspotsDialog (filtered view) |
| Dead Code | DeadCodeDialog |
| Deprecation Debt | CodeMarkersDialog (Deprecated tab) |
| Dependency Freshness | DependenciesDialog |
| Agent Context Efficiency | AgentLoadDialog |

Implementation: HealthGauge accepts an `onDimensionClick(dimensionName: string)` callback prop. DebugPanel maps dimension names to dialog open state setters. Each dialog must already be mounted (done by epic 79 story 79-3).

## Constraints

- **Cache-only computation**: The health score module must NEVER run analysis tools directly. It reads cached JSON files. If no cache exists for a dimension, that dimension is excluded. This keeps the health score API response fast (<1 second)
- **5-minute cache TTL**: The composite score itself is cached for 5 minutes. Within that window, `/api/health-score` returns the cached result immediately. After expiry, it recomputes from the latest tool caches
- **Graceful degradation**: With 0 cached dimensions, the API returns `{success: true, score: null, grade: null, available_dimensions: 0}`. The gauge renders as grey/empty. With 1+ dimensions, it produces a partial score. No minimum dimension count is required
- **Weight renormalization**: When N < 8 dimensions are available, the active weights are divided by their sum so the composite is still on a 0-100 scale. Example: if only churn (0.15) and TODO density (0.15) are available, each gets effective weight 0.5
- **Python execution timeout**: Express API sets `timeout: 15000` (15 seconds) on the `execFile` call, shorter than the 30-second timeout used by hotspots since the health score only reads cache files
- **Cache location**: Tool results cached under `.pennyfarthing/cache/observatory/` in the project directory. Each tool writes `{tool-name}.json` after a successful run. The health score writes `health-score.json`
- **No new dependencies**: The Python module uses only stdlib (`json`, `pathlib`, `datetime`, `dataclasses`). No external packages required since it only reads JSON files
- **DebugPanel layout**: The HealthGauge must not displace existing content. It sits between the panel header and "Context Usage" section, taking approximately 80-100px of vertical space. It collapses to a single-line summary on narrow panels
- **Radix Dialog compatibility**: Story 84-3 opens dialogs from within the gauge component. Per the shadcn/Radix pattern, dialogs render in portals. Tests should check `data-state` attributes on triggers, not `title` attributes (see project memory: Radix Tooltip gotcha)

## Planning Artifacts

- **Design doc:** `docs/planning/codebase-observatory.md` (section 9: Composite Health Score)
- **Epics & Stories:** `sprint/future.yaml` (Codebase Observatory initiative, epic-84)
