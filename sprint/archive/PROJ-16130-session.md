# Story 141-3: Audit Unexported Hooks — Export or Delete

**Jira:** PROJ-16130
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/PROJ-16130-audit-unexported-hooks
**Assignee:** keith.avery@slabgorb.io

## Summary
Audit the hooks directory — 33 hook files but only 13 exported from index.ts. Delete dead code (useMessageStream, usePlanModeExit), export all remaining active hooks, and add an audit test to prevent regression.

## Acceptance Criteria
- [ ] useMessageStream.ts deleted (replaced by ClaudeContext)
- [ ] usePlanModeExit.ts deleted (never wired into UI)
- [ ] All remaining hooks exported from index.ts with their public types
- [ ] Audit test verifies every use*.ts has a corresponding export
- [ ] Build compiles clean
- [ ] No stale imports remain

## Technical Approach
1. Delete useMessageStream.ts and usePlanModeExit.ts (and its test)
2. Add exports for all 17 previously-unexported hooks to index.ts, grouped by category
3. Clean up stale references in doc comments
4. Write shell-based audit test consistent with existing test patterns

## Assessment: setup → red

**SM Assessment:** Story set up. Jira claimed (PROJ-16130), session created, feature branch `feat/PROJ-16130-audit-unexported-hooks` in pennyfarthing repo. Implementation already completed during planning — changes are unstaged on the feature branch. TEA should verify tests cover the acceptance criteria: deleted hooks don't exist, all remaining hooks are exported, build compiles clean. The audit test at `tests/unit/test_hooks_export_audit.sh` already passes (33/33). TEA to confirm coverage is sufficient and add any missing test cases.

## TEA Assessment

**Tests Required:** Yes (enhanced existing)
**Reason:** Audit test existed but had gaps — added stale import detection, deprecation comment cleanup checks, and value export verification.

**Test Files:**
- `tests/unit/test_hooks_export_audit.sh` - Enhanced from 33 to 68 assertions across 5 sections

**Tests Written:** 68 assertions covering all 6 ACs
**Status:** GREEN (chore bypass — implementation completed alongside tests during planning)

**Test Sections:**
1. Deleted hooks (2) — file existence checks for useMessageStream, usePlanModeExit
2. Stale imports (2) — grep source for lingering imports of deleted hooks
3. Deprecation comments (2) — index.ts clean of deleted hook references
4. Hook exports (31) — every use*.ts has `from './useX'` in index.ts
5. Value exports (31) — every hook has a non-type export (not type-only re-exports)

**Handoff:** To Dev for commit and any remaining cleanup

## Delivery Findings

### TEA (test design)
- No upstream findings during test design.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/public/hooks/index.ts` - Removed deprecation comment, added 17 hook exports grouped by category (Data, Debug/Analysis, Layout/UI, Agent/Workflow)
- `packages/core/src/public/hooks/useMessageStream.ts` - Deleted (dead code, replaced by ClaudeContext)
- `packages/core/src/public/hooks/usePlanModeExit.ts` - Deleted (never wired into UI)
- `packages/core/src/public/types/message.ts` - Removed stale useMessageStream reference from doc comment
- `packages/cyclist/tests/PROJ-14327-smooth-plan-mode-exit.test.ts` - Deleted (test for deleted hook)
- `tests/unit/test_hooks_export_audit.sh` - New audit test (68 assertions, 5 sections)

**Tests:** 68/68 passing (GREEN)
**Build:** Compiles clean
**Branch:** feat/PROJ-16130-audit-unexported-hooks (pushed)

**Handoff:** To Reviewer for code review

### Dev (implementation)
- No upstream findings during implementation.

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Barrel re-exports → hook source files → React/utils imports. No circular deps, all type/value exports resolve correctly.
**Pattern observed:** Grouped category exports (Data, Debug, Layout, Agent) at `index.ts:25-100` — clean organization matching existing section-comment pattern.
**Error handling:** N/A — barrel file, no runtime logic.

**Observations:**
1. `[VERIFIED]` Deletions safe — zero runtime consumers for useMessageStream and usePlanModeExit
2. `[VERIFIED]` Re-exported types (Helper, DEFAULT_AVATAR) trace to valid source modules
3. `[VERIFIED]` No circular dependencies in expanded barrel
4. `[VERIFIED]` Stale doc comment in message.ts cleaned up with correct grammar
5. `[LOW]` Audit test regex `^export {.*${hook_name}` could false-match overlapping prefixes (e.g., useColor vs useColorScheme) — non-blocking, current hooks are safe
6. `[VERIFIED]` useResponsiveLayout default export correctly excluded from barrel (named only)
7. `[VERIFIED]` Build + lint + 68/68 tests all green

**Handoff:** To SM for finish-story

### Reviewer (code review)
- **Improvement** (non-blocking): Audit test regex at `tests/unit/test_hooks_export_audit.sh:93` could false-match on hook name prefixes. Consider anchoring with word boundary. Affects `tests/unit/test_hooks_export_audit.sh` (minor robustness). *Found by Reviewer during code review.*