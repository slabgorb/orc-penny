# Narrative

## Problem Statement
**Problem:** The AI-assisted development pipeline had no safeguard against quietly degrading its own test suite over time. Developers or automated agents could remove test assertions, skip tests without explanation, or weaken checks — and nothing would catch it. **Why it matters:** A test suite that silently shrinks in coverage is worse than no test suite at all — it creates false confidence. When a system is trusted to review its own code, unchecked quality erosion is a critical reliability gap.

---

## What Changed
Think of a ratchet wrench: it tightens a bolt, and a built-in mechanism prevents it from spinning backwards. We built that same one-way mechanism for test quality.

A new module was added that scans for four specific "going backwards" signals:
1. **Removed assertions** — a test that used to check something no longer does
2. **Removed test functions** — entire tests quietly deleted
3. **Weakened assertions** — a precise check replaced with a vague one
4. **Unjustified skips** — tests marked "skip this" with no linked ticket explaining why

Now, whenever Dev or the Reviewer agents touch test files, this ratchet runs. If it finds any of these patterns, it blocks the work from advancing.

---

## Why This Approach
The core principle is **one-way quality gates**: test suites should only get more thorough over time, never less. Rather than a catch-all "don't break tests" rule (which was already in place), this targets the specific ways smart automated agents tend to quietly lower the bar:

- They may refactor a strong assertion into a weaker one that still passes
- They may skip a flaky test rather than fix it
- They may delete a test that's hard to maintain

The implementation deliberately carves out legitimate cases — for example, refactoring `isinstance(x, Foo)` to `type(x) is Foo` is not flagged as weakening, and a skip with a linked issue ticket is allowed. This reduces false alarms while catching real regressions.

---

## Before/After
| | Before | After |
|---|---|---|
| **Agent removes an assertion** | Pipeline advances. No warning. | Ratchet blocks advancement. Regression logged with file + line. |
| **Agent skips a test, no ticket** | Pipeline advances. Test silently disabled. | Blocked. Agent must link a JIRA issue or remove the skip. |
| **Agent refactors `isinstance` to `type() is`** | Passes — correct behavior. | Still passes — ratchet correctly identifies this as a refactor, not a weakening. |
| **Agent removes an entire test function** | No detection. Coverage drops invisibly. | Ratchet flags missing test function by name. |
| **Skip with a linked ticket (e.g., `# MSSCI-12345`)** | Passes. | Still passes — legitimate exception is honored. |
