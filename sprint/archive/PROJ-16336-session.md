# Standalone: Upgrade pipeline replay benchmark to exercise full PF machinery

**Jira:** PROJ-16336
**Points:** 3
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/PROJ-16336-pipeline-replay-pf-machinery
**PR:** 1326
**Started:** 2026-03-10
**Completed:** 2026-03-10

---

## Description

Pipeline replay worktrees now include .pennyfarthing/ context, hooks, PATH setup, preserved helpers/skills tags, and reviewer kick-back loop with --max-rework-cycles flag. Four fixes:

1. **Fix 1**: Symlink `.pennyfarthing/` and create `.claude/settings.json` (PreToolUse hooks only) in worktrees
2. **Fix 2**: Ensure `pf` on PATH and set `CLAUDE_PROJECT_DIR` for hook resolution
3. **Fix 3**: Preserve `<helpers>` and `<skills>` tags in extracted prompts so subagents are resolvable
4. **Fix 4**: Reviewer kick-back loop with `--max-rework-cycles` flag (0=disabled, max 2)

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` | All 4 fixes: setup_worktree_pf_context(), env/PATH in run_phase(), _STRIP_TAGS cleanup, kick-back loop |
| `pennyfarthing-dist/src/pf/benchmark/cli.py` | --max-rework-cycles flag, rework echo line |
