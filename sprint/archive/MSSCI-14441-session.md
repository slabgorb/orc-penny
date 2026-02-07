# Story 79-1: Create ToolDialog shared component

**Jira:** MSSCI-14441
**Epic:** epic-79 (Dialog Infrastructure + Hotspot Refactor)
**Points:** 1
**Priority:** P0
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/79-1-create-tooldialog-shared-component

## Description
New component: components/dialogs/ToolDialog.tsx
Wraps shadcn Dialog with max-w-5xl sizing, standard header/footer,
and close button. All observatory tools will use this wrapper.

## Acceptance Criteria
- [ ] ToolDialog.tsx component created at components/dialogs/ToolDialog.tsx
- [ ] Wraps shadcn Dialog with max-w-5xl sizing
- [ ] Standard header with title and close button
- [ ] Standard footer area
- [ ] All observatory tools can use this as a wrapper
- [ ] Tests pass

## Context
This is the foundational component for epic-79. All subsequent stories depend on ToolDialog existing. It will be used by HotspotsDialog (79-2) and future observatory tool dialogs.

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `packages/cyclist/tests/79-1-tool-dialog.test.tsx` — 14 tests across 5 ACs

**Tests Written:** 14 tests covering 5 ACs
| AC | Tests | Coverage |
|----|-------|----------|
| AC1: Component exists | 3 | Export, render open, render closed |
| AC2: max-w-5xl sizing | 2 | Size class applied, custom className passthrough |
| AC3: Header with title & close | 4 | Title renders, close button exists, close fires callback, optional description |
| AC4: Footer area | 3 | Footer renders, footer omitted, multiple actions |
| AC5: Wrapper for tools | 3 | Arbitrary children, nested content, full composition |

**Status:** RED (failing — module not found, component not implemented)
**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation:** `packages/cyclist/src/public/components/dialogs/ToolDialog.tsx`
**Tests:** 15/15 passing (GREEN)
**Approach:** Thin wrapper around shadcn Dialog primitives with `max-w-5xl` sizing override, optional description and footer.

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**PR:** #719 (merged)
**Data flow traced:** `open` prop → Radix Dialog root → show/hide → `onOpenChange` callback on close. Clean, no state leaks.
**Pattern observed:** Follows `ConfirmDialog.tsx` pattern — function component, shadcn primitives, `cn()` for class merging at `ToolDialog.tsx:33`
**Error handling:** N/A — pure presentational wrapper, no async or error-prone operations
**Security:** No user input risks — renders React children (safe by default), no dangerouslySetInnerHTML

**Observations:**
1. `[VERIFIED]` No forbidden patterns (console.log, TODO, etc.)
2. `[VERIFIED]` Import paths use `@/` alias consistent with codebase
3. `[VERIFIED]` Props interface exported for type reuse
4. `[VERIFIED]` Conditional rendering avoids unnecessary DOM nodes
5. `[LOW]` Radix aria-describedby warning when no description — cosmetic, matches existing Dialog behavior

**Handoff:** To SM for finish-story

## Session Log
- Setup by SM
- Handoff to TEA for test design
- TEA: 14 failing tests written, RED state confirmed
- Handoff to Dev for implementation
- Dev: ToolDialog implemented, 15/15 tests GREEN
- Handoff to Reviewer
- Reviewer: APPROVED, PR #719 merged
- Handoff to SM for finish
