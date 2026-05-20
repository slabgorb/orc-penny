# Story 132-5: Sprint totals must include archived stories from current sprint

## Story Details
- **ID:** 132-5
- **Epic:** 132 (PROJ-15765) — Release Workflow Hardening (11.x Followup)
- **Type:** bug
- **Priority:** p0
- **Points:** 2
- **Repos:** pennyfarthing
- **Workflow:** trivial

## Problem Context

Sprint metrics are not counting archived stories from the current sprint. The issue:
- `sprint-2608-completed.yaml` contains 145 stories / 356 points
- The metrics backend only shows 32 points done
- The archive file is being counted in the "all-time" bucket instead of current sprint totals
- Both TUI Sprint panel and `pf sprint metrics` show wrong numbers

Related work: Story PROJ-15763 "Move sprint calculations to backend" recently completed, so the calculation logic is now in the WheelHub API routes or core package.

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-02-27T12:05:12Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-27T11:58:27Z | 2026-02-27T11:59:36Z | 1m 9s |
| implement | 2026-02-27T11:59:36Z | 2026-02-27T12:03:52Z | 4m 16s |
| review | 2026-02-27T12:03:52Z | 2026-02-27T12:05:12Z | 1m 20s |
| finish | 2026-02-27T12:05:12Z | - | - |

## Notes
- Fix likely involves sprint calculation backend in WheelHub API or core package
- Check: How archived stories are loaded and counted in sprint metrics calculations
- Check: Sprint totals endpoint in packages/core

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/loader.py` - Added `exclude_current` and `only_current` filters to `get_archived_stories()`
- `pennyfarthing-dist/src/pf/sprint/cli.py` - Updated `data()` and `metrics()` to include current sprint archived stories in done counts

**Tests:** N/A (trivial workflow, Python CLI — no test suite for this path)
**Branch:** feat/132-5-sprint-totals-archived-fix (pushed)

**Results:** `pf sprint metrics` now shows 388 done pts (was 32). `pf sprint data --json` shows 385 completed pts (was ~32). Prior sprint archives correctly separated at 351 pts.

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Sprint number (int) from `current-sprint.yaml` → compared to archive `sprint.number` → filters correctly at `loader.py:296`
**Pattern observed:** Backward-compatible parameter addition with safe defaults at `loader.py:260-263`
**Error handling:** Missing sprint number in archive → treated as prior sprint (safe default) at `loader.py:295-296`
**Observations:** 5 total (3 verified good, 1 low severity, 1 verified edge case). No critical or high issues.
**Handoff:** To SM for finish-story

## SM Assessment (setup → implement)
**Bug:** Sprint totals exclude 356 points / 145 stories from `sprint/archive/sprint-2608-completed.yaml`. The archive is counted under "all-time" (707 archived) instead of current sprint done. Both CLI `pf sprint metrics` and TUI Sprint panel show ~32 pts done when the real number is ~388. The calculation logic was recently moved to the backend (PROJ-15763) so the fix is in the core package sprint calculation code. Trivial workflow — Dev implements and reviews.