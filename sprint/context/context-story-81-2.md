# Story Context: 81-2 - Unused export detection via ts-prune

## Summary

Add Layer 2 of the dead code detection system: unused TypeScript export detection. Install `ts-prune` as a devDependency in the root `package.json`, implement `find_unused_exports()` in `pennyfarthing_scripts/deadcode/analyze.py` to run ts-prune via async subprocess and parse its output into `UnusedExport` model instances, and add `exports` and `all` subcommands to the deadcode CLI. Gracefully degrade when ts-prune is not installed at runtime (empty result with warning, not a crash).

## Current State

### No ts-prune installed

No `ts-prune`, `ts-unused-exports`, `knip`, or `unimported` exists in any `package.json` across the monorepo. The root `package.json` at `pennyfarthing/package.json` has `typescript` in devDependencies (line 52: `"typescript": "^5.3.3"`) but no unused export tooling.

### Deadcode module from Story 81-1

After Story 81-1 completes, `pennyfarthing_scripts/deadcode/` will exist with:
- **`models.py`** — `StaleFile`, `UnusedExport` (defined but not yet populated), `DeadCodeResult` (with `unused_exports` list field and `unused_export_count`), `MultiRepoDeadCodeResult`
- **`analyze.py`** — `_run_git_command()`, `find_stale_files()`, `analyze_all_repos()` (Layer 1 only)
- **`cli.py`** — `deadcode` Click group with `stale` subcommand
- **`formatters.py`** — table/JSON/CSV formatters for stale files only

### Dual tsconfig in Cyclist

Cyclist has two TypeScript configurations (noted in project MEMORY.md):
- `pennyfarthing/packages/cyclist/tsconfig.json` — Node main process (server, Electron)
- `pennyfarthing/packages/cyclist/tsconfig.vite.json` — React frontend (Vite bundled)

ts-prune may need to run against both to get full coverage of unused exports.

### ts-prune output format

ts-prune outputs one line per unused export:
```
src/utils/helpers.ts:42 - formatLegacyDate
src/api/old-endpoint.ts:15 - createLegacyRouter
src/types.ts:8 - OldConfig (used in module)
```

Lines ending with `(used in module)` indicate the export is used within its own file but not imported elsewhere. The format is: `<path>:<line> - <export_name>`.

## Target State

After implementation:

1. **`ts-prune`** installed as a devDependency in `pennyfarthing/package.json`
2. **`analyze.py`** has `find_unused_exports()` and `_parse_ts_prune_output()` functions
3. **`cli.py`** has `exports` subcommand (Layer 2 only) and `all` subcommand (both layers)
4. **`formatters.py`** has `format_exports_table()` and updated `export_csv()` for unused exports
5. **Graceful degradation:** if `ts-prune` binary is not found at runtime, `find_unused_exports()` returns a `DeadCodeResult` with empty `unused_exports` and `error` field set to a warning message
6. **`python -m pennyfarthing_scripts.deadcode exports --format json --tsconfig packages/cyclist/tsconfig.json`** works end-to-end
7. **`python -m pennyfarthing_scripts.deadcode all --format json --days 180`** runs both layers and merges results

## Key Files

### Files to Modify

| File | Location | What Changes |
|------|----------|--------------|
| `package.json` | `pennyfarthing/package.json` | Add `"ts-prune": "^0.10.3"` to `devDependencies` (after line 53) |
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/deadcode/analyze.py` | Add `find_unused_exports()`, `_parse_ts_prune_output()`, `analyze_repo()` (combined), `analyze_all_repos()` (updated to support layers) |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/deadcode/cli.py` | Add `exports` subcommand with `--tsconfig` option, add `all` subcommand, update `_common_options()` |
| `formatters.py` | `pennyfarthing/pennyfarthing_scripts/deadcode/formatters.py` | Add `format_exports_table()`, update `export_csv()` to handle `UnusedExport`, update `format_summary()` for combined results |
| `__init__.py` | `pennyfarthing/pennyfarthing_scripts/deadcode/__init__.py` | Add `find_unused_exports` to `__all__` and imports |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` | `_run_git_command()` async pattern (line 50) to reuse for `asyncio.create_subprocess_exec` of `npx ts-prune` |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/deadcode/models.py` | `UnusedExport` dataclass (defined in 81-1) to populate |
| `package.json` | `pennyfarthing/package.json` | Current devDependencies (lines 48-54) to add ts-prune |
| `tsconfig.json` | `pennyfarthing/packages/cyclist/tsconfig.json` | Node tsconfig — one of two targets for ts-prune |
| `tsconfig.vite.json` | `pennyfarthing/packages/cyclist/tsconfig.vite.json` | Vite tsconfig — second target for ts-prune |

## Technical Approach

### 1. Install ts-prune

Add to `pennyfarthing/package.json` devDependencies:

```json
"ts-prune": "^0.10.3"
```

Then run `pnpm install` in the `pennyfarthing/` directory. Verify `npx ts-prune --help` works.

### 2. Implement `_parse_ts_prune_output()` in `analyze.py`

```python
import re

_TS_PRUNE_LINE = re.compile(r"^(.+):(\d+) - (.+?)(?:\s+\(used in module\))?$")

def _parse_ts_prune_output(output: str) -> list[UnusedExport]:
    """Parse ts-prune stdout into UnusedExport instances.

    ts-prune output format: path:line - exportName
    Lines ending with '(used in module)' are included but flagged.
    """
    results = []
    for line in output.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        match = _TS_PRUNE_LINE.match(line)
        if match:
            path, line_num, export_name = match.groups()
            results.append(UnusedExport(
                path=path,
                export_name=export_name.strip(),
                line_number=int(line_num),
            ))
    return results
```

### 3. Implement `find_unused_exports()` in `analyze.py`

Run ts-prune via `asyncio.create_subprocess_exec`, not via `_run_git_command()` (since this is `npx`, not `git`). Create a new helper:

```python
async def _run_command(cmd: list[str], cwd: Path) -> tuple[str, str, int]:
    """Run an arbitrary command asynchronously."""
    proc = await asyncio.create_subprocess_exec(
        *cmd, cwd=cwd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    return (
        stdout.decode("utf-8", errors="replace").strip(),
        stderr.decode("utf-8", errors="replace").strip(),
        proc.returncode or 0,
    )

async def find_unused_exports(
    name: str, path: Path,
    tsconfig: str = "tsconfig.json",
    excludes: list[str] | None = None,
) -> DeadCodeResult:
    """Find unused TypeScript exports via ts-prune."""
    resolved = Path(path).resolve()
    tsconfig_path = resolved / tsconfig

    if not tsconfig_path.exists():
        return DeadCodeResult(
            success=False, repo_name=name, repo_path=str(resolved),
            time_window_days=0,
            error=f"tsconfig not found: {tsconfig_path}",
        )

    try:
        stdout, stderr, rc = await _run_command(
            ["npx", "ts-prune", "--project", tsconfig],
            cwd=resolved,
        )
    except FileNotFoundError:
        return DeadCodeResult(
            success=True, repo_name=name, repo_path=str(resolved),
            time_window_days=0,
            error="ts-prune not installed (Layer 2 skipped)",
        )

    if rc != 0 and "ts-prune" in stderr.lower():
        # ts-prune not found or failed
        return DeadCodeResult(
            success=True, repo_name=name, repo_path=str(resolved),
            time_window_days=0,
            error=f"ts-prune failed: {stderr}",
        )

    exports = _parse_ts_prune_output(stdout)

    # Filter exclusions
    all_excludes = DEFAULT_EXCLUDES + (excludes or [])
    exports = [e for e in exports if not _should_exclude(e.path, all_excludes)]

    return DeadCodeResult(
        success=True, repo_name=name, repo_path=str(resolved),
        time_window_days=0,
        unused_exports=exports,
        unused_export_count=len(exports),
    )
```

### 4. Implement combined `analyze_repo()` and update `analyze_all_repos()`

Add a top-level `analyze_repo()` that dispatches to either or both layers:

```python
async def analyze_repo(
    name: str, path: Path, days: int = 180,
    excludes: list[str] | None = None, branch: str = "--all",
    layer: str = "all", tsconfig: str = "tsconfig.json",
) -> DeadCodeResult:
    """Run dead code analysis on a single repo.

    Args:
        layer: "stale", "exports", or "all"
    """
    if layer == "stale":
        return await find_stale_files(name, path, days, excludes, branch)
    elif layer == "exports":
        return await find_unused_exports(name, path, tsconfig, excludes)
    else:
        # Run both in parallel
        stale_result, export_result = await asyncio.gather(
            find_stale_files(name, path, days, excludes, branch),
            find_unused_exports(name, path, tsconfig, excludes),
        )
        # Merge results
        return DeadCodeResult(
            success=stale_result.success and export_result.success,
            repo_name=name, repo_path=str(Path(path).resolve()),
            time_window_days=days,
            stale_files=stale_result.stale_files,
            unused_exports=export_result.unused_exports,
            stale_file_count=stale_result.stale_file_count,
            unused_export_count=export_result.unused_export_count,
            error=stale_result.error or export_result.error,
        )
```

### 5. Add CLI subcommands

Add `exports` and `all` to the `deadcode` Click group in `cli.py`:

```python
@deadcode.command()
@_common_options
@click.option("--tsconfig", default="tsconfig.json", show_default=True, help="Path to tsconfig.json")
def exports(repo, repo_path, days, top, fmt, output_file, exclude, branch, tsconfig):
    """Find unused TypeScript exports via ts-prune."""
    result = _run_analysis(repo, repo_path, days, exclude, branch, layer="exports", tsconfig=tsconfig)
    _output_result(result, fmt, output_file, top, mode="exports")

@deadcode.command()
@_common_options
@click.option("--tsconfig", default="tsconfig.json", show_default=True, help="Path to tsconfig.json")
def all(repo, repo_path, days, top, fmt, output_file, exclude, branch, tsconfig):
    """Run all dead code analysis layers."""
    result = _run_analysis(repo, repo_path, days, exclude, branch, layer="all", tsconfig=tsconfig)
    _output_result(result, fmt, output_file, top, mode="all")
```

### 6. Update formatters

Add to `formatters.py`:

```python
def format_exports_table(exports: list[UnusedExport], top_n: int = 20) -> str:
    """Format unused exports as a column-aligned table."""
    # Columns: Line | Export | File
    hdr = f"{'Line':>6}  {'Export':<40}  File"
    sep = f"{'------':>6}  {'----------------------------------------':<40}  ----"
    lines = [hdr, sep]
    for e in exports[:top_n]:
        lines.append(f"{e.line_number:>6}  {e.export_name:<40}  {e.path}")
    return "\n".join(lines)
```

## Acceptance Criteria

- `ts-prune` is listed as a devDependency in `pennyfarthing/package.json`
- `find_unused_exports()` runs `npx ts-prune --project <tsconfig>` via `asyncio.create_subprocess_exec`
- `_parse_ts_prune_output()` correctly parses ts-prune output format (`path:line - exportName`) into `UnusedExport` instances
- Lines ending with `(used in module)` are included in results (the export is still unused by external consumers)
- `DEFAULT_EXCLUDES` filters out `node_modules/*`, `dist/*` from ts-prune results
- When ts-prune is not installed, `find_unused_exports()` returns a `DeadCodeResult` with `success=True`, empty `unused_exports`, and `error` set to a warning string (not a crash)
- `pf deadcode exports --format json --tsconfig tsconfig.json` works end-to-end
- `pf deadcode all --format json --days 180` runs both layers and merges into a single `DeadCodeResult`
- `--tsconfig` option defaults to `tsconfig.json` but can be overridden (e.g., `tsconfig.vite.json`)
- `format_exports_table()` displays columns: Line, Export, File
- Combined `analyze_repo()` runs both layers in parallel via `asyncio.gather`

## Dependencies

### Depends On

- **81-1** (Python deadcode module: stale file detection) — depends on the module structure, `models.py` (all dataclasses), `analyze.py` scaffold (`_run_git_command()`, `_should_exclude()`, `DEFAULT_EXCLUDES`), `cli.py` (deadcode Click group), and `formatters.py` (base formatters).

### Depended On By

- **81-3** (Dead code API + React hook + dialog) — depends on the `all` subcommand with `--format json` for the Express router, and on `UnusedExport` data being populated for the Unused Exports tab.

## Risks / Open Questions

1. **ts-prune maintenance status:** ts-prune has not been actively maintained (last major release 2022). Alternatives include `knip` (actively maintained, broader scope) or raw `tsc` analysis. ts-prune is simpler to integrate (single-purpose, line-based output), but if it breaks with TypeScript 5.3+, we may need to switch. The graceful degradation ensures this is not a hard dependency.

2. **Dual tsconfig coverage:** Running ts-prune against `tsconfig.json` may miss exports only used in the React frontend (covered by `tsconfig.vite.json`), and vice versa. The `all` subcommand could accept a comma-separated list of tsconfigs, or the Express router could run ts-prune twice and merge. For this story, a single `--tsconfig` option per invocation is sufficient; the API layer (Story 81-3) can call twice if needed.

3. **npx overhead:** `npx ts-prune` adds ~2 seconds of startup overhead for package resolution. If ts-prune is installed locally (in `node_modules/.bin/`), using the direct path (`./node_modules/.bin/ts-prune`) would be faster. The implementation should try the direct path first, falling back to `npx`.

4. **Large repos with many exports:** ts-prune on a large TypeScript project can output thousands of lines. Parsing is fast (regex on text), but the output volume may exceed API response size limits. The `--top` flag should limit results in JSON output as well as table output.

5. **False positives:** ts-prune may report exports that are consumed dynamically (e.g., via `import()` expressions, re-exports in barrel files, or framework conventions like React component default exports). There is no way to suppress these in ts-prune itself. Consider adding a `--ignore-pattern` option for export names (e.g., `--ignore-pattern "^default$"`).

6. **`(used in module)` semantics:** ts-prune marks exports that are used within the same file but not imported elsewhere with `(used in module)`. These are technically unused exports but may be intentional (e.g., a helper used locally alongside the export). The current approach includes them; a future enhancement could add a `--skip-used-in-module` flag.
