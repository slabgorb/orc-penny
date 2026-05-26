# Story 125-10: Add pf sprint focus commands (use/close/status)

**Jira:** PROJ-15431
**Epic:** 125 — Sprint State Engine Consolidation (PROJ-15421)
**Points:** 2
**Priority:** P3
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Assigned:** slabgorb@gmail.com

## Acceptance Criteria

- [ ] `pf sprint focus use NAME` switches active sprint context
- [ ] `pf sprint focus close NAME` marks focus as completed
- [ ] `pf sprint focus status` shows current focus and all active contexts
- [ ] Commands work gracefully without a sprint registry

## Context

Final story in Epic 125 (Sprint State Engine Consolidation). Adds CLI commands for managing focus contexts, building on the lifecycle fields added in 125-9. Replaces raw config editing with proper CLI interface.

Key files:
- `pennyfarthing-dist/pf/sprint/cli.py` — Sprint CLI commands
- `pennyfarthing-dist/pf/sprint/loader.py` — Sprint loading and switching
- `pennyfarthing-dist/pf/common/config.py` — Config file I/O

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/focus.py` - New module with use_focus(), close_focus(), get_focus_status() business logic
- `pennyfarthing-dist/src/pf/sprint/cli.py` - Added focus subgroup with use/close/status commands
- `tests/python/test_sprint_focus.py` - 12 unit tests covering all ACs

**Tests:** 12/12 passing (GREEN)
**Branch:** feature/PROJ-15431-focus-commands (pushed)

**Handoff:** To Granny Weatherwax for code review