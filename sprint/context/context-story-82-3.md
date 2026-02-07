# Story Context: 82-3 - Agent load React hook + dialog

## Summary

Create a `useAgentLoad()` React hook and `AgentLoadDialog` component for the Cyclist renderer. The hook fetches from `GET /api/agent-load` (story 82-1) and provides a `pruneSidecar()` method that calls `POST /api/agent-load/prune-sidecar` (story 82-2). The dialog renders a ranked table of all 10 agents sorted by token count, with expandable component breakdowns and a sidecar section with View/Clear buttons. Uses shadcn Dialog, Collapsible, and the existing `ConfirmDialog` + `useConfirmDialog` hook for destructive prune confirmation.

## Current State

### Existing Hook Pattern: `useHotspots.ts`

`packages/cyclist/src/public/hooks/useHotspots.ts` (113 lines) is the reference pattern:
- Lines 62-113: `useHotspots(options)` returns `{data, isLoading, error, refresh}`
- Lines 63-66: State: `useState<HotspotData | null>(null)`, `useState(false)` for loading, `useState<Error | null>(null)` for error
- Line 66: `useRef<AbortController | null>(null)` for request cancellation
- Lines 68-101: `fetchHotspots` callback with `AbortController`, `fetch()`, JSON parse, error handling
- Lines 104-110: `useEffect` cleanup to abort on unmount
- Line 112: Returns `{ data, isLoading, error, refresh: fetchHotspots }`

Key difference: `useHotspots` does NOT auto-fetch on mount (the `refresh` function is called manually). The agent load hook should follow the same pattern -- fetch on demand when the dialog opens.

### Existing Hook Exports

`packages/cyclist/src/public/hooks/index.ts` (46 lines) exports hooks with their types. Pattern:
```typescript
export { useHotspots } from './useHotspots';
export type { HotspotData } from './useHotspots';
```
Note: `useHotspots` is NOT currently in this barrel file -- it's imported directly in `HotspotsPanel.tsx`. The new hook should be added to the barrel for consistency.

### ConfirmDialog + `useConfirmDialog` Hook

`packages/cyclist/src/public/components/ConfirmDialog.tsx` (168 lines) provides:
- `ConfirmDialog` component (lines 57-86): shadcn AlertDialog with title, message, confirm/cancel buttons, `isDanger` mode
- `useConfirmDialog(options)` hook (lines 131-166): Returns `{isOpen, confirm, dialogProps}`
  - `confirm()` returns `Promise<boolean>` -- opens dialog, resolves `true` on confirm, `false` on cancel
  - Usage: `const { confirm, dialogProps } = useConfirmDialog({title, message, isDanger: true})`
  - Render: `<ConfirmDialog {...dialogProps} />`

### DebugPanel: `formatComponentName()`

`packages/cyclist/src/public/components/panels/DebugPanel.tsx` exports `formatComponentName()` at lines 54-65:
```typescript
export function formatComponentName(name: string): string {
  if (name === 'persona_compressed') return 'Persona (Compressed)';
  return name.split('_').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ');
}
```
This is already exported and can be imported directly from `DebugPanel.tsx`.

### shadcn Components Available

Relevant shadcn components already installed in `packages/cyclist/src/public/components/ui/`:
- `dialog.tsx` -- for the main dialog shell
- `collapsible.tsx` -- for expandable agent rows (note: Radix Collapsible removes DOM nodes when collapsed)
- `button.tsx` -- for View/Clear buttons
- `badge.tsx` -- for status indicators
- `separator.tsx` -- for visual dividers
- `scroll-area.tsx` -- for scrollable table content
- `skeleton.tsx` -- for loading state
- `progress.tsx` -- extended with `indicatorClassName` prop for token bar visualization

### DebugPanel Token Display

`DebugPanel.tsx` lines 154-195 already renders per-component token counts with a sorted list, `toLocaleString()` formatting, and expand/collapse toggle. The agent load dialog replicates this pattern at a higher level (per-agent rather than per-component).

### No Agent Load UI Exists

There is no `AgentLoadDialog` component or `useAgentLoad` hook. No existing UI shows cross-agent token comparison.

## Target State

After implementation:

1. **`useAgentLoad.ts`** hook:
   - `useAgentLoad()` returns `{data, isLoading, error, refresh, pruneSidecar, pruneResult}`
   - `refresh()` fetches `GET /api/agent-load`
   - `pruneSidecar(agent, file)` POSTs to `/api/agent-load/prune-sidecar`, auto-refreshes on success
   - `pruneResult` contains the last prune response (`{success, tokensFreed, agent, file}` or error)

2. **`AgentLoadDialog.tsx`** component:
   - shadcn Dialog triggered from DebugPanel or toolbar
   - On open: calls `refresh()` to fetch fresh data
   - **Ranked table:** All 10 agents sorted by `totalTokens` descending
   - Each row: agent name, total tokens (formatted with `toLocaleString()`), token bar
   - **Expandable rows:** shadcn Collapsible showing per-component breakdown with `formatComponentName()`
   - **Sidecar section:** Within expanded row, lists sidecar files with individual token counts
   - **Prune button:** Next to each sidecar file, uses `ConfirmDialog` for confirmation
   - **Feedback:** After prune, shows "X tokens freed" message, auto-refreshes table
   - **Total row:** Bottom of table shows sum across all agents
   - **Loading state:** Skeleton placeholders while data loads
   - **Error state:** Error message with retry button

## Key Files

### Files to Create

| File | Location | What It Does |
|------|----------|--------------|
| `useAgentLoad.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useAgentLoad.ts` | React hook: fetch agent load data, prune sidecar, abort on unmount |
| `AgentLoadDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/AgentLoadDialog.tsx` | Dialog with ranked table, expandable breakdowns, sidecar viewer/pruner |

### Files to Modify

| File | Location | What Changes |
|------|----------|--------------|
| `hooks/index.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/index.ts` | Add `export { useAgentLoad } from './useAgentLoad'` and types |
| `DebugPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/DebugPanel.tsx` | Add button to open AgentLoadDialog (e.g., "Analyze All Agents" button) |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `useHotspots.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useHotspots.ts` | Reference hook pattern: state, AbortController, fetch, cleanup (113 lines) |
| `ConfirmDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ConfirmDialog.tsx` | `useConfirmDialog()` hook (lines 131-166), `ConfirmDialog` component (lines 57-86), `ConfirmDialogProps` (lines 34-51) |
| `DebugPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/DebugPanel.tsx` | `formatComponentName()` (lines 54-65), existing token display pattern (lines 154-195) |
| `HotspotsPanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/HotspotsPanel.tsx` | Reference for panel-with-dialog pattern (if exists) |
| `hooks/index.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/index.ts` | Hook barrel export pattern (46 lines) |
| `dialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ui/dialog.tsx` | shadcn Dialog component API |
| `collapsible.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ui/collapsible.tsx` | shadcn Collapsible component API (removes DOM when collapsed) |
| `progress.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ui/progress.tsx` | Extended Progress component with `indicatorClassName` prop |

## Technical Approach

### 1. Create `useAgentLoad.ts`

Follow `useHotspots.ts` pattern but add `pruneSidecar` method:

```typescript
import { useState, useCallback, useRef, useEffect } from 'react';

// Types matching the API response from 82-1
export interface AgentLoadComponent {
  name: string;
  tokens: number;
  source?: string;
}

export interface AgentLoadEntry {
  agent: string;
  totalTokens: number | null;
  tokenCounts?: Record<string, number>;
  components?: AgentLoadComponent[];
  error?: string;
}

export interface AgentLoadData {
  agents: AgentLoadEntry[];
  cachedAt: string;
  totalAcrossAllAgents: number;
}

export interface PruneResult {
  success: boolean;
  tokensFreed?: number;
  agent?: string;
  file?: string;
  error?: string;
}

export interface UseAgentLoadReturn {
  data: AgentLoadData | null;
  isLoading: boolean;
  error: Error | null;
  refresh: () => void;
  pruneSidecar: (agent: string, file: string) => Promise<PruneResult>;
  pruneResult: PruneResult | null;
}

export function useAgentLoad(): UseAgentLoadReturn {
  const [data, setData] = useState<AgentLoadData | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [pruneResult, setPruneResult] = useState<PruneResult | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  const refresh = useCallback(() => {
    if (abortRef.current) abortRef.current.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    setIsLoading(true);
    setError(null);

    fetch('/api/agent-load', { signal: controller.signal })
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
        return res.json();
      })
      .then((json: AgentLoadData) => {
        setData(json);
        setIsLoading(false);
      })
      .catch((err) => {
        if (err.name === 'AbortError') return;
        setError(err instanceof Error ? err : new Error(String(err)));
        setIsLoading(false);
      });
  }, []);

  const pruneSidecar = useCallback(async (agent: string, file: string): Promise<PruneResult> => {
    try {
      const res = await fetch('/api/agent-load/prune-sidecar', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ agent, file }),
      });
      const result = await res.json();
      setPruneResult(result);
      if (result.success) {
        refresh(); // Auto-refresh after successful prune
      }
      return result;
    } catch (err) {
      const result = { success: false, error: String(err) };
      setPruneResult(result);
      return result;
    }
  }, [refresh]);

  useEffect(() => {
    return () => { abortRef.current?.abort(); };
  }, []);

  return { data, isLoading, error, refresh, pruneSidecar, pruneResult };
}
```

### 2. Create `AgentLoadDialog.tsx`

```typescript
import React, { useState, useEffect } from 'react';
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription,
} from '@/components/ui/dialog';
import { Collapsible, CollapsibleTrigger, CollapsibleContent } from '@/components/ui/collapsible';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { Skeleton } from '@/components/ui/skeleton';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Separator } from '@/components/ui/separator';
import { ConfirmDialog, useConfirmDialog } from './ConfirmDialog';
import { formatComponentName } from './panels/DebugPanel';
import { useAgentLoad } from '../hooks/useAgentLoad';
import type { AgentLoadEntry } from '../hooks/useAgentLoad';
```

Key structural decisions:
- **Dialog (not AlertDialog):** This is informational/interactive, not a simple confirm/cancel
- **ScrollArea wrapper:** The 10-agent table may exceed viewport height
- **Collapsible per agent row:** Click to expand shows component breakdown + sidecar section
- **Progress bar per agent:** Visual representation of token usage relative to highest agent
- **ConfirmDialog for prune:** Each sidecar file's Clear button triggers `useConfirmDialog`

### 3. Dialog layout

```
+------------------------------------------------------+
| Agent Load Analyzer                          [X]      |
| Showing token breakdown for all agents               |
+------------------------------------------------------+
| Total: 38,500 tokens across 10 agents    [Refresh]  |
| Cached at: 2026-02-07T12:00:00Z                     |
+------------------------------------------------------+
| Agent           | Tokens  | ████████████░░░░░        |
|-----------------|---------|--------------------------|
| ▶ dev           | 4,200   | ████████████████░░░░░░░  |
| ▶ sm            | 3,800   | ██████████████░░░░░░░░░  |
| ▼ reviewer      | 3,500   | █████████████░░░░░░░░░░  |
|   ├ Agent Def   | 1,200   |                          |
|   ├ Persona     |   800   |                          |
|   ├ Behavior    |   950   |                          |
|   ├ Sprint      |    80   |                          |
|   └ Sidecars    |   470   |                          |
|     ├ patterns.md  180 tk  [View] [Clear]            |
|     ├ gotchas.md   160 tk  [View] [Clear]            |
|     └ decisions.md 130 tk  [View] [Clear]            |
| ▶ architect     | 3,200   | ████████████░░░░░░░░░░░  |
| ...                                                   |
+------------------------------------------------------+
```

### 4. Sidecar breakdown within expanded row

When the `sidecars` component is present in an agent's `components` array (source path like `.pennyfarthing/sidecars/dev/`), render individual sidecar files. The API response from 82-1 does not break sidecars into individual files -- it returns a single `sidecars` component with aggregate tokens. To show per-file breakdown, we have two options:

**Option A (recommended):** Enhance the GET response in 82-1 to include sidecar file details as sub-components. The Python side already loads them individually in `load_sidecars()` (loader.py lines 207-213).

**Option B:** Accept the aggregate and only show the total sidecar tokens, with Clear buttons for each of the 3 files (without individual token counts). The dialog can list the 3 standard files (`patterns.md`, `gotchas.md`, `decisions.md`) and show Clear buttons for each.

For this story, **Option B** is simpler and avoids modifying the 82-1 API contract. The Clear buttons work regardless because they POST to the prune endpoint with the specific filename.

### 5. Integrate into DebugPanel

Add an "Analyze All Agents" button to `DebugPanel.tsx` that opens the dialog:
```typescript
const [agentLoadOpen, setAgentLoadOpen] = useState(false);

// In the JSX, after the component breakdown section:
<Button
  variant="outline"
  size="sm"
  onClick={() => setAgentLoadOpen(true)}
  data-testid="agent-load-button"
>
  Analyze All Agents
</Button>

{agentLoadOpen && (
  <AgentLoadDialog
    isOpen={agentLoadOpen}
    onClose={() => setAgentLoadOpen(false)}
  />
)}
```

### 6. Prune confirmation flow

```typescript
const { confirm, dialogProps } = useConfirmDialog({
  title: 'Prune Sidecar',
  message: `Reset ${selectedFile} for ${selectedAgent} to template? All learned content will be lost.`,
  confirmLabel: 'Prune',
  isDanger: true,
});

const handlePrune = async (agent: string, file: string) => {
  if (await confirm()) {
    const result = await pruneSidecar(agent, file);
    if (result.success) {
      // Show "X tokens freed" feedback (toast or inline message)
    }
  }
};
```

### 7. Export from hooks index

Add to `packages/cyclist/src/public/hooks/index.ts`:
```typescript
// Agent load analysis
export { useAgentLoad } from './useAgentLoad';
export type { AgentLoadData, AgentLoadEntry, PruneResult } from './useAgentLoad';
```

## Acceptance Criteria

- `useAgentLoad()` hook returns `{data, isLoading, error, refresh, pruneSidecar, pruneResult}`
- `refresh()` fetches from `GET /api/agent-load` and populates `data`
- `pruneSidecar(agent, file)` POSTs to `/api/agent-load/prune-sidecar` and auto-refreshes on success
- AbortController cancels in-flight requests on unmount
- `AgentLoadDialog` opens as a shadcn Dialog (not AlertDialog)
- Dialog shows a ranked table with all 10 agents sorted by `totalTokens` descending
- Each agent row shows: agent name, formatted token count (`toLocaleString()`), progress bar
- Clicking an agent row expands a Collapsible showing per-component breakdown
- Component names are formatted using `formatComponentName()` from DebugPanel
- Sidecar section within expanded row lists the 3 sidecar files with Clear buttons
- Clear button opens a `ConfirmDialog` with `isDanger: true` before pruning
- After successful prune, shows `tokensFreed` feedback and table auto-refreshes
- Total row at bottom shows `totalAcrossAllAgents`
- `cachedAt` timestamp is displayed so user knows data freshness
- Loading state shows skeleton placeholders
- Error state shows error message with retry button
- Dialog is opened from DebugPanel via "Analyze All Agents" button
- Hook and types are exported from `hooks/index.ts`

## Dependencies

### Depends On

- **82-1** (Agent load API endpoint) -- `GET /api/agent-load` must exist and return the expected response shape
- **82-2** (Sidecar pruning API) -- `POST /api/agent-load/prune-sidecar` must exist for the Clear/Prune button functionality

### Depended On By

- Nothing -- this is the terminal story in the epic; it's the user-facing UI

## Risks / Open Questions

1. **Sidecar per-file token counts:** The 82-1 API returns sidecars as a single component with aggregate `tokens`. To show per-file token counts in the dialog, either: (a) enhance the API to return sidecar sub-components, or (b) show only the aggregate with Clear buttons for each file. Option B is simpler and avoids API changes. If per-file counts are needed later, the API can be extended without breaking the dialog.

2. **Collapsible DOM removal:** Radix Collapsible removes children from the DOM when collapsed (per the MEMORY.md note from the shadcn migration). This means expanded content is re-rendered on each open, which is fine for static data but worth noting for testing -- `screen.queryByText(...)` returns null for collapsed content.

3. **Dialog sizing:** With 10 agents, each expandable to show 7+ components plus sidecar files, the dialog content can be quite tall. Using `ScrollArea` prevents overflow. The dialog should have a reasonable max-height (e.g., `80vh`) with internal scrolling.

4. **Concurrent prune feedback:** If the user prunes multiple sidecar files in quick succession, `pruneResult` state gets overwritten by each response. Consider using a toast/notification system instead of a single `pruneResult` state. For the initial implementation, showing the last prune result inline is acceptable.

5. **formatComponentName import path:** `formatComponentName` is exported from `DebugPanel.tsx`. Importing a utility from a panel component is slightly unusual. Consider extracting it to a shared util file (e.g., `utils/format.ts`). However, since it's already exported and the import is straightforward, using it directly from DebugPanel is pragmatic for this story.

6. **Dialog trigger location:** The "Analyze All Agents" button in DebugPanel is one option. An alternative is adding it to the toolbar, command palette, or as a standalone panel. Starting in DebugPanel makes sense since it's already the token/context analysis panel. The dialog can be triggered from elsewhere in a follow-up.

7. **Lazy loading the dialog:** The `AgentLoadDialog` imports shadcn components and the hook. Since it's only opened on demand, consider wrapping it in `React.lazy()` to avoid including it in the initial bundle. This is an optimization for follow-up, not required for this story.
