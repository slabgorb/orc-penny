---
stepsCompleted:
  - step-01-validate
  - step-02-design-epics
  - step-03-create-stories
inputDocuments:
  - artifacts/prd.md
  - artifacts/architecture.md
---

# Cyclist Permission System - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for the Cyclist Permission System. This is brownfield wiring work - the components exist but aren't connected.

## Requirements Inventory

### Functional Requirements

- FR-1: Hook Registration and Interception
- FR-2: WheelHub Approval Router
- FR-3: ApprovalModal UI
- FR-4: Severity Classification
- FR-5: Grant Persistence
- FR-6: Grant Management
- FR-7: Old System Removal
- FR-8: Workflow Permission Presets (Growth)

### NonFunctional Requirements

- NFR-1: Latency (<500ms hook to modal)
- NFR-2: Reliability (graceful fallback, reconnection)
- NFR-3: Security (localhost-only, conservative classification)
- NFR-4: Usability (keyboard-first, no stacking)
- NFR-5: Compatibility (Claude Code hook protocol, existing hooks)

### FR Coverage Map

| FR | Story | Description |
|----|-------|-------------|
| FR-7 | 1.1 | Remove old IPC approval path |
| FR-1 | 1.2 | Update hook script and register in Claude Code |
| FR-2 | 1.3 | Integrate grant checking into WheelHub hook router |
| FR-3 | 1.4 | Mount ApprovalModal in React tree |
| FR-4 | 1.5 | Add severity classification to hook request flow |
| FR-5 | 1.6 | Wire grant persistence across all three scopes |
| FR-6 | 1.7 | Connect /permissions skill to grant store |
| FR-8 | 1.8 | Workflow permission presets (Growth) |

## Epic List

### Epic 1: Cyclist Permission System
Wire the existing permission components into a working end-to-end approval flow. When Claude Code needs permission, Cyclist shows a modal, the user decides, and work continues.
**FRs covered:** FR-1 through FR-8

## Epic 1: Cyclist Permission System

Wire the existing approval gate, hook script, WheelHub router, ApprovalModal, and grant storage into a single working permission flow. Remove the legacy IPC path.

### Story 1.1: Remove Legacy IPC Approval Path

As a developer,
I want the old Electron IPC approval system removed,
So that there is one clear approval architecture to maintain.

**Acceptance Criteria:**

**Given** the old `/approval-request` endpoint exists in `main.ts`
**When** this story is complete
**Then** the `/approval-request` HTTP handler is removed from `main.ts`
**And** the Electron IPC `permission-request` and `resolveHookApproval` handlers are removed
**And** `interceptBashToolUse` is removed from `approval-gate.ts` (generic `interceptToolUse` remains)
**And** no remaining imports or references to the old approval path exist in the codebase
**And** the build succeeds with no type errors

### Story 1.2: Update and Register PreToolUse Hook

As a developer using Cyclist,
I want Claude Code's PreToolUse hook to route permission requests to WheelHub,
So that Cyclist can intercept and respond to tool permission requests.

**Acceptance Criteria:**

**Given** `cyclist-pretooluse-hook.js` exists but POSTs to the old `/approval-request` URL
**When** this story is complete
**Then** the hook script POSTs to `http://127.0.0.1:{port}/api/hook-request` with `{ toolName, toolId, input }`
**And** the hook reads the port from `.cyclist-approval-port`
**And** the hook returns `{ "decision": "allow" }` or `{ "decision": "deny" }` based on the WheelHub response
**And** if WheelHub is unreachable, the hook returns `{ "decision": "ask" }` (fall back to Claude Code prompt)
**And** the hook is registered in `.claude/settings.local.json` under `hooks.PreToolUse`
**And** the hook does not conflict with existing PreToolUse hooks (pre-edit-check, context-warning, context-circuit-breaker)

### Story 1.3: Integrate Grant Checking into WheelHub Hook Router

As a developer using Cyclist,
I want WheelHub to auto-approve requests that match existing grants,
So that previously-approved actions don't require repeated approval.

**Acceptance Criteria:**

**Given** a hook request arrives at `POST /api/hook-request`
**When** the tool+scope matches an existing grant in `settings-store.ts`
**Then** WheelHub returns `{ decision: "allow" }` immediately without broadcasting to the UI
**And** `once` grants are auto-revoked after single use
**And** `session` grants remain active until session ends
**And** `always` grants are loaded from `.claude/settings.local.json` on startup
**And** grant check latency is < 50ms

**Given** a hook request arrives and no grant matches
**When** Cyclist UI clients are connected via WebSocket
**Then** WheelHub broadcasts a `hook-request` event on `/ws/hooks`
**And** waits up to 2 minutes for a `hook-response`
**And** on timeout returns `{ decision: "ask" }`

**Given** no WebSocket clients are connected
**When** a hook request arrives
**Then** WheelHub returns `{ decision: "ask" }` immediately

### Story 1.4: Mount ApprovalModal in React Component Tree

As a developer using Cyclist,
I want to see an approval modal when Claude Code requests permission,
So that I can approve or deny actions without leaving Cyclist.

**Acceptance Criteria:**

**Given** ApprovalModal exists at `src/public/components/ApprovalModal/index.tsx` but is not mounted
**When** this story is complete
**Then** ApprovalModal is imported and rendered in `App.tsx` at the top level (outside workspace panels)
**And** it subscribes to WebSocket `hook-request` events on mount
**And** it sends `hook-response` via WebSocket when the user decides
**And** the modal displays: tool name, command/scope, and three action buttons (Allow Once, Allow Session, Always Allow) plus Deny
**And** keyboard shortcuts work: Enter = Allow Once, Escape = Deny
**And** multiple simultaneous requests are queued and shown one at a time (no stacking)
**And** the modal is always dismissible via Escape
**And** existing ApprovalModal tests (62/62) continue to pass

### Story 1.5: Add Severity Classification to Hook Request Flow

As a developer using Cyclist,
I want dangerous actions clearly flagged in the approval modal,
So that I can make informed decisions about risky operations.

**Acceptance Criteria:**

**Given** a hook request is received by WheelHub
**When** WheelHub broadcasts to WebSocket clients
**Then** the broadcast includes a `severity` field: `safe`, `normal`, or `destructive`
**And** safe = read-only tools (Read, Grep, Glob, WebSearch, git status/diff/log)
**And** normal = standard mutations (Edit, Write, non-destructive Bash, git add/commit)
**And** destructive = irreversible ops (rm -rf, git push --force, git reset --hard, writes to dangerous paths)
**And** dangerous paths from `dangerous-path.ts` (.env, ~/.ssh/, ~/.aws/, .git/ internals, /etc/, /usr/) are classified as destructive
**And** the broadcast includes contextual warning text for dangerous paths

**Given** the ApprovalModal receives a `destructive` severity request
**When** the modal renders
**Then** it displays with red border, warning icon, and "DESTRUCTIVE ACTION" label
**And** safe/normal requests display with default/standard styling

### Story 1.6: Wire Grant Persistence Across All Three Scopes

As a developer using Cyclist,
I want my permission grants to persist according to their scope,
So that "Always Allow" survives across sessions and "Once" expires after use.

**Acceptance Criteria:**

**Given** the user selects "Allow Once" in ApprovalModal
**When** the grant is stored
**Then** it is held in memory with `uses_remaining: 1`
**And** it is consumed on the next matching request and auto-revoked

**Given** the user selects "Allow Session" in ApprovalModal
**When** the grant is stored
**Then** it is held in memory for the duration of the session
**And** it is cleared when the Claude Code session ends

**Given** the user selects "Always Allow" in ApprovalModal
**When** the grant is stored
**Then** it is persisted to `.claude/settings.local.json` under `permissions.grants`
**And** it is loaded on Cyclist startup
**And** it survives across sessions until explicitly revoked

**Given** a grant with scope pattern `npm *`
**When** a request for `npm test` arrives
**Then** the pattern matches and the request is auto-approved

### Story 1.7: Connect /permissions Skill to Grant Store

As a developer using Cyclist,
I want to view and manage my permission grants via the `/permissions` skill,
So that I can inspect active grants and revoke ones I no longer want.

**Acceptance Criteria:**

**Given** the `/permissions` skill exists at `pennyfarthing-dist/skills/permissions/skill.md`
**When** the user runs `/permissions`
**Then** all active grants are listed (once, session, always) with tool, scope, type, and granted_at

**Given** the user runs `/permissions revoke Bash`
**When** grants exist for the Bash tool
**Then** all grants for Bash are removed (memory and `.claude/settings.local.json`)

**Given** the user runs `/permissions grant Bash "npm *" --type always`
**When** the command is processed
**Then** a new always-grant is created and persisted to `.claude/settings.local.json`

### Story 1.8: Workflow Permission Presets (Growth)

As a developer using Cyclist,
I want workflows to declare what permissions each agent needs,
So that agents can work autonomously within pre-approved boundaries.

**Acceptance Criteria:**

**Given** a workflow YAML includes a `permissions` block per phase/agent
**When** an agent activates for that phase
**Then** Cyclist shows a batch approval modal listing all requested permissions with reasons
**And** the user can approve or deny the entire batch

**Given** the user approves a workflow permission preset batch
**When** the grants are stored
**Then** they are stored as session grants (not permanent)
**And** they follow the same pattern matching as individual grants

**Given** `workflow-permissions.ts` schema exists in `packages/core/src/workflow/`
**When** this story is complete
**Then** the schema is integrated into workflow startup and agent activation flows
