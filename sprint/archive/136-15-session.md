# Story 136-15: Sprint status undercounts completed points — ignores archived epics

**Status:** in_progress
**Phase:** finish
**Workflow:** tdd
**Repos:** orchestrator
**Branch:** fix/136-15-sprint-status-undercounts-completed-points
**Jira:** none
**Assigned:** keithavery
**Points:** 2

## Acceptance Criteria
- Sprint status includes points from archived epic files
- Completed point count matches actual done stories across all sources

## Technical Approach

**Root cause:** `get_sprint_status()` in `pf/sprint/status.py` only reads from `load_sprint()`.
It never calls `get_archived_stories()` from `pf/sprint/loader.py`. When epics are archived
via `pf sprint epic archive`, their stories move to `sprint/archive/sprint-*-completed.yaml`
and vanish from point totals.

**Fix pattern:** The `metrics` command in `cli.py:1576` already does this correctly:
```python
current_sprint_archived = get_archived_stories(only_current=True)
```
Apply the same pattern to `get_sprint_status()`:
1. Import `get_archived_stories` from `pf.sprint.loader`
2. Call `get_archived_stories(only_current=True)` to get current sprint's archived stories
3. Add their points to `completed_points` and `total_points`
4. Add their count to `completed` and `total_stories`

**Key file:** `pennyfarthing-dist/src/pf/sprint/status.py`

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core metrics calculation must be verified

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_sprint_status.py` - 6 tests covering archived story inclusion

**Tests Written:** 6 tests covering 2 ACs
**Status:** RED (failing - ready for Dev)

| Test | What It Verifies |
|------|-----------------|
| `test_completed_points_includes_archived_stories` | AC1: archived points in completed_points |
| `test_total_points_includes_archived_stories` | AC1: archived points in total_points |
| `test_completed_count_includes_archived_stories` | AC2: archived count in completed |
| `test_total_stories_includes_archived_stories` | AC2: archived count in total_stories |
| `test_no_archived_stories_still_works` | Regression: empty archive doesn't break |
| `test_format_status_shows_correct_points_with_archived` | AC2: display output reflects true totals |

**Handoff:** To Korben Dallas (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/status.py` - Import get_archived_stories, add archived stories to totals before counting

**Tests:** 6/6 passing (GREEN)
**Branch:** fix/136-15-sprint-status-undercounts-completed-points (pushed)

**Handoff:** To Zorg (Reviewer) for code review

## TEA Verify Assessment

**GREEN State Confirmed:** Yes
**Tests:** 6/6 passing
**Implementation Review:** Fix correctly imports `get_archived_stories` and appends archived stories to the collection before counting — same pattern used by the `metrics` command. No edge cases missed.

**Handoff:** To Ruby Rhod (SM) for finish flow

## Reviewer Assessment

**Verdict:** APPROVED
**Tests:** 6/6 passing (preflight confirmed)
**Data flow traced:** `get_archived_stories(only_current=True)` → YAML archive files → story dicts → appended to stories list → counted in totals (safe — no user-controlled input)
**Pattern observed:** Fix follows established `metrics` command pattern at `cli.py:1576` — same function, same parameter, same integration point
**Error handling:** Consistent with codebase — exceptions propagate (no wrapping), same as `load_sprint()` and `get_sprint_info()` calls
**Observations:**
- [VERIFIED] Import wiring correct at `status.py:9`
- [VERIFIED] Pattern consistency with `cli.py:1576`
- [VERIFIED] Empty archive safety via `loader.py:281` returning `[]`
- [VERIFIED] Counting correctness — archived stories naturally flow through existing point/count logic
- [VERIFIED] Test coverage — 6 tests, both ACs, regression case, format integration
- [LOW] Unused `pytest` import in test file — style nit, non-blocking

**Handoff:** To Ruby Rhod (SM) for finish-story

## Delivery Findings

<!-- Delivery findings: append-only, one subsection per agent -->

### TEA (test design)

- No upstream findings during test design.

### Dev (implementation)

- No upstream findings during implementation.

### TEA (test verification)

- No upstream findings during test verification.

### Reviewer (code review)

- No upstream findings during code review.