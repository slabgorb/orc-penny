# Narrative

## Problem Statement
Problem: Users running peloton mode (the multi-agent team pipeline) had no way to configure how the terminal panels were arranged — the layout was hardcoded. Why it matters: Different screen sizes and workflows need different layouts. Without a settings toggle, power users were stuck with one fixed view and had to dig into config files to change anything, making the tool feel unfinished and frustrating for daily use.

---

## What Changed
We added a new option to the settings page inside the terminal interface (TUI). Now, when you open the settings panel, you'll see a "Peloton Layout" option that lets you pick how the agent panes are arranged on screen — side by side, stacked, or other configurations — without touching any config files.

Think of it like adding a "view" toggle in a video conferencing app: same meeting, different arrangement of participant windows.

---

## Why This Approach
The settings page already existed for other preferences. Rather than building a separate configuration screen or requiring users to edit files manually, we plugged the layout option into the existing settings UI. It's the same pattern users already know, it took minimal effort, and it keeps all preferences in one place.

---
