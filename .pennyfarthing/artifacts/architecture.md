# Architecture Document - Cyclist Permission System

**Author:** Keith Avery
**Date:** 2026-02-05
**Status:** Draft

## System Architecture

### Decision: Consolidate on WebSocket/WheelHub Path

The system currently has two competing approval architectures. We consolidate on the **WebSocket/WheelHub path** and remove the old Electron IPC path.

**Rationale:** WheelHub is the established communication hub (per ADR-0004). The WebSocket path supports the React 19 renderer without Electron IPC dependencies, enables future web-based Cyclist, and aligns with the existing ApprovalModal implementation.

### Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Claude Code Process                                         │
│                                                             │
│  tool_use event                                             │
│      │                                                      │
│      ▼                                                      │
│  PreToolUse Hook ─── cyclist-pretooluse-hook.js             │
│      │                                                      │
│      │ HTTP POST /api/hook-request                          │
│      ▼                                                      │
├─────────────────────────────────────────────────────────────┤
│ Cyclist Main Process (Node/Electron)                        │
│                                                             │
│  WheelHub Server (Express)                                  │
│      │                                                      │
│      ├── /api/hook-request (HookRequestRouter)              │
│      │       │                                              │
│      │       ├── Check grants (settings-store.ts)           │
│      │       │   ├── Match? → { decision: "allow" }         │
│      │       │   └── No match? → broadcast to WebSocket     │
│      │       │                                              │
│      │       └── Wait for WebSocket response (2min timeout) │
│      │                                                      │
│      └── /ws/hooks (WebSocket endpoint)                     │
│              │                                              │
│              ├── Broadcast: hook-request events              │
│              └── Receive: hook-response events               │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ Cyclist Renderer Process (React 19)                         │
│                                                             │
│  App.tsx                                                    │
│      └── ApprovalModal (top-level, portal)                  │
│              │                                              │
│              ├── WebSocket subscribe: hook-request           │
│              ├── Classify severity (safe/normal/destructive) │
│              ├── Display modal with grant scope buttons      │
│              └── WebSocket send: hook-response               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow: Manual Approval

```
Claude Code                 WheelHub                    React UI
    │                          │                           │
    │── POST /api/hook-request │                           │
    │   {toolName,toolId,input}│                           │
    │                          │── WS: hook-request ──────▶│
    │                          │   {toolId,toolName,input}  │
    │                          │                           │
    │                          │                    [User decides]
    │                          │                           │
    │                          │◀── WS: hook-response ─────│
    │                          │   {toolId,approved,       │
    │                          │    grantScope}             │
    │                          │                           │
    │                          │── Store grant if approved  │
    │                          │                           │
    │◀─ HTTP Response ─────────│                           │
    │   {decision:"allow"}     │                           │
    │                          │                           │
    │── Execute tool ──────────│                           │
```

### Data Flow: Auto-Approval (Grant Exists)

```
Claude Code                 WheelHub
    │                          │
    │── POST /api/hook-request │
    │                          │── Check grants
    │                          │   (settings-store.ts)
    │                          │── Match found!
    │◀─ HTTP Response ─────────│
    │   {decision:"allow"}     │
    │                          │
    │── Execute tool           │
    (no UI involvement)
```

## Key Technical Decisions

### 1. Hook Script Targets WheelHub Directly

The hook script (`cyclist-pretooluse-hook.js`) POSTs to `/api/hook-request` on the WheelHub Express server. Port discovered via `.cyclist-approval-port` file.

**Files:**
- `packages/cyclist/src/hooks/cyclist-pretooluse-hook.js` (update target URL)
- `.cyclist-approval-port` (written by Cyclist on startup)

### 2. Grant Storage in settings-store.ts

All grant CRUD operations go through `settings-store.ts`. Three grant types:

| Type | Storage | Lifetime |
|------|---------|----------|
| `once` | In-memory Map | Single use, auto-revoked |
| `session` | In-memory Map | Cleared on session end |
| `always` | `.claude/settings.local.json` | Persistent until revoked |

**Files:**
- `packages/cyclist/src/settings-store.ts` (existing, extend)

### 3. ApprovalModal as Top-Level Portal

ApprovalModal renders via shadcn Dialog (which uses Radix Portal). Mounted in `App.tsx` outside the workspace panel tree so it overlays everything.

**Request queue:** Multiple hook-requests are queued in state. Modal shows one at a time. When resolved, next in queue appears.

**Files:**
- `packages/cyclist/src/public/components/ApprovalModal/index.tsx` (existing, mount it)
- `packages/cyclist/src/public/App.tsx` (add import + render)

### 4. Severity Classification at WheelHub Level

Severity is classified server-side in the hook-request handler before broadcasting. The classification result is included in the WebSocket broadcast so the UI doesn't need to duplicate logic.

**Categories:**
- `safe`: Read, Grep, Glob, WebSearch, git status/diff/log
- `normal`: Edit, Write, Bash (non-destructive), git add/commit
- `destructive`: rm -rf, git push --force, git reset --hard, writes to dangerous paths

**Files:**
- `packages/cyclist/src/api/hook-request.ts` (add classification before broadcast)
- `packages/cyclist/src/dangerous-path.ts` (existing, reuse for path classification)
- `packages/cyclist/src/approval-gate.ts` (existing classifyActionSeverity, move to shared util)

### 5. Old System Removal

Remove the legacy `/approval-request` endpoint from `main.ts` and all Electron IPC approval handlers. The `interceptBashToolUse` function in `approval-gate.ts` is superseded by `interceptToolUse` (generic, any tool).

**Files to modify:**
- `packages/cyclist/src/main.ts` (remove lines 2266-2318)
- `packages/cyclist/src/approval-gate.ts` (remove `interceptBashToolUse`, keep `interceptToolUse`)

## API Contracts

### POST /api/hook-request

**Request:**
```json
{
  "toolName": "Bash",
  "toolId": "tool_use_abc123",
  "input": { "command": "npm test" },
  "sessionId": "optional-session-id"
}
```

**Response (auto-approved):**
```json
{
  "decision": "allow",
  "reason": "Command matches grant pattern: npm *"
}
```

**Response (user approved):**
```json
{
  "decision": "allow",
  "reason": "Approved by user"
}
```

**Response (user denied):**
```json
{
  "decision": "deny",
  "reason": "Rejected by user"
}
```

**Response (timeout/no UI):**
```json
{
  "decision": "ask",
  "reason": "No Cyclist clients connected, deferring to Claude Code"
}
```

### WebSocket: /ws/hooks

**Server → Client (hook-request):**
```json
{
  "type": "hook-request",
  "toolId": "tool_use_abc123",
  "toolName": "Bash",
  "input": { "command": "npm test" },
  "severity": "safe",
  "context": {
    "dangerousPath": false,
    "pathCategory": null,
    "warning": null
  }
}
```

**Client → Server (hook-response):**
```json
{
  "type": "hook-response",
  "toolId": "tool_use_abc123",
  "approved": true,
  "grantScope": "session"
}
```

### Grant Format (settings.local.json)

```json
{
  "permissions": {
    "grants": [
      {
        "tool": "Bash",
        "scope": "npm *",
        "grant_type": "always",
        "granted_at": "2026-02-05T16:30:00Z"
      }
    ]
  }
}
```

## Files Changed Summary

| File | Action | Description |
|------|--------|-------------|
| `src/hooks/cyclist-pretooluse-hook.js` | Modify | Change POST target to `/api/hook-request` |
| `src/api/hook-request.ts` | Modify | Add severity classification, integrate settings-store grants |
| `src/public/components/ApprovalModal/index.tsx` | Keep | Already implemented, just needs mounting |
| `src/public/App.tsx` | Modify | Import and mount ApprovalModal |
| `src/settings-store.ts` | Extend | Ensure grant CRUD covers all three scopes |
| `src/main.ts` | Modify | Remove old `/approval-request` endpoint |
| `src/approval-gate.ts` | Modify | Remove `interceptBashToolUse`, keep generic version |
| `src/dangerous-path.ts` | Keep | Reuse for severity classification |
| `.claude/settings.local.json` | Modify | Register PreToolUse hook |

## Constraints and Risks

| Risk | Mitigation |
|------|------------|
| Claude Code hook timeout too short | Measure actual timeout, ensure WheelHub responds within it. Fallback to `ask` on timeout. |
| WebSocket disconnect during approval | Reconnection with exponential backoff. Pending approvals timeout to `ask`. |
| Race condition: grant stored after approval but before next identical request | Grant storage is synchronous in-memory; only `always` grants write to disk asynchronously. |
| Port file stale after crash | Cyclist overwrites on startup. Hook script handles connection refused gracefully. |

## No Starter Template

This is a brownfield project. All code exists in the `packages/cyclist/` package. No project scaffolding needed.
