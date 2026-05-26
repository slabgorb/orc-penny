# Story 84-3: Per-dimension drill-through from health gauge

**Jira:** PROJ-14472
**Epic:** 84 — Composite Health Score
**Points:** 1
**Priority:** P1
**Workflow:** trivial
**Phase:** approved
**Branch:** feature/PROJ-14472-per-dimension-drill-through
**Repos:** pennyfarthing
**Assigned:** slabgorb@gmail.com

---
## Description

Clicking a dimension in the health score breakdown opens the corresponding tool dialog (e.g. clicking "TODO density" opens CodeMarkersDialog). Wire gauge breakdown items to dialog openers.

## Acceptance Criteria

- [ ] Health gauge dimension breakdown items are clickable
- [ ] Clicking a dimension opens the corresponding tool dialog (CodeMarkersDialog, ComplexityDialog, etc.)
- [ ] Dialog openers are wired to the correct tool for each dimension
- [ ] Existing gauge behavior is preserved (score display, color coding)

## Technical Context

This is the final story in Epic 84 (Composite Health Score). Stories 84-1 (Python module) and 84-2 (API + gauge component) are both done. This story wires the gauge breakdown items to open the existing tool dialogs.

### Dependencies
- 84-1 (done): Health score Python module
- 84-2 (done): Health score API + gauge component with breakdown display

### Dimension-to-Dialog Mapping

| Dimension | Opens Dialog |
|-----------|-------------|
| Churn Concentration | HotspotsDialog |
| TODO/FIXME Density | CodeMarkersDialog (TODOs tab) |
| Complexity | ComplexityDialog |
| Test Coverage Gaps | HotspotsDialog (filtered view) |
| Dead Code | DeadCodeDialog |
| Deprecation Debt | CodeMarkersDialog (Deprecated tab) |
| Dependency Freshness | DependenciesDialog |
| Agent Context Efficiency | AgentLoadDialog |

## Implementation Notes

- HealthGauge component accepts an `onDimensionClick(dimensionName: string)` callback prop
- DebugPanel maps dimension names to dialog open state setters
- All dialogs must already be mounted (done by epic 79 story 79-3)
- Test for `data-state` attributes on triggers, not `title` attributes (Radix Dialog pattern)

## Agent Notes

- Session created by SM setup subagent
- Trivial workflow: SM → Dev → Reviewer → SM (skips TEA)
- 1-point UI wiring story
- Referenced epic context: `/Users/keithavery/Projects/pf-1/sprint/context/context-epic-84.md`
- SM handoff to Dev: Phase setup → implement. Trivial workflow, no TEA phase. Dev to implement directly.
- Dev handoff to Reviewer: Phase implement → review. 46/46 tests GREEN. PR #767 ready for review.
- Reviewer APPROVED and merged PR #767. Phase review → approved. Handoff to SM for finish-story.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/components/panels/DebugPanel.tsx` — Added `handleDimensionClick` callback mapping 8 dimension names to 6 dialog openers, wired to HealthGauge `onDimensionClick` prop

**Tests:** 46/46 passing (GREEN)
**PR:** #767 — feat(84-3): wire health gauge dimensions to tool dialogs
**Branch:** feature/PROJ-14472-per-dimension-drill-through (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | [VERIFIED] | Data flow clean: `useHealthScore` → `HealthGauge.onDimensionClick(dim.name)` → `handleDimensionClick` switch → dialog state setter | `DebugPanel.tsx:113-156` |
| 2 | [VERIFIED] | All 8 dimension names in switch match `DEFAULT_WEIGHTS` keys exactly (churn, todo_density, complexity, test_gaps, dead_code, deprecation_debt, dependency_freshness, agent_context_efficiency) | `models.py:13-22` vs `DebugPanel.tsx:114-134` |
| 3 | [VERIFIED] | Event propagation handled: `e.stopPropagation()` prevents gauge collapse on dimension click | `HealthGauge.tsx:127` |
| 4 | [LOW] | No default case in switch — unknown dimension names silently ignored. Acceptable: non-clickable is better than crashing | `DebugPanel.tsx:114` |
| 5 | [VERIFIED] | No security concerns: pure UI wiring, no user input, no injection vectors | `DebugPanel.tsx:113-136` |
| 6 | [VERIFIED] | Existing gauge behavior preserved: score display, color coding, expand/collapse all untouched | `HealthGauge.tsx:60-144` |
| 7 | [LOW] | `handleDimensionClick` not memoized with `useCallback` — acceptable since setState refs are stable and HealthGauge doesn't memo-compare props | `DebugPanel.tsx:113` |

**Data flow traced:** `/api/health-score` → `useHealthScore` → `HealthGauge` dimensions prop → user click → `onDimensionClick(dim.name)` → switch routes to correct dialog setter (safe, no transformations)
**Pattern observed:** Matches existing tool launcher button pattern at `DebugPanel.tsx:291-338`
**Error handling:** Optional chaining `onDimensionClick?.()` at `HealthGauge.tsx:128` handles missing callback gracefully
**Tests:** 2291/2426 passing (17 failures pre-existing in dead-code-api tests, unrelated to this PR)

**Handoff:** To SM (Slartibartfast) for finish-story
