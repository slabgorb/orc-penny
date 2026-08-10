# Demo Script — 162-25

**Total runtime: ~6 minutes**

---

**Slide 1 — Title (30 seconds)**
Introduce the story: "This is a one-point bugfix that closed a silent false-positive in our automated sprint status tracking. Small story, real consequence."

---

**Slide 2 — Problem (90 seconds)**
Walk through the scenario:

> "Suppose a developer names a branch `feat~2` — maybe by accident, maybe testing something. Our tracker checks whether that branch is merged by running a git command with that name. Git interprets `feat~2` as 'the commit two steps behind feat' — not the branch itself. That ancestor commit is almost always already merged into main. So our tracker sees count-ahead = 0 and marks the story done. The PR was never opened."

If doing a live demo:
```bash
# Show the broken behavior (on a test repo)
git rev-parse refs/heads/feat~2   # resolves to an ancestor SHA
git rev-list --count HEAD..refs/heads/feat~2   # returns 0 → looks merged
```
If the live demo environment isn't available, stay on Slide 2 and describe the output verbally: "Git returned zero commits ahead, so the system concluded the branch was fully merged."

---

**Slide 3 — What We Built (90 seconds)**
Show the validation gate:

```bash
git check-ref-format --branch "feat~2"
# exit code 128 — rejected
git check-ref-format --branch "feat/login-flow"
# exit code 0 — valid
```

"Before we ever ask 'is this merged,' we now ask 'is this even a real branch name?' If git says no, we route to the abort path we already had for unknown branches. Two lines of logic, no new error paths."

Also mention the two bonus fixes: "We also caught a case where a name ending in shell syntax like `$(command)` was being quietly trimmed to a single character instead of rejected — the system was *changing* your input rather than refusing it. And control characters in branch names now fail here instead of reaching git and causing a noisy crash."

---

**Slide 4 — Why This Approach (60 seconds)**
"We used git's own validator rather than writing our own character blocklist. Git knows every edge case. Our job was to call it at the right moment and trust its answer."

---

**Before/After Slide (60 seconds)**
Walk through the comparison table (see Before/After section below).

---

**Roadmap Slide (30 seconds)**
"This is part of a series of hardening stories around branch extraction and merge-state detection. The next logical step — story 162-47 — extends coverage to stacked PR scenarios."

---

**Questions (open)**
If asked about blast radius: "This is a defensive check at the input boundary. Legitimate branch names pass through unchanged. Only malformed names are redirected — and those were producing wrong answers before, so any change in behavior is an improvement."

---
