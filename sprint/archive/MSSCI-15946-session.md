# Story 136-14: SM sprint status omits completed stories

**Status:** in_progress
**Phase:** finish
**Workflow:** trivial
**Repos:** orchestrator
**Branch:** fix/136-14-sm-sprint-status-omits-completed-stories
**Jira:** MSSCI-15946
**Assigned:** keithavery
**Points:** 1

## Acceptance Criteria
- SM sprint status output includes completed/done stories in its counts
- SM status display matches `pf sprint status` output

## Technical Approach

### Bug Summary

Story 136-14 title: "SM sprint status omits completed stories". The related bug 136-15 ("Sprint status undercounts completed points — ignores archived epics") was already fixed.

Looking at the codebase:
- `pf/sprint/status.py` contains `get_sprint_status()` and `format_status()`
- The code already includes archived stories via `get_archived_stories(only_current=True)` (line 57 in status.py)
- The status calculation includes both active and archived stories when computing completed_points and completed counts
- The `format_status()` function properly displays "Completed: {count}" showing all completed stories

### Current Implementation

**In `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/src/pf/sprint/status.py`:**
- `get_sprint_status()` (line 24): Collects stories from epics, standalone, and archived sources
- Line 57: Includes archived stories from current sprint
- Line 96: Counts "done" and "completed" statuses across all sources
- `format_status()` (line 158): Shows "Completed: {count}" in output

**Problem:** The issue title suggests the SM agent is displaying sprint status differently than the CLI. Need to check if:
1. SM has its own status display code separate from the CLI
2. The display used in prime.sh/agent activation is missing some stories
3. There's a separate SM status output that doesn't call get_sprint_status()

### Investigation Required

1. Check if SM agent outputs sprint status directly vs calling `pf sprint status`
2. Verify the prime.py loader properly includes archived stories when activated
3. Look for any separate status display in SM workflow or activation code

## SM Assessment

**Story:** 136-14 — SM sprint status omits completed stories
**Workflow:** trivial (1pt bug)
**Setup:** Session created, Jira claimed (MSSCI-15946), branch created
**Handoff:** To Korben Dallas (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/status.py` - Default archived stories' status to "done" when missing

**Root Cause:** Archived stories in `sprint/archive/sprint-*-completed.yaml` lack a `status` field. The counting loop at `status.py:71` defaults missing status to `"backlog"`, so 150 archived stories were counted as backlog instead of completed. The `metrics` command avoided this by counting `len(current_archived)` directly rather than checking status.

**Fix:** Two lines — `if not s.get("status"): s["status"] = "done"` when processing archived stories.

**Before:** 50 completed, 104/544 points
**After:** 200 completed, 503/544 points (matches `pf sprint metrics`)

**Tests:** 6/6 passing (GREEN)
**Branch:** fix/136-14-sm-sprint-status-omits-completed-stories (pushed)

**Handoff:** To Zorg (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `get_archived_stories()` → stories without status field → default to "done" → counted correctly in completed totals (safe — no user input)
**Pattern observed:** Aligns `get_sprint_status()` with `metrics` command's counting at `cli.py:1682`
**Error handling:** `not s.get("status")` safely catches None, missing key, and empty string
**Handoff:** To Ruby Rhod (SM) for finish-story

## Delivery Findings

<!-- Delivery findings: append-only, one subsection per agent -->

### SM (setup)

- No upstream findings during setup.

### Dev (implementation)

- No upstream findings during implementation.

### Reviewer (code review)

- No upstream findings during code review.