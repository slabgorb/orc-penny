**Total runtime: ~4 minutes**

---

**[0:00–0:30] Slide 1: Title**
Introduce the story: "Today we're closing a reliability bug in Peloton — our AI team workflow runner. This is a one-point fix, but it protects the integrity of every automated pipeline run we do."

---

**[0:30–1:15] Slide 2: Problem**
Reference the before behavior. Say: "Without this fix, if Peloton was triggered while a panel was already running, it would open a second panel for the same agent. You'd have two Developers, two Reviewers — racing each other, producing conflicting results. Neither output was trustworthy."

If you want a live illustration: open a terminal and show `tmux list-panes` — point out what it would look like with duplicates (two panes labeled `dev`).

*Fallback: Stay on Slide 2 and describe the scenario verbally.*

---

**[1:15–2:00] Slide 3: What We Built**
"We added a single check: before Peloton opens a panel for an agent, it asks — does this role already have a panel? If yes, reuse it. If no, create it."

Live demo (if available):
```bash
pf peloton start
tmux list-panes -a -F '#{pane_title}'
```
Show that each role appears exactly once. Point to the output: one `tea`, one `dev`, one `reviewer`.

*Fallback: Show Slide 3 with the before/after panel list graphic.*

---

**[2:00–2:45] Slide 4: Why This Approach**
"We fixed it at the source — before creation — not after the fact. No cleanup logic, no race conditions, no risk of interrupting an agent mid-task. Smallest possible change, maximum reliability gain."

---

**[2:45–3:30] Before/After Slide**
Walk through the before/after comparison (see section below). Emphasize: "Before, you couldn't trust the output. After, the system is deterministic — same inputs, same panel layout, every time."

---

**[3:30–4:00] Questions Slide**
Open for questions. Suggested talking point: "This is foundational hygiene for Peloton. It sets us up to add more sophisticated orchestration — like parallel lanes — without instability."

---