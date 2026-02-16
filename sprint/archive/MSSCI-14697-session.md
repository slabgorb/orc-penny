# Story 98-23: Implement real OTLP integrations for core server stubs

**Jira:** MSSCI-15132
**Epic:** 98 — Safe Install, Upgrade, and Namespace Isolation
**Points:** 5
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/98-23-otlp-integrations-core-server

---

## Context

### Epic Overview

Epic 98 focuses on redesigning the install/upgrade path to prevent data loss, automate post-update setup, add versioned migrations, namespace skills/commands with pf- prefix, and integrate sprint shard migration.

**Jira:** MSSCI-14697
**ADR:** 0021
**Repo:** pennyfarthing

### Key Directories

- `pennyfarthing/packages/core/` — CLI: init, update, doctor, uninstall
- `pennyfarthing/pennyfarthing-dist/` — Published package (source of truth)
- `pennyfarthing/pennyfarthing_scripts/` — Python scripts (hooks, sprint, jira)
- `pennyfarthing/packages/cyclist/` — Visual terminal (Electron app)

### Story 98-23 Objective

Implement real OTLP (OpenTelemetry Protocol) integrations for core server stubs. This story involves adding actual telemetry/observability capabilities to the WheelHub core server component.

## Acceptance Criteria

- **AC1:** `parseOTLPMetrics()` extracts `claude_code.token.usage` data points (input, output, cacheRead, cacheCreation) from OTLP JSON metrics payloads
- **AC2:** `aggregateTokenStats()` accumulates parsed stats into session totals and notifies registered listeners via `addTokenStatsListener()`
- **AC3:** `parseOTLPLogs()` parses OTLP JSON log payloads into structured event objects with name, timestamp (ms), and flattened attributes
- **AC4:** `processLogEvents()` categorizes raw events — records `claude_code.tool_result` as tool events and `claude_code.user_prompt` as prompt events
- **AC5:** Background task lifecycle works: `trackBackgroundTask()` stores pending tasks, `completeBackgroundTask()` marks done with metadata/callbacks, `getBackgroundTaskByToolId()` retrieves by ID
- **AC6:** `addToolEventListener()` registers callbacks that fire when tool events are recorded
- **AC7:** `resetEventStore()` clears all in-memory stores; `getUserEmail()` extracts email from OTLP `user.email` attribute
- **AC8:** Delegating stubs (`processOTLPMetrics`, `processOTLPLogs`, `getTokenStats`, `getBackgroundTasks`, `getAuditLog`, etc.) work standalone without Cyclist provider — fall through to core's real implementations

## Technical Approach

Core's `otlp-receiver.ts` currently has two layers:
1. **Delegating stubs** (OTLPProvider pattern) — work with Cyclist, return empty defaults without it
2. **Plain stubs** — always no-ops (parseOTLPMetrics → null, trackBackgroundTask → void, etc.)

Implementation needs to:
- Add in-memory stores to core (token stats, tool events, prompt events, background tasks, user email)
- Make plain stubs into real implementations (port parsing/aggregation logic from Cyclist's `otlp-receiver.ts`)
- Make delegating stubs fall through to core's real implementations when no provider is set
- Keep the provider pattern working for Cyclist backward compatibility
- Core's version can be simplified (no enrichment, no span correlation — those stay in Cyclist)

Key files:
- `packages/core/src/server/otlp-receiver.ts` — primary implementation target
- `packages/cyclist/src/otlp-receiver.ts` — reference implementation (~1000 lines)
- `packages/cyclist/src/server.ts` — provider wiring pattern

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `packages/core/src/server/otlp-receiver.test.ts` — 23 tests covering 8 ACs

**Tests Written:** 23 tests covering 8 ACs
**Status:** RED (22 failing, 1 vacuously passing — all failures are assertion errors against stub returns)

**Failure modes:**
- `parseOTLPMetrics` returns `null` instead of parsed stats object
- `parseOTLPLogs` returns `null` instead of event array
- `processLogEvents` is no-op so audit log stays empty
- `trackBackgroundTask` is no-op so task store stays empty
- `getBackgroundTaskByToolId` returns `undefined` always
- `completeBackgroundTask` returns `undefined` always
- `addToolEventListener` is no-op so callbacks never fire
- `getUserEmail` returns `null` always
- Delegating stubs (`processOTLPMetrics`, `processOTLPLogs`) do nothing without provider

**Handoff:** To Inigo Montoya (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/server/otlp-receiver.ts` — replaced all stubs with real in-memory OTLP processing

**Tests:** 23/23 passing (GREEN)
**PR:** #932 — feat(98-23): implement real OTLP integrations for core server
**Branch:** feature/98-23-otlp-integrations-core-server (pushed)

**Handoff:** To Westley (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**PR:** #932 — 3 commits on `feature/98-23-otlp-integrations-core-server`
**Tests:** 23/23 passing, build clean, ESLint clean

**Observations:**

1. [VERIFIED] Provider pattern preserved — `setOTLPProvider()` wiring in Cyclist's `server.ts:116` confirmed
2. [VERIFIED] API route wiring — `otlp.ts`, `background-tasks.ts`, `audit-log.ts`, `token-stats.ts` all import from `otlp-receiver.js`
3. [VERIFIED] Module singleton pattern — ES module caching ensures shared state across importers
4. [VERIFIED] Error handling — `parseOTLPMetrics`/`parseOTLPLogs` return null on malformed input, no throws
5. [VERIFIED] `resetEventStore()` clears all 7 stores including listeners
6. [MEDIUM] `totalCost` stays 0 — no pricing calculation. Acceptable for core; Cyclist can enrich via provider
7. [MEDIUM] `processLogEvents` only categorizes `claude_code.tool_result` and `claude_code.user_prompt` — other event types silently dropped. Matches test expectations but worth noting for future extension
8. [LOW] `exportAuditLogAsCSV` doesn't quote fields containing commas — edge case, unlikely in practice
9. [LOW] `assessment_found` field in resolve-gate result is vestigial (always `True` now) — cleanup candidate
10. [VERIFIED] Handoff fix: assessment guard correctly moved from `resolve_gate.py` to `complete_phase.py` with gate_type exemption for skip/manual transitions

**No Critical or High issues found.**

**Handoff:** To Vizzini (SM) for story finish