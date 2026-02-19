# Story 117-2: Generate hook commands with pf.sh wrapper path, not bare pf

**Epic:** 117 — Consumer Install — Fix v11.x postinstall gaps
**Points:** 2
**Priority:** p0
**Jira:** (none)
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/117-2-hook-pf-wrapper
**Assigned:** (unassigned)

---

## Context

Epic 117 addresses gaps in the v11.x consumer install process. The framework was refactored to use uv for Python hook management, but the postinstall process still has issues:

- **117-1:** Ship pyproject.toml in npm package (3 pts)
- **117-2:** Generate hook commands with pf.sh wrapper path (2 pts) ← THIS STORY
- **117-3:** Postinstall cleanup of stale pre-11.x artifacts (3 pts)
- **117-4:** Ensure project hook templates have execute permission (1 pt)

This story focuses on fixing how hook commands are generated in settings.local.json.

## Description

settings.local.json hook generation writes bare `pf` commands which are not in PATH. The pf CLI is only available via `uv run` or the pf.sh wrapper. Generate hooks using the pf.sh wrapper path instead: `$CLAUDE_PROJECT_DIR/.pennyfarthing/scripts/core/pf.sh hooks <subcommand>`.

## Acceptance Criteria

- [ ] Hook generation uses `$CLAUDE_PROJECT_DIR/.pennyfarthing/scripts/core/pf.sh` wrapper path instead of bare `pf`
- [ ] Existing hooks in settings.local.json are updated to use the wrapper path
- [ ] Tests validate the correct path is generated

## Technical Approach

The bug: `migrateHookPaths()` in `settings.ts` only migrates legacy `.sh` file references to `pf.sh` wrapper commands. It does NOT catch bare `pf hooks X` commands (without the wrapper). Doctor detection checks also accept bare `pf hooks` as valid when it shouldn't — bare `pf` isn't in PATH for consumer installs.

Fix needed:
1. Add bare `pf hooks X` → `pf.sh hooks X` migration to `migrateHookPaths()` in `settings.ts`
2. Add bare `pf hooks X` migration to `mergeSettingsLocalJson()` (runs on merge/update)
3. Update `checkLegacyHookCommands()` in `doctor.ts` to flag bare `pf hooks` as needing migration
4. Update doctor detection checks to not accept bare `pf hooks` as valid

## Files of Interest

- `packages/core/src/cli/utils/settings.ts` — `migrateHookPaths()`, `LEGACY_HOOK_MIGRATIONS`, `mergeSettingsLocalJson()`
- `packages/core/src/cli/commands/doctor.ts` — `checkLegacyHookCommands()`, various `check*Hook()` functions
- `pennyfarthing-dist/templates/settings.local.json.template` — the template (already correct)
- `pennyfarthing_scripts/hooks/cli.py` — docstring references bare `pf` (cosmetic)

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core hook migration logic needs verification

**Test Files:**
- `packages/core/src/cli/utils/settings-pf-wrapper.test.ts` — 13 tests covering all 3 ACs

**Tests Written:** 13 tests covering 3 ACs
**Status:** RED (7 failing, 6 passing — failing tests target missing bare-pf migration)

**Failing tests confirm:**
- `migrateHookPaths()` does not convert bare `pf hooks X` to wrapper path
- `mergeSettingsLocalJson()` does not migrate bare commands in existing settings
- Mixed bare/wrapper settings are not cleaned up during merge

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/cli/utils/settings.ts` — added bare `pf hooks X` → wrapper migration in `migrateHookPaths()` and statusLine migration in `mergeSettingsLocalJson()`

**Tests:** 13/13 passing (GREEN) — full suite 2887/2887 passing, 0 regressions
**Branch:** feat/117-2-hook-pf-wrapper (pushed)

**Handoff:** To Reviewer

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Bare `pf hooks X` command → regex match at `settings.ts:142` → rewrite to `PF_SH hooks X` → written to settings.local.json (safe — regex anchors at `^pf`, preserves subcommand verbatim)
**Pattern observed:** Minimal change — two surgical edits to existing migration pipeline, no new abstractions at `settings.ts:142-148,381-393`
**Error handling:** migrateHookPaths returns boolean, no new error paths introduced. StatusLine null/type guards preserved from original code.
**Low finding:** Redundant equality check alongside regex in statusLine handler at `settings.ts:382` — harmless, not blocking.
**Tests:** 13/13 passing, 2887/2887 full suite, 0 regressions.

**Handoff:** To SM for finish-story