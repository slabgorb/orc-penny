---
parent: context-epic-44.md
workflow: tdd
---

# Story 44-3: Update finalize-run for multi-judge storage

## Business Context

Finalize-run is the single guardrail exit point for all benchmark results. It validates data integrity before storage, ensuring no corrupted or incomplete results enter the results directory. This story extends that validation to handle judge arrays (multi-judge) while maintaining backward compatibility with existing single-judge results. Without this, multi-judge results can't be stored or compared historically.

## Technical Guardrails

**Key files to modify:**
- `pennyfarthing-dist/skills/pf-finalize-run/SKILL.md` — Add multi-judge validation rules and storage format

**Patterns to follow:**
- Existing finalize-run validation: timestamp, response length, token counts, score extraction
- Apply all existing validation rules to EACH judge verdict independently
- Agreement metrics are informational warnings, not blockers — low alpha prints warning but doesn't prevent storage
- Summary YAML `statistics.mean` must use aggregated judge means for multi-judge runs

**Integration points:**
- Depends on 44-1 (judge array format) and 44-2 (agreement metrics)
- Consumed by all downstream analysis: `/benchmark` comparisons, JobFair aggregation

**Storage format:**
```
runs/
├── run_1.json          # Agent response
├── judge_1_0.json      # Judge 0 verdict
├── judge_1_1.json      # Judge 1 verdict
├── judge_1_2.json      # Judge 2 verdict
```

**Do NOT:**
- Break backward compatibility with single-judge results
- Block storage on low agreement (warn only)
- Change the summary YAML schema for single-judge runs

## Scope Boundaries

**In scope:**
- Validation of judge arrays (each verdict validated independently)
- Agreement metric inclusion in saved results
- Low-agreement warning (α < 0.67) as non-blocking console output
- Summary YAML `statistics.mean` uses aggregated means for multi-judge
- Backward compatibility with single-judge format

**Out of scope:**
- Judge invocation logic (44-1)
- Agreement calculation logic (44-2)
- Historical result migration (existing single-judge results stay as-is)

## AC Context

**AC: Finalize-run accepts both single judge (legacy) and judge array (multi-judge) formats**
- Detection: if input has `judges[]` array → multi-judge path; if single verdict → legacy path
- Test: Submit single-judge result → validates and stores as before (no regression)
- Test: Submit multi-judge result with 3 verdicts → validates each and stores with agreement metrics

**AC: Each judge verdict validated independently**
- Apply existing rules: timestamp present and valid ISO8601, response_text non-empty, token counts > 0, score in valid range
- Test: Multi-judge with one invalid verdict (missing timestamp) → REJECT entire run
- Test: Multi-judge with all valid verdicts → ACCEPT

**AC: Agreement metric included in saved results**
- Summary YAML gets `multi_judge:` section with alpha_mean, alpha_min, alpha_max, classification
- Test: Verify saved summary.yaml contains agreement data matching calculated values

**AC: Low-agreement warning (α < 0.67) printed but does not block storage**
- Console output: "WARNING: Low inter-judge agreement (α=0.52) on dimension 'persona'. Consider revising rubric anchors."
- Test: Submit run with α < 0.67 → warning printed AND result stored successfully
- Test: Submit run with α >= 0.67 → no warning, result stored

**AC: Summary YAML statistics.mean uses aggregated judge means**
- For multi-judge: mean = average of (mean of each judge's weighted_total per run)
- Test: 3 judges score [78, 82, 75] → run mean = 78.33; statistics.mean reflects this
- Test: Single-judge results → statistics.mean unchanged from current behavior

**AC: Existing single-judge results remain loadable and comparable**
- Test: Load old single-judge summary.yaml → all fields accessible, no errors
- Test: Compare single-judge result against multi-judge result in `/benchmark` → delta computed correctly
