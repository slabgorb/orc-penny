# Story td-5: Re-load agent after plan mode context clear

## Story Details
- **ID:** td-5
- **Title:** Re-load agent after plan mode context clear
- **Points:** 2
- **Type:** bug
- **Repos:** pennyfarthing
- **Branch:** feat/td-5-reload-agent-after-plan-clear
- **Workflow:** trivial

## Context
When a user is in plan mode and the context window fills up, Claude Code triggers a context clear. After the clear, the agent persona is lost — the user has to manually re-activate the agent. Same problem occurs on `/clear` and auto-compaction. Additionally, the `startup` matcher silently loads SM with no visible confirmation, so stale agents from previous sessions can look identical to freshly loaded ones.

### Technical Analysis (from party mode brainstorm)

**SessionStart matcher values:** `startup`, `resume`, `clear`, `compact`

**Current hooks in `.claude/settings.local.json`:**
- `startup` → `auto-load-sm.sh` — injects "load SM" but no visible confirmation
- `compact` → `prime.sh` — runs `pf prime` with NO agent name (generic context only)
- `clear` → **not handled at all**

**Key insight:** Session file at `.session/{story}-session.md` survives all clears. It contains `**Phase:**` and `**Workflow:**` fields. `pf workflow phase-check` can determine the phase owner. `pf agent start {owner}` produces full activation context.

**Known issue:** [github.com/anthropics/claude-code/issues/15174](https://github.com/anthropics/claude-code/issues/15174) — SessionStart:compact output may not inject into context. Verify this is resolved.

### Implementation approach
Create a single Python hook (or enhance existing) that handles `compact` and `clear` matchers:
1. Check `.session/` for active session with `**Phase:**` and `**Workflow:**`
2. Determine phase owner via `pf workflow phase-check`
3. Output `pf agent start {owner}` activation as `additionalContext`
4. Include visible confirmation message so user knows which agent was loaded

For `startup`: update `auto-load-sm.sh` to also output a visible confirmation that SM was freshly loaded.

## Acceptance Criteria
- [ ] `startup` matcher: loads SM AND outputs visible confirmation (distinguish from stale agent)
- [ ] `compact` matcher: detects active agent from session file, reloads it, confirms to user
- [ ] `clear` matcher (new): same as compact — detect active agent, reload, confirm
- [ ] All three matchers make it obvious which agent is active and that it was freshly loaded
- [ ] No active session → fall back to current behavior (SM on startup, generic prime on compact/clear)
- [ ] No regression on clean starts (no `.session/` files)

## SM Assessment
Story is set up and ready for implementation. Trivial workflow — routes directly to Dev (Ponder Stibbons). Bug fix touching SessionStart hooks in `.claude/settings.local.json`, `auto-load-sm.sh`, and potentially a new Python hook for compact/clear agent reload. Framework repo (`pennyfarthing/`) changes.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/hooks/agent_reload.py` - New SessionStart hook: detects active agent from session file, injects reload instruction via additionalContext
- `pennyfarthing-dist/src/pf/hooks/cli.py` - Registered `pf hooks agent-reload` CLI command
- `pennyfarthing-dist/src/pf/common/hooks.py` - Added `compact` and `clear` matchers to INFRASTRUCTURE_HOOKS
- `pennyfarthing-dist/src/pf/hooks/frontmatter.py` - Added `agent-reload` to infrastructure hooks set
- `pennyfarthing-dist/src/pf/init/core.py` - Fixed hook dedup to compare matcher+command (not just command)
- `pennyfarthing-dist/src/pf/tests/test_init_command.py` - Updated test to use dynamic hook count
- `.pennyfarthing/project/hooks/auto-load-sm.sh` - Added visible confirmation message on startup

**Tests:** 80/80 passing (55 init + 25 e2e)
**Branch:** feat/td-5-reload-agent-after-plan-clear (pennyfarthing)

**AC Status:**
- [x] `startup` matcher: loads SM AND outputs visible confirmation
- [x] `compact` matcher: detects active agent from session file, reloads it, confirms to user
- [x] `clear` matcher (new): same as compact — detect active agent, reload, confirm
- [x] All three matchers make it obvious which agent is active and that it was freshly loaded
- [x] No active session → silent exit (falls back to current behavior)
- [x] No regression on clean starts (no `.session/` files)

**Handoff:** To Reviewer (Granny Weatherwax) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** SessionStart JSON stdin → `find_active_session` → `_parse_workflow_phase` → `get_phase_owner` → `additionalContext` output (safe — all local file reads, no user input injection)
**Pattern observed:** Hook follows established `session_start.py` pattern — try/except with silent exit, `HookResponse` output, lazy imports. At `agent_reload.py:71-107`
**Error handling:** Every failure path returns None or exits silently. `find_active_session` → None, `_parse_workflow_phase` → (None, None), `get_phase_owner` → None. All handled at `agent_reload.py:63-64,85-87`
**Dedup fix:** `init/core.py:370-378` now compares (matcher, command) tuple — prevents duplicate hooks with same command but different matchers. Genuine bug fix.
**Medium note:** `_parse_workflow_phase` uses last-match-wins across full file. Safe for current session format but fragile if format diversifies.

**Handoff:** To SM (Captain Carrot) for finish-story

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-02-25T21:00:52Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-25T20:22:40Z | 2026-02-25T20:23:26Z | 46s |
| implement | 2026-02-25T20:23:26Z | 2026-02-25T20:45:30Z | 22m 4s |
| review | 2026-02-25T20:45:30Z | 2026-02-25T21:00:52Z | 15m 22s |
| finish | 2026-02-25T21:00:52Z | - | - |