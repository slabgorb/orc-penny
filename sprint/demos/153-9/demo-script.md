**Deck structure:** Slide 1 (Title) → Slide 2 (Problem) → Slide 3 (What We Built) → Slide 4 (Why This Approach) → Slide 5 (Before/After) → Slide 6 (Roadmap) → Slide 7 (Questions)

---

**Scene 1 — Opening (0:00–1:30) | Slide 1: Title**
Open on the title slide. Say: "Today we're talking about a reliability fix that's small in lines of code but had an outsized impact on developer confidence. We'll see what the bug looked like, how it hid in plain sight, and why our fix is durable."

---

**Scene 2 — The Problem (1:30–3:00) | Slide 2: Problem**
Walk through the problem statement on Slide 2. Key talking point: "The symptom wasn't a test failure. The symptom was that the codebase itself was in a different state than it was when you started. That's the hardest kind of bug to diagnose — the evidence is in what's *not* broken, not what is."

If presenting live: show the git log entry from the incident during epic 153-3:
```
git log --oneline sprint/archive/153-3-session.md
```
Point to the Dev Incident section in the archive file as documentary evidence.
*Fallback: Slide 2 already has the incident timeline bullet. Read it aloud.*

---

**Scene 3 — Reproducing the Bug (3:00–5:30) | Slide 5: Before/After (Before half)**

> **Only attempt this in a throwaway checkout — this command changes your branch.**

Show the "before" state by demonstrating what the failing test looked like. Open `test_git_utils.py` at the two affected lines (around line 626 and 639). Show the old code:
```python
("good-repo", Path("."))   # ← this was the live repo
```
Explain: "`Path('.')` is Python's way of saying 'wherever we are right now.' In a test, that should never be the live codebase." 

*Fallback: Slide 5 Before column shows this code snippet — read it directly.*

---

**Scene 4 — The Fix (5:30–7:30) | Slide 3: What We Built + Slide 5 After half**

Open the fixed `test_git_utils.py` at the same lines. Show the replacement:
```python
("good-repo", temp_git_repo)   # ← isolated throwaway repo
```
Then show the new watchdog test in `test_git_utils_isolation.py`. Run the targeted test suite live:
```bash
cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_git_utils_isolation.py -v
```
Expected output: `2 passed` — confirm the current working branch is unchanged:
```bash
git branch --show-current
```
Output should show `main` (or whatever branch you started on). "The suite ran. The branch didn't move. That's the whole story."
*Fallback: Slide 5 After column shows the test output screenshot.*

---

**Scene 5 — Why This Approach (7:30–9:00) | Slide 4: Why This Approach**

Cover the "no source guard" decision. "We could have added a safety check to the utility itself — but that would have been fixing the wrong thing. The utility is correct. The test was wrong. We fix problems at their source."

---

**Scene 6 — Roadmap (9:00–10:00) | Slide 6: Roadmap**
Cover what this unlocks (see Roadmap section below). Keep it brief — one slide, two bullets.

---

**Scene 7 — Questions (10:00+) | Slide 7: Questions**
Open floor.

---