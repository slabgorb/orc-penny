# Story Context: 80-2 - @deprecated detection and caller cross-reference

## Summary

Extends the `pennyfarthing_scripts/codemarkers/analyze.py` module (created in 80-1) to detect `@deprecated` JSDoc tags in TypeScript and JavaScript files. For each deprecated symbol, identifies the function/class/const name from the declaration following the JSDoc block, then cross-references callers by grepping the codebase for imports and references. Populates the `DeprecationMarker` model (defined in 80-1's `models.py`) with symbol name, file, caller count, and caller file paths.

## Current State

### Module infrastructure from 80-1

After 80-1 completes, `pennyfarthing_scripts/codemarkers/` will exist with:

- **`models.py`** -- `DeprecationMarker` dataclass already defined with fields: `path`, `line`, `symbol`, `text`, `caller_count`, `callers` (list of file paths)
- **`analyze.py`** -- `analyze_repo()` function that returns `CodeMarkersResult`, which has a `deprecations: list[DeprecationMarker]` field (default empty list) and a `summary.total_deprecations` / `summary.deprecations_with_callers` field (default 0)
- **`cli.py`** -- Click group with `analyze` command that dispatches to `analyze_repo()`
- **`formatters.py`** -- JSON/table/CSV formatters that serialize the result including the (currently empty) `deprecations` list

### No @deprecated scanning exists

The codebase has no existing `@deprecated` detection logic. This is new functionality that extends the codemarkers engine.

### Grep-based approach (not AST)

Per the epic constraints: "@deprecated caller detection uses simple grep, not full AST analysis -- acceptable for a diagnostic tool." This means:

1. Find `@deprecated` in JSDoc comments via regex
2. Extract symbol name from the next function/class/const declaration line
3. Find callers via `grep` for import/usage of that symbol name
4. Count unique files

### Reference patterns in hotspots

The hotspots module does not have a direct equivalent for cross-referencing, but its `_run_git_command()` async subprocess pattern (at `pennyfarthing_scripts/hotspots/analyze.py` lines 50-72) is reused by 80-1 in codemarkers `analyze.py` and this story extends that same file.

## Target State

After implementation:

1. `analyze.py` has a new `_scan_deprecations()` async function that finds `@deprecated` JSDoc tags in `.ts`, `.tsx`, `.js` files
2. `analyze.py` has a new `_find_callers()` async function that greps for imports/references of a deprecated symbol
3. `analyze_repo()` populates `CodeMarkersResult.deprecations` with `DeprecationMarker` instances
4. `analyze_repo()` populates `CodeMarkersResult.summary.total_deprecations` and `summary.deprecations_with_callers`
5. `cli.py` has a new `deprecated` command that shows only deprecation results
6. `formatters.py` has a `format_deprecation_table()` function for table output

Running `python3 -m pennyfarthing_scripts.codemarkers analyze --path . --format json` returns JSON with populated `deprecations` array and updated summary counts.

## Key Files

### Files to Modify

| File | Location | What Changes |
|------|----------|--------------|
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/codemarkers/analyze.py` | Add `_scan_deprecations()` and `_find_callers()` functions; call them from `analyze_repo()` before building the result |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/codemarkers/cli.py` | Add `deprecated` command to the Click group |
| `formatters.py` | `pennyfarthing/pennyfarthing_scripts/codemarkers/formatters.py` | Add `format_deprecation_table()` for table output of deprecation results |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `models.py` | `pennyfarthing/pennyfarthing_scripts/codemarkers/models.py` | `DeprecationMarker` dataclass definition -- fields to populate |
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/codemarkers/analyze.py` | Existing `analyze_repo()` signature, `_run_git_command()` helper, `DEFAULT_EXCLUDES` -- all to be extended |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/codemarkers/cli.py` | Existing Click group and `_common_options` decorator to add the `deprecated` command |
| `formatters.py` | `pennyfarthing/pennyfarthing_scripts/codemarkers/formatters.py` | Existing formatter patterns to follow for `format_deprecation_table()` |
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` | `_run_git_command()` async pattern (lines 50-72) for reference |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/cli.py` | `_output_result()` mode dispatch pattern (lines 82-128) for adding "deprecated" mode |

## Technical Approach

### 1. Add `_scan_deprecations()` to `analyze.py`

Scan `.ts`, `.tsx`, and `.js` files for `@deprecated` JSDoc annotations. Use regex to find JSDoc comment blocks containing `@deprecated`, then extract the symbol name from the next declaration line.

```python
import re
from pathlib import Path

DEPRECATED_PATTERN = re.compile(
    r"/\*\*[\s\S]*?@deprecated\s*(.*?)(?:\*/|\n\s*\*)",
    re.MULTILINE,
)

DECLARATION_PATTERN = re.compile(
    r"^\s*(?:export\s+)?(?:default\s+)?(?:async\s+)?"
    r"(?:function|class|const|let|var|interface|type|enum)\s+"
    r"(\w+)",
)

TS_EXTENSIONS = {".ts", ".tsx", ".js", ".jsx"}


async def _scan_deprecations(
    repo_path: Path, excludes: list[str]
) -> list[DeprecationMarker]:
    """Scan TypeScript/JS files for @deprecated JSDoc tags."""
    deprecations = []

    for ext in TS_EXTENSIONS:
        for file_path in repo_path.rglob(f"*{ext}"):
            rel_path = str(file_path.relative_to(repo_path))
            if _should_exclude(rel_path, excludes):
                continue

            content = file_path.read_text(errors="replace")
            lines = content.split("\n")

            for i, line in enumerate(lines):
                if "@deprecated" not in line:
                    continue

                # Extract deprecation text
                dep_text = line.strip().lstrip("* ").strip()

                # Look forward for the declaration that follows the JSDoc block
                symbol = ""
                for j in range(i + 1, min(i + 10, len(lines))):
                    match = DECLARATION_PATTERN.match(lines[j])
                    if match:
                        symbol = match.group(1)
                        break
                    # Stop if we hit another JSDoc or code without declaration
                    stripped = lines[j].strip()
                    if stripped and not stripped.startswith("*") and not stripped.startswith("*/"):
                        break

                if symbol:
                    deprecations.append(DeprecationMarker(
                        path=rel_path,
                        line=i + 1,
                        symbol=symbol,
                        text=dep_text,
                    ))

    return deprecations
```

### 2. Add `_find_callers()` to `analyze.py`

For each deprecated symbol, grep the codebase for files that import or reference it. Use `grep -rl` for efficiency (file names only), then filter out the file that defines the deprecated symbol itself.

```python
async def _find_callers(
    repo_path: Path,
    symbol: str,
    defining_file: str,
    excludes: list[str],
) -> list[str]:
    """Find files that import or reference a deprecated symbol."""
    exclude_args = []
    for pattern in excludes:
        exclude_args.extend(["--exclude", pattern])
        exclude_args.extend(["--exclude-dir", pattern.rstrip("/*")])

    # Search for import/usage of the symbol
    proc = await asyncio.create_subprocess_exec(
        "grep", "-rl", "--include=*.ts", "--include=*.tsx",
        "--include=*.js", "--include=*.jsx",
        *exclude_args,
        symbol,
        str(repo_path),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, _ = await proc.communicate()

    callers = []
    for line in stdout.decode("utf-8", errors="replace").strip().split("\n"):
        if not line:
            continue
        rel_path = str(Path(line).relative_to(repo_path))
        # Exclude the defining file itself
        if rel_path != defining_file:
            callers.append(rel_path)

    return callers
```

### 3. Integrate into `analyze_repo()`

After the existing marker grep + blame logic, call `_scan_deprecations()` and then `_find_callers()` for each deprecation. Update the summary counts.

```python
async def analyze_repo(name, path, days=90, excludes=None):
    # ... existing marker logic from 80-1 ...

    # Deprecation scanning
    all_excludes = DEFAULT_EXCLUDES + (excludes or [])
    deprecations = await _scan_deprecations(resolved, all_excludes)

    for dep in deprecations:
        callers = await _find_callers(resolved, dep.symbol, dep.path, all_excludes)
        dep.caller_count = len(callers)
        dep.callers = callers

    # Update summary
    summary.total_deprecations = len(deprecations)
    summary.deprecations_with_callers = sum(1 for d in deprecations if d.caller_count > 0)

    return CodeMarkersResult(
        # ... existing fields ...
        deprecations=deprecations,
        summary=summary,
    )
```

### 4. Add `deprecated` command to `cli.py`

New Click command that filters output to deprecation results only.

```python
@codemarkers.command()
@_common_options
def deprecated(repo, repo_path, days, top, fmt, output_file, exclude):
    """Show @deprecated symbols and their active callers."""
    result = _run_analysis(repo, repo_path, days, exclude)
    _output_result(result, fmt, output_file, top, "deprecated")
```

### 5. Add `format_deprecation_table()` to `formatters.py`

Table format for deprecation results with columns: Symbol, File, Line, Callers, Text.

```python
def format_deprecation_table(deprecations: list[DeprecationMarker], top_n: int = 20) -> str:
    """Format deprecation markers as a column-aligned table."""
    if not deprecations:
        return "  No @deprecated symbols found."

    items = deprecations[:top_n]
    hdr = f"{'Symbol':<30}  {'File':<40}  {'Line':>5}  {'Callers':>8}  Text"
    sep = f"{'-'*30}  {'-'*40}  {'-----':>5}  {'--------':>8}  ----"

    lines = [hdr, sep]
    for d in items:
        lines.append(
            f"{d.symbol:<30}  {d.path:<40}  {d.line:>5}  {d.caller_count:>8}  {d.text[:50]}"
        )
    return "\n".join(lines)
```

Update `_output_result()` to handle the `"deprecated"` mode by calling `format_deprecation_table()`.

## Acceptance Criteria

- `@deprecated` JSDoc tags in `.ts`, `.tsx`, `.js` files are detected and returned in `CodeMarkersResult.deprecations`
- Each `DeprecationMarker` has the correct `symbol` name extracted from the declaration following the JSDoc block
- `caller_count` reflects the number of unique files that import or reference the deprecated symbol (excluding the defining file)
- `callers` list contains relative file paths of files referencing the deprecated symbol
- `python3 -m pennyfarthing_scripts.codemarkers deprecated --path <repo>` shows only deprecation results
- `python3 -m pennyfarthing_scripts.codemarkers analyze --path <repo> --format json` includes both `markers` and `deprecations` arrays
- `summary.total_deprecations` and `summary.deprecations_with_callers` are correctly computed
- `DEFAULT_EXCLUDES` are respected during deprecation scanning (no results from `node_modules/`, `dist/`, etc.)
- Table, JSON, and CSV output all include deprecation data

## Dependencies

### Depends On

- **80-1** (Python codemarkers module) -- this story extends `analyze.py`, `cli.py`, and `formatters.py` created by 80-1. It also relies on the `DeprecationMarker` and `CodeMarkersResult` models defined in 80-1's `models.py`.

### Depended On By

- **80-3** (API + React hook + dialog) -- the Cyclist frontend displays deprecation data in the "Deprecated" tab of the CodeMarkersDialog. The Express API passes through the `deprecations` array from the Python JSON output, so this story must populate that array correctly.

## Risks / Open Questions

1. **Symbol name extraction accuracy:** The regex-based approach to extract the symbol name from the declaration following a JSDoc block is heuristic. It handles common patterns (`export function foo`, `export class Bar`, `export const baz`), but may miss complex patterns like `export default function`, destructured exports, or re-exports. The JSDoc `@deprecated` tag could also be on a method inside a class body rather than at the top-level declaration. Consider limiting scope to top-level exports for the first iteration.

2. **Caller detection false positives:** Grepping for a symbol name by string match can produce false positives when the symbol name is a common word (e.g., `get`, `set`, `data`). Since this is a diagnostic tool (not a refactoring tool), false positives are acceptable but should be documented. A refinement could check for import statements specifically (`import { symbol }` or `from '...' import symbol`).

3. **Performance with many deprecations:** Each deprecated symbol triggers a separate `grep -rl` across the codebase. If a repo has many deprecated symbols (>50), this could be slow. Consider batching: run a single grep for all deprecated symbol names and post-filter, or run caller searches concurrently with `asyncio.gather()`.

4. **Multi-line JSDoc comments:** The `@deprecated` tag may appear anywhere within a multi-line JSDoc block. The line-by-line scan in `_scan_deprecations()` handles this by checking each line for `@deprecated`. However, the deprecation text may span multiple lines (`@deprecated Use newHelper instead\n * of oldHelper`). The current approach captures only the text on the `@deprecated` line itself.

5. **Overlap with marker grep:** A comment like `// TODO: remove this @deprecated function` would be caught by both the marker grep (as a TODO) and the deprecation scanner. This is acceptable -- they represent different concerns (a TODO about removing it vs. the deprecation status itself). The UI (80-3) presents them in separate tabs.
