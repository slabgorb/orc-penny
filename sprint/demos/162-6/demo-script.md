# Demo Script — 162-6

**Total runtime: ~6 minutes**

---

**Scene 1 — Title (Slide 1) | 0:00–0:30**
Open on the title slide. Say: "Today we're looking at a small but important reliability fix in how our automation closes out completed work."

---

**Scene 2 — The Problem (Slide 2) | 0:30–2:00**
Walk through the problem slide. Say: "When a developer finished a story, our system ran two final checks before marking it done — but both checks looked in the wrong place. Here's what that looked like."

Switch to terminal. Type:
```
cd /Users/keithavery/Projects/orc-penny
pf sprint story 162-6
```
Point to the `repos: both` field — this story touches two repos. Explain: "The old code ignored that field when running its final checks."

*Fallback: if terminal unavailable, show Slide 2 with the before/after error message.*

---

**Scene 3 — What We Built (Slide 3) | 2:00–3:30**
"We fixed two things. First, every git and GitHub command now runs from the story's actual code directory. Second, for stories that span multiple repos, we now verify each one independently."

Show a terminal demo of the fixed behavior:
```
pf finish --story 162-6
```
Point to the output line that reads something like: `Checking pennyfarthing/ ... MERGED ✓` and `Checking orchestrator/ ... MERGED ✓`. Both must pass.

*Fallback: show the Before/After slide instead.*

---

**Scene 4 — Why This Approach (Slide 4) | 3:30–4:30**
"We chose the most conservative logic: if even one pull request is still open, the story stays in review. You can see that here."

Demonstrate the abort case (or show slide):
- Story with one merged PR and one open PR → system prints: `ERROR: pennyfarthing PR #171 is not merged — story left in_review` and exits without marking done.

---

**Scene 5 — Roadmap (Roadmap Slide) | 4:30–5:30**
Cover how this fits into the broader reliability track. Reference sibling stories.

---

**Scene 6 — Questions (Questions Slide) | 5:30–6:00**

---
