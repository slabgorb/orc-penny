# Epic 92: 2pTDD Workflow and Review/PR Lifecycle

**Jira:** PROJ-14580
**Status:** backlog
**Priority:** P1
**Marker:** infrastructure

## Overview

Epic 92 implements a new 2party-TDD workflow with comprehensive story refinement, review rejection loops, PR lifecycle management via pr_mode config, and updates to agent definitions. This epic touches workflow YAMLs, the BikeLane engine, agent definitions, and the configuration system.

## Key Objectives

1. **Prototype Workflow Definition** — Finalize the existing 2party-tdd.yaml v2.0.0 with refinement phases, review rejection loops, PR policy, and instructions blocks
2. **Port Changes to Standard tdd.yaml** — Apply review rejection loop and PR lifecycle patterns to the baseline tdd.yaml workflow
3. **Configuration System** — Add pr_mode user preference for controlling PR draft/ready/push-only behavior
4. **Agent Definition Updates** — Update reviewer, dev, and sm agent definitions to reflect new PR/review lifecycle roles
5. **BikeLane Engine Enhancements** — Support next directive, workflow_phase override, and review fields needed for runtime review rejection loops
6. **Quality Gate Implementation** — Add quality_pass gate type to run all configured quality checks before review acceptance

## Stories

| ID | Jira | Title | Points | Priority |
|---|---|---|---|---|
| 92-1 | PROJ-14580 | 2party-tdd.yaml workflow definition (v2.0.0) | 2 | P0 |
| 92-2 | PROJ-14582 | Apply review rejection loop and PR policy to tdd.yaml | 3 | P0 |
| 92-3 | PROJ-14583 | Implement pr_mode user preference in pennyfarthing config | 3 | P0 |
| 92-4 | PROJ-14584 | Update agent definitions: reviewer, dev, sm for new PR/review lifecycle | 2 | P0 |
| 92-5 | PROJ-14585 | BikeLane engine: support next directive, workflow_phase override, review fields | 5 | P1 |
| 92-6 | PROJ-14588 | BikeLane gate type: quality_pass — run all project quality checks | 3 | P0 |

## Technical Context

### Workflow Files
- **Primary:** `pennyfarthing-dist/workflows/2party-tdd.yaml` — prototype already at v2.0.0
- **Reference:** `pennyfarthing-dist/workflows/tdd.yaml` — baseline TDD workflow to be updated
- **Pattern:** Other workflows in `pennyfarthing-dist/workflows/` for structural reference

### Agent Definitions
- **Affected:** `pennyfarthing-dist/agents/reviewer.md`, `pennyfarthing-dist/agents/dev.md`, `pennyfarthing-dist/agents/sm.md`
- **Changes:** PR/review lifecycle responsibilities, rejection routing logic

### BikeLane Engine
- **Location:** Within pennyfarthing framework
- **Gaps to address:**
  - Support for `next:` directive to enable non-linear phase progression (review rejection loops)
  - `workflow_phase` override capability for agents to redirect execution
  - Sprint YAML schema extensions for `review_findings`, `review_verdict` fields

### Configuration System
- **File:** `.pennyfarthing/config.yaml`
- **New key:** `pr_mode` with values: `draft` (default), `ready`, `none`
- **Consumers:** `gh-pr-manage` skill, agent implementations using `gh pr create`

## Acceptance Criteria (Epic Level)

- [ ] 2party-tdd.yaml workflow definition is finalized and validates with BikeLane parser
- [ ] tdd.yaml includes review rejection loop and PR policy patterns
- [ ] pr_mode configuration is implemented and consumed by agent skills
- [ ] Agent definitions (reviewer, dev, sm) reflect new PR/review lifecycle
- [ ] BikeLane engine supports next directive and workflow_phase override
- [ ] quality_pass gate type is implemented and functional
- [ ] All story tests pass
- [ ] Framework builds without warnings

## Related Epics & Stories

- **Epic 101** (Workflow Protocol Standardization) — Related workflow improvements
- **Cyclist BikeRack** — Visual workflow panel for validating definitions
- **Prime system** — Agent bootstrapping with workflow context

## Notes

- This is Phase 1 of a larger workflow evolution
- Quality gate Phase 2 (auto-discovery) is deferred
- The 2party-tdd prototype has been actively iterated on and is ready for finalization
- BikeLane engine support is the critical blocker for runtime validation
