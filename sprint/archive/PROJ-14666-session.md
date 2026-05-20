# Story 95-1: Tandem YAML schema and BikeLane validation

**Jira:** PROJ-14666
**Epic:** 95 — Workflow Configuration & Observation Protocol
**Points:** 3
**Type:** Feature
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/95-1-tandem-yaml-schema

## Description

Extend the `WorkflowPhase` interface in `workflow-schema.ts` with an optional `tandem` field that lets workflow authors declare a backseat observer agent on any phase.

**Key features:**
- `tandem:` block on workflow phases with `partner` and optional `scope` fields
- Support single scope string or combined scopes array: `scope: [file-watch, tool-watch]`
- Validate schema at load time — fail fast on invalid config
- Backward-compatible: workflows without `tandem:` blocks work unchanged

**Scope values:** `file-watch`, `tool-watch`, `context-watch`

## Acceptance Criteria

- `WorkflowPhase` interface includes optional `tandem` field with shape: `{ partner: string; scope?: string | string[] }`
- `partner` is required when `tandem` block present; must be a string
- `scope` validates against allowed values: `file-watch`, `tool-watch`, `context-watch`
- `scope` accepts both string and string array (combined scopes)
- Missing `scope` is valid (will default to `file-watch` at runtime)
- Workflows without `tandem:` blocks load and validate unchanged (NFR15 - backward-compatible)
- Validation errors include field path and descriptive message
- Workflow schema guide documents the tandem field and valid scopes
- All test cases pass: valid tandem (single + array scope), missing partner, invalid scope, non-object tandem, workflows without tandem

## Technical Context

### Tandem System Overview

The tandem system enables backseat observation agents to monitor primary agent work. This story implements the foundational schema and validation layer.

**Architecture flow:**
1. Workflow YAML defines `tandem:` blocks on phases
2. BikeLane Loader loads YAML → Schema Validator validates `tandem` config
3. BikeLane Executor reads validated tandem config at phase start
4. Backseat Agent spawns with scope config (file-watch, tool-watch, context-watch)
5. Backseat writes observations to `.session/{story-id}-tandem-{agent}.md`
6. Bell Mode Hook injects observations into primary agent's context

### Key Design Patterns

**Interface Extension Pattern** (from existing `gate` field):
```typescript
export interface WorkflowPhase {
  // ... existing fields (name, agent, input, output, gate)
  tandem?: {                        // NEW
    partner: string;                // Agent name (architect, tea, etc.)
    scope?: string | string[];      // file-watch, tool-watch, context-watch, or array
  };
}
```

**Validation Pattern** (follow gate validation template at lines 349-360):
- Check if field exists and is an object
- If object, validate required fields (`partner` required string)
- For optional fields (`scope`), validate enum values
- Accumulate errors with field path (e.g., `workflow.phases[0].tandem.partner`)

### Example YAML Configuration

Single scope:
```yaml
phases:
  - name: development
    agent: dev
    tandem:
      partner: architect
      scope: file-watch
```

Combined scopes:
```yaml
phases:
  - name: review
    agent: reviewer
    tandem:
      partner: tea
      scope: [file-watch, tool-watch]
```

Without tandem (backward compatible):
```yaml
phases:
  - name: testing
    agent: qa
    # No tandem — works unchanged
```

## Files of Interest

### Files to Modify (Implementation)

| File | Path | Purpose |
|------|------|---------|
| `workflow-schema.ts` | `pennyfarthing/packages/core/src/workflow/workflow-schema.ts` (626 lines) | Add `tandem` to `WorkflowPhase` interface (line 21-37); add validation in phase loop after gate validation (~line 360-375) |
| `workflow-schema.md` | `pennyfarthing/pennyfarthing-dist/guides/workflow-schema.md` | Document `tandem` field schema, valid scopes, usage examples |
| `sm-subagents.test.ts` | `pennyfarthing/tests/sm-subagents.test.ts` | Add test cases: valid tandem (single + array), missing partner, invalid scope, non-object tandem, backward compatibility |

### Files to Read (Context / Reference)

| File | Path | Purpose |
|------|------|---------|
| `workflow-loader.ts` | `pennyfarthing/packages/core/src/workflow/workflow-loader.ts` (185 lines) | Confirms no loader changes needed — passes raw YAML to validator |
| `tdd.yaml` | `pennyfarthing/pennyfarthing-dist/workflows/tdd.yaml` | Base workflow; verify backward compatibility after implementation |
| `2party-tdd.yaml` | `pennyfarthing/pennyfarthing-dist/workflows/2party-tdd.yaml` | Reference for advanced phase config patterns |
| `session-state.ts` | `pennyfarthing/packages/core/src/workflow/session-state.ts` (291 lines) | Pattern reference for state tracking and result objects |

### Planning Documents (Context)

| Document | Sections |
|----------|----------|
| **PRD** | `sprint/planning/tandem-mode-prd.md` — FR1-FR3 (workflow config, schema, validation) |
| **UX Design Spec** | `sprint/planning/tandem-mode-ux-design.md` — "Journey 1: Workflow Author" (YAML config experience) |
| **Epic Breakdown** | `sprint/planning/tandem-mode-epics.md` — Story 2.1 details, FR Coverage Map |
| **Epic Context** | `sprint/context/context-epic-95.md` — Architecture, validation pattern template, key files reference |

## Validation Test Cases

1. ✓ Valid tandem with single scope (file-watch) → passes validation
2. ✓ Valid tandem with array scope (combined scopes) → passes validation
3. ✓ Valid tandem without scope field → passes validation (defaults to file-watch at runtime)
4. ✓ Missing partner field → validation error with field path
5. ✓ Invalid scope value → validation error with valid scope list enumeration
6. ✓ Non-object tandem value → validation error
7. ✓ Workflow without any tandem blocks → passes validation unchanged (backward compatible)

## Dependencies

### Depends On
- None — this is the foundation story with no blockers

### Depended On By
- **95-2** (Backseat agent spawn and lifecycle) — reads tandem config from validated definition
- **95-3** through **95-7** — all subsequent tandem stories depend transitively

## Notes

### Scope Default Behavior
The `scope` field defaults to `file-watch` at **runtime** (in the executor), not at validation time. The validator accepts missing `scope` without error.

### Agent Name Validation
The `partner` field is validated as a string but NOT checked against known agent names. Following the existing `gate` field pattern (which doesn't validate agent names either), invalid agent names will fail at spawn time with a clear error.

### Framework Rules Applied
- Return result objects `{success, data?, error?}` instead of throwing
- Use `.js` extensions in all relative TypeScript imports
- No breaking changes to existing validation patterns

## TEA Assessment

**Tests Required:** Yes
**Reason:** New validation logic for tandem field on WorkflowPhase — must prove schema contract before implementation.

**Test File:**
- `packages/core/src/workflow/workflow-schema.test.ts` — 9 new tests in `describe('Tandem validation (95-1)')` block

**Tests Written:** 9 tests covering all ACs

| # | Test | Status | Failure Reason |
|---|------|--------|----------------|
| 1 | Valid tandem with single scope | RED | `tandem` not carried to result (undefined) |
| 2 | Valid tandem with array scope | RED | `tandem` not carried to result (undefined) |
| 3 | Valid tandem without scope | RED | `tandem` not carried to result (undefined) |
| 4 | All three valid scope values | RED | `tandem` not carried to result (undefined) |
| 5 | Missing partner → error | RED | Validator accepts (no tandem validation) |
| 6 | Invalid scope → error with enum | RED | Validator accepts (no scope validation) |
| 7 | Invalid scope in array → error | RED | Validator accepts (no scope validation) |
| 8 | Non-object tandem → error | RED | Validator accepts (no type check) |
| 9 | Backward compat (no tandem) | PASS | Existing workflows unaffected |

**Status:** RED (8 failing, 1 passing — ready for Dev)
**Existing tests:** 34/34 pass — no regressions

**Implementation guidance for Dev:**
1. Add `tandem?` to `WorkflowPhase` interface (line 21-37)
2. Add validation in phase loop after gate validation (~line 360): follow gate pattern exactly
3. Add tandem to phase builder in result construction (~line 498-522)
4. Valid scopes: `file-watch`, `tool-watch`, `context-watch`
5. `scope` is string | string[] — validate each element against enum

**Handoff:** To Dev (White Rabbit) for implementation (green phase)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/workflow/workflow-schema.ts` — Added `tandem?` to `WorkflowPhase` interface, validation in phase loop (after gate), result builder carry-through

**Tests:** 42/42 passing (GREEN) — 9 new tandem + 33 existing, zero regressions
**PR:** #785 — feat(workflow): tandem YAML schema validation (95-1)
**Branch:** feat/95-1-tandem-yaml-schema (pushed)

**Implementation notes:**
- Followed gate validation pattern exactly (object check → required fields → optional enum)
- `validScopes` array used for both single string and array element validation
- Error messages include field path and list valid scope values
- No changes to loader — validator handles everything

**Handoff:** To Reviewer (Queen of Hearts) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**PR:** #785 — merged to develop, branch deleted

**Data flow traced:** Raw YAML input → `validateWorkflow()` → phase loop → tandem guard clause (line 370) → validation (partner required, scope enum) → result builder (line 559) → `WorkflowPhase` with tandem. Safe — no external input escapes, pure validation logic.

**Pattern observed:** Tandem validation follows gate validation template exactly (object check → required fields → optional enum). Consistent at `workflow-schema.ts:369-399`.

**Error handling:** All invalid inputs produce errors with indexed field paths (`workflow.phases[N].tandem.scope[M]`). Null tandem correctly caught by falsy guard. Verified at `workflow-schema.ts:371`.

**Observations:**
| # | Tag | Finding |
|---|-----|---------|
| 1 | `[VERIFIED]` | Interface matches spec — `workflow-schema.ts:37-43` |
| 2 | `[VERIFIED]` | Validation follows gate pattern — `workflow-schema.ts:369-399` |
| 3 | `[VERIFIED]` | Result builder carries tandem — `workflow-schema.ts:559-567` |
| 4 | `[VERIFIED]` | Backward compat (guard clause) — `workflow-schema.ts:370` |
| 5 | `[VERIFIED]` | Error messages enumerate valid scopes |
| 6 | `[LOW]` | Empty string partner accepted — consistent with `gate.type`/`agent` |
| 7 | `[LOW]` | Duplicate scope values in array accepted — harmless |

**Preflight:** 42/42 tests, no forbidden patterns, TypeScript clean

**Handoff:** To SM (Mad Hatter) for finish-story

## Session Log

- **2026-02-10 Setup by SM (sm-setup):** Created session file, claimed Jira, created feature branch `feat/95-1-tandem-yaml-schema`
- **2026-02-10 Handoff SM → TEA:** Story setup complete. Handing off to TEA for test design (red phase).
- **2026-02-10 TEA red phase complete:** 9 tests written, 8 RED (assertion failures), 1 PASS (backward compat). Committed as `43706cd7d`. Handing off to Dev for green phase.
- **2026-02-10 Dev green phase complete:** Implementation in `workflow-schema.ts` (48 lines added). 42/42 tests GREEN. PR #785 created. Handing off to Reviewer.
- **2026-02-10 Reviewer APPROVED:** No Critical/High issues. 7 observations (5 verified, 2 low). PR #785 merged to develop. Handing off to SM for finish.
