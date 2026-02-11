# Story 99-2: Fix story finish archive missing required sprint fields

**Epic:** 99 — Sprint CLI Bug Fixes
**Jira:** (none)
**Points:** 1
**Priority:** P1
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/99-2-fix-archive-missing-sprint-fields
**Assigned:** Keith Avery

---

## Context

The `pf sprint story finish` command creates `sprint/archive/sprint-YYWW-completed.yaml` but omits required sprint fields: `number`, `start_date`, `end_date`, and `status`. The pre-commit YAML validator correctly rejects this, blocking the commit.

**Root cause:** The archive writer in `pennyfarthing_scripts` doesn't copy all required sprint metadata from `current-sprint.yaml` into the archive file.

**Fix:** Update the archive writer to include `number`, `start_date`, `end_date`, and `status` in the sprint section of the completed archive file.

## Acceptance Criteria

- [ ] `pf sprint story finish` produces archive YAML that passes `validate_sprint_yaml()` without schema errors
- [ ] Archive file includes `number`, `start_date`, `end_date`, and `status` fields
- [ ] Existing archive files are not affected (fix is forward-only)

## Files of Interest

- `pennyfarthing/pennyfarthing_scripts/sprint/` — sprint CLI commands
- `pennyfarthing/pennyfarthing_scripts/sprint/validate_cmd.py` — validator
- `pennyfarthing/pennyfarthing_scripts/sprint/validator.py` — validation rules
- Look for archive/finish logic that writes `sprint-YYWW-completed.yaml`

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/sprint/archive_epic.py` — added `number`, `start_date`, `end_date`, `status` to `ensure_archive_file()` template

**Tests:** 750/750 passing (GREEN)
**PR:** #821 — fix(99-2): include required sprint fields in archive template
**Branch:** feat/99-2-fix-archive-missing-sprint-fields (pushed)

**Handoff:** To Reviewer for code review

---

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `load_sprint()` → `sprint_info.get()` → f-string template → `write_text()` (safe — all values from controlled `current-sprint.yaml`, no user input)
**Pattern observed:** Template follows existing unquoted f-string pattern for `jira_sprint_id`/`goal` at `archive_epic.py:78-86`
**Accuracy verified:** 4 new fields (`number`, `start_date`, `end_date`, `status`) match `REQUIRED_SPRINT_FIELDS` at `validator.py:73`
**Pre-existing failure:** `test_yaml_io.py::test_write_preserves_sharded_format` — confirmed unrelated, fails on base branch too
**Observations:** 1 LOW (unquoted f-string values — safe for these types, matches existing pattern) — non-blocking

**Handoff:** To SM for finish-story
