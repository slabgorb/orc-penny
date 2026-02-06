# MSSCI-14373: End-to-end test - fresh repo install

**Status:** in_progress
**Phase:** finish
**Workflow:** tdd
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14373-e2e-fresh-install
**Jira:** MSSCI-14373
**Epic:** epic-85 (Clean Install Consolidation)

## Story Context

Part of Epic 85 (Clean Install Consolidation, MSSCI-14364), which moves all Pennyfarthing-managed files under `.pennyfarthing/`, updates init to bootstrap then hand off to an interactive workflow, and validates the install against real repos.

This is story 1.9 in the sequence (5 points, P0). It depends on stories 1.6-1.8 (Update init command MSSCI-14370, Update update command MSSCI-14371, Update doctor MSSCI-14372).

**Story description:** Automated test that creates a new empty git repo, runs `pennyfarthing init`, validates with doctor, and exercises the just scripts (dev, test, build). Iteratively adjust scripts and restart until everything passes. Clean up temp repo afterward.

## Acceptance Criteria

- Test creates a fresh empty git repo in a temp directory
- Runs `pennyfarthing init` in that repo
- Validates the installation with `pennyfarthing doctor` (should pass)
- Exercises the just scripts: dev, test, build
- Iteratively adjusts and restarts if scripts fail
- Cleans up the temp repo afterward
- All validations pass end-to-end

## Technical Notes

- 5-point TDD story
- E2E test for fresh repo installation flow
- Part of Clean Install Consolidation epic
- Key source files: `packages/core/src/cli/commands/init.ts`, `packages/core/src/cli/commands/doctor.ts`
- Init flow creates dirs, symlinks, copies commands/skills, installs hooks, generates templates, merges settings, writes manifest
- Doctor validates files are in correct `.pennyfarthing/` locations

## TEA Assessment

**Tests Required:** Yes
**Reason:** 5-point e2e story — comprehensive test coverage essential

**Test Files:**
- `packages/core/src/cli/commands/e2e-fresh-install.test.ts` — Full e2e test suite (25 tests)

**Tests Written:** 25 tests covering 6 ACs + edge cases + idempotency
**Status:** RED (24 pass, 1 fail — ready for Dev)

**Failing Test:**
- `should create settings.local.json with symlink` — `mergeSettingsLocalJson()` does not write PostToolUse hooks during fresh install. The settings file is created but missing `PostToolUse` and possibly `Stop`/`PreToolUse` hook entries.

**Root Cause:** The `mergeSettingsLocalJson()` in `packages/core/src/cli/utils/settings.ts` likely doesn't populate all required hooks when the settings template doesn't include them, or the template file (`settings.local.json.template`) is incomplete.

**Test Architecture:**
- Uses `node:test` + `node:assert` (project standard)
- Creates real temp directories with symlinked `node_modules/@pennyfarthing/core/pennyfarthing-dist` → actual repo dist
- Runs CLI binary via `spawnSync` for true e2e isolation
- Verifies: directories, symlinks, commands/skills copy, sidecars, git hooks, templates, manifest, settings, .gitignore, doctor validation, idempotency, edge cases

**Additional Finding:** Doctor's `--json` flag outputs header text before the JSON array (not clean JSON). The test uses `extractDoctorJson()` helper to work around this. Dev may want to fix `doctor.ts` to suppress non-JSON output when `--json` is passed.

**Handoff:** To Dev for implementation (fix `mergeSettingsLocalJson`)

## Session Log

- Setup: Session created, branch `feature/MSSCI-14373-e2e-fresh-install` created from develop
- Handoff: SM → TEA (red phase) - Story setup complete, TDD workflow
- TEA: Wrote 25 e2e tests, 24 pass, 1 fail (PostToolUse hooks missing from settings). Committed test file.
- Handoff: TEA → Dev (implement phase)
- Dev: Fixed settings.local.json.template — added missing PostToolUse hooks (bell-mode-hook, sprint-yaml-validation). 25/25 tests GREEN. PR #703 created.
- Handoff: Dev → Reviewer (review phase)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/templates/settings.local.json.template` - Added PostToolUse hooks section with bell-mode-hook and sprint-yaml-validation entries

**Tests:** 25/25 passing (GREEN)
**PR:** #703 - feat(MSSCI-14373): e2e test for fresh repo install
**Branch:** feature/MSSCI-14373-e2e-fresh-install (pushed)

**Root Cause:** The template was missing PostToolUse hooks entirely. When `mergeSettingsLocalJson()` creates settings from template on fresh install, it copies the template verbatim — so no PostToolUse meant no PostToolUse in the output.

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Template file → `mergeSettingsLocalJson()` → `.pennyfarthing/settings.local.json` → symlink at `.claude/settings.local.json`. Fresh install writes template verbatim; upgrade path merges missing hooks. Both paths now produce correct PostToolUse entries.
**Pattern observed:** Template entries match doctor.ts expected structure exactly at `doctor.ts:1182-1200` — bell-mode-hook (empty matcher) + sprint-yaml-validation (Edit|Write matcher)
**Error handling:** JSON parse failure caught at `settings.ts:164`, template-not-found at `settings.ts:126`, edge cases tested (no node_modules, no .git)
**Security:** No user input, no injection vectors, template contains only `$CLAUDE_PROJECT_DIR`-prefixed paths
**Tests:** 25/25 passing (GREEN), verified independently by preflight
**Observations:**
- [VERIFIED] PostToolUse hooks match doctor.ts expected format
- [VERIFIED] Hook scripts exist at `pennyfarthing-dist/scripts/hooks/`
- [VERIFIED] Idempotency: double-init still passes doctor
- [VERIFIED] Merge path for existing installs already handled PostToolUse
- [LOW] Hook ordering in template (Stop before PostToolUse) differs from doctor.ts (PostToolUse before Stop) — semantically irrelevant

**Handoff:** PR #703 merged. To SM for finish-story.

## Session Log (continued)

- Reviewer: Adversarial review complete. APPROVED — minimal fix, correct structure, all tests GREEN. PR #703 merged.
- Handoff: Reviewer → SM (finish phase)
