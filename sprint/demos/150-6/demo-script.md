**Total estimated runtime: 12 minutes**

---

**Slide 1: Title — 1 minute**

Open with: "Today we're showing a small but high-leverage fix to our agent review pipeline. It closes three gaps that let bad outputs slip past quality gates."

---

**Slide 2: Problem — 2 minutes**

Walk through the three failure modes with concrete examples:

- "An agent filed a deviation citing `Spec source: general architecture` — not a real document. The gate accepted it."
- "A developer added `.skip()` to a failing test. The gate had no awareness of the test suite weakening."
- "An operator disabled two reviewer subagents in settings, but the gate still demanded results from all nine and blocked the handoff."

Ask the audience: "Would you sign off on a code review if the reviewer said 'I checked the requirements — somewhere'?"

---

**Slide 3: What We Built — 3 minutes**

Live terminal demo — type these exact commands:

```bash
# Show the spec-authority validation catching a vague citation
cd /Users/keithavery/Projects/pf-2/pennyfarthing
python3 -m pytest pennyfarthing-dist/src/pf/tests/test_150_6_spec_authority.py \
  -k "vague_spec_source" -v
```

Expected output: `PASSED` — test proves the gate now catches `Spec source: general architecture` and returns `"vague Spec source 'general architecture' — must reference a file path, AC, or section"`.

```bash
# Show the quality regression gate catching a skipped test
python3 -m pytest pennyfarthing-dist/src/pf/tests/test_150_6_spec_authority.py \
  -k "quality_regression" -v
```

Expected output: `PASSED` — proves `.skip()` additions and snapshot deletions are caught.

**Fallback (if terminal fails):** Jump to the Before/After slide and walk through the diff screenshot showing the new error messages.

---

**Slide 4: Why This Approach — 2 minutes**

Key talking points:
- "We used pattern matching, not another AI layer. These checks run in milliseconds and the result is always the same."
- "The authority hierarchy (`session > story > epic > architecture`) mirrors how we already think about document precedence — we just made it explicit."
- "Enforcement reads live configuration. If you disable a subagent, the gate stops requiring it. Zero manual maintenance."

---

**Slide 5: Before/After — 2 minutes**

Reference the Before/After section below. Walk through the two columns side by side.

Specific data point to call out: "Before this fix, a deviation citing `Spec source:` (blank) would pass silently. After, the gate returns: `Entry 'Changed field name' has empty Spec source — must cite a specific document or section.`"

---

**Slide 6: Roadmap — 1 minute**

Cover integration with sibling stories and upcoming work (see Roadmap section below).

---

**Slide 7: Questions — 1 minute**

---