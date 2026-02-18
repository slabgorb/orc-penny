# Story 110-11: Fix git panel: cyclist settings module never initialized

**Status:** in-progress
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** fix/110-11-git-panel-settings-init

## Context

### Problem
The git panel in both Cyclist GUI and BikeRack TUI shows "No git repos" because cyclist's settings module (`packages/cyclist/src/settings.ts`) is never initialized. Its `currentSettings` stays at defaults where `git_monitor: false`.

### Root Cause
During the 98-17 migration that moved the server into core:
- Core's `server.ts:166` calls `initializeSettings(getProjectDir())` — initializes **core's** settings module correctly
- Cyclist's `settings.ts` has an identical but **separate** `initializeSettings()` that is **never called**
- `websocket.ts:669` imports `getCurrentSettings` from cyclist's settings (`./settings.js`), not core's
- This returns `git_monitor: false` (the default), causing the WebSocket to send empty repos

### Fix
The simplest fix: make `websocket.ts` import `getCurrentSettings` from core's settings module instead of cyclist's duplicate. Alternative: call cyclist's `initializeSettings()` during server startup. The import fix is cleaner since it eliminates the duplicate state problem.

### Key Files
- `packages/cyclist/src/websocket.ts` — imports getCurrentSettings from wrong module (line 30)
- `packages/cyclist/src/settings.ts` — cyclist's settings (never initialized, has git_monitor: false default)
- `packages/core/src/server/settings.ts` — core's settings (properly initialized with git_monitor: true)
- `packages/core/src/server/server.ts:166` — where core settings ARE initialized

### Acceptance Criteria
- [ ] Git panel shows repository data in Cyclist GUI
- [ ] Git panel shows repository data in BikeRack TUI
- [ ] WebSocket /ws/git sends repo data when git_monitor is true in config
- [ ] No regression in other settings-dependent features (relay_mode, permission_mode)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/websocket.ts` - Changed `getCurrentSettings` import from cyclist's local `./settings.js` (never initialized, defaults to `git_monitor: false`) to `@pennyfarthing/core/dist/server/settings.js` (properly initialized at server startup with real config values)

**Tests:** 2891/2891 passing (4 pre-existing failures in unrelated bikerack/tab tests)
**Branch:** fix/110-11-git-panel-settings-init (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `initializeSettings(getProjectDir())` (core/server.ts:166, module-level) → `getCurrentSettings()` (websocket.ts:669,907,1014,1121) — safe, initialization precedes all WS connections
**Pattern observed:** Import follows existing `@pennyfarthing/core/dist/...` convention at api/settings.ts:2, api/story.ts:2
**Error handling:** All call sites use optional chaining `?.git_monitor === true` — null-safe
**Follow-up:** `usage-stats.ts:18` has same class of bug (imports `getBillingRolloverDay` from uninitialized cyclist settings) — track separately

**Handoff:** To SM for finish-story