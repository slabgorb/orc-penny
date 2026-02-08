# Story 82-3: Agent load React hook + dialog

**Jira:** MSSCI-14464
**Branch:** feature/82-3-agent-load-hook-dialog
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Epic:** 82 - Agent Load Analyzer

## Context

**82-1 (Agent load API endpoint)** — COMPLETED
- Implemented `GET /api/agent-load` endpoint in `packages/cyclist/src/api/agent-load.ts`
- Calls `getPrimeContextJson()` for all 10 primary agents at FULL tier
- Returns array of `{agent, totalTokens, tokenCounts, components, error?}` with 60-second caching
- Strips `context` field to prevent prompt leakage
- Handles partial failures gracefully

**82-2 (Sidecar pruning API)** — COMPLETED
- Implemented `POST /api/agent-load/prune-sidecar` endpoint in same `agent-load.ts` router
- Validates {agent, file} input against whitelists
- Reads sidecar from `.pennyfarthing/sidecars/{agent}/{file}`, calculates tokens freed (char count / 4)
- Reads template from `pennyfarthing-dist/templates/sidecar/{file}.template`
- Replaces ${AGENT_NAME} placeholder with formatted agent name (title-case with hyphen separation)
- Writes pruned sidecar and invalidates 82-1 cache
- Returns `{success, tokensFreed, agent, file}` or error response

**82-3 (This story) — Agent load React hook + dialog**
- Build React hook `useAgentLoad()` that wraps the 82-1 API endpoint
- Create `AgentLoadDialog` component with ranked agent table, expandable rows, sidecar pruning UI
- Integrate dialog into DebugPanel via "Analyze All Agents" button
- Follow existing patterns from `useHotspots` hook and `ConfirmDialog` component

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

## Technical Approach

### 1. Create `useAgentLoad.ts` hook

Follow `useHotspots.ts` pattern (113 lines) with additions:
- State: `useState<AgentLoadData | null>(null)`, loading, error, `pruneResult`
- `useRef<AbortController | null>(null)` for request cancellation
- `refresh()` callback fetches `GET /api/agent-load`, handles abort, parsing, errors
- `pruneSidecar(agent, file)` async method POSTs to prune endpoint, auto-refreshes on success
- `useEffect` cleanup aborts on unmount
- Returns `{ data, isLoading, error, refresh, pruneSidecar, pruneResult }`

**Type shapes:**
- `AgentLoadComponent` — {name, tokens, source?}
- `AgentLoadEntry` — {agent, totalTokens | null, tokenCounts?, components?, error?}
- `AgentLoadData` — {agents: AgentLoadEntry[], cachedAt: string, totalAcrossAllAgents: number}
- `PruneResult` — {success, tokensFreed?, agent?, file?, error?}

### 2. Create `AgentLoadDialog.tsx` component

- Wrap in shadcn Dialog (not AlertDialog) with max-w-lg sizing
- On open: calls `refresh()` to fetch fresh data
- **Ranked table:** All 10 agents sorted by totalTokens descending
  - Columns: agent name, formatted tokens (toLocaleString()), progress bar
  - Progress bar normalized to highest agent's token count
- **Expandable rows:** shadcn Collapsible with per-component breakdown
  - Each component: name (via formatComponentName()), token count
  - Sidecar files (patterns.md, gotchas.md, decisions.md) listed with individual Clear buttons
- **Prune flow:** Click Clear → useConfirmDialog → POST prune → show tokens freed → refresh table
- **Total row:** Sum of all agents' tokens
- **Loading state:** Skeleton placeholders while fetching
- **Error state:** Error message with retry button
- **ScrollArea:** Prevent table overflow on tall content

### 3. Integrate into DebugPanel

Add button in DebugPanel.tsx after token stats section:
- `useState(false)` for dialog open state
- Button "Analyze All Agents" → `setOpen(true)`
- Render `<AgentLoadDialog isOpen={open} onClose={() => setOpen(false)} />`

### 4. Export hook and types

Add to `packages/cyclist/src/public/hooks/index.ts`:
```typescript
export { useAgentLoad } from './useAgentLoad';
export type { AgentLoadData, AgentLoadEntry, PruneResult } from './useAgentLoad';
```

## Key Files

### Files to Create

| File | Purpose |
|------|---------|
| `packages/cyclist/src/public/hooks/useAgentLoad.ts` | React hook for agent load API, prune method, auto-refresh |
| `packages/cyclist/src/public/components/AgentLoadDialog.tsx` | Dialog UI: ranked table, expandable rows, sidecar pruner |

### Files to Modify

| File | Purpose |
|------|---------|
| `packages/cyclist/src/public/hooks/index.ts` | Add useAgentLoad export and types |
| `packages/cyclist/src/public/components/panels/DebugPanel.tsx` | Add "Analyze All Agents" button, dialog state, render dialog |

### Files to Reference

| File | Why |
|------|-----|
| `packages/cyclist/src/public/hooks/useHotspots.ts` | Reference hook pattern (state, AbortController, fetch, cleanup) |
| `packages/cyclist/src/public/components/ConfirmDialog.tsx` | useConfirmDialog hook, ConfirmDialog component |
| `packages/cyclist/src/public/components/panels/DebugPanel.tsx` | formatComponentName() function, existing token display pattern |
| `packages/cyclist/src/public/components/ui/dialog.tsx` | shadcn Dialog component API |
| `packages/cyclist/src/public/components/ui/collapsible.tsx` | shadcn Collapsible for expandable rows |
| `packages/cyclist/src/public/components/ui/progress.tsx` | Progress bar with indicatorClassName for token visualization |
| `packages/cyclist/src/api/agent-load.ts` | GET and POST endpoint contracts (already built in 82-1, 82-2) |

## Dependencies

### Depends On
- **82-1** — GET /api/agent-load endpoint (agent load data shape)
- **82-2** — POST /api/agent-load/prune-sidecar endpoint (prune functionality)

### Depended On By
- None — this is the terminal UI story for the epic

## Notes

1. **Sidecar per-file token counts:** The 82-1 API returns sidecars as a single component with aggregate tokens. Per-file counts can be shown later if the API is enhanced. For now, show aggregate sidecar tokens with Clear buttons for each of the 3 standard files.

2. **Collapsible DOM removal:** Radix Collapsible removes children from DOM when collapsed. This is fine for this use case — content re-renders on expand, which is acceptable for static data.

3. **Dialog sizing:** Use max-w-lg with ScrollArea for table content to prevent viewport overflow.

4. **formatComponentName import:** Exported from DebugPanel.tsx. Import directly from there, though it could be refactored to a shared util in the future.

5. **Dialog trigger location:** Starting in DebugPanel makes sense since it's the token/context analysis hub. Can be triggered from other locations later.

## TEA Assessment

**Tests Required:** Yes
**Reason:** React hook + dialog component with multiple ACs needs comprehensive test coverage

**Test Files:**
- `packages/cyclist/tests/MSSCI-14464-useAgentLoad.test.ts` — Hook tests: return shape, refresh/fetch, pruneSidecar, AbortController cleanup, barrel export
- `packages/cyclist/tests/MSSCI-14464-AgentLoadDialog.test.tsx` — Dialog tests: rendering, ranked table, expandable rows, sidecar Clear buttons, ConfirmDialog, loading/error states, DebugPanel integration

**Tests Written:** ~50 tests covering all 17 ACs
**Status:** RED (failing on import — `useAgentLoad.ts` and `AgentLoadDialog.tsx` don't exist yet)

**AC Coverage Map:**
| AC | Test File | Tests |
|----|-----------|-------|
| AC1: Hook return shape | useAgentLoad | 6 |
| AC2: refresh() fetches data | useAgentLoad | 7 |
| AC3: pruneSidecar() + auto-refresh | useAgentLoad | 5 |
| AC4: AbortController cleanup | useAgentLoad | 3 |
| AC5: Dialog opens as Dialog | AgentLoadDialog | 3 |
| AC6: Ranked table sorted desc | AgentLoadDialog | 2 |
| AC7: Row content (tokens, progress) | AgentLoadDialog | 2 |
| AC8: Expandable Collapsible rows | AgentLoadDialog | 3 |
| AC9: formatComponentName formatting | AgentLoadDialog | 3 |
| AC10: Sidecar Clear + ConfirmDialog | AgentLoadDialog | 3 |
| AC11: Post-prune feedback | AgentLoadDialog | 1 |
| AC12: Barrel export | useAgentLoad | 1 |
| AC13: Total row | AgentLoadDialog | 2 |
| AC14: cachedAt timestamp | AgentLoadDialog | 1 |
| AC15: Loading skeletons | AgentLoadDialog | 2 |
| AC16: Error state + retry | AgentLoadDialog | 3 |
| AC17: DebugPanel button | AgentLoadDialog | 2 |

**Key Patterns for Dev:**
- Hook follows `useHotspots.ts` pattern (useState, AbortController, fetch)
- Dialog uses `ToolDialog` wrapper (not raw Dialog) matching `HotspotsDialog`
- ConfirmDialog used with `isDanger: true` for sidecar prune
- Tests use `data-testid="agent-row-{agent}"` — Dev must add these
- Tests use `data-testid="tool-launcher-agent-load"` for DebugPanel button
- Tests mock `useAgentLoad` at module level via `vi.mock`

**Handoff:** To Dev (The White Rabbit) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/hooks/useAgentLoad.ts` - React hook with data fetching, AbortController, pruneSidecar with auto-refresh
- `packages/cyclist/src/public/components/AgentLoadDialog.tsx` - Dialog with ranked table, expandable rows, sidecar pruning, loading/error states
- `packages/cyclist/src/public/hooks/index.ts` - Added barrel export for useAgentLoad and types
- `packages/cyclist/src/public/components/panels/DebugPanel.tsx` - Added "Analyze All Agents" button and AgentLoadDialog integration

**Tests:** 51/51 passing (GREEN)
**PR:** #735 - feat(82-3): Agent load React hook + dialog
**Branch:** feature/82-3-agent-load-hook-dialog (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Clear button → handleClear → ConfirmDialog → pruneSidecar POST → auto-refresh (safe: user confirmation gate, HTTP status checks, application-level success check)
**Pattern observed:** Hook mirrors useHotspots pattern (AbortController, fetch, state management) at useAgentLoad.ts:44-76
**Error handling:** Two-layer: HTTP errors at useAgentLoad.ts:81-82, application errors at useAgentLoad.ts:87-89. Null totalTokens coalesced at AgentLoadDialog.tsx:69
**Security:** No secrets, no dangerouslySetInnerHTML, no console.log. Prune API validates agent/file against whitelists server-side (agent-load.ts:120-134)
**Tests:** 51/51 passing (GREEN)
**Observations:** 10 verified items, 1 low-severity note (inlineable function). No blocking issues.

**Handoff:** To SM for finish-story
