# Narrative

## Problem Statement
Problem: When developers work inside Pennyfarthing's multi-pane terminal workspace, the pane layout frequently drifts out of alignment — windows get resized, panes open in unexpected spots, and the critical TUI dashboard ends up buried or separated from the Claude Code pane. Why it matters: A cluttered, misaligned workspace slows down every agent handoff and forces engineers to manually drag panes back into position before they can focus on actual work.

---

## What Changed
Imagine your desktop getting messy with windows scattered everywhere. Previously, the only fix was to close everything and start fresh, or manually drag each window back into place one by one.

We added a single command — `pf tmux realign` — that acts like a "tidy desktop" button. One keystroke, and all the terminal panels snap back into a clean, logical arrangement. The AI assistant's panel (Claude Code) and the status dashboard (TUI) are automatically placed side by side, where they're most useful, no matter how scrambled things got.

You can also choose the shape of the layout — a grid, a wide main panel on top with helpers below, or everything in equal columns — using a simple option.

---

## Why This Approach
The tool speaks directly to tmux (the terminal multiplexer that manages all those panels) using its own built-in layout engine, which means the reset is instantaneous and reliable regardless of how many panels are open. Rather than hard-coding positions, the command reads a live registry of which panel is which (Claude Code, TUI dashboard, worker agents) and intelligently repositions only the ones that matter for daily workflow — the rest fill in automatically. This keeps the command simple to run but smart enough to handle any combination of open panels.

---
