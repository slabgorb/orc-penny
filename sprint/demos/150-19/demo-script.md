**Total runtime: ~8 minutes**

**Before you start:** Have two terminal windows open. Window 1: the `pennyfarthing/` repo on branch `feat/150-19-quality-regression-policy`. Window 2: a text editor showing `ratchet.py`.

---

**Scene 1 — Title (Slide 1) [0:30]**
Open with: "Today we're closing a gap in our automated pipeline that was allowing test quality to quietly erode."

---

**Scene 2 — The Problem (Slide 2) [1:30]**
Show Slide 2. Say: "Our AI agents write code, write tests, and review each other's work. But until this fix, nothing stopped an agent from removing a test assertion or skipping a test — and the pipeline would still show green."

Concrete example to describe: "Imagine a test that verifies a user's account balance can never go negative. An agent refactors it and drops the assertion. Tests pass. The pipeline advances. The bug ships."

---

**Scene 3 — What We Built (Slide 3) [2:00]**
Show Slide 3. Walk through the four regression types the ratchet catches.

Live demo — Window 1:
```bash
cd pennyfarthing
python -m pytest pennyfarthing-dist/src/pf/tests/test_150_19_quality_ratchet.py -v
```
Expected output: `23 passed` — point to this number. "23 tests, covering all four regression types plus edge cases like legitimate skips and assertion refactors that aren't regressions."

**Fallback:** If tests fail, show Slide 3 and describe the four regression types from the bullet points.

---

**Scene 4 — Why This Approach (Slide 4) [1:30]**
Show Slide 4. "We could have built a broad 'don't remove anything' rule, but that would block legitimate refactoring. Instead we built surgical detection — it distinguishes a weakened assertion from a refactored one."

---

**Scene 5 — Before/After (Before/After slide) [1:30]**
Show the Before/After slide. Walk through the two examples side-by-side (see Before/After section below).

---

**Scene 6 — Roadmap (Roadmap slide) [0:30]**
Brief: "This ratchet is phase one. Coming up: coverage floor enforcement and mutation testing gates."

---

**Scene 7 — Questions [0:30]**

---