---
story_id: "148-11"
jira_key: "MSSCI-16451"
epic: "MSSCI-16421"
workflow: "tdd"
---
# Story 148-11: Peloton live mode uses team mode instead of claude -p

## Story Details
- **ID:** 148-11
- **Jira Key:** MSSCI-16451
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-14T10:22:56Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-14T10:11:09Z | 2026-03-14T10:13:54Z | 2m 45s |
| red | 2026-03-14T10:13:54Z | 2026-03-14T10:15:26Z | 1m 32s |
| green | 2026-03-14T10:15:26Z | 2026-03-14T10:18:02Z | 2m 36s |
| spec-check | 2026-03-14T10:18:02Z | 2026-03-14T10:20:59Z | 2m 57s |
| verify | 2026-03-14T10:20:59Z | 2026-03-14T10:21:35Z | 36s |
| review | 2026-03-14T10:21:35Z | 2026-03-14T10:22:20Z | 45s |
| spec-reconcile | 2026-03-14T10:22:20Z | 2026-03-14T10:22:56Z | 36s |
| finish | 2026-03-14T10:22:56Z | - | - |

## SM Assessment

**Story:** 148-11 — Peloton live mode uses team mode instead of claude -p
**Points:** 3 | **Priority:** p0 | **Workflow:** tdd

### Setup Summary

- Session file created
- Branch `feat/148-11-peloton-team-mode` from develop
- Jira MSSCI-16451 claimed

### Scope

Peloton live mode currently launches agents via `claude -p` (non-interactive) in tmux panes. Replace with Claude Code native Agent Teams — SM acts as team lead, spawns TEA/Dev/Architect/Reviewer as teammates via TeamCreate/SendMessage.

### Key Files

- `pennyfarthing/pennyfarthing-dist/src/pf/peloton/live.py` — current tmux + claude -p implementation
- `pennyfarthing/pennyfarthing-dist/src/pf/peloton/cli.py` — CLI commands
- `pennyfarthing/pennyfarthing-dist/skills/pf-peloton/peloton.md` — skill definition

### Routing Decision

3-point TDD story → TEA for red phase.

---

## TEA Assessment

**RED phase complete.** 7 tests written, all 7 failing.

### Test File
`pennyfarthing/pennyfarthing-dist/src/pf/tests/test_148_11_peloton_team_mode.py`

### Acceptance Criteria Coverage

**AC-1: activate_next does NOT use claude -p** (2 failing tests)
- `test_activate_next_command_has_no_claude_p` — command field must not contain `claude -p`
- `test_activate_next_does_not_send_keys` — source must not call `send_keys` for agent launch

**AC-2: live.py provides team-mode activation data** (4 failing tests)
- `test_activate_next_returns_team_name` — result must include `team_name` for TeamCreate
- `test_activate_next_returns_agent_prompt` — result must include `prompt` for Agent tool
- `test_activate_next_prompt_includes_agent_start` — prompt must contain `pf agent start`
- `test_activate_next_returns_story_id` — result must include `story_id`

**AC-3: get_workflow_agents excludes SM** (1 failing test)
- `test_workflow_agents_excludes_sm` — SM should not be in the teammate list (SM is the team lead)

### Implementation Guidance for Dev

1. **`live.py` get_workflow_agents / _extract_agents**: Filter out `"sm"` from the returned agent list. SM is the team lead running in the main session, not a teammate.

2. **`live.py` activate_next**: Replace the `claude -p` command + `send_keys` with team-mode data. Return `{role, team_name, prompt, story_id}` instead of `{role, pane_id, command}`. The `prompt` should be something like `Run \`pf agent start {role}\`. Story: {story_id}.` The `team_name` follows the convention `peloton-{story_id}`.

3. **The skill file** (`pf-peloton/peloton.md`) will need updating to instruct SM to use TeamCreate/Agent/SendMessage instead of tmux pane commands — but that's a documentation change, not tested here.

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/peloton/live.py` — `activate_next` returns team-mode data; `_extract_agents` filters SM
- `pennyfarthing-dist/src/pf/tests/test_148_9_peloton_live.py` — updated 2 tests for new API
- `pennyfarthing-dist/src/pf/tmux/cli.py` — removed duplicate `read` command
- `pennyfarthing-dist/src/pf/tests/test_148_11_peloton_team_mode.py` — 7 new tests

**Tests:** 61/61 passing (GREEN) — 7 new + 54 existing
**Branch:** `feat/148-11-peloton-team-mode` (pushed)

**Handoff:** To next phase.

---

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None

All three ACs verified against the diff:
- AC-1: `activate_next` source contains no `claude -p` or `send_keys` — confirmed
- AC-2: Returns `{role, team_name, prompt, story_id}` — `team_name` follows `peloton-{story_id}` convention, `prompt` includes `pf agent start {role}` — confirmed
- AC-3: `_extract_agents` has `and agent != "sm"` filter — confirmed

Dev's delivery findings about stale skill file and CLI are valid but out-of-scope for this story. The story targeted the `live.py` API contract, not the CLI/skill layer.

**Decision:** Proceed to verify phase.

---

## TEA Assessment (verify)

**Verification:** PASSED — 61/61 tests green, zero regressions.

Tests verified: 148-11 (7), 148-9 (28), 148-10 (8), 148-8 (18).

---

## Reviewer Assessment

**Verdict:** APPROVED

4-file diff, all aligned. Key observations:

- `_extract_agents`: Single predicate `and agent != "sm"` — minimal, correct
- `activate_next`: Removed `claude -p` + `send_keys`, returns `{role, team_name, prompt, story_id}` for team-mode callers. State guard relaxed to not require panes — correct for team mode
- Defensive `if next_role in state.get("panes", {})` handles no-panes case gracefully
- Duplicate `pf tmux read` cleanup is a bonus fix
- 148-9 test updates are mechanical API contract changes

No issues found.

**Handoff:** To Stilgar (SM) for finish.

---

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Improvement** (non-blocking): The peloton skill file (`pf-peloton/peloton.md`) still documents tmux-based commands (`pf peloton start/next/switch`). It needs rewriting to document team-mode usage (TeamCreate/Agent/SendMessage pattern). The CLI commands in `cli.py` also still reference tmux pane spawning. These are documentation/CLI updates for a follow-up story.
- **Improvement** (non-blocking): `spawn_panes` still creates tmux panes. For team mode, pane spawning is unnecessary — agents run as native teammates. A follow-up could make `spawn_panes` optional or replace it with a team-mode init that only sets up state.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No deviations from spec.

### Architect (reconcile)
- No additional deviations found.