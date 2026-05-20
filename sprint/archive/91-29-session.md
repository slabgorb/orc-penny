# Story 91-29: Archive epic completed stories bug

## Story Details
- **ID:** 91-29
- **Workflow:** trivial

## Story Context

### Bug Description
`archive_epic()` in `pennyfarthing/pennyfarthing_scripts/sprint/archive_epic.py` has a critical bug: it appends the epic reference to `completed_epics` but never writes individual stories to the `completed_stories` list. The same issue exists in `story_finish.py`.

**Impact:** Completed stories vanish from the sprint panel when their epic is archived.

### Fix Location
- **Primary file:** `pennyfarthing/pennyfarthing_scripts/sprint/archive_epic.py`
- **Function:** `archive_epic()` (lines 324-331)
- **Secondary file:** `pennyfarthing/pennyfarthing_scripts/sprint/story_finish.py` (step 5)
- **Test location:** `pennyfarthing/pennyfarthing_scripts/tests/`

### Fix Details
After the epic reference is added to `completed_epics`, iterate through `epic.get("stories", [])` and append each story to `completed_stories`.

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-02-14T10:35:50Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-14 | 2026-02-14T10:18:58Z | <1m |
| implement | 2026-02-14T10:18:58Z | 2026-02-14T10:22:40Z | 3m 42s |
| review | 2026-02-14T10:22:40Z | 2026-02-14T10:35:50Z | 13m |
| finish | 2026-02-14T10:35:50Z | - | - |

## SM Assessment

Bug found during sprint panel investigation. Epic 98 (PROJ-14697) was archived with all 8 stories done, but only 4 of 8 stories had been written to `sprint-2606-completed.yaml` — the rest were lost. Root cause: neither `archive_epic()` nor `finish_story()` writes completed stories to the completed file. The `completed_stories` entries that exist were written manually by the SM agent, not by any script.

**Repos:** pennyfarthing
**Branch:** feat/91-29-archive-epic-completed-stories-bug

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/sprint/archive_epic.py` - Added story iteration after epic ref append; writes each story (id, epic, title, points, completed) to completed_stories with dedup guard
- `pennyfarthing_scripts/tests/test_archive_epic.py` - 5 new tests covering the fix and is_epic_complete

**Tests:** 5/5 passing (GREEN), 684 existing tests unaffected
**PR:** #872 - fix(sprint): populate completed_stories when archiving epics
**Branch:** feat/91-29-archive-epic-completed-stories-bug (pushed)

**Note:** `story_finish.py` does NOT need a separate fix — it calls `pf sprint epic archive` which triggers `archive_epic()`. The fix in archive_epic covers both code paths.

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Preflight:** 907 passed, 3 skipped, 0 failed. Lint clean.
**Data flow traced:** `archive_epic()` → `read_sprint()` → find epic → `is_epic_complete()` → load archive → dedup set → append stories → write back. No injection risk.
**Dedup verified:** Set comprehension at `archive_epic.py:333` provides O(1) lookup. Test confirms idempotency.
**Both paths covered:** `story_finish.py:190` delegates to `archive_epic()` via CLI — fix propagates automatically.
**Error handling:** `_load_archive_file` handles None data, missing keys, None lists defensively.
**Pattern observed:** Clean result-object pattern `{success, data?, error?}` at `archive_epic.py:371-387`.
**Low observations:** (1) No `status` field in archive entries — canceled vs done indistinguishable. Non-blocking. (2) Test warnings about missing epic ref are cosmetic.
**Handoff:** To SM for finish-story

## Handoff History

| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| implement (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-14T10:22:40Z |
| review (reviewer) | finish (sm) | review_approved | PASSED | 2026-02-14T10:35:50Z |

