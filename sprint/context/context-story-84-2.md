# Story Context: 84-2 - Health score API + gauge component

## Summary

Add a thin Express API route (`GET /api/health-score`) that shells out to the Python health score module from story 84-1, a React hook (`useHealthScore.ts`) with 60-second auto-polling, and a radial gauge component (`HealthGauge.tsx`) mounted in the DebugPanel header. The gauge displays the composite score 0-100 with green/yellow/red coloring based on grade bands, shows dimension availability ("6/8 dimensions"), and renders a grey/empty state when no data exists.

## Current State

### Express API layer

The Express API follows a consistent pattern for Python-backed observatory tools. The hotspots router at `packages/cyclist/src/api/hotspots.ts` (59 lines) is the exact template:

- `createHotspotsRouter(getProjectDir)` at line 6 creates a `Router`
- `router.get('/')` at line 10 handles the GET request
- Lines 15-26 build the `python3 -m` args array
- Lines 31-34 call `execFile('python3', args, { cwd, env, timeout: 30000 })`
- Lines 36-43 handle errors, lines 45-54 parse JSON response

The router is exported from `packages/cyclist/src/api/index.ts` at line 9:
```typescript
export { createHotspotsRouter } from './hotspots.js';
```

And mounted in `packages/cyclist/src/server.ts` at lines 137-138:
```typescript
// Hotspot analysis API
app.use('/api/hotspots', createHotspotsRouter(getProjectDir));
```

The server imports the router from the API index at line 33:
```typescript
createHotspotsRouter,
```

### React hook layer

The `useHotspots` hook at `packages/cyclist/src/public/hooks/useHotspots.ts` (113 lines) is the reference:

- Lines 4-48 define TypeScript interfaces matching the Python result shapes
- Lines 50-60 define `UseHotspotsOptions` and `UseHotspotsReturn` interfaces
- Lines 62-113 implement the hook with `useState`, `useCallback`, `useRef`, `useEffect`
- Lines 68-72 cancel in-flight requests via `AbortController`
- Lines 85-100 fetch from `/api/hotspots` with query params
- Lines 103-110 clean up abort controller on unmount

The hook does NOT auto-poll. The health score hook needs to add a 60-second `setInterval` for periodic refresh since the health score is a dashboard-level metric.

### DebugPanel

`packages/cyclist/src/public/components/panels/DebugPanel.tsx` (268 lines) currently has:

- Lines 1-15: imports (React, Button, Badge, Separator from shadcn)
- Lines 17-40: `ContextData` interface
- Lines 54-65: `formatComponentName()` helper
- Lines 76-91: `calculateTierSavings()` helper
- Lines 93-130: `DebugPanel` component setup (state, WebSocket connections)
- Lines 135-136: outer div and `<h4>Context Usage</h4>` heading
- Lines 137-222: context info block (tier badge, component breakdown, context bar)
- Lines 224: `<Separator>` between context and token stats
- Lines 226-262: token stats section
- Lines 264-268: closing divs and default export

The HealthGauge should be inserted between the opening `<div className="debug-panel">` (line 136) and the `<h4>Context Usage</h4>` heading (line 137), occupying approximately 80-100px of vertical space.

### Existing gauge-like component

`packages/cyclist/src/public/components/ui/progress.tsx` (28 lines) is a shadcn Progress bar (linear, not radial). It uses Radix `ProgressPrimitive.Root` with an `indicatorClassName` prop extension (line 9). The HealthGauge will be a custom SVG radial gauge, not based on this linear component.

### No health score API, hook, or gauge exists yet

None of the three deliverables exist. The `api/index.ts` has no health score export, `server.ts` has no health score mount, and DebugPanel has no gauge.

## Target State

After implementation:

1. **`packages/cyclist/src/api/health-score.ts`** exists with `createHealthScoreRouter(getProjectDir)`, shells out to `python3 -m pennyfarthing_scripts.healthscore analyze --format json` with 15-second timeout
2. **`packages/cyclist/src/api/index.ts`** exports `createHealthScoreRouter` from `./health-score.js`
3. **`packages/cyclist/src/server.ts`** mounts the router at `/api/health-score` (after the hotspots mount at line 138)
4. **`packages/cyclist/src/public/hooks/useHealthScore.ts`** fetches from `/api/health-score` with 60-second auto-polling, returns `{ data, isLoading, error, refresh }`
5. **`packages/cyclist/src/public/components/HealthGauge.tsx`** renders an SVG radial gauge with score, grade letter, dimension count, and color based on grade band
6. **DebugPanel** imports and mounts `HealthGauge` above the "Context Usage" heading

## Key Files

### Files to Create

| File | Path | Purpose |
|------|------|---------|
| `health-score.ts` | `pennyfarthing/packages/cyclist/src/api/health-score.ts` | Express router: GET /, shells out to Python CLI |
| `useHealthScore.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useHealthScore.ts` | React hook with 60-second polling |
| `HealthGauge.tsx` | `pennyfarthing/packages/cyclist/src/public/components/HealthGauge.tsx` | SVG radial gauge component |

### Files to Modify

| File | Path | Lines | What Changes |
|------|------|-------|--------------|
| `api/index.ts` | `pennyfarthing/packages/cyclist/src/api/index.ts` | 40 | Add `export { createHealthScoreRouter } from './health-score.js'` |
| `server.ts` | `pennyfarthing/packages/cyclist/src/server.ts` | 138 area | Import `createHealthScoreRouter`, mount at `/api/health-score` |
| `DebugPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/DebugPanel.tsx` | 136-137 | Import `HealthGauge`, render between panel div and "Context Usage" heading |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| `hotspots.ts` | `pennyfarthing/packages/cyclist/src/api/hotspots.ts` | Express router pattern: `execFile` + `python3 -m` (lines 1-59) |
| `useHotspots.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useHotspots.ts` | React hook pattern: fetch + abort + state (lines 62-113) |
| `progress.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ui/progress.tsx` | Existing Radix gauge-like component for reference |
| `server.ts` | `pennyfarthing/packages/cyclist/src/server.ts` | Router mounting pattern (lines 107-138), `getProjectDir()` wrapper (lines 93-95) |
| `api/index.ts` | `pennyfarthing/packages/cyclist/src/api/index.ts` | Export barrel pattern (lines 1-39) |
| Epic context | `sprint/context/context-epic-84.md` | API contract (lines 122-240), grade bands (lines 242-251), gauge design (lines 300-308) |

## Technical Approach

### 1. Create `api/health-score.ts`

Follow the hotspots router pattern exactly, with two changes: shorter timeout (15s vs 30s since it reads cache) and no query parameters (no `--days`, `--repo`):

```typescript
import { Router } from 'express';
import { execFile } from 'child_process';
import { join } from 'path';

export function createHealthScoreRouter(getProjectDir: () => string): Router {
  const router = Router();

  router.get('/', (req, res) => {
    const projectDir = getProjectDir();
    const args = ['-m', 'pennyfarthing_scripts.healthscore', 'analyze', '--format', 'json'];
    const pythonPath = join(projectDir, 'pennyfarthing');

    execFile('python3', args, {
      cwd: pythonPath,
      env: { ...process.env, PYTHONPATH: pythonPath },
      timeout: 15000,  // 15s — reading cache is fast
    }, (err, stdout, stderr) => {
      if (err) {
        console.error('[HealthScore] Analysis failed:', stderr || err.message);
        res.status(500).json({ success: false, error: stderr || err.message });
        return;
      }

      try {
        const data = JSON.parse(stdout);
        res.json(data);
      } catch (parseErr) {
        console.error('[HealthScore] JSON parse failed:', parseErr);
        res.status(500).json({ success: false, error: 'Failed to parse health score output' });
      }
    });
  });

  return router;
}
```

### 2. Export and mount the router

**In `api/index.ts`** (after line 9, the hotspots export):
```typescript
export { createHealthScoreRouter } from './health-score.js';
```

**In `server.ts`** (after line 138, the hotspots mount):
```typescript
// Epic 84: Composite health score API
app.use('/api/health-score', createHealthScoreRouter(getProjectDir));
```

Add `createHealthScoreRouter` to the import block at lines 11-35.

### 3. Create `useHealthScore.ts` hook

Follow `useHotspots.ts` structure but add 60-second auto-polling:

```typescript
import { useState, useCallback, useRef, useEffect } from 'react';

export interface DimensionScore {
  name: string;
  label: string;
  weight: number;
  raw_value: number | null;
  score: number | null;
  available: boolean;
}

export interface HealthScoreData {
  success: boolean;
  score: number | null;
  grade: string | null;
  dimensions: DimensionScore[];
  available_dimensions: number;
  total_dimensions: number;
  cached_at: string | null;
  cache_ttl_seconds: number;
  error?: string;
}

export interface UseHealthScoreReturn {
  data: HealthScoreData | null;
  isLoading: boolean;
  error: Error | null;
  refresh: () => void;
}

const POLL_INTERVAL_MS = 60_000; // 60 seconds

export function useHealthScore(): UseHealthScoreReturn {
  const [data, setData] = useState<HealthScoreData | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  const fetchHealthScore = useCallback(() => {
    if (abortRef.current) {
      abortRef.current.abort();
    }

    const controller = new AbortController();
    abortRef.current = controller;

    setIsLoading(true);
    setError(null);

    fetch('/api/health-score', { signal: controller.signal })
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
        return res.json();
      })
      .then((json: HealthScoreData) => {
        setData(json);
        setIsLoading(false);
      })
      .catch((err) => {
        if (err.name === 'AbortError') return;
        setError(err instanceof Error ? err : new Error(String(err)));
        setIsLoading(false);
      });
  }, []);

  // Auto-poll every 60 seconds
  useEffect(() => {
    fetchHealthScore(); // initial fetch
    const interval = setInterval(fetchHealthScore, POLL_INTERVAL_MS);
    return () => {
      clearInterval(interval);
      if (abortRef.current) abortRef.current.abort();
    };
  }, [fetchHealthScore]);

  return { data, isLoading, error, refresh: fetchHealthScore };
}
```

### 4. Create `HealthGauge.tsx`

SVG radial gauge (semicircle arc) with:

- 180-degree arc with stroke color matching grade band
- Score number centered in the arc (`--/100` when no data)
- Grade letter below the number
- Dimension count text: "N of 8 dimensions" when partial
- Grey arc + "No data" text when `score` is null
- `onClick` prop to expand dimension breakdown (for story 84-3)

**Grade band colors** (from epic context lines 243-251):
```typescript
const GRADE_COLORS: Record<string, string> = {
  A: '#22c55e',  // Green
  B: '#84cc16',  // Green-yellow
  C: '#eab308',  // Yellow
  D: '#f97316',  // Orange
  F: '#ef4444',  // Red
};
```

**SVG approach**: Use `stroke-dasharray` and `stroke-dashoffset` on a `<circle>` or `<path>` element to draw a partial arc. The arc fills proportionally to the score (0-100 maps to 0-180 degrees).

### 5. Mount HealthGauge in DebugPanel

In `DebugPanel.tsx`, insert the gauge between the opening div and the "Context Usage" heading:

```tsx
// At line 136-137, change from:
<div className="debug-panel" data-testid="debug-panel">
  <h4>Context Usage</h4>

// To:
<div className="debug-panel" data-testid="debug-panel">
  <HealthGauge />
  <Separator className="my-3" />
  <h4>Context Usage</h4>
```

The `HealthGauge` component internally calls `useHealthScore()` to fetch and auto-refresh data. No props needed from DebugPanel for the basic gauge. Story 84-3 will add the `onDimensionClick` prop for drill-through.

## Acceptance Criteria

- `GET /api/health-score` returns JSON matching the `HealthScoreResult` schema from the epic context API contract (lines 122-240)
- API responds within 15 seconds (timeout enforced by `execFile`)
- API returns `{success: false, error: "..."}` when the Python module fails
- `useHealthScore()` hook auto-polls every 60 seconds
- Hook properly cancels in-flight requests on unmount (AbortController cleanup)
- Hook returns `{ data, isLoading, error, refresh }` matching the `UseHealthScoreReturn` interface
- HealthGauge renders a semicircle radial gauge with score 0-100 and grade letter
- Gauge uses correct colors: green (#22c55e) for A, green-yellow (#84cc16) for B, yellow (#eab308) for C, orange (#f97316) for D, red (#ef4444) for F
- Gauge renders grey/empty arc with `--/100` when no data is available (`score: null`)
- Gauge shows "N of 8 dimensions" text when partial data exists (`available_dimensions < total_dimensions`)
- HealthGauge is mounted in DebugPanel header area, above the "Context Usage" heading
- Gauge occupies approximately 80-100px of vertical space, does not displace existing DebugPanel content
- `createHealthScoreRouter` is exported from `api/index.ts`
- Router is mounted at `/api/health-score` in `server.ts`
- All TypeScript imports use `.js` extensions per project rules

## Dependencies

### Depends On

- **84-1** (Health score Python module) -- the Express API shells out to `python -m pennyfarthing_scripts.healthscore analyze --format json`. Without the Python module, the API returns an error. Development can proceed in parallel (API/hook/gauge can be built and tested with mock data), but the full integration requires 84-1 to be complete

### Depended On By

- **84-3** (Per-dimension drill-through) -- extends HealthGauge with an `onDimensionClick` callback prop and wires dimension breakdown items to dialog openers in DebugPanel

## Risks / Open Questions

1. **DebugPanel layout impact**: Adding an 80-100px gauge above "Context Usage" pushes all existing content down. On narrow dockview panels, this could require scrolling. Consider making the gauge collapsible to a single-line summary (e.g., "Health: 72.3 C") on narrow panels. Measure the panel height in practice before adding responsive logic.

2. **Polling frequency**: 60-second polling means one `execFile` call per minute per open Cyclist instance. Since the health score module reads cached files (not running analysis), this should be fast (<1 second). If the Python startup overhead is problematic, consider caching the result server-side in Node memory with a TTL, reducing `execFile` calls.

3. **SVG vs Canvas for gauge**: SVG is simpler to implement and style with CSS, and is consistent with React component patterns in the codebase. Canvas would be more performant for animations but overkill for a static gauge that updates every 60 seconds. Recommend SVG.

4. **shadcn integration**: The gauge is a custom SVG component, not a shadcn primitive. It should use CSS custom properties from the Cyclist theme system where possible (e.g., `var(--text-primary)` for text, `var(--bg-secondary)` for the empty arc track) for visual consistency.

5. **TypeScript interface alignment**: The `HealthScoreData` interface in the hook must exactly match the JSON output of the Python module. If the Python schema changes in 84-1, the TypeScript types must be updated. Consider generating types from a shared schema, or at minimum document the contract in both locations.

6. **Empty state UX**: When no observatory tools have been run at all, the gauge shows a grey arc with "--/100". This may confuse users who don't know what the gauge is. Consider adding a tooltip or hover text explaining "Run observatory tools to see your codebase health score" in the empty state.
