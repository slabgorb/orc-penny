# Story Context: 81-1 - Python deadcode module: stale file detection

## Summary

Create the `pennyfarthing_scripts/deadcode/` Python module implementing Layer 1 of the dead code detection system: git-based stale file detection. The module mirrors the existing `hotspots/` structure (`analyze.py`, `models.py`, `cli.py`, `formatters.py`, `__init__.py`, `__main__.py`) and uses `git ls-files` to get all tracked files, then `git log --name-only --since=N days ago` to find recently changed files, then computes the set difference to identify stale files. Each stale file is enriched with `last_commit_date` (via `git log -1 --format=%aI`) and `size_bytes` (via `Path.stat()`).

## Current State

### No deadcode module exists

The `pennyfarthing_scripts/` package has no `deadcode/` directory. The hotspots module at `pennyfarthing/pennyfarthing_scripts/hotspots/` provides the proven pattern to follow:

- **`analyze.py`** (473 lines) — `_run_git_command()` at line 50 wraps `asyncio.create_subprocess_exec` for async git calls; `analyze_repo()` at line 260 runs analysis on a single repo; `analyze_all_repos()` at line 420 discovers repos via `repos.yaml` and runs in parallel with `asyncio.gather`; `DEFAULT_EXCLUDES` at line 32 filters out `node_modules/*`, `dist/*`, `*.lock`, etc.; `_should_exclude()` at line 201 matches paths against exclusion patterns using `fnmatch`.
- **`models.py`** (61 lines) — `@dataclass` classes following ADR-0008 result pattern: `FileHotspot` (line 14), `DirectoryHotspot` (line 29), `HotspotResult` (line 41, with `success`, `error` fields), `MultiRepoHotspotResult` (line 55).
- **`cli.py`** (153 lines) — `@click.group()` at line 18; `_common_options()` decorator at line 31 with `--repo`, `--path`, `--days`, `--top`, `--format`, `--output`, `--exclude`, `--branch`; `_run_analysis()` at line 44 handles single-repo vs all-repos dispatch; `_output_result()` at line 82 routes to formatters.
- **`formatters.py`** (109 lines) — `format_file_table()` at line 26, `format_summary()` at line 67, `export_json()` at line 77 using `dataclasses.asdict`, `export_csv()` at line 82.
- **`__init__.py`** (31 lines) — re-exports models and public functions with `__all__`.
- **`__main__.py`** (6 lines) — `from pennyfarthing_scripts.hotspots.cli import hotspots; hotspots()`.

### CLI registration

The main CLI at `pennyfarthing/pennyfarthing_scripts/cli.py` registers the hotspots group at line 39-41:
```python
from pennyfarthing_scripts.hotspots.cli import hotspots
cli.add_command(hotspots)
```

### Shared utilities

- **`common/config.py`** — `get_project_root()` at line 14 finds the project root via `PROJECT_ROOT`/`CLAUDE_PROJECT_DIR` env vars or marker walk-up; `load_yaml_config()` at line 68 loads YAML with graceful fallback.
- **`common/output.py`** — `header()`, `info()`, `warn()`, `error()` for colored terminal output; used by `hotspots/formatters.py` line 17.

## Target State

After implementation:

1. **`pennyfarthing_scripts/deadcode/`** directory exists with 6 files: `__init__.py`, `__main__.py`, `models.py`, `analyze.py`, `cli.py`, `formatters.py`
2. **`models.py`** defines `StaleFile` (path, last_commit_date, days_since_last_commit, size_bytes), `DeadCodeResult` (success, repo_name, repo_path, time_window_days, stale_files, stale_file_count, error), and `MultiRepoDeadCodeResult`
3. **`analyze.py`** implements `find_stale_files()` using async git subprocess pattern, with `get_all_tracked_files()`, `get_recently_changed_files()`, and per-file enrichment
4. **`cli.py`** provides `deadcode` Click group with `stale` subcommand and shared options
5. **`formatters.py`** supports table, JSON, and CSV output for stale files
6. **`cli.py`** registered in `pennyfarthing_scripts/cli.py` alongside `hotspots`
7. **`python -m pennyfarthing_scripts.deadcode stale --format json --days 180`** works end-to-end

## Key Files

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `models.py` | `pennyfarthing/pennyfarthing_scripts/deadcode/models.py` | `StaleFile`, `DeadCodeResult`, `MultiRepoDeadCodeResult` dataclasses |
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/deadcode/analyze.py` | Core engine: `_run_git_command()`, `get_all_tracked_files()`, `get_recently_changed_files()`, `find_stale_files()`, `analyze_all_repos()` |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/deadcode/cli.py` | Click group with `stale` subcommand, `_common_options()` decorator |
| `formatters.py` | `pennyfarthing/pennyfarthing_scripts/deadcode/formatters.py` | `format_stale_table()`, `format_summary()`, `export_json()`, `export_csv()` |
| `__init__.py` | `pennyfarthing/pennyfarthing_scripts/deadcode/__init__.py` | Public API re-exports with `__all__` |
| `__main__.py` | `pennyfarthing/pennyfarthing_scripts/deadcode/__main__.py` | Module entry: `python -m pennyfarthing_scripts.deadcode` |

### Files to Modify

| File | Location | What Changes |
|------|----------|--------------|
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/cli.py` | Add `from pennyfarthing_scripts.deadcode.cli import deadcode; cli.add_command(deadcode)` after line 41 |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` | `_run_git_command()` pattern (line 50), `DEFAULT_EXCLUDES` (line 32), `_should_exclude()` (line 201), `analyze_repo()` (line 260), `analyze_all_repos()` (line 420) |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/models.py` | ADR-0008 dataclass pattern (lines 13-61) |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/cli.py` | `_common_options()` (line 31), `_run_analysis()` (line 44), `_output_result()` (line 82) |
| `formatters.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/formatters.py` | Table/JSON/CSV output patterns |
| `__init__.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/__init__.py` | `__all__` re-export pattern |
| `config.py` | `pennyfarthing/pennyfarthing_scripts/common/config.py` | `get_project_root()` (line 14), `load_yaml_config()` (line 68) |
| `output.py` | `pennyfarthing/pennyfarthing_scripts/common/output.py` | `header()` (line 131), `info()` (line 87) for formatter output |

## Technical Approach

### 1. Create `models.py`

Define dataclasses mirroring the hotspots pattern. The `UnusedExport` model is also defined here (shared with Story 81-2) but only `StaleFile` is populated in this story.

```python
from dataclasses import dataclass, field

@dataclass
class StaleFile:
    """A tracked file with no commits in the analysis window."""
    path: str
    last_commit_date: str       # ISO 8601 from git log -1 --format=%aI
    days_since_last_commit: int
    size_bytes: int = 0

@dataclass
class UnusedExport:
    """A TypeScript export with no importers (populated by Story 81-2)."""
    path: str
    export_name: str
    line_number: int = 0

@dataclass
class DeadCodeResult:
    """Analysis result for a single repository."""
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
    """Analysis result spanning multiple repositories."""
    success: bool
    repo_results: list[DeadCodeResult] = field(default_factory=list)
    error: str | None = None
```

### 2. Create `analyze.py`

Reuse the `_run_git_command()` async subprocess pattern from `hotspots/analyze.py` line 50. Implement three core functions:

```python
async def get_all_tracked_files(repo_path: Path) -> set[str]:
    """Get all files tracked by git via 'git ls-files'."""
    stdout, stderr, rc = await _run_git_command(["ls-files"], repo_path)
    if rc != 0:
        raise RuntimeError(f"git ls-files failed: {stderr}")
    return set(stdout.splitlines()) if stdout else set()

async def get_recently_changed_files(repo_path: Path, days: int, branch: str = "--all") -> set[str]:
    """Get files with commits in the last N days via 'git log --name-only'."""
    stdout, stderr, rc = await _run_git_command(
        ["log", f"--since={days} days ago", branch, "--name-only", "--pretty=format:"],
        repo_path,
    )
    if rc != 0:
        raise RuntimeError(f"git log failed: {stderr}")
    return set(line for line in stdout.splitlines() if line.strip())

async def find_stale_files(
    name: str, path: Path, days: int = 180,
    excludes: list[str] | None = None, branch: str = "--all",
) -> DeadCodeResult:
    """Find tracked files with no commits in the time window."""
    all_files = await get_all_tracked_files(path)
    recent_files = await get_recently_changed_files(path, days, branch)
    stale_paths = all_files - recent_files
    # Filter exclusions, then enrich each file with last_commit_date and size_bytes
```

**Enrichment** must batch `git log -1 --format=%aI -- <file>` calls to stay within the 30-second API timeout. Use `asyncio.gather` with a semaphore (e.g., 20 concurrent) for parallelism:

```python
async def _enrich_stale_file(repo_path: Path, file_path: str) -> StaleFile:
    """Get last commit date and file size for a single stale file."""
    stdout, _, _ = await _run_git_command(
        ["log", "-1", "--format=%aI", "--", file_path], repo_path
    )
    last_date = stdout.strip() if stdout.strip() else "unknown"
    # Compute days since last commit from ISO date
    # Get file size via Path.stat()
```

**`DEFAULT_EXCLUDES`** — reuse the same list from `hotspots/analyze.py` line 32 (node_modules, dist, build, lock files, minified files). Reuse `_should_exclude()` pattern from line 201.

**`analyze_all_repos()`** — mirror `hotspots/analyze.py` line 420, discover repos via `repos.yaml` using `load_yaml_config()` from `common/config.py` line 68, gather results with `asyncio.gather`.

### 3. Create `cli.py`

Mirror `hotspots/cli.py`:

```python
@click.group()
def deadcode():
    """Dead code detection — stale files and unused exports."""
    pass

def _common_options(fn):
    """Shared options for all deadcode commands."""
    fn = click.option("--repo", help="Analyze a single named repo")(fn)
    fn = click.option("--path", "repo_path", type=click.Path(exists=True))(fn)
    fn = click.option("--days", default=180, show_default=True)(fn)
    fn = click.option("--top", default=20, show_default=True)(fn)
    fn = click.option("--format", "fmt", type=click.Choice(["table", "json", "csv"]), default="table")(fn)
    fn = click.option("--output", "output_file", type=click.Path())(fn)
    fn = click.option("--exclude", multiple=True)(fn)
    fn = click.option("--branch", default="--all", show_default=True)(fn)
    return fn

@deadcode.command()
@_common_options
def stale(repo, repo_path, days, top, fmt, output_file, exclude, branch):
    """Find files with no commits in the time window."""
    result = _run_analysis(repo, repo_path, days, exclude, branch)
    _output_result(result, fmt, output_file, top)
```

Note: default `--days` is 180 (not 90 like hotspots), since stale file detection uses a longer window.

### 4. Create `formatters.py`

Mirror `hotspots/formatters.py`:

```python
def format_stale_table(stale_files: list[StaleFile], top_n: int = 20) -> str:
    """Format stale files as a column-aligned table."""
    # Columns: Days Stale | Size | Last Commit | File

def export_json(result: DeadCodeResult | MultiRepoDeadCodeResult) -> str:
    return json.dumps(asdict(result), indent=2, default=str)

def export_csv(stale_files: list[StaleFile]) -> str:
    # Columns: path, last_commit_date, days_since_last_commit, size_bytes
```

### 5. Create `__init__.py` and `__main__.py`

```python
# __init__.py
from pennyfarthing_scripts.deadcode.models import (
    StaleFile, UnusedExport, DeadCodeResult, MultiRepoDeadCodeResult,
)
from pennyfarthing_scripts.deadcode.analyze import find_stale_files, analyze_all_repos

__all__ = [
    "StaleFile", "UnusedExport", "DeadCodeResult", "MultiRepoDeadCodeResult",
    "find_stale_files", "analyze_all_repos",
]

# __main__.py
from pennyfarthing_scripts.deadcode.cli import deadcode
if __name__ == "__main__":
    deadcode()
```

### 6. Register in main CLI

Add to `pennyfarthing/pennyfarthing_scripts/cli.py` after line 41:

```python
# Import and register deadcode group
from pennyfarthing_scripts.deadcode.cli import deadcode
cli.add_command(deadcode)
```

## Acceptance Criteria

- `pennyfarthing_scripts/deadcode/` module exists with `__init__.py`, `__main__.py`, `models.py`, `analyze.py`, `cli.py`, `formatters.py`
- `python -m pennyfarthing_scripts.deadcode stale --format json --days 180` outputs valid JSON matching the `DeadCodeResult` schema
- `pf deadcode stale` is registered in the main CLI (accessible via `pennyfarthing_scripts/cli.py`)
- `StaleFile` dataclass includes `path`, `last_commit_date` (ISO 8601), `days_since_last_commit`, `size_bytes`
- `DEFAULT_EXCLUDES` filters out `node_modules/*`, `dist/*`, `build/*`, `*.lock`, `*.min.js`, `*.min.css`, `*.map`, `package-lock.json`, `pnpm-lock.yaml`
- `_should_exclude()` matches paths using `fnmatch` (both full path and basename)
- Stale file enrichment (`git log -1` per file) uses async parallelism with a concurrency semaphore to stay within 30-second timeout
- `--format table` output shows columns: Days Stale, Size, Last Commit, File
- `--format csv` produces valid CSV with header row
- `_run_git_command()` uses `asyncio.create_subprocess_exec` (not synchronous `subprocess.run`)
- `analyze_all_repos()` discovers repos via `repos.yaml` using `load_yaml_config()` from `common/config.py`
- All models follow ADR-0008 `{success, data?, error?}` pattern — no exceptions raised to callers

## Dependencies

### Depends On

- Nothing — this is the first story in Epic 81.

### Depended On By

- **81-2** (Unused export detection via ts-prune) — depends on the module structure, `models.py` (`UnusedExport`, `DeadCodeResult`), and `analyze.py` scaffold to add `find_unused_exports()`.
- **81-3** (Dead code API + React hook + dialog) — depends on the CLI being functional with `--format json` for the Express router to call.

## Risks / Open Questions

1. **Enrichment performance on large repos:** `git log -1 --format=%aI -- <file>` runs once per stale file. In a repo with thousands of stale files, even with async parallelism, this could be slow. Consider a batch approach: `git log --all --name-only --pretty=format:"COMMIT:%aI"` to get all commit dates in one pass, then map files to their last date. This is more complex but O(1) git calls instead of O(n).

2. **Semaphore concurrency limit:** The asyncio semaphore for enrichment parallelism should be tunable. Too high (50+) may overwhelm git; too low (5) may be slow. Defaulting to 20 concurrent git calls seems reasonable.

3. **Files never committed but tracked:** A file could be tracked by `git ls-files` but have no commits (e.g., added to the index but never committed). `git log -1` for such files returns empty. These should be reported as stale with `last_commit_date: "unknown"` and `days_since_last_commit: -1` or similar sentinel.

4. **Binary files in stale list:** Binary files (images, fonts) will appear as stale if not recently changed. The `DEFAULT_EXCLUDES` list does not filter binaries. Should we add `*.png`, `*.jpg`, `*.woff2`, etc., or leave that to the `--exclude` option?

5. **Symlinks:** `git ls-files` may include symlink targets. Should we filter out symlinks from the stale list, or report them as-is?

6. **UnusedExport model placement:** The `UnusedExport` dataclass is defined in this story's `models.py` but not populated until Story 81-2. This is intentional — it avoids a model migration in 81-2 and keeps the `DeadCodeResult` schema stable across both stories.
