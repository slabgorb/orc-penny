# Story 100-4: Sprint panel: show closed epics for current sprint

## Overview

Add support for displaying closed/completed epics from the current sprint in the EnhancedSprintPanel Cyclist component. Currently, the SprintPanel shows only active epics in the "Current Epics" section. When epics are archived (moved to `sprint/archive/`), they disappear from view. This story enables showing closed epics in a collapsible "Completed Epics" section, providing visibility into what was accomplished during the sprint.

The data for completed epics already exists in `sprint/archive/sprint-2606-completed.yaml` (completed_epics list) and individual archived epic YAML files. The implementation needs to:

1. Load completed epic metadata from the sprint archive
2. Extend the SprintData type to include closedEpics
3. Update sprint-data.ts to aggregate completed epics
4. Update EnhancedSprintPanel to display the new section with collapsible epic groups
5. Add read-only archive epic cards (no action buttons, completed dates)

## Key Files

### Sprint Data & Type System
- `pennyfarthing/packages/cyclist/src/sprint-data.ts` — Main data aggregation service for SprintPanel
  - `SprintData` interface (lines 53-66) — Add `closedEpics: ClosedEpic[]` field
  - `getSprintData()` function (lines 279-398) — Load archived epics
  - Archive data comes from `sprint/archive/sprint-XXXX-completed.yaml` (completed_epics list)

### UI Component
- `pennyfarthing/packages/cyclist/src/public/components/panels/SprintPanel.tsx` — EnhancedSprintPanel component
  - Section 2: "Current Epics" (lines 417-565) — Duplicate pattern for "Completed Epics" section
  - Each closed epic card: title, jiraKey, context indicator, completed date
  - No expand/collapse for stories (archive epics show metadata only, not story details)
  - No action buttons (archive is read-only)

### WebSocket & Hook
- `pennyfarthing/packages/cyclist/src/public/hooks/useSprint.ts` — SprintData hook interface
  - Update `SprintData` interface to include `closedEpics`
- `pennyfarthing/packages/cyclist/src/websocket.ts` — WebSocket /ws/sprint endpoint
  - Line 832: `getSprintData(projectDir)` already called for init message
  - No changes needed — automatically broadcasts updated data structure

### Archive Data Sources
- `sprint/archive/sprint-2606-completed.yaml` — Completed sprint metadata
  - `completed_epics:` list with JIRA keys (e.g., PROJ-14453, PROJ-14469)
- `sprint/archive/epic-PROJ-14XXX.yaml` — Individual archived epic shards
  - Fields: `id`, `title`, `jira`, `completed` (date string), `points`, `status`, `description`, `repos`

## Technical Approach

### 1. Define ClosedEpic Type (sprint-data.ts)

Add new interface alongside SprintEpic:

```typescript
export interface ClosedEpic {
  id: string;
  title: string;
  jiraKey: string | null;
  points: number;
  status: 'done' | 'cancelled';
  completed: string | null;      // ISO date string
  description?: string | null;
  hasContext?: boolean;
}
```

### 2. Extend SprintData Interface (sprint-data.ts, useSprint.ts)

```typescript
export interface SprintData {
  currentStory: SprintStory | null;
  nextStory: SprintStory | null;
  epics: SprintEpic[];
  closedEpics: ClosedEpic[];      // New field
  futureEpics: FutureEpic[];
  sprint: { /* ... */ };
}
```

### 3. Load Completed Epics in getSprintData() (sprint-data.ts)

After loading current sprint epics (line 316), add:

1. Read `sprint/archive/sprint-XXXX-completed.yaml` to get `completed_epics` list
2. For each completed_epic ID (e.g., "PROJ-14453"):
   - Load the corresponding `sprint/archive/epic-PROJ-14453.yaml` shard
   - Transform to ClosedEpic type (extract title, jira, completed date, points, status)
   - Check for context file at `sprint/context/context-epic-PROJ-14453.md`
3. Return as `closedEpics` array in SprintData

**Implementation pattern:**
- Reuse existing `mergeEpicShards()` logic for shard loading
- Create new `loadClosedEpics(projectDir: string): ClosedEpic[]` helper function
- Call it after `getSprintData()` loads current sprint

### 4. Update EnhancedSprintPanel Component (SprintPanel.tsx)

Add new "Completed Epics" section after "Current Epics" section (after line 565):

**Section structure:**
- Header: "Completed Epics" (h2)
- List of closed epic cards (read-only):
  - Epic title
  - Jira link (same as current epics)
  - Context indicator
  - Completed date badge (e.g., "Completed: 2026-02-09")
  - Points (read-only, no progress bar)
  - Status badge (e.g., "Done" or "Cancelled")
- Empty state: "No completed epics in current sprint" if empty

**Design notes:**
- No expand/collapse toggle (archive epics don't show story details)
- No action buttons (archive is read-only, no promote/archive)
- Use subtle styling to differentiate from active epics (lighter background, muted text)
- Reuse existing components: `Badge`, `ContextIndicator`, `JiraLink` helpers
- No progress bar (completed epics have 100% progress implicitly)

### 5. Archive File Discovery

Current approach in sprint-data.ts reads from `sprint/current-sprint.yaml` for active epics. For closed epics:

1. Check if `sprint/archive/sprint-2606-completed.yaml` exists (follows naming pattern)
2. Extract `completed_epics:` list (JIRA key strings like "PROJ-14453")
3. Load each corresponding `sprint/archive/epic-PROJ-14453.yaml` shard

**Pattern matches existing code:**
- See lines 214-239 (mergeEpicShards) for shard loading pattern
- Can be adapted for archive directory

## Acceptance Criteria

- [x] ClosedEpic type defined with all necessary fields (id, title, jiraKey, points, status, completed date)
- [x] SprintData interface extended to include closedEpics array
- [x] getSprintData() loads completed epics from sprint/archive/ when available
- [x] Completed epic shards (epic-PROJ-XXXX.yaml) are loaded and transformed
- [x] Context file existence checked for each closed epic (sprint/context/context-epic-XXX.md)
- [x] EnhancedSprintPanel displays new "Completed Epics" section
- [x] Closed epic cards show: title, jira link, context indicator, completed date, points, status
- [x] Empty state shown when no completed epics (graceful degradation)
- [x] Read-only display (no archive/promote buttons)
- [x] useSprint hook properly types closedEpics in SprintData
- [x] WebSocket /ws/sprint automatically broadcasts updated data structure
- [x] Tests for data loading and UI rendering of closed epics
- [x] Styling distinguishes completed epics from active epics (muted/background)

## Implementation Order

1. Add ClosedEpic interface to sprint-data.ts
2. Extend SprintData interface in sprint-data.ts and useSprint.ts
3. Create loadClosedEpics() helper function
4. Update getSprintData() to load and return closed epics
5. Update EnhancedSprintPanel to render "Completed Epics" section
6. Add styling for closed epic cards (muted appearance)
7. Test with existing archive data (epic-PROJ-14453.yaml, etc.)
8. Verify WebSocket broadcasts updated data structure

## Related Stories

- **100-1**: Fix PersonaHeader CSS layout (completed)
- **100-2**: Quick agent picker in control bar (completed)
- **100-5**: Sprint metrics from completed/current/future (uses closedEpics data)
- **95-7**: Bell mode observation injection
- **Story PROJ-14189**: Enhanced Sprint Panel with story management and epic actions (prior work)

## References

- Sprint archive structure: `/sprint/archive/sprint-XXXX-completed.yaml`, `/sprint/archive/epic-PROJ-XXXX.yaml`
- Current-sprint data aggregation: `sprint-data.ts` lines 214-239 (shard merging pattern)
- EnhancedSprintPanel UI: `SprintPanel.tsx` lines 417-565 (current epics section template)
- WebSocket broadcast: `websocket.ts` lines 825-847 (sprint /ws/sprint handler)
