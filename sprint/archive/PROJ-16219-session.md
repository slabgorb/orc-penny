# Story 42-1: Create rubric-anchors.md with behavioral scales

**Jira:** PROJ-16219
**Epic:** 42 — Anchored Rubric Criteria
**Points:** 3
**Repos:** pennyfarthing
**Branch:** feature/PROJ-16219-rubric-anchors-behavioral-scales
**Workflow:** tdd
**Phase:** finish
**Assigned:** slabgorb@gmail.com

## Acceptance Criteria

**AC1: Behavioral scales for correctness dimension**
- 1-2: Response contains factual errors, misidentifies the problem, or proposes broken solutions
- 5-6: Correctly identifies the main issue with a reasonable solution; minor gaps in edge case coverage
- 9-10: Expert analysis identifying non-obvious issues; production-ready solution with comprehensive edge case handling
- Test: Read scale and verify each level is distinguishable from adjacent levels

**AC2: Behavioral scales for depth dimension**
- 1-2: Surface-level observation with no analysis
- 5-6: Identifies root cause with adequate explanation
- 9-10: Multi-layered analysis connecting symptoms to root causes to systemic patterns
- Test: Given two sample responses, the scale should unambiguously place them at different levels

**AC3: Behavioral scales for quality dimension**
- Covers clarity, actionability, and communication effectiveness
- Test: Scale distinguishes between verbose-but-unhelpful and concise-but-actionable

**AC4: Behavioral scales for persona dimension**
- Covers character voice, role-appropriate behavior, persona consistency
- Test: Scale distinguishes between surface mimicry (catchphrases) and deep behavioral alignment

**AC5: Document follows guide format**
- Markdown, lives in `pennyfarthing-dist/guides/`, cross-referenced from measurement docs

## Technical Context

This story creates `pennyfarthing-dist/guides/rubric-anchors.md` — a behavioral anchoring document that defines concrete, observable behaviors for each score level (1-10) across four judge dimensions: correctness, depth, quality, and persona.

**Key references:**
- `pennyfarthing-dist/guides/persona-effectiveness.md` — style reference and PersonaScore calibration
- `pennyfarthing-dist/guides/measurement-framework.md` — Wallach L3 rubric design principles
- `pennyfarthing-dist/skills/pf-judge/SKILL.md` — current judge rubric (to be updated in 42-2)

**Approach:** Each dimension gets a full 1-10 behavioral scale with anchors at 5 band levels (1-2, 3-4, 5-6, 7-8, 9-10). Anchors must be observable and testable — not subjective. Research basis: PersonaGym (75% Spearman with human judges via calibrated exemplars) and Galileo 3-tier rubric taxonomy.

**Dependencies:** Depends on PROJ-16214 (Multi-Judge Validation) for disagreement data. Depended on by PROJ-16212 (Gold Standards) and PROJ-16213 (Difficulty Profiles).

**Do NOT:** Modify judge prompts (42-2) or create exemplar responses (gold standards work).

## SM Assessment

Story 42-1 is ready for TDD red phase. Session file created with detailed ACs covering all four judge dimensions (correctness, depth, quality, persona). Branch exists on pennyfarthing repo. Jira claimed. Epic context provides clear research basis and file targets. Handoff to TEA for test design.

## Delivery Findings

### TEA (test design)

- No upstream findings during test design.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Structured document with testable acceptance criteria across 4 dimensions

**Test Files:**
- `tests/python/test_rubric_anchors.py` - Structural validation of rubric-anchors.md

**Tests Written:** 23 tests covering 5 ACs
- TestDocumentStructure (4 tests): file exists, title heading, all dimensions present, minimum length
- TestCorrectnessDimension (4 tests): section exists, all bands, behavioral language, failure/excellence modes
- TestDepthDimension (3 tests): section exists, all bands, surface vs deep differentiation
- TestQualityDimension (4 tests): section exists, all bands, clarity + actionability, verbose vs actionable
- TestPersonaDimension (4 tests): section exists, all bands, voice + behavior, mimicry vs embodiment
- TestCrossDimension (3 tests): consistent band structure, monotonic ordering, no stubs

**Status:** RED (1 failed, 22 errors — all due to missing rubric-anchors.md)
**Commit:** `test(42-1): add failing tests for rubric-anchors behavioral scales`

**Handoff:** To Toby Ziegler (Dev) for implementation — create `pennyfarthing-dist/guides/rubric-anchors.md` with behavioral scales for correctness, depth, quality, and persona dimensions. Each dimension needs 5 band levels (1-2, 3-4, 5-6, 7-8, 9-10) with observable behavioral descriptions.

### Dev (implementation)

- No upstream findings during implementation.

### TEA (test verification)

- **Improvement** (non-blocking): Uncommitted changes to `persona-effectiveness.md` on this branch predate story work. Affects `pennyfarthing-dist/guides/persona-effectiveness.md` (should be committed separately or stashed). *Found by TEA during test verification.*

## TEA Verify Assessment

### Simplify Report

**Files Analyzed:** 1 (tests/python/test_rubric_anchors.py)
**Skipped:** 2 markdown files (non-code)

No code changes to simplify — the only code file is a test, and the implementation is a markdown guide. Simplify fan-out skipped per verify workflow Step 1 filter.

**Overall:** simplify: clean (no code implementation to review)

### Quality-Pass

**Tests:** 23/23 passing
**Lint:** N/A (markdown guide + Python test)
**Typecheck:** N/A

**Handoff:** To Josh Lyman (Reviewer) for code review.

### Reviewer (code review)

- **Improvement** (non-blocking): `rubric_sections` fixture defined but unused in test file. Affects `tests/python/test_rubric_anchors.py:42` (dead code — remove or use). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_assert_behavioral_language()` only applied to correctness dimension, not depth/quality/persona. Affects `tests/python/test_rubric_anchors.py:135` (extend to all dimensions for consistent coverage). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED

**Dimension alignment:** Verified correctness, depth, quality, persona at 25% each — matches SKILL.md unified rubric exactly at `rubric-anchors.md:9`.
**Data flow traced:** rubric-anchors.md → referenced by pf-judge SKILL.md → judge prompts. Doc header correctly states the linkage. Story 42-2 will wire the actual references.
**Band distinguishability:** Adjacent bands in all four dimensions use clearly different behavioral descriptions. A judge can unambiguously place a response at the correct level.
**Error handling:** N/A — documentation file, no code execution paths.
**Pattern observed:** Good defensive test at `test_rubric_anchors.py:351` — monotonic ordering check prevents future edits from scrambling band order.
**Security:** No concerns — pure markdown documentation.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [LOW] | Unused `rubric_sections` fixture | `test_rubric_anchors.py:42` | Remove or use in future |
| [LOW] | Behavioral language check only on correctness | `test_rubric_anchors.py:135` | Extend to all dimensions |

**Handoff:** To Leo McGarry (SM) for finish-story.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/guides/rubric-anchors.md` - Behavioral anchoring scales for all four judge dimensions

**Tests:** 23/23 passing (GREEN)
**Branch:** feature/PROJ-16219-rubric-anchors-behavioral-scales (pushed)

**Handoff:** To Sam Seaborn (TEA) for verify phase

## Session Log

- 2026-03-06 SM: Story setup complete. Session created. Branch `feature/PROJ-16219-rubric-anchors-behavioral-scales` created from develop.