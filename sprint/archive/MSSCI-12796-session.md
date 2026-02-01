# Story Session: MSSCI-12796

**Story:** Tier selection logic
**Epic:** Epic MSSCI-12793 - Tiered Context Injection System
**Points:** 2
**Priority:** P0
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-12796-tier-selection-logic
**Jira:** MSSCI-12796

---

## Story Context

This story is the second of six in the Tiered Context Injection System epic (MSSCI-12793). The goal of the epic is to reduce token overhead from agent context injection, which currently sends ~4000 tokens via `--append-system-prompt` on every turn, even when resuming sessions where the agent already has context. The target is to reduce average system prompt tokens per turn from ~4000 to under 1000 (84% reduction).

The previous story (MSSCI-12795) established the foundation by adding `SessionContextState` tracking to ClaudeService. This includes tracking `lastAgent`, `turnCount`, and `injectedComponents` - the exact state needed to make tier selection decisions. The implementation is complete and merged (PR #599), with the interface and methods available at `packages/cyclist/src/claude-service.ts` lines 682-743.

This story implements the `selectContextTier()` function that consumes the session state and returns the appropriate context tier (`FULL`, `REFRESH`, `HANDOFF`, or `MINIMAL`). The decision logic is straightforward but critical - it determines how much context to inject on each turn. The function will be consumed by MSSCI-12798 (TypeScript Integration) to wire into the message flow.

## Acceptance Criteria

- [x] selectContextTier() function implemented
- [x] Returns FULL when no lastAgent in session state
- [x] Returns HANDOFF when current agent differs from lastAgent
- [x] Returns MINIMAL when same agent and turnCount > 3
- [x] Returns REFRESH for all other cases
- [x] Unit tests cover all tier transition scenarios

## Technical Approach

### Implementation Location

The technical design document specifies `cyclist/src/prime.ts` as the target file for the `selectContextTier()` function. This aligns with the function's purpose - it's a priming decision that determines context injection strategy.

### Tier Definitions

| Tier | Tokens | When Used |
|------|--------|-----------|
| FULL | ~4000 | First turn of new session (no lastAgent) |
| REFRESH | ~600 | Resumed session, same agent, early conversation |
| HANDOFF | ~700 | Resumed session, different agent |
| MINIMAL | ~200 | Deep conversation (turn > 3), same agent |

### Decision Logic (from design doc)

```typescript
function selectContextTier(
  agentName: string,
  state: SessionContextState
): 'FULL' | 'REFRESH' | 'HANDOFF' | 'MINIMAL' {
  if (!state.lastAgent) return 'FULL';
  if (state.lastAgent !== agentName) return 'HANDOFF';
  if (state.turnCount > 3) return 'MINIMAL';
  return 'REFRESH';
}
```

### Type Definition

Export a `ContextTier` type for consistency across the codebase:
```typescript
export type ContextTier = 'FULL' | 'REFRESH' | 'HANDOFF' | 'MINIMAL';
```

### Test Coverage

Unit tests should cover:
1. New session (no lastAgent) returns FULL
2. Agent change (lastAgent !== currentAgent) returns HANDOFF
3. Same agent, turn 1-3 returns REFRESH
4. Same agent, turn 4+ returns MINIMAL
5. Edge cases: turn exactly 3 (REFRESH), turn exactly 4 (MINIMAL)
6. Empty string vs null lastAgent handling

## Files

**Implementation:**
- `packages/cyclist/src/prime.ts` - New selectContextTier() function

**Tests:**
- `packages/cyclist/tests/MSSCI-12796-tier-selection.test.ts` - Unit tests

**Reference:**
- `packages/cyclist/src/claude-service.ts` - SessionContextState interface (lines 682-743)
- `sprint/context/MSSCI-12787-reference/tiered-context-story-draft.md` - Design document

---

## Progress Log

- Setup: Branch feat/MSSCI-12796-tier-selection-logic created and pushed
- Setup: Session file created with technical context from epic design doc and MSSCI-12795 implementation

---

## SM Assessment

**Setup Complete:** Story MSSCI-12796 ready for TDD red phase.

**Context:** This story implements the tier selection logic that decides which context tier to inject based on session state. Builds on MSSCI-12795 which added SessionContextState tracking.

**Handoff:** To TEA (Sam Seaborn) for test design.

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Pure function with clear decision logic - perfect TDD candidate

**Test File:**
- `packages/cyclist/tests/MSSCI-12796-tier-selection.test.ts` - 25 tests covering all tier transitions

**Tests Written:** 25 tests covering 6 acceptance criteria
**Status:** RED (failing - `selectContextTier` not yet implemented)

**Test Coverage Breakdown:**
| AC | Tests | Description |
|----|-------|-------------|
| AC1 | 3 | Function export and type validation |
| AC2 | 3 | FULL tier when no lastAgent (new session) |
| AC3 | 4 | HANDOFF tier when agent changes |
| AC4 | 4 | MINIMAL tier when same agent, turn > 3 |
| AC5 | 4 | REFRESH tier for other cases |
| AC6 | 7 | Edge cases: boundaries, empty string, priority |

**Edge Cases Covered:**
- Turn boundary: 3 → REFRESH, 4 → MINIMAL
- Empty string lastAgent treated as truthy (HANDOFF, not FULL)
- Case-sensitive agent names
- Whitespace in agent names
- Condition priority ordering

**Implementation Notes for Dev:**
1. Add to `packages/cyclist/src/prime.ts`
2. Export `ContextTier` type and `selectContextTier()` function
3. Import `SessionContextState` from `claude-service.js`
4. Logic is straightforward - see design doc in session

**Handoff:** To Dev (Toby Ziegler) for implementation

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/prime.ts` - Added `ContextTier` type and `selectContextTier()` function

**Implementation Notes:**
- Used explicit `=== null` check instead of falsy check to handle empty string edge case
- Empty string lastAgent is treated as a valid (but different) agent, returns HANDOFF
- Function is pure with no side effects, easy to test and reason about

**Tests:** 25/25 passing (GREEN)
**PR:** #600 - feat(MSSCI-12796): implement tier selection logic
**Branch:** feat/MSSCI-12796-tier-selection-logic (pushed)

**Handoff:** To Reviewer (Josh Lyman) for code review

---

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**

| Severity | Issue | Location |
|----------|-------|----------|
| [VERIFIED] | Type-only import correct for ESM | `prime.ts:15` |
| [VERIFIED] | Explicit `=== null` handles empty string edge case | `prime.ts:154` |
| [VERIFIED] | Decision priority order matches spec | `prime.ts:154-163` |
| [VERIFIED] | Return type exhaustive - no undefined/null paths | `prime.ts:149-163` |
| [VERIFIED] | Tests cover all 6 ACs (25 tests) | test file |
| [LOW] | `injectedComponents` unused - by design per spec | N/A |

**Data Flow Traced:** `agentName` + `state` → pure function → `ContextTier`
- Safe because: pure function with no side effects, all inputs validated by TypeScript

**Pattern Observed:** Explicit null check at `prime.ts:154`
- Good pattern: `=== null` instead of falsy check distinguishes null from empty string

**Error Handling:** Not applicable - pure function with exhaustive return paths

**PR #600 merged and branch deleted.**

**Handoff:** To SM (Leo McGarry) for finish-story
