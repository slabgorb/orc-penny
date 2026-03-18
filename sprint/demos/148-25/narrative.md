# Narrative

## Problem Statement
**Problem:** When a Peloton benchmark session finished, terminal panels created for AI agents (like TEA, Dev, and Reviewer) were left open and cluttering the screen. Why it matters: engineers running benchmark tests had to manually close orphaned terminal panels after every run, interrupting focus and adding noise to their workspace. Over repeated benchmark runs, these ghost panels accumulated — making it harder to tell what was still active vs. leftover debris.

---

## What Changed
Think of the terminal screen like a whiteboard in a meeting room. When the Peloton team meeting ends, someone is supposed to erase the board and put the chairs back. Before this fix, the cleanup crew only knew to erase boards they personally wrote on — but some boards were set up by a different process and weren't labeled as "theirs." Those boards got left behind.

The fix teaches the cleanup crew to also recognize boards by the names written on them — "TEA," "Dev," "Reviewer," etc. — and erase those too when the meeting ends. Protected boards (like the main Claude terminal and the dashboard) are still left alone.

---

## Why This Approach
Agent panels are created two ways: some are explicitly stamped "owned by Peloton," but others are discovered automatically at runtime by a reconciliation process that just notes their role name. The cleanup code only knew to check for the ownership stamp — it never thought to check the role name.

The fix is minimal and surgical: load the list of active agents at session end, then kill any panel whose role matches — regardless of how it got its stamp. No new data structures, no new processes. The existing registry already tracked role names; the cleanup logic just wasn't reading them.

---

## Before/After
| | Before | After |
|---|---|---|
| **After session ends** | `tea`, `dev`, `reviewer` panels remain open | All agent panels closed; only `claude`, `tui`, `saddle` survive |
| **How detected** | Auto-discovered panels had no `owner="peloton"` stamp | Cleanup reads active agent list from session state |
| **Manual cleanup needed?** | Yes — engineer closes panels by hand | No — fully automatic |
| **Protected panels safe?** | Yes | Yes (unchanged) |
| **Test coverage** | None for this path | 193 new test cases covering classification and cleanup |
