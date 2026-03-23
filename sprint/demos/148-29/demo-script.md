**Total runtime: ~4 minutes**

---

**Slide 1: Title (0:00–0:15)**
Introduce the story: "Today we're covering a one-point bug fix that unblocked the peloton multi-agent workflow for all consumer projects."

---

**Slide 2: Problem (0:15–1:00)**
Walk through the broken behavior. Say: "Before this fix, if you were working in any real project — not the framework itself — and tried to run the peloton pipeline, here's what happened."

Show the terminal and type:
```bash
pf peloton start
```
**(Fallback: If live demo environment isn't available, jump to the Before/After slide and show the error output screenshot.)**

Point to the recursive invocation error. Say: "The skill called itself. Then called itself again. It never stopped until the process was killed."

---

**Slide 3: What We Built (1:00–2:00)**
Transition to the fix. Say: "The solution was to add a recursion guard — a check that runs immediately when the skill is invoked."

Show the guard logic (or describe it in plain terms): "Before doing any work, the skill now asks: 'Have I already been called in this context?' If yes, it exits cleanly instead of proceeding."

Type the same command again in the fixed environment:
```bash
pf peloton start
```
Show it proceeding normally — spawning the expected agent panes without looping.

---

**Slide 4: Why This Approach (2:00–2:45)**
Say: "We kept the fix surgical. No rearchitecting, no refactoring. One guard at the entry point. For a 1-point fix on a framework that real projects depend on, stability of the surrounding code matters more than elegance."

**(Fallback: If the demo environment is unavailable for this slide, skip to Roadmap.)**

---

**Before/After Slide (2:45–3:15)**
Walk through the comparison table. Say: "On the left, what users saw before — an infinite loop with no useful error message. On the right, clean startup and normal peloton execution."

---

**Roadmap Slide (3:15–3:45)**
See Roadmap & Integration section below for talking points.

---

**Questions (3:45–4:00)**

---