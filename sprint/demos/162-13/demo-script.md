# Demo Script — 162-13

**Total runtime: ~5 minutes**

---

**Scene 1 — Title (Slide 1) | 0:00–0:30**

Open with the slide on screen. Say: "Today we're showing a small but important fix to how our sprint planning system handles story dependencies — the kind of fix that removes friction for the team without changing anything visible in the product."

---

**Scene 2 — Problem (Slide 2) | 0:30–1:30**

Walk through the problem scenario verbally:

> "Imagine you're setting up a story and it depends on two other stories — say, the API work and the schema migration both need to be done first. You write it the natural way, as a list. You hit save, and the system throws an error: 'invalid format.' Nothing is wrong with your data — the system just didn't recognize the list style."

Point to the slide. No live demo needed here.

**Fallback:** If asked for specifics, reference the slide — "the validator expected a single value and got a list, so it rejected valid input."

---

**Scene 3 — What We Built (Slide 3) | 1:30–2:30**

Describe what the fix looks like from a user perspective:

> "Now, both of these work without any errors:"

Show (or type) these two YAML snippets side by side — either in a terminal or on the slide:

```yaml
# Before (only this was accepted)
depends_on: 162-11

# After (both forms now accepted)
depends_on:
  - 162-11
  - 162-12
```

**Live demo option:** Run this command in the terminal to show the validator accepting the list form without error:

```bash
pf sprint story validate --story 162-13
```

Expected output: clean validation pass, no errors.

**Fallback:** If the command fails or environment isn't set up, show the Before/After slide instead and describe the expected output verbally.

---

**Scene 4 — Why This Approach (Slide 4) | 2:30–3:30**

Keep it brief: "We made the system flexible rather than forcing users to remember one exact format. The validator now normalizes the input before checking it — same idea as a search box that ignores whether you typed in caps or lowercase."

---

**Scene 5 — Roadmap (Roadmap Slide) | 3:30–4:30**

Transition: "This fix is part of a larger effort to harden our sprint tooling — you'll see a few companion fixes in this same sprint."

Reference sibling stories (see Roadmap section below).

---

**Scene 6 — Questions (Questions Slide) | 4:30–5:00**

Open floor.

---
