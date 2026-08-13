# 164-25

## Problem

**Problem:** Three API endpoints in the Frame server — hotspots, health score, and code markers — were silently broken. When called, they would either crash with a confusing internal error or return incomplete results without any warning. **Why it matters:** These endpoints are core to the code analysis dashboard; a broken hotspots route means the "high-risk files" panel shows nothing or errors, degrading the developer experience and eroding trust in the tool.

---

## What Changed

Think of these three routes as delivery drivers who each had a different problem filling out their manifest before heading out:

- The **hotspots** and **code markers** drivers were handed a package labeled "project folder" but needed *two* pieces of info: the project name *and* the folder path. They were only getting one, so they couldn't make the delivery.
- The **health score** driver was handed a sticky note saying "use the cache" — but the warehouse doesn't have a cache system. The sticky note caused a crash before the driver even left.

The fix: give each driver exactly what they need, remove the nonexistent instruction, and make sure the warehouse doors open correctly (async/await wiring). We also patched the quality inspector (the test suite) who was rubber-stamping crashes as "acceptable" — it was checking whether a route responded *at all*, not whether it responded *correctly*.

---

## Why This Approach

These bugs share the same root cause as a previous fix (story 160-20): routes that were migrated to async threading but whose internal function calls weren't updated to match. Rather than patching each individually with a quick workaround, the fix applies the same proven pattern from 160-20 — proper argument resolution, `Path()` type safety, and `await` threading — making all three routes consistent with each other and with the rest of the framework. The `use_cache` kwarg was simply removed rather than shimmed, because the underlying function never supported it and adding it would introduce false behavior.

Tightening the tests is equally important: a test that accepts both success *and* failure as valid outcomes isn't a test — it's a rubber stamp. The updated tests assert correct status codes and response shapes, ensuring this class of bug can't hide again.

---
