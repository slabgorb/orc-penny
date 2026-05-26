# Story 104-3: BikeShow client layout stash/restore on panel focus

**Jira:** PROJ-14977
**Epic:** 104 — /bc CLI Panel Focus (PROJ-14952)
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/104-3-bikeshow-client-layout-stash-restore
**Assigned:** slabgorb@gmail.com

---

## Description

BikeShow client handles `panel:focus` WebSocket events. On focus event: if not already in single-panel view, save current dockview layout as "saved" state. Render requested panel as single-panel view. On reset (focus: null): restore saved layout. Successive /bc calls preserve the original saved state — only the first focus after a reset triggers a save.

## Acceptance Criteria

- [ ] BikeShow connects to `/ws/focus` WebSocket endpoint on mount
- [ ] On `panel:focus` event with panel name, current dockview layout is saved (if not already in focus mode)
- [ ] Requested panel renders as single-panel fullscreen view
- [ ] On `panel:focus` event with `null`, saved layout is restored
- [ ] Successive `/bc` calls preserve the original saved state (no stash stack)
- [ ] Only the first focus after a reset triggers a layout save
- [ ] Works in both BikeRack standalone and full Cyclist mode

## Story Context

### Dependencies
- Story 104-1 (pf bc CLI command + /bc user skill) — DONE, merged
- Story 104-2 (WheelHub config file watch + panel focus broadcast) — DONE, merged
- This story builds on those; the client-side implementation to receive and handle the WebSocket events

### Key Architecture
The flow:
1. CLI: `/bc sprint` → writes focus to config.local.yaml
2. Server (WheelHub): watches config → broadcasts `panel:focus` event over WebSocket
3. **Client (this story):** receives event → stashes layout (once) → renders single panel fullscreen
4. CLI: `/bc reset` → clears focus in config
5. Client: receives event (focus: null) → restores stashed layout

### Valid Panel IDs (accept all except "message" sacred center)
`sprint, git, diffs, todo, workflow, background, audit-log, changed, ac, debug, settings, tty`

### Key Constraint
**No stash stack.** Single slot only. Successive /bc calls preserve the original saved state — only the first focus after a reset triggers a save.

### Files to Create
| File | Purpose |
|------|---------|
| `packages/cyclist/src/public/hooks/useFocusPanel.ts` | WebSocket hook for `/ws/focus` events |

### Files to Modify
| File | Change |
|------|--------|
| `packages/cyclist/src/public/components/BikeRackWorkspace.tsx` | Integrate focus hook, stash/restore logic |
| `packages/cyclist/src/public/components/DockviewWorkspace.tsx` | Same focus integration for full Cyclist mode |

### Notes
- See sprint/context/context-epic-104.md for detailed architecture and WebSocket patterns
- Follow existing hooks pattern in useSprint.ts for WebSocket connection
- Follow existing layout persistence in useLayoutPersistence.ts for stash/restore

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core feature — WebSocket event handling + layout state machine

**Test Files:**
- `packages/cyclist/tests/PROJ-14977-focus-panel-client.test.tsx` — 30 tests across 7 ACs + edge cases

**Tests Written:** 30 tests covering 7 ACs
**Status:** RED (22 failing on assertions, 8 passing structural/no-op)

**Test Coverage by AC:**
| AC | Tests | Key Assertions |
|----|-------|----------------|
| AC1 (WebSocket connection) | 5 | Creates /ws/focus WS, reconnects, cleanup |
| AC2 (Layout stash) | 4 | api.toJSON() called on first focus, not re-stashed |
| AC3 (Single panel) | 5 | api.fromJSON() with single-panel layout, state updates |
| AC4 (Layout restore) | 5 | api.fromJSON() with stashed layout on null, state cleared |
| AC5 (No stash stack) | 2 | Original stash preserved across panel switches |
| AC6 (Reset + refocus) | 3 | New stash created after reset cycle |
| AC7 (Both modes) | 3 | Same behavior for BikeRack and Cyclist layouts |
| Edge cases | 3 | Rapid cycles, same-panel focus, late API availability |

**Stub created:** `packages/cyclist/src/public/hooks/useFocusPanel.ts`
- Creates WebSocket connection to /ws/focus (allows tests to simulate messages)
- Returns default empty state (all behavior tests fail)

**Handoff:** To Dev for implementation (GREEN phase)

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/hooks/useFocusPanel.ts` - Full hook implementation: WebSocket connection, layout stash/restore state machine, reconnect logic
- `packages/cyclist/src/public/components/BikeRackWorkspace.tsx` - Integrate useFocusPanel hook
- `packages/cyclist/src/public/components/DockviewWorkspace.tsx` - Integrate useFocusPanel hook

**Tests:** 30/30 passing (GREEN)
**PR:** #844 — feat(104-3): BikeShow client layout stash/restore on panel focus
**Branch:** feat/104-3-bikeshow-client-layout-stash-restore (pushed)

**Handoff:** To Reviewer for code review

---

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** WS message → JSON.parse → handleFocusChange → api.toJSON (stash) / api.fromJSON (restore) — safe, all in try-catch, internal channel only
**Pattern observed:** WebSocket hook follows exact pattern from useSprint.ts — reconnect, mounted guard, cleanup at `useFocusPanel.ts:88-159`
**Error handling:** Malformed WS messages silently ignored via try-catch at `useFocusPanel.ts:132-140`. Null API handled via ref check at `:99,110,115`
**Security:** WS URL from `window.location` only, no user input. No XSS vectors.
**Note:** [MEDIUM] Layout persistence saves single-panel state during focus mode — reload loses stash. Not in AC scope; recommend future story.
**Tests:** 30/30 passing. All 7 ACs covered + edge cases (rapid cycles, same-panel, late API).
**Handoff:** To SM for finish-story

---

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-13T11:22:25Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-13 04:18:51 | 2026-02-13 04:18:51 | <1m |
| red | 2026-02-13 04:18:51 | 2026-02-13 09:27:20 | 5h 8m |
| green | 2026-02-13 09:27:20 | 2026-02-13T11:18:02Z | 1h 50m |
| review | 2026-02-13T11:18:02Z | 2026-02-13T11:22:25Z | 4m |

### Handoff History
| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| red (tea) | green (dev) | tests_fail | PASSED | 2026-02-13T09:27:20Z |
| green (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-13T11:18:02Z |
| review (reviewer) | finish (sm) | approval | PASSED | 2026-02-13T11:22:25Z |
