# Story Context: PROJ-14326 - Workflow permission presets

## Summary

Integrate the existing `workflow-permissions.ts` schema and `checkWorkflowPermissions()` function into the workflow startup flow so that when a workflow defines permission presets in its YAML, a batch approval modal is shown on agent activation for any missing permissions, and approved presets are stored as session grants in `settings-store.ts`.

## Current State

Substantial infrastructure already exists from Epic 33 (PROJ-11705) and the prior story PROJ-11710/PROJ-11847. The schema, validation, checking logic, grant storage, and UI approval modal are all implemented. What is missing is the integration glue that connects workflow startup to permission checking and the batch approval UX.

### What exists

1. **Workflow permission schema** (`packages/core/src/workflow/workflow-schema.ts`):
   - `WorkflowPermissionPreset` interface (lines 59-66): `{ tool, scope, reason }`
   - `WorkflowDefinition.permissions` optional field (line 132)
   - `validateWorkflow()` validates permissions arrays (lines 441-477)
   - Permissions are parsed and returned in validated workflow objects (lines 614-622)

2. **Permission checking logic** (`packages/core/src/workflow/workflow-permissions.ts`):
   - `checkWorkflowPermissions(workflowPermissions, cachedGrants)` function
   - Returns `WorkflowPermissionCheckResult`: `{ allGranted, missing, granted }`
   - Matching is exact: same `tool` and `scope` (case-sensitive)
   - 16 tests passing in `workflow-permissions.test.ts`

3. **Permission request protocol** (`packages/core/src/permissions/permission-schema.ts`):
   - `PermissionRequest` / `PermissionGrant` / `GrantType` types
   - `validatePermissionRequest()` and `createGrant()` functions
   - Three grant types: `once`, `session`, `always`

4. **Grant storage** (`packages/cyclist/src/settings-store.ts`):
   - `addGrant(grant)` - adds to session or persisted storage
   - `checkGrant(tool, command)` - checks if grant covers a tool+command
   - `getGrants()` / `getSessionGrants()` / `getPersistedGrants()`
   - Session grants cleared on session end; always grants persist to `.claude/settings.local.json`
   - Glob pattern matching for scope (e.g., `npm *` matches `npm test`)

5. **ApprovalModal component** (`packages/cyclist/src/public/components/ApprovalModal/index.tsx`):
   - Fully implemented shadcn Dialog with approve/reject buttons
   - Grant scope support: once, session, always
   - Severity classification (safe/normal/destructive)
   - WebSocket integration via `subscribeToPermissionRequests()` / `sendPermissionResponse()`
   - 62 tests passing

6. **WheelHub hook request router** (`packages/cyclist/src/api/hook-request.ts`):
   - POST `/api/hook-request` handler
   - Broadcasts to WebSocket clients for approval
   - Pending approval map with 2-minute timeout

7. **Workflow module exports** (`packages/core/src/workflow/index.ts`):
   - Already exports `checkWorkflowPermissions` and `WorkflowPermissionCheckResult`
   - Already exports `WorkflowPermissionPreset` from `workflow-schema.ts`

8. **Workflow YAML files** (`pennyfarthing-dist/workflows/`):
   - 25 workflow YAML files exist (tdd, trivial, bdd, architecture, etc.)
   - **None currently define `permissions` arrays** - this is greenfield for presets

9. **Workflow loader** (`packages/core/src/workflow/workflow-loader.ts`):
   - `loadWorkflowFile()` and `loadWorkflowsFromDir()` already parse permissions from YAML
   - No additional loader changes needed

10. **Workflow startup** (`packages/core/src/workflow/workflow-executor.ts`):
    - `startWorkflow()` initializes state and loads step 1
    - Does NOT currently check permissions

11. **SM setup** (`packages/core/src/workflow/generic-sm-setup.ts`):
    - `setupStory()` creates session file with workflow tracking
    - Does NOT currently check workflow permissions

### Prior story session

The archived session `sprint/context/archived/PROJ-11710-session.md` documents the previous story (PROJ-11710) that built the TypeScript infrastructure. That story completed the schema, validation, checking, and exports but did NOT integrate into the startup flow. The current story (PROJ-14326) is the continuation that wires everything together, now under Epic 78 (Cyclist Permission System).

## Target State

When a workflow defines a `permissions` array in its YAML, the system should:

1. **On workflow startup / agent activation**: Load the workflow definition, extract `permissions` presets
2. **Check cached grants**: Call `checkWorkflowPermissions(workflow.permissions, cachedGrants)` against existing grants in `settings-store.ts`
3. **Batch approval modal**: If any permissions are missing, show a batch approval modal displaying all missing permissions with their reasons in a single UI prompt (not one-by-one)
4. **Store as session grants**: Approved presets are stored via `addGrant()` as session-scoped grants so they persist for the duration of the workflow/session
5. **Skip if all granted**: If all required permissions are already granted, proceed silently

### Example workflow YAML with permissions

```yaml
workflow:
  name: tdd
  description: Test-driven development with code review
  permissions:
    - tool: Bash
      scope: "npm test|npm run build"
      reason: "TDD workflow requires running test and build commands"
    - tool: Bash
      scope: "git *"
      reason: "Git operations for branch management"
    - tool: Read
      scope: "src/**/*"
      reason: "Read source files for implementation"
  phases:
    - name: setup
      agent: sm
      # ...
```

## Key Files

### Core Framework (`pennyfarthing/packages/core/src/`)

| File | Purpose | Status |
|------|---------|--------|
| `workflow/workflow-permissions.ts` | `checkWorkflowPermissions()` function | Exists, complete |
| `workflow/workflow-permissions.test.ts` | 16 tests for permission checking | Exists, all passing |
| `workflow/workflow-schema.ts` | `WorkflowPermissionPreset` type, validation | Exists, complete |
| `workflow/workflow-loader.ts` | Loads + validates workflow YAML including permissions | Exists, complete |
| `workflow/workflow-executor.ts` | `startWorkflow()` - needs permission check integration | Needs modification |
| `workflow/workflow-router.ts` | `routeStoryToWorkflow()` - routes stories to workflows | Exists, no change needed |
| `workflow/index.ts` | Barrel exports for workflow module | Exists, exports ready |
| `permissions/permission-schema.ts` | `PermissionGrant` type, `createGrant()` | Exists, complete |

### Cyclist UI (`pennyfarthing/packages/cyclist/src/`)

| File | Purpose | Status |
|------|---------|--------|
| `settings-store.ts` | `addGrant()`, `getGrants()`, session/persisted grant CRUD | Exists, complete |
| `public/components/ApprovalModal/index.tsx` | Single-permission approval dialog | Exists, needs batch variant or extension |
| `api/hook-request.ts` | WheelHub hook request handler | Exists, may need batch endpoint |
| `pennyfarthing.ts` | Agent detection, persona loading | Exists, activation hooks here |
| `agent-context.ts` | Agent tracking (`setAgentContext()`, `getAgentContext()`) | Exists, integration point |

### Workflow Definitions (`pennyfarthing/pennyfarthing-dist/workflows/`)

| File | Purpose | Status |
|------|---------|--------|
| `tdd.yaml` | TDD workflow (default for features) | Exists, no permissions yet |
| `trivial.yaml` | Quick-fix workflow | Exists, no permissions yet |
| `bdd.yaml` | BDD workflow | Exists, no permissions yet |
| Other 22 workflow YAMLs | Various workflows | None have permissions yet |

### Documentation

| File | Purpose | Status |
|------|---------|--------|
| `pennyfarthing-dist/guides/permission-protocol.md` | Permission protocol guide | Exists |
| `pennyfarthing-dist/commands/permissions.md` | `/permissions` skill docs | Exists |

## Technical Approach

### 1. Add batch permission checking to workflow startup

**File:** `packages/core/src/workflow/workflow-executor.ts`

Modify `startWorkflow()` to accept a grant-checking callback or return missing permissions before proceeding. The function currently initializes state and loads step 1; add a permissions check between state init and step loading.

```typescript
// In startWorkflow():
if (workflow.permissions && workflow.permissions.length > 0) {
  const result = checkWorkflowPermissions(workflow.permissions, cachedGrants);
  if (!result.allGranted) {
    // Return missing permissions for caller to prompt
    return { success: true, state, missingPermissions: result.missing };
  }
}
```

Alternative: Create a separate `checkWorkflowStartupPermissions()` function that callers invoke before `startWorkflow()`.

### 2. Create batch approval modal or extend existing ApprovalModal

**File:** `packages/cyclist/src/public/components/ApprovalModal/index.tsx` (extend) or new `BatchApprovalModal.tsx`

The existing ApprovalModal handles single tool-use permissions. The batch approval needs to show a list of all required permissions with checkboxes/reasons, and approve them all at once as session grants. Two options:

**Option A (Recommended):** New `BatchApprovalModal` component that renders a list of `WorkflowPermissionPreset` items with a single "Approve All" / "Reject" action pair.

**Option B:** Extend the existing ApprovalModal with a `batch` mode that accepts an array of permission presets.

### 3. Wire into agent activation flow

**Integration point:** When SM runs `setupStory()` (via sm-setup subagent) or when `/workflow start` is invoked:

1. Load workflow definition via `loadWorkflowFile()` or `routeStoryToWorkflow()`
2. Read current grants from `settings-store.ts` via `getGrants()`
3. Call `checkWorkflowPermissions(workflow.permissions, grants)`
4. If missing permissions exist, trigger batch approval (via WheelHub endpoint or direct UI state)
5. On approval, call `addGrant()` for each preset as `{ tool, scope, grant_type: 'session', granted_at }`

### 4. Add WheelHub endpoint for batch approval (if needed)

**File:** `packages/cyclist/src/api/hook-request.ts` or new `batch-approval.ts`

A new endpoint (e.g., `POST /api/batch-permission-request`) that:
- Accepts an array of permission presets
- Broadcasts to WebSocket clients as a batch request
- Waits for single batch response
- Returns approved/denied result

### 5. Add permissions to workflow YAML files

**Files:** `pennyfarthing-dist/workflows/tdd.yaml`, `trivial.yaml`, etc.

Add `permissions` arrays to key workflow definitions. Start with `tdd.yaml` as the most commonly used workflow. Presets should reflect what tools each workflow's agents actually need.

### 6. Store approved presets as session grants

**File:** `packages/cyclist/src/settings-store.ts`

Use existing `addGrant()` with `grant_type: 'session'` for workflow presets. These auto-clear on session end. No changes to the store are needed unless batch-add convenience function is desired.

## Acceptance Criteria

- AC1: Workflow YAML `permissions` field is read during workflow startup
- AC2: `checkWorkflowPermissions()` is called against cached grants at workflow start
- AC3: Missing permissions trigger a batch approval prompt (modal in Cyclist UI)
- AC4: Approved presets are stored as session-scoped grants via `settings-store.ts`
- AC5: When all permissions are pre-granted (cached), no prompt is shown
- AC6: Works with existing grant infrastructure (once/session/always lifecycle)

## Dependencies

### Upstream (must be complete first)

| Story | Title | Status | Why needed |
|-------|-------|--------|------------|
| PROJ-14324 | Wire grant persistence across all three scopes | Backlog | Session grants must work end-to-end for presets to persist |
| PROJ-14322 | Mount ApprovalModal in React component tree | Backlog | ApprovalModal must be rendered for batch variant to show |
| PROJ-14321 | Integrate grant checking into WheelHub hook router | Backlog | Grant checking plumbing must exist |

### Downstream (depends on this)

None - this is the last story (P3) in Epic 78.

### Available infrastructure (no dependency, already done)

- `checkWorkflowPermissions()` - exists and tested
- `WorkflowPermissionPreset` type - exists
- `validateWorkflow()` with permissions validation - exists
- `addGrant()` / `getGrants()` in settings-store - exists
- ApprovalModal component - exists (needs batch extension)

## Risks / Open Questions

1. **Batch vs. sequential approval UX**: Should the UI show all missing permissions in one modal with "Approve All" or prompt one-by-one? The story description says "batch approval modal" which suggests a single modal with a list. This requires a new or extended component.

2. **Where exactly to trigger**: The description says "on agent activation when presets exist." Agent activation happens in multiple places:
   - SM setup phase (`generic-sm-setup.ts` / `setupStory()`)
   - Agent slash commands (`/sm`, `/dev`, `/tea`, etc.)
   - Handoff transitions (`handoff.ts`)
   - The most natural point is SM setup since that is when the workflow is selected and the session is initialized.

3. **Scope matching granularity**: `checkWorkflowPermissions()` uses exact string matching for `tool` and `scope`. The settings-store `checkGrant()` uses glob pattern matching. These may produce different results for the same grant. Need to ensure the grants created from presets use the same scope strings that will match when tools are actually used.

4. **No workflow YAMLs have permissions yet**: This is greenfield - we need to decide which workflows get which permissions. The tdd workflow is the natural starting point. Permissions should reflect actual tool usage patterns.

5. **Dependency chain**: This story is P3 and depends on P0/P1 stories (PROJ-14321, -14322, -14324) being complete. If those aren't done, this story cannot be fully integrated end-to-end, though the core logic and tests can still be written.

6. **Duplicate `WorkflowPermissionPreset` type**: The type exists in both `workflow-schema.ts` (canonical) and `workflow-permissions.ts` (backwards compat). The index.ts barrel exports from `workflow-schema.ts`. The reviewer from PROJ-11710 flagged this as a low-priority consolidation opportunity.

7. **Settings-store vs. core permission types**: `settings-store.ts` defines its own `PermissionGrant` interface while `permission-schema.ts` also defines one. They are structurally compatible but not imported from each other. When creating grants from presets, ensure the correct type is used for the target store.
