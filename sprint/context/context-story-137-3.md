# Story 137-3: Gate validation for stepped workflows

**Story ID:** 137-3
**Jira:** MSSCI-15923
**Points:** 3
**Priority:** P1
**Epic:** 137 — Stepped workflow modernization
**Workflow:** tdd

## Overview

Add automatic gate validation to the stepped workflow lifecycle. This story implements the third capability of Epic 137: a complete gate validation system for stepped workflows.

## Acceptance Criteria

1. `resolve_step_gate()` function created in `src/pf/workflow/step_gate.py`
2. `pf workflow complete-step` command extended to call gate validation when `step-meta` has `gate: true`
3. Support for inline gate criteria from `<gate>` tag and external `gate_file` references
4. `--skip-gate` override flag implemented for emergency situations
5. Stepped gate files created for architecture workflow (components, risks criteria)
6. Stepped gate files created for release workflow (version bump, commit criteria)
7. `guides/gates.md` updated with stepped gate documentation
8. `schemas/workflow-schema.md` updated with stepped gate schema

## Technical Details

### New Module: step_gate.py

Location: `src/pf/workflow/step_gate.py`

Core function:
```python
def resolve_step_gate(
    step_meta: dict,
    step_file: str,
    workflow_name: str,
    skip_gate: bool = False
) -> dict:
    """
    Validate a stepped workflow step against its gate criteria.

    Returns:
        {
            'success': bool,
            'gate_result': dict,
            'error': str or None,
            'gate_used': str  # 'inline' | 'external' | 'skipped'
        }
    """
```

### Step Meta Structure

Step files will include gate metadata:

```yaml
step-meta:
  gate: true
  gate_inline: |
    - criterion: "components documented"
      check: "All major components have ADR references"
    - criterion: "risks assessed"
      check: "Risk register updated"
  gate_file: "gates/architecture-step-03.yaml"
```

### External Gate Files

Gate files follow the existing gate schema but are stepped-aware:

**Location:** `pennyfarthing-dist/workflows/gates/stepped/`

Examples:
- `stepped/architecture-components.yaml`
- `stepped/architecture-risks.yaml`
- `stepped/release-version-bump.yaml`
- `stepped/release-commit.yaml`

### Command Extension

Modify `pf workflow complete-step`:

```bash
pf workflow complete-step --step 3 [--skip-gate] [--gate-only]
```

Flags:
- `--skip-gate`: Bypass gate validation (logs override reason)
- `--gate-only`: Run gate validation without completing the step

### Integration Points

1. **Step Completion:** In `pennyfarthing-dist/scripts/workflow.py` (or appropriate entry point)
2. **Session Updates:** Mark step as gate-validated in session file
3. **Error Handling:** Return structured GATE_RESULT on validation failure
4. **Override Audit:** Log all --skip-gate uses to audit trail

## Implementation Guidelines

### Test Coverage

- Unit tests for resolve_step_gate() with inline criteria
- Unit tests for external gate file resolution
- Integration tests for complete-step with gate validation
- Edge cases: missing gate file, malformed criteria, gate failure scenarios

### Documentation Updates

**gates.md:**
- Add section "Stepped Workflow Gates"
- Document inline vs. external gate criteria
- Show example gate files
- Explain gate_only mode and --skip-gate override

**workflow-schema.md:**
- Add step-meta.gate field documentation
- Document gate_inline and gate_file structure
- Show gate result contract

## Definition of Done

- [ ] resolve_step_gate() function implemented and tested
- [ ] pf workflow complete-step extended with gate validation
- [ ] --skip-gate flag working with audit logging
- [ ] At least 2 reference gate files created (architecture + release)
- [ ] gates.md guide updated
- [ ] workflow-schema.md updated
- [ ] All tests passing (unit + integration)
- [ ] No lint/typecheck errors
- [ ] Reviewed and approved

## Dependencies

- **Upstream:** 137-1 (tag design research), 137-2 (AskUserQuestion migration)
- **Downstream:** 137-4 (workflow-type-aware initialization), 137-5 (tandem/team collaboration)

## References

- Epic 137 description: Sprint YAML
- ADR on stepped workflows (from 137-1)
- guides/gates.md (existing gate documentation)
- schemas/workflow-schema.md
- schemas/workflow-step-schema.md
