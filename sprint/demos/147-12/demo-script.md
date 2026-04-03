### Scene 1 — Title & Framing (Slide 1) | ~1 min
Open on the title slide. Say: "This is a two-point fix, but it was a workflow blocker for anyone using Pennyfarthing without Jira, or whose stories hadn't been explicitly marked 'in progress.'"

### Scene 2 — The Problem (Slide 2) | ~2 min
Walk through Slide 2. Reference both failure modes:
- "The finish command expected a story to be at a specific point in the workflow. If it wasn't — even if the story was genuinely complete — the command would either silently fail or throw a confusing drift warning."
- Key data point: stories in `backlog` status (the default when work.py start_work is a stub) would hit a state machine rejection: `transition_story(backlog → done)` refused.
- Fallback: if live terminal isn't available, show the Before/After slide instead.

### Scene 3 — What We Built (Slide 3) | ~2 min
Live demo or screenshot:
```bash
# Before fix: story stuck in backlog, finish fails
pf sprint story finish 147-12
# Output (before): ERROR: cannot transition from backlog to done

# After fix: walks the ladder automatically
pf sprint story finish 147-12
# Output (after): ✓ backlog → in_progress → in_review → done
```
Point out: "No manual intervention. No status pre-checks required."

### Scene 4 — Why This Approach (Slide 4) | ~1 min
Explain the deliberate restraint: "We fixed the symptom here and logged the root cause separately. That's a conscious trade-off — ship the fix now, clean up the deeper stub in a follow-on story."

### Scene 5 — Before/After (Before/After Slide) | ~1 min
Show the comparison slide. Highlight the Jira drift case: "For teams not using Jira, the finish flow used to report warnings that looked like real problems. Now it skips cleanly."

### Scene 6 — Roadmap (Roadmap Slide) | ~1 min
Note the logged follow-on: `work.py:start_work()` needs a real implementation. "That's the next step — this story buys us a working finish flow today while that work is scheduled."

### Scene 7 — Questions (Questions Slide) | ~open

**Fallback plan:** If terminal demo fails at Scene 3, switch directly to the Before/After slide and narrate the output values verbally.

---