# Narrative

## Problem Statement
**Problem:** Three code-analysis tools in our Frame server were silently broken — when asked to find dead code, measure complexity, or trace dependencies, they returned empty results (or garbage) every time, without any visible error. **Why it matters:** Developers relying on these tools to audit their codebase were getting blank reports and trusting them, meaning real dead code, bloated files, and tangled dependencies were going undetected. The system looked like it was working when it wasn't.

---

## What Changed
Imagine asking someone to go fetch a file for you, but instead of actually going to get it, they hand you a sticky note that says "I will go get the file later" — and then walk away. That sticky note is useless on its own.

That's exactly what was happening. Three analysis functions were handing Python a promise to do work, but never telling Python to actually *do* the work. Python dutifully held onto those promises and returned them as if they were results. The fix was simply adding the word `await` — essentially saying "don't hand me the sticky note, go get the actual file right now."

No logic changed. No behavior was redesigned. Three lines of code each got one word added.

---

## Why This Approach
Python's async system is explicit by design: if you forget `await`, the language doesn't crash loudly — it just quietly skips the work and moves on. This makes the bug invisible in normal operation but guaranteed to produce wrong answers.

The right fix is the minimal one: add `await` exactly where it was missing. There's no need to restructure the functions, add fallbacks, or change the API. The async machinery was already correct — these three call sites just weren't using it properly. Surgical correction over broad refactor.

---

## Before/After
| | Before | After |
|---|---|---|
| **Call to `find_stale_files()`** | Returns a coroutine object (unawaited) | Awaits the coroutine; returns actual file list |
| **`GET /api/analysis/dead-code`** | Returns `[]` (empty list) or raw coroutine repr | Returns list of actual stale files, e.g. `["src/legacy/report.py", "utils/old_cache.py"]` |
| **`GET /api/analysis/complexity`** | Returns `{}` or garbage | Returns complexity scores per file |
| **`GET /api/analysis/dependencies`** | Returns `{}` or garbage | Returns real dependency graph |
| **Python runtime** | Emits `RuntimeWarning: coroutine 'find_stale_files' was never awaited` (silently swallowed) | No warning; clean execution |
| **Developer experience** | Sees empty report, assumes codebase is clean | Sees accurate report reflecting real code state |
