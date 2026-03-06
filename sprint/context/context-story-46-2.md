---
parent: context-epic-46.md
workflow: tdd
---

# Story 46-2: Populate difficulty profiles from baseline data

## Business Context

Rather than manually guessing difficulty, this story derives difficulty profiles empirically from existing control baseline data. Scenarios where control agents score high are "easy"; scenarios with low means or high variance are "hard." This data-driven approach produces accurate, defensible tier assignments.

## Technical Guardrails

**Key files to modify:**
- All scenario YAML files with existing baseline data

**Tier assignment algorithm:**
```
easy:    control_mean >= 80, control_stddev < 8
medium:  control_mean 65-79, control_stddev < 12
hard:    control_mean 50-64 OR control_stddev >= 12
extreme: control_mean < 50
```

**Data source:**
- Existing results in `internal/results/benchmarks/` for control agent runs
- Extract mean and std_dev per scenario

**Patterns to follow:**
- Populate calibration section from actual data (control_mean, control_stddev, n_runs)
- Assign tier using algorithm above
- Dimension scores (code_complexity, domain_knowledge, etc.) require human judgment — populate what's obvious, leave others for future iteration

**Do NOT:**
- Change scenario content
- Invent calibration data — only use actual baseline results

## Scope Boundaries

**In scope:**
- Extract control baseline statistics for all scenarios with existing data
- Assign tiers using the algorithm
- Populate calibration section (control_mean, control_stddev, n_runs)
- Best-effort dimension scores where obvious

**Out of scope:**
- Scenarios without baseline data (need control runs first)
- Running new control baselines
- Schema documentation (46-3)

## AC Context

**AC: All scenarios with baseline data get difficulty profiles**
- Test: Every scenario YAML that has control results in internal/results/ gets a difficulty_profile
- Test: Tier assignments match algorithm output

**AC: Calibration section populated from real data**
- Test: control_mean and control_stddev match actual values from baseline results
- Test: n_runs matches actual run count

**AC: Tier assignments are defensible**
- Test: Easy scenarios have high control means; hard scenarios have low means or high variance
- Document any edge cases or manual overrides with reasoning
