**Total estimated runtime: 12 minutes**

---

**Slide 1 (Title) — 1 minute**

Open with: *"Today we're showing a small but high-leverage fix to our agent review pipeline. It closes three gaps that let bad outputs slip past quality gates undetected."*

No commands needed. Let the title slide breathe.

---

**Slide 2 (Problem) — 2 minutes**

Walk through the three failure modes with concrete examples:

- *"An agent filed a deviation citing* `Spec source: general architecture` *— not a real document. The gate accepted it without complaint."*
- *"A developer added* `.skip()` *to a failing test. The gate had zero awareness the test suite had just gotten weaker."*
- *"An operator disabled two reviewer agents in settings. The gate still demanded all nine and blocked the handoff with a list of agents that weren't even running."*

Pause and ask: *"Would you sign off on a code review if the reviewer said 'I checked the requirements — somewhere'?"*

---

**Slide 3 (What We Built) — 3 minutes**

Live terminal demo. Type these commands exactly:

```bash
# Prove the vague-citation gate catches bad sources
cd /Users/keithavery/Projects/pf-2/pennyfarthing
python3 -m pytest pennyfarthing-dist/src/pf/tests/test_150_6_spec_authority.py \
  -k "vague_spec_source" -v
```

Expected output: `PASSED` — the test proves the gate catches `Spec source: general architecture` and returns:
`"vague Spec source 'general architecture' — must reference a file path, AC, or section"`

```bash
# Prove the quality regression gate catches skipped tests
python3 -m pytest pennyfarthing-dist/src/pf/tests/test_150_6_spec_authority.py \
  -k "quality_regression" -v
```

Expected output: `PASSED` — proves `.skip()` additions, snapshot deletions, and weakened assertions are all caught.

**Fallback (if terminal fails):** Jump directly to Slide 5 (Before/After) and walk through the error message comparison table side by side.

---

**Slide 4 (Why This Approach) — 2 minutes**

Key talking points:

- *"Pattern matching, not another AI. These checks run in milliseconds and give the same answer every single time."*
- *"The authority hierarchy mirrors how we already think about documents — we just made it enforceable, not just advisory."*
- *"Enforcement reads live config. Disable an agent, the gate stops requiring it. No one has to remember to update a list."*

---

**Slide 5 (Before/After) — 2 minutes**

Walk the Before/After table (below) column by column. Specific data point to call out:

*"Before this fix, a deviation with a completely blank spec source —* `Spec source:` *with nothing after it — would pass silently. After, the gate returns:* `Entry 'Changed field name' has empty Spec source — must cite a specific document or section.`*"*

Call out the gate error message row last: *"Before: seven agent names hardcoded. After: only the two that are actually enabled."*

---

**Slide 6 (Roadmap) — 1 minute**

Reference the Roadmap & Integration section below. Highlight the connection to sibling stories 150-7 through 150-9.

---

**Slide 7 (Questions) — 1 minute**

---