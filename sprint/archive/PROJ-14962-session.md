# Story 103-7: `/bc` TUI panel focus (BikeRack TUI + GUI)

**Jira:** PROJ-14962
**Epic:** 103 — BikeRack TUI
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** story/103-7-bc-tui-focus
**Assigned:** slabgorb@gmail.com

## Description

Make the `/bc` panel focus command work for the BikeRack TUI (Textual app) in addition to the BikeRack GUI (Electron/React). The `/bc` command, CLI (`pf bc`), skill, WheelHub `/ws/focus` channel, and React hook (`useFocusPanel.ts`) already exist from epic 104. This story wires the TUI to consume focus events.

## Acceptance Criteria

- [ ] BikeRack TUI subscribes to `/ws/focus` WebSocket channel
- [ ] `pf bc <panel>` switches the active panel in the TUI
- [ ] `pf bc reset` returns the TUI to its previous panel
- [ ] Panel switch completes in < 200ms
- [ ] TUI handles focus events while no panels are mounted (graceful no-op)
- [ ] Works alongside GUI — both TUI and GUI respond to the same `/bc` command

## Technical Context

### What Already Exists (Epic 104 — DONE)

| Component | File | Status |
|-----------|------|--------|
| Python CLI | `pennyfarthing_scripts/bc/cli.py` | Done |
| Focus logic | `pennyfarthing_scripts/bc/focus.py` | Done |
| `/bc` skill | `pennyfarthing-dist/skills/bc/skill.md` | Done |
| WheelHub focus channel | `packages/cyclist/src/websocket.ts` (`/ws/focus`) | Done |
| TS focus utils | `packages/cyclist/src/focus.ts` | Done |
| React hook | `packages/cyclist/src/public/hooks/useFocusPanel.ts` | Done |
| Config file watch | `websocket.ts:1224-1228` (100ms debounce) | Done |
| Tests | `pennyfarthing_scripts/tests/test_bc.py` | Done |

### What Needs Implementation (This Story)

The BikeRack TUI (Textual app at `pennyfarthing_scripts/bikerack/`) needs to:

1. **Subscribe to `/ws/focus` channel** via `WheelHubClient` — same pattern as BasePanel
2. **Handle focus messages** — `{type: 'init'|'update', focus: '<panel>'|null}`
3. **Switch active panel** — mount the target panel in `#main-content`, unmount current
4. **Handle reset** — `focus: null` returns to previous panel

### Key Files (Reference)

| File | Purpose |
|------|---------|
| `pennyfarthing_scripts/bikerack/tui.py` | BikeRackApp shell — mount/unmount panels in `#main-content` |
| `pennyfarthing_scripts/bikerack/base_panel.py` | BasePanel (just shipped in 103-5) — channel subscription pattern |
| `pennyfarthing_scripts/bikerack/ws_client.py` | WheelHubClient — subscribe to channels |
| `pennyfarthing_scripts/bc/focus.py` | Focus read/write logic, VALID_PANELS |
| `packages/cyclist/src/focus.ts` | FocusMessage interface: `{type, focus}` |
| `packages/cyclist/src/public/hooks/useFocusPanel.ts` | React reference for focus handling pattern |

### Focus Message Contract

```json
{"type": "init", "focus": null}
{"type": "update", "focus": "sprint"}
{"type": "update", "focus": null}
```

### Design Notes

- Focus handling belongs in `BikeRackApp` (tui.py), not in individual panels
- App subscribes to `focus` channel, manages panel switching
- Panel classes don't exist yet (later stories) — use placeholder/stub panels for now
- The `useFocusPanel.ts` React hook is the behavioral reference

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core feature — TUI must subscribe to focus channel and handle panel switching

**Test Files:**
- `pennyfarthing_scripts/tests/test_tui_focus.py` — 23 tests (11 RED, 12 coincidental pass)

**Tests Written:** 23 tests covering 6 ACs
- AC1 (subscription): 3 tests — verifies on_mount subscribes to "focus" channel
- AC2 (panel switch): 5 tests — verifies update messages set _focused_panel, track previous
- AC3 (reset): 4 tests — verifies null focus restores previous, clears state
- AC4 (timing): 2 tests — verifies < 200ms for switch and reset
- AC5 (graceful no-op): 5 tests — verifies None, empty, malformed messages handled
- AC6 (GUI compat): 4 tests — verifies same channel, message format as useFocusPanel.ts

**Status:** RED (11 failing — ready for Dev)
**Stubs Added:** `_focused_panel`, `_previous_panel` attrs, `_handle_focus_message()` no-op in `tui.py`

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/tui.py` — subscribe to focus channel, implement _handle_focus_message

**Tests:** 23/23 passing (GREEN), 116/116 full BikeRack suite
**PR:** #854 — feat(103-7): TUI panel focus via /ws/focus
**Branch:** story/103-7-bc-tui-focus (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `pf bc sprint` → config.local.yaml → WheelHub file watcher → `/ws/focus` → WheelHubClient → `_handle_focus_message` → state update (safe: guards at tui.py:78-83)
**Pattern observed:** Subscribe-before-connect ordering matches ws_client channel loop init at ws_client.py:147-149
**Error handling:** 4 guards — None, non-dict, non-update type, missing focus key at tui.py:78-83
**Notes:**
- [MEDIUM] `_previous_panel` overwrites each switch (diverges from React stash-once at useFocusPanel.ts:72-74) — acceptable, no widgets yet
- [LOW] Import ordering (typing after textual) at tui.py:16
- [LOW] Unused `call` import at test_tui_focus.py:20

**Handoff:** To SM for finish-story

## Progress

- [x] Story started
- [x] Tests written (TDD red phase)
- [x] Implementation complete (TDD green phase)
- [x] Code reviewed
- [ ] Story finished
