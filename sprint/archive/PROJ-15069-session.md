# Story 98-14: Remove dead copy-mode code paths

**Status:** in-progress
**Jira:** PROJ-15069
**Workflow:** trivial
**Phase:** finish
**Branch:** feat/98-14-remove-dead-copy-mode-code-paths
**Repos:** orchestrator, pennyfarthing
**Epic:** 98 (PROJ-14697) — Safe Install, Upgrade, and Namespace Isolation
**Started:** 2026-02-14

---

## Story Context

**Type:** refactor
**Points:** 2
**Priority:** p2

### Background

The install/upgrade system has transitioned from copy-based installations to symlink-based installations. During the transition (story 98-6: Protective symlink pre-flight checks), copy-mode code paths were preserved as fallback for backward compatibility with older installations that had data in copied form.

Now that all users have migrated to the symlink model, these dead code paths can be safely removed:

1. `copyDirectory()` — deprecated function marked in symlinks.ts line 287
2. `copyCommandsDirectory()` — copy-based variant in symlinks.ts (lines 317-382)
3. `copySkillsDirectory()` — copy-based variant in symlinks.ts (lines 388-459)

### Acceptance Criteria

- [ ] Remove `copyDirectory()` function from symlinks.ts
- [ ] Remove `copyCommandsDirectory()` function from symlinks.ts
- [ ] Remove `copySkillsDirectory()` function from symlinks.ts
- [ ] Remove all imports of copy functions from init.ts and update.ts
- [ ] All references now use `createDirectorySymlink()`, `createCommandsDirectory()`, and `createSkillsDirectory()`
- [ ] No breaking changes to public exports or test suites
- [ ] Build passes without warnings

### Technical Approach

**Files to modify:**

1. `/pennyfarthing/packages/core/src/cli/utils/symlinks.ts` — Remove 3 copy functions (copyDirectory, copyCommandsDirectory, copySkillsDirectory)
2. `/pennyfarthing/packages/core/src/cli/commands/init.ts` — Remove copyDirectory/copyCommandsDirectory/copySkillsDirectory imports, verify createDirectorySymlink usage
3. `/pennyfarthing/packages/core/src/cli/commands/update.ts` — Same as init.ts

**Scope:** This is a pure refactoring removal of dead code. The create-based functions are already in place and being used. This story simply removes the unused copy variants that were kept for backward compatibility.

### Code Locations

**Current copy-mode code:**
- `symlinks.ts:289-311` — `copyDirectory()` (generic, deprecated)
- `symlinks.ts:317-382` — `copyCommandsDirectory()` (copy-based, should remove)
- `symlinks.ts:388-459` — `copySkillsDirectory()` (copy-based, should remove)

**Comments indicating copy-mode migration:**
- `symlinks.ts:18` — "Handles both symlinks and directories (for migration from copy mode)"
- `symlinks.ts:268` — "Remove existing symlink or directory (migration from copy mode)"

**Active functions (to keep):**
- `createDirectorySymlink()` — symlinks.ts:259-282
- `createCommandsDirectory()` — symlinks.ts:100-252
- `createSkillsDirectory()` — symlinks.ts:100-252 (search for definition)
- `cleanManagedEntries()` — symlinks.ts:68-94
- `needsCommandsMigration()` — symlinks.ts:464-467
- `needsSkillsMigration()` — symlinks.ts:472-475

---

## Files

- `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/core/src/cli/utils/symlinks.ts`
- `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/core/src/cli/commands/init.ts`
- `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/core/src/cli/commands/update.ts`

## Assessment

- **Dev tasks:** Remove 3 functions + clean up imports
- **Tests:** Should verify no build errors and all existing tests pass
- **Risk:** Low — only removing unused code, no behavior change

---

## Session Notes

### Setup — 2026-02-14

- Story 98-14 claimed and marked in_progress in epic-PROJ-14697.yaml
- Feature branches created:
  - orchestrator: `feat/98-14-remove-dead-copy-mode-code-paths`
  - pennyfarthing: `feat/98-14-remove-dead-copy-mode-code-paths`
- Analyzed copy-mode code paths — identified 3 functions to remove
- Created session file with acceptance criteria and technical approach
- Workflow: trivial (SM → Dev → Reviewer → SM)

### SM Assessment — 2026-02-14

Clean 2-point refactor. Dead code removal with no behavioral changes. Korben Dallas should have a quick ride — remove three functions, clean up imports, verify build passes. Low risk, well-scoped.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/cli/utils/symlinks.ts` — Removed `copyDirectory()`, `copyCommandsDirectory()`, `copySkillsDirectory()` and unused imports (`copyFileSync`, `copySync`)
- `packages/core/src/cli/commands/init.ts` — Swapped `copyCommandsDirectory` → `createCommandsDirectory`, `copySkillsDirectory` → `createSkillsDirectory`
- `packages/core/src/cli/commands/update.ts` — Same import/call swaps as init.ts

**Tests:** Pre-existing failures only (theme-detail, variable-resolver, workflow-migration) — none related to changes
**PR:** #883 — refactor(98-14): remove dead copy-mode code paths
**Branch:** feat/98-14-remove-dead-copy-mode-code-paths (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** CLI init/update → createCommandsDirectory/createSkillsDirectory → symlinks in .claude/commands and .claude/skills (install-time only, no user data)
**Pattern observed:** Clean function signature match between removed copy variants and retained create variants at `symlinks.ts:100` and `symlinks.ts:176`
**Error handling:** Create functions retain identical try-catch + logger.warning patterns as copy variants — no regression
**Security:** No user input, no external data. Install-time filesystem operations only.
**Copy-mode gate:** `update.ts:94-101` already blocks copy-mode installations — removed functions were unreachable

**Handoff:** To SM for finish-story
