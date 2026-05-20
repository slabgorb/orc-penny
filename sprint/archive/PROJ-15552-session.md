# Story 124-1: Extract Server Engine into packages/bikerack/

## Story Details
- **ID:** 124-1
- **Jira:** PROJ-15552
- **Workflow:** tdd
- **Points:** 5
- **Priority:** p0
- **Repos:** pennyfarthing
- **Branch:** feat/124-1-extract-server-engine-bikerack

## Story Context

**Epic:** BikeRack Standalone Package Extraction (PROJ-15551)

**Description:** Extract the Server Engine (Express app factory, routing, API routers, OTLP receiver, file watchers, settings management, story-parser, sprint-data, env detection, paths resolution) from packages/cyclist into a new packages/bikerack/ package.

### Acceptance Criteria

1. packages/bikerack/src/ contains Express app factory, route mounting, all 30+ API routers, OTLP receiver interface, file watchers, settings management, story-parser, sprint-data, env detection, paths resolution
2. packages/bikerack/ has its own package.json with @pennyfarthing/bikerack name
3. packages/bikerack/ builds independently via the monorepo build toolchain
4. No Electron dependency exists in packages/bikerack/package.json

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-24T13:04:55Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-24T12:44:58Z | 2026-02-24T12:46:06Z | 1m 8s |
| red | 2026-02-24T12:46:06Z | 2026-02-24T12:54:05Z | 7m 59s |
| green | 2026-02-24T12:54:05Z | 2026-02-24T12:59:01Z | 4m 56s |
| verify | 2026-02-24T12:59:01Z | 2026-02-24T13:01:49Z | 2m 48s |
| review | 2026-02-24T13:01:49Z | 2026-02-24T13:04:55Z | 3m 6s |
| finish | 2026-02-24T13:04:55Z | - | - |

## Assessment: setup (SM)

Story 124-1 is ready for TDD red phase. Session created, Jira claimed (PROJ-15552 → In Progress), feature branch created on pennyfarthing/develop. ADR-0030 provides full architectural context for the extraction. TEA should design tests verifying: (1) packages/bikerack/src/ contains all server engine components, (2) package.json exists with @pennyfarthing/bikerack, (3) independent build works, (4) zero Electron dependencies. The server engine currently lives in packages/core/src/server/ and packages/cyclist/src/ — TEA should reference ADR-0030's "What moves where" section for precise file mapping.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Package extraction requires structural validation — files moved, package identity, build toolchain, dependency cleanliness.

**Test Files:**
- `packages/bikerack/src/bikerack-extraction.test.ts` — 35 tests covering all 4 ACs

**Tests Written:** 35 tests covering 4 ACs
- AC1 (19 tests): Server engine files — server.ts, 30+ API routers, otlp-receiver.ts, settings.ts/settings-store.ts, story-parser.ts, story-context.ts, agent-context.ts, env.ts, paths.ts, pennyfarthing.ts
- AC2 (5 tests): package.json identity — name, type:module, express/ws dependencies
- AC3 (7 tests): Build toolchain — tsconfig, build script, dist/ output, compiled .js and .d.ts
- AC4 (4 tests): No Electron — no electron/node-pty in any dep group, no electron imports in source

**Status:** RED (21 failing, 14 passing — scaffolding passes, extraction tests fail)
**Commit:** `test: add failing tests for 124-1 BikeRack extraction`

**Scaffolding created (not implementation):**
- packages/bikerack/package.json — @pennyfarthing/bikerack identity
- packages/bikerack/tsconfig.json — extends monorepo base
- packages/bikerack/src/index.ts — empty stub

**Handoff to Korben Dallas (Dev):** Move server engine files from core/src/server/ to bikerack/src/ per ADR-0030. Key references: ADR-0030 "What moves where" section, core/src/server/api/ (31 routers), core/src/server/server.ts (app factory). Run `npm run build && npm test` in packages/bikerack/ to verify GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/bikerack/src/server.ts` — Express app factory (from core/src/server/)
- `packages/bikerack/src/api/` — 31 API router files (30 routers + index barrel)
- `packages/bikerack/src/*.ts` — 20 supporting modules (settings, paths, env, parser, otlp-receiver, etc.)
- `packages/bikerack/src/plugin-loader.ts` — Fixed import from `../index.js` to `@pennyfarthing/core`
- `packages/bikerack/src/api/settings.ts` — Fixed import from `../../shared/index.js` to `@pennyfarthing/shared`
- `packages/bikerack/package.json` — Added workspace deps: @pennyfarthing/core, @pennyfarthing/shared

**Tests:** 35/35 passing (GREEN)
**Branch:** feat/124-1-extract-server-engine-bikerack (pushed)

**Approach:** Copied server engine files from core to bikerack (not moved). Core retains its copies — removal happens in story 124-4 (rewire). Two external imports fixed to use package names instead of relative paths. Package builds independently with `tsc`. Core monorepo build verified unaffected.

**Handoff:** To review phase

## TEA Verify Assessment

**Tests Verified:** 35/35 passing (GREEN confirmed)
**Build Verified:** Independent build produces dist/server.js, dist/index.js, type declarations
**AC Coverage:**
- AC1 (19 tests): All server engine components present — server.ts, 30+ API routers, supporting modules
- AC2 (5 tests): Package identity correct — @pennyfarthing/bikerack, type:module, express/ws deps
- AC3 (7 tests): Build toolchain works — tsconfig extends base, dist/ output with .js and .d.ts
- AC4 (4 tests): Zero Electron contamination — no electron/node-pty in deps or imports

**Verdict:** All acceptance criteria validated. System is worth saving.
**Handoff:** To Jean-Baptiste Emanuel Zorg (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** POST /api/bell-queue → req.body validated with Array.isArray() → writeFileSync to `.pennyfarthing/bell-queue.json` (no path traversal risk, path constructed with `join()`)
**Pattern observed:** Clean package boundary — all 55 source files use internal `./` or `../` relative imports within bikerack, external deps (`@pennyfarthing/core`, `@pennyfarthing/shared`) properly declared in package.json at `packages/bikerack/package.json`
**Error handling:** All 4 inline endpoints in server.ts use try/catch returning appropriate HTTP status codes (400 for validation, 500 for server errors)
**Security:** dangerous-path.ts comprehensively covers .env, .ssh, .aws, system paths with proper normalization at `packages/bikerack/src/dangerous-path.ts:58-65`

**Observations:**
- `[VERIFIED]` 30+ API routers wired via barrel export at `api/index.ts` — no orphaned routes
- `[VERIFIED]` No Electron or node-pty in any dependency group or source imports
- `[VERIFIED]` All TypeScript imports use `.js` extensions per project conventions
- `[VERIFIED]` No TODO/FIXME/HACK comments, no lint errors
- `[VERIFIED]` Clean git history: 2 focused commits (test + implementation)
- `[LOW]` Stale JSDoc at `server.ts:1` says "@pennyfarthing/core" — should say "@pennyfarthing/bikerack". Cosmetic only.
- `[LOW]` `index.ts` is a 2-line stub — package entry point exports nothing. Intentional per story scope (later stories populate).

**Handoff:** To Ruby Rhod (SM) for finish-story

## Implementation Notes

- This is the first story of epic 124 (PROJ-15551), foundational for the BikeRack extraction
- ADR-0030 documents the full architectural design
- Related stories: 124-2 (WebSocket/OTLP), 124-3 (DataSource<T>), 124-4 (Cyclist rewiring), 124-5 (Display components), 124-6 (CI/build)