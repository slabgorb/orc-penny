# Epic 83: Complexity + Dependencies Tools

**Jira:** MSSCI-14465
**Goal:** Two lightweight diagnostic tools for codebase analysis

## Stories
- 83-1: Python complexity module (2pts) — DELIVERED (complexity/ module exists)
- 83-2: Python dependencies module (2pts) — IN PROGRESS
- 83-3: Complexity + Dependencies APIs + hooks + dialogs (2pts) — Backlog

## Architecture
All modules live in `pennyfarthing_scripts/` as Python packages.
Each module follows the pattern: models.py, analyze.py, cli.py, formatters.py.
Tests in `tests/python/`.

## Technical Details

### Complexity Module (83-1)
- **Location:** `pennyfarthing_scripts/complexity/`
- **Purpose:** Static analysis of TypeScript/JavaScript cyclomatic complexity, function length, nesting depth
- **Wraps:** eslint with complexity/max-depth/max-lines-per-function rules
- **Models:** FileComplexity (path, total_lines, longest_function, avg_cyclomatic_complexity, max_nesting_depth, function_count)
- **Output:** ComplexityResult (success, target_path, file_count, files, error)
- **CLI:** `python -m pennyfarthing_scripts.complexity analyze [--path DIR] [--format json|table|csv] [--top N] [--exclude PATTERN...]`

### Dependencies Module (83-2)
- **Location:** `pennyfarthing_scripts/dependencies/`
- **Purpose:** Package staleness and security vulnerability detection
- **Wraps:** npm outdated --json and npm audit --json
- **Models:** OutdatedPackage (name, current, wanted, latest, type), SecurityAdvisory (severity, count)
- **Output:** DependenciesResult (success, target_path, outdated, security, error)
- **CLI:** `python -m pennyfarthing_scripts.dependencies analyze [--path DIR] [--format json|table]`

### Async Pattern
Both modules use async/await with asyncio for subprocess execution:
- `_run_eslint()` / `_run_npm()` — async subprocess execution
- `_count_file_lines()` / `_parse_output()` — async file I/O
- `analyze_*()` — main async entry point

### ADR-0008 Result Pattern
All analysis functions return result objects with structure:
```python
@dataclass
class Result:
    success: bool
    data: object = None
    error: str | None = None
```

## Testing
- Unit tests in `tests/python/test_dependencies.py`
- Test npm output parsing
- Test model creation
- Test error handling (missing npm, invalid directories)
- Test CLI formatting (json/table/csv)
