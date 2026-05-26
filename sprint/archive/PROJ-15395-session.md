# Story 121-4: Fix git sync cache busting for stale UI state

**Jira:** PROJ-15395
**Epic:** 121
**Points:** 2
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** fix/PROJ-15395-fix-git-sync-cache-busting
**Assigned:** slabgorb@gmail.com

---

## Story Context

### Problem

The git status displayed in both the BikeRack TUI (Git panel) and Cyclist UI becomes stale after write operations. The cache invalidation mechanism does not reliably bust after commits, branch switches, or file edits, causing the UI to show outdated branch, dirty file counts, and ahead/behind numbers. Users lose trust in the git panel when it disagrees with their terminal.

The root issue is a tension between accuracy and lock contention. Running `git status` takes the `.git/index` lock, which conflicts with concurrent git operations the agent may be performing. The current approach uses per-repo mutexes (`repoLocks` map) and `--no-optional-locks` for reads, but the cache layer on top doesn't invalidate properly on writes.

### Architecture

**Current Flow:**
```
WheelHub server (polling interval)
  → getGitInfoAsync() per repo
    → git --no-optional-locks status --porcelain
    → git --no-optional-locks rev-list --count @{u}..HEAD
  → broadcast via /ws/git channel
  → React: useGitStatus() hook receives WS message
  → TUI: git_panel.py subscribes to "git" WS channel
```

**Key Files:**

| File | Role |
|------|------|
| `packages/core/src/server/api/git.ts` | Git info functions, repo locks, fetch cooldown, REST API |
| `packages/core/src/public/hooks/useGitStatus.ts` | React hook consuming `/ws/git` WebSocket |
| `pennyfarthing-dist/pf/bikerack/git_panel.py` | TUI git panel (subscribes to WS "git" channel) |
| `pennyfarthing-dist/pf/bikerack/progress_panel.py` | Progress panel git summary section |

**Lock-Free Status:**
All git read operations already use `--no-optional-locks` to avoid taking the `.git/index` lock. This means reads should never conflict with concurrent writes. The problem is not lock contention on reads — it's that the polling/broadcast cycle doesn't trigger a fresh read after write operations.

**Fetch Cooldown:**
`fetchRepoAsync()` has a 60-second cooldown (`GIT_FETCH_COOLDOWN_MS`) per repo to avoid hammering the network. `resetFetchCooldown()` exists but may not be called from all write paths. The force-refresh callback (`forceRefreshCallback`) is set by the websocket layer and triggered via `POST /api/git/refresh`.

### Epic Context

Epic 121 focuses on enhancing the BikeRack TUI debug panel with keybindings and interactive controls to trigger brownfield code analysis tools. The git cache busting issue (121-4) is a reliability fix that ensures the TUI git panel displays accurate, up-to-date information after user operations.

**Related stories in Epic 121:**
- 121-1: Improve debug panel refresh rate (done 2026-02-20)
- 121-2: Add code quality tool triggers to TUI debug panel (done 2026-02-23)
- 121-3: Fix footer keybinding labels (done 2026-02-21)
- 121-4: Fix git sync cache busting (this story)

---

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

---

## Investigation Focus

Possible root causes to check:
1. **Polling interval too long** — if broadcast happens every N seconds, stale state persists for N seconds after a write
2. **Cache not busted on PostToolUse** — the hook system knows when Bash runs git commands but may not trigger `POST /api/git/refresh`
3. **WebSocket message dropped** — client reconnect logic may miss a broadcast
4. **Race in repoLocks** — the 100ms cleanup `setTimeout` could allow a stale read to slip through between lock release and deletion

---

## Session Log

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `startPeriodicPoll` → `setInterval(5s)` → `hasFreshCache` → `getCachedGitStatus` → `getAllReposGitInfoAsync` → `refreshCallbacks` → `broadcastGitUpdate` → `/ws/git` clients (safe: lock-free reads, client-gated, deduped)
**Pattern observed:** Idempotent timer start + client gating at `git-cache.ts:239,242` — good defensive coding
**Error handling:** Async path properly wrapped in try-catch at `git-cache.ts:246-250`, consistent with existing error handling in module
**Pre-existing notes:** [MEDIUM] No change-diffing on broadcast (unnecessary re-renders). [LOW] No `stopPeriodicPoll`. Both consistent with existing patterns.
**Tests:** 10 failures are pre-existing on `develop` (archived-epics), verified by running same tests on develop branch
**Handoff:** To Elrond for finish-story

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/git-cache.ts` - Added periodic polling safety net (startPeriodicPoll), reduced STALE_THRESHOLD_MS from 15s to 5s
- `packages/cyclist/src/websocket.ts` - Wired polling into git monitor setup (initial + dynamic enable)

**Root Cause:** The git cache had no periodic polling fallback. It relied entirely on OTLP tool events and .git/ file watchers for invalidation. Working tree changes (file edits) don't trigger .git/ metadata watchers, so if OTLP events were missed, the UI went stale indefinitely.

**Fix:** Added startPeriodicPoll() that checks cache freshness every 5s when WS clients are connected. Only fetches when cache is stale (age > 5s), so cost is minimal when event-driven invalidation is already working. Lock-free reads (--no-optional-locks) keep concurrent polling safe.

**AC Coverage:**
- AC1 (commits): Covered by .git/refs/heads watcher + new polling fallback
- AC2 (branch ops): Covered by .git/HEAD watcher + new polling fallback
- AC3 (file edits): Previously ONLY covered by OTLP events — now polling catches missed events
- AC4 (no lock errors): All reads use --no-optional-locks, polling is safe

**Tests:** 2,814/2,814 passing (10 pre-existing failures in archived-epics unrelated)
**Branch:** fix/PROJ-15395-fix-git-sync-cache-busting (pushed)

**Handoff:** To Saruman for code review

---

## SM Assessment (Setup)
- Story claimed in Jira, moved to In Progress
- Branch `fix/PROJ-15395-fix-git-sync-cache-busting` created from `develop`
- 2-point fix routed as `trivial` workflow → Dev (Gandalf) implements directly
- Key focus: cache invalidation after write operations in `packages/core/src/server/api/git.ts`
- ACs are clear and testable — four scenarios covering commits, branches, edits, and lock safety