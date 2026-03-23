# Narrative

## Problem Statement
Problem: Every time a developer started a multi-agent team workflow (peloton), they had to manually re-specify how they wanted their terminal panels arranged — grid, vertical, or horizontal. Why it matters: Small friction adds up. A preference that can't be saved isn't really a preference, and repetitive configuration interrupts focus at the exact moment a developer is trying to spin up complex work.

---

## What Changed
Think of the settings page like a preferences panel in any app — font size, theme, notifications. Before this change, there was no slot for "how should my team workspace look?" so every session started from scratch.

We added one new dropdown to the settings page: **Peloton Layout**. Pick Grid, Vertical, or Horizontal. The system remembers it. Next time a team workflow starts, the panels snap into place exactly the way you configured — no flag, no argument, no repetition.

---

## Why This Approach
The layout logic already existed inside the peloton engine — it could already accept a layout value from a config file. The settings page just wasn't wired up to write that value. Rather than building something new, we connected two things that were already mostly connected: a user-facing preference form and an existing config slot. Eleven lines of code. No new concepts introduced, no new dependencies, no risk of side effects.

---
