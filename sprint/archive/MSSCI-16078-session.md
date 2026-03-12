# Story 138-5: Add simplify team block to tdd and tdd-tandem workflow YAMLs

**Jira:** MSSCI-16078
**Epic:** 138 — Simplify Integration
**Points:** 1
**Workflow:** trivial
**Phase:** finish
**Repos:** orchestrator
**Branch:** chore/138-5-add-simplify-team-block

## Story Context

Epic 138 integrates three specialized Haiku teammates (simplify-reuse, simplify-quality, simplify-efficiency) into the verify phase of TDD workflows. This story adds the `team:` block configuration to both `tdd.yaml` and `tdd-tandem.yaml` to activate the simplify teammates during the verify phase when TEA runs quality checks.

This configuration enables parallel quality review across three dimensions:
- **simplify-reuse:** Code duplication and extraction opportunities
- **simplify-quality:** Naming, readability, and structural quality
- **simplify-efficiency:** Unnecessary complexity and over-engineering

The existing quality-pass gate serves as a regression safety net.

### Technical Guardrails

- Each workflow verify phase contains a single `team:` block with a `teammates:` list
- Each teammate has `agent:` (agent ID) and `task:` (human-readable instruction string)
- No changes to gate definitions, phase inputs/outputs, or trigger conditions
- No schema changes to the workflow YAML format

### Acceptance Criteria

1. `tdd.yaml` verify phase contains the team block with three simplify teammates
2. `tdd-tandem.yaml` verify phase contains the same team block (merged with existing architect teammate)
3. Workflow YAML parses without errors (validates against workflow schema)
4. Both files retain all existing phase structure, gates, and trigger conditions unchanged

## Approach

1. Locate `tdd.yaml` and `tdd-tandem.yaml` in `pennyfarthing-dist/workflows/`
2. Add `team:` block to verify phase in `tdd.yaml` with three teammates
3. Add simplify teammates to existing `team:` block in `tdd-tandem.yaml` verify phase
4. Use exact task descriptions from story context:
   - simplify-reuse: "Review changed files for code duplication and extraction opportunities. Report findings only."
   - simplify-quality: "Review changed files for naming, readability, and structural quality. Report findings only."
   - simplify-efficiency: "Review changed files for unnecessary complexity and over-engineering. Report findings only."
5. Validate workflow YAML structure

## SM Assessment

Straightforward YAML-only change. Add `team:` block with three simplify teammates to the verify phase of `tdd.yaml` and merge into existing team block in `tdd-tandem.yaml`. No code, no schema changes, no gate modifications. Dev should validate YAML parses cleanly after edit.

**Routing:** Trivial (1pt) → Dev (Naomi Nagata)

## Delivery Findings

<!-- findings-start -->
### Dev (implementation)
- No upstream findings during implementation.
### Reviewer (code review)
- **Gap** (blocking): `VALID_AGENT_NAMES` in `packages/core/src/workflow/workflow-schema.ts:81` does not include `simplify-reuse`, `simplify-quality`, or `simplify-efficiency`. Workflow validator rejects all three teammates. Affects `packages/core/src/workflow/workflow-schema.ts` (add simplify agents to allowlist). *Found by Reviewer during code review.* **RESOLVED in R2.**
### Reviewer (code review R2)
- **Improvement** (non-blocking): `VALID_AGENT_NAMES` is a flat list now at 14 entries mixing primary agents and specialized teammates. Consider categorizing as the list grows. Affects `packages/core/src/workflow/workflow-schema.ts` (future refactor). *Found by Reviewer during code review.*
<!-- findings-end -->

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [CRITICAL] | `simplify-reuse` not in `VALID_AGENT_NAMES` — workflow validator rejects it | `packages/core/src/workflow/workflow-schema.ts:81` | Add `simplify-reuse` to the allowlist |
| [CRITICAL] | `simplify-quality` not in `VALID_AGENT_NAMES` — workflow validator rejects it | `packages/core/src/workflow/workflow-schema.ts:81` | Add `simplify-quality` to the allowlist |
| [CRITICAL] | `simplify-efficiency` not in `VALID_AGENT_NAMES` — workflow validator rejects it | `packages/core/src/workflow/workflow-schema.ts:81` | Add `simplify-efficiency` to the allowlist |
| [VERIFIED] | YAML syntax valid — both files parse cleanly | `tdd.yaml`, `tdd-tandem.yaml` | — |
| [VERIFIED] | Team block structure matches existing pattern (agent + task keys only) | `tdd-tandem.yaml:57-60` (reference) | — |
| [VERIFIED] | Agent definition files exist for all three simplify agents | `pennyfarthing-dist/agents/simplify-*.md` | — |
| [VERIFIED] | No changes to gates, triggers, or phase structure | Both files | — |
| [VERIFIED] | Task descriptions match story context exactly | Both files | — |

**AC 3 FAILS:** "Workflow YAML parses without errors (validates against workflow schema)" — the workflow schema validator explicitly rejects unknown agent names. Dev validated YAML *syntax* but not *schema*.

**Handoff:** Back to Dev for fix — add `simplify-reuse`, `simplify-quality`, `simplify-efficiency` to `VALID_AGENT_NAMES` in `packages/core/src/workflow/workflow-schema.ts`, rebuild, and re-run the validator.

## Dev Assessment (Round 2)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/workflows/tdd.yaml` - Added team block with 3 simplify teammates to verify phase
- `pennyfarthing-dist/workflows/tdd-tandem.yaml` - Added 3 simplify teammates to existing team block in verify phase
- `packages/core/src/workflow/workflow-schema.ts` - Added simplify-reuse, simplify-quality, simplify-efficiency to VALID_AGENT_NAMES

**Tests:** 66/66 passing (workflow-schema.test.js GREEN)
**Validation:** Both tdd.yaml and tdd-tandem.yaml pass workflow schema validator
**Branch:** feat/MSSCI-16130-audit-unexported-hooks (pennyfarthing repo, pushed)

**Handoff:** To Reviewer (Chrisjen Avasarala) for re-review

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED

**R1 findings resolved:** All three simplify agents added to `VALID_AGENT_NAMES` at `workflow-schema.ts:84`. Single-line change, surgical fix.

| Observation | Detail |
|-------------|--------|
| [VERIFIED] | R1 critical findings resolved — all 3 agents in allowlist |
| [VERIFIED] | Workflow validator passes for both `tdd.yaml` and `tdd-tandem.yaml` |
| [VERIFIED] | Parsed `TeamConfig` correctly populated: `tdd.yaml` has 3 teammates, `tdd-tandem.yaml` has 4 (architect + 3 simplify) |
| [VERIFIED] | Schema tests 66/66 green, graph validation tests 38/38 green |
| [VERIFIED] | No collateral changes — only allowlist entry added, no logic modifications |
| [MEDIUM] | `VALID_AGENT_NAMES` growing to 14 entries; may benefit from categorization in future |

**Data flow traced:** Workflow YAML `team.teammates[].agent` → `validateWorkflow()` → `VALID_AGENT_NAMES.includes()` check at line 502 → now passes → parsed into `TeamConfig.teammates[]` with correct agent/task pairs
**Error handling:** Validator still correctly rejects unknown agents not in the list — no regression
**Handoff:** To Camina Drummer (SM) for finish

## Session Log

- **Setup:** Session created by SM
- **Implement:** Added simplify team blocks to both workflow YAMLs, validated parsing, committed and pushed
- **Review (R1):** REJECTED — VALID_AGENT_NAMES missing simplify agents, workflow validator fails
- **Implement (R2):** Added 3 simplify agents to VALID_AGENT_NAMES, rebuilt, 66/66 tests passing, validator confirms VALID
- **Review (R2):** APPROVED — fix verified, all tests green, all ACs met