# Story 98-2: Versioned migration runner infrastructure

**Jira:** PROJ-14699
**Epic:** epic-98 (Safe Install, Upgrade, and Namespace Isolation)
**Points:** 5
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/PROJ-14699-versioned-migration-runner
**Assigned:** slabgorb@gmail.com
**Started:** 2026-02-12

---

## Description

Create `pennyfarthing-dist/migrations/` directory with numbered migration files. Each exports `{id, description, up(), down?(), check()}`. Add `migrationsRun` field to manifest. Migration runner scans for pending, runs in order, updates manifest. Replaces scattered inline code in `update.ts`.

## Acceptance Criteria

- [ ] `pennyfarthing-dist/migrations/` directory exists with migration file convention
- [ ] Migration file exports: `{id: string, description: string, up(ctx): Promise<Result>, down?(ctx): Promise<Result>, check(ctx): Promise<boolean>}`
- [ ] Migration runner scans `migrations/` for pending migrations (not in manifest.migrationsRun)
- [ ] Runner executes pending migrations in numeric order
- [ ] `manifest.json` updated with `migrationsRun: string[]` tracking completed migration IDs
- [ ] `check()` function verifies if migration was already applied (idempotency guard)
- [ ] Migration context provides `projectRoot`, `logger`, `dryRun` flag
- [ ] At least one example migration file demonstrating the convention
- [ ] `pennyfarthing update` calls migration runner after content update
- [ ] Dry-run mode skips actual migration execution but logs what would run

## Key Files

- `pennyfarthing/packages/core/src/cli/commands/update.ts` — update command (wire migration runner)
- `pennyfarthing/packages/core/src/cli/utils/manifest.ts` — manifest utilities (add migrationsRun field)
- `pennyfarthing/packages/core/src/cli/utils/migrations.ts` — migration runner (NEW)
- `pennyfarthing/pennyfarthing-dist/migrations/` — migration files directory (NEW)

## Technical Notes

- Migration IDs should be numeric-prefixed for ordering (e.g., `001-initial-setup.ts`)
- Runner uses `manifest.migrationsRun` as applied-set, not filesystem state
- `check()` enables idempotency — safe to re-run migrations
- Context object pattern matches existing `{dryRun}` options throughout codebase

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** TDD workflow — migration runner is core infrastructure with multiple failure modes

**Test Files:**
- `packages/core/src/cli/utils/migrations.test.ts` — 19 tests (17 failing, 2 type-check pass)

**Stub Files:**
- `packages/core/src/cli/utils/migrations.ts` — MigrationContext, MigrationResult, Migration, RunMigrationsResult types + listMigrationFiles, getPendingMigrations, runMigrations stubs

**Tests Written:** 19 tests covering all 10 ACs
- AC1: listMigrationFiles — file discovery, sorting, non-JS filtering, missing dir (3 tests)
- AC2: Migration type contract — required fields, optional down() (2 tests)
- AC3: getPendingMigrations — filter applied, all applied, none applied (3 tests)
- AC4: Numeric ordering — execution order enforcement (1 test)
- AC5: Manifest tracking — applied IDs returned, preserves existing (2 tests)
- AC6: Idempotency — check() true skips, check() false runs (2 tests)
- AC7: Context injection — projectRoot, dryRun, logger (3 tests)
- AC8: Example migration — validated by convention tests
- AC9: update.ts wiring — implicit via runner integration
- AC10: Dry-run — no up() calls, logs what would run (2 tests)
- Failure handling — stops on first failure (1 test)

**Status:** RED (17 failing on stubs — zero import errors)

**Implementation Notes for Dev:**
1. Implement `listMigrationFiles(dir)` — scan dir for `*.js` files, sort by numeric prefix
2. Implement `getPendingMigrations(migrations, appliedIds)` — filter by ID not in applied set
3. Implement `runMigrations(migrations, projectRoot, appliedIds, opts)` — orchestrate: check() → up() → track
4. Add `migrationsRun?: string[]` field to `Manifest` interface in `manifest.ts`
5. Wire `runMigrations` into `update.ts` after `updateInstalledContent` completes
6. Create `pennyfarthing-dist/migrations/` directory with at least one example migration
7. Dry-run: call check() but skip up(), log what would run

**Handoff:** To Dev for implementation

## Dev Assessment (v2 — post-review fixes)

**Implementation Complete:** Yes
**Reviewer Fixes Applied:**
- `update.ts:245-249` — **[HIGH]** Preserve `migrationsRun` from old manifest before `createManifest()` writes to disk
- `migrations.ts:135-161` — **[MEDIUM]** Added per-migration try-catch wrapping `check()`/`up()` with migration ID in error
- `update.ts:265-273` — **[MEDIUM]** Validate `mod.id`, `mod.up`, `mod.check` exports before loading migration
- `migrations.ts:72-74` — **[LOW]** Tightened filter from `.endsWith('.js')` to `/^\d{3,}-.*\.js$/` regex
- `migrations.test.ts:38,168` — **[LOW]** Removed unused `RunMigrationsResult` import, prefixed `_ctx`

**Tests:** 19/19 passing (GREEN)
**PR:** #835 — feat(98-2): versioned migration runner infrastructure
**Branch:** feature/PROJ-14699-versioned-migration-runner (pushed, commit 06bfee7)

**Handoff:** To Reviewer for re-review

## Reviewer Assessment (v1 — REJECTED)

See session log for rejection details. All 5 issues fixed in v2.

## Reviewer Assessment (v2 — re-review)

**Verdict:** APPROVED

**Fixes verified (all 5/5):**
- [VERIFIED] `update.ts:249-252` — `migrationsRun` preserved from old manifest before `createManifest()` write. Traced second-update scenario: field survives.
- [VERIFIED] `migrations.ts:135-170` — Per-migration try-catch wraps `check()`/`up()`, returns `{id, error}` on throw.
- [VERIFIED] `update.ts:272-274` — Validates `mod.id`, `mod.up`, `mod.check` before loading; skips invalid with warning.
- [VERIFIED] `migrations.ts:73` — Regex `/^\d{3,}-.*\.js$/` matches documented `NNN-name.js` convention.
- [VERIFIED] `migrations.test.ts:34-38,167` — Lint clean: unused import removed, `_ctx` prefixed.

**Data flow traced:** `pennyfarthing update` → `readManifest` → `updateInstalledContent` → `createManifest` + preserve migrationsRun → `writeManifest` → `listMigrationFiles` (regex-filtered) → validate exports → `getPendingMigrations` → `runMigrations` (try-catch per migration) → re-read manifest → append applied IDs → write. Field survives across update cycles.

**Pattern observed:** Clean result-object pattern at `migrations.ts:152-158`, three well-separated concerns (`list`/`filter`/`run`). Tests cover all 10 ACs with 19 assertions.

**Error handling:** Two-layer defense — per-migration try-catch in `runMigrations` + outer try-catch in `update.ts:310-312`. Thrown exceptions now include migration ID.

**Handoff:** Merge PR #835, then to SM for finish-story

---

## Session Log

### Handoff: SM → TEA
**Time:** 2026-02-12
**From:** SM (Camina Drummer)
**To:** TEA (Amos Burton)
**Phase:** setup → red
**Context:** Story 98-2 setup complete. Branch feature/PROJ-14699-versioned-migration-runner created, Jira claimed. 5-point story, tdd workflow. TEA to design tests for versioned migration runner infrastructure — migration file convention, runner execution, manifest tracking, idempotency checks.

### Handoff: TEA → Dev
**Time:** 2026-02-12
**From:** TEA (Amos Burton)
**To:** Dev (Naomi Nagata)
**Phase:** red → green
**Context:** 19 tests written (17 failing RED state confirmed). migrations.test.ts covers all 10 ACs: file discovery, pending detection, ordering, manifest tracking, idempotency, context injection, dry-run, failure handling. Dev implements stubs in migrations.ts, adds migrationsRun to Manifest, wires into update.ts, creates pennyfarthing-dist/migrations/ with example.

### Handoff: Dev → Reviewer
**Time:** 2026-02-12
**From:** Dev (Naomi Nagata)
**To:** Reviewer (Chrisjen Avasarala)
**Phase:** green → review
**Context:** 19/19 tests GREEN. PR #835 created targeting develop. Implementation: migrations.ts (runner with 3 functions), manifest.ts (migrationsRun field), update.ts (wiring), pennyfarthing-dist/migrations/ (example migration). Reviewer to verify code quality and AC coverage.

### Handoff: Reviewer → Dev (REJECTED)
**Time:** 2026-02-12
**From:** Reviewer (Chrisjen Avasarala)
**To:** Dev (Naomi Nagata)
**Phase:** review → green
**Context:** REJECTED. HIGH: createManifest() overwrites migrationsRun on every update cycle — tracking lost every other run (update.ts:245-249). MEDIUM: no per-migration try-catch in runMigrations, no validation of migration module exports. LOW: 2 lint warnings. Dev to fix manifest persistence, add error handling, clean lint.

### Handoff: Dev → Reviewer (re-review)
**Time:** 2026-02-12
**From:** Dev (Naomi Nagata)
**To:** Reviewer (Chrisjen Avasarala)
**Phase:** green → review
**Context:** All 5 reviewer issues fixed: HIGH manifest persistence (preserve migrationsRun before createManifest write), MEDIUM per-migration try-catch and export validation, LOW regex filter and lint. 19/19 tests GREEN. Commit 06bfee7 pushed to PR #835.

### Handoff: Reviewer → SM (APPROVED)
**Time:** 2026-02-12
**From:** Reviewer (Chrisjen Avasarala)
**To:** SM (Camina Drummer)
**Phase:** review → finish
**Context:** APPROVED on re-review. All 5 issues from v1 rejection verified fixed. PR #835 merged to develop. 19/19 tests GREEN. SM to run finish-story flow.
