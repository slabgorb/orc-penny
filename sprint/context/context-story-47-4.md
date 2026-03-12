# Story 47-4: Run 3 Architect Personas Through Story Context for dpgd-116

## Overview

Generate story context documents using 3 different Architect personas for dpgd-116. Measures whether Architect persona choice affects architectural risk identification and technical guidance quality.

**Points:** 3 | **Workflow:** tdd | **Jira:** MSSCI-16297

## Objective

The Architect produces story context that includes architectural decisions, component boundaries, risk areas, and technical constraints. Different personas may surface different risks based on their intellectual style and scrutiny level.

## Theme Selection

Use the same 3 themes as 47-3 for consistency, evaluating the Architect role:

| Theme | Architect Character | Authority Model | Formality | Why |
|-------|-------------------|----------------|-----------|-----|
| West Wing | Will Bailey | hierarchical | formal | Structured, process-heavy architecture |
| Game of Thrones | ? | feudal | ceremonial | Power-aware, defensive architecture |
| Firefly | ? | egalitarian | casual | Pragmatic, ship-it architecture |

## Approach

1. Set theme to each of the 3 themes
2. Generate story context for dpgd-116 using the Architect persona
3. Save to `internal/results/architect-context/dpgd-116/{theme}/story-context.md`
4. Score against AC manifest (47-2) — does the Architect's guidance lead to ACs that would catch the defects?

## Acceptance Criteria

- [ ] 3 story context documents generated (one per theme)
- [ ] Each scored against AC manifest: ACs addressed / ACs missed / novel risks surfaced
- [ ] Comparison of architectural risk identification across personas
- [ ] Results summary in `internal/results/architect-context/dpgd-116/comparison.md`

## Dependencies

- 47-2 (AC manifest) — needed for scoring
