# Story 45-4: Variance comparison: with/without gold standard

**Jira:** MSSCI-16228
**Epic:** 45 — Gold Standard References
**Points:** 1
**Priority:** p1
**Repos:** pennyfarthing
**Workflow:** tdd
**Phase:** finish
**Branch:** feat/gold-standard-variance-comparison
**Assigned:** keithavery

---
## Acceptance Criteria
- Compare scoring variance with and without gold standard calibration
- Show that variance decreases when gold standards are available
- Results captured in a reproducible test or benchmark

## Context
Follow-on from 45-2 (judge calibration). Now that the judge can use gold standards, this story validates the hypothesis that calibration reduces scoring variance.

## Technical Approach
TBD — Dev/TEA will determine implementation details.

## Delivery Findings
<!-- Agent findings below -->
### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- No upstream findings during implementation.

### TEA (test verification)
- No upstream findings during test verification.

### Reviewer (code review)
- No upstream findings during code review.

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `list[float]` → `compute_score_variance` → `float` → `VarianceComparison`. Pure functions, no I/O, no mutation.
**Pattern observed:** Clean module separation — variance is independent of judge_prompt, reusable for any score comparison at `variance.py:22-46`
**Error handling:** `ValueError` on empty input at `variance.py:24-25`; division-by-zero guard at `variance.py:38-39` returns 0.0% safely

**Observations:**
| Severity | Issue | Location | Action |
|----------|-------|----------|--------|
| [VERIFIED] | Population variance math correct | `variance.py:28` | n/a |
| [VERIFIED] | Empty input guard | `variance.py:24-25` | n/a |
| [VERIFIED] | Division-by-zero guard | `variance.py:38-39` | n/a |
| [VERIFIED] | Package exports wired | `__init__.py:18-22, 38-41` | n/a |
| [VERIFIED] | Pure functions, no side effects | `variance.py:22-46` | n/a |
| [VERIFIED] | 14 tests covering all 3 ACs | `test_variance_comparison.py` | n/a |
| [LOW] | No dedicated test for `compare_calibration_variance([])` | test gap | Implicitly handled via delegation |
| [VERIFIED] | No forbidden patterns | entire diff | n/a |

**Tests:** 14/14 passing (33/33 including 45-2 tests).

**Handoff:** To SM for finish-story

## TEA Verify Assessment

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 6

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 4 findings | Copy-paste test setup (medium), shared validation gap (medium), 2x intentional duplication (low) |
| simplify-quality | 4 findings | Unused `import pytest` (high), `input` shadows builtin (medium), float == 0 (low), raises vs result objects (low) |
| simplify-efficiency | clean | No findings |

**Applied:** 1 high-confidence fix (removed unused `import pytest` from `test_judge_gold_standard.py`)
**Flagged for Review:** 3 medium-confidence findings (parameter naming, test setup repetition, missing Python-side validation)
**Noted:** 4 low-confidence observations (cross-language duplication, rubric text, float equality, error convention)
**Reverted:** 0

**Overall:** simplify: applied 1 fix

**Handoff:** To River (Reviewer) for code review

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/benchmark/variance.py` — implemented `compute_score_variance` (population variance) and `compare_calibration_variance` (comparison with reduction %)
- `pennyfarthing-dist/src/pf/benchmark/__init__.py` — wired exports for new variance module

**Tests:** 14/14 passing (GREEN), plus 19/19 from 45-2 (no regression)
**Branch:** feat/gold-standard-variance-comparison (pushed)

**Handoff:** To next phase (verify/review)

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core behavioral change — variance computation and comparison functions need validation

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_variance_comparison.py` (new) — 14 tests across 3 classes
- `pennyfarthing-dist/src/pf/benchmark/variance.py` (new) — stub with types + `compute_score_variance()` + `compare_calibration_variance()`

**Tests Written:** 14 tests covering 3 ACs
- AC1 (6 tests): Variance computation for known values, identical scores, two values, single score, empty input, comparison returns both variances
- AC2 (5 tests): With-GS variance is lower, reduction % is positive, reduction % formula correct, identical yields 0%, higher with-GS yields negative
- AC3 (3 tests): Same input → same output, manual calculation verification for both score sets

**Status:** RED (14 failing — all NotImplementedError, no import errors)

**Implementation notes for Mal:**
- `compute_score_variance(scores)` should return population variance (not sample) — divide by N, not N-1
- `compare_calibration_variance(without_gs, with_gs)` should compute both variances and return `VarianceComparison` with reduction percentage
- Reduction formula: `(without - with) / without * 100`
- Raise `ValueError` on empty input to `compute_score_variance`
- Also wire exports in `__init__.py`
- NOTE: 45-2 branch was merged into this branch (fast-forward) since develop didn't have judge_prompt.py yet

**Handoff:** To Dev (Malcolm Reynolds) for GREEN implementation

## SM Assessment
- Session created, Jira claimed (MSSCI-16228), branch cut from develop
- Story is P1, 1pt, follows 45-2 (judge calibration) — validates variance reduction hypothesis
- TDD workflow: routing to TEA (Jayne) for red phase — write failing tests first
- No blockers identified