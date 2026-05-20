# Story Context: PROJ-14327 - Smooth plan mode exit with tirepump choice

## Summary

When Claude Code exits plan mode (via `ExitPlanMode`), the user currently has to manually switch from plan mode to accept mode in the Cyclist UI before the approved plan can execute. This story automates that transition and adds an optional tirepump (commit/push context clearing) choice after plan execution completes.

## Current State

### Plan Mode in Claude Code CLI

Claude Code has a built-in plan mode (`--permission-mode plan`) where the agent explores the codebase and writes a plan without making changes. When the agent calls `ExitPlanMode`, Claude Code expects the user to approve/reject the plan and then manually change the permission mode to allow execution.

### Cyclist Mode Management

**Three UI modes** exist in the ModeSwitch component (`plan`, `manual`, `accept`):

- `plan` maps to Claude CLI `plan` mode (read-only exploration)
- `manual` maps to Claude CLI `default` mode (ask permission)
- `accept` maps to Claude CLI `acceptEdits` mode (auto-accept edits)

**Mode sync flow:**
1. User selects mode in ModeSwitch UI (Editor.tsx renders `<ModeSwitch>`)
2. `useModeSync` hook sends `{ type: 'setMode', mode }` via WebSocket to `/ws/claude`
3. WebSocket handler calls `ClaudeService.setPermissionMode(mode)` which sets `pendingMode`
4. On next `sendMessage()`, `pendingMode` becomes `activeMode` and is passed as `--permission-mode` to the CLI subprocess

**Key issue:** Mode changes are "pending" -- they only take effect on the *next* query. The `ClaudeService` (B-10 pattern) distinguishes between `activeMode` (used in last query) and `pendingMode` (will be used next). There is no mechanism to automatically switch mode in response to Claude's own actions (like calling `ExitPlanMode`).

### TirePump (Context Clearing)

TirePump clears the Claude session, resets all stats/state, reloads the agent's system prompt, and relaunches the agent. It is triggered:

- Via the pump button in ControlBar (visible at 50%+ context)
- Via `clearAndReload` WebSocket message type
- Both Electron and Web mode paths handle it

TirePump does NOT currently offer a commit/push step. It simply clears context and reloads.

### Approval/Hook System

The PreToolUse hook (`pretooluse_hook.py`) sends tool requests to WheelHub's `/api/hook-request` endpoint. The `hook-request.ts` router either auto-approves (allowlist), asks the user (via `ApprovalModal` over WebSocket), or defers to Claude Code's built-in approval. This system handles individual tool approvals but does NOT intercept or respond to plan mode transitions.

### What Happens Today (The Pain Point)

1. Agent enters plan mode and writes a plan
2. Agent calls `ExitPlanMode` to request plan approval
3. Claude Code CLI pauses, waiting for user to accept
4. User sees the plan in Cyclist but must:
   a. Manually switch ModeSwitch from "Plan" to "Accept" (or "Manual")
   b. Manually approve in the CLI
5. After plan executes, there is no prompt to commit/push changes
6. User has to manually trigger TirePump or continue without clearing context

## Target State

1. **Automatic mode transition on plan exit:** When Claude calls `ExitPlanMode` and the user approves the plan, Cyclist automatically switches from plan mode to accept mode (or manual, based on user preference) so the plan can execute without manual mode switching.

2. **Tirepump choice after plan execution:** After the plan's approved changes complete, present the user with a choice: tirepump (commit/push the changes and clear context) or continue in the current session.

## Key Files

### Mode Management
| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/src/public/components/ModeSwitch/index.tsx` | UI component for plan/manual/accept toggle; `useModeSync` hook; `MODE_TO_CLAUDE` and `CLAUDE_TO_MODE` mappings |
| `pennyfarthing/packages/cyclist/src/public/components/Editor.tsx` | Renders `<ModeSwitch>`, consumes `useModeSync`, wires `onModeChange` |
| `pennyfarthing/packages/cyclist/src/public/contexts/ClaudeContext.tsx` | `ClaudeProvider` with `setMode` WebSocket command; `clearAndReload` for TirePump |
| `pennyfarthing/packages/cyclist/src/public/hooks/useClaude.ts` | `PermissionMode` type; `setMode` WebSocket integration |
| `pennyfarthing/packages/cyclist/src/claude-service.ts` | `ClaudeService` class; `pendingMode`/`activeMode` pattern (B-10); `setPermissionMode()`; `buildArgs()` passes `--permission-mode` |
| `pennyfarthing/packages/cyclist/src/settings.ts` | Settings persistence; `PermissionMode` type (`plan`, `manual`, `accept`); settings YAML I/O |

### WebSocket / Server
| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/src/websocket.ts` | WebSocket server setup; `setMode`/`getMode`/`clearAndReload` message handlers for both Electron and Web mode; `ClaudeWebSocketMessage` type |
| `pennyfarthing/packages/cyclist/src/main.ts` | Electron main process; registers `setClaudeSetModeCallback`, `setClaudeClearAndReloadCallback`; TirePump implementation (lines 1114-1163) |
| `pennyfarthing/packages/cyclist/src/api/hook-request.ts` | Hook request/response router; approval resolution via WebSocket |

### TirePump / Control
| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/src/public/components/ControlBar.tsx` | TirePump button UI (pump-toggle); `handleTirePump` calls `clearAndReload`; `useControlBar` hook |

### Parser / Detection
| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/src/parser.ts` | `parseClaudeOutput()` detects mode from PTY output ("Plan", "Normal", "Auto-accept"); used for status display |

### Approval UI
| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/src/public/components/ApprovalModal/index.tsx` | Tool permission modal; WebSocket subscription to `/ws/hooks`; `sendPermissionResponse()` |
| `pennyfarthing/packages/cyclist/src/preload.ts` | Electron IPC bridge; exposes `setMode` to renderer |

### Patterns / Documentation
| File | Purpose |
|------|---------|
| `pennyfarthing/pennyfarthing-dist/guides/patterns/approval-gates-pattern.md` | Documents Gate Type 4 (Plan Approval Gates); `EnterPlanMode`/`ExitPlanMode` flow |

### Tests
| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/tests/PROJ-12773-mode-switch.test.ts` | ModeSwitch component tests (module structure, modes, CSS, keyboard, ARIA) |
| `pennyfarthing/packages/cyclist/e2e/app.e2e.ts` | E2E tests including mode switch display and Cmd+1 for plan mode |

## Technical Approach

### 1. Detect ExitPlanMode in the message stream

In `websocket.ts` (Web mode) and `main.ts` (Electron mode), the `sendMessage()` stream already processes `tool_use` messages to track Task subagents. Add detection for when Claude emits a `tool_use` with `tool_name: 'ExitPlanMode'`:

- **Web mode** (`websocket.ts`, line ~1343): In the `for await` loop that processes SDK messages, check for `sdkMsg.type === 'tool_use' && sdkMsg.tool_name === 'ExitPlanMode'`.
- **Electron mode** (`main.ts`): The message stream is handled by `broadcastClaudeMessage`. Need to intercept ExitPlanMode in the message callback chain.

### 2. Auto-transition mode after plan approval

When ExitPlanMode is detected and the plan result indicates approval:

- Call `service.setPermissionMode('acceptEdits')` (or `'default'` based on user config) to set `pendingMode`
- Broadcast mode change to UI via WebSocket: `{ type: 'mode', mode: newMode }`
- This ensures the next query runs with the correct permissions

**Configuration:** Add a setting in `settings.ts` for `plan_exit_mode`: `'accept' | 'manual'` (default: `'accept'`) to let users control what mode to transition to after plan approval.

### 3. Broadcast plan-exit event to UI

Add a new WebSocket message type (e.g., `{ type: 'planExitApproved' }`) that the UI can react to:

- Update `ModeSwitch` component's `useModeSync` to listen for this event and update local mode state
- This prevents the UI from showing stale "Plan" mode while the backend has already switched

### 4. Post-plan TirePump choice

After the plan's execution completes (detected by `result` message following an ExitPlanMode), present a tirepump choice:

- **Option A (New CYCLIST marker):** Emit a `<!-- CYCLIST:QUESTION:yesno -->` marker from the agent workflow followed by `AskUserQuestion` asking whether to tirepump. This keeps the choice within the existing Reflector/QuickActions pattern.

- **Option B (UI-driven):** Add a new state in the ControlBar or a new transient UI element that appears after plan execution completes, offering "Commit & Clear" (tirepump) vs "Continue" buttons. This is simpler but bypasses the agent workflow.

**Recommended: Option B** -- A small notification/toast in the ControlBar area with two buttons:
- "TirePump" -- calls `clearAndReload(currentAgent)` (existing functionality)
- "Continue" -- dismisses the notification, no action

### 5. Track plan-mode lifecycle state

Add state tracking in `ClaudeService` or a new module to track:
- `planModeActive: boolean` -- whether the current session is in plan mode
- `planExitPending: boolean` -- ExitPlanMode was called, awaiting result
- `planExecutionComplete: boolean` -- plan was approved and execution finished

This state drives both the auto-transition and the tirepump choice.

### Changes Per File

| File | Changes |
|------|---------|
| `claude-service.ts` | Add plan lifecycle state tracking (`planModeActive`, `planExitPending`); detect ExitPlanMode in message stream; auto-set pendingMode on plan approval |
| `websocket.ts` | Detect ExitPlanMode tool_use in Web mode message processing; broadcast `planExitApproved` event to Claude clients; auto-set mode after plan approval |
| `main.ts` | Detect ExitPlanMode in Electron mode message callback; broadcast `planExitApproved` to renderer; auto-set mode |
| `ModeSwitch/index.tsx` | Handle `planExitApproved` WebSocket event in `useModeSync` to update UI state; add mode transition animation |
| `ControlBar.tsx` | Add post-plan tirepump choice UI (notification/toast with TirePump/Continue buttons); track `showPlanComplete` state |
| `settings.ts` | Add `plan_exit_mode` setting (`'accept' | 'manual'`, default `'accept'`) |
| `Editor.tsx` | No changes needed (delegates to ModeSwitch) |
| `tests/PROJ-14327-*.test.ts` | New test file: mode auto-transition on ExitPlanMode, tirepump choice rendering, settings integration |

## Acceptance Criteria

1. **AC1:** When Claude calls `ExitPlanMode` and the plan is approved, Cyclist automatically transitions from plan mode to accept mode (or manual mode per user setting) without requiring the user to manually switch.

2. **AC2:** After plan approval and execution, Cyclist presents a choice to tirepump (commit/push and clear context) or continue working in the current session.

3. **AC3:** The ModeSwitch UI updates to reflect the new mode immediately after auto-transition (no stale "Plan" state displayed).

4. **AC4:** A `plan_exit_mode` setting allows users to configure whether plan exit transitions to accept mode or manual mode.

5. **AC5:** The auto-transition does not fire if the plan is rejected (user denies ExitPlanMode).

## Dependencies

- **PROJ-14322 (Mount ApprovalModal in React component tree):** The ApprovalModal must be wired into the React tree for the tirepump choice to render. However, the tirepump choice could use a different UI pattern (toast/notification) that does not depend on ApprovalModal.

- **PROJ-14320 (Update and register PreToolUse hook):** The hook must be registered for the permission system to work. Plan mode exit is a Claude CLI built-in behavior, not a hook, so this is a soft dependency (plan approval still works without it).

- **Existing TirePump infrastructure:** Already fully implemented in ControlBar, ClaudeContext, websocket.ts, and main.ts.

- **Existing ModeSwitch infrastructure:** Already fully implemented with WebSocket sync, keyboard shortcuts, and Radix ToggleGroup.

## Risks / Open Questions

1. **How does ExitPlanMode appear in the message stream?** Claude Code's `ExitPlanMode` is a built-in tool, not a user-defined tool. Need to verify whether it emits a `tool_use` message with `tool_name: 'ExitPlanMode'` in the `--output-format stream-json` output, or whether the mode change is signaled differently (e.g., via a `system` message with updated `permissionMode`). This needs to be tested with an actual plan mode session.

2. **Race condition with pending mode:** The `ClaudeService` B-10 pattern applies `pendingMode` only on the next `sendMessage()` call. If the auto-transition sets `pendingMode` but the CLI subprocess has already restarted with the old mode (due to `buildArgs()` being called before the mode change propagates), the transition could fail. May need to kill and respawn the subprocess with the new mode.

3. **Plan rejection detection:** How does Claude Code signal that a plan was rejected? If the user rejects via the CLI's built-in prompt, does it emit a `result` message with `permission_denials`? Or does it silently remain in plan mode? This determines whether AC5 can be implemented.

4. **Electron vs Web mode parity:** Both modes handle message streams differently. Electron mode uses callback bridges (`setClaudeSendCallback`), while Web mode iterates the async generator directly. ExitPlanMode detection must work in both paths.

5. **TirePump choice timing:** After plan execution completes, how long should the tirepump choice remain visible? Should it auto-dismiss? What if the user starts typing before responding?

6. **Git commit scope:** The current TirePump clears context and reloads but does NOT commit changes. The story description mentions "commit/push". Should the tirepump choice include an actual `git commit && git push` step, or just the existing context-clear behavior? The existing TirePump (`clearAndReload`) does not do git operations -- clarify whether this story adds that capability or just offers the existing TirePump as-is.

7. **Subprocess respawn:** Currently `ClaudeService.buildArgs()` includes `--permission-mode` based on `pendingMode` at spawn time. Since the process is persistent (kept alive between turns), changing `pendingMode` mid-session may not take effect until the process is killed and respawned. The auto-transition may need to force a process restart.
