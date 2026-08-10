# 162-49

## Problem

**Problem:** The persona-loading API route was silently broken in production — any request to fetch a persona would crash with a type error. **Why it matters:** Any live feature relying on persona data (agent behavior, theme display, session context) would fail at runtime with no graceful fallback, and the bug was completely invisible in the test suite because tests happened to run from a directory that caused the route to return a 404 *before* reaching the broken code — so tests passed, giving a false green signal.

---

## What Changed

Think of it like a phone number written down wrong in two places. One part of the system was trying to call a function by passing it a *folder path* and a *session ID*. But the function it was calling actually expects an *agent name* and optionally a *folder path* — completely different inputs, in a different order. When a real request came in, it tried to make that call and immediately crashed.

The fix corrected the call so it passes the right information in the right order.

The second part of the fix addressed *why the tests didn't catch it*: the test suite was accidentally sensitive to which directory you ran it from. If you ran tests from one folder, the route would short-circuit early with a "not found" response — never reaching the broken line — and tests would pass. Run from a different folder, you'd get 4 failures. The fix adds a configuration anchor so the suite always runs with a consistent project directory, regardless of where on disk you invoke it.

---

## Why This Approach

Two separate issues were fixed together because they're two sides of the same coin: a bug that existed in production, and a test harness that was structurally unable to detect it.

Fixing only the call-signature mismatch would leave the test suite fragile — the same class of problem could sneak in again undetected. Fixing only the test harness would surface the existing bug without resolving it. Addressing both in one pass closes the loop completely: the code is correct *and* the tests are now capable of proving it.

The `PF_PROJECT_DIR` fixture is a standard test hygiene pattern — it pins an environment variable so test behavior is deterministic regardless of invocation context. This is a low-risk, high-value guardrail.

---
