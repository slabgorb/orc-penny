# Story 83-2: Python dependencies module

**Jira:** MSSCI-14467
**Epic:** epic-83 (Complexity + Dependencies Tools) — MSSCI-14465
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/83-2-python-dependencies-module

## Acceptance Criteria

The dependencies module should:
- Wrap `npm outdated --json` for staleness detection
- Wrap `npm audit --json` for security vulnerability detection
- Live in `pennyfarthing_scripts/dependencies/`
- Follow the same pattern as the complexity module (models, analyze, cli, formatters)
- Include comprehensive tests in `tests/python/test_dependencies.py`

Models:
- `OutdatedPackage` (name, current, wanted, latest, type)
- `SecurityAdvisory` (severity, count)

CLI with `--format json/table` output options.

## Technical Context

Epic description: Two lightweight diagnostic tools. Complexity: static analysis via Python wrapping eslint --format json or escomplex for cyclomatic complexity, function length, nesting depth. Dependencies: Python wrapping npm outdated --json and npm audit --json for staleness and security. Both in pennyfarthing_scripts/.

The sibling complexity module was just implemented and provides the architectural pattern to follow:
- `pennyfarthing_scripts/complexity/` — models.py, analyze.py, cli.py, formatters.py, __init__.py, __main__.py
- Tests in `tests/python/test_complexity.py`

The dependencies module should mirror this structure:
- `models.py` — dataclasses for OutdatedPackage and SecurityAdvisory
- `analyze.py` — async analysis engine wrapping npm outdated/audit
- `cli.py` — Click CLI group with analyze command
- `formatters.py` — table, json, csv output
- `__init__.py` — public API exports
- `__main__.py` — module entrypoint

## Files to Create/Modify
- `pennyfarthing_scripts/dependencies/__init__.py`
- `pennyfarthing_scripts/dependencies/__main__.py`
- `pennyfarthing_scripts/dependencies/models.py`
- `pennyfarthing_scripts/dependencies/analyze.py`
- `pennyfarthing_scripts/dependencies/cli.py`
- `pennyfarthing_scripts/dependencies/formatters.py`
- `tests/python/test_dependencies.py`

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core module with parsing logic, async subprocess calls, and multiple output formats

**Test Files:**
- `tests/python/test_dependencies.py` — 42 tests across 6 test classes

**Tests Written:** 42 tests covering all ACs
- TestModels (8) — OutdatedPackage, SecurityAdvisory, DependenciesResult, ADR-0008 serialization
- TestParseOutdatedOutput (7) — npm outdated JSON parsing, edge cases
- TestParseAuditOutput (6) — npm audit JSON parsing, severity extraction
- TestAnalyzeDependencies (7) — core engine, graceful errors (npm not found, no package.json), partial failures
- TestFormatters (9) — table, JSON API contract, CSV output
- TestCLI (5) — Click group, help, format options, integration

**Status:** RED (31 failing on NotImplementedError stubs, 11 passing models+help)
**Commit:** `test: add failing tests for 83-2 dependencies module`

**Implementation notes for Dev:**
- Follow `pennyfarthing_scripts/complexity/` pattern exactly
- `_find_npm` — use `shutil.which("npm")` (simpler than eslint's walk-up approach)
- `_check_package_json` — check `target_path / "package.json"` exists
- `_parse_outdated_output` — npm outdated --json returns `{pkg: {current, wanted, latest, type}}`
- `_parse_audit_output` — npm audit --json returns `{vulnerabilities: {name: {severity}}, metadata: {vulnerabilities: {severity: count}}}`
- Tests expect partial failure tolerance: if outdated fails, still return audit results and vice versa
- `_run_analysis` in cli.py should mirror complexity's pattern with lazy imports

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/dependencies/analyze.py` — core engine: _find_npm (shutil.which), _check_package_json, _parse_outdated_output, _parse_audit_output, async npm runners, analyze_dependencies
- `pennyfarthing_scripts/dependencies/formatters.py` — format_outdated_table, format_audit_table, export_json, export_csv
- `pennyfarthing_scripts/dependencies/cli.py` — Click group with analyze command, _run_analysis, _output_result with lazy imports
- `tests/python/test_dependencies.py` — added _check_package_json mocks to 5 integration tests

**Tests:** 42/42 passing (GREEN)
**PR:** #748 — feat(83-2): Python dependencies module
**Branch:** feature/83-2-python-dependencies-module (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** target_path → Path.resolve() → subprocess cwd (safe, no shell injection)
**Pattern observed:** Mirrors complexity module exactly — models, analyze, formatters, cli at `pennyfarthing_scripts/dependencies/`
**Error handling:** Graceful ADR-0008 returns for npm-not-found (`analyze.py:130`), no-package-json (`analyze.py:137`), invalid JSON (`analyze.py:43,71`)
**Partial failure:** Outdated/audit failures independent — one failing doesn't block the other (`analyze.py:144-148`)
**Security:** No shell injection (create_subprocess_exec), no hardcoded secrets, no debug output

| Severity | Observation | Location |
|----------|-------------|----------|
| [LOW] | `_find_npm` ignores target_path param | `analyze.py:23` |
| [MEDIUM] | No subprocess timeout (pre-existing pattern from complexity) | `analyze.py:91,109` |

**Tests:** 42/42 passing, no forbidden patterns, imports clean
**Handoff:** To SM for finish-story
