# Story Context: 95-1 - Tandem YAML Schema and BikeLane Validation

## Summary

Extend the `WorkflowPhase` interface in `workflow-schema.ts` with an optional `tandem` field that lets workflow authors declare a backseat observer agent on any phase. Add schema validation for the `tandem` block (partner required, scope enum). Workflows without `tandem:` blocks continue to load unchanged.

## Planning References

- **PRD:** FR1-FR3 (workflow configuration, schema, validation). See `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** "Journey 1: Workflow Author" (YAML config experience) in `sprint/planning/tandem-mode-ux-design.md`
- **Epics Breakdown:** Story 2.1 in `sprint/planning/tandem-mode-epics.md` under "Epic 2: Workflow Configuration & Observation Protocol"

## Current State

### WorkflowPhase interface (existing)

**File:** `pennyfarthing/packages/core/src/workflow/workflow-schema.ts` (626 lines)

The interface currently (lines 21-37):
```typescript
export interface WorkflowPhase {
  name: string;
  agent: string;
  input?: string[];
  output?: string[];
  gate?: {
    type: string;
    condition?: string;
  };
}
```

No `tandem` field exists.

### Validation logic (existing)

**File:** `pennyfarthing/packages/core/src/workflow/workflow-schema.ts`

- **Lines 166-625:** `validateWorkflow()` — main validation function
- **Lines 316-377:** Phased workflow validation — iterates phases array
- **Lines 324-376:** Phase loop — validates each phase object:
  - Lines 335-339: Phase `name` required
  - Lines 342-346: Phase `agent` required
  - Lines 349-360: Gate validation (type required if gate present, optional condition)
- Gate validation pattern at lines 349-360 is the template for tandem validation

### Workflow loader (no changes needed)

**File:** `pennyfarthing/packages/core/src/workflow/workflow-loader.ts` (185 lines)
- Loads raw YAML and passes to validator — no changes needed

### Workflow schema guide (needs update)

**File:** `pennyfarthing/pennyfarthing-dist/guides/workflow-schema.md`
- Documents the workflow YAML schema — must be updated with tandem field documentation

## Target State

After implementation:

1. `WorkflowPhase` interface includes optional `tandem?: { partner: string; scope?: string | string[] }`
2. Validation in the phase loop checks:
   - `partner` is required string
   - `scope` is optional; defaults to `file-watch`; valid values: `file-watch`, `tool-watch`, `context-watch`
   - `scope` can be string or string array (combined scopes)
3. Invalid tandem config produces clear validation errors with field path
4. Workflows without `tandem:` blocks load and validate unchanged (backward-compatible, NFR15)
5. Workflow schema guide updated with tandem documentation

## Key Files

### Files to Modify

| File | Path | Purpose |
|------|------|---------|
| `workflow-schema.ts` | `pennyfarthing/packages/core/src/workflow/workflow-schema.ts` | Add `tandem` to `WorkflowPhase` interface (line 21-37); add validation after gate validation (line 360-375) |
| `workflow-schema.md` | `pennyfarthing/pennyfarthing-dist/guides/workflow-schema.md` | Document `tandem` field schema, valid scopes, examples |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| `workflow-loader.ts` | `pennyfarthing/packages/core/src/workflow/workflow-loader.ts` | Confirm no loader changes needed |
| `tdd.yaml` | `pennyfarthing/pennyfarthing-dist/workflows/tdd.yaml` | Base workflow to verify backward compatibility |
| `2party-tdd.yaml` | `pennyfarthing/pennyfarthing-dist/workflows/2party-tdd.yaml` | Reference for advanced phase config patterns |
| `sm-subagents.test.ts` | `pennyfarthing/tests/sm-subagents.test.ts` | Existing tests to extend with tandem validation cases |

## Technical Approach

### Interface Extension

Add to `WorkflowPhase` (after `gate` field, ~line 36):

```typescript
export interface WorkflowPhase {
  name: string;
  agent: string;
  input?: string[];
  output?: string[];
  gate?: {
    type: string;
    condition?: string;
  };
  tandem?: {                        // NEW
    partner: string;                // Agent name (architect, tea, etc.)
    scope?: string | string[];     // file-watch, tool-watch, context-watch, or array
  };
}
```

### Validation Logic

Add after gate validation in the phase loop (~line 360-375). Follow the same pattern:

```typescript
if ('tandem' in phaseObj && phaseObj.tandem !== undefined) {
  if (!phaseObj.tandem || typeof phaseObj.tandem !== 'object') {
    errors.push({ field: `workflow.phases[${index}].tandem`, message: 'must be an object' });
  } else {
    const t = phaseObj.tandem as Record<string, unknown>;
    if (!t.partner || typeof t.partner !== 'string') {
      errors.push({ field: `workflow.phases[${index}].tandem.partner`, message: 'is required and must be a string' });
    }
    if (t.scope !== undefined) {
      const validScopes = ['file-watch', 'tool-watch', 'context-watch'];
      const scopes = Array.isArray(t.scope) ? t.scope : [t.scope];
      for (const s of scopes) {
        if (!validScopes.includes(s as string)) {
          errors.push({ field: `workflow.phases[${index}].tandem.scope`, message: `invalid scope "${s}". Valid: ${validScopes.join(', ')}` });
        }
      }
    }
  }
}
```

### Example YAML

```yaml
phases:
  - name: development
    agent: dev
    tandem:
      partner: architect
      scope: file-watch
  - name: review
    agent: reviewer
    # No tandem — reviewer works solo
```

Combined scopes:
```yaml
tandem:
  partner: tea
  scope: [file-watch, tool-watch]
```

### Test Cases

1. Valid tandem with single scope → passes validation
2. Valid tandem with array scope → passes validation
3. Valid tandem without scope (defaults to file-watch) → passes validation
4. Missing partner → validation error
5. Invalid scope value → validation error with valid scope list
6. Workflow without any tandem blocks → passes validation unchanged
7. Non-object tandem value → validation error

## Acceptance Criteria

- `WorkflowPhase` interface includes optional `tandem` field
- `partner` is required when `tandem` block present
- `scope` validates against allowed values: `file-watch`, `tool-watch`, `context-watch`
- `scope` accepts both string and string array
- Missing `scope` is valid (will default to `file-watch` at runtime)
- Workflows without `tandem:` blocks load and validate unchanged
- Validation errors include field path and descriptive message
- Workflow schema guide documents the tandem field

## Dependencies

### Depends On

- No other stories — this is the foundation for all tandem functionality

### Depended On By

- **95-2** (Backseat agent spawn and lifecycle) — reads tandem config from validated workflow definition
- All subsequent 95-x stories depend transitively through 95-2

## Risks / Open Questions

1. **Agent name validation:** Should `partner` be validated against known agent names (from `pennyfarthing-dist/agents/`)? The current gate validation doesn't validate agent names, so following the same pattern is simpler. Invalid agent names would fail at spawn time with a clear error.

2. **Scope defaults:** The scope defaults to `file-watch` at runtime, not at validation time. The validator should accept missing scope without error. Document this default in the guide.
