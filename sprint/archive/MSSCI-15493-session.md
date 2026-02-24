# Story 126-5: Config consolidation — migrate preferences.yaml into config.local.yaml
**Jira:** MSSCI-15493
**Epic:** MSSCI-15488
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-15493-config-consolidation-migrate-prefs
**Assigned:** keith.avery@1898andco.io

---
## Context

Config consolidation story. Currently preferences are split across preferences.yaml, config.local.yaml, and persona-config.yaml. This story migrates everything into config.local.yaml as the single source of truth.

### Acceptance Criteria
- Migration moves preferences.yaml content to config.local.yaml
- All config readers use config.local.yaml
- preferences.yaml template removed
- persona-config.yaml references removed
- Existing user settings preserved during migration

---
## SM Assessment

**Story:** 126-5 — Config consolidation (3pts, TDD)
**Setup:** Session created, branch `feature/MSSCI-15493-config-consolidation-migrate-prefs` pushed, Jira claimed.
**Routing:** TDD phased workflow → TEA (red phase) for failing tests, then Dev for implementation.
**Notes:** Consolidation of preferences.yaml and persona-config.yaml into config.local.yaml. TEA should design tests around migration correctness, config reader unification, and backward compatibility (existing user settings preserved).

---
## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_config_consolidation.py` — 18 tests across 5 classes
- `pennyfarthing-dist/src/pf/config_migration.py` — stub module (NotImplementedError)

**Tests Written:** 18 tests covering 5 ACs
**Status:** RED (16 failing, 2 passing — correct RED state)

| AC | Tests | Failure Type |
|----|-------|-------------|
| Migration moves preferences → config.local | 5 tests | NotImplementedError (stub) |
| Config readers use config.local only | 4 tests (2 pass, 2 fail) | AssertionError (code still reads legacy paths) |
| preferences.yaml template removed | 1 test | AssertionError (template still exists) |
| persona-config.yaml refs removed | 3 tests | AssertionError (code still references it) |
| Settings preserved during migration | 5 tests | NotImplementedError (stub) |

**Key implementation notes for Ponder Stibbons:**
1. Implement `pf.config_migration.migrate_config()` — merges preferences.yaml + persona-config.yaml into config.local.yaml
2. Update `pf.prime.persona.is_character_voice_enabled()` to read `preferences:` section from config.local.yaml
3. Remove persona-config.yaml fallback from `pf.common.themes.get_current_theme()`
4. Remove persona-config.yaml fallback from `pf.hooks.statusline`
5. Delete `templates/preferences.yaml.template` and `templates/persona-config.yaml.template`

**Handoff:** To Ponder Stibbons (Dev) for implementation

---
## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/config_migration.py` — Full migrate_config() implementation
- `pennyfarthing-dist/src/pf/common/themes.py` — Removed persona-config.yaml fallback from get_current_theme()
- `pennyfarthing-dist/src/pf/prime/persona.py` — is_character_voice_enabled() reads config.local.yaml preferences section
- `pennyfarthing-dist/src/pf/hooks/statusline.py` — Removed persona-config.yaml fallback
- `pennyfarthing-dist/templates/preferences.yaml.template` — Deleted
- `pennyfarthing-dist/templates/persona-config.yaml.template` — Deleted

**Tests:** 18/18 passing (GREEN)
**Branch:** feature/MSSCI-15493-config-consolidation-migrate-prefs (pushed)

**Handoff:** To Granny Weatherwax (Reviewer) for code review

---
## TEA Verify Assessment

**Tests:** 18/18 passing (GREEN confirmed)
**Branch:** feature/MSSCI-15493-config-consolidation-migrate-prefs
**Regressions:** None introduced by this story (106 pre-existing failures in unrelated modules)

**Handoff:** To Granny Weatherwax (Reviewer) for code review

---
## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | **Data loss on crash:** Legacy files are `unlink()`ed BEFORE `config.local.yaml` is written. If the process crashes between delete and write, user preferences are permanently lost. | `config_migration.py:64-69,86-87` (unlinks) vs `90-92` (write) | Move all `unlink()` calls AFTER the `yaml.dump()` write succeeds |
| [HIGH] | **Migration never called in production:** `migrate_config()` has zero callers outside tests. Config readers now ONLY read `config.local.yaml`, but migration never runs — users upgrading with legacy files silently lose their preferences. | `config_migration.py` — no import in hooks, CLI, or init | Wire into `pf agent start` (prime flow) at `cli.py:238` or add `pf prime` as a top-level CLI command |
| [HIGH] | **`pf prime` missing from CLI:** Prime is only accessible as `pf agent start` which delegates to `prime()`. There is no standalone `pf prime` command, and the prime flow (`pf.prime.cli`) uses raw argparse rather than Click — it's not registered in `_LAZY_COMMANDS`. This is the natural upgrade path entry point where migration should run, but it's not a first-class CLI command. | `cli.py` — `prime` absent from `_LAZY_COMMANDS`; `prime/cli.py` uses argparse not Click | Register `pf prime` as a lazy command or wire `migrate_config()` into existing `pf agent start` path |
| [MEDIUM] | **No error handling:** Function docstring promises `{success, error}` result dict but never catches exceptions. Malformed YAML throws instead of returning error. Violates project convention "Return result objects — don't throw." | `config_migration.py:13` — entire function body lacks try-except | Wrap in try-except, return `{success: False, error: str(e)}` |
| [MEDIUM] | **Source inspection tests:** Two tests use `inspect.getsource()` for verification rather than behavioral testing. Acceptable per DEC-REV-003 but noted. | `test_config_consolidation.py:247,257` | No fix required |
| [MEDIUM] | **TypeScript persona-config fallback survives:** Python readers cleaned but `packages/core/src/cli/utils/themes.ts:getCurrentTheme()` still falls back to persona-config.yaml (23 files in packages/ reference it). Creates Python/TypeScript behavioral divergence. | `packages/core/src/cli/utils/themes.ts:107-108` | Track as follow-up story or clarify AC4 scope |

**Verified good:**
- [VERIFIED] `themes.py` fallback correctly simplified to single config.local.yaml read
- [VERIFIED] `statusline.py` fallback correctly simplified
- [VERIFIED] `persona.py:264` — `return True` default path is correct
- [VERIFIED] Both `.template` files properly deleted
- [VERIFIED] Config preservation logic (`if key not in existing_prefs`) correctly preserves existing settings
- [VERIFIED] Tests: 18/18 passing, no regressions introduced

**Data flow traced:** preferences.yaml → `yaml.safe_load()` → `prefs` dict → merge into `config["preferences"]` → `yaml.dump()` to config.local.yaml. Safe for valid YAML, throws on malformed input.

**Pattern observed:** Write-after-delete anti-pattern at `config_migration.py:64-92` — source deleted before destination written. Classic data loss footgun in migration code.

**Error handling:** `migrate_config()` has no exception handling despite promising result dict with error field. All three `yaml.safe_load()` calls at lines 44, 50, 52, 73 are unguarded.

**Handoff:** Back to Igor (TEA) for test coverage of crash-safety, wiring gap, and `pf prime` CLI registration

---
## TEA Assessment (Review Rejection)

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_config_consolidation.py` — 6 new tests in 4 classes

**Tests Written:** 6 new failing tests covering 3 HIGH + 1 MEDIUM reviewer findings
**Status:** RED (6 failing, 18 passing — correct RED state)

| Reviewer Finding | Tests | Failure Type |
|-----------------|-------|-------------|
| [HIGH] Crash safety — write before delete | 2 tests (TestMigrationCrashSafety) | AssertionError: legacy files deleted before write |
| [MEDIUM] Error handling — return dict not throw | 2 tests (TestMigrationErrorHandling) | AssertionError: function raises instead of returning error dict |
| [HIGH] Migration wired into prime | 1 test (TestMigrationWiredIntoPrime) | AssertionError: prime() doesn't reference migrate_config |
| [HIGH] pf prime CLI registration | 1 test (TestPrimeCLIRegistration) | AssertionError: "prime" not in _LAZY_COMMANDS |

**Key implementation notes for Ponder Stibbons:**
1. Reorder `config_migration.py` — move ALL `unlink()` calls AFTER `yaml.dump()` write succeeds
2. Wrap `migrate_config()` body in try-except, return `{success: False, error: str(e)}` on failure
3. Call `migrate_config(root)` inside `prime()` in `prime/cli.py` early in the activation flow
4. Register `pf prime` as a Click command in `cli.py` `_LAZY_COMMANDS` (requires a Click wrapper in `prime/cli.py`)

**Handoff:** To Ponder Stibbons (Dev) for implementation

---
## Dev Assessment (Review Rejection Fixes)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/config_migration.py` — Reordered unlinks after write, wrapped in try-except for error handling
- `pennyfarthing-dist/src/pf/prime/cli.py` — Added `migrate_config(root)` call in prime() flow; added Click `prime_cmd` command
- `pennyfarthing-dist/src/pf/cli.py` — Registered "prime" in `_LAZY_COMMANDS`
- `pennyfarthing-dist/src/pf/tests/test_config_consolidation.py` — Adapted crash safety tests for error-dict return pattern

**Tests:** 24/24 passing (GREEN)
**Branch:** feature/MSSCI-15493-config-consolidation-migrate-prefs (pushed)

**Handoff:** To Granny Weatherwax (Reviewer) for re-review

---
## TEA Verify Assessment (Post-Rejection Fixes)

**Tests:** 24/24 passing (GREEN confirmed)
**Branch:** feature/MSSCI-15493-config-consolidation-migrate-prefs
**Regressions:** None — all reviewer findings addressed

**Verified fixes:**
- [VERIFIED] Crash safety: `unlink()` calls moved AFTER `yaml.dump()` write succeeds (lines 89-97)
- [VERIFIED] Error handling: try-except wraps entire function body, returns `{success: False, error: str(e)}` (lines 29, 101-102)
- [VERIFIED] Migration wired into prime flow via `migrate_config(root)` call in `prime/cli.py`
- [VERIFIED] `pf prime` registered as lazy command in `cli.py` `_LAZY_COMMANDS`
- [VERIFIED] Crash safety tests adapted for error-dict return pattern (monkeypatch + result assertions)

**Test breakdown:** 18 original AC tests + 6 reviewer-finding tests = 24 total, all GREEN

**Handoff:** To Granny Weatherwax (Reviewer) for re-review

---
## Reviewer Assessment (Re-review)

**Verdict:** APPROVED

**Previous findings — all resolved:**
- [FIXED] Crash safety: `unlink()` calls now AFTER `yaml.dump()` write at `config_migration.py:89-97`
- [FIXED] Migration wired into prime: `migrate_config(root)` called at `prime/cli.py:374-376`
- [FIXED] `pf prime` registered as lazy command at `cli.py:88`
- [FIXED] Error handling: try-except wraps entire body, returns result dict at `config_migration.py:29,101-102`

**Data flow traced:** preferences.yaml → `yaml.safe_load()` → merge into `config["preferences"]` → `yaml.dump()` to config.local.yaml → `is_character_voice_enabled()` reads config.local.yaml preferences section. Safe end-to-end.
**Pattern observed:** Write-before-delete at `config_migration.py:89-97` — correct crash-safe ordering. `files_to_remove` list populated during merge, cleaned up only after successful write.
**Error handling:** Function returns `{success: False, error: str(e)}` on any exception. `prime()` ignores return value (graceful degradation — legacy files survive failure, next run retries).
**Wiring verified:** `migrate_config` → `prime()` → `pf agent start` / `pf prime` (both paths). Runs on every full activation (skipped in `--minimal` mode — acceptable).
**Security:** `yaml.safe_load()` throughout. No user-facing input surfaces. Path operations bounded to project tree.

| Severity | Observation | Location |
|----------|-------------|----------|
| [VERIFIED] | Crash safety: write at 91-92, unlinks at 95-96 | `config_migration.py:89-97` |
| [VERIFIED] | Error handling wraps entire function body | `config_migration.py:29,101-102` |
| [VERIFIED] | Migration wired into prime() activation flow | `prime/cli.py:374-376` |
| [VERIFIED] | `prime_cmd` Click command registered in `_LAZY_COMMANDS` | `cli.py:88`, `prime/cli.py:675` |
| [VERIFIED] | Templates deleted (preferences.yaml.template, persona-config.yaml.template) | `templates/` |
| [VERIFIED] | Config readers (themes.py, persona.py, statusline.py) only read config.local.yaml | Multiple files |
| [VERIFIED] | Idempotent: no-op when no legacy files (early return at line 39-40) | `config_migration.py:38-40` |
| [MEDIUM] | `prime()` ignores `migrate_config()` return — could log warning | `prime/cli.py:376` |
| [MEDIUM] | TypeScript persona-config fallback survives (scoped as follow-up) | `packages/core/` |

**Tests:** 24/24 passing. No forbidden patterns. No regressions.

**Handoff:** To Captain Carrot Ironfoundersson (SM) for finish-story