# Story Context: 84-1 - Health score Python module

## Summary

Create a new `pennyfarthing_scripts/healthscore/` Python module that reads cached JSON results from all Codebase Observatory tools (epics 79-83), computes per-dimension health scores (0-100, higher = healthier), and produces a weighted composite score. The module follows the established hotspots pattern with `models.py`, `analyze.py`, `cli.py`, `__init__.py`, and `__main__.py`. It caches its own composite result for 5 minutes and renormalizes weights when some dimensions are unavailable.

## Current State

### No healthscore module exists

The `pennyfarthing_scripts/` directory contains these tool modules:

```
pennyfarthing_scripts/
  hotspots/          -- Epic 79, exists and working
  brownfield/        -- Brownfield discovery (not Observatory)
  common/            -- Shared utilities (config.py, output.py)
  git/               -- Git operations
  hooks/             -- CLI hooks
  jira/              -- Jira integration
  prime/             -- Agent activation
  sprint/            -- Sprint management
  story/             -- Story utilities
```

Observatory tool modules for epics 80-83 (code markers, dead code, agent load, complexity/dependencies) do not exist yet. The health score module must handle their absence gracefully by excluding unavailable dimensions and renormalizing weights.

### Established patterns to follow

**Hotspots module structure** (`pennyfarthing_scripts/hotspots/`):
- `__init__.py` (31 lines) -- re-exports public symbols via `__all__`
- `__main__.py` (6 lines) -- delegates to `cli.py` for `python -m` invocation
- `models.py` (61 lines) -- dataclasses with `success: bool` and `error: str | None` per ADR-0008
- `analyze.py` (472 lines) -- core engine with module-level weight constants (lines 24-29)
- `cli.py` (153 lines) -- Click command group with `--format`, `--output` options
- `formatters.py` (110 lines) -- table, JSON, CSV output formatters

**Weight constants pattern** from `pennyfarthing_scripts/hotspots/analyze.py` lines 24-29:
```python
WEIGHT_BUG_FIXES = 0.35
WEIGHT_CHANGES = 0.30
WEIGHT_AUTHORS = 0.20
WEIGHT_CHURN = 0.10
WEIGHT_RECENCY = 0.05
```

**Scoring pattern** from `calculate_hotspot_score()` at `pennyfarthing_scripts/hotspots/analyze.py` lines 150-198 -- normalizes each dimension against dataset max, applies weighted sum, returns `round(min(raw * 100, 100.0), 1)`.

**Result object pattern** from `pennyfarthing_scripts/hotspots/models.py` lines 41-51:
```python
@dataclass
class HotspotResult:
    success: bool
    repo_name: str
    repo_path: str
    time_window_days: int
    commit_count: int = 0
    file_hotspots: list[FileHotspot] = field(default_factory=list)
    directory_hotspots: list[DirectoryHotspot] = field(default_factory=list)
    error: str | None = None
```

**Project root discovery** from `pennyfarthing_scripts/common/config.py` lines 14-61 -- `get_project_root()` checks `PROJECT_ROOT` and `CLAUDE_PROJECT_DIR` env vars, then walks up looking for `pennyfarthing-dist/` or `.pennyfarthing/`.

**CLI pattern** from `pennyfarthing_scripts/hotspots/cli.py` lines 18-28 -- Click `@click.group()` with subcommands, shared `_common_options` decorator, `_run_analysis()` helper that calls `asyncio.run()`.

### Cache location

The epic context specifies `.pennyfarthing/cache/observatory/` as the cache directory. Each upstream tool (epics 79-83) will write its results as `{tool-name}.json` after a successful run. The health score module reads from this cache and writes its own composite to `health-score.json` in the same directory.

This cache directory does not exist yet. The health score module must create it if missing.

## Target State

After implementation:

1. **`pennyfarthing_scripts/healthscore/`** exists with 6 files: `__init__.py`, `__main__.py`, `models.py`, `analyze.py`, `cli.py`, `formatters.py`
2. `python -m pennyfarthing_scripts.healthscore analyze --format json` outputs a `HealthScoreResult` JSON object
3. The module reads cached tool results from `.pennyfarthing/cache/observatory/{tool}.json`
4. With 0 cached dimensions, returns `{success: true, score: null, grade: null, available_dimensions: 0}`
5. With N < 8 cached dimensions, renormalizes active weights and produces a partial composite score
6. Caches its own composite result to `.pennyfarthing/cache/observatory/health-score.json` with a 5-minute TTL
7. Subsequent calls within 5 minutes return the cached composite immediately
8. Weight configuration is module-level constants, optionally overridable via `.pennyfarthing/config.local.yaml`

## Key Files

### Files to Create

| File | Path | Purpose |
|------|------|---------|
| `__init__.py` | `pennyfarthing/pennyfarthing_scripts/healthscore/__init__.py` | Re-export `HealthScoreResult`, `DimensionScore`, `calculate_health_score` |
| `__main__.py` | `pennyfarthing/pennyfarthing_scripts/healthscore/__main__.py` | Entry point for `python -m pennyfarthing_scripts.healthscore` |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/healthscore/models.py` | `DimensionScore` and `HealthScoreResult` dataclasses |
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/healthscore/analyze.py` | Core engine: read cache, compute per-dimension scores, weighted aggregate |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/healthscore/cli.py` | Click CLI: `healthscore analyze --format json/table` |
| `formatters.py` | `pennyfarthing/pennyfarthing_scripts/healthscore/formatters.py` | JSON and table output formatting |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| `hotspots __init__.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/__init__.py` | Public export pattern (lines 1-31) |
| `hotspots __main__.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/__main__.py` | Entry point pattern (lines 1-6) |
| `hotspots models.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/models.py` | ADR-0008 result dataclass pattern (lines 41-51) |
| `hotspots analyze.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` | Weight constants (lines 24-29), scoring formula (lines 150-198) |
| `hotspots cli.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/cli.py` | Click CLI group pattern (lines 18-28), shared options (lines 31-41) |
| `hotspots formatters.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/formatters.py` | JSON/table export pattern (lines 26-109) |
| `common/config.py` | `pennyfarthing/pennyfarthing_scripts/common/config.py` | `get_project_root()` (lines 14-61), `load_yaml_config()` (lines 68-81) |
| Epic context | `sprint/context/context-epic-84.md` | Weight table, scoring formulas, API contract, grade bands |

## Technical Approach

### 1. Create `models.py`

Define two dataclasses following the ADR-0008 pattern from `hotspots/models.py`:

```python
from dataclasses import dataclass, field
from datetime import datetime

@dataclass
class DimensionScore:
    """Score for a single health dimension."""
    name: str                    # e.g. "churn", "todo_density"
    label: str                   # e.g. "Churn Concentration"
    weight: float                # configured weight (0.0-1.0)
    raw_value: float | None = None   # raw signal from tool cache
    score: float | None = None       # inverted 0-100 health score
    available: bool = False          # True if cached data exists

@dataclass
class HealthScoreResult:
    """Composite health score result."""
    success: bool
    score: float | None = None        # 0-100 composite, None if no data
    grade: str | None = None          # A/B/C/D/F
    dimensions: list[DimensionScore] = field(default_factory=list)
    available_dimensions: int = 0
    total_dimensions: int = 8
    cached_at: str | None = None      # ISO timestamp
    cache_ttl_seconds: int = 300      # 5 minutes
    error: str | None = None
```

### 2. Create `analyze.py`

Core engine with these components:

**Weight constants** (mirroring the pattern at `hotspots/analyze.py` lines 24-29):
```python
# Dimension weights (must sum to 1.0)
WEIGHT_CHURN = 0.15
WEIGHT_TODO_DENSITY = 0.15
WEIGHT_COMPLEXITY = 0.15
WEIGHT_TEST_GAPS = 0.15
WEIGHT_DEAD_CODE = 0.10
WEIGHT_DEPRECATION_DEBT = 0.10
WEIGHT_DEPENDENCY_FRESHNESS = 0.10
WEIGHT_AGENT_CONTEXT = 0.10

CACHE_DIR = ".pennyfarthing/cache/observatory"
CACHE_TTL_SECONDS = 300  # 5 minutes
```

**Dimension configuration** as a list of tuples: `(name, label, weight, cache_file, inversion_fn)`.

**Cache reader** function that loads `{tool}.json` from the cache directory and extracts the raw signal for each dimension:
```python
def _read_tool_cache(project_root: Path, tool_file: str) -> dict | None:
    cache_path = project_root / CACHE_DIR / tool_file
    if not cache_path.exists():
        return None
    try:
        with open(cache_path) as f:
            data = json.load(f)
        # Check cache freshness (tool's own cache may be stale)
        return data if data.get("success") else None
    except (json.JSONDecodeError, OSError):
        return None
```

**Per-dimension scoring functions** that invert raw signals to 0-100 health scores (from the epic weight table):
- `_score_churn(data) -> float`: `100 - avg_hotspot_score` of top-10 files
- `_score_todo_density(data) -> float`: `max(0, 100 - density * 20)`
- `_score_complexity(data) -> float`: `100 - (pct_exceeding * 100)`
- `_score_test_gaps(data) -> float`: `100 - (pct_untested * 100)`
- `_score_dead_code(data) -> float`: `100 - (ratio * 100)`
- `_score_deprecation_debt(data) -> float`: `max(0, 100 - debt_count * 5)`
- `_score_dependency_freshness(data) -> float`: direct (already 0-100)
- `_score_agent_context(data) -> float`: `max(0, 100 - (avg_tokens / 80))`

**Weight renormalization** when N < 8 dimensions are available:
```python
active_weights = [d.weight for d in dimensions if d.available]
normalization_factor = sum(active_weights)
# Each active dimension's effective weight = d.weight / normalization_factor
```

**Grade assignment** based on score bands:
```python
def _compute_grade(score: float) -> str:
    if score >= 90: return "A"
    if score >= 75: return "B"
    if score >= 60: return "C"
    if score >= 40: return "D"
    return "F"
```

**Main function** `calculate_health_score(project_root: Path) -> HealthScoreResult`:
1. Check for cached composite in `health-score.json` -- if fresh (< 5 min), return it immediately
2. Read each tool's cache file and compute per-dimension scores
3. Renormalize weights for available dimensions
4. Compute weighted composite, clamp to 0-100, round to 1 decimal
5. Assign grade
6. Write composite to `health-score.json` cache
7. Return `HealthScoreResult`

### 3. Create `cli.py`

Click command group following `hotspots/cli.py` pattern:

```python
@click.group()
def healthscore():
    """Composite codebase health score."""
    pass

@healthscore.command()
@click.option("--format", "fmt", type=click.Choice(["table", "json"]), default="table")
@click.option("--output", "output_file", type=click.Path(), help="Write output to file")
@click.option("--no-cache", is_flag=True, help="Force recalculation, ignore cached composite")
def analyze(fmt, output_file, no_cache):
    """Calculate composite health score from cached tool results."""
    from pennyfarthing_scripts.common.config import get_project_root
    from pennyfarthing_scripts.healthscore.analyze import calculate_health_score
    # ...
```

### 4. Create `__init__.py` and `__main__.py`

Follow the exact patterns from `hotspots/__init__.py` (lines 1-31) and `hotspots/__main__.py` (lines 1-6).

### 5. Create `formatters.py`

JSON serialization via `dataclasses.asdict()` (matching `hotspots/formatters.py` line 79) and table formatter for terminal output showing each dimension's name, weight, score, and availability.

## Acceptance Criteria

- `pennyfarthing_scripts/healthscore/` module exists with `__init__.py`, `__main__.py`, `models.py`, `analyze.py`, `cli.py`, `formatters.py`
- `python -m pennyfarthing_scripts.healthscore analyze --format json` produces valid JSON matching the `HealthScoreResult` schema from the epic context API contract
- With no cached tool results, returns `{success: true, score: null, grade: null, available_dimensions: 0, total_dimensions: 8}`
- With partial cached results (e.g., only hotspots), renormalizes weights and produces a valid partial score
- With all 8 dimensions cached, produces a fully weighted composite score 0-100
- Composite result is cached to `.pennyfarthing/cache/observatory/health-score.json` with 5-minute TTL
- Repeated calls within 5 minutes return the cached composite without recomputation
- `--no-cache` flag forces recalculation
- Weight constants sum to 1.0
- Each dimension's inversion formula matches the epic weight table exactly
- Grade bands match: A (90-100), B (75-89), C (60-74), D (40-59), F (0-39)
- Module uses only stdlib (`json`, `pathlib`, `datetime`, `dataclasses`) plus `click` for CLI -- no new external dependencies
- All functions return result objects per ADR-0008 (never throw)

## Dependencies

### Depends On

- **Epic 79** (Hotspots) -- provides churn and test gap data via cached `hotspots.json`. The hotspots module exists and is working, but does not yet write to the `.pennyfarthing/cache/observatory/` cache directory. Either this story or a preceding chore must add cache-writing to the hotspots API, or the health score module must know how to read the hotspots data from wherever it currently lives
- **Epic 80** (Code Markers) -- provides TODO density and deprecation debt via `codemarkers.json`. Module does not exist yet
- **Epic 81** (Dead Code) -- provides stale file ratio via `deadcode.json`. Module does not exist yet
- **Epic 82** (Agent Load) -- provides agent context efficiency via `agentload.json`. Module does not exist yet
- **Epic 83** (Complexity + Dependencies) -- provides complexity threshold and dependency freshness via `complexity.json` and `dependencies.json`. Modules do not exist yet

### Depended On By

- **84-2** (Health score API + gauge component) -- shells out to `python -m pennyfarthing_scripts.healthscore analyze --format json` to get the composite score
- **84-3** (Per-dimension drill-through) -- uses dimension names from the health score result to map to tool dialog openers

## Risks / Open Questions

1. **Upstream cache format undefined**: Epics 80-83 modules do not exist yet. The health score module must define the expected cache JSON schema for each tool, but those tools may produce different shapes when implemented. Mitigation: define minimal required fields per dimension and document the expected cache contract in `analyze.py` docstrings. The per-dimension scoring functions should fail gracefully (return `available: false`) if the cache shape is unexpected.

2. **Hotspots cache path**: The hotspots module currently writes results to stdout via its CLI -- it does not persist cached results to `.pennyfarthing/cache/observatory/hotspots.json`. The Express API (`api/hotspots.ts`) calls the Python CLI and returns the result to the browser, but does not write to disk. Either (a) the hotspots Express API should be updated to cache results, (b) the health score module should call the hotspots CLI directly to generate fresh data, or (c) a separate "cache writer" mechanism should be introduced. Option (a) is simplest and aligns with the epic design: each tool's API writes cache after a successful run.

3. **Cache staleness**: The 5-minute TTL for the composite cache is separate from each tool's own data freshness. A tool's cache file could be hours or days old. The health score module reads whatever is in the cache without checking per-tool freshness. This is by design (the health score is a derived metric, not a trigger for re-analysis), but users may be confused by stale scores. Consider adding a `stale_dimensions` field listing dimensions whose cache is older than a configurable threshold.

4. **Weight configuration override**: The epic mentions optional weight override via `.pennyfarthing/config.local.yaml`. This adds complexity. Start with hardcoded module-level constants; add config override as a follow-up enhancement if needed.

5. **No external dependencies**: The module must use only stdlib plus `click`. This means no `yaml` for reading `config.local.yaml` weight overrides. If config override is needed, either use the existing `pennyfarthing_scripts.common.config.load_yaml_config()` (which depends on PyYAML, already a project dependency), or defer config override to a follow-up.
