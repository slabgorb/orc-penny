# Standalone: Archive stepped workflow sessions on completion

**Jira:** MSSCI-15514
**Points:** 2
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-15514-archive-stepped-workflow-sessions
**PR:** 1079
**Started:** 2026-02-23
**Completed:** 2026-02-23

---

## Description

Stepped workflows (architecture, prd, epics-and-stories, etc.) left session files in `.session/` after completion. This confused subsequent agent activations because the workflow state detector sees an in-progress session. Phased workflows already archive via `pf sprint story finish`, but stepped workflows had no equivalent cleanup.

Added archive logic to `workflow_complete_step_cmd()` — after writing `status: completed`, the session file is moved to `sprint/archive/`.

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/pf/workflow/cli.py` | Added shutil.move to archive completed stepped workflow sessions |
