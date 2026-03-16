# 148-24

## Problem

Problem: When Pennyfarthing launches a full agent team (the "Peloton"), all the agent terminal panes appeared in one fixed arrangement — users had no control over how that workspace was organized on screen. Why it matters: Different monitors, different workflows, and different team sizes all benefit from different layouts. A 2-agent pairing session looks very different from a 4-agent full-team run, and forcing a single arrangement wasted screen real estate and made it harder for operators to monitor what each agent was doing.

---

## What Changed

Before this change, when you kicked off a Peloton run, all your AI teammates appeared in their terminal panes in whatever default arrangement the system chose — and that was that.

Now you can choose one of three layouts when you start a session:

- **Horizontal** — panes sit side by side, like columns on a spreadsheet
- **Vertical** — panes stack on top of each other
- **Grid (2×2)** — panes fill a tidy four-square arrangement

The system is also smart about it: if you have 4 or more agents, it automatically picks the grid layout. For 2–3 agents, it defaults to vertical stacking. You can also set your preferred layout once in a config file and never think about it again. And the TUI status dashboard is now always anchored in a consistent spot — directly below the team lead's pane — so you always know where to look.

---

## Why This Approach

Think of it like choosing a window arrangement preset on your computer. The three options — side-by-side, stacked, and grid — cover the practical cases without overwhelming users with infinite choices. The smart default means most users never have to specify anything; the system picks the right shape based on team size. Saving the preference in a config file means power users can set it once and have it apply to every future session automatically. This is a deliberate "sensible default, easy override" design.

---
