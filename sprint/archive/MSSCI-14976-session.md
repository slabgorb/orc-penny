# Story 104-2: WheelHub config file watch + panel focus broadcast

**Jira:** MSSCI-14976
**Epic:** 104 — /bc CLI Panel Focus (MSSCI-14952)
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/104-2-wheelhub-config-watch-panel-focus
**Assigned:** keith.avery@1898andco.io

---

## Acceptance Criteria

- [ ] WheelHub watches config.local.yaml for `focus` key changes
- [ ] `/ws/focus` WebSocket endpoint exists with client set, upgrade route, connection handler
- [ ] On connect, client receives `{ type: 'init', focus: string | null }` with current focus value
- [ ] On focus change, clients receive `{ type: 'update', focus: string | null }`
- [ ] Broadcast only fires when focus value actually changes (track lastKnownFocus)
- [ ] Extends existing settings watcher (Option A from tech context) — no separate file watcher
- [ ] Focus reader function parses config.local.yaml and returns focus value or null

## Technical Context

See `sprint/context/context-epic-104.md` § Story 104-2 for full architecture details.

**Key file:** `packages/cyclist/src/websocket.ts`

**Pattern:** Follow existing WebSocket channel pattern (client set → WSS → upgrade route → connection handler → broadcast function). Extend existing settings config watcher to also detect focus changes.

**Constraint:** Only broadcast when focus actually changes. Track `lastKnownFocus`.

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Server-side logic with multiple ACs requiring config parsing, change detection, and message formatting

**Test Files:**
- `packages/cyclist/tests/MSSCI-14976-focus-panel.test.ts` — 37 tests (32 failing, 5 passing)

**Stub Files:**
- `packages/cyclist/src/focus.ts` — extracted module with `getConfigFocus`, `shouldBroadcastFocus`, `createFocusMessage`, `isValidFocusPanel`

**Tests Written:** 37 tests covering all 7 ACs
- AC7: 9 tests — `getConfigFocus` (file parsing, missing file, malformed YAML, edge cases)
- AC5: 6 tests — `shouldBroadcastFocus` (change detection, null handling)
- AC3/AC4: 6 tests — `createFocusMessage` (init/update format, JSON serialization)
- AC2: 3 tests — broadcast behavior (OPEN/CLOSED clients, message format)
- AC1/AC6: 3 tests — config watcher integration (rewrite detection, no-change skip, reset)
- Panel validation: 6 tests — `isValidFocusPanel`
- Constants: 4 tests — `VALID_FOCUS_PANELS`

**Status:** RED (32 failing — ready for Dev)

**Architecture Note:** Focus logic extracted into `src/focus.ts` for testability. Dev must:
1. Implement the 4 functions in `src/focus.ts`
2. Wire into `websocket.ts`: add focusClients set, focusWss WSS, `/ws/focus` upgrade route, connection handler, `broadcastFocusUpdate()`, extend settings watcher

**Handoff:** To Dev for implementation (green phase)

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/focus.ts` — implemented getConfigFocus, shouldBroadcastFocus, createFocusMessage, isValidFocusPanel
- `packages/cyclist/src/websocket.ts` — added focusClients set, focusWss WSS, /ws/focus upgrade route, connection handler, broadcastFocusUpdate(), extended settings watcher

**Tests:** 37/37 passing (GREEN)
**PR:** #843 — feat(104-2): WheelHub config file watch + panel focus broadcast
**Branch:** feature/104-2-wheelhub-config-watch-panel-focus (pushed)

**Handoff:** To Reviewer for code review

---

## Reviewer Assessment

**Verdict:** APPROVED (re-review after rejection fix)
**Data flow traced:** `/bc sprint` → config.local.yaml write → fs.watch fires → getConfigFocus reads → shouldBroadcastFocus checks → broadcastFocusUpdate sends to /ws/focus clients (safe: read-only channel, no user input processed)
**Pattern observed:** WS channel pattern followed precisely (client set, WSS, upgrade, handler, broadcast, getter) at `websocket.ts:165,444,522,796,1668`
**Error handling:** try-catch in getConfigFocus handles malformed YAML, missing files, missing directories at `focus.ts:33-44`
**Previous HIGH resolved:** `/ws/focus` added to `PRE_BIKERACK_CHANNELS` at `tests/MSSCI-14825-bikerack-integration.test.ts:374` — 83/83 integration tests GREEN
**Tests:** 37/37 focus + 83/83 integration = 120/120 GREEN
**Handoff:** To SM for finish-story

---

## Session Log

- Setup: Session created, branch created, Jira claimed
- Handoff: SM → TEA for red phase (test design)
- TEA: 37 tests written (32 RED), committed to feature branch
- Handoff: TEA → Dev for green phase
- Dev: Implemented focus.ts + wired websocket.ts, 37/37 GREEN, PR #843 created
- Handoff: Dev → Reviewer for code review
- Reviewer: REJECTED — test regression in MSSCI-14825 (channel count). Fix: add '/ws/focus' to PRE_BIKERACK_CHANNELS
- Handoff: Reviewer → Dev for fix
- Dev: Fixed — added '/ws/focus' to PRE_BIKERACK_CHANNELS, 83/83 integration + 37/37 focus tests GREEN, pushed
- Handoff: Dev → Reviewer for re-review
- Reviewer: APPROVED — HIGH fixed, 120/120 tests GREEN. Merging PR #843
- Handoff: Reviewer → SM for finish-story
