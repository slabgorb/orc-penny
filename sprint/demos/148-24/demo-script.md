# Demo Script — 148-24

**Total time: ~6 minutes**

---

**Scene 1 — Title & Context (Slide 1: Title)**
*Timing: 0:00–0:30*

Open with: "We're going to show you a small but impactful quality-of-life improvement for anyone running multi-agent Peloton sessions."

---

**Scene 2 — The Problem (Slide 2: Problem)**
*Timing: 0:30–1:15*

Show a screenshot or describe: "Before today, if you launched a 4-agent team, your terminal looked like this — four panes crammed into whatever default the system picked. There was no way to change it without hacking configuration files."

Point out: the TUI status panel could appear in unpredictable positions, making it hard to find at a glance.

*Fallback if live demo unavailable: Stay on Slide 2 and walk through the bullet points.*

---

**Scene 3 — What We Built (Slide 3: What We Built)**
*Timing: 1:15–2:30*

Type this live in the terminal:

```bash
pf peloton start --layout grid
```

Say: "We're launching a 4-agent team with the grid layout — four panes in a 2×2 arrangement."

Point out in the terminal output:
- The confirmation line showing `Layout: grid. Arrange agent teammate panes in a 2x2 grid pattern.`
- The TUI dashboard anchored below the SM lead pane

Then show the smart default kicking in with no flag needed:

```bash
pf peloton start
```

Say: "With no flag specified and 4 agents in this workflow, it picked grid automatically."

*Fallback: Slide 3 — show the three layout options as a diagram.*

---

**Scene 4 — Persistent Config (Slide 3 continued)**
*Timing: 2:30–3:30*

Show the config file:

```bash
cat .pennyfarthing/config.local.yaml
```

Point to the `peloton.layout: grid` line. Say: "Set it once, forget about it. Every future session respects this preference. The command-line flag always wins if you want to override it for a specific run."

---

**Scene 5 — Why This Approach (Slide 4: Why This Approach)**
*Timing: 3:30–4:30*

Say: "We picked exactly three layouts because they cover the real use cases: side-by-side for comparison work, stacked for tall monitors, grid for full-team runs. The smart default means the system self-configures correctly for 90% of users with zero configuration."

Demonstrate vertical layout for a 2-agent scenario:

```bash
pf peloton start --layout vertical
```

Show the output confirming `Layout: vertical. Stack agent teammate panes vertically.`

*Fallback: Slide 4 — walk through "sensible default, easy override" bullet.*

---

**Scene 6 — Wrap Up (Slide: Roadmap)**
*Timing: 4:30–5:30*

"This is one of a series of Peloton visual polish stories shipping this sprint. We'll see how it connects to agent colors and portrait panes in a moment."

Open to questions at 5:30.

---
