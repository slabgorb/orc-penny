# MSSCI-14301: Show available applicable workflows in WorkflowPanel

**Status:** in_progress
**Workflow:** tdd
**Phase:** finish
**PR:** #683
**Epic:** MSSCI-14298 (Stepped Workflow Infrastructure)
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14301-workflow-panel-available-workflows
**Jira:** MSSCI-14301
**Points:** 3
**Started:** 2026-02-05

## Story

WorkflowPanel currently only shows the active workflow (if any). When no workflow is active it shows "No active workflow" with no way to discover what workflows are available. Even when a workflow is active, users cannot see alternatives.

Fix: Add a section to WorkflowPanel that lists available workflows applicable to the current context. Filter by triggers, tags, or project type. Allow users to see stepped vs phased workflows and start new ones from the panel. Requires a backend endpoint or API to enumerate available workflow definitions and their metadata.

## Acceptance Criteria

- [ ] WorkflowPanel shows list of available workflows when no workflow is active
- [ ] Available workflows are filtered by applicability to current project context
- [ ] Each workflow entry shows name, type (stepped/phased), and description
- [ ] User can identify which workflows are startable from the panel
- [ ] List updates when project context changes

## Context

Epic MSSCI-14298 - Stepped Workflow Infrastructure. This is the third and final story in the epic.

Prior stories completed:
- MSSCI-14299 (5pt): Wired up stepped workflow session state advancement
- MSSCI-14300 (3pt): Added subdirectory workflow lookup to getWorkflowPhases

### Key Files
- `packages/cyclist/src/public/components/panels/WorkflowPanel.tsx` - UI panel (primary target)
- `packages/cyclist/src/story-parser.ts` - `getWorkflowPhases()` lookup (enhanced in MSSCI-14300)
- `packages/core/src/workflow/workflow-executor.ts` - Workflow engine
- `pennyfarthing-dist/workflows/` - Workflow definition files (flat + subdirectory)

## TEA Assessment

**Tests Required:** Yes
**Tests Written:** 30 tests (28 failing, 2 passing on mock data) covering all 5 ACs
**Status:** RED (failing — ready for Dev)

**Test File:**
- `packages/cyclist/tests/MSSCI-14301-available-workflows-panel.test.tsx`

**Test Coverage by AC:**

| AC | Tests | What's Tested |
|----|-------|---------------|
| AC1 | 5 | WorkflowPanel shows available workflows list when no active workflow |
| AC2 | 6 | getAvailableWorkflows() discovers flat + subdirectory workflows, deduplicates, handles empty dirs |
| AC3 | 4 | Each entry renders name, type badge, description, and distinct list items |
| AC4 | 3 | Visual distinction phased vs stepped, start command display |
| AC5 | 3 | Re-renders on data change, loading → available transition, hook return type |
| Backend | 8 | getAvailableWorkflows() enumeration, type detection, triggers, malformed YAML, multi-dir search |
| Integration | 2 | StoryInfo includes availableWorkflows from real project data |

**Implementation Guidance for Dev:**

1. **Backend (`story-parser.ts`):**
   - Add `getAvailableWorkflows(projectDir: string): AvailableWorkflow[]` function
   - Search same 3 dirs as `getWorkflowPhases`: `.pennyfarthing/workflows/`, `.claude/workflows/`, `pennyfarthing-dist/workflows/`
   - Enumerate both flat YAML files AND subdirectory `workflow.yaml` files
   - Parse each for: name, type (phased/stepped), description, triggers
   - Deduplicate by name (first found wins)
   - Add `availableWorkflows` field to `StoryInfo` interface and `getStoryInfo()` return
   - Export `AvailableWorkflow` interface

2. **WebSocket data (`websocket.ts`):**
   - `broadcastStoryUpdate()` already spreads `StoryInfo` — adding the field to `getStoryInfo()` is sufficient

3. **Frontend hook (`useStory.ts`):**
   - Add `availableWorkflows` to `StoryData` and `StoryMessage` interfaces
   - Pass through in `transformMessage()`

4. **Frontend component (`WorkflowPanel.tsx`):**
   - When no active workflow AND `availableWorkflows` exists: render available workflows list
   - Each entry needs: name, type badge (`data-workflow-entry-type`), description
   - Stepped workflows: show `/workflow start {name}` hint
   - Keep existing "No active workflow" for when `availableWorkflows` is null/empty

**Handoff:** To Dev (Naomi) for implementation

## Dev Assessment

**Implementation:** 3 files modified, 162 lines added
**Status:** GREEN (all 30 tests passing, 0 regressions)
**PR:** #683

**Changes:**
- `packages/cyclist/src/story-parser.ts` — `AvailableWorkflow` interface, `getAvailableWorkflows()` function, `availableWorkflows` in `StoryInfo` + `getStoryInfo()`
- `packages/cyclist/src/public/hooks/useStory.ts` — `availableWorkflows` in `UseStoryResult`, `StoryMessage`, state tracking
- `packages/cyclist/src/public/components/panels/WorkflowPanel.tsx` — `AvailableWorkflowsList` component, conditional rendering

**Handoff:** To Reviewer (Avasarala) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Disk YAML → `getAvailableWorkflows()` → `getStoryInfo()` → WebSocket `...storyInfo` spread → `useStory` hook → `WorkflowPanel` render (safe — read-only display, no user input processed)
**Pattern observed:** Code duplication in flat vs subdirectory workflow parsing at `story-parser.ts:714-762` — identical trigger extraction logic repeated. Not blocking, but should be extracted in a follow-up.
**Error handling:** Malformed YAML caught at `story-parser.ts:764`, missing dirs at line 700, empty results handled at `WorkflowPanel.tsx:159`. All solid.
**Performance note:** `getAvailableWorkflows()` does synchronous disk I/O on every file watcher tick — 27 entries read per change event. Acceptable for now, could be cached in a follow-up.
**Tests:** 30 tests, all passing. Comprehensive coverage across all 5 ACs plus backend and integration.
**CI:** All checks passing (build, lint, benchmark).
**Handoff:** Merging PR, then to SM (Drummer) for finish-story

## Handoff Log

| Time | From | To | Phase |
|------|------|----|-------|
| 2026-02-05 | SM | TEA | red |
| 2026-02-05 | TEA | Dev | green |
| 2026-02-05 | Dev | Reviewer | review |
| 2026-02-05 | Reviewer | SM | finish |