# Session: MSSCI-14369 — Consolidate sidecars directory

**Story:** MSSCI-14369
**Epic:** MSSCI-14364 (Clean Install Consolidation)
**Jira:** MSSCI-14369
**Workflow:** trivial
**Phase:** approved
**Branch:** feat/MSSCI-14369-consolidate-sidecars
**Repos:** pennyfarthing

## Acceptance Criteria

- [ ] Sidecars directory creation consolidated to single location in init/update
- [ ] Legacy sidecar locations cleaned up during migration
- [ ] All sidecar references point to `.pennyfarthing/sidecars/`
- [ ] No duplicate sidecar directories created

## Context

This story consolidates the sidecars directory handling. Currently, sidecars can exist in multiple locations:
- `.pennyfarthing/sidecars/{agent}/` (current canonical location)
- `.claude/project/agents/{agent}-sidecar/` (legacy)
- `sprint/sidecars/{agent}/` (legacy)

The update command already migrates from legacy locations, but init should create sidecars directly in `.pennyfarthing/sidecars/` and the migration paths in update should be cleaned up.

Key files:
- `packages/core/src/cli/commands/init.ts` — sidecar creation during init
- `packages/core/src/cli/commands/update.ts` — sidecar migration logic
- `packages/core/src/cli/utils/constants.ts` — CORE_AGENTS list
- `packages/core/src/cli/utils/symlinks.ts` — file operation helpers

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/cli/commands/update.ts` — Added cleanup of `.claude/project/agents/{agent}-sidecar/` dirs after migration, mirroring existing `sprint/sidecars/` cleanup
- `packages/core/src/cli/commands/doctor.ts` — Added legacy sidecar detection checks with `--fix` support for both legacy locations

**Tests:** 41/41 passing (GREEN) — update-consolidation.test.js
**PR:** #711 - feat(core): consolidate sidecar directory cleanup (MSSCI-14369)
**Branch:** feat/MSSCI-14369-consolidate-sidecars (pushed)

**Notes:** 3 pre-existing failures in doctor-legacy.test.js (statusline path detection) confirmed on clean branch — unrelated to this change.

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Legacy sidecar files copied to `.pennyfarthing/sidecars/` before legacy dirs removed — no data loss path
**Pattern observed:** Safe deletion guard (only remove when new location exists) consistent at `update.ts:314` and `doctor.ts:1557`
**Error handling:** try/catch on cleanup ops matches existing pattern — cleanup failures non-critical
**Edge cases verified:** No legacy dirs (no-op), new location missing (preserves legacy), dryRun (skips), non-sidecar content in agents/ (preserved)
**Pre-existing issues:** 3 doctor-legacy test failures (statusline path) and console.log at doctor.ts:89 — both pre-existing, not in diff

**Handoff:** To SM for finish-story

## Status Log

- Setup complete, ready for implementation
- Handoff to Dev (Toby Ziegler) for implementation
- Implementation complete, PR #711 created
- Handoff to Reviewer (Josh Lyman) for code review — PR #711
- APPROVED and merged PR #711. Handoff to SM for finish-story.
