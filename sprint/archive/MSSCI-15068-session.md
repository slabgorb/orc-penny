# Story 98-13: Cleanup migration for backward-compat symlinks

**Jira:** MSSCI-15068
**Epic:** Safe Install, Upgrade, and Namespace Isolation
**Points:** 2
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/98-13-cleanup-backward-compat-symlinks

---
## Context

This story is part of Epic 98, which redesigns the install/upgrade path to prevent data loss, automate post-update setup, add versioned migrations, namespace skills/commands with pf- prefix, and integrate sprint shard migration.

Story 98-13 focuses on cleaning up backward-compatibility symlinks. The epic has already completed several core infrastructure stories (98-9 through 98-12) that fixed uninstall data loss, settings symlink crashes, implemented shared merge models, and added git hook chaining. With this cleanup story, we need to remove or migrate obsolete symlinks that were maintained for backward compatibility during the multi-step framework refactoring.

This is a chore/maintenance task that tidies up migration artifacts now that the framework is more stable.

## Acceptance Criteria

- Identify backward-compat symlinks currently in place
- Create a versioned migration that removes/updates these symlinks safely
- Ensure existing installations can apply the migration without data loss
- Document the rationale for removal
- Update any references in initialization code

## Technical Approach

The work will likely involve:

- Reviewing `packages/core/src/` CLI initialization code (init.ts, update.ts) to understand current symlink strategy
- Checking `pennyfarthing-dist/` for any symlinked assets or configurations
- Adding a new migration file to the migration infrastructure (set up in earlier stories)
- Testing on fresh and existing installations to verify the cleanup path works correctly
- Updating CLAUDE.md or related docs if symlink behavior changes

---
## SM → Dev Handoff

**Handoff:** SM (Colonel Hogan) → Dev (Sergeant Carter)
**Phase:** setup → implement
**Workflow:** trivial
**Date:** 2026-02-15

**Instructions for Dev:**
- This is a 2-point chore to clean up backward-compatibility symlinks
- Review the migration infrastructure from earlier epic 98 stories
- Identify and remove/update obsolete symlinks
- Create a versioned migration if needed
- Test on fresh and existing installations

---
## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/migrations/009-remove-backward-compat-symlinks.js` - Migration that removes backward-compat symlinks created by 007

**Tests:** 19/19 migration runner tests passing (GREEN), plus manual E2E validation
**PR:** #902 - feat(98-13): remove backward-compat symlinks for pf-prefix migration
**Branch:** feature/98-13-cleanup-backward-compat-symlinks (pushed)

**Implementation Details:**
- Migration 009 uses same OLD_SKILL_NAMES and OLD_COMMAND_NAMES lists from 007
- `isBackwardCompatSymlink()` verifies entry is a symlink AND its target is `pf-{name}` — won't touch real files
- `check()` returns true when no backward-compat symlinks remain (idempotent)
- Init/update code already filters for `pf-` prefix only — won't recreate old symlinks
- Note: Story 98-7 (backlog) handles updating agent/workflow references to use pf- prefixed names

**Handoff:** To Reviewer for code review

---
## Reviewer Assessment

**Verdict:** APPROVED

| Severity | Observation | Location |
|----------|-------------|----------|
| [LOW] | Unused import: `readdirSync` imported but never called | `009:12` |
| [LOW] | `up()` returns `{success: true}` on partial failure — matches 007 pattern | `009:102` |
| [VERIFIED] | List parity: OLD_SKILL_NAMES (20) and OLD_COMMAND_NAMES (47) character-identical to 007 | `009:19-41` vs `007:19-42` |
| [VERIFIED] | Safety: `isBackwardCompatSymlink()` double-checks isSymbolicLink + target match | `009:47-56` |
| [VERIFIED] | No re-creation: init/update filters for `pf-` prefix only | `symlinks.ts:124,202` |
| [VERIFIED] | Migration contract compliance: id, description, up(), check() | `009:15-16,58,105` |
| [VERIFIED] | Idempotency via check() | `009:105-127` |
| [VERIFIED] | Dry-run support correct | `009:75-76` |

**Data flow traced:** runner → check() → up() → isBackwardCompatSymlink() per entry → unlinkSync() only for confirmed compat symlinks. Clean.
**Error handling:** Silent catch on unlinkSync failure — matches 007 pattern, acceptable for symlink cleanup.

**Handoff:** To SM for finish-story
