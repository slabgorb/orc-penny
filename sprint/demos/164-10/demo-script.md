# Demo Script — 164-10

**Total runtime:** ~5 minutes

---

**Scene 1 — Title (Slide 1) | 0:00–0:30**

Open the deck to Slide 1. Introduce the story: "This is a one-point housekeeping fix, but it's the kind of thing that quietly causes pain on Friday afternoons when CI fails for no obvious reason."

---

**Scene 2 — The Problem (Slide 2) | 0:30–1:30**

Walk through Slide 2 bullets. Say: "Our finish-story test suite had a gap — one step was escaping the sandbox and calling real git. Here's what that looks like."

**Live demo — show the gap (or use Slide 2 as fallback):**
```bash
cd pennyfarthing
git log --oneline -5   # orient audience to the repo
pytest pennyfarthing-dist/tests/finish/ -k "demo_generation" -v --no-header 2>&1 | tail -20
```
Point out any `subprocess` or `git` output that leaks through. If the environment is clean and nothing leaks, say: "The fix is already in — let me show you what the old behavior looked like by referencing the diff."

*Fallback: Stay on Slide 2 and describe the symptom: "Tests were passing locally but producing non-deterministic results in CI because real branch state differed."*

---

**Scene 3 — What We Built (Slide 3) | 1:30–3:00**

Transition to Slide 3. Say: "The fix is three lines of config in the test setup file, but they cover every test in the family automatically."

**Live demo — show the patch:**
```bash
grep -n "autouse" pennyfarthing-dist/tests/finish/conftest.py
```
Expected output: a fixture decorated `@pytest.fixture(autouse=True)` that patches the subprocess path. Point to it: "This runs before every test in the folder without anyone having to remember to call it."

Then show the three probe stubs:
```bash
grep -n "origin/" pennyfarthing-dist/tests/finish/conftest.py
```
Expected: three lines covering `origin/<base>`, `origin/<branch>`, and the sentinel variant. "These are the three ways the code asks 'does this branch exist on the server?' — all three are now answered by a controlled stand-in."

*Fallback: Show Slide 3 with the three bullet points and read them aloud.*

---

**Scene 4 — Why This Approach (Slide 4) | 3:00–4:00**

Slide 4. "We put this in `conftest.py` rather than in individual tests because future tests inherit it automatically. Zero ongoing maintenance cost."

---

**Scene 5 — Before/After | 4:00–4:30**

Show the Before/After slide. "Before: test run could hit real git, non-deterministic. After: fully sandboxed, same result every time, on any machine."

---

**Scene 6 — Roadmap & Questions (Slides: Roadmap → Questions) | 4:30–5:00**

Brief roadmap note, then open for questions.

---
