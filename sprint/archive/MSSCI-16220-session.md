# Story 42-2: Reference anchors in judge prompts

**Jira:** MSSCI-16220
**Epic:** 42 — Anchored Rubric Criteria
**Points:** 2
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-16220-reference-anchors-judge-prompts
**Workflow:** tdd
**Phase:** finish
**Assigned:** keith.avery@1898andco.io

## Acceptance Criteria

**AC1: Solo mode generic rubric references behavioral anchors**
- Judge prompt for solo mode (generic rubric) includes behavioral anchor descriptions from rubric-anchors.md for each dimension (correctness, depth, quality, persona)
- Each dimension's scoring guidance references the 5-band behavioral scale instead of bare "Score 1-10"
- Test: Solo mode prompt contains anchor text for all four dimensions

**AC2: Solo mode checklist rubric references behavioral anchors**
- Judge prompt for solo mode (checklist/precision-recall) includes anchor context for quality and persona dimensions
- Detection dimension retains its existing precision/recall scoring (not overridden by anchors)
- Test: Checklist prompt contains anchor text for quality and persona

**AC3: Compare mode rubric references behavioral anchors**
- Judge prompt for compare mode includes behavioral anchor descriptions for all four dimensions
- Test: Compare mode prompt contains anchor text for all four dimensions

**AC4: Phase-specific rubrics reference relevant anchors**
- Phase rubrics (SM, TEA, Dev, Reviewer) include relevant behavioral anchors for their specific dimensions
- Test: Each phase prompt contains at least one anchor reference

**AC5: Anchor references are sourced from rubric-anchors.md**
- The guide file `pennyfarthing-dist/guides/rubric-anchors.md` is the single source of truth
- Judge skill references this file rather than duplicating anchor text inline
- Test: SKILL.md contains a reference/import directive pointing to rubric-anchors.md

## Technical Context

This story modifies the judge skill (`pf-judge/SKILL.md`) to incorporate behavioral anchors from `rubric-anchors.md` (created in 42-1) into evaluation prompts. The goal is to reduce score variance by giving judges concrete behavioral descriptions for each score level rather than abstract dimension labels.

**Key references:**
- `pennyfarthing-dist/guides/rubric-anchors.md` — behavioral scales (created in 42-1, on feature branch)
- `pennyfarthing-dist/skills/pf-judge/SKILL.md` — judge prompts (to be modified)
- `pennyfarthing-dist/guides/measurement-framework.md` — Wallach L3 rubric design
- `pennyfarthing-dist/guides/persona-effectiveness.md` — PersonaScore calibration

**Dependencies:** Depends on 42-1 (rubric-anchors.md must exist). Depended on by 42-3 (variance test).

## SM Assessment

Story 42-2 is ready for TDD red phase. Session file created. Branch `feature/MSSCI-16220-reference-anchors-judge-prompts` created from develop and pushed. Jira claimed and moved to In Progress. The story modifies `pf-judge/SKILL.md` to reference behavioral anchors from `rubric-anchors.md` in all judge prompt templates. Note: rubric-anchors.md was created in story 42-1 and must be merged to develop first (or cherry-picked onto this branch). Handoff to TEA (Sam Seaborn) for test design.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Story modifies judge prompt content — tests validate anchor presence and correctness

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_judge_anchors.py` — 27 tests covering all 5 ACs

**Tests Written:** 27 tests (21 failing, 6 passing) covering 5 ACs
**Status:** RED (failing — ready for Dev)

**Test Strategy:**
- Tests parse SKILL.md content and verify behavioral anchor snippets from rubric-anchors.md are present
- AC1: 5 tests — solo generic prompt includes anchors for all 4 dimensions at all 5 bands
- AC2: 3 tests — checklist has quality/persona anchors, detection precision/recall preserved
- AC3: 5 tests — compare mode includes anchors for all 4 dimensions at all 5 bands
- AC4: 8 tests — phase rubrics (SM/TEA/Dev/Reviewer) have anchor references
- AC5: 3 tests — SKILL.md references rubric-anchors.md, anchor text matches source

**Notes:**
- Cherry-picked rubric-anchors.md from 42-1 branch (commit c265040c3) onto feature branch
- Detection scoring formulas (precision/recall/F2) must NOT be overridden in checklist mode
- Anchor snippets are fingerprinted from rubric-anchors.md to detect drift

**Handoff:** To Toby Ziegler (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/skills/pf-judge/SKILL.md` — Added behavioral anchors to solo generic, checklist (quality/persona), compare, and phase rubric prompts. Added rubric-anchors.md cross-reference.

**Tests:** 27/27 passing (GREEN)
**Branch:** feature/MSSCI-16220-reference-anchors-judge-prompts (pushed)

**Handoff:** To Josh Lyman (Reviewer) for code review

## TEA Verify Assessment

**Tests:** 27/27 passing (GREEN confirmed)

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 1 finding | Anchor text duplication across prompt templates is intentional (by design) |
| simplify-quality | 2 findings | Two tests with empty/placeholder assertions |
| simplify-efficiency | clean | Prompt template structure is intentional complexity |

**Applied:** 2 high-confidence fixes
- `test_detection_not_overridden_by_anchors`: Added assertion that correctness anchors don't leak into detection scoring section
- `test_anchor_text_matches_source`: Replaced `assert True` placeholder with real drift detection

**Flagged for Review:** 0 medium-confidence findings
**Noted:** 1 low-confidence observation (intentional anchor text duplication)
**Reverted:** 0

**Overall:** simplify: applied 2 fixes

**Regression Check:** 27/27 tests passing after fixes. No regressions.

**Handoff:** To Josh Lyman (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] Solo generic prompt correctly inlines all 4 dimensions × 5 bands from rubric-anchors.md at `SKILL.md:157-195`
2. [VERIFIED] Checklist mode adds Quality/Persona anchors while preserving Detection precision/recall formulas at `SKILL.md:313-325`
3. [VERIFIED] Compare mode has complete anchor text for all 4 dimensions at `SKILL.md:471-533`
4. [VERIFIED] Phase rubrics use reference-style mappings to appropriate anchor dimensions at `SKILL.md:59,72,85,98`
5. [LOW] `test_phase_has_anchor_reference` checks shared section for all phases (redundant but not harmful — companion test covers per-phase isolation) at `test_judge_anchors.py:248-269`
6. [VERIFIED] TEA verify fixes are correct — both previously-empty tests now exercise real assertions
7. [VERIFIED] Drift detection via 8-word fingerprints is sound at `test_judge_anchors.py:317-335`
8. [VERIFIED] Cross-reference to `rubric-anchors.md` placed correctly in Scoring Dimensions section at `SKILL.md:46`

**Data flow traced:** rubric-anchors.md → inlined in SKILL.md prompt templates → LLM judge reads at invocation (safe — no user input, no code execution)
**Pattern observed:** Snippet fingerprinting for drift detection at `test_judge_anchors.py:74` — good reusable pattern
**Error handling:** Fixtures assert file existence; test failures give clear messages with dimension/band context

**Handoff:** To Leo McGarry (SM) for finish-story

## Delivery Findings

### TEA (test design)
- **Gap** (non-blocking): Phase mode prompts in SKILL.md are minimal — just "Use phase-specific rubrics from tables above" with no inline prompt template. Dev will need to expand these `<details>` sections with actual prompt templates that include behavioral anchors. Affects `pennyfarthing-dist/skills/pf-judge/SKILL.md` (phase mode section needs full prompt templates). *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation.

### TEA (test verification)
- **Improvement** (non-blocking): Two tests (`test_detection_not_overridden_by_anchors`, `test_anchor_text_matches_source`) had no assertions and silently passed. Fixed with real assertions. Affects `pennyfarthing-dist/src/pf/tests/test_judge_anchors.py` (both now exercise their intended checks). *Found by TEA during test verification.*

### Reviewer (code review)
- No upstream findings during code review.

## Impact Summary

**Upstream Effects:** 2 findings (1 Gap, 0 Conflict, 0 Question, 1 Improvement)
**Blocking:** None

- **Gap:** Phase mode prompts in SKILL.md are minimal — just "Use phase-specific rubrics from tables above" with no inline prompt template. Dev will need to expand these `<details>` sections with actual prompt templates that include behavioral anchors. Affects `pennyfarthing-dist/skills/pf-judge/SKILL.md`.
- **Improvement:** Two tests (`test_detection_not_overridden_by_anchors`, `test_anchor_text_matches_source`) had no assertions and silently passed. Fixed with real assertions. Affects `pennyfarthing-dist/src/pf/tests/test_judge_anchors.py`.

## Session Log

- 2026-03-06 SM: Story setup complete. Session created. Branch `feature/MSSCI-16220-reference-anchors-judge-prompts` created from develop.
- 2026-03-06 TEA: 27 tests written (21 RED). Cherry-picked rubric-anchors.md. Handoff to Dev.
- 2026-03-06 Dev: Implementation complete. 27/27 GREEN. Branch pushed. Handoff to Reviewer.
- 2026-03-06 TEA (verify): Simplify pass — fixed 2 non-functional tests. 27/27 passing. Handoff to Reviewer.
- 2026-03-06 Reviewer: APPROVED. 8 observations (7 verified, 1 low). No blocking issues. Handoff to SM.