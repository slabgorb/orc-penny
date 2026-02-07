# MSSCI-14371: Update update command for file migration

**Story:** MSSCI-14371
**Epic:** epic-85 (Clean Install Consolidation)
**Jira:** MSSCI-14371
**Points:** 5
**Priority:** P0
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-14371-update-update-command-file-migration

## Story Context

Update the `pennyfarthing update` command to handle file migration for the new consolidated layout. This is story 1.7 in the Clean Install Consolidation epic.

### Dependencies
- MSSCI-14370 (Update init command) - DONE

### Key Source Files
- `packages/core/src/cli/commands/update.ts` - Update command (primary target)
- `packages/core/src/cli/commands/init.ts` - Init command (already updated in MSSCI-14370)
- `packages/core/src/cli/utils/constants.ts` - DIRECTORY_SYMLINKS, MANAGED_PATHS
- `packages/core/src/cli/utils/symlinks.ts` - Symlink/copy helpers
- `packages/core/src/cli/utils/settings.ts` - settings.local.json merge
- `packages/core/src/cli/utils/manifest.ts` - Manifest handling

### What needs to happen
The update command needs to:
1. Detect files in old locations and migrate them to `.pennyfarthing/`
2. Handle migration of settings.local.json, persona-config.yaml, project hooks, sidecars
3. Update symlinks for the new layout
4. Be idempotent (running update twice should be safe)
5. Maintain backward compatibility during transition

## TEA Assessment

**Tests Required:** Yes
**Reason:** Update command needs significant new migration logic

**Test Files:**
- `packages/core/src/cli/commands/update-consolidation.test.ts` — 41 tests (22 failing, 19 passing)

**Tests Written:** 41 tests covering 10 acceptance criteria areas:
1. **AC1: Manifest migration** (3 tests) — Move manifest from .claude/ to .pennyfarthing/
2. **AC2: Symlinks vs copies** (2 tests) — Use createDirectorySymlink not copyDirectory
3. **AC3: Legacy directory cleanup** (6 tests) — Remove .claude/{agents,guides,personas,scripts}, preserve commands/skills
4. **AC4: Template migration** (8 tests) — Move agent-scopes, setup-env, preferences, persona-config to .pennyfarthing/
5. **AC5: Sidecar migration** (3 tests) — From .claude/project/agents/ and sprint/sidecars/
6. **AC6: Settings migration** (3 tests) — Move settings.local.json, create symlink
7. **AC7: Idempotency** (2 tests) — Safe to run twice
8. **AC8: Dry-run** (2 tests) — No modifications in dry-run mode
9. **AC9: managedPaths** (2 tests) — Updated to reflect .pennyfarthing/ layout
10. **AC10: Project dirs** (2 tests) — Ensure .pennyfarthing/project/* exists

Plus unit tests for migrateSettingsFile (4 tests, all passing) and ensureSettingsSymlink (3 tests, all passing).

**Status:** RED — 22 tests failing, ready for Dev

**Key Implementation Notes for Dev:**
- `updateInstalledContent()` in update.ts uses `copyDirectory()` — replace with `createDirectorySymlink()` from symlinks.ts
- Add `migrateManifest()` function to move .claude/manifest.json → .pennyfarthing/manifest.json
- Add `migrateTemplateFiles()` to move .claude/project/* → .pennyfarthing/project/*
- Add legacy cleanup (same as init.ts lines 147-154) for .claude/{agents,guides,personas,scripts}
- All migrations must respect `dryRun` flag
- Never overwrite files already at new location

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation:** Complete
**Tests:** 41/41 GREEN

**Changes in `update.ts`:**
1. Added `migrateManifest()` — moves `.claude/manifest.json` → `.pennyfarthing/manifest.json` via `renameSync`
2. Added `removeLegacyClaudeDirectories()` — removes `.claude/{agents,guides,personas,scripts}`, preserves commands/skills
3. Added `migrateTemplateFiles()` — moves 5 template files from `.claude/` to `.pennyfarthing/`, never overwrites existing
4. Replaced `copyDirectory()` with `createDirectorySymlink()` in `updateInstalledContent()` for `.pennyfarthing/` dirs
5. All three functions are exported for direct testing and respect `dryRun` flag
6. Migration order in `updateCommand()`: manifest → legacy cleanup → templates → settings → symlinks

**No changes to other files.** All migration functions are idempotent and safe to run repeatedly.

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Tests:** 41/41 GREEN (all pre-existing failures are on develop, unchanged by this branch)
**Build:** Clean

**Data flow traced:** Legacy manifest at `.claude/manifest.json` → `migrateManifest()` checks `existsSync(newPath)` → if absent at `.pennyfarthing/`, `renameSync(oldPath, newPath)` → atomic, idempotent.

**Observations:**

| # | Severity | Issue | Location |
|---|----------|-------|----------|
| 1 | [LOW] | Duplicate calls to migration functions (idempotent, harmless) | update.ts:108-111 + 171-174 |
| 2 | [LOW] | `join(path, '..')` instead of `dirname(path)` for parent | update.ts:433 |
| 3 | [VERIFIED] | Dry-run logging correct | update.ts:355,374,439 |
| 4 | [MEDIUM] | Old file silently removed when both locations exist | update.ts:424-427 |
| 5 | [LOW] | `renameSync` could EXDEV on cross-device (exotic only) | update.ts:353,434 |
| 6 | [VERIFIED] | No path traversal — hardcoded literals | update.ts:388-409 |
| 7 | [VERIFIED] | No TOCTOU — CLI single-user context | update.ts:342-354 |
| 8 | [VERIFIED] | `.claude/commands` and `.claude/skills` preserved | update.ts:367 |
| 9 | [VERIFIED] | `shared-context.md` left untouched | test line ~465 |
| 10 | [VERIFIED] | Good pattern: never-overwrite semantics | update.ts:423 |

**Error handling:** Migration functions guard with `existsSync` before `renameSync`/`unlinkSync`. `removeSymlinkOrDirectory` in symlinks.ts has fallback from `unlinkSync` to `removeSync`. Acceptable.

**Security:** All paths are hardcoded string constants. No user input flows into file operations. No injection vectors.

**Pattern observed:** Clean separation of migration concerns into individual exported functions (`migrateManifest`, `removeLegacyClaudeDirectories`, `migrateTemplateFiles`) with consistent `{ dryRun }` options pattern at update.ts:334-442.

**Handoff:** To SM for finish-story

## Log
- Setup: Story created, branch pending
- Handoff: SM → TEA for red phase (TDD workflow)
- TEA: Wrote 41 tests (22 RED), committed to branch
- Handoff: TEA → Dev for implement phase
- Dev: Implemented 3 migration functions, replaced copyDirectory with symlinks, 41/41 GREEN
- Handoff: Dev → Reviewer for review phase
- Reviewer: APPROVED — no Critical/High issues. Push, create PR, merge.
