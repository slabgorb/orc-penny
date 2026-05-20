# Story 47-6: Context Ablation Experiment — Remove Sections, Measure Delta

## Overview

Systematically remove sections from context documents and re-run the pipeline to measure which sections actually affect downstream defect detection. Tests whether strategic context has causal impact or is just noise.

**Points:** 3 | **Workflow:** tdd | **Jira:** PROJ-16299
**Priority:** P2 — only pursue if 47-5 shows signal

## Objective

The irrelevant detail sensitivity research [15] shows 14-59% task variance from logically irrelevant persona attributes. This experiment applies that principle to context documents: which sections of PM/Architect output actually affect TEA/Dev/Reviewer performance?

## Approach

### Ablation Conditions

Starting from the best-scoring context doc (from 47-5), create variants:

| Variant | What's Removed | Hypothesis |
|---------|---------------|------------|
| `full` | Nothing (baseline) | Best performance |
| `no-risks` | Risk/concern sections | Lower detection of subtle issues |
| `no-arch` | Architecture decisions | Lower structural issue detection |
| `no-domain` | Domain background | Minimal effect (noise section) |
| `no-acs` | Acceptance criteria | Lower reviewer catch rate |
| `minimal` | Everything except story title + description | Matches control |

### Pipeline Runs

For each variant, run `pf benchmark replay run dpgd-116 --theme {best-theme}` once. Compare scores.

### Measurement

- Delta from full baseline for each variant
- Which sections, when removed, cause the largest score drop?
- Does any removal actually *improve* scores (suggesting noise)?

## Acceptance Criteria

- [ ] 6 pipeline runs (one per variant) completed
- [ ] Score comparison table with deltas from baseline
- [ ] Identification of high-impact and low-impact context sections
- [ ] Results in `internal/results/context-ablation-dpgd-116.md`

## Dependencies

- 47-5 (go/no-go decision + best context doc selection)
- Pipeline replay infrastructure (complete)
