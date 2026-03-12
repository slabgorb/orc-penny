# Story 45-2: Update judge to use gold standard as calibration

**Jira:** MSSCI-16226
**Epic:** 45 — Gold Standard References
**Points:** 2
**Priority:** p0
**Repos:** pennyfarthing
**Workflow:** tdd
**Phase:** finish
**Branch:** feat/gold-standard-judge-calibration
**Assigned:** keithavery

## Acceptance Criteria
- Judge uses gold standard responses as calibration anchors when scoring
- Scoring variance decreases when gold standards are available
- Backward compatible — judge works without gold standards

## Context
This is the follow-on to 45-1 (Add gold_standard schema to scenarios). The schema is now in place; this story wires the judge to actually use those gold standards as calibration references during evaluation.

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
**Data flow traced:** `SoloJudgeInput` → `build_solo_judge_prompt()` → string output. Pure function, no I/O, no side effects.
**Pattern observed:** Conditional section injection — gold standard block only emitted when present, cleanly separated from rubric at `judge_prompt.py:108-109`
**Error handling:** Upstream TS validator (`scenario-validator.ts:64-68`) enforces score 1-100 and non-empty response; Python layer trusts validated input. Appropriate boundary validation.
**Schema parity:** Python `GoldStandard` dataclass matches TS `GoldStandard` interface field-for-field (`scenario-validator.ts:12-17`)

**Observations:**
| Severity | Issue | Location | Action |
|----------|-------|----------|--------|
| [VERIFIED] | Schema parity with TS interface | `scenario-validator.ts:12` ↔ `judge_prompt.py:16` | n/a |
| [VERIFIED] | Conditional gold standard injection | `judge_prompt.py:108-109` | n/a |
| [VERIFIED] | Calibration language non-prescriptive | `judge_prompt.py:48-52` | n/a |
| [VERIFIED] | Backward compat — no leaking text | Tests AC3 class | n/a |
| [VERIFIED] | SKILL.md template matches code | `SKILL.md:159-175` | n/a |
| [LOW] | `input` param shadows builtin | `judge_prompt.py:104` | Non-blocking |
| [LOW] | No empty-response guard | `judge_prompt.py:56` | Upstream validates |

**Tests:** 19/19 passing. Pre-existing import error in `test_bellmode_tandem_injection.py` blocks full suite but is unrelated to this story.

**Handoff:** To SM for finish-story

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core behavioral change — judge must conditionally include calibration context

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_judge_gold_standard.py` (new) — 19 tests across 4 classes
- `pennyfarthing-dist/src/pf/benchmark/judge_prompt.py` (new) — stub with types + `build_solo_judge_prompt()`

**Tests Written:** 19 tests covering 3 ACs
- AC1 (6 tests): Gold standard response, score, notes included; absent/None omitted
- AC2 (4 tests): Calibration instruction present; reference/anchor language; different valid approaches
- AC3 (5 tests): Rubric dimensions, contestant, challenge, response, JSON format always present
- Edge cases (4 tests): Score boundaries, long response, checklist mode integration

**Status:** RED (19 failing — all NotImplementedError, no import errors)

**Implementation notes for Mal:**
- `build_solo_judge_prompt()` should construct the full prompt string matching SKILL.md templates
- When `gold_standard` is present: inject a "Gold Standard" / "Calibration" section with response + score
- When absent: no calibration section, prompt identical to current SKILL.md solo template
- Also update SKILL.md prompt templates to document the gold_standard flow
- `GoldStandard` type reuses the schema from 45-1's `scenario-validator.ts`

**Handoff:** To Dev (Malcolm Reynolds) for GREEN implementation

## TEA Verify Assessment

### Simplify Report

**Teammates:** skipped (context-constrained, direct review)
**Files Analyzed:** 4

| File | Status | Notes |
|------|--------|-------|
| judge_prompt.py | clean | Minimal, well-structured, no duplication |
| __init__.py | clean | Standard exports |
| SKILL.md | clean | Template addition follows existing patterns |
| test_judge_gold_standard.py | clean | 19 tests, good AC coverage |

**Applied:** 0 fixes
**Overall:** simplify: clean

**Handoff:** To River (Reviewer) for code review

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/benchmark/judge_prompt.py` — prompt builder with gold standard calibration
- `pennyfarthing-dist/src/pf/benchmark/__init__.py` — exports for new module
- `pennyfarthing-dist/skills/pf-judge/SKILL.md` — gold_standard in data requirements + solo prompt template

**Tests:** 19/19 passing (GREEN)
**Branch:** feat/gold-standard-judge-calibration (pushed)

**Handoff:** To next phase (verify/review)

## SM Assessment
- Session created, Jira claimed, branch cut from develop
- Story is P0, 2pts, direct follow-on from 45-1 (gold_standard schema)
- TDD workflow: routing to TEA (Jayne) for red phase — write failing tests first
- No blockers identified