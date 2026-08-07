# 162-28

## Problem

**Problem:** A safety gate that decides whether a development session is ready to advance was silently waving through sessions that hadn't done any real work. Specifically, when a story required rework — going back through the process a second or third time — the gate kept reading stale records from the *previous* cycle instead of the current one, and approved the session anyway. A second, backup check meant to catch this was permanently broken due to a name mismatch: it was looking for a label that the system never actually wrote.

**Why it matters:** The approval gate is the last line of defense before work advances to the next stage. When it fails open, low-quality or incomplete sessions slip through undetected, wasting reviewer time and potentially shipping work that didn't meet its own standards.

---

## What Changed

Think of a session file like a notebook. Each time a story gets sent back for rework, the process adds a new chapter to that notebook — same chapter titles, but new content. The bug was that the "quality inspector" was flipping to *any* page with the right title, often landing on an old chapter, and declaring the work done.

The fix teaches the inspector to always read the *latest* chapter. It now anchors its search to the current rework cycle number, so it never confuses yesterday's work for today's.

The second fix closes a permanently-open trapdoor. A backup checker was coded to look for a section called "Rework Cycle" — but the notebook writer has always labeled that section "Round-Trip Count." They've never matched. The backup checker was dead code. The fix aligns the two so they speak the same language.

---

## Why This Approach

The root cause was ambiguous section lookup — `re.search` finds the *first* match anywhere in the document, not the match that belongs to the current context. The fix scopes the search window: find the start of the current cycle's block, find the start of the next cycle's block (or end of file), and only read within that range.

This approach is minimal — it doesn't restructure the file format, doesn't break existing session files, and doesn't change what gets written. It only changes where the reader looks. That makes it safe to deploy without migrating historical data.

The header mismatch fix is a one-line correction. There's no design debate — one side was wrong, one side was right, and the writer is authoritative.

---
