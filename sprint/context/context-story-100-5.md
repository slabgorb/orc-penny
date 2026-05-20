# Story 100-5: Sprint panel: sprint metrics from completed/current/future

**PROJ-14781** | Epic 100 (PROJ-14758) | TDD Workflow | 3 points

## Overview

Enhance the SprintPanel to display comprehensive sprint metrics including velocity, points progress, story counts, and burn-down indicators. The panel will aggregate data from three sprint data files:
- `sprint/current-sprint.yaml` - active sprint epics and stories
- `sprint/archive/sprint-{number}-completed.yaml` - historical completed metrics
- `sprint/future.yaml` - backlog and future initiatives

The metrics will provide a high-level snapshot of sprint health: velocity trends, completion progress (done/remaining/in-progress points), story distribution, and timeline indicators.

## Key Files

### Frontend Components
- `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/public/components/panels/SprintPanel.tsx` - Main panel component, currently displays current story only
- `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/public/hooks/useSprint.ts` - React hook consuming sprint data via WebSocket

### Backend Services
- `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/sprint-data.ts` - Sprint data aggregation service, parses YAML files and calculates current metrics
- `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/websocket.ts` - WebSocket server, broadcasts sprint updates via `/ws/sprint`

### Sprint Data Files
- `/Users/keithavery/Projects/pf-1/sprint/current-sprint.yaml` - Current sprint metadata and epic/story structure
- `/Users/keithavery/Projects/pf-1/sprint/archive/sprint-{number}-completed.yaml` - Completed sprint snapshots with completed_epics and completed_stories
- `/Users/keithavery/Projects/pf-1/sprint/future.yaml` - Future initiatives (backlog)

### Supporting Files
- `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/story-parser.ts` - Story info parser for current active story
- `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/server.ts` - Express server setup, routes to sprint API

## Technical Approach

### 1. Extend `getSprintData()` in `sprint-data.ts`

The current `getSprintData(projectDir)` function returns:
```typescript
SprintData {
  currentStory: SprintStory | null;
  nextStory: SprintStory | null;
  epics: SprintEpic[];
  futureEpics: FutureEpic[];
  sprint: { number, name, done, remaining, inProgress, endDate }
}
```

Enhance the `sprint` object to include metrics:
```typescript
sprint: {
  number: number;
  name: string;
  goal: string;
  startDate: string;
  endDate: string;

  // Current sprint metrics
  done: number;           // points completed in current sprint
  inProgress: number;    // points actively being worked
  remaining: number;     // backlog points not started
  blocked: number;       // blocked points (not counted in remaining)
  totalPoints: number;   // sum of all current sprint points

  // Velocity & history
  velocity: {
    thisSprint: number;        // points done in current sprint
    lastSprint: number;        // points done in previous sprint (from archive)
    twoSprintsAgo: number;     // points done two sprints back
    averageVelocity: number;   // 3-sprint moving average
  };

  // Story counts
  stories: {
    total: number;
    done: number;
    inProgress: number;
    backlog: number;
    blocked: number;
  };

  // Burn-down indicators
  burndown: {
    percentComplete: number;      // done / totalPoints
    daysRemaining: number;        // days until endDate
    pointsPerDay: number;         // done / days elapsed
    trendingToComplete: boolean;  // will complete by endDate at current rate
  };
}
```

### 2. Load Completed Sprint Archive Data

Create helper function `getCompletedSprintMetrics(projectDir)`:
- Scan `sprint/archive/` for `sprint-{number}-completed.yaml` files
- Parse last 3 sprint archives to calculate velocity trends
- Extract `completed_stories` point totals per sprint
- Return velocity data and historical context

Key logic:
```
For each sprint archive found:
  1. Parse sprint metadata (name, start_date, end_date)
  2. Sum points from completed_stories
  3. Store as { sprintNumber, endDate, pointsDone }
4. Sort by date descending
5. Calculate: last sprint velocity, two-sprints-ago velocity, 3-sprint average
```

### 3. Update SprintPanel Component

Add new section to `EnhancedSprintPanel` showing metrics:

**Metrics Header Section** (above Current Story):
- Sprint name and goal
- Sprint timeline (start date → end date, days remaining)
- Sprint capacity bar (total points)

**Metrics Dashboard Section** (after Current Story):
- **Velocity Gauge**: 3-sprint average + this sprint trend
- **Progress Bar**: Done / Remaining / In-Progress breakdown with percentages
- **Story Status**: "5 done / 3 in progress / 4 backlog / 1 blocked"
- **Burn-down Chart**: Simple trend line (optional: animated or static visualization)
- **Health Indicator**:
  - Green: On track (trendingToComplete = true)
  - Yellow: At risk (points per day declining)
  - Red: Behind (will miss endDate at current rate)

### 4. Update Type Definitions

Enhance `useSprint.ts` `SprintData` interface to match new metrics structure.

### 5. Real-time Updates

The existing WebSocket mechanism (`/ws/sprint`) already broadcasts updates when sprint files change. The new metrics will automatically refresh when:
- `current-sprint.yaml` is modified (story status changes)
- `archive/sprint-{number}-completed.yaml` is added (new sprint archived)
- `.session/*-session.md` changes (active story changes)

## Implementation Steps

1. **Add velocity calculation functions** to `sprint-data.ts`:
   - `getCompletedSprintMetrics(projectDir): Promise<VelocityData>`
   - `calculateBurndownMetrics(completed, inProgress, remaining, endDate): BurndownData`
   - `getSprintDaysRemaining(endDate): number`

2. **Extend `getSprintData()`** to:
   - Load completed sprint archives
   - Calculate velocity from last 3 sprints
   - Compute burn-down indicators
   - Return enhanced `sprint` object with metrics

3. **Update `useSprint.ts`** to:
   - Extend `SprintData.sprint` interface with new fields
   - Handle velocity history in WebSocket messages

4. **Enhance `EnhancedSprintPanel`** to:
   - Add metrics display section with:
     - Velocity gauge showing 3-sprint trend
     - Progress bars for done/remaining/in-progress
     - Story count breakdown
     - Burn-down status indicator
   - Use shadcn/ui Progress and Badge components for consistency
   - Add data-testid attributes for testing

5. **Test coverage** (TDD workflow):
   - Unit tests for velocity calculations with mock archive files
   - Integration tests for metrics aggregation with real sprint files
   - Component tests for metrics display rendering
   - WebSocket broadcast tests for metrics updates

## Acceptance Criteria

- [x] `getSprintData()` loads and parses completed sprint archives from `sprint/archive/`
- [x] Velocity calculation returns last sprint, two-sprints-ago, and 3-sprint average
- [x] Burn-down metrics calculated (days remaining, points per day, trend indicator)
- [x] Story counts aggregated (total, done, in-progress, backlog, blocked)
- [x] SprintPanel displays velocity gauge with 3-sprint trend
- [x] SprintPanel shows progress breakdown (done/remaining/in-progress points)
- [x] SprintPanel displays story status counts in readable format
- [x] Burn-down indicator shows health status (on-track/at-risk/behind)
- [x] Metrics update in real-time when sprint YAML files change
- [x] Responsive design works on all panel widths (Cyclist resize handling)
- [x] All metrics properly styled with theme colors
- [x] Unit tests cover velocity and burn-down calculation edge cases
- [x] Integration tests verify metrics with real sprint file structures
- [x] Component tests render metrics section without errors

## Notes

- **Velocity calculation**: Use completed_stories point totals from archive, not epic counts (epics themselves have no points)
- **Blocked stories**: Not counted in remaining capacity — they're blocked, not available for planning
- **Days remaining**: Calculate from sprint end_date; handle weekends if needed (optional enhancement)
- **Trend indicator**: Compare this sprint's velocity to 3-sprint average to show if trending up/down/stable
- **Archive location**: Follows pattern `sprint/archive/sprint-{sprintNumber}-completed.yaml` after sprint completion
