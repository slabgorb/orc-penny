# Story 132-6: Create Guided Tour Stepped Workflow

## Story Details
- **ID:** 132-6
- **Jira:** PROJ-15640
- **Title:** Create Guided Tour Stepped Workflow
- **Points:** 5
- **Epic:** 132 / PROJ-15616 (Developer Discovery & Onboarding)
- **Workflow:** tdd
- **Assignee:** Keith Avery

## Acceptance Criteria
- Guided tour is a BikeLane stepped workflow defined in `pennyfarthing-dist/workflows/guided-tour.yaml`
- Tour covers: theme selection, agent activation, workflow basics, sprint commands, hook/config overview
- Each step has a verification gate confirming the user completed the action
- Tour can be started via `/pf-workflow start guided-tour`
- Tour integrates with getting-started guide (132-1) and welcome nudge (132-2) as entry points
- Tour is resumable — if interrupted, `/pf-workflow resume guided-tour` picks up where left off
- Tour progress is visible via `/pf-workflow status guided-tour`

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-25T12:31:14Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-25T12:10:00Z | 2026-02-25T12:16:21Z | 6m 21s |
| red | 2026-02-25T12:16:21Z | 2026-02-25T12:23:02Z | 6m 41s |
| green | 2026-02-25T12:23:02Z | 2026-02-25T12:26:07Z | 3m 5s |
| verify | 2026-02-25T12:26:07Z | 2026-02-25T12:28:52Z | 2m 45s |
| review | 2026-02-25T12:28:52Z | 2026-02-25T12:31:14Z | 2m 22s |
| finish | 2026-02-25T12:31:14Z | - | - |

## Context
- TDD workflow: SM → TEA → Dev → Reviewer → SM
- Repository: pennyfarthing
- Branch: feat/132-6-guided-tour-workflow
- This is a 5pt feature — full TDD cycle with tests first
- Related stories: 132-1 (getting started guide), 132-2 (welcome nudge)
- BikeLane stepped workflows live in `pennyfarthing-dist/workflows/*.yaml`
- Existing stepped workflows (architecture, prd, research, sprint-planning) serve as patterns

## SM Assessment — Setup Phase

**Status:** Ready for TEA

Story creates a new BikeLane stepped workflow for interactive developer onboarding. The guided tour walks users through Pennyfarthing's key features step-by-step with verification gates. Existing stepped workflows in `pennyfarthing-dist/workflows/` provide the pattern to follow.

**Routing:** SM → TEA (Igor) → Dev (Ponder Stibbons) → Reviewer (Granny Weatherwax) → SM
**Key ACs:** Stepped workflow YAML, verification gates per step, resumable, integrates with existing onboarding.

## TEA Assessment

**Tests Required:** Yes
**Reason:** 5pt feature — full stepped workflow with YAML definition, step files, gates, and CLI integration

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_guided_tour.py` — 35 tests across 8 test classes

**Test Coverage by AC:**
| AC | Tests | What's Tested |
|----|-------|---------------|
| AC1 (workflow definition) | 8 | Directory, YAML, name, type, steps config, agent, description |
| AC2 (topic coverage) | 7 | Step count, naming pattern, theme/agent/workflow/sprint/config topics |
| AC3 (verification gates) | 4 | Gates config, after_steps, gate XML sections, gate criteria |
| AC4 (CLI start) | 3 | Workflow list, stepped type, workflow show |
| AC5 (onboarding integration) | 3 | Description terms, help/guide references, trigger tags |
| AC6 (resumability) | 3 | Sequential numbering, step-meta with next, final step |
| AC7 (progress visibility) | 3 | Collaboration menus, continue option, step numbers |
| Structure | 4 | Purpose, instructions, collaboration-menu, markdown title |

**Tests Written:** 35 tests covering 7 ACs
**Status:** RED (all 35 failing — assertions on missing workflow files, not import errors)

**Handoff:** To Dev (Ponder Stibbons) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/workflows/guided-tour/workflow.yaml` — Stepped workflow definition (name, type, steps, gates, collaboration menus, triggers)
- `pennyfarthing-dist/workflows/guided-tour/steps/step-01-welcome.md` — Welcome & getting-started, /pf-help reference
- `pennyfarthing-dist/workflows/guided-tour/steps/step-02-themes.md` — Theme selection with pf theme commands
- `pennyfarthing-dist/workflows/guided-tour/steps/step-03-agents.md` — Agent activation & workflow basics
- `pennyfarthing-dist/workflows/guided-tour/steps/step-04-sprint.md` — Sprint & story management commands
- `pennyfarthing-dist/workflows/guided-tour/steps/step-05-config.md` — Hooks & configuration overview
- `pennyfarthing-dist/src/pf/tests/test_guided_tour.py` — Fixed final step test to use `next: complete` sentinel (matches schema validator convention)

**Tests:** 35/35 passing (GREEN)
**Branch:** feat/132-6-guided-tour-workflow (pushed)

**Handoff:** To Reviewer (Granny Weatherwax) for code review

## Reviewer Assessment

**Verdict:** APPROVED

| # | Tag | Observation | Location |
|---|-----|-------------|----------|
| 1 | [VERIFIED] | Workflow YAML schema correct, all required fields | `workflow.yaml:9-46` |
| 2 | [VERIFIED] | Step files structurally correct, sequential numbering, proper meta | `steps/step-01..05` |
| 3 | [VERIFIED] | All 5 topic areas covered (theme, agent, workflow, sprint, config) | `step-02..05` |
| 4 | [VERIFIED] | Gates on every step with checkable criteria | `workflow.yaml:24`, all steps |
| 5 | [VERIFIED] | Onboarding integration — /pf-help and getting-started referenced | `step-01:13` |
| 6 | [VERIFIED] | `pf validate workflow` passes 26/26 | CLI validation |
| 7 | [LOW] | Variables `project_root`/`config_file` defined but unused in steps | `workflow.yaml:19-21` |

**Data flow:** `pf workflow start guided-tour` → YAML → stepped engine → step content. Pure presentation.
**Test fix:** `test_final_step_has_next_complete` correctly matches `next: complete` convention.

**Handoff:** To SM (Captain Carrot) for finish-story

## TEA Verify Assessment

**Status:** GREEN confirmed
**Story Tests:** 35/35 passing
**Regression Check:** 39 failures in full suite — all pre-existing (41 failures on develop baseline). No regressions introduced.
**TypeScript:** Compiles clean

**Handoff:** To Reviewer (Granny Weatherwax) for code review