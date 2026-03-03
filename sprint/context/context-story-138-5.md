---
parent: context-epic-138.md
workflow: trivial
---

# Story 138-5: Add simplify team block to tdd and tdd-tandem workflow YAMLs

## Business Context

Epic 138 integrates three specialized Haiku teammates (simplify-reuse, simplify-quality, simplify-efficiency) into the verify phase of TDD workflows. This story adds the `team:` block configuration to both `tdd.yaml` and `tdd-tandem.yaml` to activate the simplify teammates during the verify phase when TEA runs quality checks. This configuration enables parallel quality review across three dimensions (code reuse, readability, efficiency) while preserving the existing quality-pass gate as a regression safety net.

## Technical Guardrails

**Workflow YAML team block schema:**
- Each workflow verify phase contains a single `team:` block with a `teammates:` list
- Each teammate has `agent:` (agent ID) and `task:` (human-readable instruction string)
- The three simplify agents must exist as definitions in `pennyfarthing-dist/agents/`
- No changes to gate definitions, phase inputs/outputs, or trigger conditions
- No schema changes to the workflow YAML format — this is a standard team block addition per tandem protocol

**Agent dependencies:**
- Story depends on 138-1, 138-2, 138-3 (agent definitions for simplify-reuse, simplify-quality, simplify-efficiency)
- Task descriptions must match the fan-out/fan-in pattern: isolated, parallel review with "Report findings only" scope

**File structure:**
- `tdd.yaml` verify phase currently has no team block; add one with three teammates
- `tdd-tandem.yaml` verify phase already has architect teammate; add simplify teammates to the same team block

## Scope Boundaries

**In scope:**
- Add `team:` block with three simplify teammates to verify phase in `tdd.yaml`
- Add simplify teammates to existing `team:` block in verify phase of `tdd-tandem.yaml` (alongside architect)
- Exact task descriptions from PRD FR-3

**Out of scope:**
- Creating or modifying agent definitions (138-1, 138-2, 138-3 handle that)
- Modifying other workflow phases (red, green, review, finish)
- Modifying trivial, bdd, or other workflows — those are Growth phase stories
- Changes to quality-pass gate or any gate definitions

## AC Context

**Testable detail:**

1. `tdd.yaml` verify phase contains:
   ```yaml
   team:
     teammates:
       - agent: simplify-reuse
         task: "Review changed files for code duplication and extraction opportunities. Report findings only."
       - agent: simplify-quality
         task: "Review changed files for naming, readability, and structural quality. Report findings only."
       - agent: simplify-efficiency
         task: "Review changed files for unnecessary complexity and over-engineering. Report findings only."
   ```

2. `tdd-tandem.yaml` verify phase contains the same `team:` block (merged with existing architect teammate in the same block)

3. Workflow YAML parses without errors (validate against workflow schema)

4. Both files retain all existing phase structure, gates, and trigger conditions unchanged
