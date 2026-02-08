# Session: 81-3 — Dead code API + React hook + dialog

**Story:** 81-3
**Jira:** MSSCI-14460
**Status:** in-progress
**Phase:** finish
**Workflow:** tdd
**Branch:** feature/MSSCI-14460-dead-code-api-hook-dialog
**Repos:** pennyfarthing
**Points:** 1
**Assigned:** Claude

## Description

Express API: GET /api/dead-code?days=180&repo=pennyfarthing. React hook: useDeadCode.ts. Dialog: DeadCodeDialog.tsx with tabs (Stale Files | Unused Exports), sortable tables, confidence badges. Add button to DebugPanel launcher row.

## Acceptance Criteria

- GET /api/dead-code?days=180&layer=all returns valid JSON matching DeadCodeResult schema
- GET /api/dead-code?days=180&layer=stale returns only stale files
- GET /api/dead-code?days=180&layer=exports returns only unused exports
- GET /api/dead-code?repo=pennyfarthing&days=180 scopes analysis to named repo
- Express router sets PYTHONPATH and has 30s timeout (matching hotspots.ts)
- createDeadCodeRouter exported from api/index.ts, mounted at /api/dead-code in server.ts
- useDeadCode hook provides { data, isLoading, error, refresh } with AbortController cleanup
- DeadCodeDialog with two tabs: "Stale Files" and "Unused Exports" with Badge counts
- Stale files table: sortable columns (File, Days Stale, Size, Last Commit)
- Unused exports table: sortable columns (File, Export, Line)
- No delete/modify buttons — diagnostic only
- Loading and error states handled

## Assessment

**SM Assessment:** Story 81-3 set up for TDD workflow. Session created, branch created in pennyfarthing repo, Jira claimed. Rich story context available at sprint/context/context-story-MSSCI-14460.md with reference patterns (hotspots.ts, useHotspots.ts, ConfirmDialog.tsx) and full technical approach. Handing off to TEA for test design (red phase).

**Handoff → TEA (red phase)**

## TEA Assessment

**Tests Required:** Yes
**Reason:** Full Cyclist integration layer — Express router, React hook, React dialog

**Test Files:**
- `tests/MSSCI-14460-dead-code-api.test.ts` — Express router: 15 tests covering python module call, query params (days/layer/repo), PYTHONPATH, 30s timeout, JSON parsing, error handling
- `tests/MSSCI-14460-useDeadCode.test.ts` — React hook: 14 tests covering return shape, loading/error states, AbortController cleanup, query param construction, refresh abort
- `tests/MSSCI-14460-DeadCodeDialog.test.tsx` — Dialog component: 18 tests covering two tabs, badge counts, sortable column headers, data rows, diagnostic-only (no delete buttons), loading/error states, props

**Stub Files (for import resolution):**
- `src/api/dead-code.ts` — empty router, no routes
- `src/public/hooks/useDeadCode.ts` — types + no-op hook
- `src/public/components/DeadCodeDialog.tsx` — renders null

**Tests Written:** 47 tests covering 18 ACs (42 failing, 5 structural passing)
**Status:** RED (failing — ready for Dev)

**Notes for Dev:**
- Python models use `symbol`/`file`/`line` (not `export_name`/`path`/`line_number`) — tests match the actual `models.py` field names
- Story context has code samples for all three files — follow hotspots.ts pattern closely
- `api/index.ts` already exports other routers — add `createDeadCodeRouter` there
- No shadcn tabs component — use custom button-based tabs with `cn()` styling

**Handoff → Dev (implement phase)**

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/api/dead-code.ts` — Express router mirroring hotspots.ts pattern: execFile with PYTHONPATH, 30s timeout, JSON parse, error handling
- `packages/cyclist/src/public/hooks/useDeadCode.ts` — React hook with fetch, AbortController, loading/error state management
- `packages/cyclist/src/public/components/DeadCodeDialog.tsx` — Dialog with custom tab buttons, Badge counts, sortable stale files and unused exports tables
- `packages/cyclist/src/api/index.ts` — Added createDeadCodeRouter export
- `packages/cyclist/src/server.ts` — Mounted at /api/dead-code

**Tests:** 47/47 passing (GREEN)
**PR:** #754 — feat(81-3): dead code API + React hook + dialog
**Branch:** feature/MSSCI-14460-dead-code-api-hook-dialog (pushed)

**Handoff → Reviewer for code review**

## Reviewer Assessment

**Verdict:** APPROVED

**Preflight:** Tests 1577/1577 pass (1 skip), build clean, 0 new lint warnings (31 pre-existing in other files).

**Data flow traced:** `DeadCodeDialog` → `useDeadCode` → `fetch('/api/dead-code?...')` → Express router → `execFile('python3', ['-m', 'pennyfarthing_scripts.deadcode', ...])` → JSON parsed → hook state → dialog render. Complete end-to-end wiring verified.

**Pattern observed:** All three files mirror established patterns exactly — `dead-code.ts` matches `hotspots.ts`, `useDeadCode.ts` matches `useHotspots.ts`, dialog follows component conventions with `cn()` tab styling.

**Security analysis:** `execFile` (not `exec`) prevents shell injection. Query params passed as array elements. `res.ok` checked before JSON parse in hook. AbortController prevents state-after-unmount.

**Error handling:** API layer returns 500 with `{success: false, error}` on execFile failure and JSON parse failure. Hook handles HTTP errors, network errors, and abort errors correctly.

**Observations:**
- [VERIFIED] Pattern conformance — mirrors hotspots.ts at `api/hotspots.ts:1-68`
- [VERIFIED] Command injection resistance at `dead-code.ts:30` (execFile, not exec)
- [VERIFIED] AbortController cleanup at `useDeadCode.ts:49-96`
- [VERIFIED] fetch error handling checks `res.ok` at `useDeadCode.ts:73`
- [VERIFIED] Diagnostic-only dialog — no action buttons at `DeadCodeDialog.tsx:106-146`
- [LOW] Sort logic duplication at `DeadCodeDialog.tsx:45-73` (style, not blocking)
- [VERIFIED] 47 tests cover all 18 ACs across 3 test files
- [VERIFIED] Server mount at `server.ts:150` follows codebase convention

**Handoff:** To SM for finish-story
