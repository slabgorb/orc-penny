# Story 98-8: Fix Cyclist false-positive detection in CLI mode

**Jira:** PROJ-14722
**Epic:** PROJ-14697 (Safe Install, Upgrade, and Namespace Isolation)
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/98-8-cyclist-false-positive-detection
**Assigned:** keith.avery
**Points:** 3
**Type:** bug

---

## Problem

`is_cyclist_running()` in `pennyfarthing_scripts/hooks.py:411` checks for `.cyclist-port` file existence to determine if Cyclist is running. This gives false positives in CLI mode when the file is stale (Cyclist shut down without cleanup, crash, SIGKILL, etc.).

The function fires on every PreToolUse hook invocation, so HTTP health checks are not viable — must be zero-latency.

## Key Discovery

Cyclist already has PID file infrastructure on the TypeScript side:
- `server.ts:290` — `PID_FILE_NAME = '.cyclist-pid'`
- `server.ts:425` — `writePidFile()` writes PID on startup
- `server.ts:434` — `cleanupPidFile()` removes on shutdown
- `server.ts:445` — `readPidFile()` reads PID from file
- `server.ts:471` — `isProcessRunning()` checks PID with signal 0

The Python side (`hooks.py`) does NOT use any of this. It only checks `.cyclist-port` existence.

## Scope

### Python side (hooks.py)
- `is_cyclist_running()` — needs PID-based validation
- `CYCLIST_PORT_FILE` constant — may need companion PID constant

### TypeScript side (cyclist/src/server.ts)
- `writePortFile()` — ensure PID file always written alongside
- `cleanupPortFile()` — ensure PID file always cleaned alongside
- Signal handlers (SIGINT, SIGTERM) — verify both files cleaned up

### Affected consumers (14 files reference .cyclist-port)
- `pretooluse_hook.py` — primary false positive path
- `hooks.py` — detection function
- `context.py` — context state
- `check-context.sh`, `session-start.sh`, `bell-mode-hook.sh`, `otel-auto-config.sh`, `welcome-hook.sh`
- `main.ts`, `server.ts` — Cyclist core
- `test_pretooluse_hook.py` — tests

## Acceptance Criteria

- [ ] `is_cyclist_running()` returns false when `.cyclist-port` exists but Cyclist process is dead
- [ ] `is_cyclist_running()` returns true when Cyclist is actually running
- [ ] Detection adds negligible latency (no HTTP, no subprocess — filesystem + signal only)
- [ ] PID file written alongside port file on Cyclist startup
- [ ] PID file cleaned alongside port file on Cyclist shutdown
- [ ] Stale `.cyclist-port` files without matching live PID are treated as "not running"
- [ ] Existing tests updated, new tests for stale-file scenarios

## Architect Recommendation

**Recommended Fix:** Add PID validation to Python's `is_cyclist_running()`:

1. **Implementation** (fast, no HTTP needed):
   - Read `.cyclist-pid` file; if present, verify process alive via `os.kill(pid, 0)`
   - Return `False` if PID file missing or process dead (even if `.cyclist-port` exists)
   - Fallback: check `.cyclist-port` exists as secondary confirmation

2. **Edge Cases:**
   - **PID recycling:** Low risk on modern systems for short-lived checks; acceptable
   - **Permission errors on os.kill:** Return `True` (conservative — assume Cyclist alive if different user)
   - **Stale files (no PID file, port file exists):** Return `False`

3. **Cleanup Strategy:** Just return `False`; let Cyclist's own startup handle stale file cleanup. No duplicate cleanup logic.

4. **Shell Scripts:** Python hooks only for now. Shell scripts rarely hit the false-positive path. Revisit if shell scripts also report issues.

**Effort:** ~15 lines Python, no breaking changes. Follows existing TypeScript PID pattern.

---

## SM → TEA Handoff

**From:** SM (Leo McGarry)
**To:** TEA (Sam Seaborn)
**Phase:** red (TDD — write tests first)
**Date:** 2026-02-10

### Context for TEA

- Story 98-8 is a bug fix: `is_cyclist_running()` false positives in CLI mode
- Cyclist already has `.cyclist-pid` + `isProcessRunning()` on TypeScript side
- Python side needs to read `.cyclist-pid` and validate with `os.kill(pid, 0)`
- See Architect Recommendation in session for edge cases (PID recycling, permission errors)
- Scope is narrow: ~15 lines Python in `hooks.py`, verify TS PID lifecycle in `server.ts`
- Existing test file: `tests/python/test_pretooluse_hook.py`

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core bug fix — `is_cyclist_running()` gives false positives in CLI mode

**Test Files:**
- `tests/python/test_pretooluse_hook.py` — `TestIsCyclistRunning` class (8 tests)

**Tests Written:** 8 tests covering 5 of 7 ACs (ACs 4-5 are TypeScript lifecycle, Dev scope)

| Test | AC | Status |
|------|-----|--------|
| `test_returns_false_when_no_files_exist` | baseline | PASS |
| `test_returns_false_when_port_file_exists_but_no_pid_file` | AC6 | FAIL (RED) |
| `test_returns_false_when_port_and_pid_exist_but_process_dead` | AC1 | FAIL (RED) |
| `test_returns_true_when_port_and_pid_exist_and_process_alive` | AC2 | PASS |
| `test_returns_false_when_pid_file_has_invalid_content` | AC1 | FAIL (RED) |
| `test_returns_false_when_pid_file_is_empty` | AC1 | FAIL (RED) |
| `test_returns_true_on_permission_error` | AC2 edge | PASS |
| `test_no_http_calls_made` | AC3 | PASS |

**Status:** RED (4 failing, 4 passing — all failures are assertion errors)
**Commit:** `e0b99e62b` on `feature/98-8-cyclist-false-positive-detection`

**Notes for Dev:**
- All failures are `assert True is False` — current impl returns `True` for any `.cyclist-port` existence
- Dev needs: add PID constant + `read_cyclist_pid()` + `is_pid_alive()` helpers to `hooks.py`
- TS side: verify `writePidFile()` is always called alongside `writePortFile()` (ACs 4-5)
- The `os.kill` patch target in permission error test assumes Dev will use `os.kill` in implementation

**Handoff:** To Dev (Toby Ziegler) for implementation

---

## TEA → Dev Handoff

**From:** TEA (Sam Seaborn)
**To:** Dev (Toby Ziegler)
**Phase:** implement (make tests pass)
**Date:** 2026-02-10
**Test State:** RED — 4 failing tests in TestIsCyclistRunning

### What Dev Needs to Do
1. Add `CYCLIST_PID_FILE = ".cyclist-pid"` constant to `hooks.py`
2. Add `read_cyclist_pid(root)` helper — read and parse `.cyclist-pid` file
3. Add `is_pid_alive(pid)` helper — `os.kill(pid, 0)` with PermissionError → True
4. Rewrite `is_cyclist_running()` to check PID file + validate process liveness
5. Verify TypeScript side: `writePidFile()` called alongside `writePortFile()` in `main.ts`
6. Run tests: `python -m pytest tests/python/test_pretooluse_hook.py::TestIsCyclistRunning -v`

---

## Dev Assessment

**Implementation Complete:** Yes
**Approach Change:** Discarded PID-based approach in favor of `CYCLIST=1` env var already set by `ClaudeService.spawn()` in `claude-service.ts:443`. Simpler, no file I/O, no race conditions, no stale state.

**Files Changed:**
- `pennyfarthing_scripts/hooks.py` — Rewrote `is_cyclist_running()` to check `os.environ.get("CYCLIST") == "1"`
- `tests/python/test_pretooluse_hook.py` — Replaced 8 PID-based tests with 6 env-var tests

**Tests:** 30/30 passing (GREEN), 0 regressions
**PR:** #789 — fix(98-8): use CYCLIST env var for Cyclist detection
**Branch:** feature/98-8-cyclist-false-positive-detection (pushed)

**Note:** ADR needed to document the env-var detection pattern. Handing to Architect before Reviewer.

**Handoff:** To Architect (Will Bailey) for ADR, then to Reviewer

---

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `CYCLIST=1` env var set at `claude-service.ts:443` → inherited by spawned Claude process → read by `os.environ.get("CYCLIST")` at `hooks.py:425` → gates hook behavior in `pretooluse_hook.py:118` and `welcome_hook.py:140`. Safe — env vars are process-scoped and cannot be left stale on disk.

**Pattern observed:** Dev correctly discarded the PID-based approach from the Architect recommendation in favor of an already-deployed env var (`CYCLIST=1` in ClaudeService since inception). This is a better solution — zero I/O, zero race conditions, zero stale state. ADR-0023 documents the decision thoroughly.

**Error handling:** `os.environ.get("CYCLIST")` returns `None` when absent, which `!= "1"` → `False`. Cannot throw. No error path needed. Verified at `hooks.py:425`.

**Observations:**
1. `[VERIFIED]` Core bug fix works — stale `.cyclist-port` files no longer cause false positives (`test_returns_false_when_stale_port_file_exists`)
2. `[VERIFIED]` `CYCLIST=1` always set in `ClaudeService.spawn()` at `claude-service.ts:443` — positioned after all spreads, cannot be overridden
3. `[VERIFIED]` Shell scripts (`session-start.sh`, `bell-mode-hook.sh`, `otel-auto-config.sh`, `welcome-hook.sh`) still use `.cyclist-port` for port discovery — unaffected, correctly scoped
4. `[VERIFIED]` 6 tests cover all scenarios: CLI mode, stale files, valid env, wrong value, empty value, no I/O
5. `[LOW]` Vestigial `project_root` parameter kept for backward compat — documented in docstring, acceptable
6. `[VERIFIED]` ADR-0023 written and accepted, covers rationale and consequences
7. `[VERIFIED]` Lint fixed — removed unused imports, sorted import blocks. Only pre-existing E402 remains (structural `sys.path.insert` pattern).

**Tests:** 30/30 passing, 0 regressions
**Lint:** Clean on `hooks.py`. Pre-existing E402 only on test file.

**Handoff:** To SM (Leo McGarry) for finish-story

---

## Phase History

| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| review | 2026-02-10T12:00:00Z | 2026-02-10T12:52:17Z | 52m 17s |

---

## Handoff History

| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| review (reviewer) | finish (sm) | approval | PASSED | 2026-02-10T12:52:17Z |
