# 136-17: Setup workflow step-06 missing wheelhub/bikerack/tui justfile recipes

**Story:** 136-17
**Jira:** MSSCI-15949
**Epic:** MSSCI-15839
**Points:** 1
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-03T11:59:09Z
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-15949-setup-step06-justfile-recipes

---

## Acceptance Criteria

1. Add wheelhub justfile recipe to step-06 setup workflow
2. Add bikerack justfile recipe to step-06 setup workflow
3. Add tui justfile recipe to step-06 setup workflow

## Context

Setup workflow step-06 is missing justfile recipes for launching wheelhub, bikerack, and tui. These recipes are commonly used for local development and should be available after running pf init in a new project.

Key files:
- `pennyfarthing-dist/templates/justfile.template` — main justfile template
- `pennyfarthing-dist/templates/justfile.pf.template` — pf-specific recipes
- `pennyfarthing-dist/scripts/setup-step-06.sh` — setup step script

## SM Assessment

Story setup complete. 1-point trivial workflow — straight to Korben Dallas (Dev). Feature branch created from develop. Three clear ACs for adding justfile recipes. No blockers.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/templates/justfile.pf.template` — added `bikerack` recipe (`just pf launch gui`)
- `pennyfarthing-dist/workflows/project-setup/steps/step-06-task-runner.md` — documented framework recipes (wheelhub, bikerack, tui, claude, tmux-dev), updated output/success criteria/interactive summary

**Tests:** N/A (documentation + template changes)
**Branch:** feat/MSSCI-15949-setup-step06-justfile-recipes (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `just bikerack` → `just pf launch gui` → `pf launch gui` (starts WheelHub + opens browser). Correct delegation chain.
**Pattern observed:** One-liner delegation to `pf launch` matches existing `tui:` recipe pattern at `justfile.pf.template:45-46`
**Error handling:** `pf launch gui` handles WheelHub lifecycle internally (idempotent start). No additional error handling needed in the recipe.
**Observations:**
- [VERIFIED] bikerack recipe delegates correctly (`justfile.pf.template:41-42`)
- [VERIFIED] Template syntax consistent with existing patterns
- [VERIFIED] Step-06 documentation replaces stale sprint-cli.sh references
- [LOW] Success criteria lists 3 of 6 framework recipes — minor inconsistency (`step-06-task-runner.md:285`)
- [VERIFIED] No functionality lost — old sprint/backlog recipes superseded by `pf` recipe

**Handoff:** To SM for finish-story

## Delivery Findings

- No upstream findings during implementation.
### Reviewer (code review)
- No upstream findings during code review.

### Phase History

| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-03T00:00:00Z | 2026-03-03T00:00:00Z | 0s |
| implement | 2026-03-03T00:00:00Z | 2026-03-03T11:57:47Z | 11h 57m |
| review | 2026-03-03T11:57:47Z | 2026-03-03T11:59:09Z | 1m 22s |
| finish | 2026-03-03T11:59:09Z | - | - |

### Handoff History

| From | To | Gate | Result | Timestamp |
| setup (sm) | implement (dev) | sm_setup_exit | PASSED | 2026-03-03T11:54:31Z |
| implement (dev) | review (reviewer) | dev_exit | PASSED | 2026-03-03T11:57:47Z |
| review (reviewer) | finish (sm) | approval | PASSED | 2026-03-03T11:59:09Z |