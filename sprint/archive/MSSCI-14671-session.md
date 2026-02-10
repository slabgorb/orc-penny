# Session: MSSCI-14671 — Context-Watch Observation Scope

## Story
- **ID:** 95-6 (MSSCI-14671)
- **Epic:** epic-95 (Workflow Configuration & Observation Protocol)
- **Points:** 3
- **Workflow:** tdd
- **Branch:** feature/MSSCI-14671-context-watch-observation-scope
- **Repo:** pennyfarthing

## Phase: finish
- **Status:** ready
- **Agent:** sm

## Acceptance Criteria
- [ ] Backseat receives periodic conversation summaries at configurable turn intervals
- [ ] Default interval: every 5 tool calls
- [ ] Summaries capture primary agent's current focus, decisions, and approach
- [ ] Summary generation does not block primary agent's conversation flow
- [ ] Combined token overhead stays under 25% per phase
- [ ] Context accumulates — later summaries reference earlier ones

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core scope implementation with turn counter, context snapshots, polling, and observation writing

**Test Files:**
- `packages/core/src/workflow/context-watch.test.ts` - 43 tests across 9 suites

**Tests Written:** 43 tests covering 6 ACs
- AC1 (7 tests): Periodic summaries at configurable intervals — turn counter increment/read/reset, shouldTriggerSummary, watcher triggers at interval
- AC2 (3 tests): Default interval of 5 — not trigger at turn 4, trigger at turn 5, default config
- AC3 (5 tests): Summary content quality — snapshot from session, includes content, includes turn count, context-watch trigger type, turn info in detail
- AC4 (5 tests): Non-blocking — incrementTurnCounter <10ms, shouldTriggerSummary pure, writeContextSnapshot <50ms, startContextWatcher returns immediately, missing dir graceful
- AC5 (4 tests): Token overhead budget — snapshot within 2000 char bound, smaller than source, 10 summaries within budget, estimated token count
- AC6 (5 tests): Context accumulation — readContextSnapshot returns prior, empty for no prior, later includes reference, multiple observations across intervals, no duplicate content
- Result objects (5 tests): Framework `{success, data?, error?}` pattern for all functions
- Error resilience (5 tests): Missing session dir, missing session file, bad observation path, idempotent stop, missing snapshot file
- Edge cases (4 tests): Empty session, very large session, concurrent reads, non-numeric counter file

**Status:** RED (43 failing — all on "Not implemented", no import/syntax errors)

**Architecture Notes for Dev:**
- Follow `tool-watch.ts` pattern exactly (types, WeakMap state, polling, result objects)
- `incrementTurnCounter()` is the hook-side function — must be synchronous and fast (<10ms)
- `shouldTriggerSummary(turnCount, interval)` is a pure function — no I/O
- `writeContextSnapshot()` reads session file, extracts tail content, writes bounded snapshot (~2000 chars max)
- Context snapshot path: `.session/{storyId}-tandem-context.md`
- Turn counter path: `.session/.tandem-turn-counter`
- `startContextWatcher()` / `stopContextWatcher()` poll counter and write observations via `appendObservation()`
- Observation trigger type: `context-watch`, detail includes turn number
- Token estimate: ~4 chars per token (simple heuristic)
- Compile: `npx tsc dist/workflow/context-watch.ts dist/workflow/context-watch.test.ts --target ES2022 --module NodeNext --moduleResolution NodeNext --declaration --skipLibCheck --esModuleInterop` (from `packages/core/` dir, after copying `.ts` to `dist/workflow/`)

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/workflow/context-watch.ts` — Full implementation (287 lines): incrementTurnCounter, readTurnCounter, resetTurnCounter, shouldTriggerSummary, writeContextSnapshot, readContextSnapshot, startContextWatcher, stopContextWatcher

**Tests:** 43/43 passing (GREEN)
**No regressions:** observation-writer (34 tests), tool-watch (42 tests), file-watch (25 tests) all pass
**PR:** #804 — feat(95-6): context-watch observation scope
**Branch:** feature/MSSCI-14671-context-watch-observation-scope (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Tests:** 43/43 PASS | observation-writer 34/34 PASS | tool-watch 42/42 PASS
**Forbidden patterns:** None
**Data flow traced:** incrementTurnCounter → .tandem-turn-counter → readTurnCounter (poll) → shouldTriggerSummary → writeContextSnapshot → appendObservation (safe: bounded, file-atomic writes)
**Pattern observed:** Follows tool-watch.ts WeakMap/handle/polling pattern at context-watch.ts:64-65
**Error handling:** Result objects throughout, try-catch with graceful degradation at context-watch.ts:92-94,171-173,257-259

| Severity | Observation | Location |
|----------|-------------|----------|
| [VERIFIED] | End-to-end data flow correct | context-watch.ts:90→216→240→252 |
| [VERIFIED] | Pattern consistency with tool-watch | context-watch.ts:64-65,201-269 |
| [VERIFIED] | Non-blocking guarantee (<10ms hook) | context-watch.ts:75-95 |
| [VERIFIED] | Token budget enforcement (2000 char max) | context-watch.ts:61,163 |
| [VERIFIED] | Error resilience and idempotent stop | context-watch.ts:275-287 |
| [VERIFIED] | Race-safe turn tracking via lastProcessedTurn | context-watch.ts:234 |
| [MEDIUM] | Snapshot is overwrite-only, not append-accumulating | context-watch.ts:168 |
| [LOW] | Unused statSync import in test file | context-watch.test.ts:25 |
| [LOW] | Fire-and-forget observation writes lose error visibility | context-watch.ts:252-259 |

**No blocking issues.** MEDIUM note: snapshot file is transient (overwritten each interval) — the observation file via `appendObservation` is the true accumulation mechanism. This is acceptable.

**Handoff:** To SM for finish-story

## Handoff Log
| Time | From | To | Notes |
|------|------|----|-------|
| now | — | SM | Story setup started |
| now | SM | TEA | Test design phase |
| now | TEA | Dev | 43 RED tests, ready for implementation |
| now | Dev | Reviewer | 43/43 GREEN, PR #804 |
| now | Reviewer | SM | APPROVED, PR #804 merged, finish-story |
