# Story 83-1: Python complexity module

**Jira:** PROJ-14466
**Epic:** 83 — Complexity + Dependencies Tools
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/83-1-python-complexity-module
**Points:** 2
**Assignee:** slabgorb@gmail.com

## Acceptance Criteria

- [ ] Module runnable as `python3 -m pennyfarthing_scripts.complexity analyze --path <dir> --format json`
- [ ] Models use `@dataclass` with ADR-0008 `{success, ..., error}` pattern
- [ ] Per-file metrics include: `path`, `total_lines`, `longest_function`, `avg_cyclomatic_complexity`, `max_nesting_depth`, `function_count`
- [ ] CLI supports `--format table|json|csv`, `--top N`, `--output <file>`, `--exclude <pattern>`
- [ ] Graceful error when eslint is not installed (returns `{success: false, error: "..."}`)
- [ ] JSON output matches the API contract defined in epic context
- [ ] Table formatter produces readable column-aligned output
- [ ] No new npm dependencies required (uses existing eslint)

## Technical Context

Create a new `pennyfarthing_scripts/complexity/` module following the hotspots module structure (6 files: `__init__.py`, `__main__.py`, `analyze.py`, `models.py`, `cli.py`, `formatters.py`).

The module performs static analysis of TypeScript/JavaScript files by wrapping `eslint --format json` with a complexity rule override (or escomplex as fallback). It extracts per-file metrics: longest function, average cyclomatic complexity, max nesting depth, total lines, and function count.

Key approach:
- **ESLint integration:** ESLint `^9.39.2` is already a devDependency in `pennyfarthing/package.json`. Use eslint with `--rule` flag to enable complexity, max-depth, and max-lines-per-function rules via subprocess.
- **Async pattern:** Follow `pennyfarthing_scripts/hotspots/analyze.py` pattern using `asyncio.create_subprocess_exec` (line 60 reference).
- **Result model:** Implement ADR-0008 pattern with `ComplexityResult(success, target_path, file_count, files, error)` dataclass.
- **CLI:** Use Click group with `_common_options` decorator following hotspots/cli.py (lines 31-41).
- **Formatters:** Implement table/json/csv output following hotspots/formatters.py pattern with `dataclasses.asdict()` for JSON serialization.

Edge cases to handle:
- ESLint not found: return `{success: false, error: "eslint not found. Install with: npm install -D eslint"}`
- No .ts/.tsx files: return success with empty files list
- ESLint exit code non-zero: Expected when rules find violations; parse stdout regardless
- Timeout: Use 30-second timeout via `asyncio.wait_for()`

## Files

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `__init__.py` | `pennyfarthing/pennyfarthing_scripts/complexity/__init__.py` | Public API: re-export `FileComplexity`, `ComplexityResult`, `analyze_complexity` |
| `__main__.py` | `pennyfarthing/pennyfarthing_scripts/complexity/__main__.py` | Module entry: `from .cli import complexity; complexity()` |
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/complexity/analyze.py` | Core analysis: run eslint subprocess, parse JSON output, compute per-file metrics |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/complexity/models.py` | Dataclasses: `FileComplexity`, `ComplexityResult` |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/complexity/cli.py` | Click CLI: `complexity analyze --path --format --top --output --exclude` |
| `formatters.py` | `pennyfarthing/pennyfarthing_scripts/complexity/formatters.py` | Table, JSON, CSV formatters |

### Reference Files

| File | Location | Why |
|------|----------|-----|
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` | Async subprocess pattern and result aggregation |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/models.py` | ADR-0008 dataclass pattern |
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/cli.py` | Click CLI structure and `_common_options` decorator |
| `formatters.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/formatters.py` | Table/JSON/CSV formatting patterns |
| `config.py` | `pennyfarthing/pennyfarthing_scripts/common/config.py` | `get_project_root()` for finding project directory |
| `output.py` | `pennyfarthing/pennyfarthing_scripts/common/output.py` | `header()`, `info()` for table formatter output |
| `eslint.config.mjs` | `pennyfarthing/eslint.config.mjs` | Existing flat config reference |
| `package.json` | `pennyfarthing/package.json` | ESLint version and configuration |

## Session Log

- **Setup:** Session created by SM setup subagent (Gaff)
  - Branch created: `feat/83-1-python-complexity-module`
  - Session file initialized with ACs, technical context, and file list
  - Ready for TEA phase (test engineer will define test strategy)
- **Handoff → TEA:** SM setup complete. Story 83-1 (Python complexity module) ready for test design. TDD workflow, phase: red. Branch: feat/83-1-python-complexity-module in pennyfarthing repo.
- **Handoff → Dev:** TEA red phase complete. 38 tests written (29 failing, 9 passing). All stubs in place at `pennyfarthing_scripts/complexity/`. Dev needs to implement `analyze.py`, `formatters.py`, and `cli.py` internals to make tests pass. Commit: test: add failing tests for 83-1 complexity module (RED).
- **Handoff → Reviewer:** Dev implementation complete. 38/38 tests GREEN. PR #747 created targeting develop. Branch: feat/83-1-python-complexity-module. Files: analyze.py, formatters.py, cli.py implemented.

## TEA Assessment

**Tests Required:** Yes
**Test File:** `tests/python/test_complexity.py` (new, 400+ lines)

**Tests Written:** 38 tests covering all 8 ACs
**Status:** RED (29 failing, 9 passing — models + CLI structure pass, all behavior stubs fail)

**Test Classes:**
- `TestModels` (6 tests) — ADR-0008 dataclass pattern, field defaults, serialization
- `TestParseEslintOutput` (10 tests) — ESLint JSON parsing, metric extraction, edge cases
- `TestFindEslint` (2 tests) — Binary discovery in node_modules
- `TestAnalyzeComplexity` (6 tests) — Core engine, eslint-not-found, excludes, empty results
- `TestFormatters` (8 tests) — Table, JSON (API contract match), CSV formatters
- `TestCLI` (6 tests) — Help, options, format choices, invocation with mocks

**Stub Files Created (6):**
- `models.py` — Fully implemented (dataclasses only)
- `analyze.py` — Stubs: `_find_eslint`, `_parse_eslint_output`, `_run_eslint`, `_count_file_lines`, `analyze_complexity`
- `formatters.py` — Stubs: `format_file_table`, `export_json`, `export_csv`
- `cli.py` — CLI structure implemented, stubs: `_run_analysis`, `_output_result`
- `__init__.py` — Re-exports done
- `__main__.py` — Entry point done

**Key Design Decisions:**
1. Tests mock `_run_eslint` at subprocess boundary — Dev implements the actual eslint invocation
2. `_parse_eslint_output` tested with realistic ESLint JSON fixtures covering complexity, max-depth, max-lines-per-function rules
3. Tests verify relative paths (not absolute) in parsed output
4. API contract test validates exact JSON shape from epic context

**Handoff:** To Dev (Roy Batty) for implementation — make all 29 tests pass

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/complexity/analyze.py` — Core engine: `_find_eslint`, `_parse_eslint_output` (regex extraction from ESLint JSON), `_run_eslint` (async subprocess), `_count_file_lines`, `analyze_complexity`, `_should_exclude`
- `pennyfarthing_scripts/complexity/formatters.py` — `format_file_table` (column-aligned), `export_json` (dataclasses.asdict), `export_csv`
- `pennyfarthing_scripts/complexity/cli.py` — `_run_analysis` (asyncio bridge), `_output_result` (format dispatch)

**Tests:** 38/38 passing (GREEN)
**PR:** #747 — feat(83-1): Python complexity module
**Branch:** feat/83-1-python-complexity-module (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Tests:** 38/38 passing (GREEN)
**Data flow traced:** CLI `analyze` → `_run_analysis()` → `analyze_complexity()` → `_find_eslint()` → `_run_eslint()` (async subprocess) → `_parse_eslint_output()` (JSON + regex) → `_count_file_lines()` → `ComplexityResult` → formatters (table/json/csv) → stdout/file (safe — no injection vectors, subprocess uses list args not shell)
**Pattern observed:** Module structure exactly mirrors hotspots module (6 files, ADR-0008 models, Click CLI with `_common_options`, async subprocess pattern) at `pennyfarthing_scripts/complexity/`
**Error handling:** Graceful eslint-not-found at `analyze.py:168-174`, non-zero exit code tolerance at `analyze.py:176`, invalid JSON returns empty at `analyze.py:49-52`, OSError on file read at `analyze.py:140-141`
**Security:** No shell=True, no unsanitized input, regex patterns are safe (no catastrophic backtracking)
**Observations:** 10 total (8 verified good, 2 low-severity cosmetic notes)
**Handoff:** To SM for finish-story
- **Handoff → SM:** Reviewer approved. PR #747 merged to develop. 38/38 tests GREEN, 0 blocking issues. Ready for finish-story.
