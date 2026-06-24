---
story_id: "159-8"
jira_key: null
epic: null
workflow: "tdd"
---
# Story 159-8: Frame kills live sessions (161-1 regression): ephemeral owner PID on hook/launch auto-start + idle-timeout blind to OTLP/HTTP traffic

## Story Details
- **ID:** 159-8
- **Jira Key:** null
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-24T09:57:47Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-24T00:00:00Z | 2026-06-24T08:59:47Z | 8h 59m |
| red | 2026-06-24T08:59:47Z | 2026-06-24T09:17:04Z | 17m 17s |
| green | 2026-06-24T09:17:04Z | 2026-06-24T09:41:25Z | 24m 21s |
| review | 2026-06-24T09:41:25Z | 2026-06-24T09:57:47Z | 16m 22s |
| finish | 2026-06-24T09:57:47Z | - | - |

## Branch
**Branch Strategy:** gitflow (feat/159-8-frame-self-term-liveness)
**Repo:** pennyfarthing (branched from develop)

## Design Reference
**ADR:** docs/adr/0040-frame-self-termination-liveness-contract.md
**Decision:** Option 3 (hybrid traffic-primary + optional hardened owner-PID fast-path) as target; Option 2 (traffic-only) as acceptable floor. Traffic signal (OTLP ingest + HTTP) is the reuse-proof primary liveness signal. Owner-PID is optional fast-path with identity verification (PID+create-time/ancestry) or dropped. Shorten idle window. Log shutdown reason.

**Coordination note:** 159-5 hardens the same monitor against silent death. Landing 159-5 before 159-8 would make the random-death MORE reliable (a regression hazard). 159-8 must land first, or the two land together.

## Sm Assessment

**Story:** 159-8 — p1 bug, 3 pts, `tdd`. A 161-1 regression: the Frame's self-termination monitor kills *live* sessions. Root cause confirmed empirically by the Architect (graceful self-SIGTERM in `.session/frame.log`, not an OOM/memory cap). Full diagnosis + design in **ADR-0040**; the 6 ACs are on the story (`pf sprint story field 159-8 acceptance_criteria`) and in `sprint/context/context-story-159-8.md`.

**Routing:** Standard phased TDD — SM → **TEA (RED)** → Dev (GREEN) → Reviewer. 3 pts, so TEA writes failing tests first (no trivial skip). This story is implementation-bearing in `pennyfarthing/` only.

**Merge gate:** Clear — no open PRs in orchestrator or pennyfarthing at setup time.

**Repo/branch:** `pennyfarthing/` (gitflow), branch `feat/159-8-frame-self-term-liveness` off `develop`. Orchestrator-side design artifacts (story YAML, ADR-0040, architect sidecar) remain uncommitted on `chore/sprint-160-peloton` and ride along for the eventual sprint commit.

**For Thufir (TEA):** The design is settled — don't re-litigate it. Write the four RED integration tests ADR-0040 names (these are exactly what 161-1 lacked): (1) ephemeral-launcher-exits-while-session-lives → frame must NOT self-terminate; (2) zero WS clients + live OTLP traffic → not idle; (3) recycled-PID → decision unchanged; (4) per-path owner correctness across all three start paths. Keep 161-1's pure `should_shutdown` unit tests green — extend, don't replace. The ADR leaves owner-PID hardening-vs-removal to Dev's discretion, so write the outcome-level assertions (no live session killed, no recycled PID trusted) rather than coupling tests to one mechanism.

**Jira:** Skipped — `jira: null`; sprints are local-only here.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): User-supplied ground truth sharpened the diagnosis — `just frame` then `claude` drops the frame, `just frame` then TUI does not. The TUI holds WebSocket clients (`active_clients > 0`) which suppresses the idle monitor; the CLI holds zero WS clients and speaks only OTLP/HTTP, so today its traffic never refreshes activity. This pins **Defect 2 (traffic-as-liveness)** as the dominant failure in the explicit-launch workflow and is now the headline RED test. Affects `pennyfarthing-dist/src/pf/frame/app.py` (`_touch_activity` must fire on OTLP ingest + HTTP). *Found by TEA during test design.*
- **Gap** (non-blocking): The `subagent-event` broadcast at `routes/state.py:506` uses `asyncio.ensure_future(...)` inside a sync-reachable handler and swallows all exceptions (`except Exception: pass`, lang-review #1). Out of scope for 159-8 but adjacent to the touched code. Affects `pennyfarthing-dist/src/pf/frame/routes/state.py` (consider a follow-up). *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): The three OTLP ingest handlers (`/v1/logs`, `/v1/metrics`, `/v1/traces`) each wrap their body in `except Exception: pass` — same silent-swallow pattern TEA flagged at `routes/state.py:506`. Liveness is unaffected (the new http middleware refreshes activity before the handler runs, so even a malformed payload correctly counts as traffic), but parse/broadcast failures are invisible. Affects `pennyfarthing-dist/src/pf/frame/app.py` (a follow-up could log at debug/warning instead of swallowing). *Found by Dev during implementation.*
- **Improvement** (non-blocking): The full Python suite has 45 pre-existing failures unrelated to this change (`test_145_5_pptx_assembler.py` ×29, `test_peloton_portrait_panes.py` ×10, `test_143_9_tdd_cycle_e2e.py` ×4, `test_init_justfile.py` ×1, `session/test_cache.py` error). None import the frame modules touched here; this repo has no CI so `develop` carries stale failures. Affects nothing in 159-8 scope — flagged so the Reviewer doesn't attribute them to this PR. *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): The 300s idle default assumes a live claude session emits inbound traffic at least every 5 min. Verified the keepalive is OTLP telemetry (the OTEL periodic metric reader, ~60s) — NOT the statusline hook, which only reads the OTEL port from env for display and never calls the frame. If a future change disables/slows OTLP metric export, an idle-but-alive CLI session could be reaped. Mitigation exists (`FRAME_IDLE_TIMEOUT_S`). Affects `pennyfarthing-dist/src/pf/frame/lifecycle.py` (revisit the value if users report idle-session drops). *Found by Reviewer during code review.*
- **Gap** (non-blocking): The owner-dead reason branch in `monitor_and_shutdown` (`reason = f"owner {owner_pid} dead"`) has no test — the only `monitor_and_shutdown` test exercises the idle branch. It is non-production-reachable under Option 2 (no owner PID is ever set), so this is a latent/future-path coverage gap, not a live bug. A future story that re-wires owner-PID must add a test for this branch. Affects `pennyfarthing-dist/src/pf/tests/test_159_8_frame_liveness.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Latent design note — the new http middleware treats *any* inbound request as liveness, including `/health`. No periodic, session-outliving `/health` poller exists today (all callers are one-shot startup probes or session-driven hooks), so orphan reaping is preserved. But if a future monitoring loop polls `/health` on a timer, it would keep an orphaned frame alive indefinitely. Affects `pennyfarthing-dist/src/pf/frame/app.py` (consider exempting `/health` from activity refresh if such a poller is ever added). *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Owner tests assert the universal invariant, not a specific owner-PID mechanism**
  - Spec source: context-story-159-8.md, AC5 ("All three start paths register a correct long-lived owner; a test asserts owner correctness per path")
  - Spec text: "a test asserts owner correctness per path"
  - Implementation: `TestOwnerIdentityPerPath` asserts the frame is *never owned by the ephemeral launching process* (hook/launch paths) and that the exec path's default owner is the caller-or-unset — rather than asserting a concrete `start_frame(owner_pid=...)` parameter exists.
  - Rationale: ADR-0040 AC4 explicitly lets Dev EITHER harden owner-PID OR drop it for the traffic signal. Coupling the tests to an `owner_pid` parameter would fail the valid traffic-only floor (Option 2). The invariant "not the ephemeral launcher" holds under both options and still fails RED today.
  - Severity: minor
  - Forward impact: none — Dev keeps full AC4 latitude; tests pass whichever mechanism is chosen.
- **No standalone recycled-PID identity test (Category 3 / AC4 partial)**
  - Spec source: context-story-159-8.md, AC4 + "RED Tests to Write" #3 ("Recycled-PID scenario → shutdown decision unchanged")
  - Spec text: "robust against PID reuse (identity verified beyond bare os.kill(pid,0) — e.g. PID+create-time or ancestry), OR owner-PID gating is removed"
  - Implementation: deferred — no unit test pins the recycled-PID case directly.
  - Rationale: a faithful recycled-PID test must target the *chosen* verification mechanism (create-time vs ancestry), which AC4 leaves to Dev; under the traffic-only floor it is vacuous (no PID to recycle-fool). Writing it now would either couple to one mechanism or be a no-op. Dev MUST add the identity test alongside the implementation IF owner-PID is retained.
  - Severity: minor
  - Forward impact: Dev (green phase) — add a recycled-PID identity test if Option 3 (owner-PID retained) is implemented; Reviewer to confirm Category 3 coverage.
- **`test_exec_path_owner_defaults_to_caller` is an intentional green-on-HEAD guard**
  - Spec source: context-story-159-8.md, AC5 (exec path) + AC: "161-1 lifecycle test baseline stays green"
  - Spec text: "All three start paths ... register a correct long-lived owner"
  - Implementation: the exec-path test passes today (owner == caller is CORRECT there because `os.execvpe` preserves the PID); it is a preservation guard, not a RED driver.
  - Rationale: per the `ac-as-green-regression-guard` pattern — an AC that pins UNCHANGED-correct behavior is correctly green; forcing a spurious RED would be dishonest. It guards against Dev breaking the one path where caller-as-owner is right.
  - Severity: trivial
  - Forward impact: none.

### Dev (implementation)
- **Shipped Option 2 (traffic-only), not the Option 3 target — owner-PID gating removed, not hardened**
  - Spec source: Design Reference (session L33) + context-story-159-8.md, AC4
  - Spec text: "Option 3 (hybrid ...) as target; Option 2 (traffic-only) as acceptable floor" / AC4: "robust against PID reuse (identity verified ...), OR owner-PID gating is removed in favor of the traffic signal"
  - Implementation: `start_frame` no longer stamps `FRAME_OWNER_PID` on any path; the production liveness signal is traffic/clients only. The env-driven owner machinery in `lifecycle.py` (`resolve_owner_pid`, the `should_shutdown` owner branch) is retained but unwired (kept green by 161-1's unit tests; available for a future hardened fast-path).
  - Rationale: a bare `os.kill(pid,0)` owner check cannot satisfy AC4's "must not be fooled by a recycled PID"; the only AC4-compliant ways to *retain* it are create-time/ancestry identity verification — which requires the recycled-PID identity test TEA deferred (a RED round-trip) — or removal. The exec-path fast-path is near-vestigial (ADR consequences: manual `pf frame start` "no longer needed"), and with the idle window shortened, orphans are reaped promptly without it. AC4 explicitly sanctions removal, so this is the floor, not a violation.
  - Severity: minor
  - Forward impact: 159-5 (hardens the same monitor) — the monitor's only production shutdown trigger is now idle-timeout; the owner branch never fires in production. TEA's deferred recycled-PID identity test is resolved by *not retaining* owner-PID and need not be added. A future story wanting instant exec-path reaping must add ancestry/create-time verification **and** that test before re-wiring an owner PID.
- **Default idle window set to 300s (ADR said "shorten" without a value)**
  - Spec source: context-story-159-8.md, ADR-0040 decision point 3
  - Spec text: "Shorten the idle window ... (Tunable via FRAME_IDLE_TIMEOUT_S; default reduced from 1800 s.)"
  - Implementation: `DEFAULT_IDLE_TIMEOUT_S` 1800.0 → 300.0.
  - Rationale: with owner-PID gating removed, the idle window is the sole orphan reaper, so it must be prompt; 5 min balances prompt reaping against safety margin over a live session's OTLP cadence (telemetry refreshes activity far more often than 300s, so a live session never trips it). Value left to Dev by the ADR; env-tunable if observation shows live-idle sessions need longer.
  - Severity: minor
  - Forward impact: 159-5 — shares this window as the now-primary reaping signal. No test pins the value (161-1 asserts only `> 0`).
- **Shutdown reason logged via the `uvicorn.error` logger, not a module-named logger**
  - Spec source: context-story-159-8.md, AC6
  - Spec text: "The self-termination path emits a log line stating the reason"
  - Implementation: `lifecycle._logger = logging.getLogger("uvicorn.error")`.
  - Rationale: the frame subprocess runs under uvicorn, which configures only the `uvicorn.*` loggers; a bare `__name__` logger's INFO record is dropped by the unconfigured root logger and never reaches `.session/frame.log` — defeating the diagnosability AC6 exists for. `uvicorn.error` routes to stderr (→ frame.log) in production and still propagates to root (→ `caplog`) under test.
  - Severity: trivial
  - Forward impact: none.

### Reviewer (audit)
Every TEA and Dev deviation reviewed; verdicts below.
- **TEA #1 (owner tests assert universal invariant)** → ✓ ACCEPTED: the mechanism-agnostic assertion is exactly right given ADR-0040 AC4's explicit harden-or-drop latitude; coupling to an `owner_pid` param would have failed the valid Option-2 floor.
- **TEA #2 (no standalone recycled-PID test)** → ✓ ACCEPTED, now MOOT: Dev chose Option 2 (no owner PID stamped in production), so there is no PID to recycle-fool — the deferred Category-3 test is vacuous under the shipped design and correctly omitted. Re-confirm only if a future story re-introduces owner-PID gating.
- **TEA #3 (exec-path green-on-HEAD guard)** → ✓ ACCEPTED: an AC that pins unchanged-correct behavior is legitimately green; the `owner in (None, str(os.getpid()))` tolerance keeps it valid under Option 2 (owner unset).
- **Dev #1 (Option 2 — owner-PID gating removed, not hardened)** → ✓ ACCEPTED: AC4 explicitly sanctions removal "in favor of the traffic signal," and a bare `os.kill(pid,0)` check cannot satisfy "must not be fooled by a recycled PID." Verified the retained machinery (`resolve_owner_pid`, `should_shutdown` owner branch) stays green via the 161-1 unit tests and is never wired by a production caller (`grep` confirms no `start_frame(..., owner_pid=...)` and no `FRAME_OWNER_PID` write remains). Sound; this is the floor, not a violation.
- **Dev #2 (idle window 300s)** → ✓ ACCEPTED with a monitored caveat: ADR decision point 3 mandates shortening and leaves the value to Dev; 300s is reasonable given OTLP's ~60s keepalive cadence and is env-tunable. Residual risk (an idle-but-alive session with >5min telemetry silence) captured as a non-blocking Delivery Finding — it cannot reintroduce the dominant active-session-death bug and is tunable, so it does not block.
- **Dev #3 (`uvicorn.error` logger)** → ✓ ACCEPTED: verified uvicorn's default `LOGGING_CONFIG` gives `uvicorn.error` an INFO StreamHandler to stderr (→ `.session/frame.log`), so the reason is visible in production; in-test it propagates to root for `caplog`. Achieves AC6's diagnostic intent; a plain module logger would have been dropped by the frame subprocess's unconfigured root.

**No undocumented deviations found.** The diff matches what TEA/Dev logged; nothing diverged from spec without a corresponding entry.

## TEA Assessment

**Tests Required:** Yes
**Test File:** `pennyfarthing-dist/src/pf/tests/test_159_8_frame_liveness.py` (new)
**Tests Written:** 7 (6 RED + 1 intentional green preservation guard) covering all 6 ACs
**Status:** RED confirmed — `6 failed, 1 passed, 0 errored` (scoped run). 161-1 baseline: `15 passed` (AC6 preserved).

**RED failures verified on assertions (not import/collection errors):**
- AC "OTLP/HTTP traffic counts as activity" (Defect 2 — user-confirmed dominant): `test_otlp_logs_ingest_refreshes_activity`, `test_otlp_metrics_ingest_refreshes_activity`, `test_http_api_request_refreshes_activity` → `assert after > before` fails (activity clock frozen; e.g. `4145.94 > 4145.94`).
- AC "hook auto-start survives the session" / AC5 per-path owner (Defect 1): `test_hook_autostart_frame_not_owned_by_ephemeral_hook`, `test_launch_autostart_frame_not_owned_by_ephemeral_launcher` → `assert owner != str(os.getpid())` fails (`'10035' != '10035'` — frame owned by the calling process).
- AC "self-termination logs its reason" (AC6): `test_monitor_logs_shutdown_reason` → monitor triggers but logs nothing (`'idle' in '' or 'owner' in ''`).

**Green preservation guard:** `test_exec_path_owner_defaults_to_caller` (the `pf frame start` exec path correctly owns via the caller; logged as a deviation).

### Rule Coverage

| Rule (lang-review/python.md) | Test(s) | Status |
|------------------------------|---------|--------|
| #4 Logging coverage (lifecycle paths must log; not `print`) | `test_monitor_logs_shutdown_reason` | failing (RED) |
| #6 Test quality (meaningful assertions, no vacuous) | self-check below | pass |
| #9 Async pitfalls (monitor is async; reason-log path) | `test_monitor_logs_shutdown_reason` drives `monitor_and_shutdown` via `asyncio.run` | failing (RED) |

**Rules checked:** Defect class here is lifecycle/observability, not untrusted-input — #1 (silent except in `routes/state.py:506`) noted as an out-of-scope Delivery Finding rather than tested. #2/#3/#5/#7/#8/#10–#13 not applicable to this change surface.
**Self-check:** 0 vacuous assertions — every test asserts a specific value/relation (timestamp advance, owner inequality, log-content membership); no `assert True`, no truthy-only checks. The one green test asserts membership in a 2-element set, not a tautology.

**Handoff:** To Reverend Mother (Dev) for GREEN. Design authority is **ADR-0040**; the AC4 fork (harden owner-PID vs drop for traffic-only) is Dev's call — see the three Design Deviations. If Option 3 (owner-PID retained) is chosen, add a recycled-PID identity test (Category 3). The dominant, user-confirmed fix is Defect 2: wire `_touch_activity()` into OTLP ingest + HTTP requests.

## Dev Assessment

**Implementation Complete:** Yes
**AC4 fork resolved:** Option 2 (traffic-only liveness) — owner-PID gating removed, not hardened. See Design Deviations for the full rationale; no recycled-PID identity test was needed (no owner PID is ever trusted).

**Files Changed (pennyfarthing, commit `e1ecaa9c3`):**
- `pennyfarthing-dist/src/pf/frame/launcher.py` — `start_frame` no longer stamps `FRAME_OWNER_PID` (was unconditional `os.getpid()` = Defect 1). Reverted to the original single-arg signature.
- `pennyfarthing-dist/src/pf/frame/app.py` — added an `http` middleware that calls `_touch_activity()` on every inbound request, so OTLP ingest + HTTP API traffic counts as liveness (Defect 2).
- `pennyfarthing-dist/src/pf/frame/lifecycle.py` — `DEFAULT_IDLE_TIMEOUT_S` 1800→300s; `monitor_and_shutdown` now logs the shutdown reason (`idle: N clients, no traffic Ns` / `owner <pid> dead`) via the `uvicorn.error` logger before triggering (AC6).

**AC coverage:**
- AC1 (hook auto-start survives live session): ✓ no ephemeral owner stamped; traffic keeps it alive — `test_hook_autostart_frame_not_owned_by_ephemeral_hook`.
- AC2 (ended session reaped within bounded window): ✓ traffic stops on death → 300s idle window reaps.
- AC3 (OTLP + HTTP count as liveness): ✓ middleware — 3 traffic tests.
- AC4 (owner-PID reuse-robust OR removed): ✓ removed (Option 2).
- AC5 (all three paths register correct owner; test per path): ✓ exec=caller-or-none, hook=none, launch=none — never the ephemeral launcher — 3 owner tests.
- AC6 (self-termination logs reason; 161-1 baseline green): ✓ reason logged; 161-1 15/15 green.

**Tests:** 22/22 passing (GREEN) — 7 new (`test_159_8_frame_liveness.py`) + 15 161-1 baseline (`test_161_1_frame_resource_hygiene.py`). Plus 283/283 across the other frame test files (routes, server, websocket, launcher, isolation) — no regressions. Verified directly via `uv run pytest` (scoped). Full-suite failures (45) are pre-existing and in unrelated modules — see Delivery Findings.
**Branch:** `feat/159-8-frame-self-term-liveness` (pennyfarthing, off `develop`) — committed, push pending.

**Coordination:** 159-8 lands first per ADR-0040 (sequencing 159-5 ahead is a known regression hazard).

**Handoff:** To Leto II (Reviewer) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none (305 pass, ruff clean, 0 smells) | N/A |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — assessed directly ([EDGE]) |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — assessed directly ([SILENT]) |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings — assessed directly ([TEST]) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — assessed directly ([DOC]) |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings — assessed directly ([TYPE]) |
| 7 | reviewer-security | Yes | clean | none | N/A |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — assessed directly ([SIMPLE]) |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings — assessed directly ([RULE]) |

**All received:** Yes (2 enabled returned; 7 disabled via `workflow.reviewer_subagents`, domains self-assessed below)
**Total findings:** 0 blocking confirmed, 0 dismissed, 3 deferred (non-blocking Delivery Findings)

## Reviewer Assessment

**Verdict:** APPROVED

**Self-review note:** I authored this code as Dev. I ran the adversarial checklist against it as if hostile — independent grep tracing, the disabled subagents' domains self-assessed, and a deliberate hunt for an orphan-reaping regression. The findings below are real checks, not a rubber stamp.

**Data flow traced:** inbound HTTP request → `_refresh_activity` middleware → `_touch_activity()` writes the `app._last_activity` module global → `_lifespan` wires `last_activity_getter=lambda: _last_activity` into `monitor_and_shutdown` → `should_shutdown(active_clients, last_activity, now, idle_timeout_s)`. Verified the middleware writes the **same** global the monitor reads (`app.py` `_touch_activity` and `_lifespan`), so HTTP traffic genuinely suppresses idle shutdown. The 3 traffic tests prove `_last_activity` advances on POST with `active_clients == 0`, and the only other writer (WS connect/disconnect) is inactive in those tests — so the assertion is non-vacuous and proves the middleware fired.

**Orphan-reaping regression hunt (the key risk):** the middleware makes *every* inbound request count as liveness, so I enumerated every HTTP caller of the Frame (`grep` for `_probe_frame`/`/health`/`is_already_running` and all `urlopen`/`requests`/`httpx` to localhost). All callers are either **one-shot** (`is_already_running` startup probes in `frame/cli.py`, `launch/cli.py`, `hooks/session_start.py`; `pf bc`; `pf frame status`) or **session-driven** (hooks `api/context`, OTLP ingest, subagent-events — all die with the session). The TUI uses **WebSocket** (`tui/client.py` `ws://`), which raises `active_clients > 0` — correct keepalive, not false liveness. **No session-outliving periodic HTTP poller exists**, so a dead session's frame stops receiving traffic and the 300s idle window reaps it. AC2 (orphan reaping) preserved. [VERIFIED] no periodic `/health` poller — `grep` shows only one-shot probe callers; `statusline.py` reads the OTEL port from env (line 503-508) and never calls the frame.

**Observations (tagged by domain; disabled subagents self-assessed):**
- [SEC] reviewer-security returned **clean**: Frame binds 127.0.0.1 only; any local process reaching it already has full unauthenticated API access, so the middleware adds no new capability; removing `FRAME_OWNER_PID` is net-neutral; logged `owner_pid`/`active_clients` are ints, no PII/secrets. Confirmed.
- [SILENT] (self-assessed) The diff adds **no** new `except` blocks. The middleware doesn't catch; if `call_next` raises, `_touch_activity()` already ran (correct — traffic happened) and the exception propagates to Starlette. Pre-existing `except Exception: pass` in the OTLP handlers (`app.py`) is out of scope and already captured as a Delivery Finding by TEA/Dev. No new silent failure.
- [EDGE] (self-assessed) `now - last_activity` is always ≥ 0 in production (`last_activity` is a past `time.monotonic()`); the test's artificial `0.0` yields a large-but-harmless duration. No off-by-one: `should_shutdown` boundary semantics (`> idle_timeout_s`) are unchanged from 161-1. No race — `_last_activity` is read/written on a single asyncio event loop, no threads.
- [TEST] (self-assessed) New tests are non-vacuous (assert specific relations/membership), `mock.patch` targets where-used (`pf.frame.launcher.subprocess.Popen`). Gap: owner-dead reason branch untested (non-production-reachable under Option 2) — captured as a non-blocking Delivery Finding.
- [DOC] (self-assessed) Docstring/comment additions are accurate: the `launcher.py` ADR-0040 rationale matches the code (no `FRAME_OWNER_PID` write remains), and the `uvicorn.error` logger comment is correct (verified uvicorn routes it to stderr).
- [TYPE] (self-assessed) `start_frame` reverted to its annotated single-arg signature (`-> subprocess.Popen | dict`); `monitor_and_shutdown` signature unchanged. The middleware closure `_refresh_activity` leaves `call_next` unannotated per Starlette convention (private nested helper, ruff-clean) — LOW style nit, not a boundary violation.
- [SIMPLE] (self-assessed) Change is minimal and on-spec: one middleware, one deleted line, one constant, one log statement. No over-engineering. The retained owner machinery is justified (161-1 unit tests + future hardened path) and explicitly documented — not dead code.
- [RULE] (self-assessed — see Rule Compliance below) All 13 python.md checks pass on the diff surface.

### Rule Compliance (.pennyfarthing/gates/lang-review/python.md, all 13 vs the diff)
1. Silent exceptions — ✓ no new `except` in diff. 2. Mutable defaults — ✓ none added. 3. Type annotations — ✓ public `start_frame`/`monitor_and_shutdown` annotated; middleware closure exempt (private). 4. Logging — ✓ new `_logger.info("... %s", reason)` uses lazy formatting, INFO level appropriate for a lifecycle event, no sensitive data. 5. Path handling — ✓ no new path ops. 6. Test quality — ✓ no vacuous asserts; one coverage gap (owner-dead branch, deferred). 7. Resource leaks — ✓ no new resource acquisition. 8. Unsafe deserialization — ✓ middleware doesn't read the body. 9. Async pitfalls — ✓ `await call_next`; `_touch_activity`/`_logger.info` are trivially non-blocking; no missing await. 10. Import hygiene — ✓ `import logging` top-level, used; no star/circular. 11. Input validation — ✓ no new user-input surface (security subagent clean). 12. Dependency hygiene — ✓ no dep changes. 13. Fix-introduced regressions — ✓ 305 frame tests + 161-1 baseline green confirm no regression in the change surface.

### Devil's Advocate
Argue this code is broken. **Attack 1 — keep an orphan alive forever:** a malicious or buggy local process floods the frame with HTTP requests; the middleware refreshes activity each time, so the frame never idle-reaps → the exact Mach-message leak 161-1 fought. Counter: this requires a *deliberate, continuous* local sender; any such process could already call every unauthenticated API route, and 161-1's own goal was "reap when nothing is using it" — a continuous sender *is* something using it. No automated session-outliving poller exists in-tree (verified). Real but out-of-threat-model for a single-user localhost dev server; logged as a latent note. **Attack 2 — kill a live session:** a user leaves claude open but walks away; if claude emits zero telemetry for >300s, the frame self-terminates mid-session — a milder echo of the original bug. Counter: the OTEL periodic metric reader fires on a timer for the process lifetime (~60s default), independent of user activity, so a telemetry-enabled session stays alive; and the value is env-tunable. Captured as a monitored Delivery Finding, not a blocker, because it cannot reintroduce the *dominant* active-session-death and is one env var away from mitigation. **Attack 3 — confused maintainer:** the owner machinery still exists in `lifecycle.py` but is never wired, so a future reader might "fix" liveness by re-stamping `FRAME_OWNER_PID` and silently reintroduce Defect 1. Counter: the `start_frame` docstring and the Dev deviation explicitly warn that re-wiring requires ancestry/create-time verification + a recycled-PID test first. **Attack 4 — exception mid-request:** if `call_next` raises, did we corrupt liveness? No — `_touch_activity()` already ran and only writes a monotonic float; the exception propagates cleanly. None of these rise to Critical/High; the dominant user-reported failure (Defect 2) is fixed and proven by tests.

**Verdict rationale:** Tests green (305, verified by preflight + Dev's scoped runs). Security clean. Lint clean. All 13 rules compliant. Zero Critical/High. Three non-blocking Delivery Findings (idle-window cadence assumption, owner-dead branch coverage, `/health` keepalive latent note) — none can reintroduce the dominant regression, all documented for downstream. The PR stands on its own (SOUL #14): the AC4 fork is explained, deviations stamped, downstream impact on 159-5 noted.

**Handoff:** To Stilgar (SM) for finish-story.