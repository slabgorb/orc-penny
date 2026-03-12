# Standalone: Plan mode agent reload hook for ExitPlanMode

**Jira:** MSSCI-16323
**Points:** 2
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16323-plan-exit-reload
**PR:** 1318
**Started:** 2026-03-10
**Completed:** 2026-03-10

---

## Description

PreToolUse hook that reloads the active agent when exiting plan mode. Supports signal file (.session/.plan-exit-agent) for cross-agent plan handoffs. Includes guide and agent-behavior docs.

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/hooks/plan_exit_reload.py` | New hook — fires on ExitPlanMode, resolves agent from signal file or session |
| `pennyfarthing-dist/src/pf/hooks/dispatch.py` | Registered plan-exit-reload in PreToolUse registry |
| `pennyfarthing-dist/guides/plan-mode.md` | New guide — full plan mode handoff documentation |
| `pennyfarthing-dist/guides/agent-behavior.md` | Added plan-mode section with link to guide |
