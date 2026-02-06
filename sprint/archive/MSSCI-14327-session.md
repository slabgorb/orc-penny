# MSSCI-14327: Smooth plan mode exit with tirepump choice

**Status:** in_progress
**Phase:** finish
**PR:** https://github.com/1898andCo/pennyfarthing/pull/699
**Workflow:** tdd
**Epic:** epic-78 (Cyclist Permission System)
**Jira:** MSSCI-14327
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14327-smooth-plan-mode-exit
**Assignee:** kavery
**Points:** 2

## Story Context

Smooth plan mode exit with tirepump choice integration. Part of the Cyclist Permission System epic (MSSCI-14317).

## Acceptance Criteria

- AC1: After plan approval, mode automatically transitions from plan to accept
- AC2: User is offered a tirepump choice (commit/push or continue without)
- AC3: Choosing tirepump triggers context clear + commit flow
- AC4: Choosing "continue without" skips tirepump and stays in accept mode
- AC5: Transition works via WebSocket mode sync (not manual user action)
- AC6: If WebSocket is disconnected, falls back gracefully

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `packages/cyclist/tests/MSSCI-14327-smooth-plan-mode-exit.test.ts` - 21 tests across 6 ACs
- `packages/cyclist/src/public/hooks/usePlanModeExit.ts` - Stub module (types + throwing functions)

**Tests Written:** 21 tests covering 6 ACs (15 behavioral failing, 6 structural passing)
**Status:** RED (failing - ready for Dev)

**Implementation Guidance:**
- New hook file: `src/public/hooks/usePlanModeExit.ts`
- `handlePlanModeExit()` - orchestrates plan→accept mode transition + tirepump prompt
- `handleTirepumpChoice()` - handles user's tirepump vs continue decision
- `usePlanModeExit()` - React hook wrapper for component integration
- `PLAN_EXIT_MODE` constant already set to `'acceptEdits'` (Claude CLI mapping)
- Integrates with existing `useModeSync` WebSocket protocol (`{ type: 'setMode', mode }`)
- Tirepump choice triggers `CONTEXT_CLEAR` marker via callback
- Must handle WebSocket disconnected state gracefully (local-only transition)

**Handoff:** To Dev (Roy Batty) for implementation

## Technical Notes

- See epic context: sprint/context/context-epic-78.md
- Key existing files:
  - `src/public/components/ModeSwitch/index.tsx` - Mode types, useModeSync, MODE_TO_CLAUDE mapping
  - `src/public/hooks/useMarkerActions.ts` - CONTEXT_CLEAR marker action handling
  - `packages/shared/src/marker/constants.ts` - MARKER_TYPES.CONTEXT_CLEAR
- 2-point TDD story

## Session Log

- Setup by SM (Captain Bryant)
- Handoff to TEA (Deckard) for red phase - test design
- TEA: 21 tests written, RED state confirmed, handing off to Dev
- Dev: Implementation complete, all 21 tests GREEN, PR #699 created, handing off to Reviewer

## Dev Assessment

**Implementation:** `packages/cyclist/src/public/hooks/usePlanModeExit.ts`
**Approach:** Replaced stub throws with working logic
**Tests:** 21/21 passing (GREEN)
**PR:** #699
**Changes:** 1 file, 51 insertions, 7 deletions

**Functions implemented:**
- `handlePlanModeExit()` - Transitions plan→accept on approval, returns tirepump choice options
- `handleTirepumpChoice()` - Fires onContextClear for tirepump, no-ops for continue
- `usePlanModeExit()` - React hook wrapping both functions with state management

**Handoff:** To Reviewer (J.F. Sebastian) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Tests:** 21/21 passing, TypeScript compiles clean, no forbidden patterns
**Data flow traced:** `handlePlanModeExit(options)` → guard on `approved` → `setMode('accept')` → return tirepump options. Pure logic, no side effects beyond the provided `setMode` callback. Safe.
**Pattern observed:** Callback delegation pattern at `usePlanModeExit.ts:80` — uses optional chaining `onContextClear?.()` instead of internal side effects. Clean separation of concerns.
**Error handling:** Graceful `wsConnected === false` strict equality at `usePlanModeExit.ts:65` correctly distinguishes undefined (not specified) from false (known disconnected).
**Security:** No concerns — pure logic module with no user input parsing, no HTML, no network calls.

**Observations:**
1. `[VERIFIED]` Rejection early return at L56-58 — no side effects on rejected plan
2. `[VERIFIED]` Redundant transition guard at L61-63 — avoids unnecessary WebSocket messages
3. `[VERIFIED]` Strict equality for wsConnected at L65 — correct semantics
4. `[LOW]` TIREPUMP_OPTIONS shared reference at L46-49 — acceptable for internal hook
5. `[VERIFIED]` Optional chaining + nullish coalescing at L80 — handles missing callback/agent
6. `[VERIFIED]` useCallback deps `[]` at L96,102 — correct since functions are module-level
7. `[VERIFIED]` No security concerns — pure callbacks
8. `[VERIFIED]` setMode correctly unused in handleTirepumpChoice — mode already set

**Handoff:** To SM (Captain Bryant) for finish-story

## Session Log (continued)

- Reviewer: APPROVED, PR #699 merged, handing off to SM for finish
