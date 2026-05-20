# Story Context: PROJ-14323 - Add severity classification to hook request flow

## Summary

Integrate severity classification into the WheelHub hook request pipeline so that tool requests are classified as `safe`, `normal`, or `destructive` before being broadcast to WebSocket clients. This connects the existing `dangerous-path.ts` module (currently unused) and the existing `classifyActionSeverity` function (currently client-side only) into the server-side broadcast, and enhances the ApprovalModal with severity-aware visual treatment including contextual warnings.

## Current State

### Severity classification exists in two disconnected places

1. **`dangerous-path.ts`** (main process module, Story 22-4) -- Detects modifications to sensitive paths (secrets, git internals, dependencies, system paths). Exports `isDangerousPath()`, `getPathCategory()`, `interceptDangerousPath()`, and `extractBashTargetPaths()`. Uses `settings-store.ts` for gate/allowlist state. **Currently not imported or used by any other module** -- it is completely orphaned.

2. **`ApprovalModal/index.tsx`** (React component, Story PROJ-12713) -- Contains a client-side `classifyActionSeverity()` function that classifies Bash commands as `safe`/`normal`/`destructive` using regex patterns (e.g., `rm -rf` is destructive, `ls` is safe). Also exports `SEVERITY_CLASSNAMES` and `ActionSeverity` type. This classification is computed locally in the React component and is **not informed by the server**.

### Hook request flow has no severity awareness

The current flow in `hook-request.ts`:
1. Hook script POSTs to `/api/hook-request` with `{ toolName, toolId, input, context }`
2. WheelHub checks allowlist for auto-approval
3. If manual approval needed, broadcasts `{ type: 'hook-request', toolId, toolName, input, context }` to `/ws/hooks` clients
4. Client receives message, shows ApprovalModal -- severity is computed client-side only
5. Client sends `{ type: 'hook-response', toolId, approved }` back

The broadcast message does **not** include severity, path category, or contextual warnings. The `context` field currently only contains `{ percentage, isHigh, isCritical }` (context window usage), not tool severity.

### ApprovalModal visual treatment exists but is limited

The ApprovalModal already has severity-based CSS classes (`severity-destructive`, `severity-normal`, `severity-safe`) and applies visual treatment:
- Destructive: red text on title (`text-destructive`), red left border on preview (`border-l-destructive bg-destructive/10`)
- Normal: primary-colored left border
- Safe: green left border

However, there are no contextual warning messages (e.g., "This command modifies a secrets file") and no path-category-based classification.

## Target State

After implementation:

1. **Server-side severity classification in WheelHub** -- `hook-request.ts` classifies every tool request before broadcasting, combining:
   - Command-based classification (from `classifyActionSeverity` logic, moved/shared to server)
   - Path-based classification (from `dangerous-path.ts` integration)
   - Result: a `severity` field (`safe` | `normal` | `destructive`) and optional `warnings` array

2. **Enhanced WebSocket broadcast** -- The `hook-request` message includes severity metadata:
   ```typescript
   {
     type: 'hook-request',
     toolId: string,
     toolName: string,
     input: Record<string, unknown>,
     context?: { percentage, isHigh, isCritical },
     severity: 'safe' | 'normal' | 'destructive',
     warnings?: string[],       // e.g. ["Modifies secrets file: .env.production"]
     pathCategory?: string,     // e.g. "secrets", "git", "system"
   }
   ```

3. **ApprovalModal consumes server severity** -- The modal uses the server-provided `severity` and `warnings` instead of (or in addition to) client-side classification. Destructive actions show red border/accent. Warnings are displayed as contextual messages.

4. **Unified classification function** -- The `classifyActionSeverity` logic is either:
   - Extracted to a shared location (used by both server and client), or
   - Computed server-side only and passed to the client via the WebSocket message

## Key Files

### Must Modify

| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/src/api/hook-request.ts` | Add severity classification before `broadcastHookRequest()`. Import and call dangerous-path functions. Expand broadcast message type to include `severity`, `warnings`, `pathCategory`. |
| `pennyfarthing/packages/cyclist/src/dangerous-path.ts` | Currently orphaned. May need to export additional helpers or adjust the `interceptDangerousPath` function for the hook-request integration pattern (it currently expects a full message object and checks the gate). |
| `pennyfarthing/packages/cyclist/src/public/components/ApprovalModal/index.tsx` | Update `HookRequestMessage` interface to include `severity`, `warnings`, `pathCategory`. Update `subscribeToPermissionRequests` callback to pass severity data. Update component to display warnings and use server-provided severity. Extend `ApprovalRequest` type. |
| `pennyfarthing/packages/cyclist/src/public/components/ApprovalModal/ApprovalModal.css` | May need additional styles for warning messages display. |

### Must Read / Understand

| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/src/websocket.ts` | Understand hooks WebSocket setup (lines 419-421, 738-752). No changes expected -- hook broadcast goes through `hook-request.ts`. |
| `pennyfarthing/packages/cyclist/src/settings-store.ts` | Provides `getDangerousPathGate()`, `isPathAllowlisted()` used by dangerous-path.ts. Understand the gate toggle mechanism. |
| `pennyfarthing/packages/cyclist/src/approval-gate.ts` | Understand the existing `interceptToolUse` pattern (Story 33-3). This story's classification complements but does not replace approval-gate logic. |
| `pennyfarthing/packages/cyclist/src/server.ts` | Hook-request router mounted at line 117: `app.use('/api/hook-request', createHookRequestRouter())`. |
| `pennyfarthing/packages/cyclist/src/public/utils/toolIntentSummarizer.ts` | Understand the existing tool-intent summarization pattern. Warnings could follow a similar summarization approach. |
| `pennyfarthing/packages/cyclist/e2e/hook-request.e2e.ts` | Existing E2E tests for hook-request flow. Tests verify broadcast message shape -- will need updates to assert `severity` field. |
| `pennyfarthing/packages/cyclist/tests/PROJ-12713-approval-modal.test.ts` | Existing unit tests for ApprovalModal including severity classification tests. |
| `pennyfarthing/pennyfarthing_scripts/pretooluse_hook.py` | Python hook script that POSTs to `/api/hook-request`. No changes expected -- severity is computed server-side, not in the hook script. |

### New Files (TDD workflow)

| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/tests/PROJ-14323-severity-classification.test.ts` | Unit tests for server-side severity classification logic. |

## Technical Approach

### 1. Extract/share severity classification logic

The `classifyActionSeverity` function currently lives in `ApprovalModal/index.tsx` (a React component file). For server-side use in `hook-request.ts`, this logic needs to be accessible from Node.js code. Options:

- **Option A (recommended):** Create a shared classification function in `hook-request.ts` (or a new `severity.ts` module) that combines the existing `classifyActionSeverity` command patterns with `dangerous-path.ts` path-based detection. The client can then use the server-provided severity.
- **Option B:** Move `classifyActionSeverity` to a shared utility file importable by both server and client code.

### 2. Integrate dangerous-path.ts into hook-request.ts

In `handleHookRequest()`, after the allowlist check and before broadcasting:

```typescript
import { isDangerousPath, getPathCategory, extractBashTargetPaths } from '../dangerous-path.js';

// In handleHookRequest, compute severity:
const severity = classifySeverity(toolName, input);
const warnings = generateWarnings(toolName, input);
const pathCategory = detectPathCategory(toolName, input);

// Broadcast with severity
broadcastHookRequest({
  type: 'hook-request',
  toolId,
  toolName,
  input: input || {},
  context,
  severity,
  warnings,
  pathCategory,
});
```

The `classifySeverity` function would:
1. Check command patterns (for Bash: destructive commands like `rm -rf`, `git reset --hard`)
2. Check path patterns (for Write/Edit: dangerous paths via `isDangerousPath()`)
3. Check bash redirect targets (via `extractBashTargetPaths()`)
4. Return the highest severity found

### 3. Generate contextual warnings

Create a `generateWarnings()` function that produces human-readable warning strings:
- `"Modifies secrets file: .env.production"` (when path category is 'secrets')
- `"Modifies git internals: .git/config"` (when path category is 'git')
- `"Destructive command: rm -rf"` (when command pattern is destructive)
- `"Modifies system path: /etc/hosts"` (when path category is 'system')

### 4. Update WebSocket broadcast types

Expand the `broadcastHookRequest` data parameter and the client-side `HookRequestMessage` interface to include the new fields.

### 5. Update ApprovalModal to consume server severity

- Update `HookRequestMessage` to include `severity`, `warnings`, `pathCategory`
- Pass severity data through `subscribeToPermissionRequests` callback into `ApprovalRequest`
- Display warnings in the modal (below the command preview, above the action buttons)
- Use server-provided severity for visual treatment (fall back to client-side classification if not present for backwards compatibility)

### 6. Visual treatment for destructive actions

The ApprovalModal already has severity-based styling. Enhancements for this story:
- Display warning messages as a list below the command preview
- Red border on the entire dialog content (not just the preview) for destructive severity
- Path category badge/label (e.g., "secrets", "system") if applicable

## Acceptance Criteria

1. **AC1:** Tool requests are classified with a `severity` field (`safe` | `normal` | `destructive`) in WheelHub before WebSocket broadcast
2. **AC2:** `dangerous-path.ts` path-based classification is integrated -- Write/Edit to `.env`, `.git/`, `node_modules/`, system paths results in `destructive` severity
3. **AC3:** Bash commands with destructive patterns (`rm -rf`, `git reset --hard`, `git push --force`, `git clean -fd`) result in `destructive` severity
4. **AC4:** Read-only commands (`ls`, `cat`, `git status`, `git log`) result in `safe` severity
5. **AC5:** WebSocket broadcast message includes `severity` field and optional `warnings` array with human-readable context
6. **AC6:** ApprovalModal displays contextual warnings from server (e.g., "Modifies secrets file: .env")
7. **AC7:** Destructive actions show red border treatment on ApprovalModal (already partially implemented -- verify integration with server-provided severity)
8. **AC8:** Classification is backwards-compatible -- if severity is not present in broadcast (e.g., older hook scripts), client falls back to local classification

## Dependencies

- **PROJ-14318** (Remove legacy IPC approval path) -- **DONE**. Clears out the old IPC path so only WheelHub flow remains.
- **PROJ-14322** (Mount ApprovalModal in React component tree) -- This story depends on PROJ-14322 being complete (or at least the ApprovalModal being mounted and receiving WebSocket messages). If PROJ-14322 is not done, this story's server-side work can proceed independently, but the visual treatment AC6/AC7 cannot be fully verified without the modal being mounted.
- **PROJ-14321** (Integrate grant checking into WheelHub) -- Partially dependent. Grant checking happens before severity classification in the flow (auto-approved requests don't need classification). Severity classification should run after grant checks fail (i.e., when manual approval is needed).

## Risks / Open Questions

1. **Where to put the shared classification function?** The `classifyActionSeverity` function in ApprovalModal duplicates some logic that will also exist server-side. Should this be a shared module (e.g., `src/severity.ts`) imported by both, or should the client simply consume the server-provided severity and the client-side function becomes a fallback? Recommendation: server-side is authoritative, client-side is fallback for backwards compatibility.

2. **dangerous-path.ts gate mechanism.** The `interceptDangerousPath` function checks `getDangerousPathGate()` before doing any work. Should severity classification also respect this gate, or should classification always run (even when the gate is off, for informational purposes)? Recommendation: classification should always run; the gate only controls whether path-based operations are *blocked*, not whether they are *classified*.

3. **Performance of path classification.** The `DANGEROUS_PATH_PATTERNS` array has 20+ regex patterns tested against every Write/Edit/Bash tool use. This runs synchronously in the HTTP handler. For typical usage this is negligible, but worth noting.

4. **No existing tests for dangerous-path.ts.** Despite being implemented in Story 22-4, there are no unit tests for `dangerous-path.ts`. The TDD approach for this story should include tests for the classification integration, which will indirectly test dangerous-path functions.

5. **Bash redirect extraction completeness.** The `extractBashTargetPaths` function handles `>`, `>>`, and `tee` patterns, but complex shell constructs (heredocs, process substitution, multi-line commands) may not be fully covered. This is an existing limitation, not introduced by this story.

6. **Warning message design.** The exact UX for displaying warnings in ApprovalModal needs design consideration. A simple bulleted list below the preview is the minimum. Should warnings have different visual treatment by path category?
