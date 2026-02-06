# Story 76-2: Sprint validate command with --fix flag

**Jira:** MSSCI-14255
**Epic:** MSSCI-14253 (Sprint Data Management System)
**Points:** 3
**Priority:** P0
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14255-sprint-validate-fix

## Acceptance Criteria

- [ ] Detects YAML syntax errors with line numbers
- [ ] Detects schema violations (missing required fields)
- [ ] Detects format drift (wrong indentation, key order)
- [ ] --fix repairs all format errors automatically
- [ ] Exit code 0 = valid, non-zero = invalid

## Context

This story adds a `sprint validate` command to the pennyfarthing sprint management system. It should validate `sprint/current-sprint.yaml` against the sprint schema, checking for:
- YAML syntax correctness
- Required fields present (name, status, dates, etc.)
- Format consistency (indentation, key ordering)

The `--fix` flag should automatically repair format issues (but not semantic errors).

## Technical Context

**Builds on 76-1:** Core `yaml_io.py` module (completed) provides `read_sprint()`, `write_sprint()`, `canonical_dump()`

**Key files to create:**
- `pennyfarthing_scripts/sprint/validate_cmd.py` — CLI command
- `pennyfarthing_scripts/tests/test_validate_cmd.py` — Tests

**Key files to modify:**
- `pennyfarthing_scripts/sprint/cli.py` — Register validate command
- `pennyfarthing_scripts/sprint/validator.py` — Extend with format checks

**Existing infrastructure:**
- `validator.py` (406 lines) — Schema validation, required fields, status values
- `loader.py` — Read-only queries, `load_sprint()`, `find_epic()`, `find_story()`
- `yaml_io.py` — Deterministic read/write with ruamel.yaml
- `conftest.py` — Pytest fixtures: `valid_sprint_data`, `valid_story`, `valid_epic`

**Error format:** `epics[1].stories[3].description: wrong string style (expected block scalar)`
**--fix pattern:** `yaml_io.read_sprint()` → `yaml_io.write_sprint()` to canonicalize

## SM Assessment

Setup complete. Story is well-scoped with clear ACs and rich epic context. 76-1 foundation is in place. Route to TEA for test design on TDD workflow.

## TEA Assessment

**Tests Required:** Yes
**Reason:** TDD workflow, 3-point story with 5 ACs

**Test Files:**
- `pennyfarthing_scripts/tests/test_validate_cmd.py` — 25 tests across 6 test classes
- `pennyfarthing_scripts/sprint/validate_cmd.py` — Stub with data classes + NotImplementedError

**Tests Written:** 25 tests covering all 5 ACs
- AC1 (syntax errors w/ line numbers): 3 tests — `TestYamlSyntaxErrors`
- AC2 (schema violations): 5 tests — `TestSchemaViolations`
- AC3 (format drift): 4 tests — `TestFormatDrift`
- AC4 (--fix auto-repair): 4 tests — `TestFixFlag`
- AC5 (exit codes): 4 tests — `TestExitCodes`
- CLI integration: 5 tests — `TestCLIIntegration`

**Status:** RED (20 failing, 5 passing scaffolding tests)
**All failures:** `NotImplementedError` — correct RED state

**Data classes provided in stub:**
- `ValidateError` — with `category` field ("syntax"/"schema"/"format") and optional `line`
- `FormatIssue` — for format drift detection
- `ValidateResult` — aggregates errors + format issues

**Implementation guidance for Dev:**
1. `validate_sprint_yaml()` — orchestrate: parse YAML (catch syntax errors w/ line), run existing `validator.validate_full_sprint()` (map to schema errors), run `check_format_drift()`. With `--fix`, use `yaml_io.read_sprint()` + `yaml_io.write_sprint()`.
2. `check_format_drift()` — compare actual key order vs canonical (`yaml_io.SPRINT_KEY_ORDER` etc), check string styles
3. `validate_command` — Click command, wire up exit codes, format output
4. Register in `cli.py` via `sprint.add_command(validate_command)`

**Handoff:** To Dev (Winchester) for implementation

## Dev Assessment

**Status:** GREEN — 25/25 tests passing
**Commits:** 2 (RED tests + GREEN implementation)

**Implementation:**
- `validate_cmd.py` — 3 public functions, ~200 lines total
  - `validate_sprint_yaml()` — orchestrates syntax → schema → format checks, --fix via yaml_io round-trip
  - `check_format_drift()` — compares key ordering against canonical orders, checks string styles via ruamel.yaml `LiteralScalarString`
  - `validate_command` — Click CLI with exit codes and formatted output
- `cli.py` — added `sprint.add_command(validate_command)` registration

**Test fixture fix:** Added `number` field to VALID_CANONICAL_YAML (required by existing validator.py) and placed it in canonical position (after known keys, since it's not in SPRINT_KEY_ORDER)

**Pre-existing failures (3, not caused by this story):**
- `test_all_valid_story_statuses_pass` — "cancelled" vs "canceled" spelling
- `test_archived_sprint_allows_all_done_stories` — same spelling issue
- `test_sprint_cli_help` — `__main__.py` imports non-existent `cli` (should be `sprint`)

**Handoff:** To Reviewer (Colonel Potter) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** CLI `file` arg → `Path(file)` → `validate_sprint_yaml()` → `yaml.safe_load()` for syntax → `validate_full_sprint()` for schema → `check_format_drift()` via `read_sprint()` for format. Fix path: `read_sprint()` → `write_sprint()` (atomic). No user input reaches dangerous sinks.

**Pattern observed:** Good separation of concerns — orchestrates three existing systems (YAML parser, schema validator, format checker) with Click CLI on top. Format drift detection delegates to `yaml_io` key order constants at `validate_cmd.py:59-75`.

**Error handling:** File-not-found (line 158), empty file (lines 172, 196), YAML parse errors with line numbers (line 183), schema failures propagated (line 207), fix failures silently caught (line 222). All paths tested.

**Security:** Uses `yaml.safe_load()` (not `yaml.load()`). Atomic writes via `os.replace()`. No shell execution.

**Tests:** 25/25 passing across 5 ACs + CLI integration. Good negative cases. Pre-existing `test_sprint_module_exists` failure is unrelated (stale infrastructure test).

**Minor observations (non-blocking):**
- `[LOW]` Unused `canonical_dump` import at `validate_cmd.py:24`
- `[LOW]` Lazy `LiteralScalarString` import inside function at `validate_cmd.py:86` (works fine due to Python import caching)

**Handoff:** To Hawkeye (SM) for finish-story

## Notes

- Part of Epic 76: Sprint Data Management System
- Jira MSSCI-14255 moved to In Progress (assignment needs manual Jira action)
