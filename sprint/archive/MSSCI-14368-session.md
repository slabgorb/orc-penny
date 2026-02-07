# Story: MSSCI-14368 — Move project hooks into .pennyfarthing/project

**Story:** MSSCI-14368
**Jira:** MSSCI-14368
**Epic:** MSSCI-14364 (Clean Install Consolidation)
**Workflow:** tdd
**Phase:** approved
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-14368-move-project-hooks
**Sprint:** TO Sprint 2606

## Description

Move project-specific hooks (setup-env.sh etc.) from `.claude/project/` to `.pennyfarthing/project/`. Update settings.local.json hook paths. Clean up `.claude/project/` if empty after migration.

## Acceptance Criteria

- [ ] Project hooks moved from `.claude/project/` to `.pennyfarthing/project/`
- [ ] `settings.local.json` hook paths updated to reference new `.pennyfarthing/project/` location
- [ ] `.claude/project/` cleaned up if empty after migration
- [ ] Existing hook functionality preserved after move
- [ ] `pennyfarthing update` migrates hooks from old to new location
- [ ] `pennyfarthing doctor` detects hooks in old location

## Context

Part of Epic MSSCI-14364 (Clean Install Consolidation). Previous stories already completed in this epic:
- MSSCI-14366: settings.local.json → .pennyfarthing/settings.local.json (with symlink)
- MSSCI-14367: persona-config.yaml → .pennyfarthing/config.local.yaml
- MSSCI-14370: Updated init command
- MSSCI-14371: Updated update command for migration

This story follows the same pattern: move files, update references, add migration logic.

## Key Files

**Core (TypeScript):**
- `packages/core/src/cli/commands/init.ts` — Create hooks at `.pennyfarthing/project/hooks/`
- `packages/core/src/cli/commands/update.ts` — Migrate hooks from old location
- `packages/core/src/cli/utils/settings.ts` — Update hook paths in settings.local.json
- `packages/core/src/cli/commands/doctor.ts` — Detect old hook locations

## Technical Notes

- Hook paths in settings.local.json must be updated atomically (update paths + move files together)
- `setup-env.sh` is referenced in SessionStart hook — path must match
- Check for user-added hooks in `.claude/project/hooks/` that aren't ours
- Migration must be idempotent (safe to re-run on partial migrations)

## Test Strategy

Tests should cover:
1. Hook directory creation at `.pennyfarthing/project/hooks/` during init
2. Hook path updates in settings.local.json (migration from `.claude/` paths to `.pennyfarthing/` paths)
3. File migration from `.claude/project/hooks/` to `.pennyfarthing/project/hooks/`
4. `.claude/project/` cleanup if empty after migration
5. Idempotency (re-running migration doesn't break things)
6. User-added hooks preserved during migration

## SM Assessment

**Setup Complete:** Yes
**Session Created:** .session/MSSCI-14368-session.md
**Branch:** feat/MSSCI-14368-move-project-hooks (pennyfarthing)
**Sprint Status:** in_progress

**Handoff:** To TEA for test design (TDD red phase)

## TEA Assessment

**Tests Required:** Yes
**Test File:** `packages/core/src/cli/commands/hooks-consolidation.test.ts`

**Tests Written:** 20 tests covering 6 ACs (14 pass, 6 RED)
**Status:** RED (6 failing — ready for Dev)

**Failing tests target 3 areas:**
1. `settings.ts` — `migrateHookPaths()` doesn't migrate `.claude/project/hooks/` → `.pennyfarthing/project/hooks/` (AC2)
2. `update.ts` — `migrateTemplateFiles()` doesn't clean up empty `.claude/project/hooks/` or `.claude/project/` after migration (AC3)
3. `doctor.ts` — `checkLegacyFiles()` doesn't detect legacy hooks at `.claude/project/hooks/` (AC6)

**Also needs updating (not tested directly but required):**
- `pennyfarthing-dist/templates/settings.local.json.template` line 51: change `.claude/project/hooks/` to `.pennyfarthing/project/hooks/`
- `doctor.ts` lines 1087, 1178: hard-coded `.claude/project/hooks/setup-env.sh` paths

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/cli/utils/settings.ts` — Added `.claude/project/hooks/` to `LEGACY_PROJECT_HOOK_PATHS` and `migrateHookPaths()`
- `packages/core/src/cli/commands/update.ts` — Added cleanup of empty `.claude/project/hooks/` and `.claude/project/` after migration
- `packages/core/src/cli/commands/doctor.ts` — Added `checkLegacyFiles` detection for legacy project hooks with fix function; updated 2 hard-coded paths
- `pennyfarthing-dist/templates/settings.local.json.template` — Updated setup-env.sh path

**Tests:** 20/20 passing (GREEN)
**PR:** #710 - feat(MSSCI-14368): move project hooks into .pennyfarthing/project
**Branch:** feat/MSSCI-14368-move-project-hooks (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**PR:** #710 — merged to develop, branch deleted

**Data flow traced:** Legacy `.claude/project/hooks/` path in `settings.local.json` → `migrateHookPaths()` string replacement → `.pennyfarthing/project/hooks/` (correct, single occurrence per command string)

**Observations:**
1. [VERIFIED] Cleanup ordering correct — leaf dirs before parent in `dirsToClean` array (`update.ts:445-449`)
2. [VERIFIED] Doctor fix handles both cases: move when dest missing, delete when dest exists (`doctor.ts:1554-1563`)
3. [VERIFIED] Template and both hard-coded doctor paths updated consistently
4. [VERIFIED] No forbidden patterns (console.log, TODO, secrets)
5. [VERIFIED] Test edge cases: idempotency, dry-run, user files preserved, conflict resolution
6. [LOW] Empty catch in cleanup is acceptable — non-blocking operation (`update.ts:458`)
7. [VERIFIED] 20/20 tests passing, no regressions in related consolidation tests (109/109)

**Handoff:** To SM for finish-story
