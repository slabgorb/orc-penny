# Story 117-2: Generate hook commands with pf.sh wrapper path, not bare pf

**Jira:** PROJ-15312
**Epic:** 117 — Consumer Install — Fix v11.x postinstall gaps
**Points:** 2
**Priority:** P0
**Workflow:** tdd-tandem
**Phase:** finish
**Branch:** feature/117-2-pf-wrapper-hooks
**Repos:** pennyfarthing

## Description

settings.local.json hook generation writes bare `pf` commands which are not in PATH. The pf CLI is only available via `uv run` or the `pf.sh` wrapper. Generate hooks using the pf.sh wrapper path instead: `$CLAUDE_PROJECT_DIR/.pennyfarthing/scripts/core/pf.sh hooks <subcommand>`.

## Acceptance Criteria

- [ ] Hook generation uses `$CLAUDE_PROJECT_DIR/.pennyfarthing/scripts/core/pf.sh` wrapper path instead of bare `pf`
- [ ] Generated settings.local.json hooks work without `pf` being in PATH
- [ ] Existing hook functionality preserved

## Epic Context

This epic addresses critical postinstall and hook generation issues that break consumer installations of pennyfarthing v11.x. The framework bundles Python hooks and scripts, but the install/setup process is incomplete:

1. No `pyproject.toml` shipped in npm package — consumers must manually create one to run hooks
2. **Hook commands generated with bare `pf` instead of wrapper path — not in PATH during installation** (this story)
3. Stale artifacts from v8-10.x upgrades left in place — conflicts and clutter
4. Generated hook scripts created with wrong permissions — causes immediate failures on session start

Story 117-1 (Ship pyproject.toml) ships a template and auto-generates it during postinstall. This story (117-2) ensures the hook commands themselves use the correct wrapper path.

**Key files:**
- Hook generation: likely in `pennyfarthing-dist/scripts/hooks/` or settings-related modules

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core hook migration logic has a gap — bare `pf hooks X` commands aren't migrated

**Test Files:**
- `packages/core/src/cli/utils/settings-hook-migration.test.ts` — 21 tests covering all 3 ACs

**Tests Written:** 21 tests covering 3 ACs
**Status:** RED (15 failing, 6 passing — ready for Dev)

**Key Findings:**
- `migrateHookPaths()` in `settings.ts:122-163` only migrates `.sh` file hooks to `pf.sh`. It does NOT handle bare `pf hooks X` → `pf.sh hooks X`.
- `mergeSettingsLocalJson()` detects bare `pf hooks X` as "already configured" (lines 242, 283, 303) and skips migration.
- `statusLine` migration (line 373) doesn't handle bare `pf hooks statusline`.
- Fix location: `packages/core/src/cli/utils/settings.ts` — `migrateHookPaths()` needs bare `pf` → `pf.sh` migration entries, and statusLine migration needs a bare `pf` check.

**Handoff:** To Dev (Sergeant Carter) for implementation

## Technical Approach

Fix in `packages/core/src/cli/utils/settings.ts`:
1. Add bare `pf hooks X` → `pf.sh hooks X` migration to `migrateHookPaths()`
2. Add bare `pf hooks statusline` → `pf.sh hooks statusline` migration to statusLine handling
3. Ensure migration runs BEFORE the "already configured" checks in `mergeSettingsLocalJson()`

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/cli/utils/settings.ts` — Added bare `pf hooks X` → `pf.sh hooks X` migration in `migrateHookPaths()` and fixed statusLine migration

**Tests:** 21/21 passing (GREEN) + 73 existing tests pass (no regressions)
**Branch:** feature/117-2-pf-wrapper-hooks (pushed)

**Changes:**
1. `migrateHookPaths()`: Added check for commands starting with `pf hooks ` (without `pf.sh`), replaces with full `$CLAUDE_PROJECT_DIR/.pennyfarthing/scripts/core/pf.sh hooks X` path
2. StatusLine migration: Moved bare `pf hooks statusline` check before legacy path loop so it gets migrated instead of being treated as "already configured"

**Self-Review:**
- [x] Code follows project patterns (same migration pattern as existing `.sh` migration)
- [x] All acceptance criteria met
- [x] Tests passing (not skipped!)
- [x] No console.log or debug code
- [x] Minimal change — 15 lines added, 2 lines changed

**Handoff:** To Reviewer (General Burkhalter)

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** Consumer `settings.local.json` with bare `pf hooks X` → `mergeSettingsLocalJson()` → `migrateHookPaths()` → command rewritten to `$CLAUDE_PROJECT_DIR/.pennyfarthing/scripts/core/pf.sh hooks X` (safe — no user input in path)

**Pattern observed:** Migration follows existing `.sh` → `pf.sh` pattern at `settings.ts:130-140`, new bare `pf` → `pf.sh` migration added at same priority level with correct guards at `settings.ts:142-148`

**Error handling:** `startsWith('pf hooks ')` with trailing space prevents false matches; `!includes('pf.sh')` prevents double-migration; null/undefined hooks filtered by parent `typeof === 'object'` check at `settings.ts:125`

**Observations:**
- [VERIFIED] Migration guard prevents double-migration at `settings.ts:142`
- [VERIFIED] StatusLine bare `pf` fix correctly restructures condition at `settings.ts:380`
- [VERIFIED] 94/94 tests pass (21 new + 73 existing, zero regressions)
- [VERIFIED] No security concerns — static string replacement
- [LOW] JSDoc at `settings.ts:120` says "to pf hooks commands" should say "to pf.sh hooks commands" — non-blocking

**Handoff:** To SM for finish-story

## Session Log

- **Setup:** Session created, branch ready
  - Claimed PROJ-15312 in Jira
  - Updated sprint status to in_progress
  - Created feature branch: `feature/117-2-pf-wrapper-hooks`
  - Read epic context