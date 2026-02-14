# Story td-4: Shard completed archive like active sprint (index + per-epic refs)

## Story Details
- **ID:** td-4
- **Workflow:** tdd

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-14T12:15:00Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-14T00:00:00 | 2026-02-14T00:01:00 | 1m |
| red | 2026-02-14T00:01:00 | 2026-02-14T11:31:24Z | 11h 30m |
| green | 2026-02-14T11:31:24Z | 2026-02-14T11:38:35Z | 7m 11s |
| review | 2026-02-14T12:00:00Z | 2026-02-14T12:15:00Z | 15m |

## Context

### Problem Statement
The completed archive file (`sprint/archive/sprint-2606-completed.yaml`) is currently a flat monolith that duplicates entire story records. This design causes:
- Merge conflicts when multiple agents complete stories concurrently
- Data duplication across the active sprint and archive
- Inconsistent update propagation (changes to a story in one place don't sync)

### Solution
Refactor the completed archive to use the same **index + per-epic shard** pattern as the active sprint:
- `sprint/archive/sprint-{N}-completed.yaml` becomes an index that references completed epic shards
- Each completed epic's stories are stored in `sprint/archive/epic-{ref}.yaml`
- This parallels the active sprint structure: `current-sprint.yaml` (index) + `epic-{ref}.yaml` (shards)

### Key Files to Modify

1. **archive_epic.py** (lines 324-331)
   - Currently adds string epic ref to `completed_epics` list
   - Needs to populate `completed_stories` when an epic is archived

2. **story_finish.py** (lines 189-193)
   - Currently calls `archive_all_completed()` via CLI
   - No changes needed here; archive_epic.py handles the flow

3. **sprint/archive/sprint-2606-completed.yaml**
   - Currently has all stories inlined under `completed_stories`
   - Refactor to index format with `completed_epics` refs only

4. **Test coverage**
   - Verify archive shard pattern matches active sprint pattern
   - Confirm merge conflict resolution works with sharded archive

### Acceptance Criteria
- Archive index file uses same structure as current-sprint.yaml
- Completed epics stored in `sprint/archive/epic-{ref}.yaml`
- No data duplication between active sprint and archive
- All existing completed stories preserved after refactor
- Merge conflicts resolved cleanly with sharded approach

## TEA Assessment

**Tests Required:** Yes
**Reason:** Data migration with risk of loss — must verify preservation

**Test Files:**
- `pennyfarthing/tests/python/test_archive_sharding.py` — 14 tests across 6 classes

**Tests Written:** 14 tests covering all 5 ACs
- `TestMigrationProducesIndexFormat` (3) — AC1: index has refs only, orphans preserved
- `TestMigrationCreatesShardsPerEpic` (4) — AC2: shards created, correct stories, metadata, no clobber
- `TestNoDuplication` (1) — AC3: migrated stories removed from index
- `TestMigrationPreservesAllStories` (2) — AC4: count preserved, field data intact
- `TestLoadArchiveMergesShards` (3) — AC5: loader merges shards + orphans, handles pre-migration
- `TestMigrationIdempotent` (1) — bonus: double migration is safe

**Stubs Added:**
- `migrate_completed_archive(archive_path)` in `archive_epic.py` — raises NotImplementedError
- `load_archive(archive_path)` in `archive_epic.py` — raises NotImplementedError

**Status:** RED (14 failing on NotImplementedError — correct failure mode)

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/sprint/archive_epic.py` — implemented `migrate_completed_archive()` and `load_archive()`

**Tests:** 14/14 passing (GREEN)
**PR:** #875 - feat(td-4): shard completed archive like active sprint
**Branch:** feat/td-4-shard-completed-archive (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** REJECTED

| # | Severity | Issue | Location |
|---|----------|-------|----------|
| 1 | [HIGH] | Ruff lint CI failure — unused `import pytest` and unsorted import block | `tests/python/test_archive_sharding.py:15-26` |
| 2 | [VERIFIED] | Data flow: stories grouped by epic → shard files → index orphans only | `archive_epic.py:93-183` |
| 3 | [VERIFIED] | Pattern matches `load_sprint()` index+shard architecture | `archive_epic.py:155-183` |
| 4 | [VERIFIED] | Error handling consistent with module patterns | `archive_epic.py:186-214` |
| 5 | [VERIFIED] | Idempotency correct — second migration is no-op | `test_archive_sharding.py:316-334` |
| 6 | [VERIFIED] | Merge-not-clobber preserves existing shard data | `archive_epic.py:125-133` |
| 7 | [MEDIUM] | No CLI entry point for migration (acceptable as library-only scope) | `archive_epic.py` |

**Fix Required:** Run `ruff check --fix tests/python/test_archive_sharding.py`, commit, push.

**Note:** CLI startup benchmark failure is pre-existing (CI runner slowness), not related to this PR.

**Handoff:** Back to Dev for lint fix

## Dev Assessment (Rework)

**Fix Applied:** Ruff lint errors resolved via `ruff check --fix`
**Changes:** Removed unused `import pytest`, sorted import block in `tests/python/test_archive_sharding.py`
**Tests:** 14/14 passing (GREEN)
**Commit:** `fe47523` — fix(td-4): resolve ruff lint errors in archive sharding tests
**Branch:** feat/td-4-shard-completed-archive (pushed)

**Handoff:** Back to Reviewer for re-review

## Reviewer Assessment (Re-review)

**Verdict:** APPROVED
**Prior blocking issue resolved:** Ruff lint now passes (verified locally)
**Tests:** 14/14 passing (GREEN)
**Data flow traced:** `archive_path` → `_load_archive_file()` → group by epic → `_write_yaml_file()` shard → `_write_archive_file()` orphans (safe — no user-controlled paths, no injection vectors)
**Pattern observed:** Follows `load_sprint()` index+shard architecture at `archive_epic.py:155-183`
**Error handling:** Null/None guards in `_load_archive_file()` at `archive_epic.py:199-212`, consistent with module
**Handoff:** To SM for finish-story

## Handoff History
| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| red (tea) | green (dev) | tests_fail | PASSED | 2026-02-14T11:31:24Z |
| green (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-14T11:38:35Z |
| review (reviewer) | green (dev) | review_rejected | PASSED | 2026-02-14T11:40:00Z |
| green (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-14T12:00:00Z |
| review (reviewer) | finish (sm) | review_approved | PASSED | 2026-02-14T12:15:00Z |
