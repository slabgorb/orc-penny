# Demo Script — 148-13

**Total runtime: ~6 minutes**

**Scene 1 — Title (0:00–0:30)**
*Slide 1: Title*
Open with: "We're fixing a subtle but annoying issue that was causing agent pane commands to silently operate on the wrong tmux session."

**Scene 2 — The Problem (0:30–1:30)**
*Slide 2: Problem*
Say: "The framework manages Claude Code and the TUI dashboard side-by-side in tmux panes. Every pane command — run a test, launch an agent, split a window — goes through the `pf tmux` CLI. That CLI has to know which session it's operating in."

Walk through the bug: "Before the fix, the CLI listed all sessions alphabetically and picked the first one. If you had two sessions — say `pf-bare-pf-1` (a placeholder) and `pf-pf-1-0` (your real session) — it would pick `pf-bare-pf-1` because 'b' comes before 'p'. Every pane command silently targeted the wrong session."

Show Slide 2 bullet: *"Alphabetical session selection ignores which session you're actually in."*

**Scene 3 — What We Built (1:30–3:00)**
*Slide 3: What We Built*

Live demo portion — if tmux is available:
```bash
# Show the old behavior concept — list-sessions returns alphabetically
tmux -L pf list-sessions -F "#{session_name}"

# Show the new detection — display-message returns attached session
tmux -L pf display-message -p "#{session_name}"
```
Point out: "The first command returns whatever's first alphabetically. The second returns *where you actually are*. That's the fix — use the right question."

If live demo fails: show Slide 3 with the before/after code comparison instead.

**Scene 4 — Why This Approach (3:00–4:00)**
*Slide 4: Why This Approach*
"We didn't add complexity — we removed a wrong assumption. The code that listed sessions was correct for the fallback case (running outside tmux), so we kept it, but we promoted the direct query to first position. Two lines changed in the logic, zero new dependencies."

**Scene 5 — Before/After (4:00–5:00)**
*Before/After slide*
Show the comparison. Walk through: "Before: always list → always pick first alphabetically. After: ask tmux which session I'm in → if that fails, list → prefer real sessions over bare placeholders."

**Scene 6 — Roadmap (5:00–5:30)**
*Roadmap slide*
"This fix is foundational for the saddle mode work coming in 148-14 through 148-16, where background observer agents will need reliable session targeting to inject into the right pane context."

**Scene 7 — Questions (5:30–6:00)**
*Questions slide*

---
