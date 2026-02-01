# Session: MSSCI-12780 - Progress Panel Shows Raw Markers Instead of Content

## Story Metadata
- **ID:** MSSCI-12780
- **Jira:** MSSCI-12780
- **Title:** Bug: Progress Panel Shows Raw Markers Instead of Content
- **Points:** 2
- **Priority:** P1
- **Epic:** 64 (MSSCI-12465) - Cyclist UX Polish
- **Workflow:** TDD (phased)
- **Assignee:** Keith Avery

## Repos and Branches
- **Repo:** pennyfarthing
- **Branch:** `feat/MSSCI-12780-progress-panel-raw-markers`
- **Base:** develop

## Problem Description
The Progress panel shows raw marker characters (>, *) instead of actual task content:
- Progress bar shows "3/7" correctly
- IN PROGRESS section shows only ">" marker
- PENDING section shows only "*" bullets
- COMPLETED section shows count but no task details

**Expected:** Task subjects/descriptions should be displayed.

## Acceptance Criteria
1. IN PROGRESS section displays task content (not just ">" marker)
2. PENDING section displays task content (not just "*" bullets)
3. COMPLETED section displays task content (not just count)
4. Status markers are rendered as icons/badges, not raw characters

## Root Cause Analysis

After examining the code, the bug appears to be a **data model mismatch** between:

1. **todos.ts** (line 13-17) - Defines `TodoItem` with:
   ```typescript
   interface TodoItem {
     content: string;       // Task description
     status: 'completed' | 'in_progress' | 'pending';
     activeForm: string;    // Active tense label
   }
   ```

2. **useTodos.ts** (line 10-17) - Expects different properties:
   ```typescript
   interface TodoItem {
     id: string;
     subject: string;       // Expected but doesn't exist in source
     description?: string;
     status: 'pending' | 'in_progress' | 'completed';
     blockedBy?: string[];
     blocks?: string[];
   }
   ```

3. **ProgressPanel.tsx** (line 22) - Uses `todo.subject` which is undefined:
   ```tsx
   <span className="todo-subject">{todo.subject}</span>
   ```

The `subject` property doesn't exist in the data being passed - it should be using `content` or `activeForm` from the actual `TodoItem` interface.

## Key Files to Investigate
- `/Users/keithavery/Projects/pennyfarthing-orchestrator/pennyfarthing/packages/cyclist/src/public/components/panels/ProgressPanel.tsx` - Main panel component
- `/Users/keithavery/Projects/pennyfarthing-orchestrator/pennyfarthing/packages/cyclist/src/public/hooks/useTodos.ts` - React hook for todo data
- `/Users/keithavery/Projects/pennyfarthing-orchestrator/pennyfarthing/packages/cyclist/src/todos.ts` - Todo extraction from SDK messages
- `/Users/keithavery/Projects/pennyfarthing-orchestrator/pennyfarthing/packages/cyclist/src/preload.ts` - IPC bridge
- `/Users/keithavery/Projects/pennyfarthing-orchestrator/pennyfarthing/packages/cyclist/src/ipc-channels.ts` - Channel definitions

## Phase
**Current:** finish (TDD workflow)

## TDD Test Strategy
1. Write failing test that verifies ProgressPanel displays `content`/`activeForm` instead of undefined `subject`
2. Test that status markers are rendered correctly
3. Test each status section (in_progress, pending, completed) displays task content

## TEA Assessment

**Tests Required:** Yes
**Reason:** Bug fix requires tests to verify content displays correctly

**Test Files:**
- `pennyfarthing/packages/cyclist/tests/MSSCI-12780-progress-panel-raw-markers.test.ts` - 15 tests covering all ACs

**Tests Written:** 15 tests covering 4 ACs
- AC1: IN PROGRESS section displays task content (3 tests)
- AC2: PENDING section displays task content (2 tests)
- AC3: COMPLETED section displays task content (2 tests)
- AC4: Status markers properly styled (3 tests)
- Data model compatibility (3 tests)
- Integration tests (2 tests)

**Status:** RED (9 failing, 6 passing - failing tests correctly identify the bug)

**Failure Reason:** `todo.subject` is undefined because the actual TodoItem data provides `content` and `activeForm` fields. The `todo-subject` span renders empty.

**Handoff:** To Dev (Inigo Montoya) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/hooks/useTodos.ts` - Updated TodoItem interface to use content/activeForm
- `packages/cyclist/src/public/components/panels/ProgressPanel.tsx` - Display activeForm for in_progress, content for others
- `packages/cyclist/tests/MSSCI-12780-progress-panel-raw-markers.test.tsx` - Fixed test expectations

**Tests:** 15/15 passing (GREEN)
**PR:** #594 - fix(cyclist): display task content in Progress Panel instead of raw markers
**Branch:** feat/MSSCI-12780-progress-panel-raw-markers (pushed)

**Handoff:** To Reviewer (Westley) for code review

## Session Log
- 2026-02-01: Session created for story setup
- 2026-02-01: Branch created: feat/MSSCI-12780-progress-panel-raw-markers
- 2026-02-01: Root cause identified: data model mismatch between TodoItem interfaces
- 2026-02-01: TEA wrote 15 failing tests - RED state confirmed
- 2026-02-01: Dev implemented fix - GREEN state achieved, PR #594 created
- 2026-02-01: Reviewer approved - PR merged

## Reviewer Assessment

**Verdict:** APPROVED

**Review Checklist:**
1. **[VERIFIED]** Data flow traced: `todos.ts` → `main.ts` (extractTodos) → IPC → `useTodos` hook → `ProgressPanel` - all wiring correct
2. **[VERIFIED]** Pattern: Interface alignment at `useTodos.ts:10-14` - `subject`→`content`, added `activeForm`
3. **[VERIFIED]** Logic: `displayText` at `ProgressPanel.tsx:20-22` - uses `activeForm` for in_progress (descriptive), `content` for others
4. **[VERIFIED]** Error handling: Null check on `activeForm` falls back to `content`
5. **[VERIFIED]** Tests: 15/15 passing, all 4 ACs covered

**Observations:**
- `[LOW]` Pre-existing: `id` field in hook interface but not provided by source - not introduced by this PR
- `[LOW]` Pre-existing: Test infrastructure issues unrelated to this change

**Security:** No concerns - UI display change only, no user input handling
**Performance:** No impact - same render logic, different property access

**Handoff:** To SM (Vizzini) for story completion
