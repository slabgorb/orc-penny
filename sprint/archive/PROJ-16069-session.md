# Story 137-7: Sprint status aggregates all archive files instead of filtering by current sprint

## Story Details
- **ID:** 137-7
- **Jira Key:** PROJ-16069
- **Epic:** 137 (PROJ-15920)
- **Title:** Sprint status aggregates all archive files instead of filtering by current sprint
- **Type:** bug
- **Points:** 2
- **Priority:** p1
- **Workflow:** tdd

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-03T12:36:51Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-03T12:26:19Z | 2026-03-03T12:27:34Z | 1m 15s |
| red | 2026-03-03T12:27:34Z | 2026-03-03T12:31:46Z | 4m 12s |
| green | 2026-03-03T12:31:46Z | 2026-03-03T12:33:32Z | 1m 46s |
| verify | 2026-03-03T12:33:32Z | 2026-03-03T12:34:39Z | 1m 7s |
| review | 2026-03-03T12:34:39Z | 2026-03-03T12:36:51Z | 2m 12s |
| finish | 2026-03-03T12:36:51Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): `current-sprint.yaml` has no `number` field, but `get_archived_stories` relies on `sprint.number` for filtering. Archives with and without `number` fields coexist in production.
  Affects `pennyfarthing-dist/src/pf/sprint/loader.py` (needs fallback matching on `name` or `jira_sprint_name`).
  *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): Unused `import textwrap` in `test_archived_stories_filter.py:18`. Cosmetic — no functional impact.
  Affects `pennyfarthing-dist/src/pf/tests/test_archived_stories_filter.py` (remove unused import).
  *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `pf sprint status` → `status.py:57` → `get_archived_stories(only_current=True)` → `loader.py:286` fallback `number → name`. Safe — both sides use identical cascade.
**Pattern observed:** `or`-chain fallback `get("number") or get("name")` at `loader.py:286,296` — consistent on both current and archive sides.
**Error handling:** `None` fallback when both fields absent → no filtering → graceful degradation (same as prior behavior).
**Tests:** 16/16 GREEN — 10 archive filter + 6 sprint status regression. Tests use real temp files, not over-mocked.
**Handoff:** To SM (The Mad Hatter) for finish-story

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/loader.py` - Changed `get_archived_stories` to fall back to `sprint.name` when `sprint.number` is absent for current-sprint matching

**Tests:** 16/16 passing (GREEN) — 10 archive filter + 6 sprint status regression
**Branch:** `feat/137-7-sprint-status-archive-filter` (pushed)

**Handoff:** To review phase

## TEA Assessment

**Tests Required:** Yes
**Reason:** Bug fix — need to prove the filter is broken before fixing

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_archived_stories_filter.py` - Tests for `get_archived_stories` sprint filtering

**Tests Written:** 10 tests covering 3 ACs (filter-by-current, exclude-current, no-double-count)
**Status:** RED (3 failing, 7 passing — failures are on assertions, not imports)

**Failing tests (the bug):**
1. `test_only_current_excludes_previous_sprint_archives` — returns 5 stories instead of 2
2. `test_only_current_works_without_number_field` — same, no fallback to name
3. `test_exclude_current_removes_current_sprint_stories` — returns 5 instead of 3

**Root cause:** `loader.py:286` uses `sprint_info.get("number")` which returns `None` when no number field exists. The `if current_number is not None:` guard at line 294 then bypasses all filtering.

**Fix hint for Dev:** Add fallback matching on `jira_sprint_name` (or `name`) when `number` is None. Both the current sprint YAML and archive files consistently have `name` and `jira_sprint_name`.

**Handoff:** To Dev (The White Rabbit) for implementation

## SM Assessment — Setup Phase

**Story:** 137-7 — Sprint status aggregates all archive files instead of filtering by current sprint
**Bug:** `pf sprint status` shows completed stories from all archived sprints, not just the current one. Archive files at `sprint/archive/` are loaded without filtering by sprint identifier.
**Workflow:** TDD — The Caterpillar (TEA) writes failing tests first to capture the expected filtering behavior, then The White Rabbit (Dev) fixes the bug.
**Repos:** pennyfarthing (framework source)
**Branch:** `feat/137-7-sprint-status-archive-filter`
**Risk:** Low — isolated to sprint status reporting, no downstream effects on story lifecycle or Jira sync.
**Routing:** TEA (red phase) → Dev (green phase) → standard review and finish.