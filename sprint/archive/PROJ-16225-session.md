# Story 45-1: Add gold_standard schema to scenarios

**Status:** In Progress
**Phase:** finish
**Workflow:** tdd
**Repos:** pennyfarthing
**Branch:** feature/45-1-gold-standard-schema
**Jira:** PROJ-16225
**Epic:** 45 — Gold Standard References

## Story Context

This is the first story in the Gold Standard References epic (PROJ-16212). It adds a `gold_standard` schema field to scenario definitions, providing a canonical "ideal response" reference that later stories will use for judge calibration and variance reduction.

The pattern follows the same approach as story 46-1 (difficulty_profile schema), which added an optional structured field to `ScenarioData`, a validation function, and corresponding tests in `packages/core/src/benchmark/scenario-validator.ts`.

## Acceptance Criteria

- `gold_standard` is an optional field on scenario YAML definitions
- Schema defines the structure for gold standard reference data
- Validation function (`validateGoldStandard`) follows the same pattern as `validateDifficultyProfile`
- `ScenarioData` interface extended with `gold_standard?: GoldStandard`
- `validateScenario` checks `gold_standard` when present
- Scenario templates updated to include optional `gold_standard` placeholder
- All tests pass (TDD: RED phase writes failing tests first)

## Technical Approach

Follow the established pattern from 46-1 (difficulty_profile):

1. **RED** — Write failing tests for `gold_standard` validation in `scenario-validator.test.ts`
2. **GREEN** — Add `GoldStandard` interface and `validateGoldStandard` to `scenario-validator.ts`, extend `ScenarioData` and `validateScenario`
3. **REFACTOR** — Clean up, ensure consistency with existing validators

Key design decisions to make during implementation:
- What fields should `GoldStandard` contain (e.g., `response`, `scoring_notes`, `key_points`, `expected_score`)?
- Should the schema be specific to code-review scenarios or generic across scenario categories?

## Files of Interest

- `pennyfarthing/packages/core/src/benchmark/scenario-validator.ts` — main validator (currently on feature/46-1 branch, will need content from develop)
- `pennyfarthing/packages/core/src/benchmark/scenario-validator.test.ts` — tests
- `pennyfarthing/packages/core/src/benchmark/index.ts` — barrel exports
- `pennyfarthing/packages/core/dist/benchmark/scenario-validator.js` — compiled output
- `pennyfarthing/pennyfarthing-dist/workflows/scenario-builder/templates/scenario-code.template.yaml` — code scenario template
- `pennyfarthing/pennyfarthing-dist/workflows/scenario-builder/templates/scenario-open.template.yaml` — open scenario template
- `pennyfarthing/tests/fixtures/mock-scenario.yaml` — test fixture
- `pennyfarthing/pennyfarthing-dist/src/pf/benchmark/` — Python benchmark modules (if Python validation needed)

## SM Assessment

Story 45-1 is set up and ready for RED phase. This follows the exact pattern established by 46-1 (difficulty profile schema) — add an optional structured field to ScenarioData, write validation, update templates. Branch created off develop in pennyfarthing repo. ADR-0034 (just written) defines the gold_standard contract: nullable field, graded_by must be human identifier, populated only by human grading process. Jayne should write failing tests for GoldStandard interface validation, then hand to Mal for implementation.

## Delivery Findings

### TEA (test design)
- No upstream findings during test design.

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## TEA Assessment

**Tests Required:** Yes
**Reason:** Schema validation needs comprehensive edge-case coverage per ADR-0034 constraints

**Test Files:**
- `packages/core/src/benchmark/scenario-validator.test.ts` - gold_standard validation tests (new)
- `packages/core/src/benchmark/scenario-validator.ts` - stub implementation (new)

**Tests Written:** 29 tests covering all ACs
**Status:** RED (25 failing on assertions, 4 pass trivially against stub)

**Coverage by AC:**
- Schema accepts gold_standard object: 4 happy-path tests (valid object, without notes, boundary scores)
- Missing response validation: 3 tests (missing, empty, wrong type)
- Score boundary validation: 5 tests (missing, below 1, above 100, non-number, fractional)
- graded_by human-only check (ADR-0034 rule 6): 7 tests (missing, "ai", "auto", "claude", "agent", case-insensitive, empty)
- Optional notes: 2 tests (string accepted, non-string rejected)
- Null/non-object input: 2 tests
- Multiple error reporting: 1 test
- validateScenario integration: 5 tests (no gold_standard, null, valid, invalid, graded_by propagation)

**Design Decisions for Dev:**
- `GoldStandard` fields: `response` (string, required), `score` (integer 1-100, required), `notes` (string, optional), `graded_by` (string, required, human-only)
- Score must be integer (fractional rejected) — keeps calibration discrete
- graded_by rejection is case-insensitive per ADR-0034 intent
- `validateGoldStandard` returns `{success, errors[]}` — collects all errors, doesn't short-circuit
- `validateScenario` delegates to `validateGoldStandard` when field is present, skips when absent/null

**Handoff:** To Dev (Malcolm Reynolds) for GREEN implementation

### Dev (implementation)
- No upstream findings during implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/benchmark/scenario-validator.ts` - Full implementation of validateGoldStandard and validateScenario
- `packages/core/src/benchmark/index.ts` - Barrel exports for new types and functions
- `pennyfarthing-dist/workflows/scenario-builder/templates/scenario-code.template.yaml` - gold_standard placeholder
- `pennyfarthing-dist/workflows/scenario-builder/templates/scenario-open.template.yaml` - gold_standard placeholder

**Tests:** 29/29 passing (GREEN)
**Branch:** feature/45-1-gold-standard-schema (pushed)

**Handoff:** To TEA (Jayne Cobb) for verify phase

### TEA (test verification)
- **Improvement** (non-blocking): `validateScenario` only validates the `gold_standard` sub-field, not required ScenarioData fields (id, name, etc.). Consider expanding or renaming when full scenario validation is needed. Affects `packages/core/src/benchmark/scenario-validator.ts` (function scope). *Found by TEA during test verification.*
- **Improvement** (non-blocking): `ValidationResult` interface shape duplicates similar interfaces in `consultation-protocol.ts` and `shared/repos-topology.ts`. A shared type could consolidate. Affects `packages/core/src/benchmark/scenario-validator.ts` (line 31). *Found by TEA during test verification.*

## TEA Verify Assessment

**Tests:** 29/29 passing (GREEN confirmed)
**Quality-Pass:** All checks pass

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 5

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 3 findings | ValidationResult duplication (med), null guard repeat (low), template comment duplication (low) |
| simplify-quality | 3 findings | validateScenario scope (med), type casts (low), test cast pattern (low) |
| simplify-efficiency | clean | No issues |

**Applied:** 0 high-confidence fixes
**Flagged for Review:** 2 medium-confidence findings
**Noted:** 4 low-confidence observations
**Reverted:** 0

**Overall:** simplify: clean (no high-confidence fixes to apply)

**Handoff:** To Reviewer (River Tam) for code review

### Reviewer (code review)
- No upstream findings during code review.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** unknown (YAML parse output) → validateScenario() → validateGoldStandard() → ValidationResult. All inputs type-guarded before property access. No injection paths, returns result objects (never throws). Safe.

**Pattern observed:** Error accumulation without short-circuit at `scenario-validator.ts:47-85` — collects all validation errors in single pass. Follows project convention of `{success, errors}` result objects.

**Error handling:** Null/undefined/non-object inputs caught with early return at `scenario-validator.ts:49` and `:89`. NaN and Infinity scores correctly rejected via `Number.isInteger()` at `:65`. Arrays rejected via property access on missing keys.

**Security analysis:** `graded_by` forbidden values checked case-insensitively at `:76`. Error messages include user-provided values (`:77`) but this is a build-time validator, not a user-facing API — no injection risk.

**Observations:**
1. `[VERIFIED]` Data flow: unknown → type guards → ValidationResult. Clean.
2. `[VERIFIED]` NaN/Infinity/Array edge cases all correctly handled.
3. `[VERIFIED]` FORBIDDEN_GRADED_BY matches ADR-0034 rule 6 exactly.
4. `[VERIFIED]` Error accumulation + multi-error reporting works.
5. `[VERIFIED]` Barrel exports correct with `.js` extensions.
6. `[LOW]` Whitespace-only response passes — unlikely in practice (human-curated). `scenario-validator.ts:58`
7. `[LOW]` Substring-containing forbidden values pass ("ai-grader", "claude-3") — ADR specifies exact-match only, by design. `scenario-validator.ts:76`

**Handoff:** To Zoe Washburne (SM) for finish-story