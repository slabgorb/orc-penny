# ADR-0040: Frame Self-Termination Liveness Contract

**Status:** Proposed
**Date:** 2026-06-24
**Author:** Architect
**Story:** 159-8 (coordinates with 159-5)
**Supersedes (in part):** the lifecycle wiring shipped in 161-1 (commit `9c882af`, gh #97)

## Context

Story 161-1 fixed a real problem: orphaned Frame uvicorn servers outlived their
owning Claude Code sessions and compounded a ~3.3 GB kernel-side Mach-message
leak on macOS. The fix added **in-process self-termination** — a monitor
(`frame/lifecycle.py::monitor_and_shutdown`) that periodically evaluates
`should_shutdown()` and, when true, SIGTERMs the server via
`app.py::_trigger_shutdown`.

The mechanism is sound; its **wiring is wrong in two ways**, and the result is
that the monitor kills *live* sessions, not just orphans. The frame log proves
the death is a graceful self-SIGTERM (`INFO: Shutting down` → clean unwind), not
an OOM/`rlimit` kill — i.e. the server is deciding to exit while a session is
still using it.

### Problem Statement

**Defect 1 — the "owner" is the launching process, which is often ephemeral.**
`launcher.start_frame()` stamps `FRAME_OWNER_PID = os.getpid()` of *whatever
calls it*. The monitor later self-terminates when that PID is no longer alive
(`should_shutdown(owner_pid set, not owner_alive) → True`). This is correct on
exactly one path:

- `pf frame start` (`frame/cli.py`) calls `start_frame()` and then
  `os.execvpe("claude", …)`, which **preserves the PID**. So the owner PID
  genuinely becomes the long-lived Claude session. ✅

It is wrong on the two **auto-start** paths that real workflows depend on:

- **SessionStart hook** (`hooks/session_start.py::_ensure_frame`, line 186) —
  runs inside the throwaway `pf hooks session-start` subprocess. That process
  exits within seconds, so `FRAME_OWNER_PID` is a dead PID almost immediately.
  This is the path `just claude` relies on (the recipe itself never starts a
  frame; it only wires OTEL to an existing one). ❌
- **`pf launch tui` / `pf launch frame`** (`launch/cli.py::_ensure_frame`) —
  same `start_frame()` call; owner is the launcher process. ❌

The death *feels random* because `is_process_alive()` is just
`os.kill(pid, 0)` — it asks "is *any* process at this PID alive?", not "is the
process that owned my session alive?". After the ephemeral launcher exits its
PID is freed; if the OS recycles it onto an unrelated process before the next
30 s monitor tick, the frame survives, otherwise it dies. Same session,
different luck.

**Defect 2 — idle-timeout is blind to non-WebSocket traffic.**
`should_shutdown()` also fires on `active_clients == 0 and idle > timeout`.
But `active_clients` counts only WebSocket clients, and `_touch_activity()`
is called only on WebSocket connect/disconnect. A frame actively receiving
OTLP telemetry and HTTP API calls (`POST /api/subagent-event`,
`/api/pending-tool-input`) with no held-open WebSocket panel is judged "idle"
and self-terminates ~30 min in — mid-work for any CLI-first session.

**Test gap.** 161-1's tests exercised `should_shutdown()` as a *pure function*
with `owner_alive` injected. They never tested the integration that actually
fails: *who* the owner is on each start path, and *what* counts as activity.

### Decision Drivers

- **Must not kill a live session.** This is a regression that makes the feature
  actively harmful; it is biting the primary user's daily `just claude` flow now.
- **Must still reap orphans** on abnormal session death (SIGKILL/crash) — the
  original 161-1 intent and the reason `atexit` alone was insufficient.
- **Reuse-first** (SOUL #2, Architect pragmatic-restraint): prefer a liveness
  signal we already have over new machinery.
- **Reuse-proof:** the decision must not be flipped by PID recycling in either
  direction (false kill or false survival).
- **Uniform across all three start paths** — hook, `pf launch`, `pf frame start`.
- **Diagnosable:** the shutdown decision must say *why* it fired.

## Considered Options

### Option 1 — Keep owner-PID primary; fix the PID per caller + harden it

Pass the genuine long-lived session PID into `start_frame(owner_pid=…)` per
caller (hook → the Claude process; `pf frame start` → `os.getpid()` pre-exec),
and verify *identity* (PID + create-time, or require the owner to be an
ancestor) so recycled PIDs can't fool the check.

- **Pros:** Instant reaping on abnormal death; smallest conceptual change.
- **Cons:** Depends on reliably discovering the session PID from an auto-start
  context. From the hook, `os.getppid()` *may* be the Claude process — or a
  shell wrapper that also exits. Brittle, platform-sensitive, and exactly the
  class of assumption that produced Defect 1.

### Option 2 — Replace owner-PID with traffic-based liveness

Drop owner-PID gating. Treat **inbound OTLP telemetry (and HTTP requests) as
activity** (`_touch_activity()` on ingest), and self-terminate only on
`no WebSocket clients AND no inbound traffic for the idle window`. A Claude
session streams telemetry continuously while alive and stops when it ends; that
stream *is* the liveness signal — no PID, no ancestry, no reuse hazard.

- **Pros:** Fixes both defects with one change; reuse-first (we already receive
  the OTLP stream); immune to PID reuse; identical on every start path.
- **Cons:** After abnormal session death the frame lingers up to the idle
  window before noticing silence (vs. near-instant for a correct PID check).

### Option 3 — Hybrid: traffic-based idle primary + hardened owner-PID fast-path

Make Option 2 the primary, reuse-proof liveness signal, and **keep a *correct*
owner-PID check only as an optional fast-path** for instant reaping where the
owner PID is genuinely the session (and identity-verified per Option 1). Shorten
the idle window (telemetry is frequent; a few minutes of *total* silence
reliably means "session gone").

- **Pros:** Live sessions never die (traffic signal); orphans reaped promptly
  on the exec path and within a bounded short window everywhere else; no single
  brittle assumption is load-bearing.
- **Cons:** Two mechanisms to reason about; the fast-path adds code that
  Option 2 doesn't need.

## Decision

Adopt **Option 3 as the target design, with Option 2 as the acceptable floor.**

1. **Traffic is liveness (required).** `_touch_activity()` fires on OTLP ingest
   and HTTP requests; idle-timeout self-terminates only when there are no
   WebSocket clients *and* no inbound traffic for the window. This is the
   reuse-proof primary signal and the part that directly restores `just claude`.
2. **Owner-PID is a fast-path, not the contract (optional).** If retained, it
   must (a) be the real long-lived session PID, passed explicitly per caller,
   and (b) be identity-verified (PID + create-time / ancestry) so recycling
   can't flip the decision. If hardening it cleanly proves not worth the
   complexity, Dev may drop it and rely on the traffic signal alone (Option 2) —
   the AC contract is written to allow either, provided **no live session is
   ever killed and no recycled PID is ever trusted.**
3. **Shorten the idle window** so abnormal-death reaping stays prompt under the
   traffic-primary model. (Tunable via `FRAME_IDLE_TIMEOUT_S`; default reduced
   from 1800 s.)
4. **Log the shutdown reason** at the self-termination point.

### The Liveness Contract (the reusable invariant)

> A Frame must self-terminate **iff** no session is using it. "A session is
> using it" is defined as **any of**: a connected WebSocket client, recent
> inbound traffic (OTLP/HTTP) within the idle window, or a verified-alive owning
> session process. Owner-PID liveness is a fast-path optimization, never the
> sole signal, and is only valid when the PID is the genuine long-lived session
> *and* its identity is verified beyond bare `os.kill(pid, 0)`.

This contract — not the specific PID plumbing — is what future lifecycle changes
must preserve.

## Consequences

**Positive**

- `just claude` and `just tui` auto-start a Frame that lives exactly as long as
  the session and reaps itself when the session ends. The manual
  `pf frame start` workaround is no longer needed.
- Both 161-1 defects are closed; orphan-reaping (the original 161-1 goal) is
  preserved within a bounded, shorter window.
- Liveness is reuse-proof and uniform across all three start paths.
- Shutdown decisions are self-explaining in the log — future diagnosis is one
  `tail .session/frame.log` instead of a forensics session.

**Negative / trade-offs**

- After an abnormal (SIGKILL) session death, a Frame may linger up to the idle
  window before exiting. Mitigated by shortening the default window; acceptable
  because lingering briefly is strictly better than killing live sessions.
- `_touch_activity()` now runs on the hot OTLP ingest path — a single monotonic
  clock write; negligible.

**Coordination with 159-5 (required, not optional)**

159-5 hardens the *same* monitor against *silent death* (guarding the
`monitor_and_shutdown` loop body so an exception can't disable orphan-reaping)
and shuts the shared executor down on lifespan exit. That makes the killer
monitor **more** robust — which, while Defect 1 stands, would make the random
death **more** reliable, not less. Therefore **159-8 (this ADR) lands first, or
the two land together.** Sequencing 159-5 ahead of 159-8 is a known regression
hazard.

## Implementation Notes (for TEA → Dev)

- Touch points: `frame/lifecycle.py` (`should_shutdown`, `monitor_and_shutdown`),
  `frame/app.py` (`_touch_activity`, OTLP endpoints, `_trigger_shutdown` logging),
  `frame/launcher.py::start_frame` (+ optional `owner_pid` param + identity),
  and the three callers (`frame/cli.py`, `launch/cli.py`,
  `hooks/session_start.py`).
- The failing tests 161-1 lacked (write these RED first): (1) a hook-style start
  where the launching process exits while the session lives → frame must NOT
  self-terminate; (2) a frame with 0 WebSocket clients but live OTLP traffic →
  not idle; (3) a recycled-PID scenario → decision unchanged; (4) per-path owner
  correctness.
- Keep the 161-1 lifecycle baseline (the pure `should_shutdown` unit tests)
  green; extend, don't replace.
