# Story 76-4: Sprint story update command

**Jira:** MSSCI-14257
**Epic:** MSSCI-14253 (Sprint Data Management System)
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Branch:** feature/MSSCI-14257-story-update-command
**Repos:** pennyfarthing

## Acceptance Criteria

1. **AC1 - Field Updates:** Update individual and multiple story fields (status, points, priority, etc.) by story ID
2. **AC2 - Story Lookup:** Find stories across all epics by story ID (e.g., "76-4" finds story in epic 76)
3. **AC3 - Auto-Cleanup Rules:** When status=done, auto-set completed date and remove assigned_to; when status=in_progress, auto-set started date
4. **AC4 - Validate & Atomic Write:** Validate after mutation, atomic write via yaml_io, dry-run support, reject invalid updates

## Technical Context

- Create `pennyfarthing_scripts/sprint/story_update.py` with update logic
- Create `pennyfarthing_scripts/tests/test_story_update.py` with TDD tests
- Modify `pennyfarthing_scripts/sprint/cli.py` to register `update` subcommand
- Uses `yaml_io.read_sprint()` / `write_sprint()` from 76-1
- Uses `loader.find_epic()` / `loader.find_story()` for story lookup
- Auto-cleanup: done→auto-set completed, remove assigned_to; in_progress→auto-set started

## Assessment

**SM Assessment (setup):** Story 76-4 is ready for TEA. All 4 acceptance criteria defined. Dependencies on yaml_io (76-1) and loader utilities are established. TDD workflow — TEA designs tests first, then Dev implements. Branch: feature/MSSCI-14257-story-update-command in pennyfarthing repo.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (37 failing, 2 infrastructure passes)

**Test Files:**
- `pennyfarthing_scripts/tests/test_story_update.py` — 39 tests across 5 classes
- `pennyfarthing_scripts/sprint/story_update.py` — stub with `NotImplementedError`

**Tests Written:** 39 tests covering 4 ACs + CLI integration

| Class | AC | Tests | Coverage |
|-------|-----|-------|----------|
| `TestUpdateStoryFields` | AC1 | 8 | status, points, priority, assigned_to, multiple fields, preserve untouched, noop, update completed story |
| `TestFindStoryAcrossEpics` | AC2 | 5 | first epic, second epic, story not found, epic not found, invalid ID format |
| `TestAutoCleanup` | AC3 | 7 | done removes assigned_to, done auto-sets completed, done preserves explicit completed, in_progress auto-sets started, in_progress preserves existing started, backlog no cleanup, ready no cleanup |
| `TestValidateAndAtomicWrite` | AC4 | 8 | valid writes, invalid rejected, file unchanged on failure, no temp files, dry-run no write, dry-run reports changes, file valid after, other stories unchanged |
| `TestCLIIntegration` | CLI | 11 | command exists, basic update, status/points/assigned-to/completed/started options, dry-run, nonexistent story error, invalid status error, success output |

**Implementation notes for Dev:**
- Follow `story_add.py` pattern closely — same read→find→mutate→validate→write flow
- `update_story()` signature matches the stub exactly — fill in the logic
- Auto-cleanup rules: check status value, conditionally set/remove fields
- Mock pattern: tests mock `date.today()` via `patch("pennyfarthing_scripts.sprint.story_update.date")` — import `from datetime import date` at module level
- Register `story_update_command` in `cli.py` like `story_add_command` (line 279-281)
- CLI uses `--sprint-file` for test injection, falls back to `config.get_project_root()`

**Handoff:** To Dev for implementation (GREEN phase)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/sprint/story_update.py` — Full implementation: update_story() + story_update_command CLI
- `pennyfarthing_scripts/sprint/cli.py` — Registered story-update subcommand

**Tests:** 39/39 passing (GREEN)
**PR:** #677 - feat(76-4): sprint story update command
**Branch:** feature/MSSCI-14257-story-update-command (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** CLI args → `update_story()` → `read_sprint()` → `find_epic()`/`find_story()` → mutate fields → auto-cleanup rules → `validate_full_sprint()` → `write_sprint()` (atomic). Safe — validation gates both pre (status check) and post (full sprint validation) mutation.

**Pattern observed:** Follows `story_add.py` pattern exactly — same imports, return dict convention, CLI error handling, `--sprint-file` override. CLI registration at `cli.py:283-286` matches existing E402 pattern at lines 273-281.

**Error handling:**
- Invalid status: fail-fast before I/O at `story_update.py:53-57`
- Bad story ID / missing epic / missing story: clear error messages at `story_update.py:61-80`
- Post-mutation validation: `story_update.py:108-113`
- Atomic write via `yaml_io.write_sprint()` — temp file + `os.replace()`

**Tests:** 39/39 passing. 5 test classes covering all 4 ACs + CLI integration. Good edge case coverage (no-op updates, preserving untouched fields, date preservation).

**Minor notes (non-blocking):**
- `[LOW]` Unused `CommentedMap` import in test file (`test_story_update.py:6`)
- `[LOW]` `click.BaseCommand` deprecation warning (Click 9.0) in test

**Handoff:** To SM for finish-story
