# 162-71

## Problem

**Problem:** A batch of automated quality tests were passing by accident — not because the behavior they checked was actually correct, but because they were secretly borrowing content from an unrelated part of the system (the bundled package). Any change to that borrowed content could silently flip 13 tests from green to red with no warning.

**Why it matters:** Tests that pass for the wrong reason are worse than tests that fail — they create false confidence. When a test passes because of an accidental side-channel rather than the thing it's supposed to verify, the pipeline looks healthy while a real defect could be hiding.

---

## What Changed

Think of a test like a judge in a blind taste test. The *old* tests were peeking at the label on the bottle before voting — they were unknowingly reading the contents of the real bundled system to decide "pass or fail," instead of testing a controlled sample.

The fix replaced that with a proper blind test: each of the 13 affected tests now runs with a controlled stand-in (a "mock" of the system path resolver), so it only evaluates exactly what it's supposed to evaluate. The production code itself was not touched at all — this was a test-only change.

One additional note: the original story also proposed a code-level guard (a one-line fix to a path-resolution function). During investigation, the team discovered that guard would have silently broken 17 tests from a prior story (162-29) — tests that deliberately rely on the behavior the guard would have blocked. The guard directive was therefore withdrawn; fallback behavior that looks like a "leak" is actually a load-bearing capability that downstream consumers depend on.

---

## Why This Approach

The team could have: (a) deleted the 13 tests, (b) left them as-is, or (c) made them honest. Deletion loses coverage. Leaving them meant the false-positive risk persisted. Making them hermetic — each test providing its own controlled inputs — is the standard engineering practice for test isolation, and three sibling tests in the same file already used this pattern. The fix brought the 13 outliers in line with the established convention.

The guard withdrawal was the harder call. It required the Developer to recognize that the original diagnosis ("fallback #4 is a leak like fallback #2") was a **category error**: fallback #2 is accidental (picks up wherever the code happens to be installed), while fallback #4 is *intentional* (provides bundled workflows to pip/npm consumers who ship no override). Guarding them identically would remove a deliberate capability. Story 162-29's explicit contract — "the bundled dist fallback still works when the project ships no override" — is the authoritative specification, and 162-71's directive conflicted with it.

---
