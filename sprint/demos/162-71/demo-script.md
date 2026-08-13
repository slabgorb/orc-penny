# Demo Script — 162-71

**Total time: 8–10 minutes**

### Scene 1 — Title (Slide 1) | 0:00–0:30
Open the deck. Read the story name aloud. Frame the talk in one sentence: "This story is about making tests honest — catching tests that were accidentally passing for the wrong reason."

### Scene 2 — The Problem (Slide 2) | 0:30–2:00
Explain the "blind taste test" analogy. Tell the audience: "13 of our automated tests were passing by peeking at the label." Show Slide 2's bullet: *"Tests depending on real bundled content instead of controlled inputs."* If you have a live terminal available:
```bash
cd pennyfarthing
git show 303bd676b --stat
```
This shows: `1 file changed, 87 insertions(+), 28 deletions(-)` — confirming the change touched only test code, not production. **Fallback:** If terminal unavailable, stay on Slide 2 and describe the stat verbally.

### Scene 3 — What We Built (Slide 3) | 2:00–4:30
Walk through the before/after at a high level. "Before: tests called the real system. After: tests call a controlled stand-in." Show the Before/After slide if prepared. For a live demo:
```bash
cd pennyfarthing
git log --oneline pennyfarthing-dist/src/pf/tests/test_dist_root.py | head -5
```
This shows the single commit from this story. **Fallback:** Show Slide 3 with the bullet: *"13 tests re-written to use patch-pattern — isolated from bundled package content."*

### Scene 4 — The Twist: Guard Withdrawn (still Slide 3 or transition slide) | 4:30–6:00
This is the interesting part for an engineering audience. "The original story asked us to also add a guard in the resolver. Our Developer ran the suite and found it would break 17 tests from a story we shipped last sprint." Show the Dev Assessment quote: *"The same call is required by 162-29 to return the bundled dist and by 162-71 to return None. There is no signal to distinguish the two intents at the call."* Frame the resolution: "The team escalated to product and the guard was withdrawn. The tests tell the truth now."

### Scene 5 — Why This Approach (Slide 4) | 6:00–7:30
Walk through the three options (delete / leave / fix) and explain why "make them honest" was chosen. Reference the three pre-existing sibling tests that already used this pattern — consistency matters.

### Scene 6 — Results (Before/After Slide) | 7:30–8:30
Show the numbers: *"35 passed, 0 regressions, 1 pre-existing unrelated failure that existed before this story touched anything."* If live terminal available:
```bash
cd pennyfarthing && python -m pytest pennyfarthing-dist/src/pf/tests/test_dist_root.py -q 2>&1 | tail -5
```
Expected output: `35 passed` line. **Fallback:** Slide shows the final suite numbers: 7557 passed / 1 pre-existing failure.

### Scene 7 — Roadmap & Questions (Slides: Roadmap, then Questions) | 8:30–10:00
Brief transition to roadmap slide, then open for questions.

---
