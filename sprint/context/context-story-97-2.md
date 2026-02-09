# Story Context: 97-2 - Ship tdd-tandem Workflow

## Summary

Create a ready-to-use `tdd-tandem.yaml` workflow definition that extends the standard TDD flow with `tandem: { partner: architect, scope: file-watch }` on the green phase. Architect observes the Developer during implementation. Non-tandem phases run identically to standard `tdd`. The workflow is opt-in (not default) and appears in `/workflow list`.

## Planning References

- **PRD:** FR24-FR25 (shipping workflow, workflow list). See `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** "Journey 1: Workflow Author" in `sprint/planning/tandem-mode-ux-design.md`
- **Epics Breakdown:** Story 4.2 in `sprint/planning/tandem-mode-epics.md` under "Epic 4"

## Current State

### Existing tdd.yaml (base workflow)

**File:** `pennyfarthing/pennyfarthing-dist/workflows/tdd.yaml` (51 lines)

```yaml
workflow:
  name: tdd
  description: Test-driven development with code review
  phases:
    - name: setup
      agent: sm
      output: [session_file, branches, story_context]
    - name: red
      agent: tea
      input: [session_file, story_context]
      output: [failing_tests]
      gate:
        type: tests_fail
        condition: All acceptance criteria have test coverage
    - name: green
      agent: dev
      input: [failing_tests, story_context]
      output: [implementation, passing_tests]
      gate:
        type: tests_pass
        condition: All tests passing, no skipped tests
    - name: review
      agent: reviewer
      input: [implementation, passing_tests]
      output: [approval]
      gate:
        type: approval
        condition: Code review approved, no blocking issues
    - name: finish
      agent: sm
      input: [approval]
      output: [archived_session, story_summary]
  triggers:
    types: [feature, enhancement]
    points:
      min: 3
    default: true
```

5-phase structure: setup → red → green → review → finish. SM bookends the flow. Gates at red (tests_fail), green (tests_pass), review (approval).

### Workflow discovery (existing)

**File:** `pennyfarthing/pennyfarthing-dist/scripts/workflow/list-workflows.sh` (125 lines)

- Lines 32-38: Discovers top-level `.yaml` files in `.pennyfarthing/workflows/`
- Lines 39-43: Also discovers subdirectory `workflow.yaml` files
- Lines 93-97: For phased workflows, counts phases with `yq eval '.workflow.phases | length'`
- Placing `tdd-tandem.yaml` in `pennyfarthing-dist/workflows/` makes it auto-discoverable

### Other workflow references

**File:** `pennyfarthing/pennyfarthing-dist/workflows/2party-tdd.yaml`
- Complex workflow with refinement parties, review rejection loops, `instructions:` blocks, `next:` directives
- Shows advanced phase configuration patterns

**File:** `pennyfarthing/pennyfarthing-dist/workflows/bdd.yaml`
- Another phased workflow (SM → UX → TEA → Dev → Reviewer → SM)
- Shows how to include UX Designer phase

### No tdd-tandem workflow exists

- No `tdd-tandem.yaml` in the workflows directory
- No workflow demonstrates tandem configuration in a shipping YAML

## Target State

After implementation:

1. New `tdd-tandem.yaml` workflow in `pennyfarthing-dist/workflows/`
2. Identical to standard `tdd` except green phase has `tandem: { partner: architect, scope: file-watch }`
3. Appears in `/workflow list` with description "TDD with Architect observing during implementation"
4. Opt-in via `tags: [tandem]` trigger (NOT default)
5. Non-tandem phases (setup, red, review, finish) run identically to standard `tdd`
6. Validates successfully via BikeLane schema (Epic 95-1)

## Key Files

### Files to Create

| File | Path | Purpose |
|------|------|---------|
| `tdd-tandem.yaml` | `pennyfarthing/pennyfarthing-dist/workflows/tdd-tandem.yaml` | Shipping workflow — TDD + Architect tandem on green phase |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| `tdd.yaml` | `pennyfarthing/pennyfarthing-dist/workflows/tdd.yaml` | Base workflow to extend |
| `2party-tdd.yaml` | `pennyfarthing/pennyfarthing-dist/workflows/2party-tdd.yaml` | Advanced phase config reference |
| `list-workflows.sh` | `pennyfarthing/pennyfarthing-dist/scripts/workflow/list-workflows.sh` | Workflow discovery to verify auto-detection |
| `workflow-schema.ts` | `pennyfarthing/packages/core/src/workflow/workflow-schema.ts` | Schema validation (from 95-1) |

## Technical Approach

### Workflow YAML

```yaml
workflow:
  name: tdd-tandem
  description: TDD with Architect observing during implementation
  version: "1.0.0"
  phases:
    - name: setup
      agent: sm
      output: [session_file, branches, story_context]
    - name: red
      agent: tea
      input: [session_file, story_context]
      output: [failing_tests]
      gate:
        type: tests_fail
        condition: All acceptance criteria have test coverage
    - name: green
      agent: dev
      input: [failing_tests, story_context]
      output: [implementation, passing_tests]
      gate:
        type: tests_pass
        condition: All tests passing, no skipped tests
      tandem:
        partner: architect
        scope: file-watch
    - name: review
      agent: reviewer
      input: [implementation, passing_tests]
      output: [approval]
      gate:
        type: approval
        condition: Code review approved, no blocking issues
    - name: finish
      agent: sm
      input: [approval]
      output: [archived_session, story_summary]
  triggers:
    tags: [tandem]
    types: [feature, enhancement]
    points:
      min: 3
    default: false
```

### Key Differences from Standard tdd.yaml

| Aspect | `tdd` | `tdd-tandem` |
|--------|-------|-------------|
| Name | `tdd` | `tdd-tandem` |
| Description | Test-driven development with code review | TDD with Architect observing during implementation |
| Green phase | No tandem | `tandem: { partner: architect, scope: file-watch }` |
| Triggers | `default: true` | `default: false`, `tags: [tandem]` |
| Other phases | Standard | Identical to standard |

### Why Architect on Green

The Architect backseating during the green (implementation) phase provides:
- Pattern consistency monitoring — notices when implementation diverges from established patterns
- Cross-module awareness — spots when changes in one module should be reflected elsewhere
- Architecture drift detection — flags structural decisions that need documentation

The TEA already covers the red phase (test writing), and the Reviewer covers the review phase. The green phase is where implementation decisions happen with the least oversight.

### Opt-In Mechanism

`default: false` means this workflow is NOT automatically selected. Users explicitly choose it:
- Set `workflow: tdd-tandem` on a story
- Or tag a story with `tandem` to match the trigger

This prevents accidental backseat spawning for users who haven't opted in.

### Verification Checklist

1. BikeLane loads and validates the workflow successfully
2. `/workflow list` shows `tdd-tandem` with correct description
3. Non-tandem phases behave identically to standard `tdd`
4. Green phase spawns Architect as backseat (when Epic 95-2 is implemented)
5. Workflow can be selected via `/workflow set tdd-tandem` or story tag

## Acceptance Criteria

- `tdd-tandem.yaml` created in `pennyfarthing-dist/workflows/`
- Standard TDD phase sequence: setup → red → green → review → finish
- Green phase has `tandem: { partner: architect, scope: file-watch }`
- Non-tandem phases run identically to standard `tdd`
- Triggers: `tags: [tandem]`, NOT default (opt-in only)
- Appears in `/workflow list` with description
- BikeLane validates the workflow successfully (tandem schema from 95-1)
- Version field present

## Dependencies

### Depends On

- **95-1** (Tandem YAML schema) — the `tandem:` block must be parseable and validated by BikeLane

### Depended On By

- Nothing. This is the shipping layer — a ready-to-use workflow for users.

## Risks / Open Questions

1. **Scope choice:** The workflow uses `file-watch` scope. This is the simplest scope and the most intuitive for a shipping workflow. `tool-watch` or combined scopes could be added in future variants (e.g., `tdd-tandem-full`).

2. **Partner choice:** Architect is chosen as the default tandem partner. Other agents (TEA, PM) could also be valuable backseat observers. Future workflows could explore different pairings. For the shipping workflow, Architect is the safest choice — they focus on patterns and structure, not implementation details.

3. **Trigger tags:** Using `tags: [tandem]` means stories must be tagged `tandem` to auto-select this workflow. If the sprint system doesn't support tags on stories yet, manual workflow selection via `/workflow set tdd-tandem` is the fallback.

4. **Version compatibility:** The `tandem:` field requires the updated BikeLane validator (95-1). If a user has an older version of the framework, loading this workflow will fail validation. This is acceptable — the workflow is only useful when the tandem infrastructure is present.
