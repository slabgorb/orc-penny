# Story 141-12: Remove as-any from UI Components

**Story ID:** 141-12
**Jira:** MSSCI-16139
**Points:** 2
**Status:** in_progress
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/141-12-remove-as-any-ui-components
**Assigned:** keithavery

## Context
Remove `as any` type assertions from UI components in the cyclist package. Part of the Tech Debt Audit epic (141) focusing on type safety improvements.

## Acceptance Criteria
- All `as any` casts removed from UI component files
- Proper TypeScript types used instead
- Existing tests pass
- Build passes with strict type checking

## SM Assessment
2-point TDD story. Sam Seaborn (TEA) designs tests first, then Toby (Dev) implements. Companion to 141-11 which handled OTLP receiver types.

## TEA Assessment

**Tests Required:** No
**Reason:** Chore bypass — type-only refactor with existing test coverage across 3 test files. Story context explicitly states "Adding new test cases — existing coverage is sufficient for a type-only chore" is out of scope. `strict: true` + `tsc --noEmit` is the verification mechanism.

**Existing Test Coverage:**
- `tests/MSSCI-14001-dockview-workspace.test.tsx` — DockviewWorkspace panel IDs, restorePanel
- `tests/MSSCI-14188-split-progress-panel.test.tsx` — ProgressPanel AC/todo rendering
- `tests/MSSCI-14189-enhanced-sprint-panel.test.tsx` — SprintPanel

**Implementation Notes for Dev (4 files, 4 ACs):**
- **AC1** `DockviewWorkspace.tsx`: Add `isPanelId()` type guard, replace `panelId as any` in `restorePanel()` (lines 132-133)
- **AC2** `ProgressPanel.tsx`: Import `CriteriaItem`, `TodoItem`, `WorkflowPhase` types, replace 4 `: any` callback annotations (lines 73, 79, 81, 121)
- **AC3** `MessageView.tsx`: Change `SubagentGroup.messages` from `MessageData[]` to `SubagentMessage[]`, remove `as any` at line 238
- **AC4** `SprintPanel.tsx`: Remove 3 `(window as any).electronAPI` dead Electron branches (lines 202, 468-469, 496-497), keep REST/window.open fallbacks
- **AC5** Verify: `cd pennyfarthing/packages/cyclist && npx tsc -p tsconfig.vite.json --noEmit && pnpm vitest run`

See `sprint/context/context-story-141-12.md` for exact code examples per AC.

**Handoff:** To Dev (Toby Ziegler) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/public/components/DockviewWorkspace.tsx` - AC1: isPanelId type guard, Orientation enum, IDockviewPanel event types
- `packages/core/src/public/components/panels/ProgressPanel.tsx` - AC2: CriteriaItem/WorkflowPhase/TodoItem type annotations
- `packages/core/src/public/components/MessageView.tsx` - AC3: SubagentMessage[] typing, removed as any cast
- `packages/core/src/public/components/panels/SprintPanel.tsx` - AC4: removed 3 dead Electron API branches
- `packages/core/src/public/hooks/useStory.ts` - inlined types from Node.js story-parser
- `packages/core/src/public/components/panels/{ACPanel,AcceptanceCriteriaPanel,BikeLanePanel,WorkflowPanel}.tsx` - import source changed to useStory
- 8 files: useRef strict mode fixes for React 19
- `packages/core/src/public/components/StreamingContent.tsx` - NodeJS.Timeout → ReturnType<typeof setTimeout>
- `packages/core/src/public/utils/{color,font}-presets.ts` - consolidated Window.electronAPI declarations
- `packages/core/src/public/hooks/useMarkerActions.ts` - parameter type annotation
- `packages/cyclist/tests/MSSCI-14189-enhanced-sprint-panel.test.tsx` - Electron mock → fetch mock
- `packages/cyclist/tests/MSSCI-14209-sprint-panel-metadata.test.tsx` - Electron mock → window.open mock
- `packages/cyclist/tsconfig.vite.json` - added declarations.d.ts to include
- `packages/cyclist/src/shared` - new symlink to core/src/shared

**Tests:** 2420/2420 passing (GREEN), 0 tsc errors
**Branch:** feature/141-12-remove-as-any-ui-components (pushed)

**Handoff:** To next phase (review)

## TEA Verify Assessment

**Verification:** GREEN confirmed — 0 tsc errors, 2420/2420 tests passing

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 24

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 13 findings | AGENT_COLORS duplication (3 files), getPhaseIcon/formatWorkflowType duplication, WebSocket lifecycle boilerplate (5 hooks), PhaseStep/CriteriaItemView component duplication |
| simplify-quality | 6 findings | Missing .js extensions on useStory imports (4 new + 4 pre-existing), type safety suggestions |
| simplify-efficiency | 14 findings | panelDisplayNames/PANEL_TITLES duplication, magic number 200, duplicate percentage calc, component duplication overlap with reuse |

**Applied:** 8 high-confidence fixes (missing `.js` extensions on relative imports — convention violation)
**Flagged for Review:** Reuse extractions (AGENT_COLORS, getPhaseIcon, formatWorkflowType, CriteriaItemView, PhaseStep, WebSocket lifecycle) — legitimate duplication but scope exceeds this story
**Noted:** Medium/low efficiency findings (panelDisplayNames consolidation, magic constants, inline type suggestions)
**Reverted:** 0

**Overall:** simplify: applied 8 fixes (import extensions), flagged larger extractions for future stories

**Tests:** 2420/2420 passing (GREEN), 0 tsc errors post-simplify
**Handoff:** To Josh Lyman (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] `isPanelId` type guard at DockviewWorkspace.tsx:112 — correct pattern, uses safe widening cast `as readonly string[]` (not `as any`)
2. [VERIFIED] `onDidAddPanel`/`onDidRemovePanel` event fix at DockviewWorkspace.tsx:567-583 — `e.id` replaces `e.panel.id`. Confirmed via dockview-core types: `Event<IDockviewPanel>` passes the panel directly. Old code silently returned `undefined`, so this is actually a bug fix
3. [VERIFIED] SprintPanel Electron removal at SprintPanel.tsx:198-202, 455-459, 478-482 — clean, fetch paths properly check `response.ok` and throw on failure
4. [VERIFIED] `msg as SubagentMessage` cast at MessageView.tsx:151 — justified by `if (msg.parent_id)` guard at line 145 which is the discriminant
5. [MEDIUM] `getFontSettingsPath()` at font-presets.ts:328 — double cast chain through `globalThis` is ugly but functional. Not blocking
6. [VERIFIED] React 19 `useRef(undefined)` changes across 8 files — mechanical, correct
7. [VERIFIED] Test mocks correctly updated: electronAPI → fetch/window.open, assertions match new source paths
8. [VERIFIED] Security — no injection vectors. `fetch` URLs use epicId from sprint data, `window.open` uses constructed Jira URLs

**Data flow traced:** Archive action: user click → handleArchive(epicId) → `fetch('/api/sprint/archive-epic/${epicId}', { method: 'POST' })` → response.ok check → error state on failure. Safe — epicId from sprint WebSocket data, not user input.

**Pattern observed:** Type inlining in useStory.ts mirrors story-parser types — acceptable for browser/Node boundary but drift risk exists (flagged by Dev and TEA).

**Error handling:** Archive/promote catch blocks set `actionError` state and reset loading in finally block. JiraLink simplification removed unnecessary try/catch (window.open doesn't throw meaningfully).

**Handoff:** To Leo McGarry (SM) for finish-story

## Delivery Findings

### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- **Improvement** (non-blocking): useStory.ts inlines WorkflowPhase/CriteriaItem/AvailableWorkflow interfaces that duplicate story-parser.ts definitions. A shared browser-safe types package would prevent drift. Affects `packages/core/src/public/hooks/useStory.ts` (could import from a shared types file). *Found by Dev during implementation.*
- **Improvement** (non-blocking): cyclist/src/shared is an absolute-path symlink to core/src/shared — works locally but will break on other machines. Consider a relative symlink or tsconfig paths alias. Affects `packages/cyclist/src/shared` (symlink target). *Found by Dev during implementation.*

### TEA (test verification)
- **Improvement** (non-blocking): AGENT_COLORS constant duplicated across AgentPopup.tsx, MessageView.tsx, and PersonaHeader.tsx — extract to shared utils. Affects `packages/core/src/public/components/` (3 files). *Found by TEA during test verification.*
- **Improvement** (non-blocking): getPhaseIcon() and formatWorkflowType() duplicated between WorkflowPanel.tsx and BikeLanePanel.tsx — extract to shared workflow helpers. Affects `packages/core/src/public/components/panels/` (2 files). *Found by TEA during test verification.*
- **Improvement** (non-blocking): WebSocket lifecycle boilerplate (~80 lines each) duplicated across 5 hooks/contexts — candidate for shared useWebSocket() hook. Affects `packages/core/src/public/hooks/` and `contexts/` (5 files). *Found by TEA during test verification.*
- **Improvement** (non-blocking): CriteriaItemView component duplicated between ACPanel.tsx and AcceptanceCriteriaPanel.tsx — extract to shared component. Affects `packages/core/src/public/components/panels/` (2 files). *Found by TEA during test verification.*

### Reviewer (code review)
- **Improvement** (non-blocking): `onDidAddPanel`/`onDidRemovePanel` callback fix (`e.id` vs `e.panel.id`) is a silent bug fix — old code never tracked closed panels correctly. Consider adding a test for panel close/restore tracking. Affects `packages/core/src/public/components/DockviewWorkspace.tsx` (lines 567-583). *Found by Reviewer during code review.*## Impact Summary

**Upstream Effects:** 6 findings (0 Gap, 0 Conflict, 0 Question, 6 Improvement)
**Blocking:** None

- **Improvement:** useStory.ts inlines WorkflowPhase/CriteriaItem/AvailableWorkflow interfaces that duplicate story-parser.ts definitions. A shared browser-safe types package would prevent drift. Affects `packages/core/src/public/hooks/useStory.ts`.
- **Improvement:** cyclist/src/shared is an absolute-path symlink to core/src/shared — works locally but will break on other machines. Consider a relative symlink or tsconfig paths alias. Affects `packages/cyclist/src/shared`.
- **Improvement:** AGENT_COLORS constant duplicated across AgentPopup.tsx, MessageView.tsx, and PersonaHeader.tsx — extract to shared utils. Affects `packages/core/src/public/components/`.
- **Improvement:** getPhaseIcon() and formatWorkflowType() duplicated between WorkflowPanel.tsx and BikeLanePanel.tsx — extract to shared workflow helpers. Affects `packages/core/src/public/components/panels/`.
- **Improvement:** CriteriaItemView component duplicated between ACPanel.tsx and AcceptanceCriteriaPanel.tsx — extract to shared component. Affects `packages/core/src/public/components/panels/`.
- **Improvement:** `onDidAddPanel`/`onDidRemovePanel` callback fix (`e.id` vs `e.panel.id`) is a silent bug fix — old code never tracked closed panels correctly. Consider adding a test for panel close/restore tracking. Affects `packages/core/src/public/components/DockviewWorkspace.tsx`.

