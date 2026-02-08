# Story 80-1: Python codemarkers module: grep + git blame

**Jira:** MSSCI-14454
**Points:** 2
**Status:** in_progress
**Phase:** approved
**Workflow:** tdd
**Repos:** pennyfarthing
**Branch:** feature/80-1-codemarkers-module

## Description

New module: pennyfarthing_scripts/codemarkers/
Files: __init__.py, analyze.py, models.py, cli.py, formatters.py, __main__.py
Core: grep for TODO/FIXME/HACK/XXX markers across source files, git blame each line for age/author. Models: CodeMarker dataclass with path, line, text, marker_type, author, age_days, is_stale. CLI: click group with analyze command, --format json/table.

## Acceptance Criteria

- Create codemarkers module at pennyfarthing_scripts/codemarkers/
- Grep source files for TODO, FIXME, HACK, XXX markers
- Git blame each marker line (batch by file for performance)
- CodeMarker dataclass: path, line, marker_type, text, author, date, age_days, is_stale
- CodeMarkersResult with success/error fields (ADR-0008)
- CLI: click group with analyze command, --format json/table/csv
- Default stale threshold: 90 days
- Exclude node_modules, dist, build, lock files
- Async git subprocess pattern (matching hotspots module)

## Technical Context

Reference implementation: pennyfarthing_scripts/hotspots/
Pattern: async git commands, dataclass models, click CLI, formatters

## TEA Assessment

**Test file:** `pennyfarthing_scripts/tests/test_codemarkers.py`
**Tests:** 46 total, 46 RED (all `ModuleNotFoundError` — module not yet created)

**Test coverage by component:**

| Component | Tests | What's covered |
|-----------|-------|---------------|
| `models.py` | 9 | CodeMarker fields/defaults/serialization, MarkerSummary, CodeMarkersResult ADR-0008 success/error |
| `analyze.py` — `_grep_markers` | 10 | TODO/FIXME/HACK/XXX detection, multi-marker files, exclude patterns, case sensitivity, nested dirs, binary file safety, empty dirs |
| `analyze.py` — `_parse_blame_porcelain` | 2 | Author + timestamp extraction from porcelain, empty output handling |
| `analyze.py` — `_batch_blame_file` | 2 | Multi-line blame from single call, git failure fallback |
| `analyze.py` — `analyze_repo` | 5 | Nonexistent path error, empty repo, blame enrichment, stale threshold, summary computation, default excludes |
| `analyze.py` — `_should_exclude` | 4 | node_modules, lock files, glob extensions, non-matching paths |
| `formatters.py` | 5 | Empty table, table headers, top_n limit, JSON export, CSV export |
| `cli.py` | 5 | Help output, analyze/stale/summary commands exist, --format json with mocked analysis |
| `__main__.py` | 1 | `python -m` invocation |
| `__init__.py` | 2 | Re-exports models + analyze_repo |

**Key design decisions:**
- `_grep_markers` is a synchronous function (file I/O, no git needed) — tests use `tmp_path` with real files
- `_batch_blame_file` is async — tests mock `_run_git_command` to avoid git dependency
- `analyze_repo` is async — tests mock `_batch_blame_file` to isolate blame from grep
- `_parse_blame_porcelain` is a pure parser — tests use raw porcelain strings
- CLI tests use Click's `CliRunner` — no subprocess needed except `__main__` test

**Function signatures prescribed by tests:**
- `_grep_markers(root: Path, excludes: list[str]) -> list[dict]` — returns `[{path, line, marker_type, text}]`
- `_parse_blame_porcelain(output: str, line: int) -> dict` — returns `{author, author_time}`
- `_batch_blame_file(repo_path: Path, file_path: str, lines: list[int]) -> dict[int, dict]` — async
- `analyze_repo(name: str, path: Path, days: int) -> CodeMarkersResult` — async
- `_should_exclude(path: str, patterns: list[str]) -> bool`

**Handoff:** To Dev for GREEN phase (implement to pass all 46 tests)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/codemarkers/__init__.py` — Re-exports CodeMarker, CodeMarkersResult, MarkerSummary, analyze_repo
- `pennyfarthing_scripts/codemarkers/__main__.py` — python -m entry point
- `pennyfarthing_scripts/codemarkers/models.py` — CodeMarker, MarkerSummary, CodeMarkersResult dataclasses (ADR-0008)
- `pennyfarthing_scripts/codemarkers/analyze.py` — _grep_markers, _parse_blame_porcelain, _batch_blame_file, _should_exclude, analyze_repo
- `pennyfarthing_scripts/codemarkers/formatters.py` — format_marker_table, format_summary, export_json, export_csv
- `pennyfarthing_scripts/codemarkers/cli.py` — Click group with analyze, stale, summary commands

**Tests:** 46/46 passing (GREEN)
**Branch:** feature/80-1-codemarkers-module (ready to push)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `_grep_markers` → filesystem walk + regex → `analyze_repo` groups by file → `_batch_blame_file` (single `git blame --porcelain` per file) → enriches markers with author/age → `CodeMarkersResult`
**Pattern compliance:** All 6 hotspots patterns replicated — ADR-0008 models, async git subprocess, Click CLI with `_common_options`, formatters (table/JSON/CSV), `__init__` re-exports, `__main__` entry point
**Security:** No injection vectors — `create_subprocess_exec` (no shell), internal file paths only, binary files skipped
**Error handling:** Nonexistent path → error result, git blame failure → empty dict fallback, unreadable files → silently skipped
**Tests:** 46/46 covering all ACs, mocks appropriate for unit scope
**Notes:** `[LOW]` `_parse_blame_porcelain` is standalone but `_batch_blame_file` has inline parsing — function exists for test surface, not blocking

**Handoff:** To SM for finish-story
