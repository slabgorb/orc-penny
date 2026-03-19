**Setup before presenting:** Open a Pennyfarthing session with at least 4 panes active. Deliberately resize and shuffle panes so the layout looks messy — TUI separated from Claude pane, uneven splits. Have the terminal ready.

---

**Scene 1 — The Messy Workspace (0:00–0:45)**
*(Slide 2: Problem)*

Walk up to the terminal showing the disorganized layout. Say: "This is a real snapshot of what a workspace looks like after 30 minutes of active development. The status dashboard is down here in the corner, the Claude pane is up top, and two worker panels are scattered in the middle. If I need to hand off to a new agent right now, I have to reorient myself before I can even start."

Point at the disconnected TUI and Claude panes. Let it sit for a beat.

*Fallback: If terminal isn't available, show the Before slide with a screenshot of the disorganized layout.*

---

**Scene 2 — One Command to Fix It (0:45–1:30)**
*(Slide 3: What We Built)*

Say: "Here's the fix." Type exactly:

```
pf tmux realign
```

The terminal immediately outputs:
```
Layout reset to 'tiled' (4 panes)
TUI pane moved adjacent to Claude Code pane
```

Pan the camera or point at the screen. All panes are now in an even grid, TUI sitting directly next to Claude Code.

Say: "That's it. One command. The system figured out where everything should go."

*Fallback: If the live demo fails, flip to the After slide showing the clean grid layout screenshot.*

---

**Scene 3 — Choosing a Layout (1:30–2:15)**
*(Slide 3: What We Built — second beat)*

Say: "You're not locked into one shape. If you prefer having Claude dominating the top half with helpers below, you run:"

```
pf tmux realign --layout main-horizontal
```

Output:
```
Layout reset to 'main-horizontal' (4 panes)
TUI already adjacent to Claude Code pane
```

Say: "Five presets built in — tiled grid, horizontal split, vertical split, equal columns, equal rows. Pick what fits your screen."

*Fallback: Show the slide listing all 5 layout names with a thumbnail of each.*

---

**Scene 4 — Why This Matters for the Team (2:15–2:45)**
*(Slide 4: Why This Approach)*

No live demo. Return to slides. Say: "The reason this works reliably is that it reads our live panel registry — it knows which panel is Claude, which is the TUI, which are workers — and makes intelligent placement decisions rather than just shuffling randomly. No panel gets lost."

---