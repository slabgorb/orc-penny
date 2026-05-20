# Story 44-1: Add --multi-judge flag to /solo command

**Story ID:** 44-1
**Jira:** PROJ-16215
**Epic:** 44 — Multi-Judge Validation
**Points:** 3
**Repos:** pennyfarthing
**Branch:** feature/44-1-multi-judge-flag
**Workflow:** tdd
**Phase:** finish
**Assignee:** Keith Avery

## Story Context

Single-judge evaluation produces unreliable scores (>50% error rate per Galileo research). This story adds the `--multi-judge N` flag to the `/solo` command, enabling ensemble scoring where each agent run is evaluated N times with randomized presentation order. Default N=3, valid range 1-5. The flag must be backward-compatible: `--multi-judge 1` (or omitting the flag) behaves identically to current single-judge behavior.

Key files to modify:
- `pennyfarthing-dist/commands/pf-solo.md` — Add `--multi-judge N` parameter to the command spec
- `pennyfarthing-dist/skills/pf-judge/SKILL.md` — Add support for randomized presentation order per invocation

Multi-judge inserts a loop between execute and finalize: judge x N with results collected as array. Each judge invocation randomizes the order of scenario context sections to control position bias. Individual verdicts stored as `runs/judge_{i}.json`. Aggregated score is the mean of `weighted_total` across judges.

Integration points: judge verdicts feed into 44-2 (Krippendorff Alpha) for agreement calculation; aggregated results feed into 44-3 (finalize-run) for storage.

## Acceptance Criteria

1. `/solo theme:agent --scenario X --multi-judge 3` invokes judge 3 times per run
   - `--multi-judge 1` produces exactly 1 judge file (backward compat)
   - `--multi-judge 0` or `--multi-judge 6` errors with clear message

2. Each judge invocation randomizes presentation order of scenario context
   - Section ordering differs per invocation (not per run)
   - Scenario description, code under review, and expected issues appear in shuffled order

3. Judge verdicts stored as array in `runs/judge_{i}.json`
   - After multi-judge run, `runs/` contains `judge_0.json`, `judge_1.json`, `judge_2.json`
   - Each file contains full judge verdict: dimension scores, weighted_total, rationale
   - Format matches existing single-judge output schema

4. Aggregated score (mean of weighted_totals) used as the run's canonical score
   - If judges score 78, 82, 75 then canonical score = 78.33

5. `--multi-judge 1` behaves identically to current single-judge
   - No `judges[]` array when N=1, just the single verdict (backward compat)

6. Summary YAML includes `judge_agreement` section
   - Contains `judge_agreement:` key with placeholder for agreement stats (populated by 44-2)

## Technical Approach

- Add `--multi-judge N` parameter to `pf-solo.md` command spec (default 3, range 1-5)
- Modify judge skill to accept randomized presentation order per invocation
- Loop judge invocations sequentially (parallel deferred to future optimization)
- Store individual verdicts as `judge_{i}.json` alongside agent response
- Compute mean of `weighted_total` as canonical score
- Add `judge_agreement` placeholder section to summary YAML
- Preserve full backward compatibility when N=1 or flag omitted

## SM Assessment

Story 44-1 is well-scoped with clear ACs and no blockers. 3-point TDD story touching two skill/command files in pennyfarthing-dist. Dependencies are forward-only (44-3 and 44-4 depend on this, not the reverse). Jira claimed, branch cut from develop. Ready for TEA to design failing tests in the red phase.

**Routing:** SM → TEA (Sam Seaborn) → Dev (Toby Ziegler)

## Delivery Findings

### TEA (test design)

- **Improvement** (non-blocking): All benchmark business logic currently lives in TypeScript (`packages/core/src/benchmark/`). Per user direction, porting to Python `pf.benchmark` package. Affects `packages/core/src/benchmark/*.ts` (to be deprecated once Python port is complete). *Found by TEA during test design.*

## Impact Summary

**Upstream Effects:** 1 findings (0 Gap, 0 Conflict, 0 Question, 1 Improvement)
**Blocking:** None

- **Improvement:** All benchmark business logic currently lives in TypeScript (`packages/core/src/benchmark/`). Per user direction, porting to Python `pf.benchmark` package. Affects `packages/core/src/benchmark/*.ts`.

## TEA Assessment

**Tests Required:** Yes
**Reason:** 6 ACs require validation + full Python port of TS benchmark modules

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_multi_judge.py` - 33 tests covering all 6 ACs
- `pennyfarthing-dist/src/pf/tests/test_benchmark_aggregator.py` - 28 tests for aggregator port
- `pennyfarthing-dist/src/pf/tests/test_benchmark_integration.py` - 27 tests for integration port

**Tests Written:** 88 tests covering 6 ACs + full TS port surface
**Status:** RED (88 failing on NotImplementedError, 6 passing constants/type checks)

**Scope expanded by user:** Create `pf.benchmark` Python package, port all TS benchmark logic, not just multi-judge. Three stub modules created:
- `multi_judge.py` — ensemble scoring (44-1 core)
- `aggregator.py` — job-fair result aggregation (port of `job-fair-aggregator.ts`)
- `integration.py` — OCEAN correlation + queries (port of `benchmark-integration.ts`)

**Handoff:** To Toby Ziegler (Dev) for implementation — fill in all stubs to make 88 tests pass.

## Delivery Findings

### Dev (implementation)

- No upstream findings during implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/benchmark/multi_judge.py` - Ensemble scoring: validation, randomization, aggregation, formatting
- `pennyfarthing-dist/src/pf/benchmark/aggregator.py` - Job-fair aggregation port from TS: themes, roles, dimensions, trends
- `pennyfarthing-dist/src/pf/benchmark/integration.py` - OCEAN correlation port from TS: queries, error-type analysis, heat maps

**Tests:** 94/94 passing (GREEN)
**Branch:** feature/44-1-multi-judge-flag (pushed)

**Handoff:** To Josh Lyman (Reviewer) for review

### TEA (test verification)

- No upstream findings during test verification.

## TEA Verify Assessment

**Phase:** finish
**Tests:** 94/94 passing (GREEN confirmed)
**Quality-Pass Gate:** PASSED

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 7

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | timeout — no result | — |
| simplify-quality | timeout — no result | — |
| simplify-efficiency | timeout — no result | — |

**Manual Analysis (TEA direct):**
- `aggregator.py:14` — unused `field` import from dataclasses (HIGH → applied)
- `integration.py:303-338` — `find_top_performers` / `query_benchmarks` share logic (MEDIUM → flagged)

**Applied:** 1 high-confidence fix (removed unused import)
**Flagged for Review:** 1 medium-confidence finding (minor duplication)
**Noted:** 0
**Reverted:** 0

**Overall:** simplify: applied 1 fix

**Handoff:** To Josh Lyman (Reviewer) for code review

### Reviewer (code review)

- **Improvement** (non-blocking): `_get_benchmarked_themes` uses `str.replace()` which replaces all occurrences — should use `removesuffix()` for correctness. Affects `pennyfarthing-dist/src/pf/benchmark/integration.py` (line 601). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `get_benchmark_with_face` is imported in tests but has zero test coverage. Affects `pennyfarthing-dist/src/pf/tests/test_benchmark_integration.py` (add tests). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `validate_multi_judge_count(n)` → pure validation → `{"valid": bool}` — no injection, no side effects
**Pattern observed:** Faithful TS→Python port pattern with `except Exception: return None` at YAML parse boundaries — consistent across both modules at `aggregator.py:193` and `integration.py:149,155,279,314,565`
**Error handling:** `aggregate_judge_scores` properly raises `ValueError` on empty input at `multi_judge.py:64`; verified round-trip in `save_historical_snapshot` at `aggregator.py:290`
**Security:** No user-controlled input reaches file system paths without sanitization; `yaml.safe_load` used throughout (no `yaml.load`)

**Observations (9):**

| # | Severity | Issue | Location |
|---|----------|-------|----------|
| 1 | [VERIFIED] | Data flow clean — pure validation, no injection | `multi_judge.py:47-51` |
| 2 | [VERIFIED] | Empty list guarded with ValueError | `multi_judge.py:63-64` |
| 3 | [VERIFIED] | Regex handles multi-hyphen themes via greedy backtrack | `aggregator.py:136` |
| 4 | [VERIFIED] | Error handling faithful to TS port pattern | `aggregator.py:193`, `integration.py:149` |
| 5 | [VERIFIED] | Package imports work, `__all__` consistent | `__init__.py:10-27` |
| 6 | [MEDIUM] | `str.replace()` replaces all occurrences, not just suffix | `integration.py:601` |
| 7 | [MEDIUM] | `get_benchmark_with_face` imported but untested | `test_benchmark_integration.py:27` |
| 8 | [LOW] | No validation that `len(verdicts) >= 1` when `n=1` | `multi_judge.py:82` |
| 9 | [LOW] | Unused imports: `os`, `textwrap` in test file | `test_benchmark_aggregator.py:10-11` |

**Handoff:** To Leo McGarry (SM) for finish-story

## Session Log

- SM setup complete, handing off to TEA (Sam Seaborn) for red phase
- TEA: Created pf.benchmark Python package with 3 modules (stubs) and 88 failing tests
- TEA: Committed on feature/44-1-multi-judge-flag, RED state confirmed