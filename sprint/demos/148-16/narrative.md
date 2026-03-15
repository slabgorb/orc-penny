# 148-16

## Problem

Problem: When running a full team of AI agents simultaneously in "peloton" mode, every agent's terminal pane displayed a status bar at the bottom — even agents that didn't need one. Why it matters: With 4–6 agent panes visible at once, these redundant status bars consumed valuable screen space, made the interface feel cluttered, and made it harder to read the actual work happening in each pane.

---

## What Changed

Think of it like a conference room with multiple TV screens, each showing a different team member's work. Before this change, every screen had the same control panel footer eating into the display area — even for screens where no one needed the controls. Now, only the main "conductor" screen shows the status bar. The supporting screens use their full height to show actual content.

In practical terms: when the system spins up a team of agents for peloton mode, it now tells each supporting agent "you don't need a status bar" before they start. The main agent still gets one. Everyone else gets clean, full-height output.

---

## Why This Approach

The simplest fix to a simple problem. The status bar is an opt-out feature — it's on by default. The change just passes a "no statusbar" flag to subagents at launch time, the same way you'd tell a new hire "we don't use that template for internal docs." No rearchitecting, no new settings panels. One targeted instruction at the right moment.

---
