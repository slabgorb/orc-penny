# Story 79-3: Add tool launcher row to DebugPanel

**Jira:** MSSCI-14443
**Points:** 1
**Status:** in_progress
**Phase:** approved
**Workflow:** trivial
**Repos:** pennyfarthing
**Branch:** feature/79-3-tool-launcher-debug-panel

## Description

Add a Tools section below Token Stats in DebugPanel with buttons for each observatory tool. First button: Hotspots (opens HotspotsDialog). Placeholder buttons for future tools.

## Acceptance Criteria

- Add Tools section to DebugPanel below Token Stats section
- Implement Hotspots button that opens HotspotsDialog (uses ToolDialog wrapper from 79-1)
- Add placeholder buttons for future observatory tools
- Maintain consistent styling with existing DebugPanel sections (Separator, heading, button layout)
- Test button interactions and dialog launches

## Technical Context

**DebugPanel location:** `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/public/components/panels/DebugPanel.tsx`

DebugPanel currently displays two main sections:
1. Context Usage (tier display, injected context breakdown, context usage bar and tokens)
2. Token Stats (input, output, cache read, cache write, cost)

The panel uses shadcn/ui Button, Badge, and Separator components. Each section has an `<h4>` heading followed by content.

**HotspotsDialog location:** `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/public/components/dialogs/HotspotsDialog.tsx`

HotspotsDialog was migrated from HotspotsPanel in story 79-2 and uses the ToolDialog wrapper (created in 79-1). It accepts `open` and `onOpenChange` props to control visibility. The dialog shows hotspot analysis results with sortable tables, time window controls, and view mode toggle (files/dirs).

**ToolDialog location:** `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/public/components/dialogs/ToolDialog.tsx`

ToolDialog is a standardized wrapper for all observatory tools. It wraps shadcn Dialog with max-w-5xl sizing, standard header/footer, and close button.

## Implementation Notes

- Flexbox layout with `flex-wrap` and `gap: 6px` for responsive button arrangement
- `useState(false)` for `hotspotsOpen` — controls HotspotsDialog visibility
- Placeholder buttons: Code Markers, Dead Code, Complexity (all disabled)
- CSS in `tailwind.css` under `.debug-panel .tool-launcher`

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/components/panels/DebugPanel.tsx` - Added Tools section with Hotspots button and 3 disabled placeholder buttons
- `packages/cyclist/src/public/styles/tailwind.css` - Added `.tool-launcher` flexbox layout styles
- `packages/cyclist/tests/MSSCI-14443-tool-launcher.test.tsx` - 5 tests covering section rendering, button states, dialog interaction

**Tests:** 5/5 passing (GREEN)
**PR:** #729 - feat(79-3): add tool launcher row to DebugPanel
**Branch:** feature/79-3-tool-launcher-debug-panel (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Button click → `setHotspotsOpen(true)` → `HotspotsDialog open={true}` → ToolDialog renders (safe: controlled component, no external input)
**Pattern observed:** Section follows existing Separator + h4 pattern at `DebugPanel.tsx:266-268`
**Error handling:** No error paths needed — pure UI toggle with no async or external data
**Security:** No user input, no dynamic content rendering, no injection vectors
**Tests:** 5/5 covering all ACs, mocks appropriate for unit scope
**Notes:** `[LOW]` HotspotsDialog always mounted (standard shadcn Dialog pattern, not a concern)

**Handoff:** To SM for finish-story
