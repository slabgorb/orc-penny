# Story 44-3: Update finalize-run for multi-judge storage

**Story ID:** 44-3
**Jira:** PROJ-16217
**Repos:** orchestrator,pennyfarthing
**Branch:** feat/finalize-run-multi-judge
**Workflow:** tdd
**Phase:** finish
**Assignee:** keith.avery

## Story Context

Update finalize-run validation to handle judge arrays (multi-judge) while maintaining backward compatibility with single-judge results. Finalize-run is the single guardrail exit point for all benchmark results -- it validates data integrity before storage.

**Key file:** `pennyfarthing-dist/skills/pf-finalize-run/SKILL.md`

### Acceptance Criteria

1. Finalize-run accepts both single judge (legacy) and judge array (multi-judge) formats
2. Each judge verdict validated independently (existing validation rules: timestamp, response length, token counts, score extraction)
3. Agreement metric included in saved results (summary YAML gets `multi_judge:` section with alpha_mean, alpha_min, alpha_max, classification)
4. Low-agreement warning (alpha < 0.67) printed but does not block storage
5. Summary YAML statistics.mean uses aggregated judge means (not first-judge-only)
6. Existing single-judge results remain loadable and comparable

### Dependencies

- Depends on 44-1 (judge array format) -- DONE
- Depends on 44-2 (agreement metrics / Krippendorff Alpha) -- DONE
- Consumed by 44-4 (multi-judge validation test)

### Storage Format (Multi-Judge)

```
runs/
  run_1.json          # Agent response
  judge_1_0.json      # Judge 0 verdict
  judge_1_1.json      # Judge 1 verdict
  judge_1_2.json      # Judge 2 verdict
```

### Scope Boundaries

- In scope: validation of judge arrays, agreement metric in results, low-agreement warning, aggregated means, backward compat
- Out of scope: judge invocation logic (44-1), agreement calculation logic (44-2), historical result migration

## SM Assessment

Story 44-3 is ready for TDD red phase. Dependencies 44-1 and 44-2 are complete. Session file created, branch `feat/finalize-run-multi-judge` cut from develop in pennyfarthing/. Story context is well-defined with clear ACs covering multi-judge validation, agreement metrics in summary YAML, backward compatibility, and aggregated means. 2-point story with TDD workflow — routing to TEA (Sam Seaborn) for test design.

## Delivery Findings

<!-- delivery-findings-start -->
### TEA (test design)
- No upstream findings during test design.
### Dev (implementation)
- No upstream findings during implementation.
### Reviewer (code review)
- **Improvement** (non-blocking): computeAgreement heuristic (1-2*std/99) diverges from Krippendorff Alpha in agreement.ts. Pragmatic for single-item case but should be documented. Affects `packages/core/src/benchmark/finalize-run-validator.ts` (add inline comment explaining why not delegating to agreement.ts). *Found by Reviewer during code review.*
### TEA (test verification)
- **Improvement** (non-blocking): Result<T> interface duplicated across 7+ files in packages/core/src. Affects `packages/core/src/benchmark/` (extract to shared types). *Found by TEA during test verification.*
- **Improvement** (non-blocking): computeAgreement() uses simplified std-based heuristic instead of Krippendorff Alpha from agreement.ts. Affects `packages/core/src/benchmark/finalize-run-validator.ts` (consider delegating to calculateAgreement). *Found by TEA during test verification.*
<!-- delivery-findings-end -->

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** FinalizeRunInput → validateFinalizeRun → agent/judge validation → agreement computation → aggregation → ValidationResult (no injection vectors)
**Pattern observed:** Result object convention followed consistently at finalize-run-validator.ts:81,94,113
**Error handling:** Success check on aggregation result before data access at finalize-run-validator.ts:143
**Observations:** 7 items checked (5 verified good, 1 low severity, 1 medium flagged by TEA verify)
**Handoff:** To Leo McGarry (SM) for finish-story

## TEA Verify Assessment

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 5 findings | Result<T> duplication (high), classifyAlpha duplication (high), computeAgreement overlap (medium), timestamp pattern (medium), test fixtures (low) |
| simplify-quality | 5 findings | classification type (high), non-null assertion (high), architecture overlap (medium), convention (low), dead code (low) |
| simplify-efficiency | 1 finding | Dead guard clause (high) |

**Applied:** 4 high-confidence fixes (classifyAlpha import, literal union type, success check, dead code removal)
**Flagged for Review:** 2 medium-confidence (Result<T> extraction, computeAgreement delegation to agreement.ts)
**Noted:** 3 low-confidence observations
**Reverted:** 0

**Overall:** simplify: applied 4 fixes

**Tests:** 37/37 passing after simplify (no regressions)
**Handoff:** To Josh Lyman (Reviewer)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/benchmark/finalize-run-validator.ts` - Full implementation replacing stubs: isMultiJudge, validateJudgeVerdict, aggregateMultiJudgeScores, validateFinalizeRun, plus internal helpers validateAgent and computeAgreement
- `packages/core/src/benchmark/index.ts` - Barrel exports for all validator functions and types
- `pennyfarthing-dist/skills/pf-finalize-run/SKILL.md` - Multi-judge data structure, validation steps, agreement report, return structure

**Tests:** 37/37 passing (GREEN)
**Branch:** feat/finalize-run-multi-judge (pushed)

**Handoff:** To Josh Lyman (Reviewer) via verify phase

## TEA Assessment

**Tests Required:** Yes
**Reason:** Multi-judge validation is core reliability infrastructure — every AC needs coverage.

**Test Files:**
- `packages/core/src/benchmark/finalize-run-validator.test.ts` (new)
- `packages/core/src/benchmark/finalize-run-validator.ts` (stubs)

**Tests Written:** 37 tests covering 6 ACs + edge cases
**Status:** RED (25 failing on assertions, 12 passing on rejection stubs)

| AC | Tests | Description |
|----|-------|-------------|
| AC1 | 5 | Format detection: single-judge vs multi-judge, accept/reject |
| AC2 | 7 | Per-verdict validation: timestamp, length, score marker, reject-on-any-invalid |
| AC3 | 5 | Agreement metrics: multi_judge section with alpha_mean/min/max/classification |
| AC4 | 2 | Low-agreement warning: non-blocking, absent when agreement OK |
| AC5 | 4 | Aggregated means: multi-judge average, single-judge unchanged, multi-agent |
| AC6 | 5 | Backward compatibility: legacy format, rejection, result objects |
| Edge | 9 | 2/5 judges, empty arrays, mismatched lengths, RATING: marker, agent validation |

**Key design decisions:**
- Created `finalize-run-validator.ts` as TypeScript module backing the SKILL.md (mirrors agreement.ts pattern)
- `isMultiJudge()` detects format by presence of `judges[]` array
- `validateJudgeVerdict()` validates individual verdicts (reusable)
- `aggregateMultiJudgeScores()` computes cross-judge means
- `validateFinalizeRun()` orchestrates full validation pipeline
- Result objects `{success, data?, error?}` throughout — never throw

**Handoff:** To Toby Ziegler (Dev) for implementation (GREEN phase)

## Session Log
- [2026-03-06T06:30:55Z] Session created by SM (sm-setup)
- [2026-03-06T06:31:30Z] SM assessment complete, handing off to TEA
- [2026-03-06T06:35:00Z] TEA: 37 failing tests written, RED state confirmed, handing off to Dev
- [2026-03-06T06:42:00Z] Dev: 37/37 GREEN, branch pushed, handing off to verify