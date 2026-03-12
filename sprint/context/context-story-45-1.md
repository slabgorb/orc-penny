---
parent: context-epic-45.md
workflow: tdd
---

# Story 45-1: Add gold_standard schema to scenarios

## Business Context

Gold standards provide calibration anchors for judge scoring. Without a reference point, judges drift between invocations. This story adds the `gold_standard` field to scenario YAML, enabling scenario authors to include curated expert responses that judges use as scoring benchmarks. Structural change only — no judge modifications.

## Technical Guardrails

**Key files to modify:**
- Scenario YAML schema definition — add `gold_standard` object field

**Schema design:**
```yaml
gold_standard:
  response: |
    [curated expert response text]
  score: 92
  notes: "Identifies race condition, suggests mutex pattern, covers edge cases"
```

**Patterns to follow:**
- Gold standard is optional (omitted = no calibration anchor, backward compatible)
- `response` is the full expert response text
- `score` is the expected score (what this response should get under the rubric)
- `notes` explains why this is the gold standard

**Do NOT:**
- Modify the judge prompt (that's 45-2)
- Create actual gold standard responses (that's 45-3)

## Scope Boundaries

**In scope:**
- `gold_standard` object field in scenario YAML schema
- Schema validation: response (string, required if gold_standard present), score (number 1-100, required), notes (string, optional)
- Backward compatibility — scenarios without gold_standard remain valid

**Out of scope:**
- Judge prompt changes (45-2)
- Writing gold standard responses (45-3)
- Variance comparison (45-4)

## AC Context

**AC: Schema accepts gold_standard object**
- Test: Scenario with gold_standard field validates
- Test: Scenario without gold_standard still validates
- Test: gold_standard with missing `response` → validation error
- Test: gold_standard with `score` outside 1-100 → validation error
