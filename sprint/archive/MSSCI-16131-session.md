# Story 141-4: Remove Deprecated Bikerack Shim and Stale References

**Status:** in-progress
**Phase:** finish
**Workflow:** trivial
**Repos:** pennyfarthing
**Branch:** feat/141-4-remove-deprecated-bikerack-shim
**Jira:** MSSCI-16131

## Story Context

This story is part of Epic 141 (Tech Debt Audit), which addresses technical debt findings from March 2026. Story 141-4 specifically targets cleanup of deprecated bikerack references and stale code that's no longer needed.

The bikerack.ts shim in the cyclist package was created as a compatibility layer but is now deprecated. Additionally, there are stale references to the old packages/bikerack/ and packages/shared/ directories that should be removed from the source code.

## Acceptance Criteria

- cyclist/src/bikerack.ts shim file is removed
- No source code references packages/bikerack/ (provenance headers acceptable)
- No source code imports from packages/shared/
- Build and tests pass after removal

## Technical Approach

1. Locate and remove the cyclist/src/bikerack.ts shim file
2. Search the codebase for any imports from packages/bikerack/ (excluding provenance headers)
3. Search the codebase for any imports from packages/shared/ and remove them
4. Run build verification (pnpm build)
5. Run test suite (pnpm test)
6. Verify no broken imports remain

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/bikerack.ts` — deleted deprecated shim (AC1)
- `packages/core/src/public/data-source.ts` — updated stale packages/bikerack/ comment (AC2)
- `packages/cyclist/tests/124-4-rewire-cyclist-bikerack.test.ts` — removed test asserting bikerack.ts exists (AC2)
- `packages/cyclist/src/server.ts` — updated stale bikerack.ts comment (AC2)
- `justfile` — updated dev server entry from bikerack.ts to core/entry.ts (AC2)
- `pennyfarthing-dist/guides/bikerack.md` — updated Key Files table (AC2)
- `CLAUDE.md` — removed stale packages/shared/ from directory table (AC3)
- `packages/core/src/shared/skill-suggest.test.ts` — fixed stale packages/shared/ path in comment (AC3)
- `packages/core/src/shared/generate-skill-docs.test.ts` — fixed stale packages/shared/ path in comment (AC3)

**Tests:** 1919/1919 passing (GREEN)
**Branch:** feat/141-4-remove-deprecated-bikerack-shim (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Preflight:** Build clean, 1919/1919 tests green, lint clean
**Data flow traced:** justfile dev-server entry → `../core/src/server/entry.ts` → `createTerminalServer()` → server.listen (functionally identical to deleted shim path)
**Pattern observed:** Provenance comment preserved correctly at `packages/core/src/public/data-source.ts:6` — AC explicitly allows this
**Error handling:** N/A — deletion story, no new error paths introduced
**Observations:** 5 verified good, 1 low (dead `IS_BIKERACK` env var in justfile:359, not in scope)
**Handoff:** To SM for finish-story

## Delivery Findings

<!-- delivery-findings -->
### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): Dead `IS_BIKERACK=1` export at `justfile:359` serves no purpose — tests enforce this env var is unused by source code.
  Affects `justfile` (remove dead env var export).
  *Found by Reviewer during code review.*