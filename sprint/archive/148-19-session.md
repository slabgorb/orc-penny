---
story_id: "148-19"
jira_key: "none"
epic: "MSSCI-16421"
workflow: "tdd"
---

# Story 148-19: Peloton pane reuse — TeamCreate targets pre-opened panes, TUI below CLI

## Story Details
- **ID:** 148-19
- **Jira Key:** none
- **Epic:** MSSCI-16421
- **Workflow:** tdd
- **Points:** 2
- **Priority:** p1
- **Stack Parent:** none

## Description

Two issues:

1. Peloton pre-opens tmux panes for agents (tea, dev, architect, reviewer) via create_peloton_layout, but TeamCreate ignores those and spawns additional panes. The pre-opened panes sit idle with zsh while new Claude processes run in separate panes. TeamCreate should target/reuse the pre-opened panes instead of spawning new ones.

2. TUI pane should stack directly below the CLI pane in the peloton layout, not at the bottom of the pane list.

## Acceptance Criteria
- TUI pane stacks below CLI pane in peloton layout (not at the bottom of the pane list)

## Workflow Tracking

**Workflow:** tdd
**Phase:** review
**Phase Started:** 2026-03-15T15:12:19Z 10:50 UTC

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-15 10:50 | 2026-03-15T15:06:53Z | 4h 16m |
| red | 2026-03-15T15:06:53Z | 2026-03-15T15:10:51Z | 3m 58s |
| green | 2026-03-15T15:10:51Z | 2026-03-15T15:12:19Z | 1m 28s |
| review | 2026-03-15T15:12:19Z | - | - |

## SM Assessment

Peloton layout creates agent panes but TeamCreate spawns separate ones — double panes per agent. Two fixes needed: (1) either skip pre-opening panes and let TeamCreate handle it, or have TeamCreate reuse existing named panes; (2) TUI pane placement below CLI. Routing to TEA for RED phase.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

No upstream findings

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

No design deviations