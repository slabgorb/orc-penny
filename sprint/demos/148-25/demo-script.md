**Total time: ~6 minutes**

**Slide 1 — Title (0:00–0:30)**
Open with: "This is a small fix with a big quality-of-life impact for anyone running Peloton benchmarks daily."

**Slide 2 — Problem (0:30–2:00)**
Describe the before state. Walk through what a Peloton benchmark run looks like: multiple terminal panels open side by side — one for TEA, one for Dev, one for Reviewer. Then say: "When the session ends, watch what happens."

*Live demo — Terminal:*
```bash
pf benchmark replay run --scenario peloton-baseline
```
Let it run ~30 seconds, then stop. Point to the orphaned panes still open.

*Fallback:* Show the Before/After slide if the terminal demo fails.

**Slide 3 — What We Built (2:00–3:30)**
"We taught the cleanup step to recognize agent panels by name, not just by a label we stamped on them."

Explain the two types of panels: explicitly-owned vs. auto-discovered. Point to the `AGENT_ROLES` set on Slide 3: `tea, dev, reviewer, architect, sm, ba, devops, tech-writer, ux-designer, orchestrator`.

**Slide 4 — Why This Approach (3:30–4:30)**
"The registry already had the role names — we just weren't reading them during cleanup. The change is 15 lines of Python."

Reference the commit: `e6c4b9ce3`. Stat: 3 files changed, 214 lines (193 of which are new tests).

**Before/After Slide (4:30–5:15)**
*Live demo — show the fix in action:*
```bash
pf benchmark replay run --scenario peloton-baseline
# After session ends:
tmux list-panes -a
```
Expected output: only `claude`, `tui`, and `saddle` panes remain. No `tea`, `dev`, or `reviewer` panes.

*Fallback:* Show the Before/After slide with the pane list comparison.

**Questions Slide (5:15–6:00)**

---