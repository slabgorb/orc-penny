# Story 141-5: Add Tests for Core API Routes (agent-load through dependencies)

**Jira:** PROJ-16132
**Branch:** feature/141-5-core-api-route-tests
**Repos:** pennyfarthing
**Workflow:** tdd
**Phase:** finish
**Points:** 5
**Assignee:** Keith Avery

## Acceptance Criteria
- Core API routes from agent-load through dependencies have comprehensive test coverage
- Tests follow existing patterns in the codebase
- All new tests pass

## Context
Adding test coverage for core API routes. The routes to test span from agent-load through dependencies endpoints.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Story is specifically about adding test coverage

**Test Files:**
- `packages/core/src/server/api/agent-load.test.ts` - Factory, route registration, GET / response shape, GET /:agent context
- `packages/core/src/server/api/audit-log.test.ts` - All 7 endpoints (GET /, /events, /types, /stats, /export/json, /export/csv, DELETE /)
- `packages/core/src/server/api/bell.test.ts` - WebSocket broadcast utilities, client management, OPEN/CLOSED filtering
- `packages/core/src/server/api/code-markers.test.ts` - Factory, route registration, handler safety
- `packages/core/src/server/api/complexity.test.ts` - Factory, route registration, handler safety
- `packages/core/src/server/api/context.test.ts` - Router, getContextUsage shape/errors, resolveContextScript path discovery
- `packages/core/src/server/api/dead-code.test.ts` - Factory, route registration, handler safety
- `packages/core/src/server/api/dependencies.test.ts` - Factory, route registration, handler safety

**Tests Written:** 55 tests covering all 3 ACs across 8 route modules
**Status:** PASS (coverage tests for existing code — all tests pass immediately)

**Note:** This is a coverage story for existing routes, not new implementation. Tests verify existing behavior and pass as-is. No RED state is appropriate — the code already works.

**Handoff:** To Dev (Toby) for any additional implementation if needed, otherwise straight to review.

## Dev Assessment

**Implementation Complete:** Yes (coverage-only story — no new implementation required)
**Files Changed:** None — tests written by TEA already pass against existing code
**Tests:** 55/55 passing (GREEN)
**Branch:** feature/141-5-core-api-route-tests (pushed)

**Handoff:** To next phase (review)

## TEA Verify Assessment

**Tests:** 55/55 passing (GREEN confirmed)
**Build:** Pass
**Lint:** 0 errors (6 pre-existing warnings in unchanged code)

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 8

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 6 findings | 4 high (duplicated router introspection, identical test files, mock objects, route layer lookup), 2 medium (route path extraction, router validation) |
| simplify-quality | 3 findings | 2 medium (Express internal `as any` casts, untyped mocks), 1 low (inconsistent mock chainability) |
| simplify-efficiency | clean | No issues |

**Applied:** 4 high-confidence fixes — extracted `__test-helpers.ts` with shared route introspection (`getRoutePaths`, `getRouteEntries`, `findRouteLayer`), mock factories (`createMockJsonRes`, `createMockChainRes`), and `describeSingleRouteRouter` for the 4 identical single-route test files
**Flagged for Review:** 4 medium-confidence findings (Express internal coupling via `as any`, untyped specialized mocks, route path extraction, router validation patterns)
**Noted:** 1 low-confidence observation (inconsistent mock chainability in audit-log export tests)
**Reverted:** 0

**Overall:** simplify: applied 4 fixes (-70 net lines)

**Handoff:** To Josh (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `createAgentLoadRouter(() => path)` → `router.get('/')` → `res.json({agents, cachedAt, totalAcrossAllAgents, summary})` — shape assertions match source at `agent-load.ts:9`
**Pattern observed:** `describeSingleRouteRouter` cleanly extracts 5-test pattern from 4 identical files at `__test-helpers.ts:45-83`
**Error handling:** `getContextUsage('/nonexistent')` correctly returns `{error: 'context.py not found', ...nulls}` at `context.ts:78` — tested at `context.test.ts:47-61`
**Wiring:** All 8 test files import from correct source modules via `.js` extensions
**Security:** No user input flows through test code; route handlers properly validated via mock req/res

| Severity | Issue | Location |
|----------|-------|----------|
| [MEDIUM] | Helper inconsistency — raw `(router as any).stack.filter` instead of using own `getRoutePaths` | `__test-helpers.ts:67` |
| [LOW] | "Does not throw synchronously" trivially true for async `execFile` handlers | `__test-helpers.ts:71-81` |

**Handoff:** To Leo (SM) for finish-story

## Delivery Findings

### Reviewer (code review)
- No upstream findings during code review.

### TEA (test verification)
- No upstream findings during test verification.

### Dev (implementation)
- No upstream findings during implementation.

### TEA (test design)
- **Improvement** (non-blocking): Python-backed routes (code-markers, complexity, dead-code, dependencies) have no integration test coverage. They call `execFile('python3', ...)` which is untestable without mocking or a test harness. Consider adding a mock/stub layer for deeper testing in a future story. Affects `packages/core/src/server/api/code-markers.ts` (and similar). *Found by TEA during test design.*## Impact Summary

**Upstream Effects:** 1 findings (0 Gap, 0 Conflict, 0 Question, 1 Improvement)
**Blocking:** None

- **Improvement:** Python-backed routes (code-markers, complexity, dead-code, dependencies) have no integration test coverage. They call `execFile('python3', ...)` which is untestable without mocking or a test harness. Consider adding a mock/stub layer for deeper testing in a future story. Affects `packages/core/src/server/api/code-markers.ts`.

