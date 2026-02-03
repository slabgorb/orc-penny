# Workflow Session: interactive-debug

**Workflow:** interactive-debug
**Type:** stepped
**Agent:** dev
**Started:** 2026-02-02T15:32:00Z

## Workflow State
- **Workflow Name:** interactive-debug
- **Type:** stepped
- **Mode:** create
- **Started:** 2026-02-02T15:32:00Z
- **Last Updated:** 2026-02-02T15:32:00Z
- **Current Step:** 1
- **Steps Completed:** []
- **Status:** in_progress
- **Notes:** Session created via /workflow start

## Progress
- Total Steps: 4
- Completion: 0%

---

## Dev Handoff Notes (2026-02-02)

### Completed Fixes

1. **Panel Layout Bug** - DONE ✓
   - Added `height: 100%; min-height: 0;` to `.sidebar` and `.center-region`
   - Added `.cyclist-app > main` flex rule
   - Sidebars and message panel now stretch to bottom
   - Commit: `28b286e5f`

2. **useStory Web Mode** - DONE ✓
   - Added REST API fallback (`/api/story`) when `electronAPI` unavailable
   - Polls every 5 seconds in web mode
   - Sprint panel now shows "No active story" instead of error
   - Commit: `28b286e5f`

3. **useGitStatus Web Mode** - DONE ✓
   - Added REST API fallback (`/api/git/all`) - Commit: `ca11dd5fd`
   - **RESOLVED**: Was configuration issue, not code bug (see below)

### Root Cause: Wrong Project Directory

The Git API was returning 404 because Cyclist was started with the wrong project directory.

**The Problem:**
- Server was started with `CYCLIST_PROJECT_DIR=/Users/keithavery/Projects/pf-2/pennyfarthing`
- But `.pennyfarthing/` exists at `/Users/keithavery/Projects/pf-2` (orchestrator root)
- `detectPennyfarthingProject()` correctly failed because there's no `.pennyfarthing/` in the `pennyfarthing/` subdirectory

**The Fix:**
Run `just cyclist web here` from the **orchestrator root**, not the pennyfarthing subdirectory.

**Dogfooding Architecture:**
The orchestrator (`pf-2`) dogfoods Pennyfarthing - it has `.pennyfarthing/` at its root and the framework source is inlined at `pennyfarthing/`. When running Cyclist, the project directory must be the orchestrator root where `.pennyfarthing/` exists.

Updated CLAUDE.md in pennyfarthing repo to document this relationship.

### Remaining Issues

~~1. **Progress panel** - "electronAPI.todos not available"~~
   - ✅ FIXED: Added `/api/todos` endpoint + `useTodos` hook REST fallback

~~2. **Settings panel** - Stuck on "Loading..." forever~~
   - ✅ FIXED: Added REST fallback to `SettingsPanel.tsx` (API already existed)

---

## UX Architecture Issue: Progress Panel Consolidation - DONE ✓

**Observation:** AC and BikeLane tabs should be **inside** Progress, not adjacent to it.

**Before:**
```
Right Sidebar Tabs:
  Sprint | Progress | AC | BikeLane | Background | Git | Settings
```

**After:**
```
Right Sidebar Tabs:
  Sprint | Progress | Background | Git | Settings
           └── Internal tabs: Workflow | AC | Todo
```

**Rationale:** Workflow steps, Acceptance Criteria, and Todos are all aspects of **tracking progress on the current story**. They belong together conceptually.

**Files modified:**
- `packages/cyclist/src/public/components/DockingWorkspace.tsx` - Removed AC/BikeLane from PANEL_INVENTORY
- `packages/cyclist/src/public/components/panels/ProgressPanel.tsx` - Rewrote with internal tabbed view
- `packages/cyclist/src/public/App.tsx` - Removed separate panel registrations
- `packages/cyclist/src/public/components/panels/index.ts` - Updated exports
- `packages/cyclist/src/public/styles/tailwind.css` - Added internal tab styles

**Screenshots:**
- `.playwright-mcp/cyclist-progress-unified-tabs.png` - New unified Progress panel
- `.playwright-mcp/cyclist-progress-tabs-complete.png` - Todo tab (needs REST fallback)

### Server Info (Updated)
- Cyclist running at: `http://localhost:1899`
- Started via: `just cyclist web here` (from orchestrator root)
- Project dir: `/Users/keithavery/Projects/pf-2` (correct!)
- Logs: `/tmp/cyclist-web.log`

### Files Modified
- `packages/cyclist/src/public/styles/tailwind.css`
- `packages/cyclist/src/public/hooks/useStory.ts`
- `packages/cyclist/src/public/hooks/useGitStatus.ts`

---

## UX Designer Panel Survey (2026-02-02)

### Panel Status (After All Fixes)

| Panel | Status | Notes |
|-------|--------|-------|
| Sprint | ✅ Working | Shows "No active story" (expected empty state) |
| Progress | ✅ Fixed | REST fallback added, shows "No active tasks" in web mode |
| AC | ✅ Working | Shows "No acceptance criteria" (expected) |
| BikeLane | ✅ Working | Shows "No active workflow" (expected) |
| Background | ✅ Working | Shows "No background tasks" (expected) |
| Git | ✅ Fixed | Was config issue - now returns both repos |
| Settings | ✅ Fixed | REST fallback added, loads themes and settings |

### Completed Issues

1. **Progress panel** - ✅ FIXED
   - Created `/api/todos` endpoint (`src/api/todos.ts`)
   - Updated `useTodos.ts` with REST fallback + 5s polling
   - Note: In web mode, todos are empty (Claude stream only in Electron)

2. **Settings panel** - ✅ FIXED
   - Updated `SettingsPanel.tsx` with REST fallback
   - Uses existing `/api/settings` and `/api/settings/themes` endpoints

### Screenshots

- `.playwright-mcp/cyclist-initial-state.png` - Initial layout (working)
- `.playwright-mcp/cyclist-git-panel-error.png` - Git panel before fix (404 error)

---

## Dev Assessment (2026-02-02)

**Implementation Complete:** Partial - continuing interactive debug

**Files Changed:**
- `packages/cyclist/src/public/hooks/useTodos.ts` - Added REST fallback with polling
- `packages/cyclist/src/public/components/panels/SettingsPanel.tsx` - Added REST fallback for settings/themes
- `packages/cyclist/src/api/todos.ts` - NEW: Todos API endpoint for web mode
- `packages/cyclist/src/api/index.ts` - Added todos export
- `packages/cyclist/src/server.ts` - Mounted `/api/todos` route
- `packages/cyclist/src/public/components/ControlBar.tsx` - Added REST fallback for bell/relay mode sync
- `packages/cyclist/src/public/styles/tailwind.css` - Removed distracting throb animation
- `.pennyfarthing/sidecars/dev/gotchas.md` - Added vanilla JS reference note

**Build:** ✅ Successful

**Commits pushed to develop:**
- `53c6e0995` - REST API fallback for Settings/Todos panels
- `00c5c8035` - Consolidated AC/BikeLane into Progress panel
- `5f9948dfb` - Documented dogfooding architecture
- `60c2c3a87` - REST fallback for ControlBar bell/relay mode sync
- `8271fb6a2` - Removed distracting throb animation from toggles

**Pattern Used:** Same pattern as vanilla JS (commit `9aea4f371^`):
```javascript
// Try IPC first, then HTTP fallback
if (window.electronAPI?.settings?.get) {
  settings = await window.electronAPI.settings.get();
} else {
  const response = await fetch('/api/settings');
  if (response.ok) settings = await response.json();
}
```

**Notes:**
- Todos in web mode will be empty (Claude stream only available in Electron)
- Settings panel now fully functional in web mode
- All right sidebar panels working in web mode
- Bell/relay toggle state now syncs between ControlBar and Settings panel
- Toggle animations removed (too distracting)

---

## IPC Deprecation Notice (2026-02-02)

**IPC is deprecated.** All renderer ↔ server communication now uses WebSockets.

See: `packages/cyclist/docs/ipc-to-websocket-migration.md`

---

## Phase 2: WebSocket Migration (In Progress)

### Completed (Phase 1)
- [x] usePersona → /ws/persona
- [x] useStory → /ws/story
- [x] useGitStatus → /ws/git
- [x] useBackgroundTasks → /ws/background-tasks
- [x] ApprovalModal → /ws/hooks
- [x] SettingsPanel → /ws/settings
- [x] ControlBar → /ws/settings

### Completed (Phase 2)
- [x] Added `/ws/context` WebSocket endpoint (2026-02-02)
- [x] useStatsStrip → /ws/context + /ws/stats (2026-02-02)
- [x] Added REST `/api/settings/layout` endpoint (2026-02-02)
- [x] useLayoutPersistence → REST API (2026-02-02)
- [x] Fixed DockingWorkspace collapse persistence and restoration
- [x] Added `/ws/diffs` WebSocket endpoint (2026-02-02)
- [x] useDiffs → /ws/diffs (2026-02-02)

### Remaining (Phase 2)
- [ ] `/ws/command` endpoint for command execution streaming
- [ ] `/ws/menu` endpoint for menu-triggered events

### Commits (Phase 2)
- `d26b615cb` - feat(cyclist): add /ws/context endpoint and migrate useStatsStrip
- `fc1a2da61` - feat(cyclist): add layout REST API and migrate useLayoutPersistence
- `d5793b69b` - feat(cyclist): add /ws/diffs endpoint and migrate useDiffs

---

## Electron Mode WebSocket Bridge (2026-02-03)

### Problem: React Panels Broken in Electron Mode

After IPC-to-WebSocket migration, React components use WebSocket for Claude communication.
But in Electron mode, the main process manages the ClaudeService - the WebSocket `/ws/claude`
endpoint was creating a **separate** ClaudeService subprocess, causing messages to not reach
the React components.

### Solution: Bridge IPC to WebSocket

**Files Modified:**
- `packages/cyclist/src/websocket.ts`:
  - Added `claudeClients` Set to track WebSocket connections
  - Added `broadcastClaudeMessage()`, `broadcastClaudeComplete()`, `broadcastClaudeError()`
  - Modified `/ws/claude` handler to detect Electron mode (`CYCLIST_ELECTRON_MODE=1`)
  - In Electron mode: clients only receive broadcasts, no local ClaudeService created

- `packages/cyclist/src/main.ts`:
  - Sets `CYCLIST_ELECTRON_MODE=1` before server start
  - Calls WebSocket broadcast functions alongside IPC broadcasts
  - Import: `broadcastClaudeMessage, broadcastClaudeComplete, broadcastClaudeError`

- `packages/cyclist/src/api/identity.ts`:
  - Added `avatarUrl` field to response (was missing, causing avatar regression)
  - Constructs from GitHub username: `https://avatars.githubusercontent.com/{username}`

### Architecture

```
Electron Mode:
  main.ts ClaudeService
    → broadcastToRenderer() (IPC for legacy)
    → broadcastClaudeMessage() (WebSocket for React)
    → React components receive via /ws/claude

Web Mode (unchanged):
  /ws/claude → ClaudeService per connection → React components
```

### Testing Required

- [ ] Restart Cyclist Electron app
- [ ] Verify avatar shows GitHub profile picture
- [ ] Verify messages appear in MessagePanel
- [ ] Verify sidebar panels receive WebSocket updates
- [ ] Verify Settings panel loads themes

### Build Status

✅ Build successful (2026-02-03)

---

## Next Steps

1. **Test the Electron WebSocket bridge** - Restart Cyclist and verify fixes
2. Continue with remaining Phase 2 endpoints (/ws/command, /ws/menu)
3. Phase 3: Low-priority migrations (audit log, file browser, avatar, skills)
4. Phase 4: Remove IPC code from preload.ts

