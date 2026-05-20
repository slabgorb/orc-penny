---
story_id: "148-6"
jira_key: "PROJ-16427"
epic: "PROJ-16421"
workflow: "tdd"
---

# Story 148-6: Debug pane not receiving signals from WebSocket

## Story Details
- **ID:** 148-6
- **Jira Key:** PROJ-16427
- **Epic:** 148 (PROJ-16421)
- **Workflow:** tdd
- **Points:** 3
- **Stack Parent:** none

## Story Context

**Problem:** The debug pane's token-stats WebSocket channel is completely unwired. Story 148-5 fixed the spans/traces/logs OTLP path for the audit log, but the metrics OTLP path for token-stats was never connected.

**Root Cause (4 gaps):**
1. `app.py` `/v1/metrics` endpoint processes metrics into `_receiver._token_stats` but never calls `broadcast("token-stats", ...)`
2. `ws_push.py` CHANNEL_FETCHERS has no `token-stats` fetcher — no initial data served to new WebSocket connections
3. `ws_push.py` POLL_CHANNELS does not include `token-stats` — never polled
4. `debug_panel.py` reads `totalCostUsd` but OTLPReceiver sends `totalCost` — field name mismatch

**Key Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/wheelhub/app.py` — OTLP metrics endpoint
- `pennyfarthing/pennyfarthing-dist/src/pf/wheelhub/ws_push.py` — CHANNEL_FETCHERS and POLL_CHANNELS
- `pennyfarthing/pennyfarthing-dist/src/pf/bikerack/debug_panel.py` — field name bug
- `pennyfarthing/pennyfarthing-dist/src/pf/wheelhub/otlp.py` — OTLPReceiver (source of truth)
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_148_5_audit_log_otel.py` — reference test pattern

## Acceptance Criteria

1. Token-stats broadcast wired in `/v1/metrics` endpoint
2. `token-stats` fetcher added to CHANNEL_FETCHERS for initial WebSocket data
3. Field name mismatch fixed (totalCost vs totalCostUsd)
4. Debug pane receives and displays live token usage data

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-13T22:32:31Z
**Next Agent:** dev (GREEN phase)

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-13T22:15:38Z | 2026-03-13T22:16:51Z | 1m 13s |
| red | 2026-03-13T22:16:51Z | 2026-03-13T22:21:01Z | 4m 10s |
| green | 2026-03-13T22:21:01Z | 2026-03-13T22:23:31Z | 2m 30s |
| spec-check | 2026-03-13T22:23:31Z | 2026-03-13T22:24:29Z | 58s |
| verify | 2026-03-13T22:24:29Z | 2026-03-13T22:26:09Z | 1m 40s |
| review | 2026-03-13T22:26:09Z | 2026-03-13T22:31:51Z | 5m 42s |
| spec-reconcile | 2026-03-13T22:31:51Z | 2026-03-13T22:32:31Z | 40s |
| finish | 2026-03-13T22:32:31Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): Root cause #3 (POLL_CHANNELS missing token-stats) may be unnecessary if broadcast-on-event is sufficient. Token stats only change when `/v1/metrics` is POSTed, so periodic polling adds no value — broadcast covers all updates. Dev should evaluate whether polling is needed. Affects `pennyfarthing/pennyfarthing-dist/src/pf/wheelhub/ws_push.py` (POLL_CHANNELS set). *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): Test isolation — tests in `TestMetricsEndpointBroadcast` and `TestTokenStatsFetcher` use `>=` assertions to compensate for shared module-level `_receiver` state. Not blocking but could cause flaky test order dependencies. Affects `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_148_6_debug_pane_otel.py` (add autouse fixture to reset receiver between tests). *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** 2 findings (0 Gap, 0 Conflict, 0 Question, 2 Improvement)
**Blocking:** None

- **Improvement:** Root cause #3 (POLL_CHANNELS missing token-stats) may be unnecessary if broadcast-on-event is sufficient. Token stats only change when `/v1/metrics` is POSTed, so periodic polling adds no value — broadcast covers all updates. Dev should evaluate whether polling is needed. Affects `pennyfarthing/pennyfarthing-dist/src/pf/wheelhub/ws_push.py`.
- **Improvement:** Test isolation — tests in `TestMetricsEndpointBroadcast` and `TestTokenStatsFetcher` use `>=` assertions to compensate for shared module-level `_receiver` state. Not blocking but could cause flaky test order dependencies. Affects `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_148_6_debug_pane_otel.py`.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Omitted POLL_CHANNELS test** → ✓ ACCEPTED by Reviewer: Correct architectural call. Token stats are event-driven; polling adds no value.
  - Spec source: Story context, Root Cause #3
  - Spec text: "ws_push.py POLL_CHANNELS does not include token-stats — never polled"
  - Implementation: No test for POLL_CHANNELS inclusion — only broadcast and fetcher tested
  - Rationale: Token stats are event-driven (change only when /v1/metrics POSTed), not externally mutating like git/sprint data. Polling adds no value; broadcast-on-event is the correct pattern. Dev should decide.
  - Severity: minor
  - Forward impact: none

### Dev (implementation)
- **Skipped POLL_CHANNELS addition per TEA finding** → ✓ ACCEPTED by Reviewer: Event-driven broadcast is architecturally correct for data that only changes on explicit POST. Polling would waste resources.
  - Spec source: Story context, Root Cause #3
  - Spec text: "ws_push.py POLL_CHANNELS does not include token-stats — never polled"
  - Implementation: Did not add token-stats to POLL_CHANNELS
  - Rationale: Agreed with TEA's finding — token stats are event-driven, not externally mutating. Broadcast-on-event from /v1/metrics is the correct pattern. Polling would re-send identical data every 5 seconds for no reason.
  - Severity: minor
  - Forward impact: none

### Reviewer (audit)
- No additional deviations found. Both logged deviations are well-documented with proper 6-field format and sound architectural rationale.

### Architect (reconcile)
- No additional deviations found. TEA and Dev entries verified: spec sources reference real story context (Root Cause #3), spec text accurately quotes the session's root cause list, implementation descriptions match the actual code (POLL_CHANNELS was not modified), rationale is architecturally sound (event-driven vs polling), and forward impact is correctly assessed as none — no sibling stories depend on token-stats polling. Reviewer stamps are present on both entries. All 4 ACs are DONE with no deferrals.

## SM Assessment

**Story selected:** 148-6 — Debug pane not receiving signals from WebSocket (3pts, p0, tdd)

**Investigation:** Traced the full OTel signal path from hook emission through WheelHub OTLP endpoints to WebSocket channels to TUI panels. Story 148-5 (completed today) fixed the spans/traces/logs path for the audit log. The debug pane's token-stats channel has a parallel but distinct pipeline that was never wired up — 4 discrete gaps identified in the story context above.

**Routing:** TDD workflow → Thufir Hawat (TEA) for red phase. Reference test at `test_148_5_audit_log_otel.py` provides the exact pattern for testing OTLP-to-WebSocket wiring.

**Risk:** Low. Well-scoped, clear root cause, good reference implementation from 148-5.

## TEA Assessment

**Tests Required:** Yes
**Reason:** 3 distinct implementation gaps in the OTel metrics → token-stats → DebugPanel pipeline

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_148_6_debug_pane_otel.py` — 20 tests covering all 4 ACs

**Tests Written:** 20 tests covering 4 ACs
**Status:** RED (9 failing, 11 passing — all failures are assertion-based)

**Failure Breakdown:**
| AC | Failing Tests | Root Cause |
|----|--------------|------------|
| AC1: Broadcast wiring | 3 | `/v1/metrics` never calls `broadcast("token-stats", ...)` |
| AC2: Channel fetcher | 4 | `CHANNEL_FETCHERS` missing `"token-stats"` entry |
| AC3: Field name | 2 | `debug_panel.py` reads `totalCostUsd`, receiver stores `totalCost` |
| AC4: Panel display | 0 | Panel handler works — only blocked by upstream gaps |

**Implementation guidance for Dev:**
1. In `app.py:otlp_metrics` — after `_receiver.process_metrics(body)`, call `await broadcast("token-stats", _receiver.get_token_stats())` (only when parsed metrics are non-empty)
2. In `ws_push.py` — add `fetch_token_stats()` function and register in `CHANNEL_FETCHERS["token-stats"]`
3. In `debug_panel.py:465` — change `stats.get("totalCostUsd")` to `stats.get("totalCost")`

**Handoff:** To Reverend Mother Gaius Helen Mohiam (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/wheelhub/app.py` — Added broadcast("token-stats", ...) after process_metrics in /v1/metrics endpoint; pre-check with parse_otlp_metrics to only broadcast when metrics are non-empty
- `pennyfarthing/pennyfarthing-dist/src/pf/wheelhub/ws_push.py` — Added fetch_token_stats() function and registered in CHANNEL_FETCHERS["token-stats"]
- `pennyfarthing/pennyfarthing-dist/src/pf/bikerack/debug_panel.py` — Fixed field name: totalCostUsd → totalCost

**Tests:** 20/20 passing (GREEN) + 28/28 regression check on 148-5
**Branch:** feat/148-6-debug-pane-otel-token-stats (pushed)

**Handoff:** To Leto II (Reviewer) via verify phase

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None

All 4 ACs are directly addressed by the implementation:
- AC1: Broadcast wired with smart non-empty guard (parse before broadcast)
- AC2: Fetcher registered in CHANNEL_FETCHERS for initial WS data
- AC3: Field name corrected to match OTLPReceiver source of truth
- AC4: Satisfied by composition of AC1-AC3

**Deviation Review:** TEA and Dev both logged the POLL_CHANNELS omission with proper 6-field format. The rationale is architecturally sound — token-stats is event-driven (changes only on OTLP POST), unlike git/sprint/context which mutate externally. Broadcast-on-event is the correct pattern here. No polling needed.

**Decision:** Proceed to verify phase.

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 6 findings | env resolution duplication, utility extraction, WebSocket error handling — all pre-existing |
| simplify-quality | 17 findings | bare except patterns, type safety — all pre-existing across full files |
| simplify-efficiency | 3 findings | redundant YAML parsing, utility duplication, tier ternary — all pre-existing |

**Applied:** 0 high-confidence fixes (all findings target pre-existing code, not story changes)
**Flagged for Review:** 0 medium-confidence findings relevant to story
**Noted:** 26 total observations about pre-existing code quality
**Reverted:** 0

**Overall:** simplify: clean — the 3 story changes (broadcast, fetcher, field name fix) are minimal and correct

**Quality Checks:** 48/48 tests passing (20 story + 28 regression)
**Handoff:** To Leto II (The God Emperor) for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 5 | dismissed 5 (pre-existing patterns, diff display artifact, correct zero-value behavior) |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 5 | dismissed 5 (all pre-existing bare-except pattern, not introduced by this story) |
| 4 | reviewer-test-analyzer | Yes | findings | 8 | confirmed 1 (test isolation), dismissed 7 (minor/low confidence) |
| 5 | reviewer-comment-analyzer | Yes | findings | 4 | dismissed 4 (low severity docstring updates, not blocking) |
| 6 | reviewer-type-design | Yes | findings | 3 | dismissed 3 (pre-existing untyped patterns, flat dict format correct for this channel) |
| 7 | reviewer-security | Yes | findings | 4 | dismissed 4 (pre-existing patterns, local dev tool, no new attack surface) |
| 8 | reviewer-simplifier | Yes | findings | 2 | dismissed 2 (double-parse minor inefficiency, orphaned line is diff artifact) |

All received: Yes
Total findings: 1 confirmed (non-blocking), 30 dismissed (with rationale), 0 deferred

## Reviewer Assessment

**Verdict:** APPROVED

**Review Checklist:**
- [x] Subagent completion gate passed: All 8 rows filled
- [x] 5+ observations (see below)
- [x] Data flow traced
- [x] Wiring checked
- [x] Pattern identified
- [x] Error handling verified
- [x] Security analysis done
- [x] Hard questions asked
- [x] Subagent findings incorporated
- [x] Judgment made

**Observations:**

1. [VERIFIED] **Data flow traced:** OTLP metrics POST → `parse_otlp_metrics(body)` → `process_metrics(body)` → `broadcast("token-stats", get_token_stats())` → WebSocket → `_handle_token_stats_message` → `_render_token_stats`. Complete end-to-end path confirmed at `app.py:148-153` → `ws_push.py:467-470` → `debug_panel.py:132-137` → `debug_panel.py:441-475`.

2. [VERIFIED] **Wiring correct:** `fetch_token_stats` registered in `CHANNEL_FETCHERS["token-stats"]` at `ws_push.py:486`. Channel `"token-stats"` exists in `WS_CHANNELS` at `app.py:35`. DebugPanel subscribes at `debug_panel.py:83`. All three connection points verified.

3. [VERIFIED] **Pattern consistent:** Implementation follows the exact pattern established by 148-5 for spans: broadcast from OTLP endpoint + fetcher in CHANNEL_FETCHERS. The flat dict format (no `{"type": "init"}` wrapper) is correct because `_handle_token_stats_message` stores the raw message directly, unlike `_handle_context_message` which unwraps.

4. [VERIFIED] **Error handling:** Broadcast failure after `process_metrics` is acceptable — state is already saved, just WS push fails. Pre-existing `except Exception: pass` pattern covers this. No new error paths introduced.

5. [LOW] [TEST] **Test isolation concern:** Tests use `>=` assertions instead of `==` to compensate for shared `_receiver` state across test classes. Non-blocking — tests pass reliably in sequence, and the `>=` guards against accumulation from prior tests. Future improvement: add autouse fixture.

6. [VERIFIED] [EDGE] **Boundary conditions verified:** Empty payloads return early (no broadcast), zero-value metrics broadcast correctly (non-empty dict is truthy), accumulation across calls works. All edge paths in `parse_otlp_metrics` exercised by tests.

7. [VERIFIED] [SILENT] **No new silent failures:** The bare `except Exception: pass` in `otlp_metrics` is pre-existing and now covers broadcast too. Ordering is correct: `process_metrics` runs before `broadcast`, so state is saved even if broadcast fails. No new error swallowing introduced.

8. [VERIFIED] [DOC] **Documentation adequate:** `fetch_token_stats` has clear docstring. Module-level docstrings describe OTLP endpoints. Minor improvement: could note token-stats broadcast in app.py docstring, but not blocking.

9. [VERIFIED] [TYPE] **Type contract consistent:** Producer (`OTLPReceiver.get_token_stats()`) returns `dict[str, int|float]` with keys `{inputTokens, outputTokens, cacheReadTokens, cacheCreationTokens, totalCost}`. Consumer (`_render_token_stats`) reads exact same keys via `stats.get()`. Flat dict format (no `{"type": "init"}` wrapper) is correct — `_handle_token_stats_message` stores raw message directly.

10. [VERIFIED] [SEC] **No new attack surface:** Local dev tool with existing CORS `allow_origins=["*"]`. Token stats broadcast adds no new injection path — data flows from OTLP receiver (trusted internal source) to WebSocket (local TUI). No user input in the broadcast payload.

11. [LOW] [SIMPLE] **Double parse:** `parse_otlp_metrics` called in `app.py:150` then again inside `process_metrics` at `otlp.py:232`. Minor inefficiency (~microseconds). Not blocking — the guard prevents unnecessary broadcast on empty payloads, which is the real value.

**Handoff:** To Stilgar (SM) for finish-story

## Work Log

<!-- Agents record work here as they progress through phases -->