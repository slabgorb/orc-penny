# Story Context: 80-3 - Code markers API + React hook + dialog

## Summary

Adds the Cyclist frontend integration for the codemarkers module: an Express API router that shells out to `python3 -m pennyfarthing_scripts.codemarkers`, a React hook (`useCodeMarkers`) for fetching and managing state, and a `CodeMarkersDialog` component with tabbed views (TODOs | FIXMEs | Deprecated), sortable table, staleness filter, and summary stats. The dialog is launched from a button added to the DebugPanel. Follows the exact patterns established by the hotspots frontend stack.

## Current State

### Hotspots frontend pattern (reference implementation)

The hotspots feature provides the complete full-stack pattern to replicate:

- **Express API** (`packages/cyclist/src/api/hotspots.ts`, 59 lines) -- `createHotspotsRouter(getProjectDir)` factory function (line 6), builds args for `python3 -m pennyfarthing_scripts.hotspots` (lines 15-26), `execFile('python3', args, ...)` with 30s timeout (lines 31-34), JSON parse of stdout (line 46), error handling returns `{ success: false, error }` (lines 38-41)
- **Barrel export** (`packages/cyclist/src/api/index.ts`, line 9) -- `export { createHotspotsRouter } from './hotspots.js';`
- **Route mounting** (`packages/cyclist/src/server.ts`, line 138) -- `app.use('/api/hotspots', createHotspotsRouter(getProjectDir));`
- **React hook** (`packages/cyclist/src/public/hooks/useHotspots.ts`, 113 lines) -- TypeScript interfaces mirroring Python models (lines 4-48), `UseHotspotsOptions` (lines 50-53), `UseHotspotsReturn` (lines 55-60), `useHotspots()` function (lines 62-113) with `AbortController` (line 66), `fetch('/api/hotspots?...')` (line 85), manual `refresh()` trigger
- **React panel** (`packages/cyclist/src/public/components/panels/HotspotsPanel.tsx`, 365 lines) -- `SortableHeader` component (lines 21-50), `FileTable` with `useMemo` sorting (lines 52-115), Badge severity coloring (line 94: `destructive` for score >= 50, `outline` for >= 25), Skeleton loading state (lines 248-261), time window buttons (lines 278-288)

### DebugPanel (button placement target)

`packages/cyclist/src/public/components/panels/DebugPanel.tsx` (268 lines):

- Imports: `Button` from `@/components/ui/button` (line 12), `Badge` from `@/components/ui/badge` (line 13), `Separator` from `@/components/ui/separator` (line 14)
- Component: `DebugPanel()` function at line 93
- Content: Context Usage section (lines 137-222), Token Stats section (lines 226-262)
- The panel ends at line 264 (`</div>`) with a closing `}` at line 266
- The code markers launcher button should be added after the Token Stats section, before the closing `</div>` at line 264

### Available shadcn components

The following shadcn/ui components are installed at `packages/cyclist/src/public/components/ui/`:

- `dialog.tsx` -- Radix Dialog (portal-rendered, use `data-state` for testing per MEMORY.md)
- `button.tsx`, `badge.tsx`, `separator.tsx`, `skeleton.tsx`
- `tooltip.tsx`, `scroll-area.tsx`, `select.tsx`, `switch.tsx`
- `toggle.tsx`, `toggle-group.tsx`, `collapsible.tsx`, `popover.tsx`
- `progress.tsx`, `checkbox.tsx`, `command.tsx`, `alert-dialog.tsx`

**Not installed:** `tabs.tsx` and `table.tsx` are NOT available. The dialog will need to use Button-based tab switching (same pattern as HotspotsPanel's view toggle at lines 291-306) and raw HTML `<table>` elements (same pattern as HotspotsPanel's FileTable at lines 78-114).

### Server configuration

- `getProjectDir()` helper at `server.ts` line 93-95 wraps `getProjectDirectory()` with cwd fallback
- Python is invoked with `PYTHONPATH` set to the `pennyfarthing/` subdirectory of the project dir (see `hotspots.ts` line 29: `const pythonPath = join(projectDir, 'pennyfarthing')`)
- `execFile` timeout is 30 seconds (hotspots.ts line 34)

## Target State

After implementation:

1. **`packages/cyclist/src/api/code-markers.ts`** -- Express router handling `GET /api/code-markers?days=90&repo=...&type=all|stale|deprecated`
2. **`packages/cyclist/src/api/index.ts`** -- exports `createCodeMarkersRouter`
3. **`packages/cyclist/src/server.ts`** -- mounts at `/api/code-markers`
4. **`packages/cyclist/src/public/hooks/useCodeMarkers.ts`** -- React hook with TypeScript interfaces, AbortController, `refresh()`
5. **`packages/cyclist/src/public/components/CodeMarkersDialog.tsx`** -- shadcn Dialog with tabbed views, sortable table, staleness filter, summary stats bar
6. **`packages/cyclist/src/public/components/panels/DebugPanel.tsx`** -- new "Code Markers" launcher button added after Token Stats section

## Key Files

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `code-markers.ts` | `pennyfarthing/packages/cyclist/src/api/code-markers.ts` | Express router: `GET /api/code-markers` shelling out to Python |
| `useCodeMarkers.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useCodeMarkers.ts` | React hook with fetch, abort, loading/error state |
| `CodeMarkersDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/CodeMarkersDialog.tsx` | Dialog component with tabs, sortable table, filters |

### Files to Modify

| File | Location | What Changes |
|------|----------|--------------|
| `index.ts` | `pennyfarthing/packages/cyclist/src/api/index.ts` | Add `export { createCodeMarkersRouter } from './code-markers.js';` |
| `server.ts` | `pennyfarthing/packages/cyclist/src/server.ts` | Add import of `createCodeMarkersRouter`, mount at `/api/code-markers` |
| `DebugPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/DebugPanel.tsx` | Add launcher button and import CodeMarkersDialog |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `hotspots.ts` | `pennyfarthing/packages/cyclist/src/api/hotspots.ts` | Express router pattern to replicate: `createHotspotsRouter()` (line 6), `execFile` with PYTHONPATH (lines 29-34), JSON parse (line 46) |
| `useHotspots.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useHotspots.ts` | Hook pattern: interfaces (lines 4-48), AbortController (line 66), fetch + error handling (lines 85-100) |
| `HotspotsPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/HotspotsPanel.tsx` | `SortableHeader` (lines 21-50), `FileTable` (lines 52-115), Badge severity (line 94), Skeleton loading (lines 248-261), view toggle buttons (lines 291-306) |
| `DebugPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/DebugPanel.tsx` | Button placement target (after Token Stats section, before closing `</div>` at line 264) |
| `index.ts` | `pennyfarthing/packages/cyclist/src/api/index.ts` | Barrel export pattern (line 9 for hotspots) |
| `server.ts` | `pennyfarthing/packages/cyclist/src/server.ts` | Route mounting pattern (line 138 for hotspots), `getProjectDir` import (line 93-95) |
| `dialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ui/dialog.tsx` | shadcn Dialog component API |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/codemarkers/models.py` | Python dataclass field names -- TypeScript interfaces must match snake_case |

## Technical Approach

### 1. Create Express API router (`code-markers.ts`)

Copy `hotspots.ts` and adapt:

```typescript
import { Router } from 'express';
import { execFile } from 'child_process';
import { join } from 'path';

export function createCodeMarkersRouter(getProjectDir: () => string): Router {
  const router = Router();

  // GET /api/code-markers?days=90&repo=pennyfarthing&type=all
  router.get('/', (req, res) => {
    const projectDir = getProjectDir();
    const days = String(req.query.days || '90');
    const repo = req.query.repo as string | undefined;
    const type = (req.query.type as string) || 'all';

    const args = [
      '-m', 'pennyfarthing_scripts.codemarkers',
      // Map type to CLI command: all->analyze, stale->stale, deprecated->deprecated
      type === 'stale' ? 'stale' : type === 'deprecated' ? 'deprecated' : 'analyze',
      '--format', 'json',
      '--days', days,
    ];

    if (repo) {
      args.push('--repo', repo);
    } else {
      args.push('--path', projectDir);
    }

    const pythonPath = join(projectDir, 'pennyfarthing');

    execFile('python3', args, {
      cwd: pythonPath,
      env: { ...process.env, PYTHONPATH: pythonPath },
      timeout: 30000,
    }, (err, stdout, stderr) => {
      if (err) {
        console.error('[CodeMarkers] Analysis failed:', stderr || err.message);
        res.status(500).json({ success: false, error: stderr || err.message });
        return;
      }

      try {
        const data = JSON.parse(stdout);
        res.json(data);
      } catch (parseErr) {
        console.error('[CodeMarkers] JSON parse failed:', parseErr);
        res.status(500).json({ success: false, error: 'Failed to parse code markers output' });
      }
    });
  });

  return router;
}
```

### 2. Register in barrel export and mount route

**`api/index.ts`** -- Add after the hotspots export (line 9):

```typescript
export { createCodeMarkersRouter } from './code-markers.js';
```

**`server.ts`** -- Add `createCodeMarkersRouter` to the import destructuring at line 33, and mount after the hotspots route (after line 138):

```typescript
// Code markers analysis API
app.use('/api/code-markers', createCodeMarkersRouter(getProjectDir));
```

### 3. Create React hook (`useCodeMarkers.ts`)

TypeScript interfaces mirroring the Python `CodeMarkersResult` dataclass fields (snake_case names for direct JSON deserialization, matching the convention in `useHotspots.ts`):

```typescript
import { useState, useCallback, useRef, useEffect } from 'react';

export interface CodeMarker {
  path: string;
  line: number;
  marker_type: string;
  text: string;
  author: string;
  date: string;
  age_days: number;
  is_stale: boolean;
}

export interface DeprecationMarker {
  path: string;
  line: number;
  symbol: string;
  text: string;
  caller_count: number;
  callers: string[];
}

export interface MarkerSummary {
  total_markers: number;
  stale_markers: number;
  by_type: Record<string, number>;
  total_deprecations: number;
  deprecations_with_callers: number;
}

export interface CodeMarkersData {
  success: boolean;
  repo_name: string;
  repo_path: string;
  stale_threshold_days: number;
  markers: CodeMarker[];
  deprecations: DeprecationMarker[];
  summary: MarkerSummary | null;
  error?: string;
}

export interface UseCodeMarkersOptions {
  days: number;
  repo?: string;
  type?: 'all' | 'stale' | 'deprecated';
}

export interface UseCodeMarkersReturn {
  data: CodeMarkersData | null;
  isLoading: boolean;
  error: Error | null;
  refresh: () => void;
}

export function useCodeMarkers(options: UseCodeMarkersOptions): UseCodeMarkersReturn {
  // AbortController pattern, fetch('/api/code-markers?...'), manual refresh()
  // Matching useHotspots.ts lines 62-113
}
```

### 4. Create `CodeMarkersDialog.tsx`

A shadcn Dialog component (not a dockview panel) with:

- **Tab switching** via Button group (same pattern as HotspotsPanel's view toggle, lines 291-306), since `tabs.tsx` is not installed. Tabs: "TODOs" (filtered to TODO type), "FIXMEs" (filtered to FIXME type), "All Markers", "Deprecated"
- **Sortable table** reusing the `SortableHeader` pattern from HotspotsPanel (lines 21-50). Columns: Type, File, Line, Text, Author, Age (days), Stale
- **Badge severity**: stale markers get `destructive` variant, non-stale get `secondary`, deprecations with callers get `outline` (matching HotspotsPanel line 94 pattern)
- **Summary stats bar**: total markers, stale count, by-type breakdown, deprecation count
- **Staleness filter**: toggle to show only stale markers
- **Loading state**: Skeleton components (matching HotspotsPanel lines 248-261)

```tsx
import React, { useState, useMemo, useCallback } from 'react';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip';
import { useCodeMarkers, CodeMarker, DeprecationMarker } from '../../hooks/useCodeMarkers';

type TabView = 'all' | 'todo' | 'fixme' | 'deprecated';
type SortField = 'marker_type' | 'path' | 'line' | 'age_days' | 'author';
type SortDirection = 'asc' | 'desc';

export function CodeMarkersDialog(): React.ReactElement {
  const [open, setOpen] = useState(false);
  const [tab, setTab] = useState<TabView>('all');
  const [staleOnly, setStaleOnly] = useState(false);
  const [sortField, setSortField] = useState<SortField>('age_days');
  const [sortDirection, setSortDirection] = useState<SortDirection>('desc');

  const { data, isLoading, error, refresh } = useCodeMarkers({ days: 90 });

  // Filter markers by tab and stale toggle
  const filteredMarkers = useMemo(() => { /* ... */ }, [data, tab, staleOnly]);
  // Sort markers
  const sortedMarkers = useMemo(() => { /* ... */ }, [filteredMarkers, sortField, sortDirection]);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm">Code Markers</Button>
      </DialogTrigger>
      <DialogContent className="code-markers-dialog max-w-4xl max-h-[80vh]">
        <DialogHeader>
          <DialogTitle>Code Markers</DialogTitle>
        </DialogHeader>
        {/* Summary stats bar */}
        {/* Tab buttons: All | TODOs | FIXMEs | Deprecated */}
        {/* Stale-only toggle */}
        {/* Sortable table or deprecation table */}
      </DialogContent>
    </Dialog>
  );
}
```

### 5. Add launcher button to DebugPanel

Add a `Separator` and a "Code Markers" button after the Token Stats section in `DebugPanel.tsx`. The button opens the `CodeMarkersDialog`.

At `DebugPanel.tsx`, insert after line 262 (after the Token Stats `</dl>` / placeholder `</div>`) and before the closing `</div>` at line 264:

```tsx
import { CodeMarkersDialog } from '../CodeMarkersDialog';

// ... inside the DebugPanel return, after Token Stats section:

      <Separator className="my-3" />

      <h4>Diagnostics</h4>
      <div className="debug-launchers">
        <CodeMarkersDialog />
      </div>
```

The `CodeMarkersDialog` component renders its own `DialogTrigger` button, so placing it directly in the launcher row is sufficient.

## Acceptance Criteria

- `GET /api/code-markers?days=90` returns valid JSON matching the `CodeMarkersResult` schema with both `markers` and `deprecations` arrays
- `GET /api/code-markers?type=stale` returns only stale markers
- `GET /api/code-markers?type=deprecated` returns only deprecation data
- Express API returns `{ success: false, error }` on Python failure with HTTP 500
- React hook manages loading, error, and data states with AbortController for request cancellation
- `refresh()` callback triggers a new fetch
- Dialog opens from the DebugPanel launcher button
- Tab buttons filter between All Markers, TODOs, FIXMEs, and Deprecated views
- Sortable table columns work for all fields (Type, File, Line, Text, Author, Age, Stale)
- Stale markers display `destructive` Badge variant
- Deprecations with active callers display `outline` Badge variant
- Summary stats bar shows total, stale, and by-type counts
- Stale-only toggle filters the markers table
- Loading state shows Skeleton placeholders
- Error state shows error message with Retry button
- Dialog renders in Radix Portal (tests use `data-state` attribute, not `title`)

## Dependencies

### Depends On

- **80-1** (Python codemarkers module) -- the Express API shells out to `python3 -m pennyfarthing_scripts.codemarkers analyze --format json`. This module must exist and produce valid JSON.
- **80-2** (@deprecated detection) -- the Deprecated tab in the dialog displays `DeprecationMarker` data. If 80-2 is not complete, the deprecations array will be empty and the tab will show "No deprecated symbols found" -- this is acceptable for partial delivery.

### Depended On By

- Nothing -- this is the frontend terminus of Epic 80.

## Risks / Open Questions

1. **Tabs component not available:** `tabs.tsx` is not installed in the shadcn component set. The dialog uses Button-based tab switching (matching HotspotsPanel's view toggle pattern). If proper Tabs are desired, they could be fetched from `https://ui.shadcn.com/r/styles/new-york/tabs.json` per the MEMORY.md pattern, but the Button approach is simpler and consistent with existing code.

2. **Dialog sizing for large result sets:** A repo with hundreds of markers will produce a long table. The dialog uses `max-h-[80vh]` with `ScrollArea` (or CSS `overflow-y: auto`) to handle this. Consider adding a `--top` limit to the API call (e.g., top 100 markers) to keep the JSON payload reasonable.

3. **Radix Dialog portal testing:** Per MEMORY.md, Radix Dialog renders in a portal. Tests should check `data-state` attribute on the trigger element, not `title` attribute. Test assertions should look for the dialog content via `role="dialog"` or `data-testid`.

4. **Python not available:** If `python3` is not on the system PATH or the `pennyfarthing_scripts` module is not importable, the Express API will return a 500 error. The hook and dialog handle this via the error state. Consider a friendlier error message that suggests checking Python installation.

5. **DebugPanel import path:** `CodeMarkersDialog` is placed at `packages/cyclist/src/public/components/CodeMarkersDialog.tsx` (not in `panels/`), since it is a dialog, not a dockview panel. The import from `DebugPanel.tsx` will be `import { CodeMarkersDialog } from '../CodeMarkersDialog';` (relative path up one directory from `panels/`).

6. **API `type` parameter mapping:** The `type` query parameter maps to different CLI commands: `all` -> `analyze`, `stale` -> `stale`, `deprecated` -> `deprecated`. If 80-2 is not yet complete, the `deprecated` command may not exist in the Python CLI. The API should handle this gracefully (the Python process will return a Click error, which the API surfaces as a 500 with the error message).
