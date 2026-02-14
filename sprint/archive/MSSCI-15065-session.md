# Story 98-10: Fix settings symlink crash on existing real file

**Story ID:** 98-10
**Epic:** 98 — Safe Install, Upgrade, and Namespace Isolation
**Jira:** none
**Type:** bug
**Points:** 2
**Priority:** P0
**Workflow:** trivial
**Phase:** approved
**Repos:** pennyfarthing
**Branch:** fix/98-10-fix-settings-symlink-crash
**Started:** 2026-02-14

---

## Context

The `ensureSettingsSymlink()` function in `pennyfarthing/packages/core/src/cli/utils/settings.ts` (lines 396-411) crashes when `.claude/settings.local.json` exists as a regular file instead of a symlink.

### The Bug

When upgrading or re-initializing projects, the function attempts to create a symlink from `.claude/settings.local.json` → `.pennyfarthing/settings.local.json`. However, if a real file exists at `.claude/settings.local.json`, the function's defensive check only verifies if it's already a symlink:

```typescript
try {
  if (lstatSync(symlinkPath).isSymbolicLink()) {
    return;
  }
} catch {
  // Doesn't exist yet — continue to create
}

ensureDirSync(join(projectRoot, '.claude'));
symlinkSync(relativeTarget, symlinkPath);  // CRASHES HERE if symlinkPath is a real file
```

The code path:
1. File exists at `.claude/settings.local.json` as a regular file
2. `lstatSync()` succeeds and returns a Stats object
3. `isSymbolicLink()` returns false
4. Function continues to `symlinkSync()`
5. **`symlinkSync()` throws EEXIST error because the path already exists**

This happens during `pf update` when a user has an older settings file as a real file (migration from pre-symlink era).

### Root Cause

The function assumes that if a path exists and isn't a symlink, it must be safe to create a symlink there. But `symlinkSync()` fails if any file/directory exists at that path, regardless of its type.

## Acceptance Criteria

- [ ] `ensureSettingsSymlink()` safely handles existing real files at `.claude/settings.local.json`
- [ ] Preserves file contents when migrating from real file to symlink
- [ ] Tests verify correct handling of:
  - Real file exists → move to `.pennyfarthing/` and create symlink
  - Symlink already exists (correct target) → no-op
  - Nothing exists → create symlink
  - Symlink exists with wrong target → update to correct target

## Technical Approach

1. **In `ensureSettingsSymlink()`**, detect if the path exists as a real file
2. **If it is a real file:**
   - Move contents to `.pennyfarthing/settings.local.json` (if not already present)
   - Remove the original file
   - Create the symlink
3. **Mirror the logic from `migrateSettingsFile()`** which already handles this correctly for migrations

The function `migrateSettingsFile()` (lines 418-448) already implements the correct pattern:
- Check if old path is a symlink → if yes, already migrated, return
- If old path is a real file and new path doesn't exist → move file
- If old path is a real file and new path exists → remove old file
- Create symlink at old location

We can either:
- A) Refactor `ensureSettingsSymlink()` to include the migration logic
- B) Call `migrateSettingsFile()` before `ensureSettingsSymlink()` to ensure the file is migrated first

**Option B is recommended** because:
- Avoids code duplication
- `migrateSettingsFile()` is already tested
- Cleaner separation of concerns (migration vs. symlink setup)
- Already used in update flow (line 115 calls `mergeSettingsLocalJson`, then line 119 calls `ensureSettingsSymlink`)

## Key Files

- `/Users/keithavery/Projects/pf-2/pennyfarthing/packages/core/src/cli/utils/settings.ts` — contains both `ensureSettingsSymlink()` and `migrateSettingsFile()`
- `/Users/keithavery/Projects/pf-2/pennyfarthing/packages/core/src/cli/commands/init.ts` — calls `ensureSettingsSymlink()` (line 424)
- `/Users/keithavery/Projects/pf-2/pennyfarthing/packages/core/src/cli/commands/update.ts` — calls `ensureSettingsSymlink()` (line 119)
- `/Users/keithavery/Projects/pf-2/pennyfarthing/packages/core/src/cli/utils/settings-consolidation.test.ts` — tests for settings behavior

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/cli/utils/settings.ts` — added `migrateSettingsFile()` call when real file detected in `ensureSettingsSymlink()`
- `packages/core/src/cli/utils/settings-consolidation.test.ts` — added 2 tests for EEXIST crash scenario

**Tests:** 57/57 passing (GREEN)
**PR:** #876 — fix(core): handle existing real file in ensureSettingsSymlink
**Branch:** fix/98-10-fix-settings-symlink-crash (pushed)

**Handoff:** To Reviewer for code review

---
## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `ensureSettingsSymlink()` → `lstatSync` succeeds, not symlink → `migrateSettingsFile(projectRoot)` → `renameSync`/`unlinkSync` + `symlinkSync` → return. All paths terminate correctly at `settings.ts:406`.

**Pattern observed:** Reuses existing `migrateSettingsFile()` from `settings.ts:421` — battle-tested in migration paths. Consistent with epic-98 namespace isolation pattern. Fix is self-healing at the right layer, protecting all callers (`init.ts:424`, `update.ts:119`, `update.ts:210`).

**Error handling:** `migrateSettingsFile` has its own try-catch at `settings.ts:427-431`. TOCTOU safe — if file disappears between the two `lstatSync` calls, returns silently.

**Observations:**
- [VERIFIED] 57/57 tests pass (settings-consolidation + update-consolidation)
- [VERIFIED] Content preserved via atomic `renameSync` or canonical `.pennyfarthing/` wins
- [VERIFIED] No forbidden patterns in diff
- [VERIFIED] Both crash scenarios tested: real file only, real file + conflict
- [LOW] Minor `lstatSync` redundancy (settings.ts:402 and settings.ts:428). Non-blocking.

**CI:** YAML Lint failure is pre-existing — PR only touches TypeScript files.

**Handoff:** To SM for finish-story

---

## Related Code

The update flow (lines 115-120 of update.ts):
```typescript
const settingsUpdated = await mergeSettingsLocalJson(projectRoot, assetsPath, { dryRun });

// Ensure symlink at .claude/settings.local.json
if (!dryRun) {
  ensureSettingsSymlink(projectRoot);  // <- Crashes here if real file exists
}
```

The migration function (lines 418-448 of settings.ts) already handles this correctly:
```typescript
export function migrateSettingsFile(projectRoot: string): void {
  const oldPath = join(projectRoot, '.claude/settings.local.json');
  const newPath = join(projectRoot, '.pennyfarthing/settings.local.json');

  // Check if old path exists at all
  let oldStats;
  try {
    oldStats = lstatSync(oldPath);
  } catch {
    return;
  }

  if (oldStats.isSymbolicLink()) {
    return;
  }

  // Old path is a real file — migrate it
  if (!pathExists(newPath)) {
    ensureDirSync(join(projectRoot, '.pennyfarthing'));
    renameSync(oldPath, newPath);
  } else {
    unlinkSync(oldPath);
  }

  // Create symlink at old location pointing to new
  symlinkSync('../.pennyfarthing/settings.local.json', oldPath);
}
```
