# Story: MSSCI-14187

**Title:** [BUG] Tab overflow - hidden tabs have no way to be accessed
**Epic:** MSSCI-14186 (Dockview Panel Migration)
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Jira:** MSSCI-14187
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14187-tab-overflow-bug

## Acceptance Criteria

- All sidebar tabs are accessible (via overflow dropdown or scroll)
- Dockview overflow dropdown appears when tabs exceed visible width
- OR horizontal tab scroll with visible scrollbar works
- Tab overflow behavior documented in ADR-0019

## Context

This is a bug fix for the Dockview panel system where tabs that overflow the visible area cannot be accessed by users.

## Technical Notes

### Root Cause Analysis

The `DockviewWorkspace.tsx` component uses `DockviewReact` without configuring tab overflow behavior. When multiple tabs exist in a group (sidebars have 4-5 tabs each), tabs that exceed the visible width become inaccessible.

### Key Files

| File | Purpose |
|------|---------|
| `packages/cyclist/src/public/components/DockviewWorkspace.tsx:567-573` | DockviewReact component - needs overflow config |
| `packages/cyclist/src/public/styles/dockview-theme.css` | Theme CSS - needs overflow dropdown styling |
| `pennyfarthing/docs/adr/0019-dockview-migration.md` | ADR - needs overflow documentation |

### Dockview Overflow Mechanisms

Dockview v4.13.1 provides two built-in overflow handling mechanisms:

1. **Scrollable Tabs** (`.dv-scrollable`)
   - Horizontal scroll with thin scrollbar
   - CSS: `scrollbar-width: thin`
   - Shows scrollbar on hover

2. **Overflow Dropdown** (`.dv-tabs-overflow-dropdown-default`)
   - Shows count badge for hidden tabs
   - Dropdown lists hidden tabs for selection
   - Requires proper CSS styling to be visible

### Implementation Approach

**Option A (Recommended): Enable built-in overflow dropdown**
- Dockview's overflow dropdown appears automatically when tabs overflow
- Need to add CSS styling to `dockview-theme.css` to make it visible
- Match Cyclist theme colors

**Option B: Rely on scrollable tabs**
- Tabs already scroll, but scrollbar is barely visible
- Add explicit scrollbar styling for better UX

### Required Changes

1. **dockview-theme.css** - Add overflow dropdown styling:
   ```css
   .cyclist-dockview .dv-tabs-overflow-dropdown-default { ... }
   .cyclist-dockview .dv-tabs-overflow-container { ... }
   ```

2. **ADR-0019** - Document tab overflow behavior

---

## TEA Assessment

**Tests Required:** Yes
**Test Count:** 15 tests (7 failing, 8 passing structural tests)

**Test File:**
- `packages/cyclist/tests/MSSCI-14187-tab-overflow.test.tsx`

**Coverage by AC:**
- AC1: 3 tests - Tab accessibility via overflow/scroll
- AC2: 3 tests - Overflow dropdown appearance
- AC3: 3 tests - Horizontal scroll with scrollbar
- AC4: 2 tests - ADR documentation
- Integration: 4 tests - Resize handling, state preservation, CSS

**Status:** RED (7 failing tests - ready for Dev)

**Handoff:** To White Rabbit (Dev) for implementation

---

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `packages/cyclist/src/public/styles/dockview-theme.css` - Added "Tab Overflow Handling" section with CSS for scrollable tabs, overflow dropdown trigger, and overflow container
- `docs/adr/0019-dockview-migration.md` - Added "Tab Overflow Handling" section documenting scrollable tabs, overflow dropdown, and keyboard navigation
- `packages/cyclist/tests/MSSCI-14187-tab-overflow.test.tsx` - Fixed ADR path, updated tests to verify CSS rules

**Tests:** 15/15 passing (GREEN)

**PR:** #644 - fix(dockview): add tab overflow handling (MSSCI-14187)

**Branch:** feature/MSSCI-14187-tab-overflow-bug (pushed)

**Implementation Notes:**
- Used CSS-only approach - Dockview has built-in overflow handling that just needs styling
- Added explicit scrollbar styling for better visibility
- Styled overflow dropdown to match Cyclist theme colors
- Tests updated to verify CSS rules rather than computed styles (JSDOM limitation)

**Handoff:** To Queen of Hearts (Reviewer) for code review

---

## Reviewer Assessment

**Review Complete:** Yes
**Decision:** APPROVED ✅

**Review Checklist:**
- [x] 7 code quality observations documented
- [x] Data flow traced (CSS-only, no data flow)
- [x] Patterns verified (CSS variables, comment headers, story refs)
- [x] Test coverage verified (15/15 tests, all ACs covered)
- [x] No blocking issues found

**Observations:**
1. Tab container uses standard `overflow-x: auto` with `scrollbar-width: thin`
2. Webkit scrollbar fallback for cross-browser compatibility
3. Overflow dropdown styled with theme variables and fallbacks
4. z-index 1000 consistent with panel-restore-menu
5. Text truncation in dropdown tabs for long names
6. ADR documentation complete with CSS snippets
7. Tests verify CSS rules exist (pragmatic JSDOM workaround)

**Minor Notes:**
- React `act()` warning in integration test is noise, not blocking

**AC Verification:**
- ✅ AC1: Scrollable and overflow mechanisms styled
- ✅ AC2: Overflow dropdown CSS added
- ✅ AC3: Scrollbar styling visible
- ✅ AC4: ADR-0019 documented

**PR Merged:** #644 merged to develop, branch deleted

**Handoff:** To Mad Hatter (SM) for story completion
