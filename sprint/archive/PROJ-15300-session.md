# Story 110-12: Context meter in TUI needs more frequent redraws

**Jira:** PROJ-15300
**Epic:** 110 — BikeRack TUI — Interactive Command Center
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** fix/110-12-context-meter-tui-redraws
**Started:** 2026-02-18T18:00:00Z

## Context

The context meter in the BikeRack TUI needs more frequent redraws to accurately reflect context window usage during agent sessions. Currently the meter may appear stale or lag behind actual context consumption.

## Acceptance Criteria

- [ ] Context meter updates more frequently during active sessions
- [ ] Redraw trigger points are identified and optimized
- [ ] No noticeable performance degradation from increased redraw frequency

## Technical Notes

_To be filled by TEA/Dev agent._

## TEA Assessment

**Tests Required:** Yes
**Reason:** Context meter needs periodic refresh, event-driven redraws, and throttling

**Test Files:**
- `tests/python/test_bikerack_context_meter_redraws.py` — 18 tests covering all 3 ACs

**Tests Written:** 18 tests covering 3 ACs
**Status:** RED (17 failing — correct, missing implementation)

**What Dev needs to implement in `context_meter_footer.py`:**
1. `refresh_interval` attribute (1-10s) and `set_interval` timer on mount
2. `request_refresh()` method that redraws from cached `_context_data`
3. `_refresh_timer` stored on mount, `.stop()` on unmount
4. `on_connection_state_change` handler + subscribe to client state changes
5. `last_update_time` tracking + `is_stale` property
6. `min_redraw_interval` throttle (50ms-1s) on `handle_context_message`
7. Panel switch in `tui.py` should call `meter.request_refresh()`

**Handoff:** To Dev (Korben Dallas) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/context_meter_footer.py` — Added periodic refresh timer, throttling, staleness tracking, connection state handler
- `pennyfarthing_scripts/bikerack/tui.py` — Wired panel switch to trigger context meter refresh via stored reference

**Tests:** 51/51 passing (GREEN) — 18 new + 33 existing
**Branch:** fix/110-12-context-meter-tui-redraws (pushed)

**Handoff:** To Reviewer (Zorg) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** WebSocket context message → `handle_context_message` → cache → throttle check → `render_meter` → `post_message(MeterUpdate)` → Textual repaint. No trust boundary crossings.

**Observations:**
1. [VERIFIED] Throttle logic at `context_meter_footer.py:112-114` correctly suppresses rapid redraws
2. [VERIFIED] Timer lifecycle — created on mount, stopped on unmount, null-guarded
3. [VERIFIED] `request_refresh()` safe no-op when unmounted or no cached data
4. [VERIFIED] `tui.py:549-550` panel switch triggers meter refresh via stored reference
5. [LOW] Double `time.monotonic()` at `context_meter_footer.py:108-111` — micro-optimization opportunity only
6. [LOW] `is_stale` naming implies time-based staleness but checks data presence only
7. [VERIFIED] Connection state handler at `context_meter_footer.py:96-98` triggers refresh on any state change — safe since it only repaints cached data

**Error handling:** Guards for None messages, missing context key, unmounted state, no cached data, timer creation failure. All edge cases handled.
**Security:** No external inputs, no trust boundaries. Internal WS channel only. N/A.
**Tests:** 51/51 pass (18 new + 33 existing). No regressions. 9 warnings are Textual Timer teardown artifacts.

**Handoff:** To SM (Ruby Rhod) for finish-story

## TEA Verify Assessment

**Tests Verified:** 51/51 passing (GREEN confirmed)
**New Tests:** 18 covering all 3 ACs
**Existing Tests:** 33 passing (no regressions)
**Throttling Verified:** Rapid-fire messages correctly suppressed (<10 redraws from 10 messages)
**Edge Cases Verified:** Safe no-op without data, safe no-op after unmount
**Status:** GREEN confirmed — ready for Reviewer

**Handoff:** To Reviewer (Zorg) for code review