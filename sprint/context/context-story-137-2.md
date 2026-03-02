---
parent: 137
---

# Story 137-2: Replace static collaboration menus with AskUserQuestion

## Business Context

The stepped workflow system currently uses static `<collaboration-menu>` elements for all user interaction points. This story modernizes those interactions by introducing structured `<switch>` elements powered by the AskUserQuestion tool, enabling:

- **Structured branching**: Steps that navigate to different outcomes based on user choice
- **Tool-driven choices**: Explicit `tool="AskUserQuestion"` attribute signals engine to use structured Q&A
- **Taxonomy clarity**: xml-tags.md documents the schema for all workflow branching constructs
- **Mechanical migration**: ~90 workflow step files across 11+ workflows are systematically updated

This supports Epic 137 (Stepped workflow modernization) by enabling gates and AskUserQuestion-driven collaboration patterns.

## Technical Guardrails

1. **Schema authority**: workflow-step-schema.md is the single source of truth for `<switch>`, `<case>`, `<default>` elements
2. **Retention rule**: `<collaboration-menu>` is retained ONLY for loop menus (A/P/C where all options cycle back to current step)
3. **Transition rule**: Any menu where options navigate to different steps MUST use `<switch tool="AskUserQuestion">`
4. **ADR-0032 compliance**: Migration is mechanical and guided by docs/adr/0032-stepped-workflow-switch-gate-output-tags.md
5. **No functional changes**: Existing workflow behavior and routing must be preserved
6. **Branch strategy**: Work on `develop` branch (pennyfarthing is gitflow)

## Scope Boundaries

**Included:**
- workflow-step-schema.md schema updates (add `<switch>`, `<case>`, `<default>` definitions)
- All stepped workflow step files in pennyfarthing-dist/workflows/:
  - architecture, release, prd, quick-dev, ux-design, epics-and-stories, sprint-planning, guided-tour, installation-check, project-setup
- xml-tags.md taxonomy updates documenting new elements
- Preserve existing `<collaboration-menu>` for loop menus only

**Excluded:**
- Changes to workflow engine or AskUserQuestion tool implementation
- Changes to handler logic or step execution
- Schema overhauls beyond `<switch>` additions

## AC Context

**Definition of Done:**
1. workflow-step-schema.md contains complete `<switch>`, `<case>`, `<default>` element definitions
2. All ~90 step files migrated: branching menus use `<switch>`, loop menus use `<collaboration-menu>`
3. xml-tags.md updated with new element documentation
4. Behavior verification: workflows execute identically to pre-migration state
5. Code review approval by architect or senior engineer

**Testing approach:**
- Spot-check 10+ step files across multiple workflows to verify correct element usage
- Verify workflow execution matches pre-migration behavior
- Schema validation against updated workflow-step-schema.md

## Interaction Patterns

- **Menu with step transitions** → `<switch tool="AskUserQuestion"><case>...→step</case></switch>`
- **Menu with loop-back** → `<collaboration-menu>` (unchanged)
- **Simple boolean choice** → `<switch>` with two `<case>` options
- **Multi-branch** → `<switch>` with `<default>` fallback

## Accessibility Requirements

- All AskUserQuestion prompts MUST have clear, unambiguous labels
- Case labels MUST match exact step names (no abbreviations)
- Default case MUST handle unexpected inputs gracefully
