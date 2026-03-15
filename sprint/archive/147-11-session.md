---
story_id: "147-11"
jira_key: "none"
epic: "MSSCI-16411"
workflow: "tdd"
---

# Story 147-11: Jira integration should be optional — hobby projects don't use Jira

## Story Details

- **ID:** 147-11
- **Jira Key:** none (hobby project without Jira)
- **Workflow:** tdd
- **Stack Parent:** none
- **Epic:** MSSCI-16411 (Configuration Gap Closure)
- **Priority:** p1
- **Points:** 2

## Story Description

Bug from sidequest (hobby project, no Jira). `pf sprint story finish` rejects non-Jira story IDs like E1-13 ('Invalid story ID format') and silently skips the YAML status update. Stories get archived but status stays `in_progress` instead of `done`.

**Root cause:** finish flow assumes Jira is present.

**Expected behavior:** The system should gracefully handle projects without Jira — skip Jira transitions, but still update YAML status and archive correctly.

**Reported symptoms:**
1. "Invalid story ID format: E1-13" warning
2. YAML statuses not flipped to `done` after finish
3. Stories archived but sprint YAML out of sync

## SM Assessment

Finish flow assumes Jira — breaks for hobby projects without it. Need to make Jira optional throughout the finish pipeline: skip Jira transitions gracefully, still update YAML status to done and archive correctly. Routing to TEA for RED phase.

**Acceptance Criteria:**
- [ ] AC1: `pf sprint story finish` completes successfully for non-Jira story IDs (e.g., E1-13)
- [ ] AC2: YAML status updates to `done` even without Jira
- [ ] AC3: Session archival works without Jira key
- [ ] AC4: Jira transitions are skipped (not errored) when no Jira configured
- [ ] AC5: Existing Jira-enabled projects continue to work

## Workflow Tracking

**Workflow:** tdd
**Phase:** review
**Phase Started:** 2026-03-15T16:33:52Z

### Phase History

| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-15 | 2026-03-15T16:26:42Z | 16h 26m |
| red | 2026-03-15T16:26:42Z | 2026-03-15T16:30:39Z | 3m 57s |
| green | 2026-03-15T16:30:39Z | 2026-03-15T16:33:19Z | 2m 40s |
| spec-check | 2026-03-15T16:33:19Z | - | - |

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_transition.py` - Changed story ID validation from `parts[0].isdigit()` to `parts[-1].isdigit()` to accept alphanumeric epic prefixes

**Tests:** 49/49 passing (GREEN)
- 17/17 new tests in `test_story_finish_no_jira.py`
- 32/32 existing tests in `test_story_transition.py` (no regressions)

**Branch:** feat/147-11-optional-jira-integration (pushed)

**Handoff:** To Reviewer for code review

## Delivery Findings

- No upstream findings during implementation.

## Design Deviations

### Dev (implementation)
- No deviations from spec.