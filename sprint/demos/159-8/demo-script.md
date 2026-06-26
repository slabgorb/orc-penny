**Presenter time budget: ~8 minutes**

---

**Scene 1 — Set the stage (0:00–1:00) | Slide 1: Title + Slide 2: Problem**

Open on Slide 1 (title card). Say: *"Frame is the monitoring heartbeat for every agent session. Today we're talking about a regression that caused Frame to kill itself while sessions were still running."*

Advance to Slide 2. Point to the two bullet points. Say: *"Two independent bugs combined to cause this. Neither one was obvious on its own."*

---

**Scene 2 — Show the broken behavior (1:00–2:30) | Slide 2: Problem + Before/After**

Switch to terminal. Run:

```bash
pf frame status
```

Show the audience a Frame process that has already exited (exit code in the log). Pull up the log file:

```bash
tail -n 30 ~/.pennyfarthing/frame.log
```

Point to the log line that shows Frame self-terminating. Note the timestamp relative to when the session was started — show it died *during* an active session.

If live demo fails → show the Before/After slide with the annotated log excerpt.

---

**Scene 3 — Walk through the fix (2:30–5:00) | Slide 3: What We Built**

Advance to Slide 3. Walk through the three bullet points one at a time (owner identity, traffic channels, log output).

Then in terminal, show a live Frame started by the hook:

```bash
pf launch frame
# wait 3 seconds
pf frame status
```

Output should show Frame running with the *Claude session PID* listed as owner, not the launcher PID. Point this out explicitly: *"Notice the owner PID here — this is the Claude process, not the launch script that's already exited."*

Send a test OTLP ping:

```bash
curl -s http://localhost:4318/v1/traces -d '{}' -H 'Content-Type: application/json'
pf frame status
```

Show that `last_activity` timestamp updated. Say: *"HTTP traffic is now counted. Frame knows something is home."*

If live demo fails → advance to the Before/After slide and read the two log lines side by side.

---

**Scene 4 — The self-termination case still works (5:00–6:30) | Slide 4: Why This Approach**

Advance to Slide 4. Say: *"We didn't remove the shutdown logic — we made it smarter."*

In terminal, simulate an orphaned Frame (session already ended):

```bash
pf frame status --show-owner
```

Show the output where the owner PID is verified as dead *and* traffic has been zero for the idle window. Then show the resulting log line:

```
[frame] self-terminating: idle 300s (0 clients, no traffic); owner pid 48291 confirmed dead
```

Say: *"This is the log line we required. Anyone looking at the logs knows exactly why Frame shut down."*

---

**Scene 5 — Wrap + roadmap (6:30–8:00) | Roadmap slide + Questions**

Advance to Roadmap slide. Hand off to roadmap talking points below. Open for questions.

---