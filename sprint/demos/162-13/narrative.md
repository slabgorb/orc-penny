# 162-13

## Problem

**Problem:** When a team member listed multiple story dependencies in a task, the system rejected the entire entry as invalid — even though the format was correct. **Why it matters:** Teams couldn't mark stories as dependent on more than one other story, forcing workarounds or leaving dependency tracking incomplete, which increases the risk of work being done in the wrong order.

---

## What Changed

Think of sprint stories like tasks on a to-do list, where some tasks can't start until other ones finish. Those "finish first" tasks are called dependencies.

Previously, the system expected dependency entries to look like a single name written on one line. If someone wrote a proper list — the way most people naturally write multiple things — the system rejected it with an error, even though both styles mean the same thing.

We fixed the system to recognize and accept both formats: a single dependency written inline, or multiple dependencies written as a proper list. Either way, the validator now understands what's intended.

---

## Why This Approach

The fix taught the validator to be format-tolerant rather than format-strict. Instead of requiring one specific syntax, it now normalizes the input — converting a list into the form it already expected — before doing any checking. This is the same principle as a form field that accepts a phone number with or without dashes: the underlying data is the same, so the system should accommodate both.

This approach avoids breaking any existing stories that use the old single-value format while opening the door to the more natural multi-value style.

---
