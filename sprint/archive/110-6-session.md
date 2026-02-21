# Story 110-6: Add completed epics section to TUI sprint panel

**Status:** in_progress
**Phase:** finish
**Workflow:** trivial
**Repos:** pennyfarthing
**Branch:** feat/110-6-completed-epics-section-tui
**Epic:** 110 — BikeRack TUI — Interactive Command Center

## Context

Story 110-5 removed archived epics from the active sprint view to fix duplicate rendering. However, we still want to display completed epics — just in a separate section below the active work, similar to how "Future Initiatives" has its own section.

The server side (`sprint-data.ts`) currently loads archived epics for metrics only but doesn't send them to the client. The TUI (`sprint_panel.py`) needs a new "Completed Epics" section rendered between active epics and Future Initiatives.

## Acceptance Criteria

- [ ] Server sends archived epics as a separate `completedEpics` array in the sprint data payload
- [ ] TUI renders a "Completed Epics" separator and lists completed epics below active work
- [ ] Completed epics show as collapsed by default with 100% progress bars
- [ ] Completed epics section appears between active epics and Future Initiatives

## Technical Approach

1. **sprint-data.ts**: Collect archived epics into a separate `completedEpics` array (not `epics`) and include in the return payload
2. **sprint_panel.py**: Render a "── Completed ──" separator after active epics, then render completed epic nodes (collapsed by default)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/sprint-data.ts` - Added `completedEpics` to SprintData interface and return payload; archived epics collected into separate array
- `pennyfarthing-dist/pf/bikerack/sprint_panel.py` - Added "Completed" section rendering between active epics and Future Initiatives; collapsed by default

**Branch:** feat/110-6-completed-epics-section-tui (pushed)

**Handoff:** To review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `getSprintData().completedEpics` → WebSocket JSON → `sprint_panel.py:359` → rendered between active epics and Future Initiatives. Separator + collapsed nodes follow established Future Initiatives pattern.
**Pattern observed:** Completed section mirrors Future Initiatives rendering pattern at `sprint_panel.py:358-402` — separator leaf, tree nodes, collapse by default, saved expand state.
**Error handling:** Empty array guard at `sprint_panel.py:360`. WebSocket serialization handles empty arrays cleanly. No new failure paths.

**Handoff:** To SM for finish-story