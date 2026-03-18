---
story_id: "147-8"
jira_key: "MSSCI-16419"
epic: "MSSCI-16411"
workflow: "tdd"
---
# Story 147-8: Add write-time validators to settings and repo writers

## Story Details
- **ID:** 147-8
- **Jira Key:** MSSCI-16419
- **Workflow:** tdd
- **Epic:** MSSCI-16411 (Epic 147)
- **Points:** 2
- **Stack Parent:** none

## Story Description
Add write-time validators to the settings and repo writers so invalid data is rejected before persisting. This story requires a TDD approach: TEA writes failing tests first (red), then Dev makes them pass (green).

## Context
- **Settings API:** `pennyfarthing/pennyfarthing-dist/src/pf/`
- **Target Repos:** pennyfarthing (gitflow, branch from develop)
- **Acceptance Criteria:**
  1. Settings API has write-time validators for invalid data
  2. Repo writers reject invalid writes before persistence
  3. Validators are tested with full coverage
  4. Invalid data scenarios are documented

## Workflow Tracking
**Workflow:** tdd
**Phase:** setup
**Phase Started:** 2026-03-18T11:40:21Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-18T11:40:21Z | - | - |

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

No deviations yet.
