# MSSCI-14192: [BUG] Sprint panel shows 'No epics in current sprint' despite active epics

**Status:** in_progress
**Phase:** finish
**Workflow:** trivial
**Points:** 2
**Jira:** MSSCI-14192
**Epic:** epic-76 (MSSCI-14186)
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14192-sprint-panel-no-epics-bug

## Acceptance Criteria
- [ ] Sprint panel shows Epic 74 with 13/13 points complete
- [ ] Sprint panel shows Epic 76 with progress (21/29 points)
- [ ] Stories visible under each epic in collapsible tree
- [ ] No "No epics" message when epics exist in sprint YAML

## Problem Summary
The Sprint panel's Current Epics section displays "No epics in current sprint" even though current-sprint.yaml contains Epic 74 (complete) and Epic 76 (in progress).

**Observed behavior:**
- Current Epics section shows empty state message
- "Promote an epic from Future Initiatives to get started" displayed
- Future Initiatives section IS populated correctly
- Sprint data clearly exists in current-sprint.yaml

**Expected behavior:**
- Epic 74 should show as complete (13/13 pts)
- Epic 76 should show with progress bar (21/29 pts done)
- Stories should be visible under each epic in collapsible tree

## Root Cause Hypothesis
- API endpoint `/api/sprint/stories` may be returning empty
- Frontend may not be calling the correct endpoint
- Data transformation may be filtering out epics incorrectly
- Possible mismatch between expected and actual response shape

## Investigation Areas
- packages/cyclist/src/public/components/panels/SprintPanel.tsx
- packages/cyclist/src/api/ (sprint-related endpoints)
- Browser DevTools Network tab: check /api/sprint/* responses

## Epic Context (epic-76)
Dockview Panel Migration - Replace hand-rolled panel management with Dockview library.
- dockview-react@4.13.1 installed
- Key patterns: PanelAdapter, Sacred Center (MessagePanel locked)
- See ADR-0019 for technical details

## Technical Context

**Root Cause Found:** YAML parse error in `current-sprint.yaml`

The `yaml` library (v2.x) strictly enforces YAML spec - single-quoted strings cannot contain blank lines. Epic descriptions used single-quoted strings with blank lines:

```yaml
description: 'Line one

  Line two after blank
'
```

This caused `parseYaml()` to throw "Missing closing 'quote" at line 32. The error was caught but `getSprintData()` silently returned empty epics, leading to "No epics in current sprint" display.

**Fix:** Convert all multi-line descriptions from single-quoted to literal block scalar (|) format.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/sprint-data.ts` - Enhanced error logging with line numbers and fix hints
- `pennyfarthing-dist/scripts/sprint/validate-sprint-yaml.sh` - New validation script

**Also fixed (in orchestrator):**
- `sprint/current-sprint.yaml` - Converted 7 description fields from single-quoted to literal block scalars

**Tests:** YAML validation passes, sprint data shows 2 epics with 11 stories
**PR:** #651 - [BUG] Sprint panel shows 'No epics' due to YAML parse errors
**Branch:** feature/MSSCI-14192-sprint-panel-no-epics-bug (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** YAML file → readFileSync → parseYaml → catch block → console.error (safe - errors logged, function continues)

**Observations:**
| # | Severity | Issue | Location |
|---|----------|-------|----------|
| 1 | [VERIFIED] | Error handling uses console.error appropriately | sprint-data.ts:191-192 |
| 2 | [VERIFIED] | Type assertion with optional chaining is safe | sprint-data.ts:188-189 |
| 3 | [LOW] | Unused variable parseError | sprint-data.ts:181 |
| 4 | [MEDIUM] | Inconsistent: future.yaml doesn't get enhanced logging | sprint-data.ts:203 |
| 5 | [VERIFIED] | Shell script handles edge cases properly | validate-sprint-yaml.sh |

**Forbidden patterns:** None found
**Security:** No issues - file reads only, no user input injection

**Handoff:** To SM for finish-story

## Notes
- This is a trivial workflow (2-pt bug) - skips TEA, goes directly to Dev
- Related to MSSCI-14189 which enhanced the Sprint Panel
- Orchestrator YAML changes committed separately (same fix, different repo)
