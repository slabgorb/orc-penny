# MSSCI-14300: Add subdirectory workflow lookup to getWorkflowPhases

**Status:** In Progress
**Workflow:** tdd
**Phase:** finish
**PR:** #682
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14300-subdirectory-workflow-lookup
**Jira:** MSSCI-14300
**Epic:** MSSCI-14298 - Stepped Workflow Infrastructure
**Assigned:** kavery
**Started:** 2026-02-05

## Story

Add subdirectory workflow lookup to getWorkflowPhases so that WorkflowPanel can discover and display stepped workflows that use the `{name}/workflow.yaml` pattern (not just flat `{name}.yaml` files).

## Acceptance Criteria

- [ ] getWorkflowPhases finds subdirectory workflow definitions
- [ ] WorkflowPanel displays stepped workflow progress (step N of M)
- [ ] Existing flat-file workflow lookup still works
- [ ] All 16 subdirectory workflows discoverable by panel

## Key Files

- `pennyfarthing/packages/cyclist/src/story-parser.ts` - `getWorkflowPhases()` lookup
- `pennyfarthing/packages/cyclist/src/public/components/panels/WorkflowPanel.tsx` - UI panel
- `pennyfarthing/pennyfarthing-dist/workflows/*/workflow.yaml` - Stepped workflow definitions
- `pennyfarthing/packages/core/src/workflow/step-parser.ts` - Step file parsing
- `pennyfarthing/packages/core/src/workflow/session-state.ts` - State read/write API

## Technical Notes

- `getWorkflowPhases()` already supports both flat-file and subdirectory lookup (implemented in prior work on develop)
- The real gap is AC2: WorkflowPanel renders stepped workflows identically to phased — needs "Step N of M" display
- 10 of 16 subdirectory workflows have step files; 6 are defined but empty (no steps/ dir)
- Some step files use non-standard naming (e.g., `step-01b-continue.md`) — parser handles gracefully with `step-?`
- `StoryData` interface needs a `workflowType` field to distinguish stepped from phased at the component level

## TEA Assessment

**Tests Required:** Yes
**Test File:** `pennyfarthing/packages/cyclist/tests/MSSCI-14300-subdirectory-workflow-lookup.test.tsx`

**Tests Written:** 27 tests covering 4 ACs + status resolution

| Suite | Tests | Status |
|-------|-------|--------|
| AC1: Subdirectory lookup | 5 | GREEN (pass) |
| AC2: Stepped display | 9 (3 pass, 6 fail) | RED |
| AC3: Flat-file lookup | 4 | GREEN (pass) |
| AC4: All workflows discoverable | 5 | GREEN (pass) |
| Status resolution | 4 | GREEN (pass) |

**RED Failures (6 tests — all AC2):**
1. `should render "Step N of M"` — WorkflowPanel shows arrow progress, not step counter
2. `should NOT render arrow separators for stepped` — still renders `.phase-arrow` elements
3. `should show step completion count` — no completion count displayed
4. `should render .stepped-progress container` — no stepped-specific DOM structure
5. `should show "Step 1 of N" when on first step` — missing step counter
6. `should show all steps as done when complete` — missing "N of N" display

**Implementation Guidance for Dev:**
- Add `workflowType?: 'phased' | 'stepped'` to `StoryData` interface in `useStory.ts`
- Pipe workflow type from `getStoryInfo()` through WebSocket to hook
- In `WorkflowPanel.tsx`, branch rendering: phased → arrow progress, stepped → "Step N of M" with `.stepped-progress` container
- Detect current step from phases array (find index where `status === 'current'`)

**Handoff:** To Dev (Naomi) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/story-parser.ts` - Added `workflowType` to `StoryInfo`, auto-detect from phase names
- `packages/cyclist/src/public/hooks/useStory.ts` - Added `workflowType` to `StoryData` and `transformMessage`
- `packages/cyclist/src/public/components/panels/WorkflowPanel.tsx` - Added `SteppedProgress` component for "Step N of M" display
- `packages/cyclist/tests/MSSCI-14300-subdirectory-workflow-lookup.test.tsx` - Fixed test bug (`getByText` → `queryByText` for fallback)

**Tests:** 27/27 passing (GREEN), 31/31 existing tests pass (no regression)
**PR:** #682 - feat(MSSCI-14300): add stepped workflow display to WorkflowPanel
**Branch:** feature/MSSCI-14300-subdirectory-workflow-lookup (pushed)

**Handoff:** To Reviewer (Avasarala) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `workflowType` → `parseSessionFile()` detects from phase names → `getStoryInfo()` includes in return → WebSocket spread `{...storyInfo}` sends to client → `useStory` hook maps to `StoryData` → `WorkflowPanel` branches on `isStepped` (safe, fully wired)
**Pattern observed:** Clean conditional rendering branch at `WorkflowPanel.tsx:139` — stepped gets `SteppedProgress`, phased gets `PhaseStep` arrows. No shared mutable state, no side effects.
**Error handling:** `getWorkflowPhases` try-catch returns null on failure at `story-parser.ts:666`. `SteppedProgress` handles missing current step at `WorkflowPanel.tsx:74`. Both defensive and correct.
**Security:** No user input flows through unescaped. Phase names from YAML are rendered as text content, not as HTML.
**Tests:** 27/27 passing. Coverage across all 4 ACs + status edge cases. AC4 uses real workflow directory for integration validation.
**No regressions:** Existing 31 tests pass. 8 pre-existing failures (MSSCI-12780, MSSCI-14191) are documented known issues.

**Handoff:** To SM (Drummer) for finish-story

## Workflow Log

| Phase | Agent | Status |
|-------|-------|--------|
| setup | SM | complete |
| red | TEA | complete |
| green | Dev | complete |
| review | Reviewer | complete |
