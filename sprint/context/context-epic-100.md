# Epic 100: UI Tweak Bucket

Collection of small UI tweaks, polish, and cosmetic fixes across Cyclist and framework components.

## Sprint Panel Stories

- **100-5:** Show closed epics in sprint panel (DONE)
- **100-9:** Wire archived epics into completed section (DONE)
- **100-6:** Sprint metrics from completed/current/future (IN PROGRESS)

## Story Context for 100-6

The sprint panel needs to show metrics sourced from completed sprint archives, the current sprint YAML, and future sprint data. This builds on stories 100-5 and 100-9 which added the ability to display closed and archived epics.

### Previous Story Work

**100-9:** Wire archived epics into completed section
- Implemented loading of archived epics from `sprint/archive/epic-*.yaml`
- Loaded completion references from `sprint/sprint-{N}-completed.yaml`
- Appended archived epics to the UI after metrics calculation
- Key insight: Archive shards already have id/title metadata, no backfill needed
- Key insight: SprintPanel already filters via `isEpicCompleted()` and renders completed section
- Modified: `packages/cyclist/src/sprint-data.ts` (36 lines added)
- Tests: 13/13 passing, no regressions

## Key Files

| File | Purpose |
|------|---------|
| `packages/cyclist/src/public/components/panels/SprintPanel.tsx` | Sprint panel UI rendering |
| `packages/cyclist/src/public/hooks/useSprint.ts` | React hook for sprint data subscription |
| `packages/cyclist/src/sprint-data.ts` | Sprint data aggregation (loads YAML, serves via WebSocket) |

## Sprint Metrics Requirements

The story needs to surface metrics from:

1. **Completed Sprint Archives** — `sprint/archive/sprint-*-completed.yaml`
   - Historical sprint completion data
   - Done stories count and points

2. **Current Sprint** — `sprint/current-sprint.yaml`
   - Active stories and epics
   - In-progress vs backlog counts
   - Current sprint metrics (done, in_progress, backlog points)

3. **Future Sprint Data** — `sprint/future.yaml`
   - Planned upcoming work
   - Estimated points
   - Status of future epics

## Technical Approach

The `getSprintData()` function in `sprint-data.ts` already loads current sprint data and archived epics. Story 100-6 should extend this to also compute and surface metrics from all three time periods.

Current metrics pattern (observed in 100-9 work):
- Metrics calculated before appending archived epics
- `sprint.done`, `sprint.in_progress`, `sprint.backlog` values computed from active epics
- Result object includes `metrics` field with aggregated counts

## Testing Strategy

Typical test file: `packages/cyclist/tests/100-6-sprint-metrics.test.ts`

Expected test coverage:
- Loading completed sprint archives and extracting metrics
- Aggregating metrics from current sprint
- Reading and parsing future sprint data
- Merging metrics across all three time periods
- Graceful handling of missing files
- Proper metrics isolation (archived metrics don't inflate current sprint totals)
