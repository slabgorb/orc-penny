# Story: MSSCI-12705 - Panel Drag-and-Drop

**Jira:** MSSCI-12705
**Epic:** 70 - Flexible Workspace
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Feature Branch:** feat/MSSCI-12705-panel-drag-and-drop

## Context

Add drag-and-drop functionality to the docking system. Users can drag panels between sidebars, reorder tabs within sidebars, with visual feedback during drag operations.

## Acceptance Criteria

1. Panels can be dragged between left and right sidebars
2. Tabs can be reordered within a sidebar via drag
3. Ghost preview shows during drag operations
4. Drop zones are highlighted when dragging over valid targets
5. Message view (center) rejects panel drops - cannot be a drop target
6. Drag handles are visually indicated on panel headers

## Technical Approach

Build on DockingWorkspace.tsx from MSSCI-12704. Dockview provides built-in drag-and-drop. Key work:
- Configure dockview drag constraints
- Style ghost preview and drop zones
- Ensure message view panel is locked/non-droppable
- Add visual drag handles to panel headers

## Key Files

- `packages/cyclist/src/public/components/DockingWorkspace.tsx` - Main docking component
- `packages/cyclist/src/public/css/react.css` - Styling for drag states

## TEA Assessment

**Tests Required:** Yes
**Reason:** New drag-and-drop functionality requires comprehensive test coverage

**Test Files:**
- `packages/cyclist/tests/70-2-panel-drag-drop.test.tsx` - Panel drag-and-drop tests

**Tests Written:** 29 tests covering 6 ACs
- AC1: Panels dragged between sidebars (4 tests)
- AC2: Tab reordering within sidebar (3 tests)
- AC3: Ghost preview during drag (4 tests)
- AC4: Drop zone highlighting (5 tests)
- AC5: Message view rejects drops (5 tests)
- AC6: Drag handles on panel headers (6 tests)
- Integration tests (2 tests)

**Status:** RED (27 failing - ready for Dev)

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/components/DockingWorkspace.tsx` - Full drag-and-drop implementation
- `packages/cyclist/tests/70-2-panel-drag-drop.test.tsx` - Fixed test (spy on Event.prototype)

**Tests:** 29/29 passing (GREEN)
**PR:** #577 - feat(cyclist): panel drag-and-drop [MSSCI-12705]
**Branch:** feat/MSSCI-12705-panel-drag-and-drop (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Panel ID → dataTransfer → array operations → state update (safe)
**Pattern observed:** Defensive dataTransfer check at DockingWorkspace.tsx:520
**Error handling:** Early returns on invalid input at lines 582, 648
**Minor observations:**
- [LOW] Unused state variables `draggingSource`, `draggingIndex`
- [MEDIUM] Shallow copy pattern (works but could use deep copy)

**PR #577 merged.** Handoff to SM for finish-story.

## Work Log

- Setup: Session created, branch created
- TEA: 29 failing tests committed to feature branch
- Dev: Implementation complete, PR #577 created
