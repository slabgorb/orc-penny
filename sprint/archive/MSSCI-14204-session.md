# Session: MSSCI-14204

**Story:** [BUG] Panel detail popup jumps in size and uses small images
**Jira:** [MSSCI-14204](https://1898andco.atlassian.net/browse/MSSCI-14204)
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Assignee:** keith.avery@1898andco.io
**Points:** 3
**Priority:** P1

## Epic Context

**Epic:** MSSCI-14186 - Dockview Panel Migration

This story is part of the Dockview migration epic which replaced the hand-rolled panel management (1,042-line DockingWorkspace.tsx) with Dockview library. The migration enables floating panels, split views, panel maximization, better drag-and-drop UX, and full ARIA accessibility.

## Story Description

The panel detail popup (shown when hovering over panel names in the restore menu or panel list) has visual polish issues that make it feel unprofessional:

- Dialog box jumps in size as you move mouse down the list of panel names
- Each panel has different content length causing layout shift
- Popup uses small/thumbnail images instead of larger detail images

## Acceptance Criteria

- [ ] Popup maintains consistent size when hovering different panels
- [ ] No layout shift or jumping when moving mouse between panel names
- [ ] Panel preview images are larger/more detailed
- [ ] Smooth visual experience when browsing panel list

## Implementation Approach (from story)

1. Set fixed dimensions for popup container (min-width/min-height or fixed size)
2. Content should scroll or truncate rather than resize container
3. Identify where panel images are sourced (may need to add larger assets)
4. If larger images don't exist, may need to generate/acquire them
5. Ensure image container has fixed aspect ratio to prevent shifts

## Investigation Needed

- Where are panel preview images stored?
- What image sizes currently exist vs what's needed?
- Which component renders the panel detail popup?

## TDD Workflow

1. **TEA Phase:** Analyze implementation, write failing tests
2. **Dev Phase:** Implement fixes to pass tests
3. **Review Phase:** Code review and verification

## Session Log

### Setup - 2026-02-04
- Session created
- Story moved to in_progress
- Ready for TEA phase

### Red - 2026-02-04
- SM setup complete. Handing off to TEA for test design.
- TEA investigation complete

### Implement - 2026-02-04
- TEA completed RED phase. 16 tests written (14 failing). Handing off to Dev for implementation.
- Dev implementation complete. All tests GREEN. PR created.
- Dev completed GREEN phase. PR #652 created. Handing off to Reviewer.

### Review - 2026-02-04
- Reviewer completed code review. All checks passed. PR #652 APPROVED.
- Handing off to SM for finish-story flow.

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `packages/cyclist/src/public/components/AgentPopup.tsx` - Added data-testid attributes
- `packages/cyclist/src/public/styles/tailwind.css` - Fixed portrait size, layout stability, transitions
- `packages/cyclist/tests/MSSCI-14204-agent-popup-polish.test.tsx` - Fixed test queries
- `packages/cyclist/tests/setup.ts` - Added CSS injection for happy-dom

**Tests:** 16/16 passing (GREEN)
**PR:** #652 - [MSSCI-14204] Fix AgentPopup layout shift and increase portrait size
**Branch:** fix/MSSCI-14204-agent-popup-polish (pushed)

**Changes Summary:**
1. Portrait increased from 120x120 to 200x200 pixels
2. Details panel: min-height 380px, max-height calc(80vh - 60px), overflow-y auto
3. Text sections: line-clamp 3 lines, overflow hidden
4. Added transition: opacity 0.15s ease

**Handoff:** To Reviewer for code review

## TEA Assessment

**Tests Required:** Yes
**Component:** `AgentPopup.tsx` in `pennyfarthing/packages/cyclist/src/public/components/`

**Test File:**
- `pennyfarthing/packages/cyclist/tests/MSSCI-14204-agent-popup-polish.test.tsx` - 16 tests covering all 4 ACs

**Tests Written:** 16 tests covering 4 ACs
**Status:** RED (14 failing, 2 passing - failing for the right reasons)

### Investigation Findings

**Component identified:** `AgentPopup.tsx` - Two-panel popup showing team roster and agent details
**CSS file:** `tailwind.css` lines 2976-3214

**Current state issues:**
1. `.popup-portrait`: 120x120px fixed (too small)
2. `.agent-popup-details`: No fixed height, content determines size (causes jumps)
3. No `data-testid` attributes for testing
4. No CSS transitions on content changes

### Implementation Tasks for Dev

1. **Add data-testid attributes:**
   - `data-testid="agent-popup-details"` on details panel div
   - `data-testid="popup-portrait"` on portrait container
   - `data-testid="popup-detail-style"` on style section
   - `data-testid="popup-detail-background"` on background section
   - `data-testid="popup-detail-quirks"` on quirks section

2. **Fix portrait size (CSS):**
   - Change `.popup-portrait` from 120x120 to 200x200
   - Ensure `object-fit: cover` on img

3. **Fix layout stability (CSS):**
   - Add `min-height: 300px` to `.agent-popup-details`
   - Add `max-height` constraint
   - Add `overflow-y: auto` for scrolling long content
   - Add line-clamp or max-height on text content areas

4. **Add smooth transitions (CSS):**
   - Add `transition: opacity 0.15s ease` or similar to details panel

**Files to modify:**
- `pennyfarthing/packages/cyclist/src/public/components/AgentPopup.tsx` (add testids)
- `pennyfarthing/packages/cyclist/src/public/styles/tailwind.css` (CSS fixes)

**Handoff:** To Dev for implementation

## Reviewer Assessment

**PR:** #652 - [MSSCI-14204] Fix AgentPopup layout shift and increase portrait size
**Branch:** fix/MSSCI-14204-agent-popup-polish
**Reviewer:** Josh Lyman

### Preflight Results
- Tests: 16/16 passing
- No console.log in changed production files
- No forbidden patterns detected

### Code Review Findings

**AgentPopup.tsx Changes:**
- [VERIFIED] All 5 data-testid attributes added correctly
- Minimal, focused changes - only testid attributes added to existing elements
- No logic changes, no risk of regression

**tailwind.css Changes:**
- [VERIFIED] Portrait increased from 120x120 to 200x200 (AC3)
- [VERIFIED] Details panel: min-height 380px, max-height calc(80vh - 60px) (AC1, AC2)
- [VERIFIED] overflow-y: auto for scrollable content (AC2)
- [VERIFIED] Line-clamp applied to text sections (AC2)
- [VERIFIED] Transition: opacity 0.15s ease (AC4)

**Test Changes:**
- Tests properly use roster items (role="option") for agent selection
- CSS injection in setup.ts mirrors production styles for happy-dom compatibility
- All 16 tests cover the 4 acceptance criteria comprehensively

### Acceptance Criteria Verification

| AC | Description | Status |
|----|-------------|--------|
| AC1 | Popup maintains consistent size | PASS - Fixed min/max-height |
| AC2 | No layout shift | PASS - overflow-y: auto, line-clamp |
| AC3 | Larger preview images | PASS - 200x200 instead of 120x120 |
| AC4 | Smooth visual experience | PASS - opacity transition added |

### Issues Found
- **Critical:** None
- **High:** None
- **Medium:** None
- **Low:** None

### Verdict: **APPROVED**

Implementation is clean, focused, and addresses all acceptance criteria. CSS changes are conservative and well-tested. Ready for merge.

**Handoff:** To SM for finish-story flow
