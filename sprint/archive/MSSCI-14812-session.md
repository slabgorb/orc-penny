# Story 91-27: Normalize stepped workflow output paths and de-collision document names

**Jira:** MSSCI-14812
**Epic:** 91 — Cross-File Reference & Schema Validation Pipeline
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/91-27-normalize-stepped-workflow-output-paths

## Story Context

Type: refactor | Points: 3 | Priority: P2

### Description
Normalize stepped workflow output paths and de-collision document names.

### Acceptance Criteria
- [ ] `normalizeOutputPath()` rewrites `artifacts/`, `./artifacts/`, `planning-artifacts/`, `./planning-artifacts/` to `sprint/planning/`
- [ ] `normalizeOutputPath()` preserves subdirectories and leaves `sprint/planning/` paths unchanged
- [ ] `normalizeOutputPath()` prepends `sprint/planning/` to bare filenames
- [ ] `auditWorkflowOutputPaths()` detects duplicate filenames across workflows
- [ ] `auditWorkflowOutputPaths()` detects inconsistent base directories
- [ ] Default `planning_artifacts` in `variable-resolver.ts` changed from `planning-artifacts/` to `sprint/planning/`
- [ ] All 10+ stepped workflow YAML files updated: `output_file` and `planning_artifacts` use `sprint/planning/`

### Implementation Notes

**Problem:** BMAD-ported stepped workflows write to `./artifacts/` with generic names
(`prd.md`, `architecture.md`, `research.md`). This collides and doesn't align with
existing project docs in `sprint/planning/`.

**Key files:**
- NEW: `packages/core/src/workflow/output-path-normalizer.ts` — normalizer + audit
- MODIFY: `packages/core/src/workflow/variable-resolver.ts` line 215 — change default
- MODIFY: `.pennyfarthing/workflows/*/workflow.yaml` — update all output_file and planning_artifacts vars

**Existing pattern in `sprint/planning/`:** `{topic}-{type}.md` (e.g., `bikerack-prd.md`, `tandem-mode-architecture.md`)

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `packages/core/src/workflow/output-path-normalizer.test.ts` — 25 tests

**Tests Written:** 25 tests covering 7 ACs
**Status:** RED (24 failing, 1 passing — all assertion-based)

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/workflow/output-path-normalizer.ts` — implemented normalizeOutputPath() and auditWorkflowOutputPaths()
- `packages/core/src/workflow/variable-resolver.ts` — changed default planning_artifacts from planning-artifacts/ to sprint/planning/
- 12 workflow YAML files — updated `planning_artifacts` and `output_file` to use `sprint/planning/`

**Tests:** 25/25 passing (GREEN)
**PRs:**
- #826 — feat(91-27): normalize stepped workflow output paths (merged)
- #828 — feat(91-27): update workflow YAML paths to sprint/planning/
**Branch:** feat/91-27-update-workflow-yaml-paths (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment (Re-review)

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] All 12 workflow YAML files updated — `planning_artifacts` and `output_file` consistently use `sprint/planning/`
2. [VERIFIED] Previous HIGH (AC7) resolved — zero stale `./artifacts` or `planning-artifacts` paths in workflow YAMLs
3. [VERIFIED] Previous HIGH (default inert) resolved — workflow vars now align with variable-resolver default
4. [VERIFIED] Trailing slash consistency on `planning_artifacts: sprint/planning/` — correct for `{planning_artifacts}/filename` substitution
5. [VERIFIED] `sprint-planning/workflow.yaml` also updated `status_file` — thorough
6. [VERIFIED] Correctly skipped brainstorming (uses `{output_folder}`) and git-cleanup (writes to `.session/`)
7. [LOW] `retrospective/workflow.yaml` retains `implementation_artifacts: ./artifacts` — out of AC7 scope

**Data flow traced:** workflow YAML `variables.planning_artifacts` → variable-resolver priority 1 → `{planning_artifacts}` in step content → resolves to `sprint/planning/`
**Error handling:** N/A — YAML configuration, no runtime error paths
**Security:** N/A — no user input, no auth boundaries

**Handoff:** To SM for finish-story

## Session Log

- [setup] Session created by SM
- [setup → red] Handoff to TEA for test design
- [red] TEA wrote 25 failing tests for output path normalization
- [red] Stub implementation created (compiles, throws 'Not implemented')
- [red] Variable resolver default test confirmed: expects sprint/planning/, gets planning-artifacts/
- [red → green] Handoff to Dev for implementation (24 tests RED)
- [green → review] Handoff to Reviewer for code review (PR #826, 25/25 GREEN)
- [review] Reviewer initially APPROVED and merged PR #826 (code-only changes)
- [review → green] Reviewer REJECTED for AC7: workflow YAML files not updated. Back to Dev.
- [green] Dev updated 12 workflow YAML files to use sprint/planning/ (PR #828)
- [green → review] Handoff to Reviewer for re-review
- [review] Reviewer APPROVED PR #828 — all AC7 findings resolved
- [review → finish] Handoff to SM for finish-story
