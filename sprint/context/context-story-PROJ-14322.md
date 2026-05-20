# Story Context: PROJ-14322 - Mount ApprovalModal in React component tree

## Summary

Import the fully-implemented (but orphaned) ApprovalModal component into App.tsx, connect it to the `/ws/hooks` WebSocket for real-time hook-request events, wire hook-response sending on user approval/rejection, and add a request queue so concurrent permission requests display one at a time without stacking modals.

## Current State

### ApprovalModal Component (COMPLETE -- 62 tests passing, NOT mounted)

The ApprovalModal was built in Story PROJ-12713 (Epic 71) with full functionality:

- **Location:** `packages/cyclist/src/public/components/ApprovalModal/index.tsx`
- **UI:** shadcn Dialog with command preview, severity classification (safe/normal/destructive), "Always allow" checkbox, Approve/Reject buttons
- **Keyboard:** Enter = approve, Escape = reject (via Radix Dialog)
- **Styles:** `ApprovalModal.css` for command preview + icon, Tailwind utilities for everything else
- **Tests:** `tests/PROJ-12713-approval-modal.test.ts` -- 62 tests covering all ACs (module exports, formatting, keyboard, severity, grants, overlay, styling, accessibility, IPC integration)

The component exports:
- `default` -- The `ApprovalModal` React component (props: `isOpen`, `toolName`, `toolId`, `input`, `onApprove`, `onReject`, `onDismiss`, `className`)
- `useApprovalModal()` -- Hook managing `{request, isOpen, show, hide, approve, reject}` state (single-request, no queue)
- `subscribeToPermissionRequests(callback)` -- Creates WebSocket to `/ws/hooks`, parses `hook-request` messages, calls callback with `ApprovalRequest`, returns cleanup function. Has reconnect logic (2s delay).
- `sendPermissionResponse(response)` -- Sends `hook-response` JSON over the same WebSocket
- `createApprovalResponse(toolId, approved, grantScope?)` -- Factory for response objects
- Types: `ApprovalRequest`, `ApprovalResponse`, `ApprovalModalProps`, `ToolInput`, `GrantScope`, `ActionSeverity`
- Constants: `GRANT_SCOPES` (`once`/`session`/`always`), `KEYBOARD_SHORTCUTS`, test IDs, severity classnames

### App.tsx (NO ApprovalModal)

- **Location:** `packages/cyclist/src/public/App.tsx`
- **Provider stack:** `ErrorBoundary > ClaudeProvider > MessageQueueProvider > CommandPaletteProvider`
- **Content:** SkipLinks, loading state, `DockviewWorkspace` panel layout
- ApprovalModal is not imported or rendered

### WebSocket Infrastructure (COMPLETE)

- **Server:** `src/websocket.ts` registers `/ws/hooks` WebSocket server (line ~420), hooks into `addHookClient` / `handleHookWebSocketMessage` from `src/api/hook-request.ts`
- **Hook request handler:** `src/api/hook-request.ts` -- Express router at `/api/hook-request`, broadcasts to WebSocket clients, tracks `pendingApprovals` Map, 2-minute timeout, `resolveApproval()` called on WebSocket response
- **E2E tests:** `e2e/hook-request.e2e.ts` -- Integration tests for the HTTP + WebSocket flow

### Hook Script (targets WRONG URL -- PROJ-14320 will fix)

- **Location:** `src/hooks/cyclist-pretooluse-hook.js`
- Currently POSTs to `/approval-request` (the old endpoint removed in PROJ-14318)
- PROJ-14320 will update it to POST to `/api/hook-request`

### Grant System (COMPLETE)

- **Location:** `src/settings-store.ts`
- `checkGrant(tool, command)` with glob matching, auto-revoke for `once` grants
- `addGrant(grant)` with session vs persisted storage
- `GrantType` enum: `once`, `session`, `always`
- Note: PROJ-14321 will wire grant checking into `hook-request.ts` (currently uses a hardcoded allowlist)

### Legacy IPC (REMOVED in PROJ-14318)

- Old `/approval-request` endpoint removed from `main.ts`
- `interceptBashToolUse` removed from `approval-gate.ts`
- Generic `interceptToolUse` remains

## Target State

After this story, App.tsx renders ApprovalModal at the top level of the component tree. When a `hook-request` WebSocket event arrives, the request is queued in component state. The modal displays one request at a time. When the user approves or rejects, a `hook-response` is sent back via WebSocket, the request is dequeued, and the next queued request (if any) is shown.

```
App.tsx render tree:
  ErrorBoundary
    ClaudeProvider
      MessageQueueProvider
        CommandPaletteProvider
          .cyclist-app
            SkipLinks
            DockviewWorkspace | Loading
          ApprovalModal  <-- NEW: rendered here, outside workspace but inside providers
```

## Key Files

### Files to Modify

| File | Change |
|------|--------|
| `packages/cyclist/src/public/App.tsx` | Import ApprovalModal + add queue state + WebSocket subscription + render modal |

### Files to Read (not modify)

| File | Reason |
|------|--------|
| `packages/cyclist/src/public/components/ApprovalModal/index.tsx` | Component API, exported hooks, types, WebSocket functions |
| `packages/cyclist/src/public/components/ApprovalModal/ApprovalModal.css` | Styles (already imported by component) |
| `packages/cyclist/src/api/hook-request.ts` | Server-side WebSocket message format, `HookRequest`/`HookResponse` types |
| `packages/cyclist/src/websocket.ts` | `/ws/hooks` WebSocket server setup, `handleHookWebSocketMessage` |
| `packages/cyclist/src/settings-store.ts` | Grant types, `GrantScope` enum (for understanding response data) |
| `packages/cyclist/src/public/contexts/MessageQueueContext.tsx` | Example of context/queue pattern already used in App.tsx |
| `packages/cyclist/src/public/contexts/ClaudeContext.tsx` | Example of WebSocket connection pattern in a provider |
| `tests/PROJ-12713-approval-modal.test.ts` | Existing 62 tests that must continue passing |
| `e2e/hook-request.e2e.ts` | E2E tests for the hook request flow |

## Technical Approach

### 1. Add Request Queue State to App.tsx

The existing `useApprovalModal()` hook manages single-request state. For queuing, add state directly in App.tsx (or create a new `useApprovalQueue` hook):

```typescript
// Queue of pending approval requests
const [approvalQueue, setApprovalQueue] = useState<ApprovalRequest[]>([]);
const currentRequest = approvalQueue[0] ?? null;
```

### 2. Subscribe to WebSocket in useEffect

Use the existing `subscribeToPermissionRequests` function exported by ApprovalModal:

```typescript
useEffect(() => {
  const unsubscribe = subscribeToPermissionRequests((request) => {
    setApprovalQueue(prev => [...prev, request]);
  });
  return unsubscribe;
}, []);
```

This creates a WebSocket connection to `/ws/hooks` with automatic reconnection.

### 3. Wire Approve/Reject Handlers

```typescript
const handleApprove = useCallback((grantScope: GrantScope) => {
  if (!currentRequest) return;
  sendPermissionResponse(createApprovalResponse(
    currentRequest.toolId, true, grantScope
  ));
  setApprovalQueue(prev => prev.slice(1)); // dequeue
}, [currentRequest]);

const handleReject = useCallback(() => {
  if (!currentRequest) return;
  sendPermissionResponse(createApprovalResponse(
    currentRequest.toolId, false
  ));
  setApprovalQueue(prev => prev.slice(1)); // dequeue
}, [currentRequest]);

const handleDismiss = useCallback(() => {
  // Dismiss = reject (non-blocking overlay click)
  handleReject();
}, [handleReject]);
```

### 4. Render ApprovalModal

Place it inside the provider stack but outside the workspace layout, so it renders as a portal overlay:

```tsx
{currentRequest && (
  <ApprovalModal
    isOpen={!!currentRequest}
    toolName={currentRequest.toolName}
    toolId={currentRequest.toolId}
    input={currentRequest.input}
    onApprove={handleApprove}
    onReject={handleReject}
    onDismiss={handleDismiss}
  />
)}
```

### 5. Queue Badge (Optional Enhancement)

Consider showing a badge/count when multiple requests are queued, so the user knows more are waiting. This is not required by the story description but improves UX.

## Acceptance Criteria

1. ApprovalModal is imported and rendered in App.tsx at the top level
2. WebSocket subscription for `hook-request` events is connected on mount
3. `hook-response` is sent via WebSocket when user approves or rejects
4. Concurrent requests are queued (one modal shown at a time, no stacking)
5. Keyboard shortcuts work: Enter = approve, Escape = reject
6. Existing 62 ApprovalModal tests continue to pass
7. E2E hook-request tests continue to pass

## Dependencies

### Upstream (must be done first)

| Story | Title | Status | Why Needed |
|-------|-------|--------|------------|
| PROJ-14318 | Remove legacy IPC approval path | **done** | Old code removed, clean slate |
| PROJ-14320 | Update and register PreToolUse hook | backlog | Hook script must POST to `/api/hook-request` for requests to reach WebSocket. Without this, no requests arrive. However, the mounting story can be done independently -- the WebSocket subscription will simply receive no messages until the hook is registered. |
| PROJ-14321 | Integrate grant checking into WheelHub hook router | backlog | Grant checking in the HTTP handler. Without this, all non-allowlisted requests are broadcast to WebSocket (which is actually fine for testing the modal). |

**Practical note:** This story (PROJ-14322) can be developed and tested independently of PROJ-14320 and PROJ-14321 by using the E2E test helpers to send synthetic hook requests via HTTP to `/api/hook-request`. The WebSocket broadcast will trigger the modal.

### Downstream (depends on this)

| Story | Title | Why |
|-------|-------|-----|
| PROJ-14323 | Add severity classification to hook request flow | Needs the modal mounted to display severity UI (red borders for destructive) |
| PROJ-14324 | Wire grant persistence across all three scopes | Needs the modal to send `grantScope` in responses |

## Risks / Open Questions

1. **Grant scope options:** The current ApprovalModal UI only offers two choices via the "Always allow" checkbox: `once` (unchecked) or `always` (checked). The story description and architecture docs mention three scopes: `once`, `session`, and `always`. Should the modal be extended to offer `session` scope? This is likely PROJ-14323/14324 territory, but worth confirming. The existing component API (`onApprove(grantScope: GrantScope)`) already supports all three values.

2. **WebSocket lifecycle:** The `subscribeToPermissionRequests` function creates its own standalone WebSocket to `/ws/hooks`, separate from the ClaudeContext WebSocket (`/ws/claude`). This means there are two independent WebSocket connections from the renderer. This is by design (different endpoints, different concerns) but worth noting for debugging.

3. **Radix Dialog portal:** ApprovalModal renders via shadcn Dialog which uses Radix Portal. This means the DOM element renders outside the React tree. Tests should use `data-state` attributes, not `title` attributes (per Radix gotcha documented in MEMORY.md).

4. **Queue ordering:** FIFO is assumed. If a user is slow to respond, multiple requests can queue up. The hook script has a 2-minute timeout (`TIMEOUT_MS = 120000`), after which the server-side `pendingApprovals` entry resolves with `decision: "ask"`. If a queued request times out server-side before the user sees it, the modal will still appear but the response will be ignored (the pending promise is already resolved). Consider cleaning stale requests from the queue.

5. **Dismiss behavior:** When `onDismiss` is called (overlay click), the current implementation treats it as a rejection. This matches the non-blocking overlay design. Confirm this is the desired behavior vs. keeping the request in queue.

6. **No new test file needed for mounting:** The mounting itself is a wiring task. The existing 62 unit tests cover the component's internal behavior. E2E tests in `hook-request.e2e.ts` cover the WebSocket flow. A new integration test verifying the queue behavior in App.tsx may be warranted as part of the TDD workflow.
