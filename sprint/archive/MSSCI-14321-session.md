# Story Session: MSSCI-14321

**Story:** MSSCI-14321 - Integrate grant checking into WheelHub hook router
**Epic:** epic-78 (WheelHub Permission System)
**Jira:** MSSCI-14321
**Points:** 3
**Priority:** P0
**Workflow:** tdd
**Phase:** finish
**Branch:** feature/MSSCI-14321-integrate-grant-checking-wheelhub-hook-router
**Repos:** pennyfarthing
**Started:** 2026-02-06

## Acceptance Criteria

1. Grant-based auto-approval: When a hook request arrives for any tool type and a matching grant exists in settings-store, return `{ decision: 'allow' }` without broadcasting to WebSocket.
2. Allowlist fallback for Bash: Bash commands matching the settings-store allowlist (`isAllowlisted()`) are still auto-approved.
3. Once grant lifecycle: Once grants auto-revoke after first use (handled by `checkGrant()` internals).
4. Session grant lifecycle: Session grants persist for the app session, cleared on exit.
5. Always grant lifecycle: Always grants persist to `~/.cyclist/grants.json` and survive restarts.
6. WebSocket broadcast on no match: Non-granted requests broadcast to connected clients for manual approval.
7. Ask fallback: Return `{ decision: 'ask' }` when no WebSocket clients are connected.
8. Grant storage on approval: When user approves with a grant scope (once/session/always), the grant is stored via `addGrant()`.
9. Hardcoded patterns removed: `SAFE_COMMAND_PATTERNS` regex array removed from hook-request.ts.

## Key Files

- `pennyfarthing/packages/cyclist/src/api/hook-request.ts` (primary target)
- `pennyfarthing/packages/cyclist/src/server.ts` (grant initialization)
- `pennyfarthing/packages/cyclist/src/settings-store.ts` (reference)
- `pennyfarthing/packages/cyclist/src/approval-gate.ts` (reference)

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core permission system integration — grant-based auto-approval, allowlist fallback, grant storage on approval

**Test Files:**
- `pennyfarthing/packages/cyclist/tests/MSSCI-14321-hook-request-grant-integration.test.ts` - 15 tests covering all 9 ACs

**Tests Written:** 15 tests covering 9 ACs (12 RED, 3 already passing)
**Status:** RED (failing — ready for Dev)

**RED Test Summary:**
| AC | Tests | Failure Reason |
|----|-------|---------------|
| AC1: Grant auto-approval (all tools) | 4 | `checkGrant` not called from hook-request handler |
| AC2: Allowlist fallback | 1 | `isAllowlisted` from settings-store not imported/called |
| AC3: Once grant lifecycle | 1 | Grant system not wired |
| AC4: Session grant lifecycle | 1 | Grant system not wired |
| AC5: Always grant lifecycle | 1 | Grant system not wired |
| AC6: WS broadcast on no match | 1 | Grant check path must precede broadcast |
| AC7: Ask fallback | 0 (passes) | Already implemented |
| AC8: Grant storage on approval | 1 | `addGrant` not called in `handleHookWebSocketMessage` |
| AC9: Hardcoded patterns removed | 1 | `SAFE_COMMAND_PATTERNS` still in hook-request.ts |
| Server init | 1 | `server.ts` doesn't call `initializeGrants`/`setGrantsPersistCallback` |

**Implementation Notes for Dev:**
1. Import `checkGrant`, `isAllowlisted`, `addGrant` from `settings-store.ts` into `hook-request.ts`
2. Add `extractToolScope()` function (model after `getToolScope()` in `approval-gate.ts`)
3. Replace `SAFE_COMMAND_PATTERNS` + `isCommandAllowlisted()` with `checkGrant()` + `isAllowlisted()` calls
4. In `handleHookWebSocketMessage`, when `data.grantScope` present and approved, call `addGrant()`
5. In `server.ts`, add `initializeGrants()` + `setGrantsPersistCallback()` calls after `initializeSettings()`

**Handoff:** To Dev (Roy Batty) for implementation

## Dev Assessment

**Status:** GREEN (all 15 tests passing)
**Regressions:** None (1695 total tests passing, 58 test files)
**TypeScript:** Clean compilation, no errors

**Changes Made:**
1. `hook-request.ts`: Imported `checkGrant`, `isAllowlisted`, `addGrant` from settings-store. Added `extractToolScope()` for scope extraction across all tool types. Replaced `SAFE_COMMAND_PATTERNS`/`isCommandAllowlisted()` with `checkGrant()`/`isAllowlisted()`. Added grant storage in `handleHookWebSocketMessage` when `grantScope` present.
2. `server.ts`: Added `loadGrants`/`saveGrants` imports from settings.ts, `initializeGrants`/`setGrantsPersistCallback` imports from settings-store.ts. Called grant initialization after `initializeSettings()`.
3. Test file: Fixed AC6 broadcast test timing (supertest dispatches on await).

**Lines Changed:** +82 / -44 across 3 files

**Handoff:** To Reviewer (J.F. Sebastian) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `POST /api/hook-request` → `extractToolScope()` → `checkGrant()` → `isAllowlisted()` (Bash only) → WS broadcast → `handleHookWebSocketMessage()` → optional `addGrant()` → `resolveApproval()` → HTTP response. Complete and correct.

**Pattern observed:** `extractToolScope()` is a 1:1 parity copy of `getToolScope()` in `approval-gate.ts:86-99`. Same switch/case structure, same fallback. Good consistency. at `hook-request.ts:72-85`

**Error handling:** `try-catch` on WS message parsing at `hook-request.ts:153/173`. Null input fallback via `input || {}` at `hook-request.ts:191,224`. Defensive empty-string scope when `pending` is null at `hook-request.ts:160-162`.

**Security:** No injection risks. Scope strings are test values against stored patterns, not patterns themselves. WebSocket trust boundary is local machine.

**Observations:**
| # | Severity | Finding | Location |
|---|----------|---------|----------|
| 1 | `[VERIFIED]` | Scope extraction parity with approval-gate.ts | `hook-request.ts:72-85` |
| 2 | `[VERIFIED]` | SAFE_COMMAND_PATTERNS fully removed | `hook-request.ts` |
| 3 | `[VERIFIED]` | Grant check order correct (grant → allowlist → broadcast → ask) | `hook-request.ts:190-216` |
| 4 | `[VERIFIED]` | AC8 grant storage wired correctly | `hook-request.ts:157-169` |
| 5 | `[LOW]` | Unvalidated `grantScope` type cast (session-only blast radius) | `hook-request.ts:166` |
| 6 | `[VERIFIED]` | Server.ts double-init is idempotent | `server.ts:100-104` |
| 7 | `[VERIFIED]` | Null pending handling is defensive and safe | `hook-request.ts:159-168` |

**Tests:** 15/15 passing. All 9 ACs covered. Build passes. Pre-existing failures on develop baseline (not introduced by this story).

**Handoff:** To SM (Captain Bryant) for finish-story
