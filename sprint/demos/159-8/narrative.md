# Narrative

## Problem Statement
**Problem:** Our agent monitoring server (Frame) was spontaneously shutting itself down while active Claude sessions were still running — taking live dashboards, telemetry, and API connectivity offline mid-session. **Why it matters:** Teams using Frame to monitor agent activity were losing visibility without warning, and session data was being dropped silently. Any tooling or integrations relying on Frame's HTTP API during a session would fail without explanation.

---

## What Changed
Think of Frame as a security guard booth at the entrance to a building. It's supposed to stay open as long as someone is working inside, and close up only when the last person leaves.

Two bugs broke this contract:

1. **The wrong person was listed as "owner."** When Claude auto-starts Frame via a startup hook, the script that launches Frame exits immediately after handing off — like a messenger who knocks on the booth's door, drops a key, and walks away. Frame saw the messenger leave and concluded "my owner is gone, I should shut down" — even though the real occupant (the Claude session) was still working inside.

2. **Frame wasn't watching the right activity.** Frame had a timer: "if no one's connected to me for N minutes, shut down." But it only counted WebSocket connections as "someone connected." Live telemetry pings (OTLP) and HTTP API calls were completely ignored. A session actively sending data to Frame looked like an empty room, so Frame would close up anyway.

The fix: Frame now tracks who actually owns the session (the real Claude process, not the launch script), watches *all* traffic channels for signs of life, and logs a clear reason whenever it does decide to shut down.

---

## Why This Approach
Three engineering principles guided the design:

**1. Track the right signal.** The root cause wasn't "the timeout is too short" — it was "we were watching the wrong door." Extending the timeout would have masked the bug, not fixed it. Instead, we wired liveness detection to all three traffic channels: WebSocket clients, OTLP telemetry, and HTTP API calls.

**2. Don't trust bare process IDs.** PIDs get recycled by the operating system — a PID that belonged to your Claude session five minutes ago might belong to a completely unrelated system process today. Checking only `os.kill(pid, 0)` was a false-confidence check. The fix pairs the PID with a process creation timestamp so we're certain we're watching the right process.

**3. Preserve the orphan-reaping feature.** Story 161-1 added the ability for Frame to clean up after itself when sessions die unexpectedly. That's valuable. The fix keeps orphan reaping intact — Frame still shuts down when the real owner dies — it just does it correctly, based on verified identity and actual traffic absence.

---

## Before/After
| | Before (broken) | After (fixed) |
|---|---|---|
| **Owner registered** | Launcher script PID (exits in <1s) | Claude session PID (lives for session duration) |
| **Idle detection** | WebSocket clients only | WebSocket + OTLP telemetry + HTTP API calls |
| **PID verification** | `os.kill(pid, 0)` bare check — fooled by PID reuse | PID + process creation timestamp — identity confirmed |
| **Shutdown log output** | *(no reason logged)* | `idle: 0 clients, no traffic 300s` or `owner pid 48291 dead` |
| **Session outcome** | Frame terminates 45s into live session | Frame alive for full session duration |
| **Orphan cleanup** | *(also broken — same PID confusion)* | Still fires correctly when real session ends |
| **Start paths tested** | None formally verified | All three paths assert correct owner in regression test |
