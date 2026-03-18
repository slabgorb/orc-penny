**Setup (before presenting):**
- Have `pf frame start` running in a terminal with peloton mode active
- Settings panel should be closed initially

**Scene 1 — Title (0:00–0:30)**
Slide 1: Title slide. Say: "Today I want to show you a small but meaningful quality-of-life improvement we shipped for teams running our multi-agent pipeline."

**Scene 2 — The Problem (0:30–1:00)**
Slide 2: Problem. Say: "Until now, when you launched peloton mode — our team benchmark runner — the panel layout was locked in. If you had a wide monitor or a narrow laptop screen, tough luck." Point to the bullet: "No user control. Hardcoded layout."

**Scene 3 — What We Built (1:00–2:00)**
Slide 3: What We Built. Transition to live terminal.

Live demo command:
```
pf frame start
```

Navigate to Settings panel on screen. Show the new "Peloton Layout" option. Select an alternative layout (e.g., stacked) and watch the panels rearrange live.

Say: "One click. The panels reflow. No config files, no restart."

*Fallback if demo fails:* Show Slide 3 with the before/after screenshot. Say: "Here's the settings page with the new option highlighted."

**Scene 4 — Why This Approach (2:00–2:30)**
Slide 4: Why This Approach. Say: "We put it in the existing settings page because that's where users already look. Zero learning curve."

**Scene 5 — Roadmap (2:30–3:00)**
Slide 5: Roadmap. Say: "This lays the groundwork for richer layout presets as the peloton feature grows."

**Scene 6 — Questions (3:00+)**
Slide 6: Questions.

---