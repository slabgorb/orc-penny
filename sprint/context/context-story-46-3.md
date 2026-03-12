---
parent: context-epic-46.md
workflow: tdd
---

# Story 46-3: Update schema.yaml with new fields documentation

## Business Context

The difficulty_profile, red_herrings, and gold_standard schema extensions from this sprint's benchmark epics need documentation in the schema reference. Scenario authors need to know what fields are available, what they mean, and how to use them. Without docs, the fields won't be adopted.

## Technical Guardrails

**Key files to modify:**
- `pennyfarthing-dist/schemas/` — scenario schema documentation

**Patterns to follow:**
- Document all new fields: difficulty_profile (46-1), red_herrings (43-1), gold_standard (45-1)
- Include field types, required/optional status, validation rules, and examples
- Follow existing schema documentation format

**Do NOT:**
- Change the actual schema validation logic (already done in respective stories)
- Document internal implementation details

## Scope Boundaries

**In scope:**
- Schema documentation for difficulty_profile, red_herrings, gold_standard fields
- Examples showing each field in context
- Cross-references to relevant epic context docs

**Out of scope:**
- Schema validation changes (done in 46-1, 43-1, 45-1)
- User-facing tutorial content

## AC Context

**AC: All three new fields documented**
- difficulty_profile: tier enum, dimension scales, calibration section
- red_herrings: array structure, required fields per entry
- gold_standard: response, score, notes
- Test: Each field has type, required status, validation rules, and at least one example

**AC: Documentation follows existing format**
- Test: New field docs match style and structure of existing schema docs
- Test: Examples are valid YAML that would pass schema validation
