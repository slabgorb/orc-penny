# Epic 78: Cyclist Permission System

## Overview

Wire existing permission components into a working end-to-end approval flow. When Claude Code needs permission for any tool action, Cyclist shows an approval modal, the user decides (once/session/always), and work continues. Remove legacy IPC path, consolidate on WheelHub WebSocket architecture.

**Prior work:** Epic 33 (PROJ-11705) built the components. This epic connects them.

## Background

### The Problem

Claude Code's permission prompts leave users with no way to respond through Cyclist. The pieces exist (approval gate, hook script, WheelHub router, ApprovalModal, grant storage) but they aren't wired together. Three specific breaks:

1. **Hook not registered**: `cyclist-pretooluse-hook.js` exists but isn't listed in `.claude/settings.local.json` PreToolUse hooks
2. **ApprovalModal not mounted**: Fully implemented React component (62 tests passing) but never imported/rendered in App.tsx - orphaned during React migration
3. **Two competing architectures**: Old Electron IPC path (`/approval-request` in main.ts) and new WebSocket/WheelHub path (`/api/hook-request` in server.ts) were never reconciled

### What Already Works

Epic 33 (PROJ-11705) completed 4 of 5 stories:
- **33-1** Permission Request Protocol - TypeScript schema and types
- **33-2** `/permissions` skill - CLI for list/grant/revoke
- **33-3** Cyclist Approval Modal UI - shadcn Dialog, WebSocket, severity classification
- **33-4** Spot Permission Grants - once/session/always grant scopes
- **33-5** Workflow Permission Presets - **NOT DONE** (schema exists, not integrated)

## Technical Architecture

### Component Map

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

### Key Files

| File | Purpose | Status |
|------|---------|--------|
| `src/hooks/cyclist-pretooluse-hook.js` | Hook script, POSTs to WheelHub | Exists, targets wrong URL |
| `src/api/hook-request.ts` | WheelHub HTTP+WebSocket handler | Mounted, functional |
| `src/public/components/ApprovalModal/index.tsx` | React approval modal | Implemented, 62 tests, NOT mounted |
| `src/public/App.tsx` | React app root | Needs ApprovalModal import |
| `src/settings-store.ts` | Grant CRUD + pattern matching | Implemented |
| `src/approval-gate.ts` | Tool interception logic | Has old + new, needs cleanup |
| `src/dangerous-path.ts` | Sensitive path detection | Implemented, reuse for severity |
| `src/main.ts` | Electron main process | Lines ~2266-2318: old `/approval-request` to remove |
| `src/websocket.ts` | WebSocket setup | `/ws/hooks` handler registered |
| `.claude/settings.local.json` | Claude Code settings | Hook registration goes here |
| `.cyclist-approval-port` | Port discovery file | Written on Cyclist startup |

### Grant Storage

| Type | Storage | Lifetime |
|------|---------|----------|
| `once` | In-memory Map | Single use, auto-revoked |
| `session` | In-memory Map | Cleared on session end |
| `always` | `.claude/settings.local.json` | Persistent until revoked |

### API Contracts

**POST /api/hook-request**
```json
// Request
{ "toolName": "Bash", "toolId": "tool_use_abc123", "input": { "command": "npm test" } }

// Response (auto-approved)
{ "decision": "allow", "reason": "Command matches grant pattern: npm *" }

// Response (denied)
{ "decision": "deny", "reason": "Rejected by user" }

// Response (no UI / timeout)
{ "decision": "ask", "reason": "No Cyclist clients connected" }
```

**WebSocket /ws/hooks**
```json
// Server → Client
{ "type": "hook-request", "toolId": "...", "toolName": "Bash", "input": {...}, "severity": "safe" }

// Client → Server
{ "type": "hook-response", "toolId": "...", "approved": true, "grantScope": "session" }
```

### Severity Classification

| Category | Examples |
|----------|----------|
| `safe` | Read, Grep, Glob, WebSearch, git status/diff/log |
| `normal` | Edit, Write, non-destructive Bash, git add/commit |
| `destructive` | rm -rf, git push --force, git reset --hard, writes to .env/.ssh/.aws |

## Stories

| Story | Title | Points | Priority | Dependencies |
|-------|-------|--------|----------|-------------|
| 78-1 | Remove legacy IPC approval path | 2 | P0 | None |
| 78-2 | Update and register PreToolUse hook | 3 | P0 | 78-1 |
| 78-3 | Integrate grant checking into WheelHub hook router | 3 | P0 | 78-2 |
| 78-4 | Mount ApprovalModal in React component tree | 3 | P0 | 78-3 |
| 78-5 | Add severity classification to hook request flow | 3 | P1 | 78-3, 78-4 |
| 78-6 | Wire grant persistence across all three scopes | 3 | P1 | 78-3, 78-4 |
| 78-7 | Connect /permissions skill to grant store | 2 | P2 | 78-6 |
| 78-8 | Workflow permission presets | 2 | P3 | 78-6 |
| 78-9 | Agent-level permission scoping | 3 | P1 | 78-3 |

### Story Notes

**78-1**: Cleanup first. Remove old `/approval-request` endpoint from main.ts, Electron IPC handlers, and `interceptBashToolUse` from approval-gate.ts. Keep generic `interceptToolUse`.

**78-2**: Update hook script target URL from `/approval-request` to `/api/hook-request`. Register in `.claude/settings.local.json`. Handle WheelHub unreachable → return `{ decision: "ask" }`.

**78-3**: Wire `settings-store.ts` grant checking into `hook-request.ts`. Auto-approve on match, broadcast to WebSocket on no match. Handle no-clients → `ask`. Handle timeout → `ask`.

**78-4**: Import ApprovalModal in App.tsx. Connect WebSocket subscription. Queue concurrent requests. Keyboard shortcuts: Enter=approve, Escape=deny. Existing 62 tests must pass.

**78-5**: Classify severity server-side before broadcast. Reuse `dangerous-path.ts` for path classification. Include severity + warning text in WebSocket payload. Red border for destructive in modal.

**78-6**: Ensure once/session/always lifecycle works end-to-end. Glob pattern matching (e.g. `npm *` matches `npm test`). Always-grants persist to `.claude/settings.local.json`, loaded on startup.

**78-7**: Wire existing `/permissions` skill to `settings-store.ts` for list/grant/revoke. Mostly connecting existing code.

**78-8**: Growth feature. Integrate `workflow-permissions.ts` schema into workflow startup. Batch approval modal on agent activation. Session-scoped grants.

**78-9**: Thread agent identity through the permission flow. `agent-session.sh` already sets the active agent name — pass it from the hook script through to WheelHub and into the grant store. ApprovalModal shows which agent is requesting. Grants can be scoped to a specific agent (e.g., "allow dev:Bash:*") or apply to all agents (current behavior). Grant matching checks agent identity when scope is agent-specific. Depends on 78-3 (grant checking in WheelHub).

## Constraints

- Claude Code PreToolUse hooks have a finite timeout - must respond within it
- Hook script reads port from `.cyclist-approval-port` - Cyclist must write this on startup
- Grants in `.claude/settings.local.json` must not conflict with Claude Code's own settings format
- ApprovalModal uses shadcn Dialog (Radix Portal) - renders outside React tree, tests use `data-state` not `title` attr

## Planning Artifacts

- **PRD:** `artifacts/prd.md`
- **Architecture:** `artifacts/architecture.md`
- **Epics & Stories:** `artifacts/epics.md`
