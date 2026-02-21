# Story 117-8: Setup workflow should create config.local.yaml with theme

**Jira:** MSSCI-15383
**Workflow:** trivial
**Phase:** finish
**Status:** in_progress
**Repos:** pennyfarthing
**Branch:** fix/MSSCI-15383-setup-workflow-config-local
**Started:** 2026-02-21T00:00:00Z
**Assigned:** keith.avery@1898andco.io

## Story Context

After /pf-setup completes and sets theme in persona-config.yaml, config.local.yaml does not exist. Doctor reports 2 warnings ("No theme configured" for both persona-config and config checks) even though persona-config.yaml has the theme set correctly.

Fix: /pf-setup should create config.local.yaml with at minimum `theme: <selected-theme>` after writing persona-config.yaml. Alternatively, init could create it with a default.

Found during clean E2E install of orc-ax (2026-02-19).

## Acceptance Criteria

- [ ] After /pf-setup completes, config.local.yaml exists with `theme: <selected-theme>`
- [ ] Doctor no longer reports "No theme configured" warnings post-setup
- [ ] Existing config.local.yaml is preserved (not overwritten) if it already exists

## Technical Approach

Bug fix in the setup workflow — after writing persona-config.yaml with the selected theme, also create config.local.yaml if it doesn't exist. Type: bug, 2 points, trivial workflow.

## Reviewer Assessment (Round 1)

**Verdict:** REJECTED
| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | "Do not overwrite if it already exists" means user's theme selection doesn't propagate to config.local.yaml when init already created it with default theme | step-07-theme.md:134 | Change to "Create if missing, or update theme field if exists" |
| [MEDIUM] | Instructions block doesn't mention config.local.yaml | step-07-theme.md:12 | Add step 6 |

**Handoff:** Back to Dev for fixes

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED
**Data flow traced:** User selects theme → step-07 writes persona-config.yaml → step-07 creates/updates config.local.yaml → getCurrentTheme() reads config.local.yaml (priority 1) → correct theme active
**Pattern observed:** init.ts skipIfExistsTemplates pattern consistently applied at init.ts:457
**Error handling:** getCurrentTheme() catches parse errors on config.local.yaml, falls through to persona-config.yaml (themes.ts:102)
**Previous findings resolved:** Both HIGH and MEDIUM issues fixed in round 2

**Handoff:** To SM for finish-story

---

## Dev Assessment (Round 2)

**Implementation Complete:** Yes
**Reviewer Findings Addressed:**
- [HIGH] Changed "Do not overwrite" → "Update theme field, preserve other fields"
- [MEDIUM] Added step 6 to instructions: "Create or update config.local.yaml with selected theme"

**Files Changed:**
- `pennyfarthing-dist/workflows/project-setup/steps/step-07-theme.md` - Fixed instructions to create/update config.local.yaml with selected theme
- `pennyfarthing-dist/templates/config.local.yaml.template` - New template for config.local.yaml with default theme
- `packages/core/src/cli/commands/init.ts` - Added config.local.yaml to skipIfExistsTemplates list

**Tests:** 2,799/2,800 passing (GREEN) — 1 pre-existing failure in unrelated MSSCI-14320
**Branch:** fix/MSSCI-15383-setup-workflow-config-local (pushed, 2 commits)

**Handoff:** To Reviewer for re-review