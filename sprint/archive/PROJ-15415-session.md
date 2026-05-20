# Story 120-9: Add statusbar CLI toggle setting

**Jira:** PROJ-15415
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/120-9-statusbar-cli-toggle
**Points:** 1
**Type:** chore

## Acceptance Criteria

Add a configuration setting to allow toggling the statusbar (status line) visibility in Claude Code through CLI configuration. This is a chore task to add the infrastructure for statusbar control.

## Context

The statusline.py hook renders the Claude Code status bar at the bottom of the terminal. It displays agent role, theme, repository, branch, model, and context usage metrics. This story adds a configuration setting to allow users to toggle the statusbar visibility through `.pennyfarthing/config.local.yaml`.

**Related files:**
- `/pennyfarthing/pennyfarthing-dist/pf/hooks/statusline.py` — statusline hook implementation
- `.pennyfarthing/config.local.yaml` — user configuration (where the toggle setting should be added)
- Hook system reads settings via `load_settings()` from `pf.hooks`

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/pf/hooks/__init__.py` - Added `statusbar: bool = True` to CyclistSettings, loading from `workflow.statusbar` in config
- `pennyfarthing-dist/pf/hooks/statusline.py` - Early exit when statusbar is disabled

**Tests:** N/A (config toggle, no existing test suite for hooks)
**Branch:** feat/120-9-statusbar-cli-toggle (pushed)

**Usage:** Set `workflow.statusbar: false` in `.pennyfarthing/config.local.yaml` to hide the statusline. Default is `true` (visible).

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `config.local.yaml` → `workflow.statusbar` → `load_settings()` → `CyclistSettings.statusbar` → `statusline.py:main():366` → early exit if disabled
**Pattern observed:** Follows exact same pattern as `git_monitor` and `bell_mode` settings at `__init__.py:208-217`
**Error handling:** All `load_settings()` failure paths return default `statusbar=True` — safe degradation verified
**Observations:** 5/5 verified (default safety, pattern consistency, early exit behavior, load order, fallback safety). No issues found.
**Handoff:** To SM for finish-story

## Session Log

- 2026-02-22T07:07:58Z SM: Story setup complete, ready for Dev
- 2026-02-22T07:09:30Z Dev: Implementation complete, 2 files changed, branch pushed
- 2026-02-22T07:10:45Z Reviewer: APPROVED — clean, minimal, pattern-consistent change