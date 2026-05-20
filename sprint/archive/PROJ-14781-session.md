# Story 100-6: Sprint panel: sprint metrics from completed/current/future

**Status:** in_progress
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Jira:** PROJ-14781
**Repos:** pennyfarthing
**Branch:** feature/100-6-sprint-panel-sprint-metrics

---

## SM Assessment

Story 100-6 setup complete. TDD workflow — handing off to TEA for test design.

- Jira PROJ-14781 claimed and In Progress
- Branch `feature/100-6-sprint-panel-sprint-metrics` created in pennyfarthing repo
- Epic context written at `sprint/context/context-epic-100.md`
- Previous sprint panel stories (100-5, 100-9) provide patterns for archive/metrics work

**Handoff:** To TEA for red phase (test design)

## Story Description

Sprint panel: sprint metrics from completed/current/future

The sprint panel needs to show metrics sourced from completed sprint archives, the current sprint YAML, and future sprint data. This will provide a comprehensive view of sprint progress across time periods.

## Acceptance Criteria

- **AC1:** `SprintData.metrics.completed` contains total done points, story count, and epic count from archived sprint shards
- **AC2:** `SprintData.metrics.current` contains done/inProgress/remaining points, totalPoints, and story counts by status
- **AC3:** `SprintData.metrics.future` contains total estimated points and initiative count from future.yaml
- **AC4:** Metrics are isolated — completed archive points do NOT inflate `sprint.done` or `metrics.current`
- **AC5:** Graceful degradation — missing files produce zero metrics, partial data counted correctly

## Technical Context

- Previous sprint panel stories (100-5, 100-9) added closed/archived epic display
- Sprint data is loaded via `sprint-data.ts` server route
- UI renders via `SprintPanel.tsx` using `useSprint.ts` hook
- Sprint YAML is sharded: `current-sprint.yaml` + `epic-*.yaml` shards
- Completed sprint data lives in `sprint/archive/sprint-*-completed.yaml`
- Story 100-9 added loading of archived epics from `sprint/archive/epic-*.yaml`

## Technical Approach

The `getSprintData()` function in `sprint-data.ts` currently:
1. Loads and aggregates current sprint data from `current-sprint.yaml` and `epic-*.yaml` shards
2. Calculates metrics for current sprint
3. Loads archived epics and appends them (100-9)

Story 100-6 extends this to also:
1. Load completed sprint archives (`sprint/archive/sprint-*-completed.yaml`)
2. Extract metrics from completed sprints
3. Load future sprint data (`sprint/future.yaml`)
4. Aggregate and surface all metrics across time periods

### Key Files

| File | Purpose | Recent Changes |
|------|---------|-----------------|
| `packages/cyclist/src/sprint-data.ts` | Data aggregation | 100-9 added archived epic loading |
| `packages/cyclist/src/public/components/panels/SprintPanel.tsx` | UI rendering | Displays current/completed/future sections |
| `packages/cyclist/src/public/hooks/useSprint.ts` | React hook | Data subscription interface |

### Data Structures

**SprintData interface** (from useSprint.ts):
- `currentStory: SprintStory | null`
- `nextStory: SprintStory | null`
- `epics: SprintEpic[]` (includes current + archived)
- Likely needs new fields for metrics aggregation

**Metrics needed:**
- Current sprint: done/in_progress/backlog points and counts
- Completed sprint(s): historical metrics
- Future sprint: planned/estimated metrics

## TEA Assessment

**Tests Required:** Yes
**Reason:** New `metrics` field on SprintData — data aggregation across three sources

**Test File:**
- `packages/cyclist/tests/100-6-sprint-metrics.test.ts` — 15 tests across 5 ACs

**Tests Written:** 15 tests covering 5 ACs
**Status:** RED (14 failing, 1 baseline passing — `data.metrics` undefined)

**Implementation guidance for Dev:**

1. Add `SprintMetrics` interface to `sprint-data.ts`:
   ```typescript
   interface SprintMetrics {
     completed: { points: number; stories: number; epics: number };
     current: { done: number; inProgress: number; remaining: number; totalPoints: number; storiesDone: number; storiesInProgress: number; storiesRemaining: number };
     future: { totalPoints: number; initiatives: number };
   }
   ```

2. Add `metrics: SprintMetrics` to `SprintData` interface

3. In `getSprintData()`:
   - Build `metrics.current` from existing `done/inProgress/remaining` vars + story counts
   - Build `metrics.completed` by counting archived epic stories/points during archive loading loop (lines 338-371)
   - Build `metrics.future` from `futureEpics` array after initiative resolution

4. Existing `sprint.done/inProgress/remaining` fields remain unchanged (backward compat)

**Handoff:** To Korben Dallas (Dev) for green phase

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/sprint-data.ts` — Added `SprintMetrics` interface, `metrics` field on `SprintData`, story count tracking in metrics loop, completed metrics tracking in archive loop, future metrics from resolved initiatives

**Tests:** 15/15 passing (GREEN), 13/13 regression suite passing
**PR:** #813 — feat(100-6): sprint panel metrics from completed/current/future
**Branch:** feature/100-6-sprint-panel-sprint-metrics (pushed)

**Handoff:** To Zorg (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**PR:** #813 — merged to develop, branch deleted

**Data flow traced:** `sprint-{N}-completed.yaml` → `completed_epics` string refs → `join(sprintDir, 'archive', ...)` → `parseYaml` → `transformEpic` → counter accumulation. No user input in path construction — refs are JIRA keys from local YAML. `sprint-data.ts:346-371`

**Metrics isolation verified:** Current metrics loop (lines 328-342) completes before archive loading (lines 350-389). Separate counter variables — `done/inProgress/remaining` vs `completedPoints/completedStories/completedEpics`. Never cross-contaminate. Test AC4 confirms at `100-6-sprint-metrics.test.ts:377-395`.

**Pattern observed:** Metrics piggyback on existing loops — story counters added to the active epic loop, completed counters added to the archive loading loop, future totals computed from already-resolved `futureEpics` array. Minimal code, no new loops. `sprint-data.ts:338-339,367-371,441-444`

**Error handling:** Three defensive layers inherited from 100-9 work — missing completed YAML (skip), missing archive shard (warn+skip), malformed YAML (error+skip). Partial metrics preserved on failure. Tested at AC5 `100-6-sprint-metrics.test.ts:459-474`.

**[MEDIUM] Client-side type drift:** `useSprint.ts:47-60` SprintData interface lacks `metrics` field. Runtime works (JSON merge), but TypeScript consumers can't access `data.metrics` without type assertion. Not blocking — no UI consumes metrics yet, follow-up story expected.

**[LOW] Sprint/metrics.current duplication:** `sprint.done` and `metrics.current.done` share the same variable. Intentional backward compat per AC4.

**Pre-existing:** `console.log` + `TODO` in `archiveEpic`/`promoteEpic` stubs (lines 473-484) — out of scope, not introduced by this PR.

**Handoff:** To SM for finish-story
