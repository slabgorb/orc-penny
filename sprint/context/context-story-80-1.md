# Story Context: 80-1 - Python codemarkers module: grep + git blame

## Summary

New Python module at `pennyfarthing_scripts/codemarkers/` that scans source files for `TODO`, `FIXME`, `HACK`, and `XXX` comment markers, then cross-references each match with `git blame --porcelain` to determine author and age. Markers older than a configurable threshold (default 90 days) are flagged as stale. The module follows the exact structure and patterns established by the `hotspots` module: async git subprocess, dataclass models with ADR-0008 result pattern, Click CLI with shared options, and table/JSON/CSV formatters.

## Current State

### No codemarkers module exists

There is no `pennyfarthing_scripts/codemarkers/` directory. The feature is entirely new.

### Reference implementation: hotspots module

The `hotspots` module at `pennyfarthing_scripts/hotspots/` provides the complete pattern to replicate. It consists of 6 files totaling ~820 lines:

- **`analyze.py`** (473 lines) -- async git subprocess pattern via `_run_git_command()` (lines 50-72), `DEFAULT_EXCLUDES` list (lines 32-42), `_should_exclude()` helper (lines 201-209), `analyze_repo()` entry point (lines 260-417), `analyze_all_repos()` for multi-repo support (lines 420-472)
- **`models.py`** (61 lines) -- `@dataclass` models following ADR-0008: `FileHotspot`, `DirectoryHotspot`, `HotspotResult` (with `success: bool` and `error: str | None`), `MultiRepoHotspotResult`
- **`cli.py`** (153 lines) -- Click `@click.group()` at line 18, `_common_options` decorator (lines 31-41) applying `--repo`, `--path`, `--days`, `--top`, `--format`, `--output`, `--exclude`, `--branch`; `_run_analysis()` helper (lines 44-79) with `asyncio.run()`, `_output_result()` (lines 82-128) for formatter dispatch
- **`formatters.py`** (110 lines) -- `format_file_table()` (lines 26-44), `format_summary()` (lines 67-74) using `common/output.py` helpers, `export_json()` using `dataclasses.asdict()` (line 79), `export_csv()` (lines 82-109)
- **`__init__.py`** (31 lines) -- re-exports models and analysis functions in `__all__`
- **`__main__.py`** (7 lines) -- `python -m` entry point calling the Click group

### Shared utilities

- **`pennyfarthing_scripts/common/config.py`** -- `get_project_root()` (lines 14-61) walks up from cwd looking for `pennyfarthing-dist/` or `.pennyfarthing/`, also checks `PROJECT_ROOT` and `CLAUDE_PROJECT_DIR` env vars; `load_yaml_config()` (lines 68-81) for `repos.yaml`
- **`pennyfarthing_scripts/common/output.py`** -- `header()` (lines 131-143), `info()` (lines 87-95), `success()` (lines 76-84), `warn()` (lines 98-106), `error()` (lines 109-117) for colored terminal output

## Target State

After implementation, `pennyfarthing_scripts/codemarkers/` exists with 6 files following the hotspots pattern:

```
pennyfarthing_scripts/codemarkers/
  ├── __init__.py       # Re-exports models + analyze_repo in __all__
  ├── __main__.py       # python -m pennyfarthing_scripts.codemarkers entry point
  ├── analyze.py        # Core engine: grep for markers, git blame per file, staleness computation
  ├── cli.py            # Click group with analyze, stale, summary commands
  ├── formatters.py     # Table/JSON/CSV output formatters
  └── models.py         # CodeMarker, MarkerSummary, CodeMarkersResult dataclasses
```

Running `python3 -m pennyfarthing_scripts.codemarkers analyze --path . --format json` produces structured JSON output matching the API contract defined in the epic context.

## Key Files

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `models.py` | `pennyfarthing/pennyfarthing_scripts/codemarkers/models.py` | `CodeMarker`, `DeprecationMarker`, `MarkerSummary`, `CodeMarkersResult` dataclasses |
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/codemarkers/analyze.py` | Core grep + git blame engine with async subprocess |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/codemarkers/cli.py` | Click CLI group with `analyze`, `stale`, `summary` commands |
| `formatters.py` | `pennyfarthing/pennyfarthing_scripts/codemarkers/formatters.py` | Table/JSON/CSV output formatters |
| `__init__.py` | `pennyfarthing/pennyfarthing_scripts/codemarkers/__init__.py` | Public API re-exports |
| `__main__.py` | `pennyfarthing/pennyfarthing_scripts/codemarkers/__main__.py` | `python -m` entry point |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` | `_run_git_command()` (lines 50-72), `DEFAULT_EXCLUDES` (lines 32-42), `_should_exclude()` (lines 201-209), `analyze_repo()` (lines 260-417), `analyze_all_repos()` (lines 420-472) -- all patterns to replicate |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/models.py` | ADR-0008 result pattern: `success: bool`, `error: str \| None` on result dataclasses |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/cli.py` | `_common_options` decorator (lines 31-41), `_run_analysis()` helper (lines 44-79), `_output_result()` (lines 82-128) |
| `formatters.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/formatters.py` | `export_json()` using `dataclasses.asdict()` (line 79), `export_csv()` pattern (lines 82-109) |
| `__init__.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/__init__.py` | `__all__` export pattern (lines 22-31) |
| `__main__.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/__main__.py` | Entry point pattern (lines 1-6) |
| `config.py` | `pennyfarthing/pennyfarthing_scripts/common/config.py` | `get_project_root()` (lines 14-61), `load_yaml_config()` (lines 68-81) |
| `output.py` | `pennyfarthing/pennyfarthing_scripts/common/output.py` | `header()`, `info()` for summary display |

## Technical Approach

### 1. Create `models.py`

Define dataclasses following ADR-0008. The `DeprecationMarker` is included here for 80-2 but is not populated by 80-1's analysis.

```python
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class CodeMarker:
    """A single TODO/FIXME/HACK/XXX comment marker."""
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
    """A @deprecated JSDoc annotation with caller cross-reference."""
    path: str
    line: int
    symbol: str               # Function/class/const name
    text: str                 # @deprecated annotation text
    caller_count: int = 0
    callers: list[str] = field(default_factory=list)


@dataclass
class MarkerSummary:
    """Aggregate counts for code markers."""
    total_markers: int = 0
    stale_markers: int = 0
    by_type: dict[str, int] = field(default_factory=dict)
    total_deprecations: int = 0
    deprecations_with_callers: int = 0


@dataclass
class CodeMarkersResult:
    """Analysis result following ADR-0008 pattern."""
    success: bool
    repo_name: str
    repo_path: str
    stale_threshold_days: int
    markers: list[CodeMarker] = field(default_factory=list)
    deprecations: list[DeprecationMarker] = field(default_factory=list)
    summary: MarkerSummary | None = None
    error: str | None = None
```

### 2. Create `analyze.py`

Core engine with three main operations:

**a) Grep for markers** -- Use `asyncio.create_subprocess_exec` to run `grep -rnE "(TODO|FIXME|HACK|XXX)\b"` across the repo, respecting `DEFAULT_EXCLUDES` (reuse the same list from hotspots). Parse each match line as `file:line:text`.

```python
MARKER_PATTERN = r"\b(TODO|FIXME|HACK|XXX)\b"

async def _grep_markers(repo_path: Path, excludes: list[str]) -> list[tuple[str, int, str]]:
    """Grep for comment markers, returning (path, line, text) tuples."""
    exclude_args = []
    for pattern in excludes:
        exclude_args.extend(["--exclude", pattern])
        exclude_args.extend(["--exclude-dir", pattern.rstrip("/*")])

    args = ["grep", "-rnE", MARKER_PATTERN, str(repo_path)] + exclude_args
    proc = await asyncio.create_subprocess_exec(
        *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, _ = await proc.communicate()
    # ...parse lines...
```

**b) Batch git blame per file** -- Group markers by file path. For each unique file, run `git blame --porcelain <file>` once and parse the output to extract `author` and `author-time` (Unix timestamp) for each line number. This is the key optimization constraint from the epic: blame entire files rather than one blame per marker line.

```python
async def _blame_file(repo_path: Path, file_path: str) -> dict[int, tuple[str, int]]:
    """Blame an entire file, returning {line_num: (author, unix_timestamp)}."""
    stdout, stderr, rc = await _run_git_command(
        ["blame", "--porcelain", file_path], repo_path
    )
    # Parse porcelain output: line starts with commit hash, then
    # "author <name>" and "author-time <unix>" on subsequent lines
```

**c) Assemble results** -- For each grep match, look up the blame data, compute `age_days` from the Unix timestamp, set `is_stale = age_days > stale_threshold_days`, determine `marker_type` from the matched keyword, and build `CodeMarker` instances.

```python
async def analyze_repo(
    name: str,
    path: Path,
    days: int = 90,
    excludes: list[str] | None = None,
) -> CodeMarkersResult:
```

Reuse `_run_git_command()` from the hotspots pattern (copy the same async subprocess helper). Reuse `DEFAULT_EXCLUDES` (same list). Include `analyze_all_repos()` for multi-repo support via `repos.yaml`, following `hotspots/analyze.py` lines 420-472.

### 3. Create `cli.py`

Click group `codemarkers` with three commands:

- **`analyze`** -- All markers with full detail (default)
- **`stale`** -- Only markers older than `--days` threshold
- **`summary`** -- Counts by type, no individual markers

Reuse `_common_options` decorator pattern from `hotspots/cli.py` (lines 31-41). The options are: `--repo`, `--path`, `--days` (default 90), `--top` (default 50), `--format` (table/json/csv), `--output`, `--exclude`.

```python
@click.group()
def codemarkers():
    """Code marker detection (TODO, FIXME, HACK, XXX)."""
    pass

@codemarkers.command()
@_common_options
def analyze(repo, repo_path, days, top, fmt, output_file, exclude):
    """Full code marker analysis with git blame."""
    result = _run_analysis(repo, repo_path, days, exclude)
    _output_result(result, fmt, output_file, top, "analyze")
```

### 4. Create `formatters.py`

Following `hotspots/formatters.py`:

- `format_marker_table()` -- Column-aligned table with columns: Type, File, Line, Age, Author, Stale, Text
- `format_summary()` -- Header with total/stale/by-type counts using `common/output.py` helpers
- `export_json()` -- `json.dumps(asdict(result), indent=2, default=str)` matching hotspots line 79
- `export_csv()` -- CSV with headers: path, line, marker_type, text, author, date, age_days, is_stale

### 5. Create `__init__.py` and `__main__.py`

Follow the exact patterns from hotspots:

```python
# __init__.py
from pennyfarthing_scripts.codemarkers.models import (
    CodeMarker, DeprecationMarker, MarkerSummary, CodeMarkersResult,
)
from pennyfarthing_scripts.codemarkers.analyze import analyze_repo, analyze_all_repos

__all__ = [
    "CodeMarker", "DeprecationMarker", "MarkerSummary", "CodeMarkersResult",
    "analyze_repo", "analyze_all_repos",
]
```

```python
# __main__.py
"""Allow running as: python -m pennyfarthing_scripts.codemarkers"""
from pennyfarthing_scripts.codemarkers.cli import codemarkers

if __name__ == "__main__":
    codemarkers()
```

## Acceptance Criteria

- `python3 -m pennyfarthing_scripts.codemarkers analyze --path <repo> --format json` produces valid JSON matching the `CodeMarkersResult` schema
- `python3 -m pennyfarthing_scripts.codemarkers stale --path <repo> --days 90` outputs only markers older than 90 days
- `python3 -m pennyfarthing_scripts.codemarkers summary --path <repo>` outputs aggregate counts by marker type
- Table, JSON, and CSV output formats all work via `--format` flag
- `DEFAULT_EXCLUDES` match the hotspots list: `node_modules/*`, `dist/*`, `build/*`, `*.lock`, `*.min.js`, `*.min.css`, `*.map`, `package-lock.json`, `pnpm-lock.yaml`
- Git blame data populates `author`, `date`, and `age_days` fields on each marker
- `is_stale` is `True` when `age_days > stale_threshold_days`
- Blame is batched per file (one `git blame --porcelain` per unique file, not one per marker line)
- Module works standalone without Cyclist running
- `--repo` flag resolves named repos from `repos.yaml` via `common/config.py`

## Dependencies

### Depends On

- Nothing -- this is the foundation story for Epic 80 with no prerequisites.

### Depended On By

- **80-2** (@deprecated detection) -- extends `analyze.py` with deprecation scanning and reuses the module infrastructure created here.
- **80-3** (API + React hook + dialog) -- the Express API shells out to `python3 -m pennyfarthing_scripts.codemarkers analyze --format json`, so this module must exist and produce valid JSON output.

## Risks / Open Questions

1. **Grep performance on large repos:** Running `grep -rnE` across a full repo can be slow. The `DEFAULT_EXCLUDES` mitigate this by skipping `node_modules/`, `dist/`, etc. If performance is still an issue, consider using `git grep` instead (which respects `.gitignore` automatically and only searches tracked files). The hotspots module uses `git log` which is inherently scoped to the repo; codemarkers needs to decide between `grep` and `git grep`.

2. **Git blame porcelain parsing complexity:** The `--porcelain` format has a specific structure where each blamed region starts with a 40-char hash + line info, followed by `author`, `author-mail`, `author-time`, etc. The parser must handle boundary commits (initial commit) where author may differ from committer. Test with repos that have uncommitted files (blame fails on untracked files).

3. **Binary file matches:** `grep` may match binary files that contain marker strings. The `DEFAULT_EXCLUDES` handles common cases (`.min.js`, `.map`), but consider adding `--binary-files=without-match` to the grep invocation.

4. **Marker in strings vs comments:** Simple grep cannot distinguish between `TODO` in a comment vs. in a string literal. This is an acceptable trade-off for a diagnostic tool (documented in epic constraints), but may produce false positives. A post-filter heuristic (check if the line contains `//`, `#`, `/*`, `*`, or `<!--` before the marker) could reduce noise.

5. **`DeprecationMarker` model scope:** This story creates the `DeprecationMarker` dataclass in `models.py` but does not populate it -- that is 80-2's responsibility. The model should be included now so 80-2 only needs to extend `analyze.py`, not modify `models.py`.
