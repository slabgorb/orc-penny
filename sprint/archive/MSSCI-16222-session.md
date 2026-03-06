# Story: 43-1 — Add red_herrings schema to scenarios

**Status:** in-progress
**Phase:** finish
**Workflow:** tdd
**Repos:** orchestrator,pennyfarthing
**Branch:** feat/red-herrings-schema
**Jira:** MSSCI-16222

<session story="43-1" workflow="tdd">
  <meta>
    <jira>MSSCI-16222</jira>
    <epic>MSSCI-16211</epic>
    <points>2</points>
    <started>2026-03-06</started>
  </meta>

  <status phase="setup" next-agent="tea" handoff-ready="false"/>

  <acceptance-criteria>
    <ac id="1" status="pending">Schema accepts red_herrings array with valid entries (type, description, severity)</ac>
    <ac id="2" status="pending">Scenario without red_herrings still validates (backward compatible)</ac>
    <ac id="3" status="pending">Invalid red_herring entry rejects (missing required fields)</ac>
    <ac id="4" status="pending">Partial red_herring (type only, no description) validates or rejects per schema rules</ac>
  </acceptance-criteria>

  <context>
    Epic 43: False Positive Traps (Red Herrings) — adds red herring metadata to benchmark scenarios
    so the judge can evaluate whether agents correctly ignore misleading signals.

    This story (43-1) adds the `red_herrings` schema field to scenario YAML validation.
    Follow-up stories: 43-2 updates the judge for red herring detection, 43-3 pilots red herrings
    in the order-service scenario.

    Sister epic pattern: follows the same approach as 46-1 (difficulty_profile schema) —
    schema first, then consumption, then pilot.

    Key files (likely):
    - `packages/core/src/benchmark/scenario-validator.ts` — existing scenario validation
    - `packages/core/src/benchmark/scenario-validator.test.ts` — existing tests
  </context>

## SM Assessment

Story 43-1 setup complete. 2pt TDD story in epic 43 (False Positive Traps). Adds `red_herrings` schema to benchmark scenario validation. Sister pattern to 46-1 (difficulty profiles). Repos: pennyfarthing. Jira MSSCI-16222 claimed and in-progress.

**Handoff:** To Jayne (TEA) for red phase — test design for schema validation.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Schema validation needs comprehensive coverage for red_herrings field

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_scenario_red_herrings.py` — 24 tests across 4 ACs
- `pennyfarthing-dist/src/pf/benchmark/scenario_validator.py` — stub module (NotImplementedError)

**Tests Written:** 24 tests covering 4 ACs
- AC1 (7 tests): Valid entries, all severity levels, empty array, full scenario integration
- AC2 (3 tests): Backward compat — scenarios without red_herrings, required-fields-only, with other optionals
- AC3 (9 tests): Invalid entries — missing fields, bad severity, wrong types, null, mixed valid/invalid
- AC4 (5 tests): Partial entries — type-only, two-of-three combos, extra fields OK, error indexing

**Status:** RED (24 failing — all NotImplementedError, no import/syntax errors)

**Key decisions:**
- Python-only per user directive — no JavaScript scenario validator
- New module `pf.benchmark.scenario_validator` with `validate_scenario()` and `validate_red_herrings()`
- Follows `{valid, errors}` result pattern consistent with existing `validate_multi_judge_count()`
- Severity enum: low/medium/high (not critical — that's for baseline_issues, not red herrings)
- Extra fields on red herring entries are accepted (forward-compatible for `expected_trap` in 43-2)

**Handoff:** To Mal (Dev) for GREEN implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/benchmark/scenario_validator.py` — implemented `validate_scenario()` and `validate_red_herrings()`

**Tests:** 24/24 passing (GREEN)
**Branch:** feat/red-herrings-schema (pushed)

**Implementation details:**
- `validate_red_herrings()`: validates list of dicts, checks required fields (type, description, severity), validates severity enum (low/medium/high), reports errors by index
- `validate_scenario()`: validates required scenario fields (name, title, category, difficulty, prompt), delegates to `validate_red_herrings()` when present
- Constants exported: `REQUIRED_SCENARIO_FIELDS`, `VALID_CATEGORIES`, `VALID_DIFFICULTIES`, `RED_HERRING_REQUIRED_FIELDS`, `VALID_SEVERITIES`
- Python-only, no JavaScript written

**Handoff:** To River (Reviewer) for code review

## Delivery Findings

### TEA (test design)
- **Gap** (non-blocking): No Python scenario validator existed prior to this story. The TS schema definition at `packages/core/scenarios/schema.yaml` only exists in the asar bundle, not in source. Dev should create the full scenario validator in Python, not just red_herrings. Affects `pennyfarthing-dist/src/pf/benchmark/scenario_validator.py` (needs full schema port eventually).
- **Gap** (non-blocking): `pf sprint work` is a stub — doesn't create session files or branches. SM had to work around it. Affects `pennyfarthing-dist/src/pf/sprint/work.py`.

### Dev (implementation)
- No upstream findings during implementation.

## TEA Verify Assessment

### Simplify Report

**Files Analyzed:** 2
- `pennyfarthing-dist/src/pf/benchmark/scenario_validator.py` (implementation)
- `pennyfarthing-dist/src/pf/tests/test_scenario_red_herrings.py` (tests)

**Manual review** (2-file change set, skipped subagent fan-out):
- No duplicated logic — single validation loop, no extraction needed
- No dead code — all constants used, no unused imports
- No over-engineering — minimal implementation, no unnecessary abstractions
- Error messages well-structured with indices

**Applied:** 0 fixes
**Overall:** simplify: clean

**Tests:** 24/24 passing (GREEN confirmed)
**Handoff:** To River (Reviewer) for code review

### TEA (test verification)
- No upstream findings during test verification.

## Reviewer Assessment

**Verdict:** APPROVED
**Reviewer:** River Tam (reviewer agent)

**Data flow traced:** `validate_scenario(dict)` → field presence check → optional `validate_red_herrings(list)` → per-entry field/enum validation → `{valid, errors}` return. No input mutation, no side effects, no exceptions thrown.

**Observations:**
1. [VERIFIED] Type guards on `validate_red_herrings` — None, non-list, non-dict entries all handled safely at `scenario_validator.py:55-64`
2. [VERIFIED] Error messages include entry index for debuggability at `scenario_validator.py:63,68`
3. [VERIFIED] Constants match TS schema.yaml enums — categories, difficulties, severities all correct
4. [VERIFIED] Backward compatible — `red_herrings` only validated when present (line 33)
5. [VERIFIED] `{valid, errors}` result pattern consistent with existing `validate_multi_judge_count()`
6. [LOW] `validate_scenario()` checks field presence but not types — `name: 123` passes. Acceptable: AC scope is red_herrings only, full type validation is future work.
7. [VERIFIED] Test coverage: 24 tests across all 4 ACs, including edge cases (None, strings, mixed valid/invalid arrays)

**Tests:** 24/24 passing
**Handoff:** To Zoe (SM) for finish-story

### Reviewer (code review)
- **Improvement** (non-blocking): `validate_scenario()` does not validate field types or enum values for top-level fields (category, difficulty). Acceptable for this story's scope but should be addressed when porting the full scenario schema. Affects `pennyfarthing-dist/src/pf/benchmark/scenario_validator.py` (add type/enum checks for required fields). *Found by Reviewer during code review.*

  <work-log>
    <entry agent="sm" date="2026-03-06">
      Story setup complete. Jira claimed (MSSCI-16222), session created.
      Epic context: False Positive Traps — red herring metadata for benchmark scenarios.
      Repos: orchestrator + pennyfarthing. Workflow: TDD.
      No story context file exists yet — TEA/Dev should reference session context above.
    </entry>
  </work-log>
</session>