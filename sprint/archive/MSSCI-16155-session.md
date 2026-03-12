# Story 141-21: Extract Hardcoded Values and Relocate Misplaced Business Logic

**Jira:** MSSCI-16155
**Workflow:** tdd
**Phase:** finish
**Repos:** orchestrator,pennyfarthing
**Branch:** feature/141-21-extract-hardcoded-values
**Assigned:** keith.avery@1898andco.io

## Story Context

Cleanup story for hardcoded values and misplaced business logic found during the audit. Two remaining items after trivial items were absorbed into adjacent stories (141-17, 141-18):

**1. Agent evaluation in the wrong package:** `packages/cyclist/src/agent-evaluation.ts` (644 lines) is a full Job Fair benchmarking engine with scoring, regression detection, and persona comparisons. It belongs in `packages/benchmark` or `packages/core/src/benchmark/`, not in the GUI package.

**2. Settings migration unreachable from Python:** `packages/core/src/server/settings.ts` contains `migrateSettings()` handling four legacy config shapes. The Python `pf` CLI reads config directly and has no migration path, so legacy configs are silently misread.

### Acceptance Criteria

**AC1:** `agent-evaluation.ts` moved out of `packages/cyclist/src/` into either `packages/benchmark/` (new package) or `packages/core/src/benchmark/` (adjacent to existing `benchmark-integration.ts`). Build succeeds in both core and cyclist after move.

**AC2:** Python-callable `migrate_settings(raw: dict) -> dict` function in `pennyfarthing-dist/pf/` that applies the same four legacy-format migrations as the TypeScript `migrateSettings()`:
1. `permission_mode: turbo` -> `permission_mode: accept` + `relay_mode: true`
2. `handoff_mode: auto` -> `relay_mode: true`
3. `handoff_mode: manual` -> `relay_mode: false`
4. `auto_handoff: true/false` -> `relay_mode: true/false`

### Out of Scope
- Changing evaluation scoring logic (relocation only, not rewrite)
- `toSlug()`/`oceanSuffix()` dedup (absorbed into 141-17)
- Token limits (absorbed into 141-18)
- Destructive removal of legacy config keys

## SM Assessment
Ready for TEA phase. Story involves two well-scoped refactoring tasks suitable for TDD approach: relocating a module and implementing a Python migration function with clear specs from the existing TypeScript implementation.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Both ACs have clear testable outcomes — file relocation and function behavior

**Test Files:**
- `packages/core/src/benchmark/agent-evaluation.test.ts` — AC1: verifies agent-evaluation.ts relocated from cyclist to core/benchmark, all 19 exports importable, cyclist source removed
- `pennyfarthing-dist/src/pf/tests/test_settings_migration.py` — AC2: exercises all 4 legacy migration paths (turbo, handoff_mode auto/manual, auto_handoff bool), precedence rules, edge cases

**Tests Written:** 22 TypeScript + 21 Python = 43 tests covering 2 ACs
**Status:** RED (failing — ready for Dev)
- AC1: 21/22 fail with ERR_MODULE_NOT_FOUND (module not yet relocated)
- AC2: 21 fail with ModuleNotFoundError (pf.settings_migration not yet created)

**Handoff:** To Dev (Malcolm Reynolds) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/benchmark/agent-evaluation.ts` — relocated from cyclist (644 lines, no logic changes)
- `packages/core/src/benchmark/telemetry-types.ts` — copied from cyclist (type definitions for compilation)
- `packages/core/src/benchmark/agent-evaluation.test.ts` — fixed __dirname resolution for dist/src mapping
- `packages/core/src/server/agent-evaluation.ts` — updated stub to re-export from benchmark module
- `packages/core/src/server/api/evaluation.ts` — fixed route handlers to use correct function signatures
- `pennyfarthing-dist/src/pf/settings_migration.py` — new: migrate_settings() with 4 legacy transforms

**Tests:** 46/46 passing (GREEN) — 22 TypeScript + 24 Python
**Branch:** feature/141-21-extract-hardcoded-values (pushed)

**Handoff:** To verify phase (TEA)

## TEA Verify Assessment

### Simplify Report

**Teammates:** skipped (relocation story — minimal new logic)
**Files Analyzed:** 4 non-test files (2 pure relocations, 1 stub update, 1 route fix)

**Applied:** 0 high-confidence fixes
**Flagged for Review:** 0
**Noted:** 0

**Overall:** simplify: clean — agent-evaluation.ts/telemetry-types.ts are unmodified relocations, settings_migration.py is a clean 50-line module

**Quality-Pass:** 46/46 tests GREEN (22 TS + 24 Python)
**Handoff:** To River Tam for code review

## Delivery Findings
<!-- Append findings below. Do not edit other agents' entries. -->
### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- **Improvement** (non-blocking): The evaluation route (`server/api/evaluation.ts`) was calling `detectTrend(results)` and `generateRecommendations(results)` with wrong types — the stub signatures didn't match the real module. Fixed to use correct signatures. Affects `packages/core/src/server/api/evaluation.ts` (route now uses query param for agent role and getEvaluation() for recommendations). *Found by Dev during implementation.*

### TEA (test verification)
- No upstream findings during test verification.

### Reviewer (code review)
- **Improvement** (non-blocking): Unused `valid_modes` variable in `settings_migration.py:46`. Affects `pennyfarthing-dist/src/pf/settings_migration.py` (remove or use the tuple). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** config.local.yaml → YAML parse → migrate_settings(raw) → deepcopy → transform workflow keys → return new dict (safe, no side effects)
**Pattern observed:** Clean relocation with re-export stub at `packages/core/src/server/agent-evaluation.ts:7-10`
**Error handling:** Python handles missing/non-dict workflow gracefully; route handlers null-check evaluation before use at `evaluation.ts:37`
**Handoff:** To Zoe Washburne for finish-story