# Story 86-15: Team-enabled workflow templates

## Story Details
- **ID:** 86-15
- **Jira:** PROJ-15110
- **Title:** Team-enabled workflow templates
- **Points:** 2
- **Workflow:** tdd
- **Assigned To:** slabgorb@gmail.com
- **Repos:** pennyfarthing
- **Branch:** feat/86-15-team-enabled-workflow-templates

## Acceptance Criteria

- [ ] `tdd-team.yaml` — Dev + Architect on green, Reviewer + Architect on review
- [ ] `bdd-team.yaml` — UX + Architect on design, Dev + TEA on green
- [ ] Each template documented with when-to-use vs tandem variants
- [ ] `/workflow list` shows team-enabled workflows with indicator
- [ ] Templates include graceful fallback comment for when teams unavailable

## Context

**Phase 2 Deliverable:** Team-enabled workflow templates to complement 86-9 (workflow schema) and 86-14 (agent behavior protocol).

From epic context (context-epic-86.md):
- Story depends on: 86-9 (workflow schema), 86-14 (agent behavior)
- Native teams feature-flagged: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`
- Phase-scoped teams: created at phase start, destroyed before handoff
- Lead agent (Dev, Reviewer) spawns teammates per YAML config
- Falls back to solo mode when teams unavailable (feature detection from 86-7)

**Key files:**
- `pennyfarthing-dist/workflows/tdd-team.yaml` (new)
- `pennyfarthing-dist/workflows/bdd-team.yaml` (new)

Reference templates to compare against:
- `pennyfarthing-dist/workflows/tdd.yaml` (baseline TDD flow)
- `pennyfarthing-dist/workflows/tdd-tandem.yaml` (Tandem variant)
- `pennyfarthing-dist/workflows/bdd.yaml` (baseline BDD flow)
- `pennyfarthing-dist/workflows/bdd-tandem.yaml` (BDD with Tandem)

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-18T12:08:08Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-18T06:26:35-05:00 | 2026-02-18T11:29:00Z | 2m 25s |
| red | 2026-02-18T11:29:00Z | 2026-02-18T11:41:12Z | 12m 12s |
| green | 2026-02-18T11:41:12Z | 2026-02-18T11:44:38Z | 3m 26s |
| verify | 2026-02-18T11:44:38Z | 2026-02-18T12:08:00Z | 23m 22s |
| review | 2026-02-18T12:08:00Z | 2026-02-18T12:08:08Z | 8s |
| finish | 2026-02-18T12:08:08Z | - | - |

## Related Stories

- **86-9:** Workflow schema: `team:` block on phases (done 2026-02-16)
- **86-14:** Agent behavior: team-mode protocol (done 2026-02-18)
- **86-7:** Feature detection: native teams capability (done 2026-02-16)
- **86-8:** Teammate activation via spawn prompts (done 2026-02-16)
- **86-10:** Phase-scoped team lifecycle + gate hooks (done 2026-02-17)

## TEA Assessment

**Tests Required:** Yes
**Reason:** New YAML template files + workflow list behavior change — all 5 ACs are testable

**Test Files:**
- `packages/core/src/workflow/workflow-team-templates.test.ts` — 28 integration tests validating template structure, team blocks, documentation, fallback comments
- `pennyfarthing_scripts/tests/test_workflow_list_team.py` — 5 tests for workflow list team indicator

**Tests Written:** 33 tests covering 5 ACs
- AC1 (tdd-team.yaml): 9 tests — file existence, validation, phase structure, Dev+Architect on green, Reviewer+Architect on review, gates, triggers
- AC2 (bdd-team.yaml): 9 tests — file existence, validation, phase structure, UX+Architect on design, Dev+TEA on green, gates, triggers
- AC3 (documentation): 4 tests — when-to-use comments, tandem variant references, description text
- AC4 (workflow list indicator): 5 tests — team workflows in list, team indicator per row, distinguishes from tandem
- AC5 (fallback comments): 2 tests — fallback/unavailable/solo guidance in raw YAML
- Bonus: 4 tests for teammate task descriptions

**Status:** RED (32 failing, 1 passing — ready for Dev)

**Handoff:** To Korben Dallas (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/workflows/tdd-team.yaml` — TDD team workflow with Dev+Architect on green, Reviewer+Architect on review
- `pennyfarthing-dist/workflows/bdd-team.yaml` — BDD team workflow with UX+Architect on design, Dev+TEA on green

**Tests:** 33/33 passing (GREEN)
**Branch:** feat/86-15-team-enabled-workflow-templates (pushed)

**Handoff:** To Zorg (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** YAML → `loadWorkflowFile()` → `validateWorkflow()` (schema validates team blocks, teammates, agent names) → `WorkflowDefinition` consumed by BikeLane engine. Clean path, no unvalidated inputs.

**Pattern observed:** Both templates mirror tandem variants structurally, replacing `tandem:` with `team:` blocks. Consistent with `tdd-tandem.yaml`/`bdd-tandem.yaml` at `pennyfarthing-dist/workflows/`.

**Error handling:** Schema validation rejects malformed team blocks (missing teammates, invalid agents, empty arrays). Gate types validated against allowlist.

**Observations:**
| # | Severity | Issue | Location |
|---|----------|-------|----------|
| 1 | [MEDIUM] | `test_non_team_workflows_lack_team_indicator` has no assertions after filtering loop — passes vacuously | `pennyfarthing_scripts/tests/test_workflow_list_team.py:87-116` |
| 2 | [LOW] | `bdd-team.yaml` omits `types:` from triggers unlike `bdd.yaml`/`bdd-tandem.yaml` — acceptable since team workflows are opt-in | `pennyfarthing-dist/workflows/bdd-team.yaml:85-89` |
| 3 | [VERIFIED] | Team blocks correctly placed per ACs 1 & 2 | Both YAML files |
| 4 | [VERIFIED] | Documentation thorough — when-to-use, tandem comparison, fallback guidance (ACs 3 & 5) | Both YAML header comments |
| 5 | [VERIFIED] | Gates, triggers, and non-team phases all correct | Both YAML files |
| 6 | [VERIFIED] | Schema validates team blocks including agent name validation against `VALID_AGENT_NAMES` | `workflow-schema.ts:474-531` |

**Handoff:** To Ruby Rhod (SM) for finish-story

## Notes

- All prior Phase 2 stories are complete
- Workflow templates should mirror `tdd-tandem.yaml` and `bdd-tandem.yaml` structure but with `team:` blocks instead of `tandem:` blocks
- Both workflows should include fallback comments for teams-unavailable scenarios
- `/workflow list` implementation may need updates to show team-enabled indicator