# Context: Story 121-4 — Fix git sync cache busting for stale UI state

**GitHub Issue:** slabgorb/pennyfarthing-orchestrator#31
**Points:** 2
**Epic:** 121 — Debug Panel and Brownfield Tools Fixes

## Problem

The git status displayed in both the BikeRack TUI (Git panel) and Cyclist UI becomes stale after write operations. The cache invalidation mechanism does not reliably bust after commits, branch switches, or file edits, causing the UI to show outdated branch, dirty file counts, and ahead/behind numbers. Users lose trust in the git panel when it disagrees with their terminal.

The root issue is a tension between accuracy and lock contention. Running `git status` takes the `.git/index` lock, which conflicts with concurrent git operations the agent may be performing. The current approach uses per-repo mutexes (`repoLocks` map) and `--no-optional-locks` for reads, but the cache layer on top doesn't invalidate properly on writes.

## Architecture

### Current Flow

```
WheelHub server (polling interval)
  → getGitInfoAsync() per repo
    → git --no-optional-locks status --porcelain
    → git --no-optional-locks rev-list --count @{u}..HEAD
  → broadcast via /ws/git channel
  → React: useGitStatus() hook receives WS message
  → TUI: git_panel.py subscribes to "git" WS channel
```

### Key Files

| File | Role |
|------|------|
| `packages/core/src/server/api/git.ts` | Git info functions, repo locks, fetch cooldown, REST API |
| `packages/core/src/public/hooks/useGitStatus.ts` | React hook consuming `/ws/git` WebSocket |
| `pennyfarthing-dist/pf/bikerack/git_panel.py` | TUI git panel (subscribes to WS "git" channel) |
| `pennyfarthing-dist/pf/bikerack/progress_panel.py` | Progress panel git summary section |

### Lock-Free Status

All git read operations already use `--no-optional-locks` to avoid taking the `.git/index` lock. This means reads should never conflict with concurrent writes. The problem is not lock contention on reads — it's that the polling/broadcast cycle doesn't trigger a fresh read after write operations.

### Fetch Cooldown

`fetchRepoAsync()` has a 60-second cooldown (`GIT_FETCH_COOLDOWN_MS`) per repo to avoid hammering the network. `resetFetchCooldown()` exists but may not be called from all write paths. The force-refresh callback (`forceRefreshCallback`) is set by the websocket layer and triggered via `POST /api/git/refresh`.

## Acceptance Criteria

### AC1: Status updates after local commits
- **Given** the git panel shows a dirty working tree
- **When** the agent commits changes
- **Then** the panel updates to show clean state within one polling cycle

### AC2: Status updates after branch operations
- **Given** the git panel shows branch `feature/foo`
- **When** the agent switches to branch `main`
- **Then** the panel shows `main` within one polling cycle

### AC3: Dirty file count is accurate after edits
- **Given** the git panel shows `0M 0U`
- **When** the agent edits a tracked file
- **Then** the panel shows `1M` within one polling cycle

### AC4: No lock contention errors in logs
- **Given** the agent is performing git operations (commit, push, rebase)
- **When** the polling cycle runs concurrently
- **Then** no `index.lock` errors appear in WheelHub logs

## Investigation Notes

Possible root causes to check:
1. **Polling interval too long** — if broadcast happens every N seconds, stale state persists for N seconds after a write
2. **Cache not busted on PostToolUse** — the hook system knows when Bash runs git commands but may not trigger `POST /api/git/refresh`
3. **WebSocket message dropped** — client reconnect logic may miss a broadcast
4. **Race in repoLocks** — the 100ms cleanup `setTimeout` could allow a stale read to slip through between lock release and deletion
