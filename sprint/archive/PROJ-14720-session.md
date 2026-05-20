# Story 91-26: Enhance pf sprint info to return full sprint header

**Story ID:** 91-26
**Jira:** [PROJ-14720](https://slabgorb.atlassian.net/browse/PROJ-14720)
**Epic:** PROJ-14510 — Cross-File Reference & Schema Validation Pipeline
**Workflow:** trivial
**Phase:** finish
**PR:** #786 - feat(91-26): enhance pf sprint info with full header fields
**Repos:** pennyfarthing
**Branch:** feat/PROJ-14720-sprint-info-header
**Assigned:** keith.avery@slabgorb.io

---

## Description

Existing `pf sprint info` only returns `remaining`/`inProgress`/`endDate`. Enhance to include full sprint header fields: `name`, `jira_sprint_id`, `jira_sprint_name`, `goal`, `start_date`, `end_date`, `status`, `number`.

## Acceptance Criteria

- [ ] `pf sprint info` output includes all sprint header fields from current-sprint.yaml
- [ ] Existing `remaining` and `inProgress` fields still present
- [ ] Date fields serialized as strings for JSON compatibility

## Technical Context

- **File to edit:** `pennyfarthing_scripts/sprint/cli.py` (~line 1329-1360)
- **Pattern:** `get_sprint_info()` from `loader.py` already returns the full sprint dict
- **Key change:** Merge sprint header dict with computed remaining/inProgress values
- **Watch for:** Date objects from YAML need `str()` conversion for JSON serialization

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/sprint/cli.py` — merged sprint header dict into info() output, auto-stringify dates

**Tests:** 50/50 sprint CLI tests passing (GREEN)
**PR:** #786 — feat(91-26): enhance pf sprint info with full header fields
**Branch:** feat/PROJ-14720-sprint-info-header (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** YAML → get_sprint_info() → dict comprehension (date stringify) → json.dumps → stdout
**Pattern observed:** Duck-type date check `hasattr(v, 'isoformat')` at cli.py:1355 — robust
**Error handling:** Empty sprint dict degrades gracefully to just remaining/inProgress
**Consumers:** No Cyclist code parses old shape — safe to expand
**Tests:** 50/50 sprint CLI tests GREEN
**Handoff:** To SM for finish-story
