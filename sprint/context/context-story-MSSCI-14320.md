# Story Context: MSSCI-14320 - Update and register PreToolUse hook

## Summary

Update `cyclist-pretooluse-hook.js` to POST to `/api/hook-request` instead of the old `/approval-request` endpoint, register it in `.claude/settings.local.json` under `hooks.PreToolUse`, and change the fallback behavior when WheelHub is unreachable from `allow` to `ask` (defer to Claude Code's built-in permission dialog).

## Current State

### Hook Script (`cyclist-pretooluse-hook.js`)

The hook script exists at `packages/cyclist/src/hooks/cyclist-pretooluse-hook.js` and is fully functional, but has two issues:

1. **Wrong endpoint:** Line 121 POSTs to `/approval-request` (the legacy endpoint removed in MSSCI-14318). It should POST to `/api/hook-request` which is already mounted and working on WheelHub (`server.ts` line 117).

2. **Wrong fallback on unreachable:** Lines 143-148 handle `ECONNREFUSED` by returning `{ decision: "allow" }`. This silently approves all tool uses when Cyclist is not running. The Python equivalent (`pretooluse_hook.py`) correctly returns `ask` in this case, deferring to Claude Code's built-in approval dialog.

3. **Wrong port file:** The script reads `.cyclist-approval-port` (line 38, `APPROVAL_PORT_FILE`), which is the legacy port file. The canonical port file is `.cyclist-port` (used by WheelHub and the Python hooks). The legacy file is still written by `writeApprovalPortFile` in `server.ts` but is deprecated.

### Hook Registration

The hook is **not registered** in `.claude/settings.local.json`. The existing `PreToolUse` hooks (lines 93-121) are:

- `pre-edit-check.sh` (matcher: `Edit|Write`) -- protects sensitive files
- `context-warning.sh` (matcher: `Edit|Write|Bash|Task`) -- context usage warning
- `context-circuit-breaker.sh` (matcher: `Edit|Write|Bash|Task`) -- context circuit breaker

The cyclist pretooluse hook is absent. This is specifically called out as one of the three breaks in the epic context (`context-epic-78.md`): "Hook not registered: cyclist-pretooluse-hook.js exists but isn't listed in .claude/settings.local.json PreToolUse hooks".

### Python Hook (Reference Implementation)

The Python version at `pennyfarthing_scripts/pretooluse_hook.py` is already correctly implemented:
- POSTs to `/api/hook-request` (line 96)
- Reads `.cyclist-port` via `hooks.py:get_cyclist_port()` (which falls back to `.cyclist-approval-port` for migration)
- Returns `ask` when WheelHub is unreachable (lines 111-118)
- Includes context percentage in the request (lines 102-106)

This serves as the reference for what the JS hook should look like.

### WheelHub Server-Side

`src/api/hook-request.ts` is fully mounted and functional:
- Mounted at `/api/hook-request` in `server.ts` line 117
- WebSocket at `/ws/hooks` registered in `websocket.ts` lines 419-420, 488-491, 738-752
- Handles auto-approval for safe commands via allowlist (lines 68-84)
- Falls back to `ask` when no WebSocket clients are connected (lines 188-194)
- Broadcasts to WebSocket clients for manual approval (lines 218-228)
- 2-minute timeout with `ask` fallback (lines 206-214)

## Target State

After implementation:

1. **`cyclist-pretooluse-hook.js`** POSTs to `/api/hook-request` (not `/approval-request`)
2. **`cyclist-pretooluse-hook.js`** reads `.cyclist-port` (not `.cyclist-approval-port`), with fallback to `.cyclist-approval-port` for migration
3. **`cyclist-pretooluse-hook.js`** returns `{ decision: "ask" }` when WheelHub is unreachable (not `allow`)
4. **`.claude/settings.local.json`** includes the hook registered under `hooks.PreToolUse`
5. The hook registration should use a broad matcher (e.g., empty string or omitted) to intercept all tool uses, or use `Bash` to match the primary use case -- the existing pattern in the codebase and the epic context suggests it should cover at minimum `Bash` tools

## Key Files

### Files to Modify

| File | Location | What Changes |
|------|----------|--------------|
| `cyclist-pretooluse-hook.js` | `pennyfarthing/packages/cyclist/src/hooks/cyclist-pretooluse-hook.js` | Change POST path from `/approval-request` to `/api/hook-request`; change port file from `.cyclist-approval-port` to `.cyclist-port` with legacy fallback; change ECONNREFUSED handler from `allow` to `ask`; update doc comments |
| `settings.local.json` | `.claude/settings.local.json` | Add PreToolUse hook entry pointing to the cyclist hook script |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `hook-request.ts` | `pennyfarthing/packages/cyclist/src/api/hook-request.ts` | Server-side handler -- understand request/response contract |
| `hook-request.e2e.ts` | `pennyfarthing/packages/cyclist/e2e/hook-request.e2e.ts` | E2E tests -- understand expected API behavior |
| `pretooluse_hook.py` | `pennyfarthing/pennyfarthing_scripts/pretooluse_hook.py` | Python reference implementation (already correct) |
| `hooks.py` | `pennyfarthing/pennyfarthing_scripts/hooks.py` | Shared hook utilities -- port discovery, settings, context state |
| `server.ts` | `pennyfarthing/packages/cyclist/src/server.ts` | WheelHub setup -- port file write, route mounting |
| `websocket.ts` | `pennyfarthing/packages/cyclist/src/websocket.ts` | WebSocket wiring for `/ws/hooks` |
| `hooks.md` | `pennyfarthing/pennyfarthing-dist/guides/hooks.md` | Hook configuration schema documentation |
| `approval-gate.ts` | `pennyfarthing/packages/cyclist/src/approval-gate.ts` | Post-cleanup state (generic interceptToolUse only) |
| `settings-store.ts` | `pennyfarthing/packages/cyclist/src/settings-store.ts` | Grant checking (used by subsequent story MSSCI-14321) |
| `preload.ts` | `pennyfarthing/packages/cyclist/src/preload.ts` | Contains orphaned IPC channels from legacy system (reviewer note from MSSCI-14318) |

## Technical Approach

### 1. Update `cyclist-pretooluse-hook.js`

**Change the POST path** (line 121):
```javascript
// Before:
path: '/approval-request',
// After:
path: '/api/hook-request',
```

**Change the port file constant** (line 38):
```javascript
// Before:
const APPROVAL_PORT_FILE = '.cyclist-approval-port';
// After:
const PORT_FILE = '.cyclist-port';
const LEGACY_PORT_FILE = '.cyclist-approval-port'; // migration fallback
```

Update `getApprovalPort()` (lines 67-89) to first try `.cyclist-port`, then fall back to `.cyclist-approval-port`, mirroring `hooks.py:get_cyclist_port()` which does exactly this (lines 130-139).

**Change ECONNREFUSED handler** (lines 143-148):
```javascript
// Before:
if (e.code === 'ECONNREFUSED') {
  resolve({ decision: 'allow', reason: 'Cyclist approval server not running' });
}
// After:
if (e.code === 'ECONNREFUSED') {
  resolve({ decision: 'ask', reason: 'WheelHub not running, deferring to Claude Code' });
}
```

**Update error handler** (lines 222-227): Consider changing the catch-all error handler to also output `ask` instead of silently exiting with code 0. Currently it exits 0 with no stdout, which causes Claude Code to proceed (implicit allow). Better to explicitly output `ask`.

**Update doc comments**: Update the header comment block (lines 2-28) to reference `/api/hook-request`, `.cyclist-port`, and WheelHub terminology.

### 2. Register hook in `.claude/settings.local.json`

Add a new entry to the `hooks.PreToolUse` array. Following the pattern from the hooks guide and the hook's own doc comments:

```json
{
  "matcher": "",
  "hooks": [
    {
      "type": "command",
      "command": "node \"$CLAUDE_PROJECT_DIR\"/pennyfarthing/packages/cyclist/src/hooks/cyclist-pretooluse-hook.js"
    }
  ]
}
```

**Matcher considerations:**
- Empty string `""` or omitted matcher means it runs on ALL tool uses (broadest)
- `"Bash"` would only intercept Bash commands
- The architecture document and epic context show the full permission system is meant to handle any tool, not just Bash
- The existing hook script already handles any tool_name (lines 192-200 extract tool_name generically)
- Start with empty/broad matcher per the epic's design intent; subsequent stories (MSSCI-14321) will add grant-based auto-approval to prevent UI overhead

**Path considerations:**
- This orchestrator repo has `pennyfarthing/` inlined, so the path from project root is `pennyfarthing/packages/cyclist/src/hooks/cyclist-pretooluse-hook.js`
- Must use `$CLAUDE_PROJECT_DIR` variable per existing pattern in settings.local.json
- In a non-development (published) context, the hook would be at a different path; for this orchestrator it's at the inlined location

### 3. Testing

**Unit/integration tests for the hook script:**
- Test that the script POSTs to `/api/hook-request` (verify URL in request options)
- Test ECONNREFUSED returns `{ decision: "ask" }` not `allow`
- Test port file discovery: `.cyclist-port` preferred over `.cyclist-approval-port`
- Test graceful fallback when no port file exists

**E2E tests already exist:**
- `pennyfarthing/packages/cyclist/e2e/hook-request.e2e.ts` tests the server-side `/api/hook-request` endpoint and WebSocket flow
- These tests validate the server behavior and should pass unchanged

**Manual verification:**
- Start Cyclist, confirm `.cyclist-port` is written
- Run the hook script manually with piped JSON to verify it connects to WheelHub
- Stop Cyclist, run hook script, verify `ask` response (not `allow`)

## Acceptance Criteria

- `cyclist-pretooluse-hook.js` POSTs to `/api/hook-request` (not `/approval-request`)
- Hook is registered in `.claude/settings.local.json` under `hooks.PreToolUse`
- When WheelHub is unreachable (ECONNREFUSED), hook returns `{ decision: "ask" }` to defer to Claude Code
- When WheelHub is running and no WebSocket clients are connected, server returns `{ decision: "ask" }`
- Existing E2E tests in `hook-request.e2e.ts` continue to pass
- Port file discovery uses `.cyclist-port` with `.cyclist-approval-port` fallback

## Dependencies

### Depends On

- **MSSCI-14318** (Remove legacy IPC approval path) -- **DONE**. The old `/approval-request` endpoint has been removed from `main.ts`. This story updates the hook to use the new endpoint.

### Depended On By

- **MSSCI-14321** (Integrate grant checking into WheelHub hook router) -- needs the hook to be posting to `/api/hook-request` so grants can be checked server-side
- **MSSCI-14322** (Mount ApprovalModal in React component tree) -- needs the hook registered so approval requests actually arrive at the WebSocket for the modal to display
- All subsequent stories in Epic 78 depend on this hook being correctly wired up

## Risks / Open Questions

1. **Port file migration timing:** The `.cyclist-approval-port` file is still written by `writeApprovalPortFile` in `server.ts` (lines 345-347) but these functions were flagged as orphaned by the MSSCI-14318 reviewer. Should this story also clean up those orphaned port file functions, or leave that for a follow-up? The conservative approach is to keep the legacy fallback in the hook and clean up server-side port file writing in a separate chore.

2. **Hook path portability:** The hook path in `settings.local.json` currently points to the inlined framework source (`pennyfarthing/packages/cyclist/src/hooks/cyclist-pretooluse-hook.js`). In a published/installed context, the path would differ. For this orchestrator repo (the primary consumer), the inlined path is correct. The `init` CLI command would need to handle this for other consumers.

3. **Matcher scope:** Using an empty matcher means the hook runs on every tool use (Read, Grep, Glob, Edit, Write, Bash, Task, etc.). This adds latency to all tool calls. However, since WheelHub auto-approves safe tools via the allowlist in `hook-request.ts`, the actual user-facing delay should be minimal. The alternative is `"Bash|Edit|Write"` but that limits the permission system's reach.

4. **Dead IPC channels in preload.ts:** The MSSCI-14318 reviewer noted orphaned IPC channels (`bash:approval-request`, `path:approval-request`, `permission:request`) at lines 699-719 of `preload.ts`. These are dead code but don't affect this story's scope. Consider a follow-up cleanup chore.

5. **Context info not included in JS hook:** The Python hook includes context percentage (used/high/critical) in the request to WheelHub. The JS hook does not. The JS hook could be enhanced to read context state, but this may be better addressed in MSSCI-14323 (severity classification). For now, the JS hook sends what it has and WheelHub works fine without context info.
