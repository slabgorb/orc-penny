---
parent: context-epic-44.md
workflow: tdd
---

# Story 44-2: Implement Krippendorff Alpha calculation

## Business Context

Inter-rater agreement metrics are the core scientific contribution of the multi-judge system. Without them, multiple judges are just "more opinions" — with them, we can quantify measurement reliability and identify which rubric dimensions need improvement. Krippendorff's Alpha (interval scale) measures agreement beyond chance; Cronbach's Alpha measures internal consistency. Per-dimension reporting reveals whether disagreement is global or concentrated on specific dimensions (e.g., judges agree on correctness but disagree on persona adherence).

## Technical Guardrails

**Key files to create/modify:**
- `packages/core/src/benchmark/agreement.ts` (new) — Krippendorff's Alpha and Cronbach's Alpha implementations
- `packages/core/src/benchmark/index.ts` — Export new functions
- `packages/core/src/benchmark/job-fair-aggregator.ts` — Integrate agreement reporting into aggregation

**Patterns to follow:**
- Return result objects `{success, data?, error?}` — don't throw
- Use `.js` extensions in relative TypeScript imports
- Functions are pure: take number arrays, return alpha values
- No external dependencies (numpy equivalent) — implement from scratch using the standard formulas

**Key formulas:**
- Krippendorff's Alpha: `α = 1 - (D_observed / D_expected)` with squared difference metric for interval data
- Cronbach's Alpha: `α = (k/(k-1)) * (1 - Σvar_i / var_total)` where k = number of dimensions

**Integration points:**
- Consumes judge verdict arrays from 44-1
- Agreement metrics feed into 44-3 (finalize-run) and 44-4 (validation test)

**Do NOT:**
- Import external statistics libraries — implement the formulas directly
- Modify the judge or solo command (that's 44-1)
- Handle storage (that's 44-3)

## Scope Boundaries

**In scope:**
- `calculateKrippendorffAlpha(judges: number[][])` — interval scale
- `calculateCronbachAlpha(judges: number[][])` — internal consistency
- Per-dimension agreement (correctness, depth, quality, persona)
- Overall agreement across all dimensions
- Interpretation thresholds with classification labels
- Flagging unreliable dimensions with revision recommendations
- Comprehensive unit tests with known matrices

**Out of scope:**
- Fleiss' kappa (categorical, not appropriate for our ordinal/interval scores)
- McDonald's omega (future enhancement)
- Gwet's AC2 (future enhancement for skewed distributions)
- Integration with judge invocation (44-1)
- Storage format changes (44-3)

## AC Context

**AC: `calculateKrippendorffAlpha(judges: number[][])` function in benchmark module**
- Input: 2D array where rows = items (scenarios/dimensions), columns = judges
- Output: `{alpha: number, classification: string, reliable: boolean}`
- Test with known matrices from Krippendorff (2011) — expected values within 0.01

**AC: `calculateCronbachAlpha(judges: number[][])` function in benchmark module**
- Input: 2D array where rows = items, columns = judges
- Output: `{alpha: number, classification: string}`
- Test: Perfect agreement → α = 1.0; random data → α ≈ 0

**AC: Agreement calculated per dimension AND overall**
- Input: Array of judge verdicts with dimension scores
- Output: `{overall: AlphaResult, dimensions: {correctness: AlphaResult, depth: AlphaResult, ...}}`
- Test: Construct case where judges agree on correctness (α > 0.8) but disagree on persona (α < 0.5)

**AC: Interpretation thresholds**
- α >= 0.80 → "reliable" (green)
- 0.67 <= α < 0.80 → "acceptable" (yellow)
- α < 0.67 → "unreliable" (red, flagged)
- Test: Verify boundary values classify correctly (0.67 = acceptable, 0.6699 = unreliable)

**AC: Unreliable dimensions flagged with recommendation**
- Any dimension with α < 0.67 gets `flagged: true` and `recommendation: "Revise rubric anchors for {dimension}"`
- Test: Verify flag set and recommendation string includes dimension name

**AC: Unit tests with known agreement matrices**
- Perfect agreement: all judges give identical scores → α = 1.0
- Zero/no agreement: random scores → α ≈ 0 (within 0.1)
- Moderate agreement: partially correlated scores → α ≈ 0.5-0.7
- Edge: 2 judges (minimum), 5 judges (maximum expected)
- Edge: single item (degenerate case, should return undefined/NaN with warning)

**AC: Functions exported from `packages/core/src/benchmark/index.ts`**
- Verify imports work: `import { calculateKrippendorffAlpha, calculateCronbachAlpha } from '@pennyfarthing/core/benchmark'`
