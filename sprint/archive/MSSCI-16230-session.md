# Story 46-2: Populate difficulty profiles from baseline data

**Jira:** MSSCI-16230
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/difficulty-profile-populate
**Assignee:** K. Avery

## Context

Epic 46 adds structured difficulty metadata to benchmark scenarios so results can be stratified by difficulty tier (easy/medium/hard/extreme). This enables analysis of how agent performance and judge agreement vary across difficulty levels, and directly supports the context collapse research showing personas abandon character-specific reasoning under high cognitive load.

Story 46-2 derives difficulty profiles empirically from existing control baseline data rather than manual guessing. Scenarios where control agents score high are "easy"; scenarios with low means or high variance are "hard." This data-driven approach produces accurate, defensible tier assignments.

## Acceptance Criteria

**AC: All scenarios with baseline data get difficulty profiles**
- Test: Every scenario YAML that has control results in internal/results/ gets a difficulty_profile
- Test: Tier assignments match algorithm output

**AC: Calibration section populated from real data**
- Test: control_mean and control_stddev match actual values from baseline results
- Test: n_runs matches actual run count

**AC: Tier assignments are defensible**
- Test: Easy scenarios have high control means; hard scenarios have low means or high variance
- Document any edge cases or manual overrides with reasoning

## Technical Notes

- Story 46-1 (difficulty_profile schema) is on unmerged branch `feat/difficulty-profile-schema` — need to cherry-pick or merge those changes
- Control baseline data exists for 5 scenarios in internal/results/benchmarks/:
  - astropy-12907/control-dev (mean: 60.55, stddev: 7.53, n: 9)
  - legacy-modernization/control-architect (mean: 74.25, stddev: 4.19, n: 10)
  - order-service/control-reviewer (mean: 71.75, stddev: 1.95, n: 10)
  - sprint-planning-conflict/control-sm (mean: 81.42, stddev: 4.40, n: 7)
  - tdd-shopping-cart/control-dev (mean: 61.00, stddev: 8.67, n: 10)
- Only 2 have matching test-case YAMLs in benchmarks/test-cases/:
  - order-service → cr-002-order-service.yaml
  - tdd-shopping-cart → dev-002-tdd-shopping-cart.yaml
- Tier algorithm: easy (mean>=80, stddev<8), medium (65-79, stddev<12), hard (50-64 OR stddev>=12), extreme (mean<50)

## TEA Assessment

**Tests Required:** Yes
**Reason:** Tier computation algorithm needs verified correctness — wrong tier = misleading analysis

**Test Files:**
- `packages/core/src/benchmark/difficulty-profiler.test.ts` - 26 tests for computeTier and computeDifficultyProfile

**Tests Written:** 26 tests covering 3 ACs
- AC1 (scenarios get profiles): Tests verify computeDifficultyProfile returns complete profile with correct tier
- AC2 (calibration from real data): Tests verify calibration fields match input stats exactly
- AC3 (defensible tiers): Tests verify all 5 known control baselines produce correct tiers per algorithm

**Status:** RED (26 failing — stubs throw 'not implemented')

**Handoff:** To Dev (Malcolm Reynolds) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/benchmark/difficulty-profiler.ts` - Implemented computeTier and computeDifficultyProfile
- `benchmarks/test-cases/code-review/cr-002-order-service.yaml` - Added difficulty_profile (medium, control_mean=71.75)
- `benchmarks/test-cases/dev/dev-002-tdd-shopping-cart.yaml` - Added difficulty_profile (hard, control_mean=61.00)

**Tests:** 26/26 passing (GREEN)
**Branch:** feat/difficulty-profile-populate (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** ControlStats → computeTier → tier enum, ControlStats → computeDifficultyProfile → DifficultyProfile object → YAML files (safe — pure computation, no side effects)
**Pattern observed:** Minimal implementation matching spec exactly at `difficulty-profiler.ts:56-60`
**Error handling:** Pure functions with no I/O — no error paths needed. Types enforce valid inputs.
**Tests:** 26/26 covering all tier boundaries, real data, and calibration passthrough
**Observations:** 7 (2 non-blocking findings logged, 5 verified-good)

**Handoff:** To SM (Zoe Washburne) for finish-story

## Delivery Findings

<!-- Append-only: each agent adds findings under their subheading -->

### Reviewer (code review)
- **Question** (non-blocking): Easy tier spec says `stddev < 8` but algorithm has no explicit medium-between-easy-and-hard for mean>=80 with stddev 8-11.99. Current impl treats this as `easy`. No real data hits this gap. Affects `packages/core/src/benchmark/difficulty-profiler.ts` (clarify spec if edge case emerges). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `cr-002-order-service.yaml` has `difficulty: hard` but `difficulty_profile.tier: medium` — old manual vs new empirical. Consider reconciling in 46-3. Affects `benchmarks/test-cases/code-review/cr-002-order-service.yaml` (update legacy `difficulty` field). *Found by Reviewer during code review.*

### Dev (implementation)
- No upstream findings during implementation.

### TEA (test design)
- **Gap** (non-blocking): Story 46-1 schema validation (`validateDifficultyProfile`) is on unmerged branch `feat/difficulty-profile-schema`. Dev will need to cherry-pick or reimplement. Affects `packages/core/src/benchmark/scenario-validator.ts` (needs difficulty_profile validation added). *Found by TEA during test design.*