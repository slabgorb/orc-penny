---
parent: context-epic-43.md
workflow: tdd
---

# Story 43-1: Add red_herrings schema to scenarios

## Business Context

Benchmark scenarios currently contain only genuine issues, which inflates scores for agents that flag everything indiscriminately. Adding a `red_herrings` field to the scenario schema lets scenario authors embed deliberate distractors. This structural change enables precision measurement — does the agent distinguish real issues from noise?

## Technical Guardrails

**Key files to modify:**
- Scenario YAML schema definition — add `red_herrings` array field
- Schema validation logic — validate red herring entries

**Schema design:**
```yaml
red_herrings:
  - description: "Unused import that's actually used via reflection"
    location: "line 12"
    trap_type: "false-unused"
```

**Patterns to follow:**
- Red herrings are optional (empty array or omitted = no red herrings, backward compatible)
- Each red herring has: description, location, trap_type
- `trap_type` is freeform string (not enum) to allow scenario-specific categories

**Do NOT:**
- Add red herrings to any actual scenarios yet (that's 43-3)
- Modify the judge (that's 43-2)

## Scope Boundaries

**In scope:**
- `red_herrings` array field in scenario YAML schema
- Schema validation for red herring entries (description required, location required, trap_type required)
- Backward compatibility — scenarios without red_herrings field remain valid

**Out of scope:**
- Judge changes for precision scoring (43-2)
- Adding red herrings to actual scenarios (43-3)

## AC Context

**AC: Schema accepts red_herrings array**
- Test: Scenario YAML with `red_herrings` field validates successfully
- Test: Scenario YAML without `red_herrings` field still validates (backward compat)
- Test: Red herring entry missing `description` → validation error

**AC: Each entry has required fields**
- `description`: string, required — what the red herring is
- `location`: string, required — where in the code/scenario
- `trap_type`: string, required — category of false positive
- Test: Entry with all three fields → valid; missing any one → invalid
