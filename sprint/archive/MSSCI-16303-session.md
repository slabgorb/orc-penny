# Standalone: Fix persona tracking — eliminate CYCLIST_SESSION_ID, set SESSION_ID before WheelHub spawn

**Jira:** MSSCI-16303
**Points:** 3
**Priority:** P1
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16303-fix-persona-session-id
**PR:** 1310
**Started:** 2026-03-08
**Completed:** 2026-03-08

---

## Description

TUI persona display frequently showed stale ORC (orchestrator) instead of the active agent. Root cause: SESSION_ID was not set in process env before WheelHub spawned, so persona resolution fell back to mtime-sorting stale agent files and then defaulting to orchestrator.

Additionally, the CYCLIST_SESSION_ID env var was an unnecessary translation layer — SESSION_ID was renamed to CYCLIST_SESSION_ID when passed to WheelHub, adding confusion and failure points.

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/hooks/session_start.py` | Set SESSION_ID in env before WheelHub spawn |
| `packages/core/src/server/pennyfarthing.ts` | Remove ORC default, add 1-hour mtime window |
| `packages/core/src/server/websocket.ts` | Dynamic SESSION_ID reads in watcher |
| `packages/core/src/server/api/persona.ts` | CYCLIST_SESSION_ID → SESSION_ID |
| `packages/core/src/cli/commands/cyclist.ts` | CYCLIST_SESSION_ID → SESSION_ID |
| `pennyfarthing-dist/src/pf/bikerack/launcher.py` | CYCLIST_SESSION_ID → SESSION_ID |
| `pennyfarthing-dist/src/pf/hooks/statusline.py` | 1-hour mtime window on fallback |
| `pennyfarthing-dist/src/pf/prime/session.py` | Stale agent file purge on register |
| `packages/cyclist/tests/story-git.test.ts` | Env var rename in test |
| `pennyfarthing-dist/src/pf/_dist/server/wheelhub.mjs` | Rebuilt bundle |
