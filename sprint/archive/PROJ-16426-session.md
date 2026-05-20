---
story_id: "148-5"
jira_key: "PROJ-16426"
epic: "PROJ-16421"
workflow: "tdd"
---
# Story 148-5: Audit log pane not recording OTEL traces via WebSocket

## Story Details
- **ID:** 148-5
- **Jira Key:** PROJ-16426
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-13T18:24:29Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-13T17:15:10Z | 2026-03-13T17:16:25Z | 1m 15s |
| red | 2026-03-13T17:16:25Z | 2026-03-13T17:24:16Z | 7m 51s |
| green | 2026-03-13T17:24:16Z | 2026-03-13T17:26:47Z | 2m 31s |
| spec-check | 2026-03-13T17:26:47Z | 2026-03-13T17:41:37Z | 14m 50s |
| verify | 2026-03-13T17:41:37Z | 2026-03-13T18:16:14Z | 34m 37s |
| review | 2026-03-13T18:16:14Z | 2026-03-13T18:21:36Z | 5m 22s |
| spec-reconcile | 2026-03-13T18:21:36Z | 2026-03-13T18:24:29Z | 2m 53s |
| finish | 2026-03-13T18:24:29Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): SM assessment says "OTLP receiver parses traces but data isn't broadcast to audit-log channel." Correction: the `AuditLogPanel` subscribes to the `spans` channel (not `audit-log`), and `process_traces()` is a complete no-op — it doesn't parse anything. Additionally, `process_logs()` returns parsed events but the `/v1/logs` endpoint discards the return value. The pipeline is severed at 4 points, not 1. Affects `pf/wheelhub/otlp.py`, `pf/wheelhub/app.py`, `pf/wheelhub/routes/state.py`. *Found by TEA during test design.*
- **Gap** (non-blocking): `_enriched_spans` list in `state.py:404` has no code path that ever appends to it. The `fetch_spans()` fetcher in `ws_push.py` reads it, but it's always empty. Fix should wire `OTLPReceiver.get_spans()` into `fetch_spans()` or populate `_enriched_spans` from OTLP processing. Affects `pf/wheelhub/ws_push.py` and `pf/wheelhub/routes/state.py`. *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): `_enriched_spans` in `state.py:404` is now orphaned — `fetch_spans()` reads from `_receiver.get_spans()` instead. The dead list and its GET/DELETE/filter routes in `state.py` could be cleaned up. Affects `pf/wheelhub/routes/state.py` (spans_router). *Found by Dev during implementation.*

### Reviewer (code review)
- No upstream findings during code review.

## SM Assessment

**Story context:** Bug fix — the audit log TUI pane is not receiving OTEL traces via WebSocket. The OTLP receiver in WheelHub (`pf/wheelhub/otlp.py`) parses traces but the data isn't being broadcast to the `audit-log` WebSocket channel for TUI consumption.

**Key files for TEA to investigate:**
- `pennyfarthing/pennyfarthing-dist/src/pf/wheelhub/otlp.py` — OTEL receiver (traces endpoint is deferred)
- `pennyfarthing/pennyfarthing-dist/src/pf/wheelhub/ws_push.py` — WebSocket broadcast (audit-log channel)
- `pennyfarthing/pennyfarthing-dist/src/pf/wheelhub/app.py` — FastAPI routes + channel registration
- `pennyfarthing/pennyfarthing-dist/src/pf/bikerack/ws_client.py` — TUI WebSocket client

**Dependency note:** This story is a prerequisite for 148-8 (Peloton mode). OTEL trace routing must work before multi-agent pipeline visualization is viable.

**Routing:** TDD workflow → TEA (red phase) for test design.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Bug fix — 4 severed links in the OTEL → WebSocket → TUI pipeline need implementation and testing

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_148_5_audit_log_otel.py` — 28 tests covering trace parsing, span storage, log-to-span conversion, buffer bounding, WebSocket broadcast integration, and edge cases

**Tests Written:** 28 tests (24 failing, 4 passing on stubs)
**Status:** RED (failing — ready for Dev)

**Root Cause Analysis (for Dev):**
1. `otlp.py:process_traces()` — no-op, needs to parse OTLP traces into span dicts with keys: `toolName`, `timestamp`, `durationMs`, `success`, `input`, `toolParameters`
2. `otlp.py:process_logs()` — returns events but caller discards them. Needs to convert `claude_code.tool_result` events to spans and store
3. `otlp.py:OTLPReceiver` — needs `_spans` buffer with `get_spans()` accessor
4. `app.py:/v1/traces` endpoint — needs to broadcast new spans to `spans` WebSocket channel via `broadcast("spans", {"type": "span", "span": ...})`
5. `app.py:/v1/logs` endpoint — same broadcast path for tool_result events
6. `ws_push.py:fetch_spans()` — should read from `_receiver.get_spans()` instead of dead `_enriched_spans` list

**Handoff:** To Reverend Mother Mohiam (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/wheelhub/otlp.py` — Implemented `parse_otlp_traces()`, `_log_event_to_span()`, `_extract_attr()`, `_coerce_bool()`. Added `_spans` buffer to `OTLPReceiver` with `get_spans()`, `_store_spans()`. Rewired `process_traces()` and `process_logs()` to parse, store, and return spans.
- `pennyfarthing-dist/src/pf/wheelhub/app.py` — `/v1/traces` and `/v1/logs` endpoints now broadcast new spans to `spans` WebSocket channel.
- `pennyfarthing-dist/src/pf/wheelhub/ws_push.py` — `fetch_spans()` reads from `_receiver.get_spans()` instead of dead `_enriched_spans` list.

**Tests:** 28/28 passing (GREEN) + 30/30 existing wheelhub tests pass
**Branch:** feat/148-5-audit-log-otel-websocket (pushed)

**Handoff:** To verify phase (TEA) then Leto II (Reviewer)

## Architect Assessment (Spec-Check)

**Spec Alignment:** Confirmed — implementation addresses all 4 severed pipeline links identified in TEA's root cause analysis.

**AC Coverage:**
1. `otlp.py:process_traces()` — was no-op, now parses OTLP traces into span dicts with correct keys (`toolName`, `timestamp`, `durationMs`, `success`, `input`, `toolParameters`). ✓
2. `otlp.py:process_logs()` — return value no longer discarded; `claude_code.tool_result` events converted to spans and stored. ✓
3. `otlp.py:OTLPReceiver._spans` — buffer added with `get_spans()` accessor and `_store_spans()`. ✓
4. `app.py:/v1/traces` and `/v1/logs` — endpoints broadcast new spans to `spans` WebSocket channel. ✓
5. `ws_push.py:fetch_spans()` — reads from `_receiver.get_spans()` instead of dead `_enriched_spans`. ✓

**Test Coverage:** 28/28 new tests + 30/30 existing wheelhub tests = no regressions.

**Architectural Observations:**
- Dev noted `_enriched_spans` in `state.py` is now orphaned. Non-blocking cleanup — can be addressed in a follow-up chore or next story touching that file.
- The design correctly routes through existing WebSocket broadcast infrastructure rather than introducing new channels. Reuse-first principle satisfied.

**Verdict:** Pass — proceed to verify phase.

## TEA Assessment (Verify)

**Phase:** finish
**Status:** GREEN confirmed

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 4

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 5 findings | 4 high (all out-of-scope or premature abstraction), 1 medium (test duplication) |
| simplify-quality | 1 finding | 1 high (dead code in pre-existing ws_push.py:83) |
| simplify-efficiency | 2 findings | 1 medium (pre-existing ws_push.py:390), 1 low (duplicate of reuse #1) |

**Applied:** 0 high-confidence fixes (all high-confidence findings were either in pre-existing code outside the diff or proposed premature abstractions for trivial patterns)
**Flagged for Review:** 1 medium-confidence finding (test mock_broadcast duplication — acceptable for test clarity)
**Noted:** 1 low-confidence observation (attribute extraction duplication in pre-existing parse_otlp_logs)
**Reverted:** 0

**Overall:** simplify: clean (no in-scope findings warranting changes)

**Quality Checks:** 28/28 story tests + 213/213 wheelhub tests passing
**Handoff:** To Leto II (Reviewer) for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 10 | dismissed 9 (pre-existing, false positive, or Python-safe), noted 1 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 8 | dismissed 8 (pre-existing `except Exception: pass` pattern, OTLP protocol design) |
| 4 | reviewer-test-analyzer | Yes | findings | 6 | confirmed 3 (LOW — test quality), noted 3 (medium) |
| 5 | reviewer-comment-analyzer | Yes | clean | none | N/A |
| 6 | reviewer-type-design | Yes | findings | 5 | dismissed 5 (scope creep for bug fix, pre-existing) |
| 7 | reviewer-security | Yes | findings | 5 | dismissed 5 (all pre-existing — CORS, no auth on localhost dev server) |
| 8 | reviewer-simplifier | Yes | findings | 3 | dismissed 3 (pre-existing code, premature abstractions) |

All received: Yes
Total findings: 3 confirmed (LOW), 34 dismissed (with rationale), 4 noted (medium, non-blocking)

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** OTLP JSON → `request.json()` → `_receiver.process_traces(body)` → `parse_otlp_traces()` → span dicts → `_store_spans()` (bounded buffer) → `broadcast("spans", ...)` → WebSocket clients (AuditLogPanel). Safe because: input is Claude Code's own OTLP instrumentation (not user input), all parsing has defensive defaults, buffer is bounded at MAX_SPANS=500.

**Pattern observed:** Stateless parse functions (`parse_otlp_traces`, `_log_event_to_span`) + stateful accumulator (`OTLPReceiver`) is a clean separation at `otlp.py:112-253`. Matches existing `parse_otlp_metrics`/`parse_otlp_logs` pattern.

**Error handling:** Pre-existing `except Exception: pass` at `app.py:141,161` — correct for OTLP partial success protocol. Broadcast failures inside the try block are silently swallowed, which means spans are stored but WebSocket delivery is best-effort. Acceptable for an observability tool.

**Wiring:** `fetch_spans()` at `ws_push.py:453` correctly imports `_receiver` from `app` and calls `get_spans()` which returns a defensive copy (`list(self._spans)`).

**Security:** OTLP endpoints are unauthenticated on localhost dev server — pre-existing, no change in attack surface. Span data comes from Claude Code's own OTEL SDK, not user input.

**Observations:**
1. `[VERIFIED]` `_log_event_to_span` uses dict-style access on `attrs` — confirmed correct because `parse_otlp_logs` converts OTLP attribute list to flat dict at `otlp.py:98-106`
2. `[VERIFIED]` Buffer bound at `_store_spans` keeps oldest-evicted, newest-retained — `self._spans[-MAX_SPANS:]`
3. `[VERIFIED]` `get_spans()` returns `list(self._spans)` — defensive copy prevents external mutation
4. `[VERIFIED]` `process_logs` return type changed from events to spans — only caller is `app.py:138` which previously discarded the return value, so no breaking change
5. `[TEST]` `test_malformed_timestamp_no_crash` should assert fallback values (timestamp=0, durationMs=0), not just "no crash" — LOW, test exists and covers the path
6. `[TEST]` `test_span_buffer_bounded` should verify oldest spans evicted, not just count ≤ 500 — LOW, eviction logic is simple slice
7. `[TEST]` `test_fetch_spans_reflects_received_traces` depends on module-level `_receiver` singleton — LOW, test is order-dependent but isolated enough in practice
8. `[EDGE]` All 10 edge-hunter findings dismissed: negative timestamps/durations handled by Python int, attrs type mismatch verified as false positive (parse_otlp_logs flattens to dict), broadcast timeout/partial failure is pre-existing OTLP protocol design
9. `[SILENT]` All 8 silent-failure findings dismissed: `except Exception: pass` blocks at `app.py:141,161` are pre-existing and correct for OTLP partial success protocol; silent timestamp defaults are by design
10. `[DOC]` Comment-analyzer returned clean — all docstrings accurate and up-to-date with implementation
11. `[TYPE]` All 5 type-design findings dismissed: stringly-typed spans (medium) and missing TypedDict are scope creep for a bug fix story; inconsistent key naming is pre-existing with defensive handling in AuditLogPanel
12. `[SEC]` All 5 security findings dismissed: CORS wildcard + no auth are pre-existing on localhost-only dev server; span data is from Claude Code's own OTLP instrumentation, not user input
13. `[SIMPLE]` All 3 simplifier findings dismissed: `if new_spans:` guard is a valid optimization, attr extraction duplication is in pre-existing `parse_otlp_logs`, broadcast loop duplication is 3 lines used twice
14. `[IMPROVEMENT]` `_enriched_spans` and its REST routes in `state.py:404-420` are now orphaned dead code — non-blocking cleanup for future chore

**Handoff:** To Stilgar (SM) for finish-story

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No deviations from spec. → ✓ ACCEPTED by Reviewer: agrees with author reasoning

### Dev (implementation)
- No deviations from spec. → ✓ ACCEPTED by Reviewer: agrees with author reasoning

### Reviewer (audit)
- No undocumented deviations found. Implementation matches TEA's 6-point root cause analysis precisely.