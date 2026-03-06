---
parent: context-epic-46.md
workflow: tdd
---

# Story 46-1: Add difficulty_profile schema to scenarios

## Business Context

Without difficulty metadata, benchmark results conflate easy and hard scenarios in aggregate statistics. A mean score of 75 across easy scenarios is very different from 75 across hard ones. This story adds a `difficulty_profile` field to scenario YAML, enabling stratified analysis. Critical for testing context collapse (do personas drop under cognitive load?) and calibrating expectations by difficulty tier.

## Technical Guardrails

**Key files to modify:**
- Scenario YAML schema definition — add `difficulty_profile` object field

**Schema design:**
```yaml
difficulty_profile:
  tier: medium
  dimensions:
    code_complexity: 6
    domain_knowledge: 4
    red_herring_count: 2
    issue_subtlety: 5
  calibration:
    control_mean: 72.5
    control_stddev: 8.3
    n_runs: 4
```

**Patterns to follow:**
- `difficulty_profile` is optional (backward compatible)
- `tier` is enum: easy, medium, hard, extreme
- `dimensions` are all optional numeric 1-10 scales
- `calibration` is populated from baseline data (46-2), can be empty initially

**Do NOT:**
- Populate profiles for actual scenarios (that's 46-2)
- Document the schema externally (that's 46-3)

## Scope Boundaries

**In scope:**
- `difficulty_profile` object field in scenario YAML schema
- Validation: tier enum, dimension values 1-10, calibration fields numeric
- Backward compatibility

**Out of scope:**
- Populating profiles (46-2)
- Schema documentation (46-3)

## AC Context

**AC: Schema accepts difficulty_profile**
- Test: Scenario with difficulty_profile validates
- Test: Scenario without it still validates
- Test: Invalid tier value (e.g., "impossible") → validation error
- Test: Dimension value outside 1-10 → validation error
- Test: Partial profile (tier only, no dimensions) → valid
