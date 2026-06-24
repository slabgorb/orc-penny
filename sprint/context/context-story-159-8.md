# Story 159-8 Context

## Title
Frame kills live sessions (161-1 regression): ephemeral owner PID on hook/launch auto-start + idle-timeout blind to OTLP/HTTP traffic

## Metadata
- **Story ID:** 159-8
- **Type:** bug
- **Points:** 3
- **Priority:** p1
- **Workflow:** tdd
- **Repo:** pennyfarthing
- **Epic:** Smaller standalone fixes

## Problem
161-1 (commit 9c882af, gh #97) added in-process self-termination to the Frame (lifecycle.py monitor_and_shutdown → app.py _trigger_shutdown SIGTERM). Two wiring defects cause it to kill LIVE sessions. Defect 1: start_frame() stamps FRAME_OWNER_PID = os.getpid() of its CALLER; correct only on the 'pf frame start' exec path (PID preserved via os.execvpe into claude). On the SessionStart-hook auto-start (session_start.py:186, the path 'just claude' relies on) and on 'pf launch tui/frame' (launch/cli.py), the caller is ephemeral — owner PID is a dead/recycled PID within seconds → monitor self-terminates the frame (~30s, or randomly via PID reuse). Defect 2: idle-timeout treats a frame with zero WebSocket clients as idle even while it is actively serving OTLP telemetry + HTTP API (POST /api/subagent-event etc.); _touch_activity() only fires on WS connect/disconnect, so a CLI-only session's frame dies ~30min in. Evidence: frame.log shows a graceful self-SIGTERM ('Shutting down'), NOT a memory/OOM kill. COORDINATION: sibling 159-5 hardens the SAME monitor against silent death (orphans surviving); landing 159-5 first would make THIS random-death more reliable. Do 159-8 first (or together). Design recorded in docs/adr/0040.

## Technical Approach

Design authority: **docs/adr/0040-frame-self-termination-liveness-contract.md** (ADR-0040, Status: Proposed).

### ADR-0040 Decision

Adopt Option 3 (hybrid) as target, Option 2 (traffic-only) as acceptable floor:

1. **Traffic is liveness (required).** `_touch_activity()` fires on OTLP ingest and HTTP requests. Idle-timeout self-terminates only when there are no WebSocket clients AND no inbound traffic for the idle window.
2. **Owner-PID is an optional fast-path, not the contract.** If retained it must (a) carry the real long-lived session PID passed explicitly per caller, and (b) be identity-verified (PID + create-time or ancestry) so recycling cannot flip the decision. Dev may drop it and rely on the traffic signal alone (Option 2) — the AC contract allows either, provided no live session is ever killed and no recycled PID is trusted.
3. **Shorten the idle window** (tunable via `FRAME_IDLE_TIMEOUT_S`; default reduced from 1800 s).
4. **Log the shutdown reason** at the self-termination point.

### Liveness Contract (ADR-0040)

> A Frame must self-terminate **iff** no session is using it. "A session is using it" means: a connected WebSocket client, OR recent inbound traffic (OTLP/HTTP) within the idle window, OR a verified-alive owning session process.

### Touch Points

- `frame/lifecycle.py` — `should_shutdown`, `monitor_and_shutdown`
- `frame/app.py` — `_touch_activity` (add OTLP/HTTP triggers), `_trigger_shutdown` (add reason log)
- `frame/launcher.py` — `start_frame()` (optional `owner_pid` param + identity verification)
- Three callers: `frame/cli.py`, `launch/cli.py`, `hooks/session_start.py`
- Tests: `pf/tests/test_frame_*.py`

### RED Tests to Write (161-1 lacked these)

1. Hook-style start: launching process exits while session lives → frame must NOT self-terminate.
2. Frame with 0 WS clients but live OTLP traffic → not idle.
3. Recycled-PID scenario → shutdown decision unchanged (neither killed nor fooled).
4. Per-path owner correctness: each of the three start paths registers the correct long-lived owner.

Keep 161-1's pure `should_shutdown` unit tests green — extend, do not replace.

### Coordination

- **159-5** hardens the same monitor against silent death; landing 159-5 first would make the random-death MORE reliable (worse). **159-8 must land first, or the two land together.**

## Scope
- In scope: the behavior described by the story title.
- Out of scope: unrelated changes.

## Acceptance Criteria
- A Frame auto-started by the SessionStart hook survives the full duration of its owning Claude session and does not self-terminate while that session is alive and producing telemetry (regression test simulates an ephemeral launcher exiting while the session lives).
- A Frame whose owning session has ended — normally OR via SIGKILL — still self-terminates within a bounded window (preserves 161-1 orphan-reaping intent; default window may be shortened).
- Inbound OTLP telemetry and HTTP API requests count as liveness activity: a Frame with zero WebSocket clients but live telemetry is NOT judged idle.
- Any owner-PID liveness check is robust against PID reuse (identity verified beyond bare os.kill(pid,0) — e.g. PID+create-time or ancestry), OR owner-PID gating is removed in favor of the traffic signal per the ADR. Chosen design must neither kill a live session nor be fooled by a recycled PID.
- All three start paths (pf frame start, pf launch tui/frame, SessionStart-hook auto-start) register a correct long-lived owner; a test asserts owner correctness per path.
- The self-termination path emits a log line stating the reason (e.g. 'idle: 0 clients, no traffic Ns' vs 'owner <pid> dead'); 161-1 lifecycle test baseline stays green.

---
_Generated by `pf context create story 159-8` from the sprint YAML._
