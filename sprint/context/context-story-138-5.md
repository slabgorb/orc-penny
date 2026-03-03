---
parent: 138
workflow: trivial
---

# Story 138-5: Add simplify team block to tdd and tdd-tandem workflow YAMLs

## Business Context

The workflow YAML `team:` block is the declarative mechanism that tells TEA which teammates to spawn during a phase. Without these blocks, TEA's new simplify integration (138-4) has no way to discover the simplify teammates. This story adds the team block to the verify phase of both `tdd.yaml` and `tdd-tandem.yaml`, enabling the simplify feature for all TDD-based story work. Other workflow types (trivial, bdd) are unaffected — simplify only activates where the team block is present.

## Technical Guardrails

- **Modify:** `pennyfarthing-dist/workflows/tdd.yaml` — add `team:` block to verify phase
- **Modify:** `pennyfarthing-dist/workflows/tdd-tandem.yaml` — add `team:` block to verify phase (alongside existing architect teammate)
- **Follow:** Workflow YAML schema at `pennyfarthing-dist/schemas/workflow-schema.md`
- **Team block structure:** Per FR-3.1 in PRD — three teammates with agent names and task descriptions
- **Backward compatibility:** Workflows without team blocks must continue to work (NFR-4)
- **Do NOT modify:** Any other workflow files, gate definitions, or agent definitions

## Scope Boundaries

**In scope:**
- Add `team:` block with three simplify teammates to `tdd.yaml` verify phase
- Add `team:` block with three simplify teammates to `tdd-tandem.yaml` verify phase
- Ensure team block structure matches the schema and PRD spec

**Out of scope:**
- Subagent definitions (stories 138-1, 138-2, 138-3)
- TEA agent behavior changes (story 138-4)
- Extension to `bdd.yaml`, `trivial.yaml`, or other workflows (post-MVP growth feature)
- Changes to the verify phase's existing gate definition
- Schema changes to workflow-schema.md (team blocks are already supported)

## AC Context

1. **`tdd.yaml` verify phase has team block** — The verify phase in `tdd.yaml` includes a `team:` block with `teammates:` array containing entries for `simplify-reuse`, `simplify-quality`, and `simplify-efficiency`, each with an `agent` name and `task` description string
2. **`tdd-tandem.yaml` verify phase has team block** — Same team block added to `tdd-tandem.yaml`. If an architect teammate already exists in verify, the simplify teammates are added alongside it (not replacing it)
3. **Task descriptions are report-only** — Each teammate's task description explicitly includes "Report findings only" to reinforce that teammates do not modify files
4. **Existing verify phase structure preserved** — The `agent`, `input`, `output`, and `gate` fields of the verify phase remain unchanged; only the `team` block is added
5. **No other workflow files modified** — `trivial.yaml`, `bdd.yaml`, and other workflows are untouched
