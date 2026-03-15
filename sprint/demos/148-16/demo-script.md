# Demo Script — 148-16

**Setup (before presenting):** Have a terminal ready. Have peloton mode available to launch. Optionally have a screenshot of the "before" state (cluttered panes) ready as a fallback.

---

**Scene 1 — Title slide (0:00–0:30)**
*Slide 1: Title*
Open with: "We made a small but noticeable improvement to how our multi-agent peloton view looks. Let me show you what changed."

---

**Scene 2 — Show the problem (0:30–1:15)**
*Slide 2: Problem*
Reference the before screenshot (or describe it): "When we ran 5 agents at once, each pane had a status bar footer — that's 5 identical footers taking up space. On a standard laptop screen, you'd lose roughly 10–15% of visible area to footers that only the main agent actually uses."

If you have a before screenshot: point to the repeated footers in each pane.
Fallback: describe it verbally and move to Slide 3.

---

**Scene 3 — Live demo (1:15–2:30)**
*Slide 3: What We Built*

Run peloton mode live:
```
pf peloton start
```

Point out: "Notice the main agent pane — it still has the status bar at the bottom. Now look at the supporting agent panes — clean, full-height output. No repeated footers."

Count the panes visually: "Five panes, one status bar. Before: five status bars."

Fallback: If peloton fails to start, show the after screenshot on Slide 3 and narrate what the audience would see.

---

**Scene 4 — Why this approach (2:30–3:00)**
*Slide 4: Why This Approach*
"We didn't rebuild anything. We just added one instruction at launch: subagents start with the status bar turned off. That's it. No new configuration screens, no user settings to manage."

---

**Scene 5 — Roadmap tease (3:00–3:30)**
*Roadmap Slide*
"This is part of a broader push to make peloton mode feel polished and production-ready. Cleaner panes means cleaner recordings, cleaner demos, and cleaner operator experience as we scale up team sizes."

---

**Close — Questions (3:30+)**
*Questions Slide*
Open the floor.

---
