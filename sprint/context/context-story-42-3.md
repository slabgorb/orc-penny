---
parent: context-epic-42.md
workflow: tdd
---

# Story 42-3: Variance test — measure CV reduction

## Business Context

This validation story measures whether anchored rubrics actually reduce scoring variance. Run the same scenarios before and after anchoring, compare coefficient of variation (CV). If CV doesn't decrease, the anchors need revision. This provides empirical evidence for the anchor design quality.

## Technical Guardrails

**Key files:**
- Existing baseline results in `internal/results/benchmarks/` — pre-anchor scores
- New runs with anchored judge — post-anchor scores

**Patterns to follow:**
- Use same scenarios and agents as existing baselines for apples-to-apples comparison
- CV = std_dev / mean — lower CV = more consistent scoring
- Report per-dimension CV, not just overall

**Do NOT:**
- Modify any code — this is a measurement/validation story
- Change scenarios or agents between pre/post comparison

## Scope Boundaries

**In scope:**
- Select 5+ scenarios with existing baseline data
- Re-run with anchored judge prompt (from 42-2)
- Calculate CV before and after for each dimension
- Report: which dimensions improved, which didn't, by how much

**Out of scope:**
- Revising anchors based on results (future iteration)
- Running on all scenarios (sample of 5+ is sufficient)

## AC Context

**AC: CV comparison before and after anchoring**
- Per-dimension CV table: correctness, depth, quality, persona
- Pre-anchor CV from existing baselines, post-anchor CV from new runs
- Test: Report shows clear before/after comparison with percentage change

**AC: Statistical significance**
- With small N (3-4 runs per scenario), note confidence limitations
- Report raw numbers rather than claiming significance with insufficient data
- Test: Report includes sample size caveat
