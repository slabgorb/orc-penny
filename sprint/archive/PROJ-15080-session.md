# Story 98-22: v11 migration automation — detect and remove old multi-package installs

**Status:** in-progress
**Phase:** finish
**Workflow:** tdd
**Jira:** PROJ-15080
**Branch:** feature/98-22-v11-migration-automation
**Repos:** pennyfarthing
**Epic:** 98 — Safe Install, Upgrade, and Namespace Isolation

## Acceptance Criteria

- AC1: Migration file `010-detect-remove-old-packages.js` exists in `pennyfarthing-dist/migrations/` with correct exports (`id`, `description`, `up`, `check`)
- AC2: `check()` detects old packages (`@pennyfarthing/shared`, `@pennyfarthing/cyclist`, `@pennyfarthing/benchmark`) in `node_modules/` — returns `false` if any found, `true` if clean
- AC3: `up()` removes old package directories from `node_modules/@pennyfarthing/` (shared, cyclist, benchmark)
- AC4: `up()` respects `ctx.dryRun` — logs what would be removed without deleting
- AC5: `up()` logs removal actions via `ctx.logger`
- AC6: `check()` and `up()` handle missing `node_modules/` gracefully (no crash on fresh installs)
- AC7: Migration integrates with existing runner — auto-discovered by `listMigrationFiles()` and executed by `pennyfarthing update`

## Technical Context

This story is part of Epic 98, which focuses on safe install/upgrade paths and namespace isolation. The v11 migration automation specifically targets detection and removal of old multi-package installs from the pre-monorepo era when Pennyfarthing was split into separate packages (core, shared, cyclist, themes).

Key context:
- Previous architecture had `@pennyfarthing/core`, `@pennyfarthing/shared`, `@pennyfarthing/cyclist`, and individual theme packages
- Story 98-16 absorbed shared and benchmark packages into core
- Story 98-17 moved web server and API layer into core
- Story 98-18 moved React UI build and static assets into core
- v11 introduces monorepo structure with packages/* workspace

The migration automation needs to:
1. Detect users who have old multi-package installations
2. Provide automated cleanup/migration path to v11 single-package structure
3. Integrate with the versioned migration runner infrastructure (story 98-2)

## Files of Interest

- `pennyfarthing/packages/core/src/cli/commands/update.ts` — update command entry point
- `pennyfarthing/packages/core/src/migrations/` — migration runner infrastructure
- `pennyfarthing/packages/core/src/cli/commands/uninstall.ts` — uninstall logic
- `pennyfarthing/packages/core/src/cli/commands/doctor.ts` — diagnostic checks
- `pennyfarthing/pennyfarthing-dist/scripts/` — distributed scripts
- ADR 0021 — safe install/upgrade decisions

## Development Notes

- Use migration runner infrastructure from story 98-2
- Return result objects `{success, data?, error?}` instead of throwing
- Follow pnpm monorepo patterns
- Ensure backward compatibility with existing installations

## TEA Assessment

**Tests Required:** Yes
**Test File:** `packages/core/src/cli/utils/010-detect-remove-old-packages.test.ts`
**Tests Written:** 24 tests covering 7 ACs
**Status:** RED (11 failing, 13 passing — stub in place)

**Failing tests by AC:**
- AC2: 4 tests — `check()` always returns true (doesn't detect old packages)
- AC3: 4 tests — `up()` doesn't remove any directories
- AC4: 1 test — no dry-run logging
- AC5: 2 tests — no logging at all

**Passing tests (stub contract):**
- AC1: 4 tests — file exports exist with correct types
- AC6: 3 tests — stub gracefully handles missing node_modules (returns true/success)
- AC7: 2 tests — file discovered by migration runner

**Key implementation notes for Dev:**
- Stub at `pennyfarthing-dist/migrations/010-detect-remove-old-packages.js` — implement `check()` and `up()`
- Type declarations at `pennyfarthing-dist/migrations/010-detect-remove-old-packages.d.ts` (already correct)
- Follow migration 009 pattern (uses `existsSync`, `rmSync` from 'fs')
- Old packages to detect: `@pennyfarthing/shared`, `@pennyfarthing/cyclist`, `@pennyfarthing/benchmark`
- Must NOT remove `@pennyfarthing/core`
- `check()`: return `false` if old packages found, `true` if clean
- `up()`: remove old package dirs, respect `ctx.dryRun`, log via `ctx.logger`
- Run tests: `cd packages/core && pnpm build && node --test dist/cli/utils/010-detect-remove-old-packages.test.js`

**Handoff:** To Dev for implementation (GREEN phase)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/migrations/010-detect-remove-old-packages.js` — full migration implementation (check + up)
- `pennyfarthing-dist/migrations/010-detect-remove-old-packages.d.ts` — type declarations (created by TEA)
- `packages/core/src/cli/utils/010-detect-remove-old-packages.test.ts` — 24 tests (created by TEA)

**Tests:** 24/24 passing (GREEN)
**PR:** #903 — feat(98-22): v11 migration — detect and remove old multi-package installs
**Branch:** feature/98-22-v11-migration-automation (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** projectRoot → node_modules/@pennyfarthing/{pkg} → existsSync guard → rmSync (safe — ctx.projectRoot controlled by migration runner)
**Pattern observed:** Follows migration 009 pattern — bare catch, existsSync guard, `{success: true}` result contract at `010-detect-remove-old-packages.js`
**Error handling:** try/catch at line 59-64, existsSync guards at lines 26,46,55. Graceful on missing dirs (AC6).
**Tests:** 24/24 passing, no regressions in core suite (pre-existing failures verified on main)
**Non-blocking notes:** [MEDIUM] Bare catch discards error info at line 62 (consistent with 009). [LOW] removed counter semantics differ slightly from 009.
**Handoff:** To SM for finish-story

## SM Assessment

- Story setup complete, session created, Jira claimed
- TDD workflow: routing to TEA for test design (red phase)
- 3-point story covering v11 migration automation
- Branch: feature/98-22-v11-migration-automation in pennyfarthing repo
