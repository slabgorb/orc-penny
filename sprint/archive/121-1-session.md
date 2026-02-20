# Story 121-1: Improve debug panel refresh rate for real-time token usage tracking

**Status:** in-progress
**Phase:** finish
**Workflow:** trivial
**Points:** 2
**Priority:** p1
**Repos:** pennyfarthing
**Branch:** debug-panel-refresh
**Jira:**
**Assigned:**

---

## Context

The debug panel in Cyclist/BikeRack displays token usage metrics but currently lags behind actual context consumption. The refresh rate needs to be improved for near-real-time tracking during agent sessions.

### Potential Bottlenecks (per story description)
1. **WheelHub broadcast interval** — server-side event emission rate
2. **OTEL span ingestion cadence** — how quickly telemetry data is processed
3. **React component polling cycle** — client-side update frequency

### Acceptance Criteria
- [ ] Token usage metrics update in near-real-time during agent sessions
- [ ] Identified and fixed the actual bottleneck (WheelHub broadcast, OTEL ingestion, or React polling)
- [ ] No performance regression from increased refresh rate
- [ ] Debug panel responsiveness verified in both Cyclist and BikeRack modes

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/websocket.ts` — Reduced CONTEXT_DEBOUNCE_MS from 2000ms to 500ms (4x faster context updates), added token stats listener to trigger debounced context refresh on OTLP metric arrival

**Investigation Findings:**
- WheelHub broadcast interval: CONTEXT_DEBOUNCE_MS was 2000ms — **primary bottleneck, fixed**
- OTEL span ingestion: Context refresh only triggered by tool events, not metric arrival — **fixed by adding addTokenStatsListener**
- React component polling: Not a bottleneck (WebSocket push, no polling)

**Tests:** 2198/2200 passing (2 pre-existing skill count failures unrelated to changes)
**Branch:** debug-panel-refresh (pushed)

**Handoff:** To River Tam for review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** OTLP metrics → parseOTLPMetrics → aggregateTokenStats → notifyTokenStatsListeners → new listener (websocket.ts:684) → debounced getContextUsage → broadcastContextUpdate → WebSocket /ws/context → DebugPanel.tsx setContext → re-render. Clean end-to-end.

**Pattern observed:** Shared debounce timer (`contextDebounceTimer`) between two listener sites prevents double-fire. Both at websocket.ts:686 and websocket.ts:1089 use identical clear+set pattern — correct coalescing behavior.

**Error handling:** getContextUsage wraps execSync in try-catch (context.ts:119), returns error object. No unhandled exceptions. 5000ms timeout safety net on the shell script.

**Findings:**
| Severity | Issue | Location | Note |
|----------|-------|----------|------|
| [MEDIUM] | execSync at 500ms debounce spawns 2 Python processes per call | context.ts:67 | Mitigated by debounce; monitor in long sessions |
| [LOW] | Debounce logic duplicated in two listener sites | websocket.ts:684-696 vs 1088-1098 | Could extract helper; cosmetic |

**Pre-existing issues (not blocking):** 5 lint warnings (unused vars in shared/electron), 2 test failures (skill count 22→23). All confirmed present before this change.

**Handoff:** To Zoe Washburne for finish-story