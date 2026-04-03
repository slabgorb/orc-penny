# Narrative

## Problem Statement
**Problem:** After running an automated testing pipeline (called a "Peloton session"), leftover terminal windows kept accumulating in the background and were never closed. Each benchmark run added more orphaned windows, eventually cluttering the environment and consuming system resources.

**Why it matters:** If these ghost windows pile up unnoticed, they can slow down the developer's machine, make it harder to navigate the terminal workspace, and — in the worst case — cause future automated runs to behave unpredictably because they inherit stale state from sessions that should have been long gone.

---

## What Changed
Think of tmux panes like sticky notes on a whiteboard. Before this fix, when the pipeline kicked off a testing session, it handed out sticky notes but never wrote anyone's name on them. When the session ended, the cleanup crew had no way to know which notes belonged to that session — so they left everything up.

The fix adds a simple label ("owner=peloton") to each sticky note the moment it's created. Now when a session ends, cleanup knows exactly which notes to pull down and does so automatically.

---

## Why This Approach
Tagging at creation time is the right call for two reasons:

1. **No guesswork later.** Trying to figure out after-the-fact which windows belong to a finished session is error-prone. Labeling up front is reliable.
2. **Minimal blast radius.** The change touches only the moment a window is opened, leaving everything else — how sessions run, how results are scored — completely untouched. Small change, clean solution.

---
