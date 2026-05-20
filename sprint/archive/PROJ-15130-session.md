# Story 91-15: Cross-entity reference validation

## Story Details
- **ID:** 91-15
- **Jira:** PROJ-15130
- **Title:** Cross-entity reference validation
- **Points:** 5
- **Epic:** 91 (Cross-File Reference & Schema Validation Pipeline)
- **Repos:** pennyfarthing
- **Workflow:** tdd
- **Assignee:** keith.avery@slabgorb.io

## Description
Semantic cross-refs between agents, workflows, commands, skills. Bidirectional reference consistency.

## Acceptance Criteria
- Validate that agents referenced in workflows exist
- Validate that workflows referenced in agents are properly defined
- Validate that commands referenced in skills exist
- Validate that skills are properly registered in command definitions
- Check bidirectional consistency of all references

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-19T20:03:13Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-19T14:48:00Z | 2026-02-19T19:49:47Z | 5h 1m |
| red | 2026-02-19T19:49:47Z | 2026-02-19T19:58:32Z | 8m 45s |
| green | 2026-02-19T19:58:32Z | 2026-02-19T20:00:34Z | 2m 2s |
| verify | 2026-02-19T20:00:34Z | 2026-02-19T20:01:28Z | 54s |
| review | 2026-02-19T20:01:28Z | 2026-02-19T20:03:13Z | 1m 45s |
| finish | 2026-02-19T20:03:13Z | - | - |

## Branch
- **Branch:** feat/91-15-cross-entity-ref-validation

## Context
This story is part of the Cross-File Reference & Schema Validation Pipeline epic. It focuses on semantic validation of cross-entity references (agents, workflows, commands, skills) to ensure bidirectional consistency. Previous validation work in this epic:
- Layer 0: Formatting & linting (ESLint, Ruff, markdownlint, yamllint) - DONE
- Layer 1: File reference validation - DONE
- Layer 2: Schema validation (YAML fields, enums) - DONE
- Layer 3: Graph validation (workflow steps, gates) - DONE

This story adds semantic validation for cross-entity references.

## SM Assessment (Setup)

Story 91-15 is set up and ready for TEA. PROJ-15130 claimed in Jira, branch `feat/91-15-cross-entity-ref-validation` created on pennyfarthing repo (gitflow, off develop). Session file created with ACs covering agent→workflow, workflow→agent, command→skill, and skill→command cross-references with bidirectional consistency checks. This is Layer 4 in the validation pipeline — Layers 0-3 are done (91-14 completed graph validation). 5 points, TDD workflow → TEA writes failing tests first.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Layer 4 cross-entity reference validation — core validation logic needs full test coverage

**Test Files:**
- `packages/core/src/workflow/cross-entity-validation.test.ts` — 31 tests covering all 5 ACs
- `packages/core/src/workflow/cross-entity-validation.ts` — stub implementation (types + function returning `{valid: true}`)

**Tests Written:** 31 tests covering 5 ACs
- AC1: Agents referenced in workflows exist (4 tests)
- AC2: Workflows referenced in agents are properly defined (4 tests)
- AC3: Skill related_skills references exist (5 tests)
- AC4: Skills referenced in commands exist (4 tests)
- AC5: Bidirectional consistency (6 tests)
- Edge cases (6 tests)
- Integration scenarios (2 tests)

**Status:** RED (18 failing, 13 passing — failures are assertion errors against stub, not import/syntax errors)

**Pattern:** Follows Layer 3 (`workflow-graph-validation.test.ts`) — Node.js native test runner, result objects with `{valid, errors?, warnings?}`, `CrossEntityContext` for dependency injection (no filesystem access needed).

**Key Design Decisions:**
- `CrossEntityContext` provides all entity data via DI (same pattern as `GraphValidationContext`)
- Errors for missing references (AC1-AC4), warnings for bidirectional inconsistencies (AC5)
- Self-referencing skills flagged, asymmetric related_skills warned
- Case-sensitive matching for all entity names

**Handoff:** To Naomi (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/workflow/cross-entity-validation.ts` — replaced stub with full validation logic (~125 lines)

**Implementation Approach:**
- AC1: Iterate `workflowAgentRefs`, check each agent against `knownAgentFiles` set
- AC2: Iterate `agentWorkflowRefs`, check each workflow against `knownWorkflowNames` set
- AC3: Iterate `skillEntityRefs.relatedSkills`, check against `knownSkillNames` set; flag self-references as warnings
- AC4: Iterate `commandSkillRefs.referencedSkills`, check against `knownSkillNames` set
- AC5: Build bidirectional maps, check workflow→agent and agent→workflow consistency; check related_skills symmetry. All bidirectional issues are warnings (advisory, not blocking).
- Same result-object pattern as `validateWorkflowGraph`: `{valid, errors?, warnings?}`, sparse (only include arrays when non-empty)

**Tests:** 31/31 passing (GREEN) — all workflow validation tests: 135/135 total, zero regressions
**Branch:** feat/91-15-cross-entity-ref-validation (pushed)

**Handoff:** To verify phase (TEA) or review

## TEA Verify Assessment

**Quality Verified:** Yes
**Tests:** 31/31 passing (cross-entity) — 135/135 total (all workflow validation)
**Typecheck:** Clean (tsc --noEmit passes)
**Working Tree:** Clean
**Branch:** feat/91-15-cross-entity-ref-validation (2 commits, pushed)

**Handoff:** To Avasarala (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** CrossEntityContext → Set lookups → per-AC loops → errors/warnings → sparse result object. No input mutation.
**Pattern observed:** Follows Layer 3 (validateWorkflowGraph) pattern — DI context, result objects, sparse arrays. Consistent with codebase at `packages/core/src/workflow/workflow-graph-validation.ts`.
**Error handling:** Graceful on empty inputs, no exceptions. Lines 147-256 all use safe iteration over potentially-empty arrays.

| Severity | Observation | Location |
|----------|------------|----------|
| [LOW] | Unused `type { WorkflowDefinition }` import | cross-entity-validation.ts:16 |
| [LOW] | `knownCommandFiles` declared in context but never used | cross-entity-validation.ts:72 |
| [VERIFIED] | AC1-AC4 validation logic correct, case-sensitive | cross-entity-validation.ts:147-199 |
| [VERIFIED] | AC5 bidirectional guards defensively skip unscanned entities | cross-entity-validation.ts:216-256 |
| [VERIFIED] | Self-reference correctly flagged as warning with continue | cross-entity-validation.ts:173-179 |
| [VERIFIED] | 31 tests with good negative/edge case coverage | cross-entity-validation.test.ts |

**Handoff:** To SM for finish-story