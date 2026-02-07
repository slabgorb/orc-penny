# Story: MSSCI-14325 - Connect /permissions skill to grant store

**Epic:** epic-78 (Cyclist Permission System) - MSSCI-14317
**Points:** 2
**Workflow:** tdd
**Phase:** approved
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14325-connect-permissions-skill-grant-store
**Jira:** MSSCI-14325

## Acceptance Criteria

- /permissions list shows active grants from settings-store.ts
- /permissions grant adds grants via settings-store.ts
- /permissions revoke removes grants including always-grants from .claude/settings.local.json
- /permissions show displays grant details for a specific permission

## Technical Context

- Epic context: `sprint/context/context-epic-78.md`
- Key files to investigate (TEA will confirm):
  - Existing /permissions skill definition
  - `settings-store.ts` - grant storage backend
  - `.claude/settings.local.json` - persisted always-grants

## TEA Assessment

**Tests Required:** Yes
**Reason:** New API router bridging skill to grant store — needs full coverage

**Test Files:**
- `packages/cyclist/tests/MSSCI-14325-permissions-api.test.ts` - Permissions API router tests
- `packages/cyclist/src/api/permissions.ts` - Stub router (no routes implemented)

**Tests Written:** 24 tests covering 4 ACs (22 failing, 2 passing — router existence checks)
- AC1 (4 tests): GET / — list all active grants
- AC2 (8 tests): POST /grant — add grants with validation, default type, error cases
- AC3 (6 tests): DELETE /revoke/:tool — remove grants, persistence callback, mixed types, optional scope filter
- AC4 (4 tests): GET /show/:tool — filtered grants by tool, case sensitivity

**Status:** RED (22 failing — routes not implemented)

**Implementation Notes for Dev:**
1. Implement 4 route handlers in `src/api/permissions.ts`: GET /, POST /grant, DELETE /revoke/:tool, GET /show/:tool
2. Import from `settings-store.ts`: `getGrants`, `addGrant`, `removeGrant`
3. Register router in `server.ts` as `/api/permissions`
4. Export from `api/index.ts`
5. Update `skill.md` to call WheelHub API instead of raw `cat | jq`
6. Grants are stored in `~/.cyclist/grants.json` (always-type via persist callback), not `.claude/settings.local.json` — the skill docs reference the wrong location

**Handoff:** To Dev for implementation

## Dev Assessment

**Status:** GREEN (24/24 tests passing)
**PR:** https://github.com/1898andCo/pennyfarthing/pull/696

**Files Changed:**
- `packages/cyclist/src/api/permissions.ts` — 4 route handlers (list, grant, revoke, show)
- `packages/cyclist/src/api/index.ts` — export `createPermissionsRouter`
- `packages/cyclist/src/server.ts` — mount at `/api/permissions`
- `pennyfarthing-dist/skills/permissions/skill.md` — WheelHub API calls instead of raw file ops

**Implementation Approach:**
- Thin router delegating to existing `settings-store.ts` functions
- POST /grant validates required fields, defaults grant_type to 'session'
- DELETE /revoke/:tool supports optional `?scope=` query for targeted revoke
- Corrected skill.md storage docs (was `.claude/settings.local.json`, now `~/.cyclist/grants.json`)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Preflight:**
- Tests (shared): 103/103 PASS
- Tests (core): 1491/1578 (86 failures — all pre-existing OCEAN/spider chart tests, confirmed identical on develop)
- Story tests: 24/24 PASS
- Lint: 18 pre-existing unused-var warnings, none in changed files
- No `console.log`, no forbidden patterns

**Data flow traced:** skill.md curl → Express /api/permissions → permissions.ts router → settings-store.ts (getGrants/addGrant/removeGrant) → grants.json persistence callback. Verified end-to-end wiring at server.ts:136, api/index.ts:39.

**Pattern observed:** Thin router delegating to store — matches existing Cyclist API patterns (settings, mode, identity routers). Clean separation of concerns at permissions.ts:20-85.

**Error handling:** POST /grant validates tool (string, required), scope (string, required), grant_type (optional, whitelist-validated against ['once','session','always']). Missing fields → 400. Invalid grant_type → 400. DELETE /revoke returns 200 with {removed: 0} for nonexistent tools (idempotent).

**Security:** No auth middleware — consistent with all Cyclist API routes (localhost-only dev server). No new attack surface.

**Observations:**
1. [VERIFIED] Router export/import/mount chain complete — no dead wires
2. [VERIFIED] Snapshot-then-iterate pattern in revoke prevents iterator invalidation (permissions.ts:65-72)
3. [VERIFIED] Store-level duplicate prevention on addGrant (tool+scope match)
4. [LOW] Type assertion before validation at permissions.ts:42 — runtime guard on line 44 makes it safe
5. [VERIFIED] 24 tests cover all 4 ACs including edge cases (empty state, case sensitivity, mixed grant types, scope filtering)
6. [VERIFIED] Clean TDD commit history: test commit first, then implementation commit
7. [VERIFIED] skill.md correctly documents WheelHub API endpoints with curl examples
8. [VERIFIED] skill.md storage docs corrected from `.claude/settings.local.json` to `~/.cyclist/grants.json`
9. [VERIFIED] No forbidden patterns (console.log, t.Skip, hardcoded secrets)
10. [LOW] skill.md uses WHEELHUB_PORT default 7173 — different from server.ts default 1898, but consistent with existing skill convention

**Handoff:** To SM for finish-story

## Notes

TDD workflow: SM → TEA → Dev → Reviewer
