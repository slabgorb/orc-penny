# Story 83-3: Complexity + Dependencies APIs + hooks + dialogs

**Jira:** PROJ-14468
**Epic:** epic-83 (Complexity + Dependencies Tools)
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/83-3-complexity-deps-apis
**Assigned:** keith

## Description

Express APIs: GET /api/complexity, GET /api/dependencies
React hooks: useComplexity.ts, useDependencies.ts
Dialogs: ComplexityDialog.tsx (sortable table, threshold highlighting), DependenciesDialog.tsx (outdated table + security section). Add buttons to DebugPanel launcher row.

## Acceptance Criteria

- [ ] GET /api/complexity returns ComplexityResult JSON from Python module
- [ ] GET /api/dependencies returns DependenciesResult JSON from Python module
- [ ] useComplexity hook fetches and caches complexity data
- [ ] useDependencies hook fetches and caches dependencies data
- [ ] ComplexityDialog shows sortable table with threshold highlighting
- [ ] DependenciesDialog shows outdated packages table and security section
- [ ] DebugPanel launcher row has buttons for both dialogs
- [ ] All new code has tests (TDD workflow)

## Context

See `sprint/context/context-epic-83.md` for full architecture details.

Python modules already exist:
- `pennyfarthing_scripts/complexity/` — complexity analysis
- `pennyfarthing_scripts/dependencies/` — dependency analysis

This story creates the Express API layer, React hooks, and UI dialogs to surface these tools in Cyclist.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Full TDD workflow — APIs, hooks, dialogs, and panel integration all need tests

**Test Files:**
- `tests/PROJ-14468-complexity-api.test.ts` — AC1: Complexity API route (9 tests)
- `tests/PROJ-14468-dependencies-api.test.ts` — AC2: Dependencies API route (8 tests)
- `tests/PROJ-14468-useComplexity.test.ts` — AC3: useComplexity hook (12 tests)
- `tests/PROJ-14468-useDependencies.test.ts` — AC4: useDependencies hook (11 tests)
- `tests/PROJ-14468-ComplexityDialog.test.tsx` — AC5: ComplexityDialog component (9 tests)
- `tests/PROJ-14468-DependenciesDialog.test.tsx` — AC6: DependenciesDialog component (9 tests)
- `tests/PROJ-14468-debug-panel-tools.test.tsx` — AC7: DebugPanel launcher buttons (7 tests)

**Stub Files Created:**
- `src/api/complexity.ts` — API route stub (returns 501)
- `src/api/dependencies.ts` — API route stub (returns 501)
- `src/public/hooks/useComplexity.ts` — Hook stub (no-op refresh)
- `src/public/hooks/useDependencies.ts` — Hook stub (no-op refresh)
- `src/public/components/dialogs/ComplexityDialog.tsx` — Dialog stub
- `src/public/components/dialogs/DependenciesDialog.tsx` — Dialog stub

**Tests Written:** 69 tests covering 7 ACs
**Status:** RED (48 failing, 21 passing — failures are assertion-based, not compile errors)

**Implementation Notes for Dev:**
- Follow `hotspots.ts` pattern for API routes (createXxxRouter, execFile, PYTHONPATH)
- Follow `useHotspots.ts` pattern for hooks (useState, useCallback, AbortController)
- Follow `HotspotsDialog.tsx` pattern for dialogs (ToolDialog wrapper, sortable table)
- DebugPanel already has disabled Complexity button at line 293 — enable it and add Dependencies button
- Wire both dialogs into DebugPanel with useState for open state
- Python modules: `pennyfarthing_scripts.complexity` and `pennyfarthing_scripts.dependencies`

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `src/api/complexity.ts` - Express API route wrapping Python complexity module
- `src/api/dependencies.ts` - Express API route wrapping Python dependencies module
- `src/public/hooks/useComplexity.ts` - React hook with fetch, abort, error handling
- `src/public/hooks/useDependencies.ts` - React hook with fetch, abort, error handling
- `src/public/components/dialogs/ComplexityDialog.tsx` - Sortable table with threshold highlighting
- `src/public/components/dialogs/DependenciesDialog.tsx` - Outdated packages table + security section
- `src/public/components/panels/DebugPanel.tsx` - Enabled Complexity + added Dependencies launcher buttons
- `tests/PROJ-14468-DependenciesDialog.test.tsx` - Fixed overly-broad regex in advisory count test

**Tests:** 69/69 passing (GREEN)
**PR:** #757 - feat(83-3): complexity + dependencies APIs, hooks, dialogs
**Branch:** feature/83-3-complexity-deps-apis (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [CRITICAL] | API routes not wired to Express server — dead code at runtime. Hooks will 404. | `src/api/index.ts` (missing exports), `src/server.ts:146-152` (missing mount) | 1. Export `createComplexityRouter` and `createDependenciesRouter` from `src/api/index.ts` 2. Import and mount in `src/server.ts` with `app.use('/api/complexity', createComplexityRouter(getProjectDir))` and `app.use('/api/dependencies', createDependenciesRouter(getProjectDir))` |

**Data flow traced:** Button click → dialog opens → useEffect triggers refresh() → fetch(`/api/complexity`) → **404 at runtime** (route not mounted on Express server)
**Pattern observed:** Router implementations correctly follow hotspots.ts pattern, but wiring to server.ts was missed
**Error handling:** Correctly implemented in both routes and hooks (verified good)
**Security:** No injection risks — execFile uses array args, no string interpolation (verified good)

**Verified good:**
- API route implementations mirror hotspots.ts pattern exactly
- Hooks mirror useHotspots.ts pattern (AbortController, error handling)
- Dialogs mirror HotspotsDialog.tsx (ToolDialog wrapper, sortable table, loading/error states)
- DebugPanel button wiring correct with data-testid attributes
- No forbidden patterns, TypeScript clean, 69/69 tests passing

**Handoff:** Back to Dev for fixes

## Dev Assessment (Fix)

**Fix Applied:** Yes — wired API routes to Express server
**Files Changed:**
- `src/api/index.ts` - Added exports for `createComplexityRouter` and `createDependenciesRouter`
- `src/server.ts` - Imported and mounted both routers at `/api/complexity` and `/api/dependencies`

**Tests:** 69/69 passing (GREEN)
**PR:** #757 - updated with fix commit
**Branch:** feature/83-3-complexity-deps-apis (pushed)

**Handoff:** To Reviewer for re-review

## Reviewer Assessment (Re-review)

**Verdict:** APPROVED

**Fix verified:** `createComplexityRouter` and `createDependenciesRouter` now exported from `src/api/index.ts:47-48`, imported in `src/server.ts:37-38`, and mounted at `src/server.ts:155-156`
**Data flow traced:** Button click → dialog → useEffect → refresh() → fetch(`/api/complexity`) → Express route → execFile → JSON response (complete path, no 404)
**Pattern observed:** Mount calls use `getProjectDir` wrapper consistent with all other tool routes (hotspots, dead-code, code-markers, agent-load)
**Error handling:** execFile failure → 500 + error, JSON parse failure → 500 + descriptive error, hooks check `response.ok` (verified good)
**Security:** execFile with array args, no shell injection, PYTHONPATH to known dir (verified good)
**Tests:** 69/69 passing, TypeScript clean

**Handoff:** To SM for finish-story
