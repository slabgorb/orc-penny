# 148-15

## Problem

Problem: When running the AI development pipeline in peloton mode, all terminal windows were jumbled together without a clear visual hierarchy, making it impossible to tell what the system was doing at a glance. Why it matters: Developers and reviewers watching the pipeline run couldn't distinguish the control interface from the active work happening in each agent pane — like trying to watch a race where the scoreboard, commentary booth, and track are all on the same screen with no separation.

---

## What Changed

Think of a TV sports broadcast: there's the main anchor desk in the top-left, and the live field footage fills the rest of the screen. Before this change, everything was crammed into one flat row. Now, the terminal layout follows that broadcast metaphor:

- **Left column (top + bottom stacked):** The CLI prompt where you type commands sits on top, and the TUI status display (live sprint/agent state) sits below it — your "anchor desk."
- **Right column:** All the peloton agent panes (TEA, Dev, Reviewer, etc.) live here in a split — your "field cameras."

The result is a clean two-column layout where control lives on the left and execution lives on the right.

---

## Why This Approach

The left-right split mirrors how developers already think about their workflow: "I'm over here giving instructions, and the agents are over there doing the work." Stacking CLI on top of TUI on the left keeps the two control surfaces together without competing for attention. The right column can then grow or shrink as more agent panes are added, without ever disturbing the control area. This approach required the least amount of custom layout code while producing the most intuitive spatial separation.

---
