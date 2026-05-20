---
parent: context-epic-45.md
workflow: tdd
---

# Story 45-4: Variance comparison — with/without gold standard

## Business Context

Validation story measuring whether gold standard calibration actually reduces judge scoring variance. Run the same 5 scenarios with and without gold standards, compare CV. If gold standards don't reduce variance, the approach needs revision before broader rollout.

## Technical Guardrails

**Key files:**
- 5 scenarios from 45-3 with gold standards
- Existing baseline data (without gold standards)

**Patterns to follow:**
- Same methodology as 42-3 (CV comparison)
- Use same agents and run counts for apples-to-apples comparison
- If multi-judge is available (PROJ-16214), use it for richer agreement data

**Do NOT:**
- Modify any code — measurement/validation only
- Compare different scenarios or agents pre/post

## Scope Boundaries

**In scope:**
- Re-run 5 scenarios with gold standard calibration active
- CV comparison: with gold standard vs without
- Per-dimension analysis if data supports it
- Report with findings and recommendations

**Out of scope:**
- Code changes
- Gold standard revision based on results (future iteration)

## AC Context

**AC: CV comparison with and without gold standard**
- Per-scenario table showing CV before and after gold standard introduction
- Overall summary: average CV reduction across 5 scenarios
- Test: Report contains numeric comparison for all 5 scenarios

**AC: Recommendations**
- Does gold standard reduce variance? By how much?
- Which scenarios benefit most?
- Should gold standards be required for all scenarios or only high-variance ones?
