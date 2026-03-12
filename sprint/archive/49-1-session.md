# Story 49-1: TirePump removal — finish React cleanup and stale references

**Status:** in_progress
**Phase:** finish
**Workflow:** trivial
**Repos:** pennyfarthing
**Branch:** feature/49-1-tirepump-removal
**Jira:**
**Epic:** 49 — Post-Migration Cleanup

## Acceptance Criteria
- Remove TirePump React components and stale references from the codebase
- Clean up any imports, exports, or configuration that reference TirePump
- Ensure no dead code remains related to TirePump after the Python WheelHub migration (ADR-0034)

## Technical Approach
TirePump was part of the pre-migration TypeScript/Node.js infrastructure. With the WheelHub migration to Python (ADR-0034) complete, the React components and any remaining references to TirePump are dead code. This story removes those stale artifacts from the `pennyfarthing/` repo — components, imports, configuration entries, and any test files that reference TirePump.

## SM Assessment
Story 49-1 is a 2-point trivial cleanup. TirePump React components and references are dead code after the WheelHub migration (ADR-0034). Straightforward removal — no design phase needed. Branch `feature/49-1-tirepump-removal` ready in `pennyfarthing/` repo. Handing to Dev for implement phase.

## Delivery Findings

<!-- delivery-findings-start -->
### Dev (implementation)
- No upstream findings during implementation.
### Reviewer (code review)
- **Improvement** (non-blocking): Stale scenario comment in `test-reflector.mjs:10` still lists `context` scenario after removal. Affects `packages/cyclist/scripts/test-reflector.mjs` (update header comment). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): CONTEXT_CLEAR marker detection in `useMarkerActions.ts:149` is now a dead code path (no consumer handles `context_clear` type). Affects `packages/core/src/public/hooks/useMarkerActions.ts` (clean up in story 49-2). *Found by Reviewer during code review.*
<!-- delivery-findings-end -->

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/public/components/ControlBar.tsx` — removed TirePump button, props, handler, context/persona WS subscriptions
- `packages/core/src/public/components/panels/MessagePanel.tsx` — removed TirePump prop passing
- `packages/core/src/public/contexts/ClaudeContext.tsx` — removed clearAndReload function and interface member
- `packages/core/src/public/App.tsx` — removed clearAndReload from mock context value
- `packages/core/src/public/styles/tailwind.css` — removed TirePump button and warning animation CSS
- `packages/cyclist/src/websocket.ts` — removed clearAndReload case handlers and callback infrastructure
- `packages/cyclist/README.md` — removed TirePump section
- `packages/cyclist/scripts/test-reflector.mjs` — removed CONTEXT_CLEAR test case
- `pennyfarthing-dist/guides/tirepump.md` — rewrote to reflect Python-only reality

**Tests:** Build passes clean (pnpm build succeeds across all 3 packages)
**Branch:** feature/49-1-tirepump-removal (pushed)

**Kept intact:** Python `context_window.py` (still calculates `use_tirepump` for handoff marker), `test_handoff_marker.py`, CHANGELOG entries (historical), CLAUDE.md glossary, spinner-tips, docs references to TirePump as a concept.

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** TirePump button click → onTirePump → handleTirePump → clearAndReload → WebSocket → server handler. Every link severed, no dangling references.
**Pattern observed:** Clean deletion pattern — all removed symbols verified absent from committed code at `ControlBar.tsx`, `ClaudeContext.tsx`, `websocket.ts`
**Error handling:** No new error paths introduced (pure deletion)
**Build:** Passes clean on story branch
**Handoff:** To SM (Stilgar) for finish-story

## Session Log
- Setup complete, ready for implement phase
- Dev: removed 237 lines of dead TirePump React/Cyclist code across 9 files