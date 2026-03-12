# Story 42-3: Variance test: measure CV reduction

**Jira:** MSSCI-16221
**Epic:** 42 - Anchored Rubric Criteria
**Points:** 1
**Workflow:** tdd
**Phase:** finish
**Repos:** orchestrator,pennyfarthing
**Branch:** feature/42-3-variance-cv-reduction
**Assigned:** claude

## Story Context

Variance test: measure CV reduction. Priority p1, 1 story point. TDD workflow — write failing tests first, then implement to green, verify, and review.

No story-level or epic-level context files exist yet. The next agent (TEA) should establish acceptance criteria and test specifications during the red phase.

## Technical Approach

Context needs to be established by the TEA agent during the red phase. This story is part of Epic 42 (Anchored Rubric Criteria) and focuses on measuring coefficient of variation (CV) reduction in variance testing.

## SM Assessment

Story 42-3 is a 1-point TDD story to measure CV (coefficient of variation) reduction in variance tests. Session created, branch `feature/42-3-variance-cv-reduction` cut from `develop` in pennyfarthing repo, Jira MSSCI-16221 claimed and moved to In Progress. No existing story or epic context files — TEA will need to establish test specifications during the red phase. Routing to TEA (Sam Seaborn) for test design.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core validation story — must prove anchored rubrics reduce scoring variance

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_variance_cv.py` — 26 tests (new)
- `pennyfarthing-dist/src/pf/benchmark/variance_cv.py` — stub module (new)

**Tests Written:** 26 tests covering 2 ACs
- AC1 (CV comparison): `TestCalculateCV` (6), `TestCompareCV` (6), `TestDimensionCV` (1), `TestGenerateCVReport` (7)
- AC2 (Statistical significance): sample size caveat tests (2), markdown caveat section (1)
- Edge cases: zero mean, near-zero mean, negative scores, single dimension (4)

**Status:** RED (26 failing — all `NotImplementedError`, confirmed by test runner)

**Module API:**
- `calculate_cv(scores) -> float` — CV = std_dev / mean
- `compare_cv(pre, post) -> list[CVComparison]` — per-dimension comparison
- `generate_cv_report(pre, post) -> CVReport` — full report with markdown output
- `DimensionCV` dataclass with computed properties (cv, mean, n)
- `CVReport.to_markdown()` — table with before/after CV and percentage change

**Handoff:** To Toby Ziegler (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/benchmark/variance_cv.py` — full implementation replacing stubs

**Tests:** 26/26 passing (GREEN)
**Branch:** feature/42-3-variance-cv-reduction (pushed)

**Implementation Notes:**
- `calculate_cv`: population std_dev / mean, returns 0.0 for empty/single/zero-mean
- `compare_cv`: per-dimension comparison with percentage change; handles zero pre_cv edge case (reports 100% increase)
- `generate_cv_report`: aggregates comparisons, computes overall change, sets sample size caveat when max N < 30
- `CVReport.to_markdown()`: formatted table with Pre/Post-Anchor CV, change %, and caveat section

**Handoff:** To Sam Seaborn (TEA) for verify phase

## TEA Verify Assessment

**Tests:** 26/26 passing (GREEN confirmed after simplify)

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 2

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 3 findings | 1 high: duplicated std_dev logic; 2 low: intra-file mean dup, test mirrors formula |
| simplify-quality | 3 findings | 1 medium: population vs sample variance; 2 low: KeyError convention, naming |
| simplify-efficiency | 2 findings | 1 medium: DimensionCV unused by pipeline; 1 low: redundant bool field |

**Applied:** 1 high-confidence fix (reuse `calculate_std_dev` from `aggregator.py`)
**Flagged for Review:** 2 medium-confidence findings (population vs sample variance; DimensionCV unused)
**Noted:** 5 low-confidence observations
**Reverted:** 0

**Overall:** simplify: applied 1 fix

**Handoff:** To Josh Lyman (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `list[float]` → `calculate_cv` → `calculate_std_dev` (aggregator reuse) → `std_dev/mean` — internal data, no sanitization needed
**Pattern observed:** Good reuse of sibling module at `variance_cv.py:11` (import from aggregator)
**Error handling:** Zero mean → 0.0, empty/single → 0.0, missing dim → KeyError (tested). All at `variance_cv.py:80-87`
**Tests:** 26/26 passing, clean TDD progression (3 commits)
**Observations:** 5 total — 0 critical, 0 high, 0 medium, 2 low (DimensionCV unused by pipeline; averaging percentages)

**Handoff:** To Leo McGarry (SM) for finish-story

## Delivery Findings

<!-- delivery-findings -->
### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- No upstream findings during implementation.

### TEA (test verification)
- **Question** (non-blocking): Population variance (N) vs sample variance (N-1) in `calculate_cv`. Sibling `calculate_std_dev` in aggregator.py also uses population variance, so this is consistent within the package, but sample variance may be more statistically appropriate for small judge panels. Affects `pennyfarthing-dist/src/pf/benchmark/variance_cv.py` (divisor in std_dev calc). *Found by TEA during test verification.*

### Reviewer (code review)
- No upstream findings during code review.

## Session Log

- **Setup:** Session created by SM
- **RED:** 26 failing tests written, stub module created, committed on `feature/42-3-variance-cv-reduction`
- **GREEN:** Implementation complete, 26/26 passing, branch pushed
- **VERIFY:** Simplify applied 1 fix (reuse calculate_std_dev), 26/26 still green, pushed
- **REVIEW:** Approved — no blocking issues, clean implementation