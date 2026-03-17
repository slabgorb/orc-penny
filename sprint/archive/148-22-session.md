---
story_id: "148-22"
jira_key: ""
epic: "MSSCI-16421"
workflow: "trivial"
---

# Story 148-22: Peloton agent color matching — teammates run /color to match badge colors

**Phase:** implement
**Workflow:** trivial
**Branch:** feat/148-22-peloton-agent-colors
**Repos:** pennyfarthing

## Context

When peloton spawns teammates, each agent gets a badge color in the Claude Code UI (tea=blue, dev=green, reviewer=yellow, etc.). The teammate's tmux pane or Claude CLI should match these colors. The story title mentions "run /color" — this likely refers to having the peloton startup prompt instruct each teammate to set their CLI color to match their badge color.

## Acceptance Criteria

- [x] AC1: Each peloton teammate's prompt includes a color instruction matching their badge color
- [x] AC2: Color assignments are consistent with the teammate badge colors (tea=blue, dev=green, reviewer=yellow, architect=purple)

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/peloton/live.py` - Added `AGENT_BADGE_COLORS` mapping and `/color` instructions in TeamCreate prompt

**Tests:** 96/96 passing (GREEN)
**Branch:** feat/148-22-peloton-agent-colors (pushed)

**Handoff:** To review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `AGENT_BADGE_COLORS.get(agent)` → f-string → prompt text (safe, no injection vector — static dict, no user input)
**Pattern observed:** Graceful fallback via `.get(agent, "")` + conditional at `live.py:183-184`
**Error handling:** Unmapped agents silently skip color instruction — correct behavior
**Tests:** 96/96 peloton tests passing

| Severity | Issue | Location | Note |
|----------|-------|----------|------|
| [LOW] | `ux-designer`, `tech-writer`, `orchestrator` have no color mapping | `live.py:26-31` | Non-blocking — AC only requires tea/dev/reviewer/architect. Fallback is safe. |
| [VERIFIED] | Color assignments match AC | `live.py:26-31` | tea=blue, dev=green, reviewer=yellow, architect=purple |
| [VERIFIED] | SM excluded from agent list | `live.py:143` | `_extract_agents` filters `agent != "sm"` — no SM color needed |
| [VERIFIED] | Prompt format clean and readable | `live.py:184-188` | Instruction appends naturally to bullet |
| [VERIFIED] | No regressions | tests | 96/96 pass |

**Handoff:** To SM for finish-story
