# Demo Script — 162-28

**Total runtime: ~8 minutes**

**Slide 1: Title** *(0:00–0:30)*
Introduce the story: "Today we're closing a gap in our quality gate — one that let rework sessions get approved without doing any work."

**Slide 2: Problem** *(0:30–2:00)*
Walk through the scenario: "Imagine a story fails review and gets sent back. The engineer does a second pass. When they submit, the gate reads their *first* attempt instead of their second — and approves it based on stale data. Worse, the backup safety check was looking for a section that was never written. Both guards failed simultaneously."

Show the before behavior:
```bash
# Simulate a rework session with zero specialists in cycle 2
pf test replay test_143_12 --show-input
```
Point to the output: "Cycle 1 dispatched 3 specialists. Cycle 2 dispatched 0. The gate reads Cycle 1 and approves."

**Slide 3: What We Built** *(2:00–3:30)*
"We fixed the reader to be cycle-aware — it now only looks at the current rework block. And we fixed the label mismatch so the backup check actually runs."

Show the pinned test passing:
```bash
cd pennyfarthing && python -m pytest tests/test_143_12.py -v
```
Expected output: test transitions from `XFAIL` to `PASSED`. Point to: "This test was pinned as a known failure. It now passes."

*Fallback if pytest unavailable:* Go to Slide 3 and read the before/after bullet points verbatim.

**Slide 4: Why This Approach** *(3:30–5:00)*
"We scoped the fix to the read path only — no changes to how sessions are written, no migration needed. Minimal blast radius, maximum precision."

**Before/After slide** *(5:00–6:30)*
Walk through the comparison table. Key line: "A session with zero specialists in its latest cycle now correctly BLOCKS. Before this fix, it was approved."

**Roadmap slide** *(6:30–7:30)*
"This closes the last triage item from 162-5. It unblocks 162-47's verdict routing from operating on stale approvals."

**Questions** *(7:30–8:00)*

---
