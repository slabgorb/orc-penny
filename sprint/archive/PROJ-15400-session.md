# Story 120-4: Fix TUI reconnecting flicker from unsupported WS channel

**Status:** in-progress
**Workflow:** trivial
**Phase:** finish
**Jira:** PROJ-15400
**Branch:** feature/120-4-fix-tui-reconnecting-flicker
**Repos:** pennyfarthing
**Epic:** 120 — BikeRack TUI Enhancements

## Story Context

**Title:** Fix TUI reconnecting flicker from unsupported WS channel

**Points:** 2

**Priority:** p1

**Description:**
BikeRack TUI connection status flickers between Connected and Reconnecting because ws_client.py uses a single shared connection state and the nonexistent background-tasks WS channel poisons it for all other working channels.

**Problem:**
- The ws_client.py module uses a single shared connection state across all WebSocket channels
- When a channel (background-tasks) doesn't exist or fails to connect, it corrupts the shared state
- This causes the UI to flicker between Connected and Reconnecting states
- The issue affects the visual stability of the BikeRack TUI

**Acceptance Criteria:**
- Connection status should remain stable and not flicker
- Individual channel failures should not affect the shared connection state
- The TUI should gracefully handle unsupported WS channels

## SM Assessment

**Routing:** Trivial workflow — straight to Dev. This is a 2-point bug fix with clear scope: ws_client.py shared connection state gets poisoned by failed channel connections. The fix should isolate per-channel connection state so one bad channel doesn't flicker the whole TUI.

**Key files to investigate:** `pennyfarthing_scripts/bikerack/ws_client.py` — the shared connection state logic.

**Risk:** Low. Scoped to BikeRack TUI connection handling.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/pf/bikerack/ws_client.py` — Added per-channel state tracking (`_channel_states` dict), `_set_channel_state()` method that derives aggregate from individual channels, dedup guard in `_set_state()`. Channel loops now update per-channel state instead of shared state directly.
- `tests/python/test_wheelhub_client.py` — 3 regression tests: failing channel doesn't override CONNECTED aggregate, all-channels-failing shows RECONNECTING, callback deduplication.

**Tests:** 29/29 passing (GREEN)
**Branch:** feature/120-4-fix-tui-reconnecting-flicker (pushed)

**AC Coverage:**
- Connection status remains stable: per-channel isolation prevents flicker from racing channel loops
- Individual channel failures don't affect shared state: aggregate stays CONNECTED if any channel is up
- Graceful handling of unsupported channels: failing channels are tracked independently, don't corrupt healthy ones

**Handoff:** To Reviewer (Colonel Potter) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** channel_loop → _set_channel_state → aggregate computation → _set_state → callback → WsStateUpdate → ConnectionStatus.reactive (safe end-to-end, no injection points)
**Pattern observed:** Per-channel state isolation with aggregate derivation at `ws_client.py:80-97` — standard multi-connection manager pattern, correctly implemented
**Error handling:** Broad `except Exception` in channel_loop (line 159) is pre-existing and appropriate for reconnect logic; disconnect teardown clears channel states cleanly at `ws_client.py:200-203`
**Concurrency:** Asyncio cooperative scheduling verified — no race conditions in `_set_channel_state` despite concurrent channel loops
**Tests:** 29/29 GREEN (3 new regression tests cover exact bug scenario + edge cases)
**Low findings:** No explicit unit test for mid-session channel drop transition (implicit coverage adequate)

**Handoff:** To SM (Hawkeye Pierce) for finish-story

## Session Log

### Setup — 2026-02-21
- Story started with sprint CLI
- Jira ticket claimed: PROJ-15400 (assigned to slabgorb@gmail.com)
- Branch created: feature/120-4-fix-tui-reconnecting-flicker
- Session created for development
- Workflow: trivial (SM → Dev → Reviewer → SM)