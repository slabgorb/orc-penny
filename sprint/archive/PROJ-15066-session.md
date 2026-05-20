# Story 98-11: Settings.local.json shared merge model for multi-framework coexistence

## Story Details
- **ID:** 98-11
- **Jira:** PROJ-15066
- **Title:** Settings.local.json shared merge model for multi-framework coexistence
- **Points:** 5
- **Priority:** P1
- **Epic:** PROJ-14697 (Epic 98: Safe Install, Upgrade, and Namespace Isolation)
- **Workflow:** tdd

## Story Context

### Problem Statement
Current settings system (`.pennyfarthing/config.local.yaml`) doesn't support multiple frameworks coexisting. Each framework needs to contribute its own settings section, and changes should be merged together rather than overwriting each other.

### Solution Overview
Design a merge model for settings.local.json that:
1. Allows each framework to define its own settings namespace/section
2. Merges settings from multiple frameworks intelligently
3. Prevents conflicts and data loss during multi-framework coexistence
4. Maintains backward compatibility with current `.pennyfarthing/config.local.yaml` approach

### Key Files to Reference
- `pennyfarthing/packages/core/src/` — Core CLI including init/update commands
- `pennyfarthing/pennyfarthing-dist/` — Published package structure
- `.pennyfarthing/config.local.yaml` — Current local config approach
- `pennyfarthing/packages/core/src/init.ts` — Init logic
- `pennyfarthing/packages/core/src/update.ts` — Update logic

### Acceptance Criteria
1. **Design Phase:** Document merge strategy for settings.local.json
   - Define namespace/section approach
   - Define merge conflict resolution rules
   - Define rollback strategy

2. **Implementation Phase:** Create shared merge model
   - Implement merge function that handles multi-framework settings
   - Create migration path from config.local.yaml to settings.local.json
   - Add validation to detect conflicts early

3. **Testing Phase:** Ensure merge correctness
   - Test single-framework settings
   - Test multiple frameworks merging
   - Test conflict detection and resolution
   - Test backward compatibility

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-14T12:32:34Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-14 06:51:51 | 2026-02-14 06:52:40 | 49s |
| red | 2026-02-14 06:52:40 | 2026-02-14T12:03:23Z | 10m |
| green | 2026-02-14T12:03:23Z | 2026-02-14T12:24:47Z | 21m 24s |
| review | 2026-02-14T12:09:14Z | 2026-02-14T12:20:36Z | 11m |
| review | 2026-02-14T12:24:47Z | 2026-02-14T12:32:34Z | 7m |

## TEA Assessment

**Tests Required:** Yes
**Reason:** 5-point TDD story — core merge model needs comprehensive test coverage

**Test Files:**
- `pennyfarthing/packages/core/src/cli/utils/settings-merge.test.ts` — 57 tests across 12 describe blocks
- `pennyfarthing/packages/core/src/cli/utils/settings-merge.ts` — Stubs (types + empty implementations)

**Tests Written:** 57 tests covering 6 ACs

| AC | Tests | Coverage |
|----|-------|----------|
| AC1: Namespace/section approach | 6 | Framework contributions stored under namespace keys, metadata tracking, idempotent updates |
| AC2a: Hook merging | 6 | Single/multi framework hooks, dedup, ordering, empty contributions |
| AC2b: Permission merging | 5 | Union, dedup, empty, stable ordering |
| AC2c: Scalar resolution | 4 | Priority-based, equal priority fallback, undefined when missing |
| AC2d: Conflict detection | 5 | Duplicate hooks, scalar collisions, no false positives |
| AC3: Migration from legacy | 6 | v1→v2, populate merged output, empty/missing fields, unknown keys |
| AC4: Framework removal | 5 | Clean removal, re-merge hooks/permissions, remove-only, remove-nonexistent |
| AC5: Flat format export | 6 | Strip internal fields, valid hooks/permissions/statusLine/context_budget, JSON round-trip |
| AC6: Validation | 7 | Correct structure, null/string/missing-version/wrong-version/missing-frameworks, empty valid |
| Integration | 3 | Full lifecycle, migrate-then-contribute, idempotency |

**Status:** RED (36 failing, 21 passing — failures on assertions, not imports)
**Commit:** `test: add failing tests for 98-11 settings merge model`

**Design Decisions:**
- New module `settings-merge.ts` — separate from existing `settings.ts` to avoid coupling
- `SharedSettings` type with `_version: 2`, `_frameworks`, `_contributions` internal fields
- `toFlatFormat()` strips internals for Claude Code compatibility
- Hooks: concatenated per type across frameworks, deduped within framework
- Permissions: unioned and deduped, alphabetically sorted for stability
- Scalars (statusLine, context_budget): priority-based with alphabetical tiebreak
- Conflicts are detected and reported but don't block merging

**Handoff:** To Dev (Agent Smith) for GREEN phase implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/packages/core/src/cli/utils/settings-merge.ts` — Full implementation of shared merge model (stubs → working code)

**Tests:** 57/57 passing (GREEN)
**PR:** #877 — feat(98-11): shared merge model for settings.local.json
**Branch:** feature/98-11-settings-local-shared-merge (pushed)

**Implementation Summary:**
- `contributeFrameworkSettings()` — immutable clone, store contribution + metadata, remerge, detect conflicts
- `removeFrameworkSettings()` — delete contribution + metadata, remerge remaining
- `mergeHooks()` — concatenate per hook type across frameworks, dedup within framework via serialized key
- `mergePermissions()` — union via Set, sort alphabetically for stability
- `resolveScalar()` — sort candidates by priority then alphabetical, return first
- `detectConflicts()` — command→framework map for hook duplicates, contributor count for scalar collisions
- `migrateToSharedFormat()` — extract known fields from legacy, create contribution, remerge
- `toFlatFormat()` — copy hooks/permissions/statusLine/context_budget, skip internal fields
- `validateSharedSettings()` — check _version, _frameworks, _contributions, hooks, permissions

**Handoff:** To Reviewer (The Merovingian) for code review

## Dev Assessment (Review Fixes)

**Fixes Applied:**
- `toFlatFormat()` — deep-clone hooks/permissions/statusLine/context_budget via `JSON.parse(JSON.stringify())` [MEDIUM #1]
- Renamed misleading test from "preserve unknown top-level keys" to "handle unknown keys gracefully without crashing" [MEDIUM #2]
- Removed dead `'permission_overlap'` type variant from `MergeConflict` union [LOW #3]
- Removed unused type imports `HookEntry`, `MergeConflict` from test file [LOW #4]

**Tests:** 57/57 passing (GREEN)
**Commit:** `fix(98-11): address reviewer feedback on settings merge model`
**Branch:** feature/98-11-settings-local-shared-merge (pushed)

**Handoff:** To Reviewer (The Merovingian) for re-review

## Reviewer Assessment

**Verdict:** REJECTED
**Tests:** 57/57 passing (confirmed independently)
**Build:** PASS
**Lint:** 2 warnings (unused type imports in test file)

**Data flow traced:** `contributeFrameworkSettings(settings, id, contribution)` → deep-clone input → store contribution under namespace → store/update framework metadata → `remerge()` → `mergeHooks()` + `mergePermissions()` + `resolveScalar()` twice → `detectConflicts()` → return `MergeResult`. Safe — all mutations on cloned data only.

**Fixes Required:**

| # | Severity | Issue | Location | Fix Required |
|---|----------|-------|----------|--------------|
| 1 | [MEDIUM] | `toFlatFormat` copies hooks/permissions by reference, not deep-clone — inconsistent with rest of module. Downstream mutation corrupts source. | `settings-merge.ts:381-382` | Deep-clone via `JSON.parse(JSON.stringify())` for hooks and permissions |
| 2 | [MEDIUM] | Test "preserve unknown top-level keys" is misleading — `customExtension` is silently dropped, test only validates structure | `settings-merge.test.ts:704` | Either rename test to reflect actual behavior ("should handle unknown keys gracefully") OR implement preservation of unknown keys |

**Also noted (non-blocking LOWs, fix if convenient):**

| # | Severity | Issue | Location |
|---|----------|-------|----------|
| 3 | [LOW] | Dead type variant `'permission_overlap'` in MergeConflict union — never generated | `settings-merge.ts:52` |
| 4 | [LOW] | Unused type imports: HookEntry, MergeConflict | `settings-merge.test.ts:34-35` |
| 5 | [LOW] | `hookEntryKey` dedup ignores HookCommand.type field | `settings-merge.ts:77` |

**Verified Good:**
- [VERIFIED] Immutability — all public functions deep-clone, never mutate input
- [VERIFIED] Permission dedup + stable alphabetical sort
- [VERIFIED] Scalar priority resolution — lower wins, alpha tiebreak
- [VERIFIED] Framework removal cascade — contribution + metadata + remerge
- [VERIFIED] No security vulnerabilities — pure data transformations

**Handoff:** Back to Dev (Agent Smith) for fixes

## Reviewer Assessment (Re-review)

**Verdict:** APPROVED
**Tests:** 57/57 passing (confirmed)
**Build:** PASS

**Fixes Verified:**
- [FIXED] `toFlatFormat` now deep-clones all fields via `JSON.parse(JSON.stringify())` — consistent with rest of module
- [FIXED] Test renamed to "should handle unknown top-level keys gracefully without crashing" — accurate
- [FIXED] Dead `'permission_overlap'` type variant removed
- [FIXED] Unused type imports removed

**Data flow traced:** `contributeFrameworkSettings` → deep-clone → store → remerge → `toFlatFormat` → deep-clone output. Full isolation chain verified end-to-end.
**Pattern observed:** Consistent deep-clone via `JSON.parse(JSON.stringify())` at every boundary at `settings-merge.ts:121,124,151,191,381-390`
**Error handling:** Graceful no-ops for missing frameworks, empty contributions. Validation returns error arrays rather than throwing.

**Handoff:** To SM (Morpheus) for finish-story

## Handoff History

| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| red (tea) | green (dev) | tests_fail | PASSED | 2026-02-14T12:03:23Z |
| green (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-14T12:09:14Z |
| review (reviewer) | green (dev) | approval | PASSED | 2026-02-14T12:20:36Z |
| green (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-14T12:24:47Z |
| review (reviewer) | finish (sm) | approval | PASSED | 2026-02-14T12:32:34Z |

## Notes
- This is part of the epic for safe install, upgrade, and namespace isolation
- Related to work on prefixing built-in skills/commands with pf- (story 98-4)
- Consider impact on existing user configurations when implementing
