# Story 103-6: SprintPanel implementation

**Jira:** PROJ-14961
**Epic:** 103 — BikeRack TUI (PROJ-14951)
**Points:** 2
**Workflow:** tdd
**Phase:** approved
**Repos:** orchestrator, pennyfarthing
**Branch:** feature/103-6-sprint-panel-implementation
**Assigned:** slabgorb@gmail.com

---

## Description

First panel implementation — proves the full vertical slice for BikeRack TUI. Subscribes to `/ws/sprint` WebSocket channel. Renders sprint status as Rich table: story list with status, points, Jira status, velocity. Default panel on launch.

## Acceptance Criteria

- [ ] SprintPanel subscribes to `/ws/sprint` channel
- [ ] Receives and parses JSON payloads: `{type: 'init'|'update', currentStory, nextStory, epics, futureEpics, sprint, metrics}`
- [ ] Renders sprint status as Rich table with columns: story ID, title, status, points, Jira status
- [ ] Displays velocity and sprint metrics
- [ ] Default panel on TUI launch
- [ ] Updates in real-time when data changes on channel
- [ ] All tests GREEN

## Technical Context

### WebSocket Channel Contract

**Channel:** `/ws/sprint`

**Message Schema:**
```json
{
  "type": "init|update",
  "currentStory": {"id": "...", "title": "...", "status": "...", ...},
  "nextStory": {...} or null,
  "epics": [{id, name, status, progress}, ...],
  "futureEpics": [{...}, ...],
  "sprint": {
    "number": 1,
    "name": "Sprint 1",
    "done": 5,
    "remaining": 3,
    "inProgress": 2,
    "endDate": "2026-02-20"
  },
  "metrics": {
    "velocity": 8,
    "burndown": [...]
  }
}
```

### React Reference Implementation

The `useSprint()` hook at `packages/cyclist/src/public/hooks/useSprint.ts` shows the exact data contract and patterns:
- Channel: `/ws/sprint`
- Auto-reconnect on close (2s delay)
- Parses both `init` and `update` message types
- Maintains sprint state across updates

### Key Files to Reference

| File | Purpose |
|------|---------|
| `pennyfarthing_scripts/bikerack/tui.py` | BikeRackApp shell — mounts panels in `#main-content` |
| `pennyfarthing_scripts/bikerack/base_panel.py` | BasePanel abstraction (just shipped in 103-5) — channel subscription pattern |
| `pennyfarthing_scripts/bikerack/ws_client.py` | WheelHubClient — handles WebSocket subscriptions |
| `packages/cyclist/src/public/hooks/useSprint.ts` | React reference for sprint data structure and update pattern |
| `pennyfarthing_scripts/common/config.py` | Config loading for port discovery |

### Base Panel Pattern (from 103-5)

All panels inherit from `BasePanel` and follow this pattern:

1. **Inherit from BasePanel** — get automatic channel subscription
2. **Define channel key** — `CHANNEL = "sprint"` (without `/ws/` prefix)
3. **Implement `render(data)`** — receives parsed JSON, returns Rich renderable
4. **Auto-updates** — BasePanel handles message loop, calls `render()` on each update

```python
from pennyfarthing_scripts.bikerack.base_panel import BasePanel
from rich.table import Table

class SprintPanel(BasePanel):
    CHANNEL = "sprint"

    def render(self, data):
        # data is parsed JSON from /ws/sprint
        table = Table(title="Sprint Status")
        table.add_column("ID", style="cyan")
        # ... add columns for title, status, points, jira
        # Populate from data["epics"] or similar
        return table
```

### Rich Rendering Notes

- Use `Rich.Table` for structured data (stories, metrics)
- Display current sprint info: name, number, days remaining
- Show story list with columns: ID, title, status, points
- Display velocity metric at the bottom
- Keep layout simple — default panel should establish pattern for others

### Entry Points

- **TUI app launches:** `pf bikerack`
- **BikeRackApp.on_mount()** mounts the default panel — SprintPanel
- **Port discovery:** reads `.bikerack-port` or defaults to 2898
- **Config:** reads `.pennyfarthing/config.local.yaml` for theme, etc.

### Critical Path

SprintPanel is the first "proves the vertical slice" panel in the critical path:

```
103-1 (scaffold) ──┐
103-2 (WS client) ─┼─→ 103-5 (base panel) ─→ 103-6 (SprintPanel, proves vertical slice)
103-3 (launcher)  ─┘                        ├→ 103-10 (GitPanel)
                                            ├→ 103-18 (DiffsPanel)
                                            └→ 103-11..17 (remaining panels)
```

All 103-1, 103-2, 103-3, 103-5 are DONE. This story builds the first concrete panel implementation.

## Implementation Notes

### Tests First (TDD)

1. Write tests in `pennyfarthing_scripts/tests/test_sprint_panel.py`
2. Coverage: subscription, data parsing, rendering, real-time updates
3. Mock WheelHubClient to simulate channel messages
4. Tests should mirror acceptance criteria

### Key Design Points

- SprintPanel is **not** special — it's the first proof that BasePanel pattern works
- No custom state machine — rely on BasePanel for channel lifecycle
- Render output should be readable at typical terminal width (80-120 cols)
- Real-time updates: when sprint data changes on server, table re-renders immediately
- Default startup: BikeRackApp automatically mounts SprintPanel on `on_mount()`

### Dependencies

- All framework pieces exist:
  - WheelHub serves `/ws/sprint` ✓
  - BasePanel provides subscription abstraction ✓
  - WheelHubClient handles reconnect ✓
  - BikeRackApp shell ready to mount ✓
- No new Node.js/TypeScript changes needed
- Python deps already present or added in earlier stories

### Related Stories

- **Depends on:** 103-1, 103-2, 103-3, 103-5 (all DONE)
- **Enables:** 103-10, 103-18, 103-11..17 (other panels reuse same pattern)
- **Independent of:** 103-7 (/bc command), 103-4 (connection status), 103-8+ (polish)

---

## SM Assessment

**Routed:** setup → red (TEA)
**Rationale:** TDD workflow — TEA writes failing tests first, then Dev implements.
**Context:** SprintPanel is the first concrete panel proving the BasePanel vertical slice. All dependencies (103-1, 103-2, 103-3, 103-5) are complete. TEA should write tests for channel subscription, data parsing, Rich table rendering, and real-time updates.
**Priority:** P0 — critical path for all subsequent panels.

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** First panel proving the BasePanel vertical slice — every AC needs coverage.

**Test Files:**
- `pennyfarthing_scripts/tests/test_sprint_panel.py` — 34 tests across 8 test classes
- `pennyfarthing_scripts/bikerack/sprint_panel.py` — Stub (imports work, assertions fail)

**Tests Written:** 34 tests covering 6 ACs (AC7 is "all green" — that's Dev's job)

| AC | Tests | Status |
|----|-------|--------|
| AC1: Channel subscription | 4 tests | 4 PASS (channel, inheritance, subscribe, no-client) |
| AC2: JSON parsing | 5 tests | 5 FAIL (init, update, empty epics, null story, multi-epic) |
| AC3: Rich table rendering | 8 tests | 8 FAIL (table type, columns: ID/title/status/pts/jira, row counts) |
| AC4: Metrics display | 5 tests | 5 FAIL (velocity, sprint name, done, remaining, update) |
| AC5: Default panel | 1 test | 1 FAIL (BikeRackApp doesn't mount SprintPanel yet) |
| AC6: Real-time updates | 6 tests | 6 PASS (handle_message, sequential, none, unmount, payload store) |
| Edge cases | 4 tests | 1 FAIL, 3 PASS |

**Status:** RED — 20 failing, 14 passing. All failures are assertion-based (stub returns "" not Table). Zero import/syntax errors.

**Implementation guidance for Dev:**
1. `sprint_panel.py`: Implement `render_panel()` → build Rich Table from payload epics/stories
2. `tui.py`: Import SprintPanel, mount it in `compose()` replacing the placeholder
3. Run tests: `cd pennyfarthing && python -m pytest pennyfarthing_scripts/tests/test_sprint_panel.py -v`

**Handoff:** To Korben Dallas (Dev) for GREEN phase

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/sprint_panel.py` — Implemented `render_panel()`: Rich Group with metrics header + story Table
- `pennyfarthing_scripts/bikerack/tui.py` — Import SprintPanel, mount as default replacing placeholder
- `pennyfarthing_scripts/tests/test_sprint_panel.py` — Fixed AC5 test to use async Textual runner

**Tests:** 34/34 passing (GREEN)
**PR:** #858 — feat(103-6): SprintPanel implementation
**Branch:** feature/103-6-sprint-panel-implementation (pushed)

**Handoff:** To Zorg (Reviewer) for code review

---

## Reviewer Assessment

**Verdict:** APPROVED
**PR:** #858 — MERGED at 2026-02-14T05:50:04Z

**Data flow traced:** WheelHub `/ws/sprint` → WheelHubClient → BasePanel.handle_message → SprintPanel.render_panel → Static.update (safe — all `.get()` with defaults, internal data source only)
**Pattern observed:** Correct BasePanel inheritance pattern at `sprint_panel.py:18,25` — matches 103-5 exactly
**Wiring verified:** `tui.py:65` passes client → SprintPanel; Textual auto-calls `on_mount()` → subscribes to "sprint" channel
**Error handling:** BasePanel try/except on update (`base_panel.py:52-54`), null jiraKey → "—" (`sprint_panel.py:67`), all payload access defensive
**Security:** No external user input in data path. Rich markup injection cosmetic only.

| # | Severity | Observation |
|---|----------|-------------|
| 1 | `[VERIFIED]` | Data flow end-to-end, all `.get()` defaults |
| 2 | `[VERIFIED]` | BasePanel pattern followed precisely |
| 3 | `[VERIFIED]` | Client wiring: compose → on_mount → subscribe |
| 4 | `[VERIFIED]` | Error handling on null/missing data |
| 5 | `[VERIFIED]` | No forbidden patterns in any file |
| 6 | `[LOW]` | Unused import `call` in test file (non-blocking) |
| 7 | `[VERIFIED]` | 34/34 tests GREEN, all ACs covered |

**Handoff:** To Ruby Rhod (SM) for finish-story
