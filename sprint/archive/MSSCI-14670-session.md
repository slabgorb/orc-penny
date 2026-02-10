# Session: MSSCI-14670 — Tool-Watch Observation Scope

## Story
- **ID:** 95-5 (MSSCI-14670)
- **Epic:** epic-95 (Workflow Configuration & Observation Protocol)
- **Points:** 3
- **Workflow:** tdd
- **Branch:** feature/MSSCI-14670-tool-watch-observation-scope
- **Repo:** pennyfarthing

## Phase: finish
- **Status:** ready
- **Agent:** sm

## Acceptance Criteria
- [ ] Backseat receives tool call data (name, params, result) from primary agent
- [ ] Data delivered within one tool-use cycle
- [ ] Large results truncated to configurable max size
- [ ] Truncation indicator included when results are truncated
- [ ] Non-blocking to primary agent (hook execution remains fast)
- [ ] Observations include analysis, not just raw tool call replay
- [ ] Context accumulates across tool calls

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core scope implementation with JSONL transport, truncation, polling, and observation writing

**Test Files:**
- `packages/core/src/workflow/tool-watch.test.ts` - 42 tests across 11 suites

**Tests Written:** 42 tests covering 7 ACs
- AC1 (7 tests): Tool call data reception — JSONL writes, field presence, multi-entry append
- AC2 (2 tests): One-cycle delivery — processToolCall completes <50ms, synchronous write
- AC3 (5 tests): Truncation — configurable max, respects limits, default 500 chars
- AC4 (5 tests): Truncation indicator — format `[truncated from N chars]`, absent for small results
- AC5 (3 tests): Non-blocking — large results still fast, missing dir graceful, watcher returns immediately
- AC6 (3 tests): Analytical observations — tool-watch trigger type, tool name in detail, enriched content
- AC7 (3 tests): Context accumulation — multiple tool calls, last-read tracking, live arrival
- Result objects (4 tests): Framework `{success, data?, error?}` pattern
- Error resilience (4 tests): Missing dir, write failures, idempotent stop, malformed JSONL
- Edge cases (5 tests): Empty result, special chars, empty file, empty string truncation, exact boundary

**Status:** RED (42 failing — all on "not implemented", no import/syntax errors)

**Architecture Notes for Dev:**
- Follow `file-watch.ts` pattern exactly (types, WeakMap state, polling, result objects)
- `processToolCall()` is the hook-side function — must be synchronous and fast (<50ms)
- `readToolCalls()` reads JSONL transport file, skipping malformed lines
- `truncateResult()` pure function: truncate + append `[truncated from N chars]` suffix
- `startToolWatcher()` / `stopToolWatcher()` poll JSONL and write observations via `appendObservation()`
- JSONL path: `.session/{storyId}-tandem-toolcalls.jsonl`
- Observation trigger type: `tool-watch`, detail includes tool name + param summary

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/workflow/tool-watch.ts` — Full implementation (167 lines): truncateResult, processToolCall, readToolCalls, startToolWatcher, stopToolWatcher

**Tests:** 42/42 passing (GREEN)
**No regressions:** observation-writer (59 tests), file-watch tests all pass
**PR:** #802 — feat(95-5): tool-watch observation scope
**Branch:** feature/MSSCI-14670-tool-watch-observation-scope (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** processToolCall(params) → appendFileSync(JSONL) → startToolWatcher polls → readFileSync(JSONL) → appendObservation(observation.md) — fully wired, no gaps
**Pattern observed:** Exact match to file-watch.ts architecture (WeakMap state, setInterval polling, idempotent stop, result objects) at tool-watch.ts:66-67,147-213
**Error handling:** Non-throwing everywhere — processToolCall returns {success:false} on missing dir (line 93), watcher has nested try/catch (lines 200,204), readToolCalls skips malformed JSONL (line 133)
**Security:** All writes use JSON.stringify (no injection), all reads use JSON.parse with try/catch
**Lint:** 4 warnings in test file (unused type imports, unused variable) — LOW, non-blocking
**Tests:** 42/42 pass. Pre-existing cyclist failure (MSSCI-14204) unrelated to this PR.
**Handoff:** To SM for finish-story

## Handoff Log
| Time | From | To | Notes |
|------|------|----|-------|
| now | — | SM | Story setup started |
| now | SM | TEA | Test design phase |
| now | TEA | Dev | 42 RED tests, ready for implementation |
| now | Dev | Reviewer | 42/42 GREEN, PR #802 |
| now | Reviewer | SM | APPROVED — PR #802 merged, 42/42 tests pass |
