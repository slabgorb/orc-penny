# Story Context: PROJ-14321 - Integrate grant checking into WheelHub hook router

## Summary

Wire the existing `settings-store.ts` grant checking system (`checkGrant()`) into the `hook-request.ts` handler so that incoming PreToolUse hook requests are automatically approved when a matching grant exists, and broadcast to WebSocket clients for manual approval only when no grant matches. Handle all three grant lifecycles (once auto-revoke, session, always) and fall back to `ask` when no UI clients are connected.

## Current State

### Grant System (settings-store.ts) -- Fully Implemented but Disconnected from Hook Router

The grant system in `settings-store.ts` is fully functional with:

- **PermissionGrant interface**: `{ tool, scope, grant_type, granted_at }` where `grant_type` is `'once' | 'session' | 'always'`
- **`checkGrant(tool, command)`**: Checks both session and persisted grants, auto-revokes `once` grants after a match. Uses tool-specific matching: glob patterns for Bash commands, domain matching for WebFetch URLs, path matching for Edit/Write/Read file paths.
- **`addGrant(grant)`**: Adds grants to either session storage (once/session) or persisted storage (always), with deduplication.
- **`initializeGrants()` / `setGrantsPersistCallback()`**: Initialization flow in `main.ts:initializeApp()` loads persisted (always) grants from `~/.cyclist/grants.json` via `settings.ts:loadGrants()`, initializes the runtime store, and wires `saveGrants()` as the persistence callback.
- **Three storage tiers**: Session grants (once + session) live in-memory only. Always grants persist to `~/.cyclist/grants.json` via the callback.

### Hook Request Handler (hook-request.ts) -- Has Hardcoded Allowlist, No Grant Integration

The handler currently:

1. Accepts `POST /api/hook-request` with `{ toolName, toolId, input, sessionId?, context? }`.
2. **Hardcoded Bash-only auto-approval**: Uses `SAFE_COMMAND_PATTERNS` (regex array for `ls`, `pwd`, `git status`, etc.) via a local `isCommandAllowlisted()` function. This is a temporary stopgap that duplicates logic -- it does NOT use `settings-store.ts` grants or allowlists.
3. **No-client fallback**: Returns `{ decision: 'ask' }` when `hookClients.size === 0`.
4. **WebSocket broadcast**: Creates a `PendingApproval` promise, broadcasts `hook-request` message to all `/ws/hooks` clients, waits for `hook-response` message back with approve/deny.
5. **Timeout**: 2-minute timeout on pending approvals, then falls back to `ask`.
6. **Only handles Bash**: The `isCommandAllowlisted()` function only checks Bash commands -- Edit, Write, WebFetch, and other tools always go to broadcast even if they have matching grants.

### Approval Gate (approval-gate.ts) -- Uses Grants but Not Called from Hook Router

`approval-gate.ts:interceptToolUse()` already imports and uses `checkGrant()` from settings-store, plus `getBashApprovalGate()` and `isAllowlisted()`. However, this module is used by the Electron IPC path (main.ts message handler), **not** by the HTTP hook-request router. The function extracts tool scope via `getToolScope()` which maps tool names to their relevant input fields (command for Bash, url for WebFetch, file_path for Edit/Write/Read).

### WebSocket Infrastructure (websocket.ts) -- Hook Clients Already Wired

The `/ws/hooks` WebSocket channel is fully operational:
- `hooksWss` WebSocket server handles upgrade at `/ws/hooks`
- On connection: calls `addHookClient(ws)` from hook-request.ts
- On message: calls `handleHookWebSocketMessage(ws, data)` for approval responses
- The ApprovalModal component (`ApprovalModal/index.tsx`) already subscribes to `/ws/hooks` via `subscribeToPermissionRequests()` and sends responses via `sendPermissionResponse()`

### Grant Initialization (main.ts) -- Only Runs in Electron Mode

`main.ts:initializeApp()` loads grants from file and initializes the store. In web/standalone server mode (`server.ts`), only `initializeSettings()` is called -- grants are NOT loaded. This means in standalone WheelHub mode, the grant store starts empty.

## Target State

After implementation, the hook-request handler should:

1. **Import and use `checkGrant()` from settings-store** instead of the hardcoded `SAFE_COMMAND_PATTERNS`.
2. **Check grants for ALL tool types**, not just Bash -- using proper scope extraction (command for Bash, url for WebFetch, file_path for Edit/Write/Read, JSON for others).
3. **Auto-approve when grant matches**: Return `{ decision: 'allow', reason: 'Granted by <grant_type> permission' }` immediately, without broadcasting to WebSocket.
4. **Once grants consumed on check**: The `checkGrant()` function already auto-revokes once grants. No additional work needed for once lifecycle.
5. **Broadcast only when no grant matches**: Fall through to existing WebSocket broadcast path.
6. **Return `ask` when no clients connected**: Existing behavior, preserved.
7. **Optionally also check `isAllowlisted()`**: The settings-store allowlist (`addToAllowlist`, `isAllowlisted`) is a separate mechanism from grants -- keep checking it for Bash commands as a supplementary auto-approval path.

## Key Files

### Must Modify

| File | Description |
|------|-------------|
| `pennyfarthing/packages/cyclist/src/api/hook-request.ts` | **Primary target.** Import `checkGrant`, `isAllowlisted`, `getBashApprovalGate` from settings-store. Replace hardcoded `SAFE_COMMAND_PATTERNS` with grant/allowlist checking. Add scope extraction for all tool types. |
| `pennyfarthing/packages/cyclist/src/server.ts` | May need to call `initializeGrants()` / `setGrantsPersistCallback()` for standalone server mode, so grants are available when WheelHub runs outside Electron. Currently only `initializeSettings()` is called. |

### Must Read (Reference / Dependencies)

| File | Description |
|------|-------------|
| `pennyfarthing/packages/cyclist/src/settings-store.ts` | Grant storage, `checkGrant()`, `addGrant()`, `isAllowlisted()`, `getBashApprovalGate()`, `PermissionGrant` interface, `GrantType` enum. |
| `pennyfarthing/packages/cyclist/src/approval-gate.ts` | Reference for `getToolScope()` pattern -- extracts scope from tool input. `interceptToolUse()` shows the grant-checking pattern already in use. |
| `pennyfarthing/packages/cyclist/src/settings.ts` | `loadGrants()`, `saveGrants()`, `PermissionGrant` type (duplicated from settings-store), `GRANTS_FILE` path (`~/.cyclist/grants.json`). |
| `pennyfarthing/packages/cyclist/src/main.ts` | `initializeApp()` shows initialization flow: `initializeSettings()` -> `loadGrants()` -> `initializeGrants()` -> `setGrantsPersistCallback(saveGrants)`. |
| `pennyfarthing/packages/cyclist/src/websocket.ts` | Hook WebSocket setup (`hooksWss`), `addHookClient()` usage, message handling. |
| `pennyfarthing/packages/cyclist/src/public/components/ApprovalModal/index.tsx` | Client-side WebSocket subscription for hook requests, response sending with `grantScope`. Reference for understanding the data contract. |
| `pennyfarthing/packages/cyclist/src/dangerous-path.ts` | Path-based danger classification (not directly used in this story, but relevant for PROJ-14323). |
| `pennyfarthing/packages/cyclist/e2e/hook-request.e2e.ts` | Existing E2E tests for hook request flow. Tests verify allowlist behavior, WebSocket broadcast, approve/deny flow. Will need new tests for grant-based auto-approval. |

### May Need New Tests

| File | Description |
|------|-------------|
| `pennyfarthing/packages/cyclist/tests/PROJ-14321-*.test.ts` | New unit tests for grant integration in hook-request handler. |
| `pennyfarthing/packages/cyclist/e2e/hook-request.e2e.ts` | Extend with grant-based auto-approval tests. |

## Technical Approach

### 1. Add grant checking to hook-request.ts `handleHookRequest()`

Import from settings-store:
```typescript
import { checkGrant, isAllowlisted, getBashApprovalGate } from '../settings-store.js';
```

Add a scope extraction function (modeled after `approval-gate.ts:getToolScope()`):
```typescript
function extractToolScope(toolName: string, input: Record<string, unknown>): string {
  switch (toolName) {
    case 'Bash': return (input.command as string) || '';
    case 'WebFetch': return (input.url as string) || '';
    case 'Edit':
    case 'Write':
    case 'Read': return (input.file_path as string) || '';
    default: return JSON.stringify(input);
  }
}
```

Replace the hardcoded `isCommandAllowlisted()` check with a unified grant + allowlist check:
```typescript
// Check for auto-approval via grants (all tool types)
const scope = extractToolScope(toolName, input || {});
if (checkGrant(toolName, scope)) {
  res.json({
    decision: 'allow',
    reason: 'Granted by permission grant',
  });
  return;
}

// Also check Bash allowlist for backward compatibility
if (toolName === 'Bash' && isAllowlisted(scope)) {
  res.json({
    decision: 'allow',
    reason: 'Command matches allowlist pattern',
  });
  return;
}
```

Remove `SAFE_COMMAND_PATTERNS` and `isCommandAllowlisted()` -- these are superseded by the proper grant/allowlist system.

### 2. Ensure grants are initialized in standalone server mode

In `server.ts`, add grant initialization alongside settings initialization:
```typescript
import { loadGrants, saveGrants } from './settings.js';
import { initializeGrants, setGrantsPersistCallback } from './settings-store.js';

// After initializeSettings(getProjectDir()):
const grants = loadGrants();
initializeGrants(grants);
setGrantsPersistCallback(saveGrants);
```

### 3. Handle grant responses from WebSocket

When the ApprovalModal sends a `hook-response` with a `grantScope`, the hook-request handler should persist the grant. In `resolveApproval()` or `handleHookWebSocketMessage()`, when `data.grantScope` is present:
```typescript
import { addGrant, type PermissionGrant } from '../settings-store.js';

// After resolving the approval:
if (approved && data?.grantScope) {
  const scope = extractToolScope(pending.toolName, pending.input);
  const grant: PermissionGrant = {
    tool: pending.toolName,
    scope,
    grant_type: data.grantScope as GrantTypeValue,
    granted_at: new Date().toISOString(),
  };
  addGrant(grant);
}
```

This ensures that when a user checks "Always allow" in the ApprovalModal and approves, the grant is stored and future identical requests are auto-approved.

## Acceptance Criteria

1. **Grant-based auto-approval**: When a hook request arrives for any tool type and a matching grant exists in settings-store, return `{ decision: 'allow' }` without broadcasting to WebSocket.
2. **Allowlist fallback for Bash**: Bash commands matching the settings-store allowlist (`isAllowlisted()`) are still auto-approved.
3. **Once grant lifecycle**: Once grants auto-revoke after first use (handled by `checkGrant()` internals).
4. **Session grant lifecycle**: Session grants persist for the app session, cleared on exit.
5. **Always grant lifecycle**: Always grants persist to `~/.cyclist/grants.json` and survive restarts.
6. **WebSocket broadcast on no match**: Non-granted requests broadcast to connected clients for manual approval.
7. **Ask fallback**: Return `{ decision: 'ask' }` when no WebSocket clients are connected.
8. **Grant storage on approval**: When user approves with a grant scope (once/session/always), the grant is stored via `addGrant()`.
9. **Hardcoded patterns removed**: `SAFE_COMMAND_PATTERNS` regex array removed from hook-request.ts.

## Dependencies

### Depends On (Predecessors)

- **PROJ-14318** (Remove legacy IPC approval path) -- **DONE**. Ensures old IPC flow is removed so there is no confusion about which approval path is active.
- **PROJ-14320** (Update and register PreToolUse hook) -- Should be done or in-flight. The hook script needs to POST to `/api/hook-request` for this story's changes to be exercised. However, this story can be developed and tested independently via direct HTTP requests.

### Depended On By (Successors)

- **PROJ-14322** (Mount ApprovalModal in React component tree) -- Depends on this story's WebSocket broadcast behavior being correct. The modal consumes hook-request broadcasts.
- **PROJ-14323** (Add severity classification) -- Builds on this story by adding severity metadata to the broadcast.
- **PROJ-14324** (Wire grant persistence across scopes) -- Extends grant behavior, but the core once/session/always lifecycle is already implemented in settings-store.ts and wired by this story.
- **PROJ-14325** (Connect /permissions skill) -- Uses the same grant store this story wires in.

## Risks / Open Questions

1. **Standalone server grant initialization**: In standalone server mode (not Electron), `main.ts:initializeApp()` is never called, so grants start empty. The fix in `server.ts` is straightforward but needs to be included. Without it, grants only work in Electron mode.

2. **Race condition on grant storage**: If `handleHookWebSocketMessage` stores a grant via `addGrant()` while `checkGrant()` is running for a concurrent request, there could be a brief inconsistency. However, since Node.js is single-threaded, this is safe -- operations are atomic within the event loop.

3. **Scope extraction duplication**: `getToolScope()` in approval-gate.ts and the new `extractToolScope()` in hook-request.ts are essentially identical. Consider extracting to a shared utility, or importing from approval-gate.ts. However, approval-gate.ts also imports from settings-store.ts, creating a potential circular dependency concern if hook-request.ts imports from approval-gate.ts. Best approach: duplicate the small function to keep modules decoupled, or extract to a tiny shared module.

4. **SAFE_COMMAND_PATTERNS removal risk**: The hardcoded patterns provide a safety net even when no grants exist. Removing them means the first time a user runs `ls` or `git status`, it will prompt for approval (if the approval gate is enabled and no grant exists). This is arguably correct behavior -- grants should be explicit. But it is a UX regression from the current behavior. Consider: keep `SAFE_COMMAND_PATTERNS` as a built-in baseline alongside grants, or convert them to default session grants on initialization.

5. **Grant store in web mode**: When running Cyclist in web mode (`CYCLIST_DEV_WEB`), the server starts via `server.ts` not `main.ts`. Need to ensure grants are loaded in that path too.

6. **grantScope in hook-response data contract**: The ApprovalModal already sends `grantScope` in the WebSocket `hook-response` message (`data.grantScope`). But the current `resolveApproval()` in hook-request.ts passes `data` through opaquely -- the grant storage logic needs to be added to actually consume it.

7. **TDD workflow**: This is a `tdd` workflow story. Tests should be written first (RED), then implementation (GREEN). TEA should focus on testing grant-based auto-approval, allowlist fallback, scope extraction for all tool types, once-grant revocation, and the no-client fallback.
