# Standalone: Add startup agent auto-invoke on SessionStart

**Jira:** PROJ-16331
**Points:** 3
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/PROJ-16331-startup-agent-autoinvoke
**PR:** 1319
**Started:** 2026-03-10
**Completed:** 2026-03-10

---

## Description

Add startup_agent setting that auto-invokes a configured agent on session start. The SessionStart hook loads agent context via prime (HANDOFF tier) and injects it as additionalContext, so the agent is active from the first message.

Also removes dead welcome/greeting/nudge code from session_start.py — dev/tty output, discovery nudge markers, and welcome lock files were all non-functional.

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/hooks/session_start.py` | Remove dead welcome/greeting/nudge code; keep startup agent injection |
| `pennyfarthing-dist/src/pf/hooks/__init__.py` | Add startup_agent field to PennySettings |
| `pennyfarthing-dist/src/pf/prime/cli.py` | Add --greeting flag and _emit_greeting for stderr output |
| `pennyfarthing-dist/src/pf/cli.py` | Wire --greeting flag through Click CLI |
| `pennyfarthing-dist/src/pf/bikerack/settings_meta.py` | Add startup_agent select widget to settings UI |
| `pennyfarthing-dist/src/pf/settings/settings.py` | Add startup_agent default to DEFAULTS |
