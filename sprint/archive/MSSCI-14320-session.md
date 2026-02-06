# Story Session: MSSCI-14320

**Story:** Update and register PreToolUse hook
**Epic:** MSSCI-14317 - Cyclist Permission System (Epic 78)
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Branch:** feature/MSSCI-14320-pretooluse-hook-update
**Repos:** pennyfarthing
**Jira:** MSSCI-14320
**Started:** 2026-02-06

## Context

Replace `cyclist-pretooluse-hook.js` with the existing Python implementation. The Python hook (`pretooluse_hook.py`) already POSTs to the correct endpoint, uses the correct port file, and returns "ask" on connection failure. The JS hook is redundant legacy code.

## Acceptance Criteria

- [ ] Hook POSTs to `/api/hook-request` (not `/approval-request`)
- [ ] Hook registered in `.claude/settings.local.json` under `hooks.PreToolUse`
- [ ] ECONNREFUSED returns `{ decision: "ask" }` (not `allow`)
- [ ] Port file discovery uses `.cyclist-port` with `.cyclist-approval-port` fallback
- [ ] Existing E2E tests continue to pass
- [ ] Legacy JS hook (`cyclist-pretooluse-hook.js`) deleted

## Key Files

### Create
- `pennyfarthing/pennyfarthing_scripts/hooks/cyclist-pretooluse-hook.sh` — bash wrapper calling python3 pretooluse_hook.py

### Modify
- `.claude/settings.local.json` — register the .sh wrapper in hooks.PreToolUse
- `pennyfarthing/pennyfarthing_scripts/hooks.py` — fix NameError on line 72 (`CYCLIST_APPROVAL_PORT_FILE` → `CYCLIST_APPROVAL_PORT_FILE_LEGACY`)

### Delete
- `pennyfarthing/packages/cyclist/src/hooks/cyclist-pretooluse-hook.js` — replaced by Python

### Reference
- `pennyfarthing/pennyfarthing_scripts/pretooluse_hook.py` — already-correct Python implementation
- `pennyfarthing/pennyfarthing_scripts/hooks.py` — shared hook utilities
- `pennyfarthing/packages/cyclist/src/api/hook-request.ts` — server-side handler
- `pennyfarthing/packages/cyclist/e2e/hook-request.e2e.ts` — E2E tests

## TEA Assessment

**Tests Required:** Yes
**Approach:** Consolidate on Python hook — delete JS, wrap with .sh, register

**Test Files:**
- `pennyfarthing/tests/python/test_pretooluse_hook.py` — 24 tests (pytest)
- `pennyfarthing/packages/cyclist/tests/MSSCI-14320-pretooluse-hook-registration.test.ts` — 4 tests (vitest)

**RED State:** 7 failing, 19 passing, 2 skipped

**Failing tests (Dev must fix):**
1. `test_shell_wrapper_exists` — create `cyclist-pretooluse-hook.sh`
2. `test_js_hook_removed` — delete `cyclist-pretooluse-hook.js`
3. `test_find_project_root_finds_cyclist_port` — fix `CYCLIST_APPROVAL_PORT_FILE` → `CYCLIST_APPROVAL_PORT_FILE_LEGACY` in hooks.py:72
4. 4x vitest registration tests — add hook entry to settings.local.json

**Bug found:** `hooks.py` line 72 references undefined `CYCLIST_APPROVAL_PORT_FILE` (should be `CYCLIST_APPROVAL_PORT_FILE_LEGACY`). Tests correctly catch this NameError.

**Dev implementation steps:**
1. Fix `hooks.py:72` NameError
2. Create `pennyfarthing_scripts/hooks/cyclist-pretooluse-hook.sh` wrapper
3. Register wrapper in `.claude/settings.local.json` PreToolUse hooks
4. Delete `packages/cyclist/src/hooks/cyclist-pretooluse-hook.js`
5. Run all tests to GREEN

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/hooks.py` - Fixed NameError on line 72 (`CYCLIST_APPROVAL_PORT_FILE` → `CYCLIST_APPROVAL_PORT_FILE_LEGACY`)
- `pennyfarthing_scripts/hooks/cyclist-pretooluse-hook.sh` - Created shell wrapper calling python3 pretooluse_hook.py
- `packages/cyclist/src/hooks/cyclist-pretooluse-hook.js` - Deleted (replaced by Python hook)
- `.claude/settings.local.json` - Registered .sh wrapper in hooks.PreToolUse

**Tests:** 28/28 passing (GREEN) — 24 pytest + 4 vitest
**PR:** #686 - feat(MSSCI-14320): update and register PreToolUse hook
**Branch:** feature/MSSCI-14320-pretooluse-hook-update (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** stdin JSON → cyclist-pretooluse-hook.sh (exec) → pretooluse_hook.py → read_stdin_json() → find_project_root() → is_cyclist_running() → send_to_cyclist("/api/hook-request") → WheelHub → response → output_hook_response() → stdout JSON. Safe — exec preserves stdin passthrough.
**Pattern observed:** Security improvement — old JS hook returned `allow` on ECONNREFUSED (line 155), Python correctly returns `ask` at pretooluse_hook.py:75 and :115
**Error handling:** Catch-all at pretooluse_hook.py:134 exits 0 (fail-open), correct for hooks
**Minor fix applied:** Quoted `$CLAUDE_PROJECT_DIR` in settings.local.json for consistency with all other hook entries
**Tests:** 28/28 GREEN (24 pytest + 4 vitest)

**Handoff:** To SM for finish-story
