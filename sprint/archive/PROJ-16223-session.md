# Story 43-2: Update judge for red herring detection

**Story ID:** 43-2
**Jira:** PROJ-16223
**Epic:** 43 - False Positive Traps (Red Herrings)
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** orchestrator,pennyfarthing
**Branch:** feat/43-2-judge-red-herring-detection

## Acceptance Criteria
- Judge can detect red herring criteria in scenario rubrics
- Red herring scores are excluded from final scoring
- A new `precision` sub-score within the correctness dimension reflects red herring handling
- Test coverage for red herring detection logic

## Context
Story 43-1 (complete, PROJ-16222) established the red herring schema in `packages/core/src/benchmark/scenario-schema.ts`. It added the `red_herrings` field to scenario YAML with `description`, `location`, and `trap_type` subfields. The `validateScenario()` function validates this structure. 16 tests cover schema validation. Barrel export exists in `benchmark/index.ts`.

This story updates the judge to recognize and handle red herrings during evaluation.

## Technical Approach
Update the judge evaluation pipeline to:
1. Read `red_herrings` from scenario data using the schema established in 43-1
2. During evaluation, identify when an agent flags a red herring (false positive)
3. Score red herrings but exclude them from final aggregation
4. Add a `precision` sub-score within the correctness dimension
5. Report red herring detection in judge output

## Key Files
- `pennyfarthing-dist/skills/pf-judge/SKILL.md` - Judge skill definition (precision scoring)
- `packages/core/src/benchmark/scenario-schema.ts` - Schema with red_herrings field (from 43-1)
- `packages/core/src/benchmark/` - Benchmark module where judge logic lives

## Assessment
Ready for TDD workflow. 2-point story continuing the False Positive Traps epic. Schema foundation is solid from 43-1. This story focuses on judge-side consumption of red herring data.

## Delivery Findings

<!-- agent-findings-start -->
### TEA (test design)
- **Gap** (non-blocking): 43-1 branch not yet merged to develop. Merged into feature branch locally for type availability. Affects `packages/core/src/benchmark/scenario-schema.ts` (needs PR merge before this story's PR). *Found by TEA during test design.*
### Dev (implementation)
- No upstream findings during implementation.
### TEA (test verification)
- No upstream findings during test verification.
### Reviewer (code review)
- **Improvement** (non-blocking): Location-only matching in `findMatchingHerring` means agent findings without exact location strings won't match red herrings. Affects `packages/core/src/benchmark/judge-red-herrings.ts` (story 43-3 should ensure scenario locations are precise). *Found by Reviewer during code review.*
<!-- agent-findings-end -->

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core judge functionality — precision scoring for red herring detection needs full coverage

**Test Files:**
- `packages/core/src/benchmark/judge-red-herrings.test.ts` — 23 tests across 10 suites

**Tests Written:** 23 tests covering 4 ACs
- Prompt section building: descriptions, locations, trap types, scoring guidance, single herring (5 tests)
- Backward compatibility: undefined and empty red_herrings return empty section (2 tests)
- Precision scoring: flagging penalty, ignore neutral, dismissal bonus, mixed scenarios (7 tests)
- Edge cases: empty herrings, empty findings, no dismissals (3 tests)
- Correctness adjustment: negative/positive/zero/net calculations (4 tests)
- Differential scoring: flagging vs ignoring, dismissing vs ignoring (2 tests)

**Status:** RED (all 23 failing with `Error: not implemented` — stubs throw, not import errors)

**Source stubs:** `packages/core/src/benchmark/judge-red-herrings.ts` — types + 3 stub functions:
- `buildRedHerringPromptSection()` — formats red herrings for judge prompt
- `evaluateRedHerringPrecision()` — matches agent findings against known red herrings
- `calculateCorrectnessAdjustment()` — computes correctness dimension adjustment

**Note:** Merged 43-1 branch (`feature/43-1-red-herrings-schema`) into feature branch for `RedHerring` type access. 43-1 PR should merge to develop first.

**Handoff:** To Toby (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/benchmark/judge-red-herrings.ts` — implemented 3 functions: buildRedHerringPromptSection, evaluateRedHerringPrecision, calculateCorrectnessAdjustment

**Tests:** 23/23 passing (GREEN) + 16/16 from 43-1 (no regressions)
**Branch:** feat/43-2-judge-red-herring-detection (pushed)

**Handoff:** To Sam (TEA) for verify phase

## TEA Verify Assessment

**Phase:** finish (simplify + quality-pass)

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 5

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 2 findings | Duplicated ValidationResult pattern (medium), calculateCorrectnessAdjustment duplicates netAdjustment (high) |
| simplify-quality | 3 findings | Missing barrel export (high), calculateCorrectnessAdjustment duplication (medium), Array.isArray guard (medium) |
| simplify-efficiency | 4 findings | calculateCorrectnessAdjustment duplication (high), interface overlap (medium), hasRedHerrings redundant (low), barrel missing (low) |

**Applied:** 2 high-confidence fixes (barrel export, calculateCorrectnessAdjustment → evaluation.netAdjustment)
**Flagged for Review:** 3 medium-confidence findings (ValidationResult duplication across 4 files, Array.isArray guard in scenario-schema, interface overlap)
**Noted:** 2 low-confidence observations (hasRedHerrings flag, barrel consistency)
**Reverted:** 0

**Overall:** simplify: applied 2 fixes

**Tests:** 39/39 passing (GREEN confirmed after simplify)
**Handoff:** To Josh (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `RedHerring[]` → `findMatchingHerring` → location match → `RedHerringEvaluation` → `netAdjustment` (pure functions, no mutation, no throws)
**Pattern observed:** Result-object return convention at `judge-red-herrings.ts:86` — consistent with project rules
**Error handling:** All paths return structured results, undefined/empty inputs handled gracefully at lines 50-52, 79, 95
**Wiring:** Barrel export in `benchmark/index.ts:59-68` confirmed — types and functions reachable from package
**Medium finding:** Location-only matching is a design constraint; 43-3 (pilot scenario) must use precise locations

**Handoff:** To Leo (SM) for finish-story

## Session Log

- Setup by SM (Margaret)
- TEA: 23 failing tests committed on feat/43-2-judge-red-herring-detection
- Dev: implemented judge-red-herrings.ts, all 23 tests GREEN, branch pushed