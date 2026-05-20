# Story 110-5: Filter archived epics from active sprint view in TUI

**Status:** in_progress
**Phase:** finish
**Workflow:** trivial
**Repos:** pennyfarthing
**Branch:** fix/110-5-filter-archived-epics-tui
**Epic:** 110 — BikeRack TUI — Interactive Command Center

## Context

The BikeRack TUI sprint panel loads all epic shard YAML files from both `sprint/` and `sprint/archive/` directories without filtering. This causes:

1. **Duplicate epics** — Epic 110 (active) and archived PROJ-15184 (epic 118, done) both have the title "BikeRack TUI — Interactive Command Center" and both show in the sprint view
2. **Completed epics appearing in active view** — PROJ-15184 (100%), PROJ-14697 (100%), PROJ-15373 (100%) are archived but still rendered in the sprint panel
3. **Inflated counts** — Done/Remaining/Velocity numbers include archived epic points

## Acceptance Criteria

- [ ] Sprint panel only shows epics listed in `current-sprint.yaml` epics array (or their shard files in `sprint/`)
- [ ] Archived epics in `sprint/archive/` do not appear in the active sprint view
- [ ] Sprint totals (Done/Remaining/Velocity) only count active sprint stories

## Technical Approach

The fix is in the TUI's sprint data loader — it needs to filter epic shard loading to only `sprint/epic-*.yaml` and not recurse into `sprint/archive/`. Alternatively, filter loaded epics against the `epics` list in `current-sprint.yaml`.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/sprint-data.ts` - Removed `epics.push(transformed)` for archived epics; preserved archived metrics in `sprint.done` and `velocity`

**Branch:** fix/110-5-filter-archived-epics-tui (pushed)

**Handoff:** To review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `getSprintData()` → WebSocket JSON → Python TUI `sprint_panel.py:312` render loop. Removing `epics.push` at `sprint-data.ts:363` correctly prevents archived epics from reaching the panel.
**Pattern observed:** Metrics split — archived points feed `sprint.done` and `velocity` for accurate totals, while `remaining`/`inProgress` now correctly exclude archived data. Clean separation at `sprint-data.ts:520,529`.
**Error handling:** Existing try/catch blocks around archive YAML parsing preserved. No new failure paths.

**Handoff:** To SM for finish-story