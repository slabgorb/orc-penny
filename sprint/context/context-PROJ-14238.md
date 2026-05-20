# Story Context: PROJ-14238

## Changed Files and Diffs Panels - Use Git Commands Instead of OTEL

**Epic:** PROJ-14186 (Sprint Data Management)
**Points:** 5 | **Workflow:** tdd | **Priority:** P1

## Overview

Refactor the Diffs panel to use `git diff` commands directly instead of extracting diffs from OTEL tool correlation data (old_string/new_string from Edit tool). The Changed Files panel already uses git commands correctly.

## Problem

- OTEL-based diff extraction is fragile and fails in Electron mode
- Complex correlation logic in otlp-receiver.ts is hard to maintain
- Edit tool's old_string/new_string don't capture all file changes (Bash, Write, etc.)

## Key Files

| File | Purpose | Action |
|------|---------|--------|
| `packages/cyclist/src/public/components/panels/DiffsPanel.tsx` | Diffs UI | Modify to use git diff |
| `packages/cyclist/src/public/hooks/useDiffs.ts` | WebSocket client | Update data format |
| `packages/cyclist/src/otlp-receiver.ts` | OTEL parsing | Remove diff extraction (lines 933-950) |
| `packages/cyclist/src/git-cache.ts` | Git caching | Extend for diff caching |
| `packages/cyclist/src/websocket.ts` | WebSocket server | Update /ws/diffs handler |

## Existing Infrastructure (Already Working)

### Changed Files Panel (no changes needed)
- `ChangedPanel.tsx` uses `useGitStatus()` hook
- Executes `git status --porcelain` via git-cache
- Real-time updates via WebSocket at `/ws/git`

### Git Cache (git-cache.ts:35-37)
```typescript
REFRESH_DELAY_MS = 1500      // Normal debounce
MAX_INVALIDATION_DELAY_MS = 5000  // Force refresh cap
STALE_THRESHOLD_MS = 30000   // Age forcing refresh
```

### Cache Invalidation Triggers (websocket.ts:41-81)
Already detects file-modifying operations:
- Edit/Write tools
- Bash git commands (add, commit, checkout, reset, etc.)
- Bash file ops (rm, mv, cp, touch, mkdir)
- Bash redirects (> operator)
- Package managers (npm/pnpm install)

### Branch Switch Handling (websocket.ts:946-950)
`.git/HEAD` watcher calls `forceRefreshGitCache()` for immediate refresh.

## Implementation Approach

### 1. Extend Git Cache for Diffs
Add diff content to cache state:
```typescript
interface GitCacheState {
  repos: RepoGitInfo[];
  diffs?: Map<string, string>;  // file path → diff content
  stale: boolean;
  lastFetch: number;
}
```

### 2. Git Diff Command
```bash
git diff HEAD           # Working tree changes
git diff --cached       # Staged changes
git diff HEAD -- <file> # Specific file
```

### 3. Update /ws/diffs WebSocket
- Initial broadcast: all current diffs
- Update messages when cache refreshes
- Same invalidation triggers as git cache

### 4. Remove OTEL Diff Extraction (otlp-receiver.ts)
Delete lines 933-950:
```typescript
// REMOVE:
toolEvent.diffOriginal = toolInput.old_string;
toolEvent.diffModified = toolInput.new_string;
```

## Acceptance Criteria

- [ ] Changed Files panel shows all modified files via git status
- [ ] Diffs panel shows accurate diffs via git diff
- [ ] Real-time updates use existing debounce/backoff (1.5s normal, 5s max cap)
- [ ] Cache invalidation on Edit/Write/Bash file modifications (existing logic)
- [ ] Branch switch triggers immediate refresh (existing .git/HEAD watcher)
- [ ] Works correctly in both Electron and browser modes
- [ ] Bash commands that modify files are properly tracked
- [ ] Simpler codebase - remove OTEL tool correlation for diffs from otlp-receiver.ts

## References

| File | Lines | Purpose |
|------|-------|---------|
| git-cache.ts | 14-39 | Cache state structure |
| git-cache.ts | 60-101 | getCachedGitStatus |
| git-cache.ts | 107-170 | invalidateGitCache |
| websocket.ts | 41-81 | shouldInvalidateGitCache |
| websocket.ts | 835-841 | Tool event → cache invalidation |
| otlp-receiver.ts | 933-950 | Diff extraction (remove) |
| useDiffs.ts | 12-19 | DiffData interface |
| useDiffs.ts | 41 | WebSocket endpoint /ws/diffs |
