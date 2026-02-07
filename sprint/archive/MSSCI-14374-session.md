# MSSCI-14374: End-to-end test - existing repo upgrade

**Story:** MSSCI-14374
**Jira:** MSSCI-14374
**Epic:** epic-85 (Clean Install Consolidation)
**Points:** 3
**Priority:** P0
**Workflow:** tdd
**Phase:** finish
**PR:** https://github.com/1898andCo/pennyfarthing/pull/704
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14374-e2e-test-existing-repo-upgrade
**Assigned:** keithavery

## Description

Automated test that sets up an old-style install with files in .claude/ locations, runs pennyfarthing update, and validates migration. Doctor should pass, files should be in .pennyfarthing/, symlinks should exist for Claude Code compatibility. Clean up afterward.

## Acceptance Criteria

- [x] Test creates a temp directory with old-style install layout (.claude/ based)
- [x] Test runs `pennyfarthing update` against the old layout
- [x] Test validates files migrated to .pennyfarthing/
- [x] Test validates symlinks exist for Claude Code compatibility
- [x] Test runs doctor and confirms it passes
- [x] Test cleans up temp directory afterward
- [x] All tests pass

## Context

See `sprint/context/context-epic-85.md` for full epic context. Key source files:
- `packages/core/src/cli/commands/update.ts` - Update command with migration
- `packages/core/src/cli/commands/doctor.ts` - Health check and auto-repair
- `packages/core/src/cli/utils/constants.ts` - DIRECTORY_SYMLINKS, MANAGED_PATHS

## TEA Assessment

**Tests Required:** Yes — this story IS the test
**Test File:** `packages/core/src/cli/commands/e2e-upgrade.test.ts`
**Tests Written:** 34 tests covering all 7 ACs across 9 suites
**Status:** GREEN (all pass — the update command was already implemented in MSSCI-14371)

**Test Coverage by AC:**
- AC1 (legacy layout): 6 tests — validates git repo, legacy manifest, legacy symlinks, templates, sidecars, settings
- AC2 (run update): 2 tests — exit code 0, migration output
- AC3 (migration validation): 10 tests — manifest, templates, sidecars, settings, managedPaths, shared-context preserved
- AC4 (symlink compat): 5 tests — .pennyfarthing/ symlinks, .claude/commands+skills real dirs, settings symlink
- AC5 (doctor passes): 6 tests — no failures, manifest, symlinks, settings, session-start hook, no legacy files
- AC6 (cleanup): 1 test — afterEach removes temp dir
- Bonus: 4 tests — idempotency (double update) + edge cases (missing files, pre-migrated sidecars, no node_modules)

**Note:** This is a test-only story. The test itself IS the deliverable. Dev phase can be skipped — ready for Reviewer.

**Handoff:** To Dev (formality) → Reviewer for PR

## Session Log

- Setup by SM (Captain Bryant)
- Handoff to TEA (Rick Deckard) for test design phase
- TEA wrote 34 tests, all GREEN (update command already implemented)
- Committed: `test: add e2e test for existing repo upgrade (MSSCI-14374)`
- Handoff to Dev (Roy Batty) — test-only story, all 34 tests pass, no implementation needed
- Dev verified GREEN state (34/34 pass), pushed branch, created PR #704
- Handoff to Reviewer (J.F. Sebastian) for PR review

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] Legacy layout setup is comprehensive and realistic — `e2e-upgrade.test.ts:163-306`
2. [VERIFIED] Data flow: legacy manifest → update → .pennyfarthing/manifest.json (atomic rename)
3. [VERIFIED] User content preservation: preferences.yaml and shared-context.md
4. [VERIFIED] Sidecar no-clobber: pre-existing new-location content not overwritten
5. [VERIFIED] Error handling: partial migration, pre-migrated sidecars, missing node_modules
6. [LOW] `.claude/project/agents/{agent}-sidecar/` legacy path not exercised (non-blocking)
7. [VERIFIED] Constants match source of truth in constants.ts and update.ts
8. [VERIFIED] Cleanup reliable — afterEach + finally blocks
9. [VERIFIED] No forbidden patterns (no console.log, .skip, .only, TODO)
10. [VERIFIED] Follows established e2e-fresh-install.test.ts patterns exactly

**Tests:** 34/34 pass, build clean, no forbidden patterns
**Security:** N/A (test-only, no user input handling)

**Handoff:** To SM for finish-story

- Reviewer APPROVED PR #704, merging
- PR #704 merged to main
- SM (Captain Bryant) completing finish flow — story DONE
