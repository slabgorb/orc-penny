# Story: MSSCI-12784 - Bug: Background Task Timer Doesn't Update While Watching

**Status:** in_progress
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Feature Branch:** fix/MSSCI-12784-timer-bug-fix
**Jira:** MSSCI-12784

## Context

The background task timer doesn't update in real-time while viewing the Background tab. The elapsed time is recorded correctly, but the UI doesn't refresh to show it.

**Repro:**
1. Start a background task
2. Switch to Background tab and watch
3. Timer appears frozen

**Workaround:** Click to another tab and back to see updated time.

**Expected:** Timer should update every second while visible.

**Likely cause:** Missing setInterval or React state update, plus missing cleanup on task completion.

**Additional symptom:** Background timers never stop running even after task completes.

## Acceptance Criteria
- [ ] Timer updates in real-time while Background tab is visible
- [ ] Timer stops when background task completes (success, failure, or cancellation)
- [ ] No performance issues from the timer updates
- [ ] Timer stops updating when tab is not visible (optimization)

## Technical Approach

Timer strategy:
1. Tab opens → fetch all tasks from backend (accurate snapshot via `backgroundTask:getAll` IPC)
2. Pending tasks → estimate elapsed from `startedAt`, update via 1-second interval
3. Completed tasks → use authoritative `durationMs` from backend (set at completion time)
4. Interval only runs when `pendingCount > 0` and panel is visible (unmount cleans up)

## Files Changed
- `packages/cyclist/src/otlp-receiver.ts` - Added `completedAt`/`durationMs` to BackgroundTask, record at completion
- `packages/cyclist/src/ipc-channels.ts` - Added `TASK_GET_ALL` channel
- `packages/cyclist/src/main.ts` - Added IPC handler for `backgroundTask:getAll`
- `packages/cyclist/src/preload.ts` - Added `getAll()` to electronAPI.backgroundTask
- `packages/cyclist/src/public/hooks/useBackgroundTasks.ts` - Fetch on mount, updated interface
- `packages/cyclist/src/public/components/panels/BackgroundPanel.tsx` - Interval for live updates, authoritative display for completed

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:** 6 files, 83 insertions, 16 deletions

**Tests:** Build passes. Pre-existing test failures in vanilla JS tests (unrelated to this change).
**PR:** #618 - fix(cyclist): background task timer updates in real-time
**Branch:** fix/MSSCI-12784-timer-bug-fix (pushed)

**Acceptance Criteria:**
- [x] Timer updates in real-time while Background tab is visible (1s interval)
- [x] Timer stops when background task completes (uses authoritative `durationMs`)
- [x] No performance issues (interval only runs when pending tasks exist)
- [x] Timer stops updating when tab is not visible (React unmount cleanup)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** Task creation → `trackBackgroundTask()` → IPC broadcast → hook state update → UI render. Completion adds `durationMs` at backend before broadcast. Tab open fetches snapshot via `getAll()` IPC.

**Observations:**
| Severity | Finding | Location |
|----------|---------|----------|
| [VERIFIED] | Interface fields synchronized across 3 files | otlp-receiver.ts, preload.ts, useBackgroundTasks.ts |
| [VERIFIED] | Interval cleanup correct with dependency array | BackgroundPanel.tsx:61-65 |
| [VERIFIED] | Error handling for fetch with fallback | useBackgroundTasks.ts:46-48 |
| [VERIFIED] | IPC wiring complete | ipc-channels.ts, main.ts, preload.ts |
| [VERIFIED] | Security: no user input, no injection vectors | All files |
| [LOW] | Tick state increments forever | BackgroundPanel.tsx:55 (non-blocking, JS safe integers) |
| [MEDIUM] | Missing IPC listener cleanup | useBackgroundTasks.ts:51-64 (pre-existing, not introduced) |

**Security:** No issues - internal state only, no external data processed
**Error handling:** Fetch errors silently caught with IPC fallback (acceptable)
**Edge cases:** Clock skew unlikely to cause issues; interval cleanup is correct

**Handoff:** To SM for finish-story
