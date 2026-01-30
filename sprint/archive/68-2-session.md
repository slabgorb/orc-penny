# Story 68-2: Create Todos panel as top-level tab

**Status:** in_progress
**Workflow:** tdd
**Phase:** approved
**Repos:** pennyfarthing
**Feature Branch:** feat/68-2-todos-panel-tab
**Jira:** MSSCI-12676 (epic - story not yet synced)

## Context

Part of Epic 68: Cyclist Sidebar Panels to Top-Level Tabs. This story extracts the todos section from the sidebar into its own top-level VerticalPanel. After this story, users will have a dedicated TODOS tab that displays their task list with progress indication.

The work follows the same pattern as 68-1 (Background Tasks), where existing sidebar sections are promoted to independent panels using the existing VerticalPanel infrastructure.

## Acceptance Criteria

- TODOS tab visible in tab bar
- Panel toggles on tab click
- Progress shows in tab (e.g., "3/5")
- Existing todo rendering works in new location

## Technical Approach

Based on how 68-1, 68-3, 68-4 were implemented:

1. Add `#todos-panel` to index.html
2. Create TodosPanel class extending VerticalPanel
3. Add tab button with progress indicator (X/Y format)
4. Migrate todo rendering logic from sidebar.js to TodosPanel
5. Wire up existing tasks.js module
6. Ensure state management (localStorage) integration
7. Update tab bar to display TODOS tab alongside BACKGROUND, SPRINT, GIT, SETTINGS

## TEA Assessment

**Tests Required:** Yes - written and passing
**Reason:** Implementation already exists, tests confirm ACs met

**Test Files:**
- `pennyfarthing/packages/cyclist/tests/68-2-todos-panel.test.ts` - 34 tests covering all 4 ACs

**Tests Written:** 34 tests covering 4 ACs
**Status:** GREEN (all tests pass - implementation pre-exists)

**Finding:** The Todos panel was implemented alongside other Epic 68 work but this story was never formally completed. The implementation is complete:
- `todos-panel.js` - Full TodosPanel class extending VerticalPanel
- `index.html` - Panel element with proper structure
- PanelManager integration, progress badges, IPC listeners all working

**Recommendation:** Skip to review phase. No Dev work needed.

**Handoff:** To Reviewer for verification

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `electronAPI.todos.onUpdate` → `updatePanelDisplay()` → `renderTodos()` + `calculateProgress()` → DOM (safe: uses textContent for user data, no HTML injection)

**Observations:**
1. [VERIFIED] Class structure correct at `todos-panel.js:36` - extends VerticalPanel
2. [VERIFIED] Error handling at `todos-panel.js:111-114` - graceful when panel not found
3. [VERIFIED] Null input handling at `todos-panel.js:90` - `todos || []`
4. [VERIFIED] IPC error handling at `todos-panel.js:194-196` - caught and logged
5. [LOW] Dynamic import warning-only at `todos-panel.js:169-171` - acceptable degradation

**Security:** No injection vectors. Static HTML only for empty state. User data via textContent.

**Error handling:** Missing elements handled gracefully, IPC errors caught, empty state displays "No tasks"

**Pattern:** Follows 68-1 BackgroundPanel pattern correctly

**Handoff:** To SM for finish-story

## Session Log

- 2026-01-30 Session created by SM for TDD workflow setup
- 2026-01-30 14:32:15 SM handoff to TEA for red phase
- 2026-01-30 15:45:00 TEA wrote 34 tests - all PASS (implementation pre-exists)
- 2026-01-30 15:52:00 TEA handoff to Reviewer (skip Dev - implementation complete)
- 2026-01-30 16:05:00 Reviewer APPROVED - implementation follows patterns, no issues found
- 2026-01-30 16:07:30 Reviewer handoff complete - phase approved, handoff to SM for finish-story
