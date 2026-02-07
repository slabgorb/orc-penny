# Story Context: 83-3 - Complexity + Dependencies APIs + hooks + dialogs

## Summary

Wire the Python complexity and dependencies modules (stories 83-1 and 83-2) into Cyclist's three-layer stack: Express API routes that shell out to the Python modules, React hooks that fetch from those APIs, and dialog components that display sortable tables with threshold highlighting and severity badges. Add launcher buttons to the DebugPanel so users can trigger complexity and dependency analysis from the UI.

## Current State

### Express API layer

The hotspots API (`packages/cyclist/src/api/hotspots.ts`, 59 lines) is the reference implementation. It exports a `createHotspotsRouter` factory function (line 6) that takes `getProjectDir: () => string`, creates a `Router()`, and has a single `GET /` handler (line 10) that calls `execFile('python3', ['-m', 'pennyfarthing_scripts.hotspots', 'analyze', '--format', 'json', ...])` with a 30-second timeout (line 34), parses JSON stdout (line 46), and returns the result.

The router is exported from `packages/cyclist/src/api/index.ts` (line 9: `export { createHotspotsRouter } from './hotspots.js'`) and mounted in `packages/cyclist/src/server.ts` at line 138: `app.use('/api/hotspots', createHotspotsRouter(getProjectDir))`.

The `getProjectDir()` function is defined in `server.ts` at line 93-95 as a wrapper around `getProjectDirectory()` with fallback to `process.cwd()`.

Currently there are no `/api/complexity` or `/api/dependencies` routes.

### React hooks layer

The `useHotspots` hook (`packages/cyclist/src/public/hooks/useHotspots.ts`, 113 lines) is the reference implementation. It defines TypeScript interfaces for the Python model types (lines 4-48), option/return types (lines 50-60), and a hook function (line 62) using `useState` for `data`/`isLoading`/`error` (lines 63-65), `useRef` for `AbortController` (line 66), `useCallback` for fetch with abort (line 68), and cleanup `useEffect` (line 104).

The fetch call at line 85 hits `/api/hotspots?${params}` with the abort signal, parses JSON, and updates state.

The hooks directory (`packages/cyclist/src/public/hooks/`) contains 25 hook files. There is a barrel export at `hooks/index.ts`.

Currently there are no `useComplexity.ts` or `useDependencies.ts` hooks.

### React dialog/panel layer

The `HotspotsPanel` (`packages/cyclist/src/public/components/panels/HotspotsPanel.tsx`, 365 lines) is the reference implementation for sortable table UI. Key patterns:

- **SortableHeader** component (lines 21-50): clickable `<th>` with sort direction indicator, `aria-sort` attribute
- **FileTable** component (lines 52-115): `useMemo` for sorted data (line 63), Badge with severity coloring (line 94: `variant={score >= 50 ? 'destructive' : score >= 25 ? 'outline' : 'secondary'}`)
- **Skeleton** loading state (lines 248-261)
- **Error state** with Retry button (lines 264-271)
- **Time window controls** (lines 279-289): Button group for 30d/60d/90d
- shadcn imports: `Button`, `Badge`, `Tooltip`, `TooltipContent`, `TooltipProvider`, `TooltipTrigger`, `Skeleton`

The panels are registered in `packages/cyclist/src/public/components/panels/index.ts` (26 lines) and referenced in `DockviewWorkspace.tsx` via the `PANEL_INVENTORY` const (lines 36-54) and `registerPanelComponent()` (line 67).

### DebugPanel

The `DebugPanel` (`packages/cyclist/src/public/components/panels/DebugPanel.tsx`, 268 lines) currently shows context usage (tokens, tier, component breakdown) and token stats (input/output/cache/cost). It uses `Button`, `Badge`, and `Separator` from shadcn. It does **not** have a "launcher row" for diagnostic tools yet -- the Hotspots panel is a separate dockview panel, not launched from Debug. The new Complexity and Dependencies dialogs will be launched from buttons added to the DebugPanel.

## Target State

After implementation:

1. **Two new Express API routes:**
   - `GET /api/complexity?path=<dir>` -- shells out to `python3 -m pennyfarthing_scripts.complexity analyze --format json --path <dir>`
   - `GET /api/dependencies?path=<dir>` -- shells out to `python3 -m pennyfarthing_scripts.dependencies check --format json --path <dir>`

2. **Two new React hooks:**
   - `useComplexity.ts` -- fetches `/api/complexity`, returns `{ data, isLoading, error, refresh }`
   - `useDependencies.ts` -- fetches `/api/dependencies`, returns `{ data, isLoading, error, refresh }`

3. **Two new React dialog components:**
   - `ComplexityDialog.tsx` -- sortable table of files by complexity metrics, threshold highlighting (red badge for cyclomatic > 10, yellow for > 5), triggered by a button
   - `DependenciesDialog.tsx` -- outdated packages table with version diff + security advisories section with severity badges, triggered by a button

4. **DebugPanel updated** with a launcher row containing "Complexity" and "Dependencies" buttons that open their respective dialogs.

## Key Files

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `complexity.ts` | `pennyfarthing/packages/cyclist/src/api/complexity.ts` | Express router: `GET /` -> `python3 -m pennyfarthing_scripts.complexity analyze --format json` |
| `dependencies.ts` | `pennyfarthing/packages/cyclist/src/api/dependencies.ts` | Express router: `GET /` -> `python3 -m pennyfarthing_scripts.dependencies check --format json` |
| `useComplexity.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useComplexity.ts` | React hook: fetch + abort + types |
| `useDependencies.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useDependencies.ts` | React hook: fetch + abort + types |
| `ComplexityDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/ComplexityDialog.tsx` | Sortable table with threshold highlighting |
| `DependenciesDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/DependenciesDialog.tsx` | Outdated table + security advisories section |

### Files to Modify

| File | Location | What Changes |
|------|----------|--------------|
| `index.ts` | `pennyfarthing/packages/cyclist/src/api/index.ts` | Add exports: `createComplexityRouter` and `createDependenciesRouter` (after line 9, following the `createHotspotsRouter` export) |
| `server.ts` | `pennyfarthing/packages/cyclist/src/server.ts` | Add imports (line 33-34 area) and mount routes: `app.use('/api/complexity', ...)` and `app.use('/api/dependencies', ...)` (after line 138 near the hotspots mount) |
| `DebugPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/DebugPanel.tsx` | Add launcher row with "Complexity" and "Dependencies" buttons, import and render dialogs |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `hotspots.ts` | `pennyfarthing/packages/cyclist/src/api/hotspots.ts` | Express router pattern: `createHotspotsRouter(getProjectDir)` factory (line 6), `execFile` with timeout (line 31), JSON parse (line 46) |
| `index.ts` | `pennyfarthing/packages/cyclist/src/api/index.ts` | Barrel exports -- understand where to add new router exports (line 9) |
| `server.ts` | `pennyfarthing/packages/cyclist/src/server.ts` | Route mounting pattern: import at line 33, mount at line 138 |
| `useHotspots.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useHotspots.ts` | React hook pattern: interfaces (lines 4-48), useState/useCallback/AbortController (lines 62-113) |
| `HotspotsPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/HotspotsPanel.tsx` | Sortable table UI: SortableHeader (lines 21-50), Badge severity coloring (line 94), Skeleton loading (lines 248-261) |
| `DebugPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/DebugPanel.tsx` | Current layout -- understand where to add launcher buttons (after line 263 Separator area) |
| `DockviewWorkspace.tsx` | `pennyfarthing/packages/cyclist/src/public/components/DockviewWorkspace.tsx` | Panel inventory (lines 36-54) -- may need to add entries if dialogs become panels |
| `panels/index.ts` | `pennyfarthing/packages/cyclist/src/public/components/panels/index.ts` | Panel barrel exports -- may need to add dialog exports |

## Technical Approach

### 1. Create Express API routers

**`api/complexity.ts`** -- Follow `hotspots.ts` exactly:

```typescript
import { Router } from 'express';
import { execFile } from 'child_process';
import { join } from 'path';

export function createComplexityRouter(getProjectDir: () => string): Router {
  const router = Router();

  // GET /api/complexity?path=<dir>
  router.get('/', (req, res) => {
    const projectDir = getProjectDir();
    const targetPath = (req.query.path as string) || projectDir;

    const args = [
      '-m', 'pennyfarthing_scripts.complexity',
      'analyze',
      '--format', 'json',
      '--path', targetPath,
    ];

    const pythonPath = join(projectDir, 'pennyfarthing');

    execFile('python3', args, {
      cwd: pythonPath,
      env: { ...process.env, PYTHONPATH: pythonPath },
      timeout: 30000,
    }, (err, stdout, stderr) => {
      if (err) {
        console.error('[Complexity] Analysis failed:', stderr || err.message);
        res.status(500).json({ success: false, error: stderr || err.message });
        return;
      }
      try {
        const data = JSON.parse(stdout);
        res.json(data);
      } catch (parseErr) {
        console.error('[Complexity] JSON parse failed:', parseErr);
        res.status(500).json({ success: false, error: 'Failed to parse complexity output' });
      }
    });
  });

  return router;
}
```

**`api/dependencies.ts`** -- Same pattern:

```typescript
export function createDependenciesRouter(getProjectDir: () => string): Router {
  const router = Router();

  // GET /api/dependencies?path=<dir>
  router.get('/', (req, res) => {
    const projectDir = getProjectDir();
    const targetPath = (req.query.path as string) || projectDir;

    const args = [
      '-m', 'pennyfarthing_scripts.dependencies',
      'check',
      '--format', 'json',
      '--path', targetPath,
    ];

    const pythonPath = join(projectDir, 'pennyfarthing');

    execFile('python3', args, {
      cwd: pythonPath,
      env: { ...process.env, PYTHONPATH: pythonPath },
      timeout: 30000,
    }, (err, stdout, stderr) => {
      // Same error handling pattern as hotspots.ts
      ...
    });
  });

  return router;
}
```

### 2. Register routes in `api/index.ts` and `server.ts`

**`api/index.ts`** -- Add after line 9 (the hotspots export):

```typescript
export { createComplexityRouter } from './complexity.js';
export { createDependenciesRouter } from './dependencies.js';
```

**`server.ts`** -- Add imports to the destructured import block (around lines 11-35):

```typescript
import {
  // ...existing imports...
  createComplexityRouter,
  createDependenciesRouter,
} from './api/index.js';
```

Add mounts after line 138 (the hotspots mount):

```typescript
// Complexity analysis API
app.use('/api/complexity', createComplexityRouter(getProjectDir));
// Dependency health API
app.use('/api/dependencies', createDependenciesRouter(getProjectDir));
```

### 3. Create React hooks

**`useComplexity.ts`** -- Follow `useHotspots.ts` pattern:

```typescript
import { useState, useCallback, useRef, useEffect } from 'react';

export interface FileComplexity {
  path: string;
  total_lines: number;
  longest_function: number;
  avg_cyclomatic_complexity: number;
  max_nesting_depth: number;
  function_count: number;
}

export interface ComplexityData {
  success: boolean;
  target_path: string;
  file_count: number;
  files: FileComplexity[];
  error?: string;
}

export interface UseComplexityOptions {
  path?: string;
}

export interface UseComplexityReturn {
  data: ComplexityData | null;
  isLoading: boolean;
  error: Error | null;
  refresh: () => void;
}

export function useComplexity(options: UseComplexityOptions = {}): UseComplexityReturn {
  const [data, setData] = useState<ComplexityData | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  const fetchComplexity = useCallback(() => {
    if (abortRef.current) abortRef.current.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    setIsLoading(true);
    setError(null);

    const params = new URLSearchParams();
    if (options.path) params.set('path', options.path);

    fetch(`/api/complexity?${params}`, { signal: controller.signal })
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
        return res.json();
      })
      .then((json: ComplexityData) => { setData(json); setIsLoading(false); })
      .catch((err) => {
        if (err.name === 'AbortError') return;
        setError(err instanceof Error ? err : new Error(String(err)));
        setIsLoading(false);
      });
  }, [options.path]);

  useEffect(() => {
    return () => { if (abortRef.current) abortRef.current.abort(); };
  }, []);

  return { data, isLoading, error, refresh: fetchComplexity };
}
```

**`useDependencies.ts`** -- Same pattern with dependency-specific types:

```typescript
export interface OutdatedPackage {
  package: string;
  current: string;
  wanted: string;
  latest: string;
  type: string;
  severity: string;
}

export interface SecurityAdvisory {
  package: string;
  severity: string;
  title: string;
  url: string;
  vulnerable_versions: string;
  recommendation: string;
}

export interface DependencySummary {
  total_outdated: number;
  major_updates: number;
  minor_updates: number;
  patch_updates: number;
  advisories_critical: number;
  advisories_high: number;
  advisories_moderate: number;
  advisories_low: number;
}

export interface DependencyData {
  success: boolean;
  target_path: string;
  outdated: OutdatedPackage[];
  advisories: SecurityAdvisory[];
  summary: DependencySummary;
  error?: string;
}

export interface UseDependenciesReturn {
  data: DependencyData | null;
  isLoading: boolean;
  error: Error | null;
  refresh: () => void;
}

export function useDependencies(options: { path?: string } = {}): UseDependenciesReturn {
  // Same useState/useCallback/AbortController pattern as useComplexity
  // Fetch from /api/dependencies?path=...
}
```

### 4. Create dialog components

**`ComplexityDialog.tsx`** -- Sortable table with threshold highlighting:

```tsx
import React, { useState, useMemo } from 'react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { useComplexity, FileComplexity } from '../../hooks/useComplexity';

// Threshold constants
const COMPLEXITY_HIGH = 10;
const COMPLEXITY_WARN = 5;
const NESTING_HIGH = 4;
const FUNCTION_LENGTH_HIGH = 50;

type SortField = 'avg_cyclomatic_complexity' | 'longest_function' | 'max_nesting_depth' | 'function_count' | 'total_lines' | 'path';

export function ComplexityDialog(): React.ReactElement {
  const { data, isLoading, error, refresh } = useComplexity();
  const [sortField, setSortField] = useState<SortField>('avg_cyclomatic_complexity');
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('desc');

  // SortableHeader pattern from HotspotsPanel lines 21-50
  // Badge severity: destructive for > COMPLEXITY_HIGH, outline for > COMPLEXITY_WARN
  // Table columns: Complexity | Longest Fn | Nesting | Functions | Lines | File
}
```

**`DependenciesDialog.tsx`** -- Two sections: outdated table + security advisories:

```tsx
export function DependenciesDialog(): React.ReactElement {
  const { data, isLoading, error, refresh } = useDependencies();

  // Section 1: Outdated Packages table
  //   Columns: Severity | Package | Current | Wanted | Latest | Type
  //   Badge colors: destructive for major, outline for minor, secondary for patch

  // Section 2: Security Advisories table
  //   Columns: Severity | Package | Title | Vulnerable Versions | Recommendation
  //   Badge colors: destructive for critical/high, outline for moderate, secondary for low

  // Summary bar at top with counts: "5 outdated (1 major) | 1 security advisory (high)"
}
```

### 5. Update DebugPanel with launcher buttons

Add a "Diagnostics" section to `DebugPanel.tsx` (after the Token Stats section ending at line 262) with buttons to open the complexity and dependencies dialogs:

```tsx
// After the Token Stats section (line 262)
<Separator className="my-3" />

<h4>Diagnostics</h4>
<div className="diagnostics-launcher" data-testid="diagnostics-launcher">
  <Button
    variant="outline"
    size="sm"
    onClick={() => setShowComplexity(true)}
    data-testid="launch-complexity"
  >
    Complexity
  </Button>
  <Button
    variant="outline"
    size="sm"
    onClick={() => setShowDependencies(true)}
    data-testid="launch-dependencies"
  >
    Dependencies
  </Button>
</div>

{showComplexity && (
  <ComplexityDialog onClose={() => setShowComplexity(false)} />
)}
{showDependencies && (
  <DependenciesDialog onClose={() => setShowDependencies(false)} />
)}
```

Add state variables for dialog visibility:

```tsx
const [showComplexity, setShowComplexity] = useState(false);
const [showDependencies, setShowDependencies] = useState(false);
```

## Acceptance Criteria

- `GET /api/complexity` returns JSON matching the contract in `context-epic-83.md` (success, target_path, file_count, files array)
- `GET /api/dependencies` returns JSON matching the contract in `context-epic-83.md` (success, target_path, outdated array, advisories array, summary)
- Both APIs use 30-second timeout and return `{success: false, error: "..."}` on failure
- `useComplexity` hook provides `{ data, isLoading, error, refresh }` with AbortController cleanup
- `useDependencies` hook provides `{ data, isLoading, error, refresh }` with AbortController cleanup
- ComplexityDialog shows sortable table with columns: Complexity, Longest Function, Nesting Depth, Functions, Lines, File
- ComplexityDialog highlights files exceeding thresholds: red badge for cyclomatic complexity > 10, yellow for > 5
- DependenciesDialog shows outdated packages table with severity badges (major=red, minor=yellow, patch=gray)
- DependenciesDialog shows security advisories section with severity badges (critical/high=red, moderate=yellow, low=gray)
- DebugPanel has "Complexity" and "Dependencies" buttons in a Diagnostics section
- Both dialogs show Skeleton loading state and error state with Retry button
- New routers are exported from `api/index.ts` and mounted in `server.ts`

## Dependencies

### Depends On

- **Story 83-1** (Python complexity module) -- the Express API shells out to `python3 -m pennyfarthing_scripts.complexity`
- **Story 83-2** (Python dependencies module) -- the Express API shells out to `python3 -m pennyfarthing_scripts.dependencies`
- **Existing Cyclist infrastructure:**
  - `hotspots.ts` router pattern (line 6 factory, line 31 execFile)
  - `server.ts` route mounting (line 138)
  - `api/index.ts` barrel exports (line 9)
  - `useHotspots.ts` hook pattern (line 62)
  - `HotspotsPanel.tsx` UI patterns (SortableHeader line 21, Badge line 94, Skeleton line 248)
  - shadcn components: `Button`, `Badge`, `Tooltip`, `Skeleton`, `Separator`

### Depended On By

- None -- this is the final story in Epic 83.

## Risks / Open Questions

1. **Dialog vs Panel:** The epic context says "dialogs" but the existing Hotspots tool is a full dockview panel. The approach here uses inline dialogs rendered within DebugPanel, which is simpler and avoids panel registration overhead. If users prefer standalone panels (like HotspotsPanel), the dialogs could be promoted to panels later by adding entries to `PANEL_INVENTORY` in `DockviewWorkspace.tsx` (line 36) and `panels/index.ts`.

2. **DebugPanel size:** Adding dialog content inline to DebugPanel could make it cluttered. Consider rendering dialogs as modals (using shadcn `Dialog` component) instead of expanding DebugPanel. This would keep the launcher buttons small and the content in a focused overlay.

3. **PYTHONPATH resolution:** The hotspots router sets `PYTHONPATH` to `join(projectDir, 'pennyfarthing')` (line 29 of `hotspots.ts`). This works in the orchestrator context where the framework is inlined at `pennyfarthing/`. In other deployment contexts, the path may differ. Both new routers should use the same pattern for consistency.

4. **Path parameter security:** Both APIs accept a `path` query parameter. This should be validated to prevent directory traversal attacks. Consider restricting to subdirectories of `projectDir` or using `path.resolve()` and checking it starts with `projectDir`.

5. **Hook auto-fetch vs manual:** The `useHotspots` hook requires the user to call `refresh()` manually (it doesn't auto-fetch on mount). The new hooks should follow the same pattern to avoid unexpected API calls when the dialog opens. The dialog's "Analyze" button triggers `refresh()`.

6. **shadcn Dialog component:** If using modal dialogs, the shadcn `Dialog` component may not be installed yet. Check `packages/cyclist/src/public/components/ui/` for existing dialog component. If absent, fetch from `https://ui.shadcn.com/r/styles/new-york/dialog.json` (per project memory notes).
