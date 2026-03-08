# Story 47-7: A/B Pipeline Run — Good Context vs No Context

## Overview

The definitive experiment: run the full TDD pipeline on dpgd-116 with the best PM/Architect context versus no strategic context at all. Measures the end-to-end causal impact of strategic role personas on pipeline detection rates.

**Points:** 5 | **Workflow:** tdd | **Jira:** MSSCI-16300
**Priority:** P2 — only pursue if 47-5/47-6 show signal

## Objective

Current pipeline-replay runs use no strategic context — agents receive only the scenario code and their role definition. This experiment adds PM-generated epic context and Architect-generated story context to see if it changes outcomes.

## Approach

### Conditions

| Condition | Context Provided | Runs |
|-----------|-----------------|------|
| `baseline` | None (current default) | 4 (use existing dpgd-116 results) |
| `best-context` | Best PM + Architect context (from 47-5) | 4 (new runs) |
| `worst-context` | Worst-scoring context (from 47-5) | 2 (if budget allows) |

### Implementation

1. Modify pipeline-replay to accept optional context documents
2. Inject context into agent prompts at session start
3. Run 4 replays with context for the best theme
4. Compare detection rates against existing baseline

### Statistical Analysis

- Mean score difference with 95% CI
- Cohen's d effect size (threshold: d > 0.5 for practical significance)
- Per-finding analysis: which defects are context-sensitive?
- Phase attribution: does context help TEA, Dev, or Reviewer most?

## Acceptance Criteria

- [ ] Pipeline-replay supports optional context injection
- [ ] 4 runs completed with best context
- [ ] Statistical comparison with baseline (Cohen's d, CI)
- [ ] Finding-level analysis: which defects benefit from context?
- [ ] Results in `internal/results/ab-context-dpgd-116.md`
- [ ] Dashboard updated to show A/B comparison

## Dependencies

- 47-5 (best/worst context selection)
- 47-6 (ablation results inform which context sections to include)
- Pipeline replay infrastructure (may need context injection feature)
