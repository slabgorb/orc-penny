# Story 107-1: Gate schema validation at parse time

**Jira:** MSSCI-15009
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/107-1-gate-schema-validation-parse-time

---

## Workflow Tracking

**Workflow:** tdd
**Phase:** red
**Phase Started:** 2026-02-15 09:35:42

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-15 09:35 | 2026-02-15 09:35 | <1m |
| red | 2026-02-15 09:35 | - | - |

---

## Context

Epic 107: Gate Validation & Authoring. This story adds schema validation for gate definitions in workflow YAML files at parse time. The gate system was built in epic 106 (stories 106-1 through 106-4). Gates define phase transitions in workflows — types like "tests-pass", "file", etc. Malformed gate definitions should be caught early when YAML is loaded, not at runtime.

### Key Files
- `pennyfarthing_scripts/workflow/resolve_gate.py` — gate resolution logic
- `pennyfarthing_scripts/workflow/` — workflow scripts
- `pennyfarthing-dist/workflows/` — workflow YAML definitions

## Acceptance Criteria

1. Schema file validates gate structure (type, condition, file if present)
2. Parser validates gates at load time, raises clear errors for invalid definitions
3. All existing gate definitions conform to schema (no breaking changes)
4. Error messages guide authors on valid gate syntax

## SM Assessment

Story setup complete. TDD workflow — TEA writes failing tests first, then Dev implements.

**Handoff:** To TEA for red phase (failing tests)

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `packages/core/src/workflow/gate-schema-validation.test.ts` — 17 tests covering all 4 ACs

**Tests Written:** 17 tests covering 4 ACs (13 failing, 4 passing)
**Status:** RED (failing — ready for Dev)

**Gaps Exposed:**
1. `gate.file` not in `WorkflowPhase` interface — field dropped on parse
2. `gate.file` not validated (type, format, traversal, empty, absolute path)
3. `gate.type` accepts any string — no enum validation against known types
4. `gate.condition` not type-checked (accepts non-string values)
5. Error messages don't list valid types or mention `file` as alternative to `type`
6. Empty gate `{}` error says "type required" but doesn't mention `file` as option

**Implementation Guidance for Dev:**
- Add `file?: string` to `WorkflowPhase.gate` interface
- Add gate type enum: `tests_pass`, `tests_fail`, `approval`, `manual`
- Validate `gate.file` format: must be string, non-empty, no `..`, no absolute paths
- Allow gate with `file` but no `type` (file-based gates are the future)
- Update error messages to list valid types and mention `file` option
- Preserve `gate.file` in the builder output (lines 550-558 of workflow-schema.ts)

**Handoff:** To Sergeant Carter (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/workflow/workflow-schema.ts` — Added gate.file support, gate type enum validation, condition type checking, helpful error messages

**Tests:** 17/17 passing (GREEN), 795/795 workflow tests passing (no regressions)
**PR:** #915 — feat(107-1): gate schema validation at parse time
**Branch:** feat/107-1-gate-schema-validation-parse-time (pushed)

**Handoff:** To General Burkhalter (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | [MEDIUM] | `phase.gate.type` potentially `undefined` for file-only gates; `default` switch handles correctly (pass-through to Python resolver) | `handoff.ts:223` |
| 2 | [LOW] | Unnecessary `as Record<string, unknown>` cast; interface already declares `file?: string` | `workflow-schema.ts:591` |
| 3 | [VERIFIED] | Path traversal security: `..`, empty, absolute path rejection comprehensive | `workflow-schema.ts:387-393` |
| 4 | [VERIFIED] | Error messages include phase indices, list valid types, mention type+file options | `workflow-schema.ts:370-398` |
| 5 | [VERIFIED] | Backward compat: all 7 existing gate types in enum, legacy gates unchanged | `workflow-schema.ts:368` |
| 6 | [VERIFIED] | `gate.condition` type validation added (previously unchecked) | `workflow-schema.ts:395-399` |
| 7 | [LOW] | `validGateTypes` inline constant not exported — YAGNI, acceptable | `workflow-schema.ts:368` |

**Data flow traced:** YAML input → `validateWorkflow()` → validation checks → builder output. File field preserved end-to-end. Invalid inputs caught at validation boundary.
**Error handling:** Each failure produces specific error with field path and message. Multiple errors accumulate. Function never throws (returns result object).
**Security:** Path traversal, absolute paths, empty strings all rejected. Appropriate for YAML-parsed inputs.

**Handoff:** To Colonel Hogan (SM) for finish-story
