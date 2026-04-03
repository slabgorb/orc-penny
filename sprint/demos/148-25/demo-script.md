**Total runtime: ~5 minutes**

---

**Slide 1 — Title (0:00–0:15)**
Introduce the story: "Today we're showing a small but important housekeeping fix in our automated testing pipeline."

---

**Slide 2 — Problem (0:15–1:00)**
Walk through the before state. Say: "Every time a Peloton benchmark ran, it left behind open terminal windows. After five runs, you'd have five sets of orphaned windows. After twenty runs — twenty sets."

Show **Slide 2** with the before screenshot or diagram of accumulated panes.

If doing a live demo, open a terminal and run:
```bash
tmux list-panes -a -F "#{pane_id} #{pane_title} #{?pane_dead,[DEAD],}"
```
Point out any panes with no owner label. Say: "Notice — no labels, no ownership. The system has no idea who created these."

*Fallback: If the terminal demo is unavailable, stay on Slide 2 and describe the output verbally.*

---

**Slide 3 — What We Built (1:00–2:00)**
Transition: "Here's the fix."

Run a fresh Peloton session start to show the tagging in action:
```bash
pf benchmark replay run --scenario peloton-baseline
```

Then immediately check pane metadata:
```bash
tmux list-panes -a -F "#{pane_id} #{pane_title} owner=#{E:@owner}"
```

Expected output will show something like:
```
%12  tea-worker  owner=peloton
%13  dev-worker  owner=peloton
```

Say: "See that 'owner=peloton' tag? That's the label being applied the moment each window opens."

*Fallback: Show Slide 3 with the before/after pane metadata screenshot.*

---

**Slide 4 — Why This Approach (2:00–2:45)**
No live demo needed here. Walk through the slide bullets. Emphasize: "Label at birth, clean up by label. Simple, reliable, no side effects."

---

**Before/After Slide (2:45–3:30)**
Show the comparison side-by-side. Left side: pane list with no labels, session-end with leftover windows. Right side: labeled panes, zero leftover windows after session close.

If demoing live, end the session:
```bash
pf benchmark replay stop
```

Then verify cleanup:
```bash
tmux list-panes -a -F "#{pane_id} #{pane_title} owner=#{E:@owner}"
```

Expected output: empty or shows only non-peloton panes. Say: "Gone. Every peloton-owned window closed cleanly."

*Fallback: Stay on the Before/After slide.*

---

**Roadmap Slide (3:30–4:15)**
Walk through integration context (see Roadmap & Integration section below).

---

**Questions (4:15–5:00)**
Open for questions.

---