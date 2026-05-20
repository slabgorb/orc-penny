# Story Context: 83-2 - Python dependencies module

## Summary

Create a new `pennyfarthing_scripts/dependencies/` module that aggregates package staleness and security vulnerability data by wrapping `npm outdated --json` and `npm audit --json`. The module produces structured output with outdated package details (name, current, wanted, latest, type, severity classification) and security advisories (severity, title, URL, recommendation). Follows the same 6-file module structure established by the hotspots module (ADR-0008 result pattern, Click CLI, table/json/csv formatters).

## Current State

### No dependencies module exists

The `pennyfarthing_scripts/` directory has no dependency health analysis capability. Existing modules include: `hotspots/`, `brownfield/`, `preflight/`, `sprint/`, `story/`, `jira/`, `git/`, `prime/`, `hooks/`, `common/`, `migration/`, and several standalone scripts.

### npm is always available

The monorepo uses pnpm (`packageManager: "pnpm@9.0.0"` in `pennyfarthing/package.json` line 58), but `npm` is always available in any Node.js environment. Both `npm outdated --json` and `npm audit --json` work regardless of the package manager used to install dependencies. No additional dependencies are required.

### npm command behavior

- **`npm outdated --json`**: Returns exit code **1** when outdated packages exist (this is not a failure). Returns exit code 0 only when all packages are up to date. JSON output is a map of package names to `{current, wanted, latest, dependent, type, homepage}` objects.
- **`npm audit --json`**: Returns exit code > 0 when vulnerabilities are found. JSON output (npm 9+) contains `vulnerabilities` map with per-package `{severity, via, effects, range, nodes, fix}` objects, plus a `metadata` object with summary counts.

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

## Target State

After implementation, a new module at `pennyfarthing_scripts/dependencies/` with 6 files:

```
pennyfarthing_scripts/dependencies/
  __init__.py        # Public API re-exports
  __main__.py        # python -m pennyfarthing_scripts.dependencies
  analyze.py         # async subprocess: npm outdated --json, npm audit --json
  models.py          # OutdatedPackage, SecurityAdvisory, DependencyResult
  cli.py             # Click CLI: dependencies check [OPTIONS]
  formatters.py      # table/json/csv output
```

Running `python3 -m pennyfarthing_scripts.dependencies check --path /some/dir --format json` produces:

```json
{
  "success": true,
  "target_path": "/some/dir",
  "outdated": [
    {
      "package": "express",
      "current": "4.18.2",
      "wanted": "4.21.0",
      "latest": "5.0.1",
      "type": "dependencies",
      "severity": "major"
    }
  ],
  "advisories": [
    {
      "package": "ws",
      "severity": "high",
      "title": "ReDoS vulnerability",
      "url": "https://github.com/advisories/GHSA-xxxx",
      "vulnerable_versions": "<8.17.1",
      "recommendation": "Upgrade to >=8.17.1"
    }
  ],
  "summary": {
    "total_outdated": 5,
    "major_updates": 1,
    "minor_updates": 3,
    "patch_updates": 1,
    "advisories_critical": 0,
    "advisories_high": 1,
    "advisories_moderate": 0,
    "advisories_low": 0
  },
  "error": null
}
```

## Key Files

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `__init__.py` | `pennyfarthing/pennyfarthing_scripts/dependencies/__init__.py` | Public API: re-export `OutdatedPackage`, `SecurityAdvisory`, `DependencyResult`, `check_dependencies` |
| `__main__.py` | `pennyfarthing/pennyfarthing_scripts/dependencies/__main__.py` | Module entry: `from .cli import dependencies; dependencies()` |
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/dependencies/analyze.py` | Core analysis: run npm outdated + npm audit subprocesses, parse JSON, aggregate results |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/dependencies/models.py` | Dataclasses: `OutdatedPackage`, `SecurityAdvisory`, `DependencySummary`, `DependencyResult` |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/dependencies/cli.py` | Click CLI: `dependencies check --path --format --output` |
| `formatters.py` | `pennyfarthing/pennyfarthing_scripts/dependencies/formatters.py` | Table, JSON, CSV formatters |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` | Async subprocess pattern (`create_subprocess_exec` line 60), error handling |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/models.py` | ADR-0008 dataclass pattern |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/cli.py` | Click CLI structure, `_common_options` decorator (lines 31-41) |
| `formatters.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/formatters.py` | Table/JSON/CSV formatting, `export_json()` via `asdict()` (line 77) |
| `__init__.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/__init__.py` | `__all__` export pattern |
| `__main__.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/__main__.py` | Module entry pattern |
| `config.py` | `pennyfarthing/pennyfarthing_scripts/common/config.py` | `get_project_root()` (line 14) for project directory discovery |
| `output.py` | `pennyfarthing/pennyfarthing_scripts/common/output.py` | `header()`, `info()` for table formatter output |
| `package.json` | `pennyfarthing/package.json` | Verify npm availability, understand dependency structure |

## Technical Approach

### 1. Create `models.py`

Follow the `hotspots/models.py` pattern. Four dataclasses:

```python
from dataclasses import dataclass, field

@dataclass
class OutdatedPackage:
    """A single outdated npm package."""
    package: str
    current: str
    wanted: str
    latest: str
    type: str = "dependencies"       # dependencies | devDependencies
    severity: str = "patch"          # major | minor | patch

@dataclass
class SecurityAdvisory:
    """A single security vulnerability advisory."""
    package: str
    severity: str = "low"            # critical | high | moderate | low
    title: str = ""
    url: str = ""
    vulnerable_versions: str = ""
    recommendation: str = ""

@dataclass
class DependencySummary:
    """Aggregate counts for quick overview."""
    total_outdated: int = 0
    major_updates: int = 0
    minor_updates: int = 0
    patch_updates: int = 0
    advisories_critical: int = 0
    advisories_high: int = 0
    advisories_moderate: int = 0
    advisories_low: int = 0

@dataclass
class DependencyResult:
    """Analysis result following ADR-0008 pattern."""
    success: bool
    target_path: str = ""
    outdated: list[OutdatedPackage] = field(default_factory=list)
    advisories: list[SecurityAdvisory] = field(default_factory=list)
    summary: DependencySummary = field(default_factory=DependencySummary)
    error: str | None = None
```

### 2. Create `analyze.py`

Two async subprocess calls following the `hotspots/analyze.py` pattern (line 60):

```python
async def _run_npm_command(args: list[str], cwd: Path) -> tuple[str, str, int]:
    """Run an npm command asynchronously."""
    proc = await asyncio.create_subprocess_exec(
        "npm", *args,
        cwd=cwd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    return (
        stdout.decode("utf-8", errors="replace").strip(),
        stderr.decode("utf-8", errors="replace").strip(),
        proc.returncode or 0,
    )
```

**`npm outdated --json` parsing:**

```python
async def _get_outdated(target_path: Path) -> list[OutdatedPackage]:
    """Parse npm outdated --json output into OutdatedPackage models."""
    stdout, stderr, rc = await _run_npm_command(
        ["outdated", "--json"], target_path
    )
    # IMPORTANT: npm outdated returns exit code 1 when outdated packages exist.
    # This is expected behavior, not an error. Only fail on empty stdout + rc > 1.
    if not stdout and rc > 1:
        return []

    data = json.loads(stdout) if stdout else {}
    packages = []
    for name, info in data.items():
        severity = _classify_version_bump(
            info.get("current", ""), info.get("latest", "")
        )
        packages.append(OutdatedPackage(
            package=name,
            current=info.get("current", ""),
            wanted=info.get("wanted", ""),
            latest=info.get("latest", ""),
            type=info.get("type", "dependencies"),
            severity=severity,
        ))
    return packages
```

**Version severity classification:**

```python
def _classify_version_bump(current: str, latest: str) -> str:
    """Classify version difference as major/minor/patch."""
    # Parse semver: compare major.minor.patch components
    # If major differs -> "major", elif minor differs -> "minor", else -> "patch"
```

**`npm audit --json` parsing:**

```python
async def _get_advisories(target_path: Path) -> list[SecurityAdvisory]:
    """Parse npm audit --json output into SecurityAdvisory models."""
    stdout, stderr, rc = await _run_npm_command(
        ["audit", "--json"], target_path
    )
    # npm audit returns exit code > 0 when vulnerabilities exist
    if not stdout:
        return []

    data = json.loads(stdout)
    advisories = []
    # npm 9+ format: data["vulnerabilities"] is a dict of package -> vuln info
    vulns = data.get("vulnerabilities", {})
    for name, vuln in vulns.items():
        # "via" contains advisory details (list of dicts or strings)
        via_list = vuln.get("via", [])
        for via in via_list:
            if isinstance(via, dict):
                advisories.append(SecurityAdvisory(
                    package=name,
                    severity=via.get("severity", vuln.get("severity", "low")),
                    title=via.get("title", ""),
                    url=via.get("url", ""),
                    vulnerable_versions=vuln.get("range", ""),
                    recommendation=_format_fix(vuln.get("fix", {})),
                ))
    return advisories
```

**Main analysis function:**

```python
async def check_dependencies(
    target_path: Path,
) -> DependencyResult:
    """Run both npm outdated and npm audit, aggregate results."""
    resolved = target_path.resolve()

    # Check package.json exists
    if not (resolved / "package.json").exists():
        return DependencyResult(
            success=False,
            target_path=str(resolved),
            error=f"No package.json found at {resolved}",
        )

    # Run both checks concurrently
    outdated, advisories = await asyncio.gather(
        _get_outdated(resolved),
        _get_advisories(resolved),
    )

    summary = _build_summary(outdated, advisories)

    return DependencyResult(
        success=True,
        target_path=str(resolved),
        outdated=outdated,
        advisories=advisories,
        summary=summary,
    )
```

### 3. Create `cli.py`

Follow `hotspots/cli.py` pattern with Click group:

```python
@click.group()
def dependencies():
    """NPM dependency health check."""
    pass

def _common_options(fn):
    """Shared options for dependency commands."""
    fn = click.option("--path", "target_path", type=click.Path(exists=True),
                       help="Directory with package.json")(fn)
    fn = click.option("--format", "fmt", type=click.Choice(["table", "json", "csv"]),
                       default="table", show_default=True)(fn)
    fn = click.option("--output", "output_file", type=click.Path(),
                       help="Write output to file")(fn)
    return fn

@dependencies.command()
@_common_options
def check(target_path, fmt, output_file):
    """Check for outdated packages and security vulnerabilities."""
    path = Path(target_path).resolve() if target_path else Path.cwd()
    result = asyncio.run(check_dependencies(path))
    _output_result(result, fmt, output_file)
```

### 4. Create `formatters.py`

Follow `hotspots/formatters.py` pattern:

```python
def format_outdated_table(packages: list[OutdatedPackage]) -> str:
    """Format outdated packages as column-aligned table."""
    # Columns: Severity | Package | Current | Wanted | Latest | Type
    hdr = f"{'Severity':>8}  {'Package':<30}  {'Current':<12}  {'Wanted':<12}  {'Latest':<12}  Type"
    ...

def format_advisory_table(advisories: list[SecurityAdvisory]) -> str:
    """Format security advisories as table."""
    # Columns: Severity | Package | Title | Vulnerable Versions
    ...

def format_summary(result: DependencyResult, file: TextIO = sys.stderr) -> None:
    """Print summary header."""
    header(f"  Dependencies: {result.target_path}", char="=", width=60, file=file)
    info(f"Outdated packages: {result.summary.total_outdated}", file=file)
    ...

def export_json(result: DependencyResult) -> str:
    return json.dumps(asdict(result), indent=2, default=str)

def export_csv(packages: list[OutdatedPackage]) -> str:
    """Export outdated packages as CSV."""
    ...
```

### 5. Create `__init__.py` and `__main__.py`

```python
# __init__.py
from pennyfarthing_scripts.dependencies.models import (
    OutdatedPackage, SecurityAdvisory, DependencySummary, DependencyResult,
)
from pennyfarthing_scripts.dependencies.analyze import check_dependencies

__all__ = [
    "OutdatedPackage", "SecurityAdvisory", "DependencySummary",
    "DependencyResult", "check_dependencies",
]

# __main__.py
from pennyfarthing_scripts.dependencies.cli import dependencies
if __name__ == "__main__":
    dependencies()
```

### 6. Handle edge cases

- **No package.json:** Return `DependencyResult(success=False, error="No package.json found at ...")`.
- **No node_modules:** `npm outdated` and `npm audit` may fail or return empty results. Handle gracefully.
- **npm outdated exit code 1:** This is expected when outdated packages exist -- not an error. Parse stdout regardless.
- **npm audit exit code > 0:** Also expected when vulnerabilities are found. Parse stdout regardless.
- **npm not found:** Return `DependencyResult(success=False, error="npm not found")`. Check with `which npm` or catch `FileNotFoundError` from subprocess.
- **Timeout:** Use 30-second timeout on `asyncio.wait_for()` wrapping the subprocess calls.

## Acceptance Criteria

- Module runnable as `python3 -m pennyfarthing_scripts.dependencies check --path <dir> --format json`
- Models use `@dataclass` with ADR-0008 `{success, ..., error}` pattern
- Parses `npm outdated --json` into `OutdatedPackage` models with correct severity classification (major/minor/patch)
- Parses `npm audit --json` into `SecurityAdvisory` models with severity, title, URL, vulnerable versions, and recommendation
- Summary object includes aggregate counts: total_outdated, major/minor/patch_updates, advisories by severity level
- CLI supports `--format table|json|csv` and `--output <file>`
- Handles `npm outdated` exit code 1 correctly (not treated as error)
- Handles `npm audit` exit code > 0 correctly (not treated as error)
- Graceful error when no `package.json` exists or npm is not available
- JSON output matches the API contract defined in `context-epic-83.md`
- No new npm or Python dependencies required

## Dependencies

### Depends On

- **npm** (always available in Node.js environment)
- **pennyfarthing_scripts/common/** for `get_project_root()` (config.py line 14) and output utilities (output.py)
- **Click** (already used by hotspots/cli.py and other modules)

### Depended On By

- **Story 83-3** (APIs + hooks + dialogs) -- Express API calls this module via `python3 -m pennyfarthing_scripts.dependencies check --format json`

## Risks / Open Questions

1. **npm audit JSON format varies by version:** The `npm audit --json` schema changed between npm 6, 7, 8, and 9. npm 9+ uses a `vulnerabilities` map with `{severity, via, fix, range}` per package. Older versions use an `advisories` map with different structure. The module should target npm 9+ and include defensive parsing with graceful degradation for older formats. Consider detecting npm version via `npm --version` and branching parsing logic.

2. **pnpm vs npm:** The monorepo uses pnpm (`packageManager: "pnpm@9.0.0"` in package.json line 58). `npm outdated --json` still works in pnpm-managed projects because npm reads `node_modules/` directly. However, pnpm's hoisted vs non-hoisted `node_modules` layout could affect results. The `pnpm outdated --json` and `pnpm audit --json` commands could be used as alternatives but have different output formats. For v1, stick with npm commands for simplicity and consistency.

3. **Monorepo workspace handling:** In a pnpm workspace monorepo, `npm outdated` at the root only reports root dependencies. Per-package outdated analysis would require running in each workspace directory. For v1, analyze the directory specified by `--path` (or project root). Consider `--all-workspaces` support as a future enhancement.

4. **Rate limiting on npm audit:** `npm audit` contacts the npm registry. In CI or rapid iteration scenarios, this could hit rate limits. Consider caching results with a short TTL (e.g., 5 minutes) to avoid repeated registry hits.

5. **Private registries:** Projects using private npm registries may require authentication for `npm audit` to work. If the registry URL is configured in `.npmrc`, npm will use it automatically. If authentication fails, the error should be surfaced clearly in the `DependencyResult.error` field.
