# Story 47-3: Run 3 PM Personas Through Epic Context for dpgd-116

## Overview

Generate epic context documents using 3 different PM personas for the dpgd-116 scenario. Compare the output to measure whether PM persona choice affects the quality and coverage of strategic planning artifacts.

**Points:** 3 | **Workflow:** tdd | **Jira:** PROJ-16296

## Objective

Use the `/pf-context` skill to generate epic context documents as if dpgd-116 were a real story. Run 3 themes with contrasting PM personas to maximize differentiation signal.

## Theme Selection

Choose 3 themes that vary on dimensions likely to affect PM behavior:

| Theme | PM Character | Scrutiny | Intellectual Style | Why |
|-------|-------------|----------|-------------------|-----|
| West Wing | CJ Cregg | professional | analytical | High-structure, formal planning |
| Game of Thrones | Cersei/Varys | adversarial | strategic | Paranoid, risk-focused |
| Firefly | ? | trusting | improvisational | Casual, adaptive planning |

These span the scrutiny axis (professional → adversarial → trusting) and intellectual style (analytical → strategic → improvisational).

## Approach

1. Set theme to each of the 3 themes
2. Generate epic context for dpgd-116 scenario using the PM persona
3. Save output to `internal/results/pm-context/dpgd-116/{theme}/epic-context.md`
4. Score each context against the concern manifest (47-2)

## Key Files

| File | Purpose |
|------|---------|
| `internal/results/manifests/dpgd-116-concern-manifest.yaml` | Scoring rubric (from 47-2) |
| `/pf-context` skill | Context generation |
| `pennyfarthing-dist/personas/themes/{theme}.yaml` | PM persona definitions |

## Acceptance Criteria

- [ ] 3 epic context documents generated (one per theme)
- [ ] Each scored against concern manifest: concerns hit / concerns missed / false concerns
- [ ] Qualitative comparison: how does PM voice affect content?
- [ ] Results summary in `internal/results/pm-context/dpgd-116/comparison.md`

## Dependencies

- 47-2 (concern manifest) — needed for scoring
