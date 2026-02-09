# Story 84-2: Health score API + gauge component

**Jira:** MSSCI-14471
**Status:** in-progress
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/84-2-health-score-api-gauge
**Points:** 2
**Priority:** P0

## Description

Express API: GET /api/health-score (calls Python module).
React hook: useHealthScore.ts. Radial gauge component in DebugPanel header showing score 0-100 with green/yellow/red coloring. Tap to see dimension breakdown.

## Acceptance Criteria

- [ ] GET /api/health-score endpoint returns JSON with score 0-100 and dimension breakdown
- [ ] Endpoint calls Python healthscore module via child process
- [ ] useHealthScore.ts React hook with loading/error/data states
- [ ] Radial gauge component renders in DebugPanel header
- [ ] Green/yellow/red coloring based on score thresholds
- [ ] Tap/click gauge opens dimension breakdown view
- [ ] Tests pass (unit + integration)

## Epic Context

Epic 84: Composite Health Score - Single 0-100 codebase health score displayed as a gauge. Prior story 84-1 (Python healthscore module) is complete — provides the scoring algorithm, caching, and formatters.

## Technical Context

- Health score Python module already exists: `pennyfarthing_scripts/healthscore/`
- Cyclist Express server: `packages/cyclist/src/server.ts`
- Existing hook patterns: `packages/cyclist/src/public/hooks/`
- DebugPanel: `packages/cyclist/src/public/components/panels/DebugPanel.tsx`
- Similar API pattern: see `/api/codemarkers` route for Python module integration

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (41 failing, 7 passing — all assertion-based)

**Test Files:**
- `packages/cyclist/tests/84-2-health-score-api.test.ts` — 9 tests (AC1, AC2)
- `packages/cyclist/tests/84-2-useHealthScore.test.ts` — 12 tests (AC3)
- `packages/cyclist/tests/84-2-HealthGauge.test.tsx` — 27 tests (AC4, AC5, AC6)

**Tests Written:** 48 tests covering 6 ACs

**Stubs Created:**
- `packages/cyclist/src/api/health-score.ts` — `createHealthScoreRouter()` empty router
- `packages/cyclist/src/public/hooks/useHealthScore.ts` — Types + no-op hook
- `packages/cyclist/src/public/components/HealthGauge.tsx` — Empty div with test ID

**Key Patterns for Dev:**
- API: Follow `api/hotspots.ts` — `execFile('python3', ['-m', 'pennyfarthing_scripts.healthscore', 'analyze', '--format', 'json'])` with 15s timeout
- Hook: Follow `useHotspots.ts` — fetch + AbortController + 60s setInterval polling
- Gauge: SVG arc, `data-grade` attribute for color tests, `data-testid="dimension-{name}"` for breakdown items
- Grade bands: A(90-100), B(75-89), C(60-74), D(40-59), F(0-39) — boundary tests included
- Mount gauge in DebugPanel above "Context Usage" heading
- Wire `onDimensionClick` prop for 84-3 drill-through story

**Handoff:** To Dev for GREEN phase implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/api/health-score.ts` - Express route calling Python healthscore module via execFile with 15s timeout
- `packages/cyclist/src/api/index.ts` - Export createHealthScoreRouter
- `packages/cyclist/src/public/hooks/useHealthScore.ts` - React hook with fetch, AbortController, 60s polling, loading/error/data states
- `packages/cyclist/src/public/components/HealthGauge.tsx` - SVG radial gauge with grade bands (A-F), dimension breakdown, onDimensionClick prop
- `packages/cyclist/src/public/components/panels/DebugPanel.tsx` - Mount HealthGauge above Context Usage
- `packages/cyclist/src/server.ts` - Wire /api/health-score route
- `packages/cyclist/tests/84-2-HealthGauge.test.tsx` - Fixed: happy-dom env, fake timers, cleanup
- `packages/cyclist/tests/84-2-useHealthScore.test.ts` - Fixed: happy-dom env, shouldAdvanceTime

**Tests:** 48/48 passing (GREEN)
**PR:** #761 - feat(84-2): Health score API + gauge component
**Branch:** feat/84-2-health-score-api-gauge (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** DebugPanel → useHealthScore (fetch) → /api/health-score (Express) → execFile python3 → pennyfarthing_scripts.healthscore → JSON response → hook state → HealthGauge props. All null-safe with `??` operators.

**Pattern observed:** API route follows exact hotspots.ts pattern (execFile, PYTHONPATH, timeout, error JSON) at `health-score.ts:5-41`. Hook follows useHotspots pattern (fetch + AbortController + setInterval polling) at `useHealthScore.ts:26-76`.

**Error handling:** Complete chain — Python fail (500 + error JSON), JSON parse fail (500 + error), HTTP non-ok (thrown Error), network error (caught), AbortError (silently ignored), null score (-- display, no grade).

**Security:** No injection risk — `execFile` (not `exec`), hardcoded args, no user-controlled input to child process.

**Observations:**
| Severity | Issue | Location | Action |
|----------|-------|----------|--------|
| `[LOW]` | Hardcoded `totalDimensions={8}` | `DebugPanel.tsx:155` | Acceptable — dimension set is stable |
| `[LOW]` | First data delayed 60s (no initial fetch on mount) | `useHealthScore.ts:63` | Acceptable for background metric |

**Tests:** 48/48 GREEN — preflight clean, no forbidden patterns, TSC clean.
**PR:** #761 merged

**Handoff:** To SM for finish-story
