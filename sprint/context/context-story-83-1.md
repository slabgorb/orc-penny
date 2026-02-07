# Story Context: 83-1 - Python complexity module

## Summary

Create a new `pennyfarthing_scripts/complexity/` module that performs static analysis of TypeScript/JavaScript files to extract per-file complexity metrics. The module wraps `eslint --format json` with a complexity rule override (or uses `escomplex` as a subprocess fallback), producing per-file metrics: longest function, average cyclomatic complexity, max nesting depth, total lines, and function count. Follows the same 6-file module structure established by the hotspots module (ADR-0008 result pattern, Click CLI, table/json/csv formatters).

## Current State

### No complexity module exists

The `pennyfarthing_scripts/` directory has no complexity analysis capability. The existing modules are: `hotspots/`, `brownfield/`, `preflight/`, `sprint/`, `story/`, `jira/`, `git/`, `prime/`, `hooks/`, `common/`, `migration/`, and several standalone scripts.

### ESLint is available

ESLint `^9.39.2` is a devDependency of the monorepo (`pennyfarthing/package.json` line 51). The flat config at `pennyfarthing/eslint.config.mjs` uses `typescript-eslint` (line 2) with `tseslint.configs.recommended` (line 7). The config ignores `**/*.js`, `**/dist/**`, `**/node_modules/**` (lines 34-41). The `complexity` rule is not currently enabled (it defaults to off in eslint:recommended).

### Hotspots module (reference pattern)

The module to replicate structurally is `pennyfarthing_scripts/hotspots/` with these files:

| File | Lines | Key patterns |
|------|-------|--------------|
| `analyze.py` | 472 | `asyncio.create_subprocess_exec` at line 60, `_run_git_command()` helper (lines 50-72), result aggregation into dataclass models |
| `models.py` | 61 | `@dataclass` classes with ADR-0008 pattern: `success: bool`, typed fields, `error: str | None = None` |
| `cli.py` | 153 | Click group at line 18, `_common_options` decorator (lines 31-41), `asyncio.run()` bridge at line 54, `_output_result()` at line 82 |
| `formatters.py` | 109 | `format_file_table()` (line 26), `export_json()` using `dataclasses.asdict()` (line 77), `export_csv()` (line 82) |
| `__init__.py` | 31 | Public API re-exports with `__all__` |
| `__main__.py` | 6 | Module entry point: `from .cli import hotspots; hotspots()` |

### Common utilities

- `pennyfarthing_scripts/common/config.py` (92 lines): `get_project_root()` (line 14) walks up looking for `pennyfarthing-dist/` or `.pennyfarthing/`, respects `PROJECT_ROOT` and `CLAUDE_PROJECT_DIR` env vars
- `pennyfarthing_scripts/common/output.py` (181 lines): `header()`, `info()`, `warn()`, `error()` functions with ANSI coloring, used by formatters

## Target State

After implementation, a new module at `pennyfarthing_scripts/complexity/` with 6 files:

```
pennyfarthing_scripts/complexity/
  __init__.py        # Public API re-exports
  __main__.py        # python -m pennyfarthing_scripts.complexity
  analyze.py         # async subprocess: eslint --format json with complexity rule
  models.py          # FileComplexity, ComplexityResult dataclasses
  cli.py             # Click CLI: complexity analyze [OPTIONS]
  formatters.py      # table/json/csv output
```

Running `python3 -m pennyfarthing_scripts.complexity analyze --path /some/dir --format json` produces:

```json
{
  "success": true,
  "target_path": "/some/dir",
  "file_count": 42,
  "files": [
    {
      "path": "src/server.ts",
      "total_lines": 506,
      "longest_function": 85,
      "avg_cyclomatic_complexity": 4.2,
      "max_nesting_depth": 5,
      "function_count": 18
    }
  ],
  "error": null
}
```

## Key Files

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `__init__.py` | `pennyfarthing/pennyfarthing_scripts/complexity/__init__.py` | Public API: re-export `FileComplexity`, `ComplexityResult`, `analyze_complexity` |
| `__main__.py` | `pennyfarthing/pennyfarthing_scripts/complexity/__main__.py` | Module entry: `from .cli import complexity; complexity()` |
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/complexity/analyze.py` | Core analysis: run eslint subprocess, parse JSON output, compute per-file metrics |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/complexity/models.py` | Dataclasses: `FileComplexity`, `ComplexityResult` |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/complexity/cli.py` | Click CLI: `complexity analyze --path --format --top --output` |
| `formatters.py` | `pennyfarthing/pennyfarthing_scripts/complexity/formatters.py` | Table, JSON, CSV formatters |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` | Async subprocess pattern (`create_subprocess_exec` line 60), result aggregation |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/models.py` | ADR-0008 dataclass pattern |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/cli.py` | Click CLI structure, `_common_options` decorator (lines 31-41) |
| `formatters.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/formatters.py` | Table/JSON/CSV formatting, `export_json()` via `asdict()` (line 77) |
| `__init__.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/__init__.py` | `__all__` export pattern |
| `__main__.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/__main__.py` | Module entry pattern |
| `config.py` | `pennyfarthing/pennyfarthing_scripts/common/config.py` | `get_project_root()` (line 14) for finding project directory |
| `output.py` | `pennyfarthing/pennyfarthing_scripts/common/output.py` | `header()`, `info()` for table formatter output |
| `eslint.config.mjs` | `pennyfarthing/eslint.config.mjs` | Existing flat config -- understand what rules are active |
| `package.json` | `pennyfarthing/package.json` | ESLint version (`^9.39.2`, line 51), lint script (line 37) |

## Technical Approach

### 1. Create `models.py`

Follow the `hotspots/models.py` pattern. Two dataclasses:

```python
from dataclasses import dataclass, field

@dataclass
class FileComplexity:
    """Complexity metrics for a single file."""
    path: str
    total_lines: int = 0
    longest_function: int = 0
    avg_cyclomatic_complexity: float = 0.0
    max_nesting_depth: int = 0
    function_count: int = 0

@dataclass
class ComplexityResult:
    """Analysis result following ADR-0008 pattern."""
    success: bool
    target_path: str = ""
    file_count: int = 0
    files: list[FileComplexity] = field(default_factory=list)
    error: str | None = None
```

### 2. Create `analyze.py`

Core analysis function using `asyncio.create_subprocess_exec` (same pattern as `hotspots/analyze.py` line 60).

**ESLint approach:** Run eslint with complexity rule enabled via `--rule` flag and `--format json` output. ESLint 9 with flat config uses `--no-config-lookup` to ignore the project's config and `--rule 'complexity: ["warn", 5]'` to report functions exceeding threshold.

```python
async def _run_eslint(target_path: Path) -> tuple[str, str, int]:
    """Run eslint --format json with complexity rule enabled."""
    eslint_bin = _find_eslint(target_path)
    if not eslint_bin:
        return "", "eslint not found", 1

    proc = await asyncio.create_subprocess_exec(
        str(eslint_bin),
        str(target_path),
        "--format", "json",
        "--no-config-lookup",
        "--rule", "complexity: [\"warn\", 1]",  # Report all functions
        "--ext", ".ts,.tsx,.js,.jsx",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    return stdout.decode(), stderr.decode(), proc.returncode or 0
```

**Finding eslint:** Look for `node_modules/.bin/eslint` relative to the target path or project root, similar to how `hotspots/analyze.py` uses `get_project_root()` from `common/config.py` (line 47 of `cli.py`).

**Parsing eslint JSON output:** ESLint JSON format returns an array of file results, each with `messages` containing rule violations. Count complexity rule violations per file to derive average cyclomatic complexity. For nesting depth and function length, eslint's `complexity` rule only reports the complexity value -- additional parsing of the source or use of `max-depth` and `max-lines-per-function` rules can supplement.

**Alternative: multi-rule approach:**
```python
"--rule", "complexity: [\"warn\", 1]",           # All functions reported
"--rule", "max-depth: [\"warn\", 1]",             # Nesting depth
"--rule", "max-lines-per-function: [\"warn\", 1]", # Function length
```

Each eslint message includes `ruleId`, `message` (with the value), and `line`/`column`. Parse message text to extract numeric values (e.g., "Function 'foo' has a complexity of 12." yields 12).

**Line count:** Use `wc -l` or read file to count total lines per file. ESLint doesn't report total lines, so supplement with a file stat or subprocess.

```python
async def analyze_complexity(
    target_path: Path,
    excludes: list[str] | None = None,
) -> ComplexityResult:
    """Analyze complexity of files in the target directory."""
```

### 3. Create `cli.py`

Follow `hotspots/cli.py` pattern with Click group and `_common_options` decorator:

```python
@click.group()
def complexity():
    """Code complexity analysis."""
    pass

def _common_options(fn):
    """Shared options for complexity commands."""
    fn = click.option("--path", "target_path", type=click.Path(exists=True),
                       help="Directory to analyze")(fn)
    fn = click.option("--format", "fmt", type=click.Choice(["table", "json", "csv"]),
                       default="table", show_default=True)(fn)
    fn = click.option("--top", default=20, show_default=True,
                       help="Number of top results")(fn)
    fn = click.option("--output", "output_file", type=click.Path(),
                       help="Write output to file")(fn)
    fn = click.option("--exclude", multiple=True,
                       help="Exclude patterns (repeatable)")(fn)
    return fn

@complexity.command()
@_common_options
def analyze(target_path, fmt, top, output_file, exclude):
    """Analyze code complexity."""
    result = asyncio.run(analyze_complexity(Path(target_path or ".").resolve()))
    _output_result(result, fmt, output_file, top)
```

### 4. Create `formatters.py`

Follow `hotspots/formatters.py` pattern:

```python
def format_file_table(files: list[FileComplexity], top_n: int = 20) -> str:
    """Format complexity results as column-aligned table."""
    # Columns: Complexity | Longest Fn | Nesting | Functions | Lines | File
    ...

def export_json(result: ComplexityResult) -> str:
    """Serialize result to JSON."""
    return json.dumps(asdict(result), indent=2, default=str)

def export_csv(files: list[FileComplexity]) -> str:
    """Export as CSV."""
    ...
```

### 5. Create `__init__.py` and `__main__.py`

Direct copies of the hotspots pattern:

```python
# __init__.py
from pennyfarthing_scripts.complexity.models import FileComplexity, ComplexityResult
from pennyfarthing_scripts.complexity.analyze import analyze_complexity
__all__ = ["FileComplexity", "ComplexityResult", "analyze_complexity"]

# __main__.py
from pennyfarthing_scripts.complexity.cli import complexity
if __name__ == "__main__":
    complexity()
```

### 6. Handle edge cases

- **eslint not found:** Return `ComplexityResult(success=False, error="eslint not found. Install with: npm install -D eslint")`. Check `node_modules/.bin/eslint` relative to target path, then walk up directories.
- **No .ts/.tsx files:** Return success with empty files list.
- **eslint exit code non-zero:** ESLint returns exit code 1 when it finds lint warnings/errors -- this is expected since we're intentionally setting low thresholds. Parse stdout regardless of exit code (same pattern as how story 83-2 handles `npm outdated` exit code 1).
- **Timeout:** Use 30-second timeout on `asyncio.wait_for()` wrapping the subprocess.

## Acceptance Criteria

- Module runnable as `python3 -m pennyfarthing_scripts.complexity analyze --path <dir> --format json`
- Models use `@dataclass` with ADR-0008 `{success, ..., error}` pattern
- Per-file metrics include: `path`, `total_lines`, `longest_function`, `avg_cyclomatic_complexity`, `max_nesting_depth`, `function_count`
- CLI supports `--format table|json|csv`, `--top N`, `--output <file>`, `--exclude <pattern>`
- Graceful error when eslint is not installed (returns `{success: false, error: "..."}`)
- JSON output matches the API contract defined in `context-epic-83.md`
- Table formatter produces readable column-aligned output
- No new npm dependencies required (uses existing eslint)

## Dependencies

### Depends On

- **ESLint** (`eslint@^9.39.2`) already installed as devDependency in `pennyfarthing/package.json` (line 51)
- **pennyfarthing_scripts/common/** for `get_project_root()` (config.py line 14) and output utilities (output.py)
- **Click** (already used by hotspots/cli.py and other modules)

### Depended On By

- **Story 83-3** (APIs + hooks + dialogs) -- Express API calls this module via `python3 -m pennyfarthing_scripts.complexity analyze --format json`

## Risks / Open Questions

1. **ESLint 9 flat config vs --no-config-lookup:** ESLint 9 uses flat config (`eslint.config.mjs`). The `--no-config-lookup` flag prevents loading the project's config so we can inject our own rules. Verify this flag works correctly with ESLint 9's flat config system. If it doesn't, an alternative is to pass a temporary config file path via `--config`.

2. **Extracting all metrics from eslint alone:** The `complexity` rule reports cyclomatic complexity per function. The `max-depth` rule reports nesting depth. The `max-lines-per-function` rule reports function length. However, extracting exact numeric values requires parsing the message text (e.g., "Arrow function has a complexity of 12."). These message formats may change between eslint versions. Consider using regex patterns with fallback.

3. **Performance on large codebases:** Running eslint across an entire monorepo's TypeScript files could be slow. The Express API layer (story 83-3) uses a 30-second timeout. Consider defaulting to analyzing only the `src/` subdirectory or supporting glob patterns to limit scope.

4. **escomplex as fallback:** If eslint proves insufficient for extracting all desired metrics, `escomplex` (a standalone complexity analysis tool) could be used as a subprocess. It produces richer output but requires separate installation (`npx escomplex`). For v1, prefer eslint since it's already installed; consider escomplex as a future enhancement.

5. **File line counting:** ESLint JSON output doesn't include total line count per file. Supplementing with file reads adds overhead. Consider using a fast approach: `wc -l` on each file path returned by eslint, or read file bytes and count newlines in Python.
