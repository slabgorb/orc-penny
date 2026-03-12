# Story 141-11: Type OTLP Receiver Payloads Properly

**Story ID:** 141-11
**Jira:** MSSCI-16138
**Points:** 2
**Status:** in-progress
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/141-11-type-otlp-receiver-payloads
**Assigned:** keithavery

## Context

Replace `any` types on OTLP receiver payloads with proper TypeScript interfaces. Part of the Tech Debt Audit epic (141) focusing on type safety improvements.

## Acceptance Criteria

- OTLP receiver payloads have proper TypeScript types
- No `any` types remain on OTLP-related interfaces
- Existing tests pass with new types
- New type definitions are exported for consumers

## SM Assessment

2-point TDD story. Sam Seaborn (TEA) designs tests first, then Toby (Dev) implements the types. Straightforward type safety improvement.

## TEA Assessment

**Tests Required:** No
**Reason:** Chore bypass — type-only refactor with existing comprehensive test coverage. The existing `otlp-receiver.test.ts` has 30+ assertions covering `parseOTLPMetrics`, `parseOTLPLogs`, aggregation, enrichment pipeline, and full standalone pipeline (Stories 98-23, 132-5). Zero runtime behavior changes — only TypeScript interface additions and `as any` cast removals. TypeScript `strict: true` with `noImplicitAny` is the verification mechanism. Story context explicitly states "no new tests needed."

**Existing Test Coverage:**
- `packages/core/src/server/otlp-receiver.test.ts` — AC1-AC8 from Story 98-23, plus Story 132-5 enrichment suite

**Implementation Notes for Dev:**
- Mirror interfaces from `packages/cyclist/src/otlp-receiver.ts` (lines 354-382 for metrics, 507-534 for logs)
- Replace 3 `as any` casts: line 243 (`parseOTLPMetrics`), line 251 (`.find()` callback), line 279 (`parseOTLPLogs`)
- Remove `eslint-disable @typescript-eslint/no-explicit-any` wrapper (lines 239, 449)
- Verify: `cd pennyfarthing/packages/core && pnpm run build && npm test`

**Handoff:** To Dev (Toby Ziegler) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/server/otlp-receiver.ts` — Added 12 TypeScript interfaces for OTLP metrics/logs payloads, replaced 3 `as any` casts with typed alternatives, removed eslint-disable wrapper

**Tests:** 31/31 passing (GREEN)
**Branch:** feature/141-11-type-otlp-receiver-payloads (pushed)

**Handoff:** To next phase (verify/review)

## TEA Verify Assessment

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 1

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 4 findings | Duplicated pending input filter (high), duplicated audit log filter (high), missing listener error wrapper (medium), provider delegation repetition (low) |
| simplify-quality | 7 findings | Non-null assertions in fallback chain (high), unchecked casts on optional values (4x medium), cast without validation (medium), silent catch (low) |
| simplify-efficiency | 5 findings | Duplicated pending input filter (high), unused _durationMs param (high), repeated conditional spreads (medium), complex fallback chain (medium), overlapping resets (medium) |

**Applied:** 0 — all high-confidence findings are in pre-existing code not modified by this story; applying would exceed story scope ("no runtime behavior changes")
**Flagged for Review:** 5 medium-confidence findings (conditional spreads, unchecked casts, overlapping resets, missing listener wrapper)
**Noted:** 2 low-confidence observations (silent catch, provider delegation)
**Reverted:** 0

**Overall:** simplify: clean (story-scoped changes are type-level only)

**Quality Gate:** Build clean, 31/31 tests passing

**Handoff:** To Reviewer (Josh Lyman)

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `req.body` → `processOTLPMetrics/Logs(body)` → `parseOTLP*(body)` → `body as OTLPMetricsPayload/OTLPLogsPayload` → nested traversal with `?.` and `?? []` guards → accumulation/event extraction. Graceful degradation on malformed input (returns empty object/array).

**Pattern observed:** Interfaces mirror cyclist's reference implementation field-for-field on all accessed fields. `OTLPLogRecord` intentionally omits `traceId`/`spanId` (present in cyclist) since core doesn't use them — correct minimal interface. `OTLPMetricsPayload` renamed from cyclist's `OTLPPayload` for clarity.

**Error handling:** All nested traversals use optional chaining (`?.`) and nullish coalescing (`?? []`). No new crash paths. Cast assertions are safe because guard clauses (`if (!payload?.resourceMetrics)`) catch malformed shapes before traversal.

**Security:** No user-facing input paths affected. OTLP payloads come from Claude Code's instrumentation, not external users.

**Handoff:** To SM (Leo McGarry) for finish-story

## Delivery Findings

### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- No upstream findings during implementation.

### TEA (test verification)
- **Improvement** (non-blocking): Pre-existing non-null assertions in `processLogEvents` fallback chain at line 383 bypass type safety. Affects `packages/core/src/server/otlp-receiver.ts` (could be cleaned up in a future tech debt pass). *Found by TEA during test verification.*
- **Improvement** (non-blocking): Unused `_durationMs` parameter in `enrichEntrySync` at line 425. Affects `packages/core/src/server/otlp-receiver.ts` (remove parameter and update callers). *Found by TEA during test verification.*

### Reviewer (code review)
- **Improvement** (non-blocking): `OTLPLogRecord` omits `traceId` and `spanId` fields present in cyclist's interface. Affects `packages/core/src/server/otlp-receiver.ts` (add fields if future stories need trace correlation in standalone mode). *Found by Reviewer during code review.*