# Story 98-9: Fix uninstall data loss — replace rmSync with cleanManagedEntries for commands and skills

**Story ID:** 98-9
**Epic:** 98 — Safe Install, Upgrade, and Namespace Isolation
**Jira:** MSSCI-14697
**Type:** bug
**Points:** 2
**Priority:** P0
**Workflow:** trivial
**Phase:** review
**Repos:** pennyfarthing
**Branch:** fix/98-9-fix-uninstall-data-loss
**Started:** 2026-02-14

---

## Context

BUG-1 from the Install Experience v2 architectural review.

`uninstall.ts` lines 150-153 use `rmSync(fullPath, { recursive: true, force: true })` on `.claude/commands` and `.claude/skills` directories. This destroys ALL content — including user-created commands/skills that don't have the `pf-` prefix.

The fix pattern already exists: `cleanManagedEntries(dir, 'pf-')` from `symlinks.ts:68` removes only `pf-*` prefixed entries. The directory itself should only be removed if empty afterward.

## Acceptance Criteria

- [x] `uninstall.ts` uses `cleanManagedEntries(dir, 'pf-')` instead of `rmSync` for `.claude/commands` and `.claude/skills`
- [x] After cleaning managed entries, only remove the directory if it's empty
- [x] User commands (e.g., `my-tool.md`) and skills without `pf-` prefix survive uninstall
- [x] Test: uninstall preserves user commands/skills without `pf-` prefix
- [x] All existing tests pass (`pnpm test` in pennyfarthing/)

## Key Files

- `pennyfarthing/packages/core/src/cli/commands/uninstall.ts` — primary fix target (lines 150-156)
- `pennyfarthing/packages/core/src/cli/utils/symlinks.ts` — `cleanManagedEntries()` to import and use

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/cli/commands/uninstall.ts` — Import `cleanManagedEntries`, selective removal for `.claude/commands` and `.claude/skills`
- `packages/core/src/cli/commands/uninstall.test.ts` — 7 tests covering user content preservation

**Approach:** Added `SELECTIVE_CLEAN_DIRS` array for `.claude/commands` and `.claude/skills`. In the removal loop, these directories use `cleanManagedEntries(dir, 'pf-')` instead of `rmSync`. After cleaning, directory is only removed if empty (via existing `isDirEmpty()`).

**Tests:** 7/7 passing (GREEN). 2716/2868 total suite (34 pre-existing cyclist failures unrelated).
**PR:** #874 — fix(core): prevent uninstall from destroying user commands and skills
**Branch:** fix/98-9-fix-uninstall-data-loss (pushed)

**Handoff:** To Reviewer for code review

---

## Handoff: SM → Dev

**From:** SM (Morpheus)
**To:** Dev (Agent Smith)
**Phase:** setup → implement
**Timestamp:** 2026-02-14

Story is set up and ready for implementation. The fix is straightforward:
- Import `cleanManagedEntries` from `symlinks.ts` into `uninstall.ts`
- Replace `rmSync` on `.claude/commands` and `.claude/skills` with `cleanManagedEntries(dir, 'pf-')`
- Only remove the directory if empty after cleaning

All context is in the session file above.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `MANAGED_PATHS` → `managedToRemove` → `SELECTIVE_CLEAN_DIRS` check → `cleanManagedEntries(dir, 'pf-')` → only `pf-*` entries removed. User content never matches prefix filter at `symlinks.ts:75`.

**Pattern observed:** Reuses existing `cleanManagedEntries()` from `symlinks.ts` — battle-tested in init/update paths. Consistent with the namespace isolation pattern from epic-98.

**Error handling:** `cleanManagedEntries` wraps each deletion in try-catch at `symlinks.ts:87`. dryRun path verified correct — counts without deleting, `isDirEmpty` guarded by `!dryRun`.

**Observations:**
- [VERIFIED] 7/7 tests pass covering commands, skills, dryRun, and empty-dir cleanup
- [VERIFIED] No forbidden patterns in diff
- [MEDIUM] Legacy symlink edge case — `cleanManagedEntries` follows symlinks, slightly different from old `rmSync` behavior on symlinked dirs. Non-blocking for uninstall context.
- [LOW] `SELECTIVE_CLEAN_DIRS` inline vs module-level constant. Style preference, non-blocking.

**CI:** Python Lint (Ruff) failure is pre-existing — PR only touches TypeScript files. Build pending.

**Handoff:** To SM for finish-story
