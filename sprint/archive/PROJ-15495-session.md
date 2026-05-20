# Story 126-7: pf upgrade — detect npm-based install, migrate to Python-based

**Jira:** PROJ-15495
**Points:** 5
**Status:** in_progress
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/PROJ-15495-pf-upgrade-npm-to-python
**Assigned:** keith.avery@slabgorb.io

---

## Acceptance Criteria

- [ ] Detects npm-based install (node_modules/@pennyfarthing)
- [ ] Migrates directory structure to new layout
- [ ] Preserves user custom hooks (non-pf-* prefixed)
- [ ] Migrates settings.local.json (removes old hooks, adds new)
- [ ] Config files migrated (preferences.yaml → config.local.yaml)
- [ ] Clear reporting of what changed

## Context

New command `pf upgrade` that detects an npm-based Pennyfarthing installation and migrates to the Python-based structure. Preserves user custom hooks, commands, and skills. Migrates config files. Removes npm artifacts.

## SM Assessment

Story setup complete. `pf upgrade` command — new Python CLI subcommand to detect and migrate npm-based Pennyfarthing installations. 5-point TDD story targeting pennyfarthing repo. Branch created, Jira claimed. Handing off to TEA for red phase (failing tests first).

## TEA Assessment

**Tests Required:** Yes
**Reason:** New CLI command with 6 ACs requiring detection, migration, and reporting logic

**Test Files:**
- `tests/python/test_upgrade_npm_to_python.py` — 31 tests across 7 test classes

**Tests Written:** 31 tests covering all 6 ACs
- AC1 (npm detection): 5 tests — presence, paths, absence, package.json, false positives
- AC2 (directory migration): 4 tests — creation, reporting, dry run, idempotency
- AC3 (custom hooks): 5 tests — identification, exclusion, structure, missing file, npm-era hooks
- AC4 (settings migration): 4 tests — hook replacement, preservation, valid JSON, dry run
- AC5 (config migration): 5 tests — preferences migration, values, preservation, no legacy, dry run
- AC6 (reporting): 4 tests — non-empty, npm mention, hooks preserved, config details
- Integration: 4 tests — full upgrade, non-npm project, dry run, report in result

**Status:** RED (all 31 failing with NotImplementedError — ready for Dev)

**Implementation notes for Ponder Stibbons:**
- Stub module at `pennyfarthing-dist/src/pf/upgrade/core.py` — implement each function
- CLI registered in `cli.py` as lazy command `"upgrade"` → `pf.upgrade.cli`
- Follow `config_migration.py` and `init/core.py` patterns for migration logic
- `preserve_custom_hooks` should filter out both `pf hooks *` and `npx pennyfarthing *` commands
- `migrate_settings` should write the `_MINIMAL_SETTINGS` hooks from `init/core.py`

**Handoff:** To Dev for implementation (GREEN phase)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/upgrade/core.py` — implemented all 7 functions (detect_npm_install, plan_migration, migrate_directory_structure, preserve_custom_hooks, migrate_settings, migrate_config_files, generate_report, run_upgrade)

**Tests:** 31/31 passing (GREEN)
**Branch:** feature/PROJ-15495-pf-upgrade-npm-to-python (pushed)

**Implementation notes:**
- `_is_pf_managed_command()` filters both `pf hooks *` and `npx pennyfarthing *` prefixes
- `_PYTHON_HOOKS` mirrors `_MINIMAL_SETTINGS` from `init/core.py` for hook replacement
- `migrate_config_files` uses yaml read-modify-write preserving existing config keys
- All functions support dry_run where applicable
- All functions return `{success, ...}` result objects per project convention

**Handoff:** To next phase (review)

## TEA Verify Assessment

**Tests:** 31/31 passing (GREEN confirmed)
**All 6 ACs covered** by tests with no gaps
**Implementation follows project patterns:** result objects, dry_run, no unnecessary abstractions
**No regressions detected**

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

| # | Severity | Finding | Location |
|---|----------|---------|----------|
| 1 | [MEDIUM] | No try/except around json.loads — corrupt settings.local.json raises unhandled JSONDecodeError | core.py:140, 187 |
| 2 | [LOW] | preserve_custom_hooks() called but result discarded in run_upgrade | core.py:359 |
| 3 | [LOW] | _PYTHON_HOOKS duplicates _MINIMAL_SETTINGS hooks (drift risk) | core.py:16-36 |
| 4 | [LOW] | migrate_config_files doesn't remove preferences.yaml after migration | core.py:265 |
| 5 | [VERIFIED] | _is_pf_managed_command correctly filters both pf hooks and npx pennyfarthing | core.py:39-42 |
| 6 | [VERIFIED] | CLI wiring correct, error path handles stderr + exit code | cli.py:31-33 |
| 7 | [VERIFIED] | yaml.safe_load used, no injection vectors, Path.resolve() throughout | core.py:254,256 |
| 8 | [VERIFIED] | Data flow clean end-to-end, no unvalidated writes | full trace |

**Data flow traced:** `pf upgrade /path` → `Path.resolve()` → `run_upgrade` → detect/migrate/report → `click.echo`
**Pattern observed:** Follows `config_migration.py` and `init/core.py` result-object patterns
**Error handling:** Missing try/except [MEDIUM] — outside AC scope, recommend follow-up

**Handoff:** To Captain Carrot for finish-story

## Phase Log

| Phase | Agent | Started | Status |
|-------|-------|---------|--------|
| setup | sm | 2026-02-24 | done |
| red | tea | 2026-02-24 | done |
| green | dev | 2026-02-24 | done |
| verify | tea | 2026-02-24 | done |
| review | reviewer | 2026-02-24 | done |