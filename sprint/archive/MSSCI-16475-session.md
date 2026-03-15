---
story_id: "148-16"
jira_key: "MSSCI-16475"
epic: "MSSCI-16421"
workflow: "trivial"
---

# Story 148-16: Disable CLI statusbar for subagents — prevent status line noise in agent panes

## Story Details
- **ID:** 148-16
- **Jira Key:** MSSCI-16475
- **Epic:** MSSCI-16421
- **Workflow:** trivial
- **Stack Parent:** none

## Workflow Tracking

**Workflow:** trivial
**Phase:** review
**Phase Started:** 2026-03-15T13:46:03Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-15T13:35:26Z | 2026-03-15T13:36:47Z | 1m 21s |
| implement | 2026-03-15T13:36:47Z | 2026-03-15T13:46:03Z | 9m 16s |
| review | 2026-03-15T13:46:03Z | - | - |

## SM Assessment

Trivial 1-point story. Subagents spawned via the Agent tool get Claude Code's status line in their tmux panes, adding noise. Need to suppress the statusbar for subagent processes.

**Acceptance Criteria:**
- [ ] AC1: Subagent panes do not show CLI statusbar
- [ ] AC2: Main Claude Code pane retains its statusbar
- [ ] AC3: No regressions in existing agent/subagent functionality

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

No upstream findings.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

No design deviations yet.