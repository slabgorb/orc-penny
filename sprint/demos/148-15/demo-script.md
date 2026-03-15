# Demo Script — 148-15

**Total runtime: ~4 minutes**

**Slide 1 — Title (30 sec)**
Introduce the story: "We improved the visual workspace for our AI pipeline runner. Small change, big difference in readability."

**Slide 2 — Problem (45 sec)**
Walk through the before state. If you have a screenshot of the old flat layout, show it here. Describe: "Every pane was side-by-side with no grouping. You couldn't tell where to look first."

**Slide 3 — What We Built (60 sec — live demo)**
Run the following command in a terminal:
```bash
pf peloton start --scenario cr-003
```
Point out: "Notice the left column — CLI on top, TUI panel below it. On the right, the agent panes appear as the pipeline stages spin up." If the live demo fails (tmux not available, env not configured), switch to **Slide 5 (Before/After screenshot)** and narrate the layout differences from the static image.

**Slide 4 — Why This Approach (30 sec)**
Reference the broadcast metaphor: "Anchor desk on the left, field cameras on the right. This is a layout pattern viewers already understand."

**Slide 5 — Before/After (45 sec)**
Show the side-by-side screenshot. Point to: left column containing exactly two panes stacked vertically, right column containing the three agent panes. Count them aloud if needed — audiences respond to concrete numbers.

**Slide 6 — Roadmap (30 sec)**
Tee up what comes next (see Roadmap section below).

**Slide 7 — Questions**
Open floor.

**Fallback plan:** If tmux/peloton won't launch during the live demo, the Before/After slide is fully self-contained. Narrate: "On the left here you see CLI stacked above TUI, and on the right are the three agent panes — TEA, Dev, and Reviewer."

---
