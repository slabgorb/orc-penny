# Story: 46-1 — Add difficulty_profile schema to scenarios

**Status:** in-progress
**Phase:** finish
**Workflow:** tdd
**Repos:** orchestrator,pennyfarthing
**Branch:** feat/difficulty-profile-schema
**Jira:** PROJ-16229

## Context

Without difficulty metadata, benchmark results conflate easy and hard scenarios in aggregate statistics. A mean score of 75 across easy scenarios is very different from 75 across hard ones. This story adds a `difficulty_profile` field to scenario YAML, enabling stratified analysis.

### Schema Design

```yaml
difficulty_profile:
  tier: medium
  dimensions:
    code_complexity: 6
    domain_knowledge: 4
    red_herring_count: 2
    issue_subtlety: 5
  calibration:
    control_mean: 72.5
    control_stddev: 8.3
    n_runs: 4
```

### Key Constraints

- `difficulty_profile` is optional (backward compatible)
- `tier` is enum: easy, medium, hard, extreme
- `dimensions` are all optional numeric 1-10 scales
- `calibration` is populated from baseline data (46-2), can be empty initially

### Acceptance Criteria

- Schema accepts difficulty_profile with valid tier, dimensions, calibration
- Scenario without difficulty_profile still validates
- Invalid tier value rejects
- Dimension value outside 1-10 rejects
- Partial profile (tier only, no dimensions) validates

### Scope Boundaries

**In scope:** difficulty_profile schema field, validation, backward compatibility
**Out of scope:** Populating profiles (46-2), schema documentation (46-3)

## SM Assessment

Story 46-1 is set up and ready for TDD. Session created, Jira claimed (PROJ-16229), branches created in both repos. Context file exists with clear schema design, ACs, and scope boundaries. Handing off to TEA for red phase — test design for difficulty_profile schema validation.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Schema validation for new difficulty_profile field requires coverage of all ACs

**Test Files:**
- `packages/core/src/benchmark/scenario-validator.test.ts` - 24 tests across 6 suites
- `packages/core/src/benchmark/scenario-validator.ts` - Stub with types and interfaces

**Tests Written:** 24 tests covering 5 ACs
**Status:** RED (all 24 failing with "not implemented" — correct RED state)

**AC Coverage:**
| AC | Tests | Suite |
|----|-------|-------|
| Schema accepts difficulty_profile | 3 | difficulty_profile acceptance |
| Scenario without difficulty_profile validates | 2 | backward compatibility |
| Invalid tier value rejects | 3 | invalid tier rejection |
| Dimension value outside 1-10 rejects | 5 | dimension value validation |
| Partial profile validates | 5 | partial profiles |
| Standalone validateDifficultyProfile | 6 | validateDifficultyProfile |

**Edge cases covered:** boundary values (1, 10), negative values, fractional values, non-numeric types, empty strings, null/non-object inputs, unknown dimension keys, negative calibration values, partial calibration.

**Note:** Tests run with `npx tsx --test` (not compiled `node --test`) since `.js` ESM resolution requires build step. Dev should ensure build passes.

**Handoff:** To Dev (Malcolm Reynolds) for implementation

## Delivery Findings

### TEA (test design)
- **Improvement** (non-blocking): Scenario source files don't exist in the framework source tree — only in the asar bundle at `packages/cyclist/release/`. Dev should create `packages/core/scenarios/` as source of truth and add it to the build pipeline. Affects `packages/core/` (needs scenarios directory in source).
  *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/benchmark/scenario-validator.ts` — Implemented `validateScenario` and `validateDifficultyProfile` with tier enum validation, dimension range checks (integer 1-10), calibration non-negative checks, and unknown key rejection.

**Tests:** 24/24 passing (GREEN)
**Branch:** feat/difficulty-profile-schema (pushed)

**Handoff:** To River Tam (Reviewer) for code review

## TEA Verify Assessment

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 2

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 1 finding | ValidationResult interface duplicated across 4 files (medium) |
| simplify-quality | 4 findings | 2 high (type-safe constants), 2 low (acceptable patterns) |
| simplify-efficiency | clean | No issues |

**Applied:** 2 high-confidence fixes (type-safe `VALID_TIERS` and `VALID_DIMENSION_KEYS` arrays)
**Flagged for Review:** 1 medium-confidence finding (ValidationResult consolidation — cross-module dependency trade-off)
**Noted:** 2 low-confidence observations (runtime `as Record` casts are safe after guards; `as any` in tests is standard)
**Reverted:** 0

**Overall:** simplify: applied 2 fixes

**Tests:** 24/24 passing after simplify (regression check passed)
**Branch:** feat/difficulty-profile-schema (pushed)

**Handoff:** To River Tam (Reviewer) for code review

### TEA (test verification)
- No upstream findings during test verification.

### Reviewer (code review)
- **Improvement** (non-blocking): `scenario-validator.ts` not re-exported from `packages/core/src/benchmark/index.ts`. Story 46-2 will need the barrel export to use validation in scenario population. Affects `packages/core/src/benchmark/index.ts` (add re-exports).
  *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. `[VERIFIED]` AC coverage — all 5 ACs have tests (24/24 GREEN), implementation matches spec
2. `[VERIFIED]` Data flow — `ScenarioData.difficulty_profile` → null guard → `validateDifficultyProfile()` → accumulated errors → `ValidationResult`. Pure functions, no side effects
3. `[VERIFIED]` Error handling — never throws, `== null` guards catch both null/undefined, errors accumulate across all validation sections
4. `[MEDIUM]` Not exported from barrel `index.ts` — acceptable for 46-1 scope, flagged for 46-2
5. `[LOW]` Calibration accepts unknown keys — by design, calibration schema will tighten in 46-2
6. `[VERIFIED]` Type safety — `VALID_TIERS` and `VALID_DIMENSION_KEYS` use typed arrays synced to interfaces
7. `[VERIFIED]` No forbidden patterns (console.log, debugger, TODO, t.Skip)

**No Critical or High issues.**

**Handoff:** To Zoe Washburne (SM) for finish