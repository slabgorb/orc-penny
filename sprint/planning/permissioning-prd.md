---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-03-success
  - step-04-journeys
  - step-05-domain (skipped)
  - step-06-innovation (skipped)
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
inputDocuments:
  - pennyfarthing/packages/cyclist/src/approval-gate.ts
  - pennyfarthing/packages/cyclist/src/api/hook-request.ts
  - pennyfarthing/packages/cyclist/src/dangerous-path.ts
  - pennyfarthing/packages/cyclist/src/settings-store.ts
  - pennyfarthing/packages/cyclist/src/public/components/ApprovalModal/index.tsx
  - pennyfarthing/pennyfarthing-dist/guides/permission-protocol.md
  - pennyfarthing/pennyfarthing-dist/skills/permissions/skill.md
  - pennyfarthing/packages/core/src/permissions/permission-schema.ts
  - pennyfarthing/packages/core/src/workflow/workflow-permissions.ts
  - sprint/context/PROJ-11705-context.md
workflowType: 'prd'
documentCounts:
  briefCount: 0
  researchCount: 0
  brainstormingCount: 0
  projectDocsCount: 10
classification:
  projectType: Developer Tooling / IDE Extension
  domain: Developer Experience (DX) / Agent Infrastructure
  complexity: High
  projectContext: brownfield
---

# Product Requirements Document - Cyclist Permission System

**Author:** Keith Avery
**Date:** 2026-02-05

## Success Criteria

### User Success

- **Zero blocked sessions**: When Claude Code requests permission for any tool, Cyclist presents an approval modal within 1 second. The user can approve or deny. Work continues immediately. No session ever blocks with no way to respond.
- **Permission memory**: Permanent grants persist across sessions. If a user grants "always allow `npm test`", it is never asked again until explicitly revoked.
- **Dangerous actions are possible**: Users can explicitly approve destructive operations (force push, file deletion, system path edits) through the same modal with clear severity indication. The system warns but does not block.
- **Single interaction point**: All permission decisions happen in Cyclist UI. Users never need to context-switch to the terminal to answer Claude Code's built-in prompts.

### Business Success

- **Unblocks agent autonomy**: Agents running multi-step workflows (TDD, architecture) can complete without human intervention for pre-approved tool categories.
- **Reduces session restart rate**: Permission-blocked sessions that require restart drop to zero.
- **Enables advanced workflows**: Story 33-5 (workflow permission presets) becomes possible, allowing workflows to declare required permissions upfront.

### Technical Success

- **Single approval architecture**: One system (WebSocket/WheelHub), not two competing paths. The old Electron IPC approval path is removed.
- **Hook integration**: `cyclist-pretooluse-hook.js` is registered in Claude Code settings and successfully intercepts tool_use events.
- **End-to-end latency < 500ms**: From hook interception to modal display, measured by WheelHub round-trip.
- **Grant persistence**: `once` grants expire after single use, `session` grants clear on session end, `always` grants persist in `.claude/settings.local.json`.
- **62/62 existing tests pass**: No regression in ApprovalModal test suite.

### Measurable Outcomes

| Metric | Target | Measurement |
|--------|--------|-------------|
| Permission-blocked sessions | 0 per week | Manual tracking |
| Hook → Modal latency | < 500ms | WheelHub timing logs |
| Grant types working | 3/3 (once, session, always) | Integration test |
| Agent preset declarations | Functional for all workflows | Workflow startup test |
| Existing test regression | 0 failures | CI |

## Product Scope

### MVP - Minimum Viable Product

1. **Wire the hook**: Register `cyclist-pretooluse-hook.js` in `.claude/settings.local.json` PreToolUse hooks
2. **Unify on WebSocket path**: Hook script POSTs to `/api/hook-request` (WheelHub), not `/approval-request` (old IPC)
3. **Mount ApprovalModal**: Import and render in App.tsx component tree, connect WebSocket subscription
4. **Three grant scopes working**: Once, Session, Always - with proper persistence
5. **Dangerous action support**: Severity classification in modal (safe/normal/destructive) with user override capability

### Growth Features (Post-MVP)

1. **Agent permission presets** (Story 33-5): Workflows declare required permissions, auto-granted on agent activation
2. **Permission dashboard**: View all active grants, revoke individually, bulk manage
3. **Pattern-based grants**: "Allow `git *` always" - wildcard matching for command families
4. **Per-agent scoping**: TEA agent can run tests but not push; Dev can edit but not deploy

### Vision (Future)

1. **Adaptive permissions**: System learns from approval patterns and suggests permanent grants for frequently-approved actions
2. **Team permission profiles**: Shareable permission configurations for onboarding
3. **Audit trail**: Full log of permission requests, grants, and revocations for compliance

## User Journeys

### Journey 1: Developer Mid-Session (Happy Path)

**Keith** is deep in a TDD workflow. Claude's Dev agent needs to run `npm test` to validate a green-phase implementation. Claude emits a Bash tool_use.

1. **Hook fires**: `cyclist-pretooluse-hook.js` intercepts the PreToolUse event, POSTs to WheelHub at `/api/hook-request`
2. **WheelHub checks grants**: `npm test` matches an existing session grant pattern `npm *` → auto-approved. No modal needed.
3. **Work continues**: Claude runs the test, sees results, proceeds to next step. Keith never noticed anything happened.

**When no grant exists**: WheelHub broadcasts to Cyclist via WebSocket. ApprovalModal appears overlaid on the current panel. Keith sees the command, its severity (safe/normal/destructive), and three buttons: Allow Once, Allow Session, Always Allow. He hits Enter (default: Allow Once). Modal dismisses, Claude continues within 1 second.

**Capabilities revealed**: Auto-approval via grants, WebSocket modal delivery, grant scope selection, keyboard shortcuts.

### Journey 2: Developer Encounters Dangerous Action

**Keith** asks Claude to force-push a feature branch. Claude emits `git push --force origin feature/permissions`.

1. **Hook fires**: WheelHub receives the request, classifies severity as **destructive** (matches force-push pattern)
2. **Modal appears**: Red-tinted border, warning icon, clear label: "DESTRUCTIVE ACTION". The command is displayed with the destructive portion highlighted.
3. **Keith decides**: He reads the command, confirms the branch is correct, clicks "Allow Once". He would never grant "Always Allow" for force-push, and the UI makes that choice feel appropriately weighty.
4. **Work continues**: Claude force-pushes. Keith's intent was respected.

**If Keith denies**: Claude receives a rejection error, acknowledges it, and suggests alternatives ("Would you like me to push without force instead?").

**Capabilities revealed**: Severity classification, destructive action visual treatment, denial handling, recovery suggestions.

### Journey 3: Dangerous Path Detection

**Keith** is debugging and Claude attempts to write to `~/.ssh/config`.

1. **Dangerous path detection**: Before the hook even fires, `dangerous-path.ts` classifies this as a **secrets** category path
2. **Enhanced modal**: Modal appears with additional context: "This file is in a sensitive directory (~/.ssh/). Changes here affect SSH authentication for your entire system."
3. **Keith denies**: This wasn't what he asked for. Claude was hallucinating a fix. The denial stops damage.

**Capabilities revealed**: Path-based danger classification, contextual warnings beyond just command text, protection against agent mistakes.

### Journey 4: Agent Workflow with Presets (Growth)

**Keith** starts a TDD workflow with `/workflow start tdd`. The SM agent activates and hands off to TEA.

1. **TEA activates**: The TDD workflow declares TEA needs `Bash(npm test, npx vitest)`, `Read(tests/**)`, `Write(tests/**)`.
2. **Preset prompt**: Cyclist shows a single consolidated modal: "TEA agent requests these permissions for the TDD workflow: [list]. Grant for this session?" Keith approves the batch.
3. **TEA works autonomously**: Writes tests, runs them, iterates - no permission interrupts for pre-approved patterns.
4. **Dev takes over**: Different preset loads. Dev needs `Edit(src/**)`, `Bash(npm run build)`. Same batch approval flow.

**Capabilities revealed**: Workflow-declared permission presets, batch approval, per-agent scoping, session-bound grants.

### Journey 5: Permission Management

**Keith** realizes he granted "Always Allow" to `rm -rf` during a late-night session. Next morning, he wants to clean up.

1. **Opens permissions**: `/permissions` in Claude or a Cyclist UI panel shows all active grants
2. **Reviews grants**: Sees the `rm -rf` always-grant, winces, clicks Revoke
3. **Grant removed**: Deleted from `.claude/settings.local.json`. Next time Claude tries `rm`, the modal will appear again.

**Capabilities revealed**: Grant visibility, revocation, persistent storage management.

### Journey Requirements Summary

| Journey | Capabilities Required |
|---------|----------------------|
| Happy Path | Hook registration, WebSocket broadcast, ApprovalModal mounting, grant checking, auto-approval |
| Dangerous Action | Severity classification, visual severity treatment, denial → error flow |
| Dangerous Path | Path detection, contextual warnings, category-based classification |
| Agent Presets | Workflow permission declarations, batch approval modal, per-agent grant scoping |
| Permission Mgmt | Grant listing, revocation, persistent storage CRUD |

## Developer Tooling Specific Requirements

### Architecture Overview

This is an **Electron app** (Cyclist) that wraps Claude Code CLI sessions. The permission system spans three process boundaries:

1. **Claude Code process** - Emits tool_use events, executes PreToolUse hooks
2. **Cyclist main process** (Node/Electron) - Runs WheelHub HTTP/WebSocket server, stores grants
3. **Cyclist renderer process** (React 19) - Displays ApprovalModal, captures user decisions

### Integration Points

| Integration | Protocol | Status |
|-------------|----------|--------|
| Claude Code → Hook script | PreToolUse hook (shell exec) | Script exists, not registered |
| Hook script → WheelHub | HTTP POST to `/api/hook-request` | Endpoint mounted, hook targets wrong URL |
| WheelHub → React UI | WebSocket `/ws/hooks` broadcast | WebSocket handler registered, no UI consumer |
| React UI → WheelHub | WebSocket `hook-response` message | ApprovalModal implements, not mounted |
| WheelHub → Hook script | HTTP response (allow/deny/ask) | Implemented |
| Grant storage | `.claude/settings.local.json` | Implemented in settings-store.ts |

### Key Technical Constraints

- **Hook timeout**: Claude Code PreToolUse hooks have a finite timeout. If WheelHub doesn't respond in time, Claude Code falls back to its built-in terminal prompt. The hook must respond within this window.
- **Single port coordination**: Hook script reads port from `.cyclist-approval-port` file. Cyclist must write this file on startup.
- **Grant format compatibility**: Grants stored in `.claude/settings.local.json` must not conflict with Claude Code's own settings format.
- **React component lifecycle**: ApprovalModal must subscribe to WebSocket on mount and clean up on unmount. Must handle rapid successive requests (agent running multiple tools quickly).

### Implementation Considerations

- **Remove old IPC approval path**: `main.ts` lines 2266-2318 contain the old `/approval-request` endpoint that uses Electron IPC. This should be removed in favor of the WheelHub WebSocket path.
- **Hook script update**: `cyclist-pretooluse-hook.js` currently POSTs to `/approval-request`. Must be updated to POST to `/api/hook-request`.
- **ApprovalModal mounting**: Must be a top-level component (not nested inside workspace panels) so it overlays everything. Use React portal or shadcn Dialog's built-in portal behavior.
- **Concurrent requests**: Multiple tools can fire in rapid succession. The modal should queue requests or show them sequentially, not stack modals.

## Functional Requirements

### FR-1: Hook Registration and Interception

**Capability**: Claude Code PreToolUse hooks intercept tool_use events and route them to Cyclist for approval.

**Acceptance Criteria**:
- `cyclist-pretooluse-hook.js` is registered in `.claude/settings.local.json` under `hooks.PreToolUse`
- Hook script reads WheelHub port from `.cyclist-approval-port` file
- Hook POSTs to `http://127.0.0.1:{port}/api/hook-request` with `{ toolName, toolId, input }`
- Hook returns JSON `{ decision: "allow"|"deny" }` to Claude Code
- If WheelHub is unreachable (Cyclist not running), hook returns `{ decision: "ask" }` to fall back to Claude Code's built-in prompt

**Traces to**: Journey 1 (Happy Path), Technical Success (Hook integration)

### FR-2: WheelHub Approval Router

**Capability**: WheelHub receives hook requests, checks grants, and either auto-approves or broadcasts to UI for manual approval.

**Acceptance Criteria**:
- `POST /api/hook-request` accepts `{ toolName, toolId, input, context? }`
- Grant check runs first: if tool+scope matches an existing grant, returns `{ decision: "allow" }` immediately
- If no grant matches, broadcasts `hook-request` event to all WebSocket clients on `/ws/hooks`
- Waits for WebSocket `hook-response` with timeout (2 minutes)
- On timeout with no response, returns `{ decision: "ask" }` (defer to Claude Code)
- Auto-revokes `once` grants after single use

**Traces to**: Journey 1 (auto-approval), Journey 2 (dangerous action routing)

### FR-3: ApprovalModal UI

**Capability**: React modal displays permission requests and captures user decisions with three grant scope options.

**Acceptance Criteria**:
- ApprovalModal is mounted at the top level of the React component tree (renders via portal)
- Subscribes to WebSocket `hook-request` events on mount, cleans up on unmount
- Displays: tool name, command/scope, severity classification (safe/normal/destructive)
- Three action buttons: "Allow Once", "Allow This Session", "Always Allow"
- "Deny" button to reject
- Keyboard shortcuts: Enter = Allow Once, Escape = Deny
- Sends `hook-response` via WebSocket with `{ toolId, approved, grantScope }`
- Queues multiple simultaneous requests, shows one at a time

**Traces to**: Journey 1, Journey 2, User Success (single interaction point)

### FR-4: Severity Classification

**Capability**: Tool requests are classified by risk level with visual treatment matching severity.

**Acceptance Criteria**:
- Classification categories: `safe` (read-only ops), `normal` (standard mutations), `destructive` (irreversible ops)
- Destructive patterns detected: `rm -rf`, `git push --force`, `git reset --hard`, `DROP TABLE`, file deletion, system path writes
- Dangerous path detection (from `dangerous-path.ts`): `.env`, `~/.ssh/`, `~/.aws/`, `.git/` internals, `node_modules/`, `/etc/`, `/usr/`
- Visual treatment: safe = default styling, normal = standard border, destructive = red border + warning icon + "DESTRUCTIVE ACTION" label
- Contextual warning text for dangerous paths (e.g., "This file is in a sensitive directory")

**Traces to**: Journey 2 (Dangerous Action), Journey 3 (Dangerous Path)

### FR-5: Grant Persistence

**Capability**: Permission grants persist according to their scope and survive across sessions where appropriate.

**Acceptance Criteria**:
- `once` grants: stored in memory, consumed after single use, auto-revoked
- `session` grants: stored in memory, cleared when Claude Code session ends
- `always` grants: persisted to `.claude/settings.local.json`, loaded on startup
- Grant format: `{ tool, scope, grant_type, granted_at, uses_remaining? }`
- Pattern matching for scope: exact match and glob patterns (e.g., `npm *` matches `npm test`, `npm run build`)

**Traces to**: User Success (permission memory), Journey 1 (auto-approval)

### FR-6: Grant Management

**Capability**: Users can view, revoke, and manage active permission grants.

**Acceptance Criteria**:
- `/permissions` skill lists all active grants (once, session, always)
- `/permissions grant <tool> "<scope>" --type <scope>` adds a grant manually
- `/permissions revoke <tool>` removes grants for a tool
- `/permissions show <tool>` shows grants for a specific tool
- Always-grants can be revoked, removing them from `.claude/settings.local.json`

**Traces to**: Journey 5 (Permission Management)

### FR-7: Old System Removal

**Capability**: The legacy Electron IPC approval path is removed to eliminate architectural confusion.

**Acceptance Criteria**:
- Old `/approval-request` HTTP endpoint removed from `main.ts`
- Old Electron IPC `permission-request` / `resolveHookApproval` handlers removed
- Old `interceptBashToolUse` function in `approval-gate.ts` deprecated or removed (replaced by generic `interceptToolUse` which is used by WheelHub)
- No remaining references to the old approval path in the codebase

**Traces to**: Technical Success (single approval architecture)

### FR-8: Workflow Permission Presets (Growth)

**Capability**: Workflows declare required permissions per agent phase, presented as batch approval on agent activation.

**Acceptance Criteria**:
- Workflow YAML includes `permissions` block per phase/agent
- On agent activation, if preset permissions exist, Cyclist shows a batch approval modal
- User can approve or deny the entire batch
- Approved presets are stored as session grants
- Schema: `{ tool, scope, reason }` per preset entry

**Traces to**: Journey 4 (Agent Presets), Business Success (agent autonomy)

## Non-Functional Requirements

### NFR-1: Latency

- Hook interception to modal display: < 500ms
- Grant check (auto-approval path): < 50ms
- Modal dismiss to Claude Code resumption: < 200ms
- Total round-trip for manual approval: < user response time + 700ms overhead

### NFR-2: Reliability

- Hook script must handle WheelHub unavailability gracefully (return `ask`, never hang)
- WebSocket reconnection on disconnect with exponential backoff
- No data loss on grant storage writes (atomic file writes for `.claude/settings.local.json`)
- Modal must always be dismissible (Escape key as failsafe)

### NFR-3: Security

- Hook script only connects to `127.0.0.1` (no external network calls)
- Port file (`.cyclist-approval-port`) should have restrictive file permissions
- Grant storage must not allow injection of arbitrary Claude Code settings
- Destructive action classification must be conservative (false positives are safer than false negatives)

### NFR-4: Usability

- Modal must be readable at a glance: tool name, command, severity, and action buttons clearly visible
- Keyboard-first interaction: Enter to approve, Escape to deny, no mouse required
- No modal stacking: queue multiple requests, show sequentially
- Permission state must be inspectable at any time via `/permissions`

### NFR-5: Compatibility

- Must work with Claude Code's PreToolUse hook protocol (stdout JSON response)
- Must not conflict with existing hooks (pre-edit-check, context-warning, context-circuit-breaker)
- Grant storage format must coexist with Claude Code's own settings in `.claude/settings.local.json`
- Must work across macOS (primary) and Linux (secondary) platforms
