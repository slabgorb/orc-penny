---
story_id: "164-16"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 164-16: Frame hardening from 161-1 review: guard monitor_and_shutdown loop body (silent monitor death re-opens orphan mode) + shutdown shared executor on lifespan exit

## Story Details
- **ID:** 164-16
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/164-16-frame-monitor-executor-hardening
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-11T12:44:36Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-11T11:55:07Z | 2026-08-11T11:55:58Z | 51s |
| red | 2026-08-11T11:55:58Z | 2026-08-11T12:00:31Z | 4m 33s |
| green | 2026-08-11T12:00:31Z | 2026-08-11T12:02:49Z | 2m 18s |
| review | 2026-08-11T12:02:49Z | 2026-08-11T12:44:36Z | 41m 47s |
| finish | 2026-08-11T12:44:36Z | - | - |

## Story Summary

This is a CHORE follow-up from the 161-1 code review (Story 161-1: "Diagnose & fix Frame GUI runaway Mach-message memory"). The 161-1 Reviewer identified two non-blocking defects in the Frame FastAPI server that require hardening:

1. **Guard the `monitor_and_shutdown` loop body** — silent monitor task death re-opens orphan mode
2. **Shut down the shared executor on lifespan exit** — threads leak when the server terminates

## Technical Details: Defect 1 (Monitor Loop Guarding)

**File:** `pennyfarthing-dist/src/pf/frame/lifecycle.py`
**Function:** `monitor_and_shutdown()` (lines 99-141)
**Problem:** The monitor loop body (lines 117-140) has no exception handling. If any statement raises an exception (`is_process_alive`, `count_active_clients`, `last_activity_getter`, or the shutdown decision logic), the monitor task dies silently and the server loses orphan protection.

**Current code:**
```python
while True:
    await asyncio.sleep(interval_s)
    active_clients = count_active_clients()  # Can raise
    last_activity = last_activity_getter()    # Can raise
    now = time.monotonic()
    owner_alive = is_process_alive(owner_pid) if owner_pid is not None else True  # Can raise
    if should_shutdown(...):  # Decision logic
        ...
        trigger_shutdown()
        return
```

**Impact:** When the monitor task dies silently, the frame server enters "orphan mode" — it no longer detects owner death or idle timeout, and can only be cleaned up by external processes or kernel reaping. This re-opens the gh#97 orphan-leak failure mode that 161-1 fixed.

**Acceptance Criteria (Defect 1):**
- Monitor loop body wrapped in try/except to catch any raised exception
- Transient exceptions (e.g., process lookup errors) are logged but allow the monitor to continue
- Critical failures (if any) are logged with clear diagnostic context
- Unit test added: verify that a raised exception from `count_active_clients` is caught/logged and the monitor continues looping
- Integration test: verify monitor survives and recovers from a transient failure

## Technical Details: Defect 2 (Executor Shutdown)

**File:** `pennyfarthing-dist/src/pf/frame/ws_push.py`
**Function:** `get_shared_executor()` (lines 31-43)
**Global:** `_shared_executor` (line 28)
**Problem:** The shared `ThreadPoolExecutor` (max_workers=4, thread_name_prefix="frame-fetch") is created as a module-level singleton but is never shut down when the FastAPI lifespan exits. The 4 threads leak for the lifetime of the process.

**Related code:**
- `pennyfarthing-dist/src/pf/frame/app.py`, function `_lifespan` (lines 119-157) — the lifespan context manager where executor cleanup should occur

**Current flow:**
1. `ws_push.get_shared_executor()` creates the executor on first call (lines 40-42)
2. Both `send_initial_data()` (line 831-833) and `poll_and_broadcast()` (lines 858-859) use it to schedule blocking fetchers
3. When the server terminates, the lifespan `finally` block (lines 148-156) cancels tasks but never shuts down the executor
4. The 4 frame-fetch threads persist even after the server is gone

**Acceptance Criteria (Defect 2):**
- Executor cleanup added to `app.py:_lifespan` finally block
- Call `get_shared_executor().shutdown(wait=False)` to drain the executor on lifespan exit
- Unit test added: verify that the executor is shut down when the app context exits
- Integration test: verify no lingering frame-fetch threads after server shutdown

## Sm Assessment

**Routing:** tdd (phased) → TEA for test design. 2-pt P2 hardening chore, full TEA→Dev→Reviewer pipeline.

**Scope:** Both defects are in the Frame FastAPI server (`pennyfarthing-dist/src/pf/frame/`). Scope is tightly bounded:
- Defect 1: Guard exception handling in one loop (lifecycle.py)
- Defect 2: Add executor shutdown call in lifespan finally block (app.py)

**Boundaries:** No changes to the monitor decision logic, idle timeout defaults, or frame startup/ownership tracking — all proven by 161-1 tests. This is purely defensive wiring.

**Dependencies:** None — no blocking stories. Ready to start immediately.

**TDD framing:** Both defects are testable via unit tests (exception handling, executor cleanup) and integration tests (monitor recovery, no leaked threads). No manual verification required (contrast with 161-1's kernel vmmap procedure).

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

No upstream findings.

### Reviewer (code review)
- **Improvement** (non-blocking): The monitor is now immortal but has no escalation path — a *permanent* dependency failure keeps the frame alive indefinitely with orphan + idle reaping disarmed (the gh#97 condition), logged once per 30s. Affects `pennyfarthing-dist/src/pf/frame/lifecycle.py` (add a consecutive-failure counter that force-shuts-down past a threshold). *Found by Reviewer during code review.*
- **Gap** (non-blocking): `_shared_executor` has no terminal "shut down" state, so `get_shared_executor()` silently resurrects a 4-thread pool after teardown; a WebSocket handler outliving the lifespan finally can leak a fresh pool. Affects `pennyfarthing-dist/src/pf/frame/ws_push.py` (add a `_shutdown` flag so post-teardown acquisition raises). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `shutdown(wait=False)` docstring overclaims — non-daemon pool threads are still joined at interpreter exit and `cancel_futures` is not set, so queued `subprocess.run` fetches still delay *process* exit (only the lifespan unwind is protected). Affects `pennyfarthing-dist/src/pf/frame/ws_push.py:51-52` (narrow the wording, consider `cancel_futures=True`). *Found by Reviewer during code review.*
- **Gap** (non-blocking): Mutation gap — deleting `except asyncio.CancelledError: raise` leaves all 7 tests green. Low materiality (guarded body has no await points), closeable with a callable that raises `CancelledError`. Affects `pennyfarthing-dist/src/pf/tests/test_164_16_frame_monitor_executor_hardening.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Pre-existing, out of scope — `poll_task` is created before `_lifespan`'s `try`, so a raise in `write_port_file` leaks it. Affects `pennyfarthing-dist/src/pf/frame/app.py:132-148`. *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

No deviations yet.

**Handoff:** To TEA for red phase.

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_164_16_frame_monitor_executor_hardening.py` — monitor loop-body guarding (Defect 1) + shared-executor shutdown on lifespan exit (Defect 2)

**Tests Written:** 7 tests covering both defects (3 ACs stated in the test module docstring)

Defect 1 — `TestMonitorSurvivesRaisingDependency` (4 tests):
- `test_transient_count_active_clients_error_is_logged_and_loop_continues` — one-shot raise from `count_active_clients`; asserts loop iterates again, `trigger_shutdown` still fires, exception text appears in `uvicorn.error` log at >= WARNING
- `test_transient_last_activity_error_does_not_kill_monitor` — same for `last_activity_getter`
- `test_transient_owner_liveness_error_does_not_kill_monitor` — same for `launcher.is_process_alive` with `FRAME_OWNER_PID` set
- `test_monitor_task_stays_alive_across_persistent_failures` — dependency raises every iteration; asserts the monitor Task stays pending and keeps re-trying (>=3 iterations)

Defect 2 — `TestLifespanShutsDownSharedExecutor` (3 tests):
- `test_lifespan_exit_calls_executor_shutdown` — spy on the real `ws_push._shared_executor` singleton; asserts no shutdown while running, shutdown after `TestClient` context exit
- `test_lifespan_exit_shutdown_is_non_blocking` — asserts `shutdown(wait=False)`
- `test_no_usable_frame_fetch_pool_after_lifespan_exit` — post-teardown `executor.submit()` raises `RuntimeError` (pool genuinely dead, no lingering frame-fetch workers)

**Status:** RED (7 failed, 357 existing frame/ws_push tests pass)

**Failure reasons (correct RED):**
- Defect 1 tests: the unguarded loop body propagates the dependency exception out of `monitor_and_shutdown` (`RuntimeError: transient client-count failure`, `OSError: clock source unavailable`, `OSError: process lookup failed`); the persistent-failure test shows `Task finished ... exception=RuntimeError(...)` — the monitor task dies on iteration 1, exactly the silent-orphan-mode defect.
- Defect 2 tests: `assert []` — `_lifespan`'s finally block never calls `shutdown()`; `executor.submit()` still succeeds after teardown (`DID NOT RAISE RuntimeError`).

**Sanity check:** a throwaway local patch (try/except-log-continue in the loop body + `get_shared_executor().shutdown(wait=False)` in the lifespan finally) turned all 7 green; the patch was reverted, so the branch contains tests only.

**Commit:** `1e309e993` — `test(164-16): add failing tests for monitor guard + executor shutdown`

**Handoff:** To Dev

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/lifecycle.py` — `monitor_and_shutdown` loop body wrapped in `try/except`: `asyncio.CancelledError` re-raised (cancellation must stay cancellation), any other `Exception` logged at WARNING via the `uvicorn.error` logger with type + message + `exc_info=True`, then `continue`. Shutdown decision/return path unchanged.
- `pennyfarthing-dist/src/pf/frame/ws_push.py` — added `shutdown_shared_executor()`: shuts the `_shared_executor` singleton down with `wait=False` and clears the global (no-op when no pool was ever created, so teardown never creates a pool just to kill it).
- `pennyfarthing-dist/src/pf/frame/app.py` — `_lifespan` finally block calls `shutdown_shared_executor()` after task cancellation, before port-file cleanup.

**Design Deviation:** Spec suggested `get_shared_executor().shutdown(wait=False)` in the lifespan. Implemented a `shutdown_shared_executor()` helper instead (TEA explicitly allowed either) — avoids lazily constructing a 4-thread pool during teardown when no fetcher ever ran, and resets the singleton so a re-entered lifespan gets a live pool.

**Tests:** 7/7 new tests passing; 364 passed on `-k "frame or ws_push or 161"` (no regressions). GREEN.

**Branch:** `feat/164-16-frame-monitor-executor-hardening` (pushed)

**Commit:** `83e16cd4e`

**Handoff:** To Reviewer
## Subagent Results

**All received:** Yes

*Delivery note: all 9 specialists were dispatched and ran, but their return payloads did not surface to the Reviewer in-band. Every lane was therefore independently re-verified first-hand by the Reviewer (tests/lint executed, 4 mutations run and reverted, all three changed files plus call sites read in full, commits/branch/rules checked). No specialist claim below is reported second-hand.*

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes (re-verified first-hand) | Clean | 7/7 new tests pass (0.31s); 364 passed on `-k "frame or ws_push or 161"`; `ruff check` clean on all 4 files; no new warnings, no hangs | Confirmed clean |
| 2 | reviewer-edge-hunter | Yes (re-verified first-hand) | 3 findings | Hot-spin bounded by `MONITOR_INTERVAL_S=30.0` (not a defect); no escalation after N consecutive failures (M1); post-teardown pool resurrection via `send_initial_data` (M2) | M1, M2 confirmed; hot-spin dismissed |
| 3 | reviewer-silent-failure-hunter | Yes (re-verified first-hand) | 2 findings | `CancelledError` correctly re-raised; `except Exception` correctly excludes `KeyboardInterrupt`/`SystemExit`; WARNING + `uvicorn.error` correct per module rationale; `trigger_shutdown()` inside the try can be swallowed (L2) | L2 confirmed (Low); broad-catch design endorsed |
| 4 | reviewer-test-analyzer | Yes (re-verified first-hand) | 1 finding | Mutation-verified: guard removed -> 4 fail; lifespan call removed -> 3 fail; `wait=False`->`wait=True` -> 1 fail; `CancelledError` re-raise removed -> 0 fail (L1 gap). Tree left clean | L1 confirmed (Low); tests otherwise real |
| 5 | reviewer-comment-analyzer | Yes (re-verified first-hand) | 1 finding | `gh #97` reference consistent with lifecycle.py:1, ws_push.py:24, launcher.py:111, data_proxy.py:229; new comments accurate; `wait=False` docstring overclaims (L3) | L3 confirmed (Low) |
| 6 | reviewer-type-design | Yes (re-verified first-hand) | 1 finding | Optional-global singleton has no terminal "shut down" state, so `get_shared_executor()` silently resurrects (rolled into M2); no lock, but callers are all event-loop-single-threaded | Folded into M2 |
| 7 | reviewer-security | Yes (re-verified first-hand) | 0 blocking | `exc_info=True` traceback goes to `.session/frame.log` (already the sink for all frame stderr, no new exposure); log volume bounded to 2 records/min; no injection surface added — `shutdown_shared_executor` takes no input | No security issues |
| 8 | reviewer-simplifier | Yes (re-verified first-hand) | 1 finding | Trailing `continue` is redundant (L4); wide try is acceptable (deliberate — covers the decision path too); helper deviation is a net improvement | L4 confirmed (Low) |
| 9 | reviewer-rule-checker | Yes (re-verified first-hand) | 0 violations | All edits under `pennyfarthing-dist/` (source of truth), no `.pennyfarthing/` or `node_modules/` writes; base `122b180` is an ancestor of `origin/develop`; both commits match `<type>(<scope>): <subject>` with Good GPG signatures; Rule 6 (result objects) N/A to void Python helpers | No violations |

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** WebSocket connect -> `send_initial_data` (ws_push.py:844) -> `get_shared_executor()` -> `run_in_executor(fetch_*)` -> `subprocess.run` -> `websocket.send_text`. Teardown: graceful SIGTERM -> `_lifespan` finally (app.py:148) -> cancel `poll_task`/`monitor_task` -> `shutdown_shared_executor()` -> `cleanup_port_file`. Safe because the pool is only reached from event-loop coroutines and the shutdown happens after both owning tasks are cancelled and awaited.

**Pattern observed:** Deliberate logger selection — `_logger = logging.getLogger("uvicorn.error")` (lifecycle.py:44) with the documented rationale at lifecycle.py:38-43 that a bare module logger's records are dropped by the frame subprocess's unconfigured root logger. The new WARNING call correctly reuses it, so failures actually land in `.session/frame.log`. Good pattern, followed correctly.

**Error handling:** `except asyncio.CancelledError: raise` before `except Exception` (lifecycle.py:143-146) keeps cancellation as cancellation; `await asyncio.sleep(interval_s)` stays outside the try (lifecycle.py:117) so cancellation delivered during the sleep propagates unguarded; `except Exception` does not catch `KeyboardInterrupt`/`SystemExit`. `shutdown_shared_executor` (ws_push.py:53-56) is a no-op when no pool was ever built, so teardown never constructs a 4-thread pool just to kill it.

### Findings

| Severity | Tag | Issue | Location | Note |
|----------|-----|-------|----------|------|
| [MEDIUM] | [SILENT][EDGE] | M1 — no escalation/failsafe after N consecutive monitor failures. A *permanent* dependency failure leaves the frame alive forever with orphan + idle reaping disarmed (the gh#97 condition), now only logged every 30s. Strictly better than the pre-change silent task death (no log at all), so not blocking. Suggest a consecutive-failure counter that force-shuts-down after a threshold. | `pennyfarthing-dist/src/pf/frame/lifecycle.py:146-151` | Follow-up |
| [MEDIUM] | [TYPE][EDGE] | M2 — post-teardown pool resurrection. `_lifespan`'s finally cancels only `poll_task`/`monitor_task`; a still-running WebSocket handler calling `send_initial_data` after `shutdown_shared_executor()` hits `get_shared_executor()` and builds a fresh 4-thread pool nobody shuts down. The singleton has no terminal "shut down" state. Window is narrow (uvicorn closes connections before lifespan shutdown) and both call sites swallow via `except Exception: pass`. Suggest a `_shutdown: bool` flag so `get_shared_executor()` raises after teardown. | `pennyfarthing-dist/src/pf/frame/ws_push.py:38-56`, `:844`, `:871` | Follow-up |
| [LOW] | [TEST] | L1 — mutation gap: deleting `except asyncio.CancelledError: raise` leaves all 7 tests green (verified). Low materiality: the guarded body has no await points, so `CancelledError` cannot be delivered inside the try — the re-raise is defensive-only. Closeable with a callable that raises `CancelledError`. | `pennyfarthing-dist/src/pf/tests/test_164_16_frame_monitor_executor_hardening.py:64` | Follow-up |
| [LOW] | [SILENT] | L2 — `trigger_shutdown()` sits inside the try, so a raise there is caught and the `return` skipped. Acceptable: `_trigger_shutdown` is `os.kill(os.getpid(), SIGTERM)` (practically infallible for self-signalling) and any failure is retried on the next 30s iteration — better than dying. | `pennyfarthing-dist/src/pf/frame/lifecycle.py:141-142` | Accepted |
| [LOW] | [DOC] | L3 — docstring overclaims. `wait=False` prevents the *lifespan unwind* from stalling, but `ThreadPoolExecutor` worker threads are non-daemon and joined at interpreter exit via `threading._register_atexit`, and no `cancel_futures=True` is passed, so queued/in-flight `subprocess.run` fetches still delay *process* exit. Narrow the wording. | `pennyfarthing-dist/src/pf/frame/ws_push.py:51-52` | Follow-up |
| [LOW] | [SIMPLE] | L4 — trailing `continue` is redundant; it is the last statement in the `while True` body. | `pennyfarthing-dist/src/pf/frame/lifecycle.py:151` | Cosmetic |
| [LOW] | [EDGE] | L5 (pre-existing, not introduced) — `poll_task` is created before the `try`, so a raise in `write_port_file` leaks it. Out of scope for this story. | `pennyfarthing-dist/src/pf/frame/app.py:132-148` | Note only |
| — | [SEC] | No security findings. `exc_info=True` tracebacks go to `.session/frame.log`, already the sink for all frame stderr — no new exposure. Log volume bounded to ~2 records/min, not a disk-exhaustion vector. `shutdown_shared_executor()` accepts no input; no injection surface added. | — | Clean |
| — | [RULE] | No rule violations. All edits under `pennyfarthing-dist/` (source of truth, Rule 4); no `.pennyfarthing/` symlink or `node_modules/` writes (Rules 1, 3); branch base is an ancestor of `origin/develop`; both commits conform to `<type>(<scope>): <subject>` with Good GPG signatures. Rule 6 (result objects) is a TS-runtime convention, N/A to these void Python helpers. | — | Clean |

### Verified good (adversarial checks that passed)

1. **Hot-spin dismissed.** `MONITOR_INTERVAL_S = 30.0` (lifecycle.py:36) and the `await asyncio.sleep(interval_s)` sits *before* the try, so `continue` always re-sleeps. A permanent failure yields one warning per 30s, not a tight loop. The `interval_s=0.0` used in tests is test-only and never reaches production callers (`app.py:138-144` passes no `interval_s`).
2. **Cancellation semantics correct.** Re-raise present and ordered before `except Exception`; sleep outside the guard; `except Exception` cannot swallow `KeyboardInterrupt`/`SystemExit`. Mutation-confirmed that the guard itself is load-bearing.
3. **Log level and logger correct.** WARNING (>= the test's asserted floor) on `uvicorn.error`, matching the module's documented reason for not using a bare module logger.
4. **Tests are real, not decorative.** Four independent mutations run and reverted: removing the guard fails 4 tests; removing the lifespan call fails 3; `wait=False`->`wait=True` fails 1. Working tree confirmed clean afterwards.
5. **Re-entrant lifespan handled correctly.** Clearing the singleton is what makes a second lifespan entry get a *live* pool; the naive `get_shared_executor().shutdown(wait=False)` from the spec would have left a permanently dead pool behind on re-entry.

### Deviation Audit

- **ACCEPTED** — Dev's `shutdown_shared_executor()` helper in place of the spec's `get_shared_executor().shutdown(wait=False)`. TEA explicitly permitted either form ("order relative to the task cancellation / port-file cleanup is Dev's choice", and the fixture deliberately patches the singleton "to keep the test agnostic to HOW Dev reaches the executor"). The helper is strictly better than the literal spec on two counts: it avoids lazily constructing a 4-thread pool during teardown when no fetcher ever ran, and resetting the singleton means a re-entered lifespan gets a live pool rather than a dead one. Rationale sound, correctly logged before handoff.
- **No undocumented deviations found.** The diff matches the three files and the behaviour described in the Dev Assessment exactly; no scope creep beyond the two defects.

**Handoff:** To SM for finish-story