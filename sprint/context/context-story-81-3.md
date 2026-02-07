# Story Context: 81-3 - Dead code API + React hook + dialog

## Summary

Create the Cyclist integration layer for dead code detection: an Express router at `GET /api/dead-code` that calls the Python deadcode module via `execFile`, a React hook `useDeadCode.ts` for frontend data fetching, and a `DeadCodeDialog.tsx` component with two tabs (Stale Files, Unused Exports) displaying sortable tables with confidence badges. The Express router follows the existing `hotspots.ts` pattern (59 lines), the hook follows `useHotspots.ts` (113 lines), and the dialog uses shadcn Dialog, Badge, and custom tab primitives.

## Current State

### Hotspots integration (reference pattern)

The hotspots module has a complete Cyclist integration that this story mirrors:

**Express router** — `pennyfarthing/packages/cyclist/src/api/hotspots.ts` (59 lines):
- `createHotspotsRouter(getProjectDir)` factory at line 6 returns a `Router`
- Single `GET /` handler at line 10
- Calls `execFile('python3', ['-m', 'pennyfarthing_scripts.hotspots', 'analyze', '--format', 'json', ...])` at line 31
- Sets `PYTHONPATH` to `join(projectDir, 'pennyfarthing')` at line 29-33
- 30-second timeout at line 34
- JSON parse with error handling at lines 45-54

**React hook** — `pennyfarthing/packages/cyclist/src/public/hooks/useHotspots.ts` (113 lines):
- TypeScript interfaces: `FileHotspot` (line 4), `DirectoryHotspot` (line 16), `HotspotRepoResult` (line 25), `HotspotData` (line 36), `UseHotspotsOptions` (line 50), `UseHotspotsReturn` (line 55)
- `useHotspots(options)` function at line 62 with `useState`, `useCallback`, `useRef`
- `AbortController` for cleanup at line 66, abort on unmount at lines 104-110
- `fetch('/api/hotspots?...')` at line 85 with `URLSearchParams`
- Returns `{ data, isLoading, error, refresh }` at line 112

**Server mount** — `pennyfarthing/packages/cyclist/src/server.ts`:
- Import: `createHotspotsRouter` from `./api/index.js` at line 33
- Mount: `app.use('/api/hotspots', createHotspotsRouter(getProjectDir))` at line 138

**API index** — `pennyfarthing/packages/cyclist/src/api/index.ts`:
- Export: `createHotspotsRouter` from `./hotspots.js` at line 9

### Available shadcn components

The following shadcn/ui components are already installed in `pennyfarthing/packages/cyclist/src/public/components/ui/`:
- **`dialog.tsx`** — `Dialog`, `DialogContent`, `DialogHeader`, `DialogTitle`, `DialogDescription`, `DialogFooter`, `DialogClose` (Radix Dialog primitives)
- **`badge.tsx`** — `Badge` with `default`, `secondary`, `destructive`, `outline` variants (line 10-21)
- **`button.tsx`** — standard button with variants
- **`scroll-area.tsx`** — Radix ScrollArea for scrollable content
- **`separator.tsx`** — visual separator

**Not installed:** `tabs.tsx` (Radix Tabs). The dialog will need either custom tab implementation using buttons/state or fetching the shadcn tabs component.

### Existing dialog pattern

`ConfirmDialog.tsx` at `pennyfarthing/packages/cyclist/src/public/components/ConfirmDialog.tsx` (168 lines) shows the component pattern: imports from `@/components/ui/alert-dialog`, uses `@/lib/utils` for `cn()`, typed props interface, exported component + hook.

## Target State

After implementation:

1. **`GET /api/dead-code?days=180&repo=pennyfarthing&layer=all`** returns JSON matching the `DeadCodeResult` schema from `models.py`
2. **`dead-code.ts`** Express router at `packages/cyclist/src/api/dead-code.ts`, exported from `api/index.ts`, mounted in `server.ts`
3. **`useDeadCode.ts`** React hook at `packages/cyclist/src/public/hooks/useDeadCode.ts` providing `{ data, isLoading, error, refresh }`
4. **`DeadCodeDialog.tsx`** at `packages/cyclist/src/public/components/DeadCodeDialog.tsx` with:
   - Two tabs: "Stale Files" and "Unused Exports"
   - Badge counts on each tab showing `stale_file_count` and `unused_export_count`
   - Sortable table for stale files (columns: File, Days Stale, Size, Last Commit)
   - Sortable table for unused exports (columns: File, Export, Line)
   - Diagnostic only — no delete buttons
5. **Server mount** at `app.use('/api/dead-code', createDeadCodeRouter(getProjectDir))` in `server.ts`

## Key Files

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `dead-code.ts` | `pennyfarthing/packages/cyclist/src/api/dead-code.ts` | Express router: `createDeadCodeRouter(getProjectDir)`, `GET /` handler |
| `useDeadCode.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useDeadCode.ts` | React hook: `useDeadCode({days, repo?, layer?})` |
| `DeadCodeDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/DeadCodeDialog.tsx` | Dialog component with tabs and sortable tables |

### Files to Modify

| File | Location | What Changes |
|------|----------|--------------|
| `index.ts` | `pennyfarthing/packages/cyclist/src/api/index.ts` | Add `export { createDeadCodeRouter } from './dead-code.js'` (after line 9) |
| `server.ts` | `pennyfarthing/packages/cyclist/src/server.ts` | Add `createDeadCodeRouter` to import (line 33), mount `app.use('/api/dead-code', createDeadCodeRouter(getProjectDir))` (after line 138) |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `hotspots.ts` | `pennyfarthing/packages/cyclist/src/api/hotspots.ts` | Express router pattern — `createHotspotsRouter()`, `execFile`, `PYTHONPATH`, 30s timeout |
| `useHotspots.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useHotspots.ts` | React hook pattern — types, `AbortController`, `fetch`, state management |
| `ConfirmDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ConfirmDialog.tsx` | Dialog component pattern — imports, props interface, shadcn Dialog usage |
| `dialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ui/dialog.tsx` | shadcn Dialog primitives available |
| `badge.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ui/badge.tsx` | Badge component with variants (for count badges on tabs) |
| `server.ts` | `pennyfarthing/packages/cyclist/src/server.ts` | Mount pattern (line 138 for hotspots), `getProjectDir` helper (line 93) |
| `index.ts` | `pennyfarthing/packages/cyclist/src/api/index.ts` | Re-export pattern (line 9 for hotspots) |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/deadcode/models.py` | Python dataclass schema to match in TypeScript interfaces |

## Technical Approach

### 1. Create `dead-code.ts` Express router

Mirror `hotspots.ts` structure:

```typescript
import { Router } from 'express';
import { execFile } from 'child_process';
import { join } from 'path';

export function createDeadCodeRouter(getProjectDir: () => string): Router {
  const router = Router();

  // GET /api/dead-code?days=180&repo=pennyfarthing&layer=all
  router.get('/', (req, res) => {
    const projectDir = getProjectDir();
    const days = String(req.query.days || '180');
    const repo = req.query.repo as string | undefined;
    const layer = String(req.query.layer || 'all');

    // Subcommand maps to layer: "stale", "exports", or "all"
    const args = [
      '-m', 'pennyfarthing_scripts.deadcode',
      layer,
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
        console.error('[DeadCode] Analysis failed:', stderr || err.message);
        res.status(500).json({ success: false, error: stderr || err.message });
        return;
      }

      try {
        const data = JSON.parse(stdout);
        res.json(data);
      } catch (parseErr) {
        console.error('[DeadCode] JSON parse failed:', parseErr);
        res.status(500).json({ success: false, error: 'Failed to parse dead code analysis output' });
      }
    });
  });

  return router;
}
```

Key differences from `hotspots.ts`:
- Default days is `180` (not `90`)
- Subcommand is dynamic: `layer` query param maps to `stale`, `exports`, or `all`
- Additional query param: `layer`

### 2. Register in `api/index.ts` and mount in `server.ts`

**`api/index.ts`** — add after line 9 (the hotspots export):
```typescript
export { createDeadCodeRouter } from './dead-code.js';
```

**`server.ts`** — add `createDeadCodeRouter` to the import block at line 33, then mount after line 138:
```typescript
// Dead code analysis API
app.use('/api/dead-code', createDeadCodeRouter(getProjectDir));
```

### 3. Create `useDeadCode.ts` React hook

Mirror `useHotspots.ts` structure, adapting types to match `DeadCodeResult`:

```typescript
import { useState, useCallback, useRef, useEffect } from 'react';

// Types matching Python DeadCodeResult
export interface StaleFile {
  path: string;
  last_commit_date: string;
  days_since_last_commit: number;
  size_bytes: number;
}

export interface UnusedExport {
  path: string;
  export_name: string;
  line_number: number;
}

export interface DeadCodeData {
  success: boolean;
  repo_name?: string;
  repo_path?: string;
  time_window_days?: number;
  stale_files?: StaleFile[];
  unused_exports?: UnusedExport[];
  stale_file_count?: number;
  unused_export_count?: number;
  // Multi-repo
  repo_results?: DeadCodeData[];
  error?: string | null;
}

export interface UseDeadCodeOptions {
  days: number;
  repo?: string;
  layer?: 'stale' | 'exports' | 'all';
}

export interface UseDeadCodeReturn {
  data: DeadCodeData | null;
  isLoading: boolean;
  error: Error | null;
  refresh: () => void;
}

export function useDeadCode(options: UseDeadCodeOptions): UseDeadCodeReturn {
  const [data, setData] = useState<DeadCodeData | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  const fetchDeadCode = useCallback(() => {
    if (abortRef.current) {
      abortRef.current.abort();
    }
    const controller = new AbortController();
    abortRef.current = controller;

    setIsLoading(true);
    setError(null);

    const params = new URLSearchParams({
      days: String(options.days),
      layer: options.layer || 'all',
    });
    if (options.repo) {
      params.set('repo', options.repo);
    }

    fetch(`/api/dead-code?${params}`, { signal: controller.signal })
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
        return res.json();
      })
      .then((json: DeadCodeData) => {
        setData(json);
        setIsLoading(false);
      })
      .catch((err) => {
        if (err.name === 'AbortError') return;
        setError(err instanceof Error ? err : new Error(String(err)));
        setIsLoading(false);
      });
  }, [options.days, options.repo, options.layer]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (abortRef.current) {
        abortRef.current.abort();
      }
    };
  }, []);

  return { data, isLoading, error, refresh: fetchDeadCode };
}
```

### 4. Create `DeadCodeDialog.tsx`

Build on shadcn Dialog with custom tab state (no `tabs.tsx` component available). Use `Badge` for count badges.

```tsx
import React, { useState, useMemo, useCallback } from 'react';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription,
} from '@/components/ui/dialog';
import { Badge } from '@/components/ui/badge';
import { ScrollArea } from '@/components/ui/scroll-area';
import { cn } from '@/lib/utils';
import { useDeadCode, type DeadCodeData, type StaleFile, type UnusedExport } from '@/hooks/useDeadCode';

// =============================================================================
// Types
// =============================================================================

export interface DeadCodeDialogProps {
  isOpen: boolean;
  onClose: () => void;
  days?: number;
  repo?: string;
}

type TabId = 'stale' | 'exports';
type SortField = 'path' | 'days_since_last_commit' | 'size_bytes' | 'export_name' | 'line_number';
type SortDir = 'asc' | 'desc';

// =============================================================================
// Component
// =============================================================================

export function DeadCodeDialog({ isOpen, onClose, days = 180, repo }: DeadCodeDialogProps) {
  const { data, isLoading, error, refresh } = useDeadCode({ days, repo, layer: 'all' });
  const [activeTab, setActiveTab] = useState<TabId>('stale');
  const [sortField, setSortField] = useState<SortField>('days_since_last_commit');
  const [sortDir, setSortDir] = useState<SortDir>('desc');

  // Fetch on open
  React.useEffect(() => {
    if (isOpen) refresh();
  }, [isOpen, refresh]);

  const handleSort = useCallback((field: SortField) => {
    setSortDir(prev => sortField === field && prev === 'desc' ? 'asc' : 'desc');
    setSortField(field);
  }, [sortField]);

  const staleCount = data?.stale_file_count ?? 0;
  const exportCount = data?.unused_export_count ?? 0;

  return (
    <Dialog open={isOpen} onOpenChange={(open) => { if (!open) onClose(); }}>
      <DialogContent className="max-w-4xl max-h-[80vh]">
        <DialogHeader>
          <DialogTitle>Dead Code Analysis</DialogTitle>
          <DialogDescription>
            Diagnostic report — files and exports with no recent activity.
          </DialogDescription>
        </DialogHeader>

        {/* Tab bar */}
        <div className="flex gap-2 border-b pb-2">
          <button onClick={() => setActiveTab('stale')}
            className={cn('px-3 py-1.5 text-sm rounded-t', activeTab === 'stale' && 'bg-accent')}>
            Stale Files <Badge variant="secondary" className="ml-1">{staleCount}</Badge>
          </button>
          <button onClick={() => setActiveTab('exports')}
            className={cn('px-3 py-1.5 text-sm rounded-t', activeTab === 'exports' && 'bg-accent')}>
            Unused Exports <Badge variant="secondary" className="ml-1">{exportCount}</Badge>
          </button>
        </div>

        {/* Content area */}
        <ScrollArea className="h-[50vh]">
          {isLoading && <div className="p-4 text-muted-foreground">Analyzing...</div>}
          {error && <div className="p-4 text-destructive">Error: {error.message}</div>}
          {data && activeTab === 'stale' && <StaleFileTable files={data.stale_files || []} ... />}
          {data && activeTab === 'exports' && <UnusedExportTable exports={data.unused_exports || []} ... />}
        </ScrollArea>
      </DialogContent>
    </Dialog>
  );
}
```

**Table sub-components** render inside the dialog with sortable column headers. Clicking a column header toggles sort direction. The stale files table uses a confidence color on the days column (green < 180, yellow 180-365, red > 365 days). No delete buttons — this is diagnostic only.

## Acceptance Criteria

- `GET /api/dead-code?days=180&layer=all` returns valid JSON matching `DeadCodeResult` schema
- `GET /api/dead-code?days=180&layer=stale` returns only stale files (no ts-prune invocation)
- `GET /api/dead-code?days=180&layer=exports` returns only unused exports
- `GET /api/dead-code?repo=pennyfarthing&days=180` scopes analysis to a named repo
- Express router sets `PYTHONPATH` to `join(projectDir, 'pennyfarthing')` (matching `hotspots.ts` line 29-33)
- Express router has 30-second `execFile` timeout (matching `hotspots.ts` line 34)
- `createDeadCodeRouter` exported from `api/index.ts`
- Router mounted at `/api/dead-code` in `server.ts`
- `useDeadCode` hook provides `{ data, isLoading, error, refresh }` matching `UseDeadCodeReturn` interface
- Hook aborts in-flight requests on unmount via `AbortController` (matching `useHotspots.ts` lines 104-110)
- `DeadCodeDialog` opens with two tabs: "Stale Files" and "Unused Exports"
- Each tab shows a Badge with the count (`stale_file_count`, `unused_export_count`)
- Stale files table has sortable columns: File, Days Stale, Size, Last Commit
- Unused exports table has sortable columns: File, Export, Line
- No delete or modify buttons — diagnostic only
- Loading state shows while analysis runs
- Error state renders when API returns `success: false`

## Dependencies

### Depends On

- **81-1** (Python deadcode module: stale file detection) — the Express router calls `python -m pennyfarthing_scripts.deadcode` which must exist and support `--format json`.
- **81-2** (Unused export detection via ts-prune) — for the Unused Exports tab to show data, the `exports` and `all` subcommands must be functional. However, 81-3 can be developed in parallel with 81-2 since the `stale` layer from 81-1 is sufficient for initial testing, and the `unused_exports` array will simply be empty until 81-2 lands.

### Depended On By

- Nothing in this epic. This is the terminal story for Epic 81. Future work may integrate the dialog into a Cyclist panel or add it to the diagnostics menu.

## Risks / Open Questions

1. **Tabs component not installed:** shadcn `tabs.tsx` (Radix Tabs) is not in the project. The implementation uses custom tab state with buttons and `cn()` styling. An alternative is to fetch the shadcn tabs component: `https://ui.shadcn.com/r/styles/new-york/tabs.json` and install it. Using custom buttons is simpler and avoids adding a dependency.

2. **Dialog width on small screens:** The `max-w-4xl` class gives 896px max width, which is needed for the table columns. On smaller viewports this may overflow. Consider `max-w-full` with horizontal scroll on the table, or responsive column hiding.

3. **Sortable table implementation:** No shadcn Table component is installed. The sortable table will be implemented with plain HTML `<table>` elements and React state for sort field/direction. If a more robust table is needed later, `@tanstack/react-table` could be added as a dependency.

4. **Where to mount the dialog trigger:** This story creates the `DeadCodeDialog` component but does not specify where in the Cyclist UI it is triggered. It could be added to the diagnostics panel, a menu bar item, or a quick action. The trigger integration is left for a follow-up or can be addressed during implementation by adding a button to an existing panel (e.g., the debug panel or a new diagnostic section).

5. **Multi-repo response shape:** When no `repo` query param is provided, the Python module may return a `MultiRepoDeadCodeResult` (with `repo_results` array) instead of a single `DeadCodeResult`. The `DeadCodeData` TypeScript interface includes `repo_results?` to handle this, but the dialog may need to flatten results across repos or show a repo selector dropdown.

6. **API response size:** A repo with many stale files (hundreds) could produce a large JSON response. The Express router does not currently limit results. Consider adding a `top` query param passthrough to `--top` in the Python CLI, or paginating results client-side.

7. **30-second timeout for combined analysis:** Running both layers (`all`) means stale file enrichment + ts-prune execution must complete within 30 seconds. For large repos, this may be tight. The Python `analyze_repo()` runs both layers in parallel via `asyncio.gather`, which helps, but the enrichment step (one `git log -1` per stale file) is the bottleneck. Story 81-1's semaphore-based parallelism is critical here.
