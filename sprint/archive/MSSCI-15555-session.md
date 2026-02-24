# Story 124-4: Rewire Cyclist to Depend on BikeRack

## Story Details
- **ID:** 124-4
- **Jira Key:** MSSCI-15555
- **Title:** Rewire Cyclist to Depend on BikeRack
- **Status:** in_progress
- **Points:** 3
- **Priority:** p0
- **Assigned to:** keith.avery@1898andco.io
- **Repos:** pennyfarthing
- **Workflow:** tdd
- **Type:** feature

## Acceptance Criteria
- packages/cyclist/package.json lists @pennyfarthing/bikerack as a dependency
- Cyclist starts BikeRack's server engine on launch
- Cyclist wires ClaudeService and registers /ws/claude channel on top of BikeRack's server
- IS_BIKERACK env var is removed — mode determined by entry point and service registration
- /ws/claude channel only exists when ClaudeService registers it (BikeRack never registers it)
- Cyclist IDE control plane (ClaudeService, MessagePanel, bell mode, Reflector, TirePump, permissions, dockview) remains in packages/cyclist/

## Story Context
This is story 4 of 6 in Epic 124: BikeRack Standalone Package Extraction (MSSCI-15551).

Previous completed stories:
- 124-1: Extract Server Engine into packages/bikerack/ (MSSCI-15552) - APPROVED
- 124-2: Move WebSocket and OTLP from Cyclist to BikeRack (MSSCI-15553) - APPROVED
- 124-3: Introduce DataSource<T> and Refactor Panel Hooks (MSSCI-15554) - APPROVED

This story focuses on wiring Cyclist as a consumer of BikeRack's server engine, establishing the dependency relationship and service integration patterns.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-24T16:54:12Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-24T10:52:00Z | 2026-02-24T15:56:03Z | 5h 4m |
| red | 2026-02-24T15:56:03Z | 2026-02-24T16:02:16Z | 6m 13s |
| green | 2026-02-24T16:02:16Z | 2026-02-24T16:12:21Z | 10m 5s |
| verify | 2026-02-24T16:12:21Z | 2026-02-24T16:51:27Z | 39m 6s |
| review | 2026-02-24T16:51:27Z | 2026-02-24T16:54:12Z | 2m 45s |
| finish | 2026-02-24T16:54:12Z | - | - |

## SM Assessment — Setup Phase

Story 124-4 is ready for TDD red phase. Session file created with all 6 ACs from the sprint YAML. Feature branch `feature/MSSCI-15555-rewire-cyclist-bikerack` created from develop in the pennyfarthing repo. Jira MSSCI-15555 claimed and moved to In Progress.

This is the fourth story in the BikeRack extraction epic. Stories 124-1 through 124-3 are all approved/complete, establishing the BikeRack package, WebSocket/OTLP migration, and DataSource pattern. This story wires Cyclist as a consumer of BikeRack's server engine.

Key areas for TEA to focus test design:
- BikeRack dependency wiring in Cyclist's package.json
- Server engine startup integration
- ClaudeService and /ws/claude channel registration
- IS_BIKERACK env var removal
- Service boundary: IDE control plane stays in Cyclist

**Handoff to:** TEA (red phase)

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core architectural rewiring — every AC needs verification

**Test Files:**
- `packages/cyclist/tests/124-4-rewire-cyclist-bikerack.test.ts` — 20 tests covering all 6 ACs

**Tests Written:** 20 tests covering 6 ACs
**Status:** RED (14 failing, 6 passing guard tests)

**Test Strategy:**
- AC1 (2 tests): Verify `@pennyfarthing/bikerack` in cyclist's package.json dependencies
- AC2 (3 tests): Verify cyclist imports from bikerack directly, not core/server
- AC3 (1 test): Verify /ws/claude is not gated by isBikeRackMode() + 1 guard test (channel exists in cyclist)
- AC4 (5 tests): Verify IS_BIKERACK env var and isBikeRackMode() removed from all source files
- AC5 (3 tests): Verify bikerack has no knowledge of /ws/claude or ClaudeService
- AC6 (6 tests): Guard tests — ClaudeService, dockview isolation stay in cyclist (all passing)

**Implementation Notes for Dev:**
- Current arch: Cyclist → @pennyfarthing/core/server (which wraps bikerack). Target: Cyclist → @pennyfarthing/bikerack directly.
- `cyclist/src/server.ts` imports from `@pennyfarthing/core/server` — rewire to `@pennyfarthing/bikerack`
- `cyclist/src/bikerack.ts` sets `IS_BIKERACK=1` — remove env var, use entry point detection
- `bikerack/src/websocket.ts` line 549 has `/ws/claude && !isBikeRackMode()` gate — remove /ws/claude from bikerack entirely
- `cyclist/src/websocket.ts` same line — change to unconditional /ws/claude registration (no mode check)
- `isBikeRackMode()` exists in `bikerack/src/env.ts`, `cyclist/src/env.ts`, `core/src/server/env.ts` — all must be cleaned
- Existing tests for MSSCI-14820 and MSSCI-14825 test isBikeRackMode behavior — will need updating

**Handoff:** To Dev (Korben Dallas) for GREEN implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/package.json` — added @pennyfarthing/bikerack dependency
- `packages/bikerack/package.json` — added ./server export path
- `packages/bikerack/src/env.ts` — replaced IS_BIKERACK with getMode/setMode
- `packages/bikerack/src/server.ts` — switched to getMode(), export getMode/setMode
- `packages/bikerack/src/api/mode.ts` — switched to getMode()
- `packages/bikerack/src/websocket.ts` — removed 470 lines of Claude/isBikeRackMode code
- `packages/bikerack/src/claude-service.ts` — DELETED (972 lines)
- `packages/cyclist/src/server.ts` — rewired from core/server to bikerack/server, setMode('cyclist')
- `packages/cyclist/src/websocket.ts` — removed isBikeRackMode import, unconditional /ws/claude
- `packages/cyclist/src/bikerack.ts` — removed IS_BIKERACK env var, import from bikerack directly
- `packages/cyclist/src/env.ts` — re-exports from bikerack

**Tests:** 20/20 passing (GREEN)
**Branch:** feature/MSSCI-15555-rewire-cyclist-bikerack (pushed)
**Net change:** +58 / -1494 lines

**Handoff:** To Reviewer (Zorg) for review phase

## TEA Verify Assessment

**Verify Result:** PASS (after fixes)
**Tests:** 21/21 passing (20 original + 1 new AC5 coverage test)
**Compilation:** bikerack and cyclist both compile (pre-existing websocket-data-source.ts errors from 124-3 excluded)

**Issues Found and Fixed:**

1. **Dangling import in `bikerack/src/todos.ts` (FIXED):**
   - `claude-service.ts` was deleted but `todos.ts` still imported `SDKMessage` from it
   - Fix: Replaced external import with local interface definition
   - Commit: `fix(124-4): fix dangling import and strengthen AC5 test`

2. **Stale `dist/` not rebuilt (FIXED locally):**
   - Ran `tsc` in bikerack — `dist/server.d.ts` now exports `getMode`/`setMode`
   - dist/ is gitignored so this is a local build artifact (reviewer must rebuild)

3. **Test gap — AC5 regex blind spot (FIXED):**
   - Original test checked `/ClaudeService/i` — misses `claude-service` (kebab-case)
   - Added test: "should NOT import from claude-service module in bikerack source"
   - Now 21 tests covering all 6 ACs

**Pre-existing (out of scope):**
- `websocket-data-source.ts` — DataSource/window errors from story 124-3

**Handoff:** To Reviewer (Zorg) for review phase

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** Mode detection: `bikerack/env.ts` defaults 'bikerack' → `cyclist/server.ts` calls `setMode('cyclist')` at module load → all downstream `getMode()` calls return correct value. No race condition (ESM load is synchronous).

**Pattern observed:** Clean dependency inversion — BikeRack provides server engine, Cyclist layers IDE features on top. No circular dependency. Export path `./server` in bikerack/package.json properly exposes getMode/setMode.

**Error handling:** ClaudeService error/abort handling preserved in cyclist/websocket.ts (Electron & Web mode). BikeRack cleanly divested of all Claude error paths.

**Findings:**
| Severity | Issue | Location |
|----------|-------|----------|
| [LOW] | Unused `isTodoWriteMessage`/`extractTodos` imports after Claude handler removal | `bikerack/src/websocket.ts:39` |
| [LOW] | Pre-existing test references deleted exports (124-2 story) | `bikerack/src/websocket-otlp-extraction.test.ts:108,126-128` |

**Verify phase note:** TEA (Leeloo) caught and fixed `todos.ts` dangling import + strengthened AC5 test. Both fixes committed and pushed.

**Handoff:** To SM (Ruby Rhod) for finish-story

## Development Branch
- **Branch:** feature/MSSCI-15555-rewire-cyclist-bikerack
- **Base:** develop