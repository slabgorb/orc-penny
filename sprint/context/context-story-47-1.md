# Story 47-1: Cascade Attribution on dpgd-116 Existing Results

## Overview

Analyze existing dpgd-116 pipeline-replay results to trace defect catches back to upstream context signals. No new pipeline runs — this is pure analysis of the 20 themes × 4 runs already completed.

**Points:** 2 | **Workflow:** trivial | **Jira:** MSSCI-16294

## Objective

For each caught finding in dpgd-116, determine: what information in the agent's context enabled the catch? Was it the scenario code itself (any agent would catch it), the agent definition (role-specific expertise), or the persona (character-specific perspective)?

## Approach

1. Read all `score.yaml` files across 20 themes for dpgd-116
2. For each finding × theme × run, examine the `evidence` field
3. Classify each catch into attribution categories:
   - **Code-obvious**: Defect visible from code alone (e.g., missing error handling)
   - **Role-driven**: Agent role expertise surfaced it (e.g., reviewer's security focus)
   - **Persona-driven**: Character voice or personality contributed (e.g., adversarial scrutiny)
   - **Context-driven**: Upstream context doc mentioned the concern area
4. Tabulate: which themes show persona-driven or context-driven catches?

## Key Files

| File | Purpose |
|------|---------|
| `internal/results/pipeline-replay/dpgd-116/*/run-*/score.yaml` | Evidence fields for each finding |
| `internal/results/pipeline-replay/dpgd-116/comparison.yaml` | Aggregated results across themes |
| `internal/results/benchmark-dashboard.html` | Visualization of phase attribution |

## Acceptance Criteria

- [ ] Attribution table covering all 7 findings × 20 themes
- [ ] Summary: what percentage of catches appear persona/context-driven vs code-obvious
- [ ] Signal assessment: is there enough variance to justify 47-3 through 47-7?
- [ ] Results written to `internal/results/cascade-attribution-dpgd-116.md`

## Dependencies

- dpgd-116 results (complete)
