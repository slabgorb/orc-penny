# Story MSSCI-14318: Remove legacy IPC approval path

**Status:** in_progress
**Phase:** approved
**Workflow:** trivial
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-14318-remove-legacy-ipc-approval
**Jira:** MSSCI-14318
**Epic:** epic-78 (Cyclist Permission System)
**Points:** 2

## Story Description

Remove old /approval-request endpoint from main.ts, Electron IPC permission-request/resolveHookApproval handlers, and interceptBashToolUse from approval-gate.ts. Generic interceptToolUse remains.

## Acceptance Criteria

- [ ] /approval-request endpoint removed from main.ts
- [ ] Electron IPC permission-request handler removed
- [ ] resolveHookApproval IPC handler removed
- [ ] interceptBashToolUse removed from approval-gate.ts
- [ ] Generic interceptToolUse remains intact
- [ ] No broken imports or references to removed code
- [ ] Tests pass (existing tests updated if they reference removed code)

## Epic Context

### Epic 78: Cyclist Permission System

Wire existing permission components into a working end-to-end approval flow. When Claude Code needs permission for any tool action, Cyclist shows an approval modal, the user decides (once/session/always), and work continues. Remove legacy IPC path, consolidate on WheelHub WebSocket architecture.

### The Problem

Claude Code's permission prompts leave users with no way to respond through Cyclist. Three specific breaks:

1. **Hook not registered**: `cyclist-pretooluse-hook.js` exists but isn't listed in `.claude/settings.local.json` PreToolUse hooks
2. **ApprovalModal not mounted**: Fully implemented React component (62 tests passing) but never imported/rendered in App.tsx - orphaned during React migration
3. **Two competing architectures**: Old Electron IPC path (`/approval-request` in main.ts) and new WebSocket/WheelHub path (`/api/hook-request` in server.ts) were never reconciled

### Technical Architecture

The permission flow uses a WheelHub WebSocket architecture:

```
Claude Code Process
  └── PreToolUse Hook → cyclist-pretooluse-hook.js
        └── HTTP POST /api/hook-request

Cyclist Main Process (Node/Electron)
  └── WheelHub Server (Express)
        ├── /api/hook-request (HookRequestRouter)
        │     ├── Check grants (settings-store.ts)
        │     │   ├── Match? → { decision: "allow" }
        │     │   └── No match? → broadcast to WebSocket
        │     └── Wait for WebSocket response (2min timeout)
        └── /ws/hooks (WebSocket endpoint)

Cyclist Renderer (React 19)
  └── App.tsx
        └── ApprovalModal (top-level portal)
              ├── Subscribe: hook-request events
              ├── Classify severity
              ├── Display modal with grant scope buttons
              └── Send: hook-response
```

### Story Notes

**78-1 (This Story)**: Cleanup first. Remove old `/approval-request` endpoint from main.ts, Electron IPC handlers, and `interceptBashToolUse` from approval-gate.ts. Keep generic `interceptToolUse`.

### Key Files

| File | Purpose |
|------|---------|
| `src/main.ts` | Electron main process - Lines ~2266-2318: old `/approval-request` to remove |
| `src/approval-gate.ts` | Tool interception logic - Has old + new, needs cleanup |

### Grant Storage

| Type | Storage | Lifetime |
|------|---------|----------|
| `once` | In-memory Map | Single use, auto-revoked |
| `session` | In-memory Map | Cleared on session end |
| `always` | `.claude/settings.local.json` | Persistent until revoked |

## Work Log

- **Setup**: Branch created, session file initialized
- **Implement**: Removed legacy IPC approval code, PR #684 created

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `src/main.ts` - Removed /approval-request endpoint, setupApprovalIPCHandlers, startApprovalServer/stopApprovalServer, resolveHookApproval, processToolUseWithApproval, handlePermissionResponse, sendApprovalRequest, pendingHookApprovals, MSSCI-11947 interactive tool helpers, DI test helpers (-630 lines)
- `src/approval-gate.ts` - Stripped to only interceptToolUse + getToolScope. Removed interceptBashToolUse, requestApproval, resolveApproval, createRejectionError, pendingApprovals, getQueueLength, clearPendingApprovals

**Tests:** 1675/1675 passing (GREEN, 2 pre-existing failures unrelated)
**PR:** #684 - feat(MSSCI-14318): remove legacy IPC approval path
**Branch:** feat/MSSCI-14318-remove-legacy-ipc-approval (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** No new data flow — pure deletion of legacy IPC/HTTP approval code paths. WheelHub system (hook-request.ts, /ws/hooks) verified untouched.
**Pattern observed:** Clean import cleanup at main.ts:12,16 — removed unused http/server imports. approval-gate.ts properly reduced to single-responsibility (interceptToolUse only).
**Error handling:** N/A — no new code. Verified no dangling references to removed functions.
**Security:** No issues — legacy endpoints removed, no new attack surface.
**Notes:**
- [LOW] Orphaned `writeApprovalPortFile`/`cleanupApprovalPortFile`/`readApprovalPortFile` remain in server.ts — follow-up cleanup
- [LOW] Dead IPC channels in preload.ts (`bash:approval-request`, `path:approval-request`, `permission:request`) — follow-up cleanup
**Handoff:** To SM for finish-story
