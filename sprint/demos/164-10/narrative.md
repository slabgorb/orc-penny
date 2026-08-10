# 164-10

## Problem

**Problem:** Tests for the story-finish workflow were accidentally reaching out to real git infrastructure during automated test runs. **Why it matters:** A test that fires real git commands is unpredictable — it passes on a developer's machine with the right branches checked out, and fails silently (or not at all) on a CI server in a different state. You can't trust a test suite that behaves differently depending on what's in your `.git` folder.

---

## What Changed

Think of the test suite as a flight simulator. A good simulator lets a pilot practice landings without ever touching a real runway. Before this fix, one section of the simulator — the part that tests "finishing a story" — had a small hole in the floor: whenever it ran the demo-generation step, it would quietly poke the real runway to check if it existed.

This fix seals that hole. It adds an automatic intercept (called an *autouse patch*) in the test setup file so that any time those demo-generation steps would reach out to real git, they instead talk to a safe, pre-scripted stand-in. The simulator stays a simulator, end to end.

It also closes three smaller gaps left over from the previous story (155-34), where three specific "does this branch exist on the server?" checks were still going to real git instead of the stand-in.

---

## Why This Approach

The fix lives in the test configuration file (`conftest.py`) rather than in each individual test. That's the right altitude — one declaration covers every test in the family automatically (`autouse=True`), so future tests written by anyone on the team inherit the isolation for free. Patching at the source of the problem (the subprocess call) rather than at the test assertion level means we're blocking the real call before it ever leaves the process.

The three probe-path variants (prefer `origin/<base>`, fall back to `origin/<branch>`, handle annotated/backtick sentinel) map directly to the three real-world branch-resolution strategies the code uses. Covering all three means there's no path through the logic that can escape to real git.

---
