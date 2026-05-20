# Story Context: PROJ-14324 - Wire grant persistence across all three scopes

## Summary

Connect the existing grant lifecycle machinery (once/session/always) end-to-end so that once-grants auto-revoke after a single check, session-grants clear when the Cyclist session ends, and always-grants persist to `~/.cyclist/grants.json` and reload on startup. Wire glob pattern matching from `settings-store.ts` into the WheelHub hook-request router so approved grants actually auto-approve subsequent matching tool invocations.

## Current State

### What exists and works

1. **Grant data model** -- `PermissionGrant` interface is defined identically in three places:
   - `packages/core/src/permissions/permission-schema.ts` (canonical schema, includes `uses_remaining`)
   - `packages/cyclist/src/settings-store.ts` (runtime in-memory store, Story 33-4)
   - `packages/cyclist/src/settings.ts` (file I/O, includes `GrantType` const, `validateGrant`, `loadGrants`, `saveGrants`)

2. **In-memory grant store** (`settings-store.ts`):
   - Two arrays: `sessionGrants` (once + session) and `persistedGrants` (always)
   - `addGrant()` routes to the correct array by `grant_type`
   - `checkGrant()` looks up both arrays with tool-specific matching (glob for Bash, domain for WebFetch, path for Edit/Write/Read), auto-revokes once-grants via `splice`
   - `clearSessionGrants()` exists but is **never called** anywhere in the codebase
   - `clearAllGrants()` exists but is also never called outside settings-store itself

3. **File persistence** (`settings.ts`):
   - `GRANTS_FILE = ~/.cyclist/grants.json` -- cross-project grant storage
   - `loadGrants()` reads the file, filters to only `always` type, validates each grant
   - `saveGrants()` writes only `always` grants to file
   - `ensureSettingsDir()` creates `~/.cyclist/` if missing

4. **Startup wiring** (`main.ts` line ~796-810, `initializeApp()`):
   - Calls `initializeSettings()`, then `loadGrants()`, then `initializeGrants()`, then `setGrantsPersistCallback(saveGrants)`
   - This means always-grants load from disk and the persist callback is registered

5. **Approval gate** (`approval-gate.ts`):
   - `interceptToolUse()` calls `checkGrant()` from settings-store -- if a grant matches, `shouldApprove` stays false (no approval needed)
   - But `interceptToolUse()` is **not imported or used by hook-request.ts** (the WheelHub handler)

6. **WheelHub hook-request router** (`api/hook-request.ts`):
   - Receives `POST /api/hook-request` from PreToolUse hook scripts
   - Has its own hardcoded `SAFE_COMMAND_PATTERNS` allowlist for auto-approval
   - Does **NOT** call `checkGrant()` or `addGrant()` from settings-store
   - `resolveApproval()` receives `data` payload (which contains `grantScope`) but does **nothing** with it -- just resolves the HTTP response

7. **ApprovalModal** (`public/components/ApprovalModal/index.tsx`):
   - Sends `grantScope` in WebSocket `hook-response` message via `data.grantScope`
   - Currently only offers "once" (default) or "always" (via checkbox) -- no explicit "session" option

8. **Glob pattern matching** (`settings-store.ts`):
   - `matchGlobPattern()` -- private function, converts `*` to `.*` regex
   - `extractPattern()` -- takes first word of command, appends ` *` (e.g., `npm test` -> `npm *`)
   - `matchDomainPattern()` -- handles `*.github.com` style patterns for URLs
   - `matchPathPattern()` -- same glob logic for file paths
   - All three are already used by `checkGrant()` based on tool type

### Gaps (what this story must fix)

| Gap | Description |
|-----|-------------|
| **G1** | `hook-request.ts` does not call `checkGrant()` -- so grants are never consulted during hook processing |
| **G2** | `hook-request.ts` does not call `addGrant()` when user approves with a grantScope -- so grants are never created from approvals |
| **G3** | `clearSessionGrants()` is exported but never called -- session grants persist forever (they're just in-memory so they clear on app restart, but not on explicit session clear) |
| **G4** | Session clear paths (`clearSession`, `clearSessionAsync`, `setClaudeClearCallback`) do not invoke `clearSessionGrants()` |
| **G5** | `before-quit` handler does not call `clearSessionGrants()` |
| **G6** | ApprovalModal only offers "once" or "always" -- no "session" scope option for users |
| **G7** | No integration tests for the full grant lifecycle (create via approval -> check on next request -> revoke/expire) |

## Target State

After this story:

1. **Hook-request checks grants**: When `POST /api/hook-request` arrives, call `checkGrant(toolName, command/scope)` before broadcasting to WebSocket. If grant matches, return `{ decision: "allow" }` immediately.

2. **Hook-request creates grants**: When `resolveApproval()` receives a user approval with `grantScope`, call `addGrant()` with the appropriate tool, scope (extracted via `extractPattern()`), and grant_type. The `addGrant()` function already handles routing to the correct store and persisting always-grants via callback.

3. **Once-grants auto-revoke**: Already implemented in `checkGrant()` -- the `splice` removes the grant after it matches. Just needs to be called from hook-request.

4. **Session grants clear on session end**: `clearSessionGrants()` is called from:
   - `clearSession()` / `clearSessionAsync()` in main.ts clear callbacks
   - `before-quit` handler
   - WebSocket `setClaudeClearCallback`

5. **Always-grants persist**: Already works via `setGrantsPersistCallback(saveGrants)` in `initializeApp()`. Just needs grants to actually be created (G2 fix).

6. **Glob matching works end-to-end**: Already implemented in `matchGlobPattern()`. Once hook-request calls `checkGrant()`, patterns like `npm *` will match `npm test`, `npm run build`, etc.

## Key Files

### Primary (must change)

| File | Path | Purpose |
|------|------|---------|
| `hook-request.ts` | `pennyfarthing/packages/cyclist/src/api/hook-request.ts` | Wire grant checking + creation into WheelHub handler |
| `main.ts` | `pennyfarthing/packages/cyclist/src/main.ts` | Add `clearSessionGrants()` calls to session lifecycle |
| `websocket.ts` | `pennyfarthing/packages/cyclist/src/websocket.ts` | May need session-end grant clearing if WebSocket manages session |

### Secondary (may need minor changes)

| File | Path | Purpose |
|------|------|---------|
| `settings-store.ts` | `pennyfarthing/packages/cyclist/src/settings-store.ts` | Already has all grant CRUD -- may need minor adjustments |
| `ApprovalModal/index.tsx` | `pennyfarthing/packages/cyclist/src/public/components/ApprovalModal/index.tsx` | Add "session" scope option (currently only once/always) |
| `approval-gate.ts` | `pennyfarthing/packages/cyclist/src/approval-gate.ts` | Already calls `checkGrant()` -- may be superseded by hook-request integration |

### Reference (read-only, for understanding)

| File | Path | Purpose |
|------|------|---------|
| `settings.ts` | `pennyfarthing/packages/cyclist/src/settings.ts` | `loadGrants()`, `saveGrants()`, `GRANTS_FILE` location |
| `permission-schema.ts` | `pennyfarthing/packages/core/src/permissions/permission-schema.ts` | Canonical grant types and validation |
| `permission-schema.test.ts` | `pennyfarthing/packages/core/src/permissions/permission-schema.test.ts` | Tests for grant creation (33-1) |
| `workflow-permissions.ts` | `pennyfarthing/packages/core/src/workflow/workflow-permissions.ts` | Workflow permission preset checking |
| `settings.local.json` | `.claude/settings.local.json` | Claude Code settings -- hooks registered here |
| `context-epic-78.md` | `sprint/context/context-epic-78.md` | Epic context with architecture diagram |

### Test files

| File | Path | Purpose |
|------|------|---------|
| `PROJ-12713-approval-modal.test.ts` | `pennyfarthing/packages/cyclist/tests/PROJ-12713-approval-modal.test.ts` | Existing ApprovalModal tests (62 tests, must continue passing) |

## Technical Approach

### 1. Wire grant checking into hook-request.ts (G1)

Import `checkGrant` and `isAllowlisted` from `settings-store.ts`. In `handleHookRequest()`, after the hardcoded safe-pattern check, add:

```typescript
import { checkGrant, addGrant, extractPattern, type PermissionGrant } from '../settings-store.js';

// In handleHookRequest, after existing allowlist check:
const scope = toolName === 'Bash' ? (input?.command as string || '') : getToolScope(toolName, input);
if (checkGrant(toolName, scope)) {
  res.json({ decision: 'allow', reason: 'Matches cached grant' });
  return;
}
```

The `getToolScope()` helper from `approval-gate.ts` extracts the right scope field per tool type (command for Bash, url for WebFetch, file_path for Edit/Write/Read). Consider extracting this to a shared utility or importing from approval-gate.

### 2. Wire grant creation into resolveApproval (G2)

When user approves with a `grantScope`, create and store the grant:

```typescript
export function resolveApproval(toolId, approved, data) {
  const pending = pendingApprovals.get(toolId);
  if (!pending) return false;

  // Create grant if approved with a scope
  if (approved && data?.grantScope) {
    const scope = extractScopeForGrant(pending.toolName, pending.input);
    addGrant({
      tool: pending.toolName,
      scope,
      grant_type: data.grantScope as GrantTypeValue,
      granted_at: new Date().toISOString(),
    });
  }

  pending.resolve({ ... });
  pendingApprovals.delete(toolId);
  return true;
}
```

The scope extraction for Bash should use `extractPattern()` (e.g., `npm test` -> `npm *`) so that the grant covers the whole command family. For other tools, use the specific input field (url, file_path, etc.).

### 3. Wire session grant clearing (G3, G4, G5)

In `main.ts`, add `clearSessionGrants()` calls to all session-end paths:

- **`setClaudeClearCallback`** (line ~1070): Add `clearSessionGrants()` after other reset calls
- **`setClaudeClearAndReloadCallback`** (line ~1115): Add `clearSessionGrants()` after other reset calls
- **`before-quit`** handler (line ~2352): Add `clearSessionGrants()` before stopping server

Import `clearSessionGrants` from `settings-store.ts` (already partially imported).

### 4. Add "session" scope to ApprovalModal (G6)

The ApprovalModal currently has a single "Always allow" checkbox that toggles between `once` and `always`. Options:

**Option A (minimal):** Add a dropdown/radio group: "This time only" (once), "For this session" (session), "Always" (always).

**Option B (progressive):** Keep the simple approve button (defaults to `once`), add a split-button dropdown for "Session" and "Always" options.

The `grantScope` is already threaded through the entire WebSocket protocol (`hook-response.data.grantScope`), so only the UI needs updating.

### 5. Tests (G7)

Create integration-style tests covering:

- Grant created when user approves with `grantScope: 'session'`
- Subsequent matching tool call auto-approved via `checkGrant()`
- Once-grant disappears after single check
- Session grants cleared on `clearSessionGrants()`
- Always-grants survive `clearSessionGrants()` but still match
- Glob pattern `npm *` matches `npm test`, `npm run build`, etc.
- Domain pattern `*.github.com` matches `api.github.com`

## Acceptance Criteria

From the story description and epic context:

1. **Once grants auto-revoke after single use** -- `checkGrant()` already does this via splice; needs to be called from hook-request
2. **Session grants clear on session end** -- `clearSessionGrants()` must be called from all session-end paths
3. **Always grants persist to disk** -- `addGrant()` with `always` type already triggers `saveGrants()` callback; needs grants to actually be created from approvals
4. **Always grants loaded on startup** -- Already works via `initializeApp()` -> `loadGrants()` -> `initializeGrants()`
5. **Glob pattern matching works** -- `npm *` matches `npm test` etc.; already implemented in `matchGlobPattern()`, needs to be exercised from hook-request

## Dependencies

| Dependency | Status | Notes |
|-----------|--------|-------|
| PROJ-14318 (78-1): Remove legacy IPC approval path | Completed | Old approval IPC removed |
| PROJ-14320 (78-2): Update and register PreToolUse hook | Must be done or in progress | Hook must POST to `/api/hook-request` |
| PROJ-14321 (78-3): Integrate grant checking into WheelHub | Overlaps with this story | This story's G1/G2 are exactly 78-3's scope |
| PROJ-14322 (78-4): Mount ApprovalModal in React tree | Must be done or in progress | Modal must be rendering for user to approve |

**Note:** The epic lists 78-6 (this story) as depending on 78-3 and 78-4. However, 78-3 ("Integrate grant checking into WheelHub hook router") has significant overlap with this story's G1 and G2 work. If 78-3 is completed first, much of the hook-request wiring will already be done and this story focuses on lifecycle (session clear, always reload) and pattern matching verification. If 78-3 is still in backlog, this story subsumes that work.

## Risks / Open Questions

1. **Scope extraction strategy for grants**: When creating a grant from an approved Bash command `npm test`, should the scope be the literal command (`npm test`) or the extracted pattern (`npm *`)? The `extractPattern()` function exists and creates `npm *`, but this is aggressive -- it means approving `npm test` also approves `npm install`, `npm audit`, etc. The story description says "e.g. npm * matches npm test" suggesting the pattern approach is intended, but this should be confirmed.

2. **Grant file location mismatch**: The epic context says always-grants persist to `.claude/settings.local.json`, but the actual implementation uses `~/.cyclist/grants.json` (a separate cross-project file). The `.claude/settings.local.json` file contains Claude Code's own permission allowlist (different format: `Bash(*)`, `Read`, etc.). These are separate systems. The current `grants.json` approach avoids conflict with Claude Code's settings format but differs from the epic's stated location.

3. **ApprovalModal "session" UI**: The current modal only has once/always via a checkbox. Adding a three-way selector (once/session/always) requires a UI decision. A radio group or segmented control would work but changes the approval UX flow. This could be deferred to a follow-up if the story scope is tight.

4. **No existing grant tests in Cyclist**: The `settings-store.ts` grant functions have no dedicated test file. The `permission-schema.test.ts` in `packages/core` tests the schema/validation but not the runtime store. New tests should be created alongside the wiring changes.

5. **Race condition on concurrent approvals**: If two tool calls arrive simultaneously and the user approves both with "session" scope, two grants may be created with slightly different scope patterns. The `addGrant()` function deduplicates by tool+scope, so this should be safe, but needs verification.

6. **`before-quit` cleanup timing**: The `before-quit` handler calls `claudeServiceInstance.abort()` and `stopServer()`. Adding `clearSessionGrants()` here is logically correct but technically unnecessary since session grants are in-memory and the process is exiting. It matters only for correctness in testing or if the app supports "quit but keep process" scenarios.
