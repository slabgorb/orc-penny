# Story Context: PROJ-14325 - Connect /permissions skill to grant store

## Summary

The `/permissions` skill currently exists as markdown-only instructions that tell Claude to use raw `jq` and `cat` commands against `.claude/settings.local.json`. It needs to be wired to the existing `settings-store.ts` grant CRUD API so that list/grant/revoke/show operations go through the proper in-memory store (with persistence callbacks), rather than directly manipulating a JSON file that is not actually used for grant storage.

## Current State

### The `/permissions` Skill (Markdown-Based)
- **Skill definition:** `pennyfarthing-dist/skills/permissions/skill.md` -- describes list/grant/revoke/show subcommands
- **Command definition:** `pennyfarthing-dist/commands/permissions.md` -- duplicate description, registered in slash-commands
- **Registry entry:** `pennyfarthing-dist/skills/skill-registry.yaml` -- listed under `permissions` with `category: project-management`
- Both the skill and command markdown instruct Claude to use `cat .claude/settings.local.json | jq` for reading and `jq ... > .claude/settings.local.json.tmp && mv ...` for writing
- This is **wrong** for two reasons:
  1. Grants are actually stored in `~/.cyclist/grants.json` (cross-project, via `settings.ts:GRANTS_FILE`), not in `.claude/settings.local.json`
  2. Runtime grants live in `settings-store.ts` in-memory state and are synced to disk via a persist callback -- direct file manipulation bypasses the runtime store entirely

### The Grant Store (`settings-store.ts`)
- **Location:** `pennyfarthing/packages/cyclist/src/settings-store.ts`
- Maintains two in-memory arrays: `sessionGrants` (once + session) and `persistedGrants` (always)
- Exports a full CRUD API already implemented:
  - `getGrants()` -- returns all grants (session + persisted)
  - `getSessionGrants()` / `getPersistedGrants()` -- filtered views
  - `addGrant(grant)` -- adds to appropriate store, triggers persist callback for always grants
  - `removeGrant(grant)` -- removes from both stores, triggers persist callback
  - `checkGrant(tool, command)` -- checks if a grant matches, auto-revokes once grants
  - `clearAllGrants()` / `clearSessionGrants()` -- bulk clear operations
  - `initializeGrants(grants)` -- loads persisted grants at startup
  - `setGrantsPersistCallback(cb)` -- delegates file I/O to `settings.ts`
- The `PermissionGrant` interface: `{ tool, scope, grant_type, granted_at }`
- `GrantType` enum: `ONCE = 'once'`, `SESSION = 'session'`, `ALWAYS = 'always'`

### Grant Persistence (`settings.ts`)
- **Location:** `pennyfarthing/packages/cyclist/src/settings.ts`
- `loadGrants()` -- reads from `~/.cyclist/grants.json`, filters to always-type only
- `saveGrants(grants)` -- writes always-type grants to `~/.cyclist/grants.json`
- `GRANTS_FILE = path.join(os.homedir(), '.cyclist', 'grants.json')`
- Wired in `main.ts` at startup: `initializeGrants(loadGrants())` then `setGrantsPersistCallback(saveGrants)`

### Permission Schema (`@pennyfarthing/core`)
- **Location:** `pennyfarthing/packages/core/src/permissions/permission-schema.ts`
- Defines `PermissionRequest`, `PermissionGrant`, `GrantType` types
- `validatePermissionRequest(input)` -- validates request objects
- `createGrant(request)` -- creates a `PermissionGrant` from a validated request

### Approval Gate Integration
- **Location:** `pennyfarthing/packages/cyclist/src/approval-gate.ts`
- `interceptToolUse()` calls `checkGrant()` from `settings-store.ts` to auto-approve matching grants
- This proves the store is already the single source of truth for runtime grant checking

### `.claude/settings.local.json`
- Used for Claude Code's own permission allow-list (the `permissions.allow` array)
- Does NOT contain grant data (the skill markdown incorrectly says it does)
- The actual `.claude/settings.local.json` has `permissions.allow` entries like `"Read"`, `"Bash(*)"`, `"Skill(sm)"`

## Target State

The `/permissions` skill should invoke programmatic operations against `settings-store.ts` rather than raw file manipulation. Since skills are markdown read by Claude (not executable code), the implementation approach must bridge the skill's text-based instructions to the TypeScript grant store. There are two viable approaches:

### Approach A: WheelHub API Endpoints (Preferred if Cyclist is running)
Add Express routes in Cyclist's WheelHub server that expose grant CRUD as HTTP endpoints. The skill markdown would instruct Claude to call these via `curl localhost:<port>/api/grants/...` or via Bash tool.

### Approach B: CLI Script (Works without Cyclist)
Create a small CLI script (e.g., `pennyfarthing-dist/scripts/permissions/manage-grants.sh` or `.mjs`) that reads/writes `~/.cyclist/grants.json` directly. The skill markdown would instruct Claude to invoke this script via Bash.

### Approach C: Direct File Manipulation with Correct Path
Update the skill markdown to point at `~/.cyclist/grants.json` instead of `.claude/settings.local.json` for always-grants. This is the simplest change but doesn't integrate with the runtime store.

## Key Files

### Primary (must modify)
| File | Purpose |
|------|---------|
| `pennyfarthing/pennyfarthing-dist/skills/permissions/skill.md` | Skill definition -- update instructions to use store API |
| `pennyfarthing/pennyfarthing-dist/commands/permissions.md` | Command definition -- update to match skill changes |

### Secondary (likely modify)
| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/src/settings-store.ts` | Runtime grant store -- may need new query functions (e.g., getGrantsByTool) |
| `pennyfarthing/packages/cyclist/src/settings.ts` | File I/O for grants -- may need to expose path or add helpers |
| `pennyfarthing/packages/cyclist/src/api/hook-request.ts` | WheelHub hook router -- may add grant management routes alongside |

### Reference (read-only context)
| File | Purpose |
|------|---------|
| `pennyfarthing/packages/core/src/permissions/permission-schema.ts` | PermissionGrant/PermissionRequest types, validation, createGrant |
| `pennyfarthing/packages/core/src/permissions/permission-schema.test.ts` | Tests for permission schema validation |
| `pennyfarthing/packages/cyclist/src/approval-gate.ts` | Shows how checkGrant is used at runtime |
| `pennyfarthing/packages/cyclist/src/main.ts` | Shows grant initialization wiring (lines 798-807) |
| `pennyfarthing/packages/cyclist/src/claude-service.ts` | Claude CLI interaction (skill execution context) |
| `pennyfarthing/packages/core/src/workflow/workflow-permissions.ts` | Workflow permission presets (adjacent story PROJ-14326) |
| `pennyfarthing/pennyfarthing-dist/skills/skill-registry.yaml` | Skill registry (permissions entry at line 215) |
| `pennyfarthing/pennyfarthing-dist/guides/permission-protocol.md` | Permission request protocol guide |
| `pennyfarthing/docs/PERMISSIONS.md` | User-facing permissions documentation |
| `.claude/settings.local.json` | Claude Code settings (NOT grant storage) |
| `pennyfarthing/pennyfarthing-dist/templates/settings.local.json.template` | Template for new projects |

## Technical Approach

### 1. Update Skill Markdown (`skill.md` and `commands/permissions.md`)

The current skill instructs Claude to use `cat .claude/settings.local.json | jq`. This needs to change to one of:

**Option A (Recommended): Use `~/.cyclist/grants.json` directly**
- Update all `jq` commands to target `~/.cyclist/grants.json` instead of `.claude/settings.local.json`
- For **list**: `cat ~/.cyclist/grants.json 2>/dev/null | jq '.grants // []'`
- For **grant**: append to `grants` array in `~/.cyclist/grants.json`
- For **revoke**: filter `grants` array by tool name
- For **show**: filter `grants` array by tool name
- Pros: Simple, works without Cyclist running
- Cons: Bypasses runtime store (but always-grants are re-loaded on next startup)

**Option B (More Integrated): Add WheelHub API routes**
- Add `/api/grants` routes to Cyclist's Express server
- `GET /api/grants` -- list all grants
- `POST /api/grants` -- add a grant
- `DELETE /api/grants/:tool` -- revoke grants for tool
- `GET /api/grants/:tool` -- show grants for tool
- Update skill markdown to use `curl` against WheelHub
- Pros: Full runtime integration, grants take effect immediately
- Cons: Requires Cyclist to be running; more code to write

**Recommended: Option A for the skill, with a note about Option B as future enhancement**

### 2. Correct Storage Format Documentation

Update the skill's "Storage Format" section to reflect actual storage:
- Always-grants: `~/.cyclist/grants.json` with structure `{ "grants": [...] }`
- Session/once grants: memory-only (not persisted)
- `.claude/settings.local.json` is for Claude Code's allow-list, NOT for Pennyfarthing grants

### 3. Handle Revocation of Always-Grants

The story specifically says "Ensure always-grants can be revoked from .claude/settings.local.json." This is interesting because:
- Always-grants are actually stored in `~/.cyclist/grants.json`, not `.claude/settings.local.json`
- The story description may be using `.claude/settings.local.json` loosely to mean "from the persisted grant store"
- Revocation should: remove from `~/.cyclist/grants.json` AND from the runtime store if Cyclist is running

### 4. Test Coverage

Tests should verify:
- List returns grants from `~/.cyclist/grants.json`
- Grant creates a properly-formatted entry with timestamp
- Revoke removes all grants for a tool
- Show filters grants by tool name
- Always-grants round-trip through file persistence
- Error handling for missing file, invalid JSON, empty grants

## Acceptance Criteria

From the story description and epic context:

1. `/permissions` (no args) lists all active grants from the grant store
2. `/permissions grant <tool> "<scope>" [--type <type>]` creates a grant via `settings-store.ts` API (or direct file for always-grants)
3. `/permissions revoke <tool>` removes all grants for a tool, including persisted always-grants
4. `/permissions show <tool>` displays detailed grant info for a specific tool
5. Always-grants can be revoked and the revocation persists (removed from `~/.cyclist/grants.json`)
6. Grant storage location is correctly documented (not `.claude/settings.local.json`)

## Dependencies

| Story | Relationship | Status |
|-------|-------------|--------|
| PROJ-14318 | Remove legacy IPC approval path | Done |
| PROJ-14324 | Wire grant persistence across all three scopes | Backlog (P1) -- provides the persistence guarantees this story relies on |
| PROJ-14321 | Integrate grant checking into WheelHub hook router | Backlog (P0) -- if WheelHub API approach chosen, routes would go here |
| PROJ-14326 | Workflow permission presets | Backlog (P3) -- downstream consumer of grant store |

**Hard dependency:** PROJ-14324 should ideally be done first since it ensures the three grant scopes (once/session/always) work correctly with persistence. However, this story can proceed if the skill only targets always-grants (which already persist).

**Soft dependency:** PROJ-14321 would benefit from being done first if taking the WheelHub API approach, since that story already wires `settings-store.ts` into `hook-request.ts`.

## Risks / Open Questions

1. **Storage location mismatch:** The story description says "revoked from `.claude/settings.local.json`" but grants are stored in `~/.cyclist/grants.json`. Need to confirm with PM whether to:
   - (a) Update the story to reflect actual storage location, or
   - (b) Move grant storage into `.claude/settings.local.json` (would require changing `settings.ts`)

2. **Cyclist dependency:** If using the WheelHub API approach, the `/permissions` skill only works when Cyclist is running. A fallback for CLI-only usage would be needed.

3. **Session/once grants are memory-only:** The skill can only list/revoke session and once grants if Cyclist is running and the WheelHub API approach is used. With file-based approach, only always-grants are visible.

4. **Skill execution model:** Skills are markdown files read by Claude -- they contain instructions, not executable code. The "implementation" is really updating the instructions Claude follows. This means the skill cannot import TypeScript modules; it can only instruct Claude to run bash commands or use tools.

5. **Workflow:** TDD workflow is specified. TEA writes tests first. But since the skill is markdown-based, the "tests" may need to be:
   - Integration tests that invoke the skill and verify grant file state
   - Unit tests for any new helper functions added to `settings-store.ts`
   - Verification that `~/.cyclist/grants.json` is correctly manipulated

6. **Duplicate definitions:** Both `skill.md` and `commands/permissions.md` describe the same functionality. They should be kept in sync or consolidated.
