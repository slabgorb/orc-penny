---
parent: context-epic-140.md
workflow: trivial
---

# Story 140-1: Create Batch Workflow YAML

## Business Context

The batch workflow YAML is the foundational definition that enables all parallel batch execution within Pennyfarthing. Without this, the batch feature cannot be invoked, phases cannot be sequenced, gates cannot be evaluated, and agents cannot coordinate. This is the single source of truth that the workflow engine loads to orchestrate decompose → fan-out → review → finish. Everything else in Epic 137 depends on this file existing and conforming to the schema.

## Technical Guardrails

**Key Files:**

- **NEW:** `pennyfarthing/pennyfarthing-dist/workflows/batch-workflow.yaml` — the deliverable
- **REFERENCE:** `pennyfarthing/pennyfarthing-dist/schemas/workflow-schema.md` — validation rules and schema structure
- **REFERENCE:** `pennyfarthing/pennyfarthing-dist/workflows/tdd.yaml` — existing workflow pattern to follow (4 phases, gates, phase outputs/inputs)

**Critical Constraints:**

1. **No schema changes required** — The batch workflow must pass the existing validator without adding new gate types, field structures, or phase properties. The validator is already in place; this story simply adds a new workflow definition that conforms to the existing rules.

2. **Follow existing workflow patterns** — The `tdd.yaml` file demonstrates the expected structure: phase names (setup/decompose/fan-out/review/finish), agent assignments, optional input/output arrays, and gate definitions with type and condition. Match this style and structure.

3. **Workflow schema compliance** — Per the schema:
   - `workflow.name` is required and unique (must be `batch`)
   - `workflow.phases` is required with at least one phase
   - Each phase requires `name` and `agent` fields
   - Gates are optional per-phase but required here for decompose/fan-out/review
   - `output` and `input` arrays are optional but recommended for documenting data flow
   - `triggers` section should include `tags: [batch]` to enable story routing

4. **Version and description** — Include semantic versioning (e.g., `1.0.0`) and a brief description for clarity and future extensibility.

**Reference Architecture from PRD:**

```yaml
workflow:
  name: batch
  phases:
    - name: decompose
      agent: architect
      output: [unit_definitions, independence_check]
      gate:
        type: manual
        condition: Unit boundaries approved
    - name: fan-out
      agent: orchestrator
      input: [unit_definitions]
      output: [unit_results, unit_prs]
      gate:
        type: manual
        condition: All batch units resolved
    - name: review
      agent: reviewer
      input: [unit_results, unit_prs]
      output: [approval]
      gate:
        type: approval
        condition: Batch consistency review approved
    - name: finish
      agent: sm
      input: [approval]
      output: [archived_session]
```

## Scope Boundaries

**In scope:**

- Create `pennyfarthing/pennyfarthing-dist/workflows/batch-workflow.yaml` with 4 phases: decompose (architect), fan-out (orchestrator), review (reviewer), finish (sm)
- Define gates: manual on decompose, manual on fan-out, approval on review
- Include triggers section with `tags: [batch]` for story routing
- Include descriptive phase `output` and `input` arrays to document data flow
- Verify the file passes the existing workflow validator without errors
- Ensure the YAML structure follows the patterns established in `tdd.yaml`

**Out of scope:**

- Modifying the workflow schema itself (schema is fixed)
- Implementing the orchestrator agent definition or batch-specific prompts (story 140-2)
- Creating the session `<units>` XML tracking element (story 140-2)
- Building the session update tooling or file-overlap check (stories 140-3, 138-1)
- Testing the workflow end-to-end; validation only confirms schema compliance

## AC Context

**AC-1: Workflow YAML exists and is well-formed**
- File created at `pennyfarthing/pennyfarthing-dist/workflows/batch-workflow.yaml`
- YAML syntax is valid (can be parsed by `yaml` library without errors)
- Includes all required fields: `workflow.name`, `workflow.phases` with phase names and agents

**AC-2: Conforms to workflow schema without requiring schema changes**
- Run the existing workflow validator against the file (validator location: `pennyfarthing/packages/core/src/validators/workflow-validator.ts` or equivalent Python/JS validator used at startup)
- Validator output: zero errors, zero warnings
- No modifications to the schema itself are needed — the workflow uses only existing gate types (manual, approval) and existing phase structure

**AC-3: Implements the 4-phase batch workflow architecture**
- Phase 1: `decompose` — assigned to `architect` agent, output includes unit_definitions and independence_check
- Phase 2: `fan-out` — assigned to `orchestrator` agent, input from decompose, output includes unit_results and unit_prs
- Phase 3: `review` — assigned to `reviewer` agent, input from fan-out, output is approval
- Phase 4: `finish` — assigned to `sm` agent, input from review, output is archived_session

**AC-4: Gates are correctly configured**
- `decompose` phase has a manual gate with condition "Unit boundaries approved"
- `fan-out` phase has a manual gate with condition "All batch units resolved"
- `review` phase has an approval gate with condition "Batch consistency review approved"
- `finish` phase has no gate (final phase)

**AC-5: Includes triggers for batch story routing**
- `triggers.tags` includes `batch` so stories tagged with `batch` are routed to this workflow
- If appropriate, include `triggers.types` or `triggers.points` based on expected batch story patterns (optional per schema, but recommended for clarity)

**AC-6: Follows existing workflow patterns and style**
- Structure and formatting match `tdd.yaml`
- Phase names are descriptive and align with batch workflow terminology
- Input/output arrays document data flow between phases
- Gate definitions use consistent condition messaging
- Includes `workflow.version` and `workflow.description` for maintainability

**AC-7: Is ready for downstream stories**
- Orchestrator agent can read this workflow to understand the fan-out phase responsibilities
- Session tracking code can identify the `<units>` output that will be tracked
- Reviewer agent can understand that the review phase receives batch-wide results
- SM agent knows finish responsibilities are to archive and clean up
