# 161-1

## Problem

**Problem:** Every time a developer opened the Pennyfarthing GUI panel, the system launched a background server that silently consumed 3.3 gigabytes of Mac system memory — and never let go. With four sessions open simultaneously (a normal day), that totaled 13GB of lost memory, roughly the equivalent of leaving four browser tabs open that each eat an entire laptop's worth of RAM, forever.

**Why it matters:** Left unchecked, this would make the tool unusable on any machine with less than 16GB of RAM, degrade overall system performance for anyone using multiple sessions, and silently compound over the course of a workday until the Mac slowed to a crawl or ran out of memory entirely. It also represented a class of resource leak that, if unaddressed, signals deeper hygiene debt in the server architecture.

---

## What Changed

Think of the GUI panel server like a hotel concierge who is supposed to check in, help guests while they're there, and go home when the hotel closes. Before this fix, two things were broken:

1. **The concierge was generating mountains of paperwork on every task and never shredding it.** Every 5 seconds, the server called out to check git repository status. Each call was done in the most wasteful way possible on a Mac — using a low-level system fork that creates a new process slot in the operating system's memory kernel. Those slots accumulated like sticky notes piling up on a desk: 206,000+ of them per instance, totaling 3.3GB of kernel-held memory that never got cleaned up.

2. **The concierge kept working in an empty hotel.** When a developer closed their session, the server kept running. When four sessions had been opened and closed over a day, there were four servers still running, still polling every 5 seconds, still accumulating memory — even though all the guests had checked out.

The fix addressed both:
- **Wasteful calls replaced:** The low-level fork mechanism was swapped for the standard safe approach, and all background work now shares a single, bounded worker pool instead of spinning up fresh pools on every poll.
- **Self-checkout installed:** Each server now watches whether its owning session is still alive. When the session ends — even if it crashes or is force-killed — the server detects this within 30 seconds and shuts itself down cleanly. If no one has connected in 30 minutes, it also shuts down on its own.

---

## Why This Approach

The initial hypothesis (a file-watcher leaking OS notification channels) turned out to be wrong — investigation revealed no file-watcher existed in the live code path at all. The actual culprit was a lower-level mechanism: the way Mac handles process forking in multi-threaded servers generates OS kernel message regions on every call, and nothing was ever reclaiming them.

Fixing it at the correct layer (replacing the fork with a safe subprocess call and bounding the worker pool) addresses the root cause rather than papering over symptoms. The self-termination logic was designed as a pure decision function — "should this server shut down right now?" — kept completely separate from the shutdown mechanism itself. This means it's fully testable in automated tests without needing to run a live server, and can be verified to be correct by inspection alone. The kernel-level memory behavior can't be tested in a CI pipeline (it requires a real Mac and real memory tools), but the behavioral contracts — "one shared worker pool," "server exits when owner dies," "server exits when idle 30 minutes" — are all covered by 15 automated tests.

---
