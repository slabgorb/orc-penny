# Demo Script — 161-1

### Pre-Demo Setup (5 min before presenting)

```bash
# In the pennyfarthing/ repo, on the fix branch:
git checkout feat/161-1-frame-mach-message-leak

# Verify tests pass
cd pennyfarthing && python -m pytest pennyfarthing-dist/src/pf/tests/test_161_1_frame_resource_hygiene.py -v

# Have a second terminal ready for footprint commands
# Have Activity Monitor open, filtered to "pf" processes
```

### Scene 1 — Title (0:00–0:30) | Slide 1

Open on the title slide. One sentence: "Today we're closing a memory leak that was costing us 3.3 gigabytes per session — permanently."

### Scene 2 — The Problem (0:30–2:00) | Slide 2

Walk through the symptom first: "We noticed Activity Monitor showing four `pf.frame.app` processes each using 3.3GB. Normal Python server memory is maybe 700MB. Something was very wrong."

Show the Before/After slide or this concrete framing:
> "206,000 kernel memory regions per instance. Four instances. Thirteen gigabytes of RAM just to run the GUI panel — before writing a line of code."

Advance to the root cause bullet: "Every 5 seconds, the server called `git` using a low-level fork. On Mac, every fork creates kernel message slots. None were ever reclaimed."

Second bullet: "And when you closed your session, the server kept running. Silently. Forever."

**Fallback:** If live demo tooling isn't available, show the Slide 2 annotated screenshot of Activity Monitor with four 3.3GB processes highlighted.

### Scene 3 — What We Built (2:00–4:30) | Slide 3

Live demo — run in terminal:

```bash
# Show the 15 tests that prove the fix
python -m pytest pennyfarthing-dist/src/pf/tests/test_161_1_frame_resource_hygiene.py -v --tb=short
```

Point out the test names as they pass:
- `test_single_shared_poller` — "one polling loop per process, not per connection"
- `test_shared_executor_singleton` — "one worker pool, reused across all polls"
- `test_should_shutdown_owner_liveness` — "detects dead owner session"
- `test_should_shutdown_idle_timeout` — "self-exits after 30 minutes idle"
- `test_should_shutdown_strict_boundary` — "won't exit at exactly the boundary — only after"

**Expected output:** `15 passed in ~0.4s`

**Fallback:** If pytest fails to run, show the pre-captured screenshot of the green test run (15 passed, 0 failed).

Then show the new lifecycle module exists:

```bash
ls -la pennyfarthing-dist/src/pf/frame/lifecycle.py
```

### Scene 4 — Why This Approach (4:30–6:00) | Slide 4

"The investigation found the original hypothesis was wrong — there was no file-watcher leaking. The real mechanism was a 30-year-old Unix system call (`os.fork`) that Mac handles differently in multi-threaded servers."

"We replaced it with the modern safe equivalent. Same result, no kernel churn."

"The shutdown logic was written as a pure math-style function: given these inputs, should this server shut down? Yes or no. That let us test every edge case without running a real server."

### Scene 5 — Before/After (6:00–7:30) | Before/After Slide

Show the table (see Before/After section below). Walk through each row. Emphasize:
- Memory: 3.3GB → bounded (flat with uptime)
- Orphan servers: 4 running, 1 active → max 1 server per active session
- Self-termination: never → within 30 seconds of owner death

```bash
# Show the manual verification procedure documented for runtime validation
grep -A 10 "Manual Verification" pennyfarthing-dist/src/pf/tests/test_161_1_frame_resource_hygiene.py
```

**Fallback:** If the grep doesn't surface it cleanly, advance to the Roadmap slide.

### Scene 6 — Roadmap (7:30–8:30) | Roadmap Slide

"This fix is the foundation. The resource hygiene infrastructure we built — the lifecycle monitor, the shared executor, the owner-liveness check — these are the building blocks for everything that comes next."

Reference deferred items: "Two small follow-up items were identified and logged for a future story: adding error handling inside the monitor loop, and shutting down the worker pool on exit. Neither blocks anything; both are tidy-up."

### Scene 7 — Questions (8:30+) | Questions Slide

"Questions?"

If asked about the kernel memory tools: "`footprint <pid>` and `vmmap <pid>` are the macOS command-line tools that show exactly how many kernel message regions a process holds. The procedure to verify this fix at runtime is documented step-by-step in the codebase."

---
