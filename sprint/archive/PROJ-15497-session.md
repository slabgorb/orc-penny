# Story 126-9: Remove Node init.ts, npx entry point, postinstall.cjs

**Jira:** PROJ-15497
**Status:** in-progress
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/126-9-remove-node-init-npx-postinstall

## Acceptance Criteria

- init.ts removed
- npx pennyfarthing entry point removed from package.json bin
- postinstall.cjs removed
- setup-detector.js removed
- session-start.js removed (functionality in Python)
- No Node-based init code remains

## Story Context

Remove all Node-based installation artifacts that are replaced by Python-first approach. Clean up package.json bin entries. Remove setup-detector.js and session-start.js.

## Technical Approach

- Identify and remove Node-specific entry points (init.ts, npx wrapper, postinstall.cjs)
- Remove setup-detector.js and session-start.js
- Clean up package.json bin entries
- Ensure Python-first installation path is not broken by removals
- Verify no remaining references to removed files

## SM Assessment

Straightforward cleanup story — remove Node-based installation artifacts replaced by Python-first approach. 2-point trivial workflow, no test design needed. Six files to remove plus package.json bin cleanup. Dev should verify no remaining imports or references to removed files before committing.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/cli/commands/init.ts` - deleted (Node init command)
- `packages/core/bin/pennyfarthing.js` - deleted (npx entry point)
- `scripts/postinstall.cjs` - deleted (npm postinstall hook)
- `packages/core/src/cli/commands/e2e-fresh-install.test.ts` - deleted (tested init flow)
- `packages/core/src/cli/utils/install-helpers.ts` - new (extracted installGitHooks, generatePyprojectToml)
- `packages/core/src/cli/index.ts` - removed init command registration
- `packages/core/src/cli/commands/update.ts` - updated imports, error messages
- `packages/core/src/cli/commands/hook-chaining.test.ts` - updated import path
- `packages/core/src/cli/commands/e2e-upgrade.test.ts` - updated CLI_BIN path
- `packages/core/src/cli/commands/pyproject-install.test.ts` - updated CLI_BIN path
- `packages/core/src/cli/workspace.test.ts` - removed bin assertions
- `package.json` - removed bin, postinstall, files entries
- `packages/core/package.json` - removed bin, files entries
- `tests/fixtures/package-manifest.json` - removed bin/postinstall references

**ACs:**
- [x] init.ts removed
- [x] npx pennyfarthing entry point removed from package.json bin
- [x] postinstall.cjs removed
- [x] setup-detector.js removed (already gone prior)
- [x] session-start.js removed (already gone prior; .sh hook version retained)
- [x] No Node-based init code remains

**Tests:** 209 pre-existing failures, 0 regressions (verified against develop baseline)
**Branch:** feature/126-9-remove-node-init-npx-postinstall (pushed)

**Note:** String references to `pennyfarthing init` remain in error messages across skill.ts, command.ts, doctor.ts, theme.ts, version.ts, uninstall.ts — these are user-facing messages in other commands, not init code. Follow-up story recommended.

**Handoff:** To Reviewer (Granny Weatherwax)

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `update.ts` → `install-helpers.js` imports verified, function signatures match, paths resolve correctly
**Pattern observed:** Clean extraction pattern — shared functions lifted from deleted module to utils, all consumers updated at `packages/core/src/cli/commands/update.ts:27`, `hook-chaining.test.ts:33`
**Error handling:** `installGitHooks` gracefully handles missing .git, missing sources, dryRun; `generatePyprojectToml` handles all skip conditions. No regressions.
**Security:** No user input flows through changed code. No injection vectors.

| Severity | Observation | Location |
|----------|-------------|----------|
| [VERIFIED] | Clean extraction to install-helpers.ts | `packages/core/src/cli/utils/install-helpers.ts` |
| [VERIFIED] | No broken imports from deleted init.ts | All CLI source |
| [VERIFIED] | CLI_BIN path updates correct | `e2e-upgrade.test.ts:44`, `pyproject-install.test.ts:38` |
| [VERIFIED] | Error messages updated to `pf setup` | `update.ts:57,98` |
| [VERIFIED] | No forbidden patterns in changed files | All changed files |
| [MEDIUM] | ~30 stale `pennyfarthing init` references in untouched files — follow-up story needed | skill.ts, command.ts, theme.ts, etc. |
| [VERIFIED] | Test fixture correctly updated | `package-manifest.json` |
| [VERIFIED] | workspace.test.ts bin→module check | `workspace.test.ts:119-123` |
| [VERIFIED] | Pre-existing test failures, 0 regressions | packages/shared, cyclist |

**Handoff:** To SM (Captain Carrot) for finish-story

## Session Log

- **Setup:** Session created by SM - ticket claimed, story staged, branch created at feature/126-9-remove-node-init-npx-postinstall
- **Implement:** Removed init.ts, bin/pennyfarthing.js, postinstall.cjs. Extracted shared functions to install-helpers.ts. Updated all imports and test references. 0 regressions.