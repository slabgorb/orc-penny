# Story 43-1: Add red_herrings schema to scenarios

**Jira:** MSSCI-16222
**Epic:** 43 — False Positive Traps (Red Herrings)
**Points:** 2
**Priority:** p0
**Repos:** pennyfarthing
**Branch:** feature/43-1-red-herrings-schema
**Workflow:** tdd
**Phase:** finish
**Assigned:** keith.avery@1898andco.io

## Acceptance Criteria

- Add `red_herrings` field to scenario YAML schema
- Each red herring entry includes: `description`, `location`, and `trap_type`
- Schema validates the new field structure (see context-epic-43.md for example shape)
- Existing scenarios without `red_herrings` remain valid (field is optional)

## Technical Notes

[Leave blank for next agent to fill.]

## SM Assessment

Story 43-1 is ready for TDD red phase. Session created, branch cut from develop, Jira claimed. ACs are clear — schema extension with optional red_herrings field. 2-point story, straightforward schema work. Routing to TEA for test-first design.

## Delivery Findings

<!-- agent-findings-start -->
### TEA (test design)
- No upstream findings during test design.
### Dev (implementation)
- No upstream findings during implementation.
### TEA (test verification)
- No upstream findings during test verification.
### Reviewer (code review)
- No upstream findings during code review.
<!-- agent-findings-end -->

## TEA Assessment

**Tests Required:** Yes
**Reason:** Schema validation with new field — needs full coverage of valid/invalid inputs

**Test Files:**
- `packages/core/src/benchmark/scenario-schema.test.ts` — 16 tests across 5 suites

**Tests Written:** 16 tests covering 4 ACs
- Basic scenario validation (name, title required, non-object rejection)
- Backward compatibility (no red_herrings, empty array both valid)
- Valid red_herrings entries (single, multiple, all fields present)
- Missing required subfields (description, location, trap_type — each individually and combined)
- Edge cases (non-array red_herrings, non-object entries, empty strings)

**Status:** RED (all 16 failing with `Error: not implemented` — stub throws, not import errors)

**Source stub:** `packages/core/src/benchmark/scenario-schema.ts` — types + `validateScenario()` stub

**Handoff:** To Toby (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/benchmark/scenario-schema.ts` — implemented `validateScenario()` with full red_herrings validation

**Tests:** 16/16 passing (GREEN)
**Branch:** feature/43-1-red-herrings-schema (pushed)

**Handoff:** To Josh (Reviewer) for code review

## TEA Verify Assessment

**Phase:** finish (simplify + quality-pass)

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 2

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 3 findings | Duplicated validation types (medium), shared guard pattern (low), isNonEmptyString not shared (medium) |
| simplify-quality | 3 findings | Missing barrel export (high), unexported types (medium), cast pattern noted (low) |
| simplify-efficiency | clean | No issues |

**Applied:** 1 high-confidence fix (added barrel export in `benchmark/index.ts`)
**Flagged for Review:** 3 medium-confidence findings (unexported types, duplicated validation interfaces, shared helper)
**Noted:** 2 low-confidence observations (guard pattern, cast pattern)
**Reverted:** 0

**Overall:** simplify: applied 1 fix

**Tests:** 16/16 passing (GREEN confirmed after simplify)
**Handoff:** To Josh (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `unknown` → object guard → `Record<string, unknown>` cast → field validation → `{valid, errors}` (no mutation, no throws)
**Pattern observed:** Result-object return convention at `scenario-schema.ts:35` — consistent with project rules
**Error handling:** All paths return result objects, null/non-object early return at line 38-39
**Wiring:** Barrel export in `benchmark/index.ts` confirmed — types reachable from package
**Low findings:** `ValidationError`/`ValidationResult` unexported (TS infers, non-blocking)

**Handoff:** To Leo (SM) for finish-story

## Session Log

- Setup by SM
- TEA: 16 failing tests committed on feature/43-1-red-herrings-schema
- Dev: implemented validateScenario, all 16 tests GREEN, branch pushed
- TEA verify: simplify clean + 1 barrel export fix applied, all GREEN