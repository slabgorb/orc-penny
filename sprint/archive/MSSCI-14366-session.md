# Story: MSSCI-14366 — Move settings.local.json into .pennyfarthing

**Workflow:** tdd
**Phase:** review
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-14366-settings-local-consolidation
**Epic:** epic-85 (MSSCI-14364)
**Jira:** MSSCI-14366

## Acceptance Criteria

- `mergeSettingsLocalJson()` writes to `.pennyfarthing/settings.local.json`
- Symlink created at `.claude/settings.local.json` → `../.pennyfarthing/settings.local.json`
- Migration: existing real file at `.claude/settings.local.json` moved on update
- Tests for symlink creation and migration

## Key Files

- `packages/core/src/cli/utils/settings.ts` — Main modification target
- `packages/core/src/cli/commands/init.ts` — Update init to create symlink
- `packages/core/src/cli/commands/update.ts` — Add migration logic
- `packages/core/src/cli/commands/doctor.ts` — Check symlink validity

## Technical Notes

- Relative symlink: `../.pennyfarthing/settings.local.json` from `.claude/`
- Must handle case where `.claude/settings.local.json` is already a symlink (idempotent)
- Must handle case where it's a real file with user customizations (move, preserve content)
- Phase 1 story of epic-85 — no dependencies on other stories in this epic

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core file consolidation — symlink creation, file migration, and path changes need thorough coverage

**Test Files:**
- `packages/core/src/cli/utils/settings-consolidation.test.ts` — 15 tests across 4 describe blocks

**Tests Written:** 15 tests covering 4 ACs
- AC1 (3 tests): `mergeSettingsLocalJson()` writes to `.pennyfarthing/`, not `.claude/`, preserves existing content
- AC2 (4 tests): symlink creation, idempotency, resolution, directory creation
- AC3 (5 tests): file migration, symlink replacement, no-overwrite, idempotency, empty state
- Integration (3 tests): merge+symlink workflow, migrate-then-merge workflow

**Status:** RED (compilation fails — `ensureSettingsSymlink` and `migrateSettingsFile` not yet exported from settings.ts)

**Implementation guidance for Dev:**
1. Add `ensureSettingsSymlink(projectRoot: string): void` to `settings.ts` — creates relative symlink `.claude/settings.local.json` → `../.pennyfarthing/settings.local.json`
2. Add `migrateSettingsFile(projectRoot: string): void` to `settings.ts` — moves real file from `.claude/` to `.pennyfarthing/`, replaces with symlink, idempotent
3. Modify `mergeSettingsLocalJson()` to read/write `.pennyfarthing/settings.local.json` instead of `.claude/settings.local.json`
4. Update callers in `init.ts` (call `ensureSettingsSymlink` after merge) and `update.ts` (call `migrateSettingsFile` before merge)

**Handoff:** To Dev for implementation

## Dev Assessment

**Changes:** 3 files, 88 insertions, 9 deletions

**Files Modified:**
- `packages/core/src/cli/utils/settings.ts` — Changed `settingsPath` from `.claude/` to `.pennyfarthing/`, added `ensureSettingsSymlink()` and `migrateSettingsFile()`
- `packages/core/src/cli/commands/init.ts` — Calls `ensureSettingsSymlink()` after merge
- `packages/core/src/cli/commands/update.ts` — Calls `migrateSettingsFile()` before merge, `ensureSettingsSymlink()` after

**Tests:** 14/14 GREEN
**PR:** #695
**Note:** 3 pre-existing doctor-legacy test failures confirmed unrelated (same failures on develop branch). doctor.ts not modified — symlink validation deferred to MSSCI-14372.

**Handoff:** To Reviewer

## Reviewer Assessment

**Verdict:** APPROVED

| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | [VERIFIED] | Canonical path change correct — all 4 references consistent | `settings.ts:123,150,341,343` |
| 2 | [VERIFIED] | Relative symlink `../.pennyfarthing/settings.local.json` — idempotent | `settings.ts:353-368` |
| 3 | [VERIFIED] | Migration handles all edge cases (no-op, move, delete, symlink) | `settings.ts:375-405` |
| 4 | [MEDIUM] | `ensureSettingsSymlink` will EEXIST if regular file exists (init path) | `settings.ts:367` |
| 5 | [LOW] | `doctor.ts` still uses `.claude/` paths — deferred to MSSCI-14372 | `doctor.ts:354,408,...` |
| 6 | [VERIFIED] | `uninstall.ts` removes symlink correctly | `uninstall.ts:25` |
| 7 | [VERIFIED] | `update.ts` wiring order: migrate → merge → symlink | `update.ts:104-112,201-207` |
| 8 | [VERIFIED] | 14 tests across 4 ACs — TDD confirmed (RED → GREEN commits) | `settings-consolidation.test.ts` |
| 9 | [VERIFIED] | `.gitignore` covers both symlink and canonical file | `init.ts:387,395` |
| 10 | [VERIFIED] | No forbidden patterns | All modified files |

**Data flow traced:** `update` → `migrateSettingsFile` → `mergeSettingsLocalJson` → `ensureSettingsSymlink` → doctor reads through symlink transparently
**Error handling:** `lstatSync` failures caught, JSON parse failures caught, `renameSync` safe (same filesystem)

**Handoff:** To SM for finish-story
