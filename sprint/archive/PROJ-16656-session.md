---
story_id: "150-21"
jira_key: "PROJ-16656"
epic: "PROJ-16564"
workflow: "tdd"
---
# Story 150-21: Remove hardcoded PROJ/1898 defaults from framework — configurable Jira project and URL

## Story Details
- **ID:** 150-21
- **Jira Key:** PROJ-16656
- **Workflow:** tdd
- **Stack Parent:** none
- **Assigned To:** slabgorb@gmail.com

## Context
This story removes hardcoded company-specific Jira configuration from the pennyfarthing framework, making it open-sourceable. The framework currently defaults to PROJ project key and slabgorb.atlassian.net Jira URL, which should be user-configurable instead.

### Acceptance Criteria
1. `settings.py` DEFAULTS has empty/null Jira project and URL (no company-specific defaults)
2. `pf init` prompts for Jira project key and URL during setup (or skips if user declines)
3. Jira CLI commands gracefully handle missing config (error message, not crash)
4. Project setup workflow step-09 uses configured values, not hardcoded 1898
5. GitHub URLs in documentation replaced with placeholder (e.g., github.com/your-org/pennyfarthing)
6. Existing tests updated to not depend on PROJ as default

## Workflow Tracking
**Workflow:** tdd
**Phase:** setup
**Phase Started:** 2026-03-21T00:00:00Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-21 | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

No upstream findings

## Sm Assessment

**Story:** 150-21 — Remove hardcoded PROJ/1898 defaults
**Workflow:** TDD (3 pts)
**Repos:** pennyfarthing (targets develop)
**Branch:** feat/150-21-remove-hardcoded-company-refs
**Jira:** PROJ-16656

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->
None yet
