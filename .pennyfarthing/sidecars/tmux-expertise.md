# tmux Expertise Sidecar

## Environment
- Kitty + tmux 3.5a + Claude Code
- Dedicated socket: `tmux -L pf` with project-specific `tmux.conf`
- Layout: top pane (Claude Code), bottom pane (TUI)

## Key Fixes Applied

### Shift+Enter (CSI u mode)
- **Root cause:** `extended-keys on` waits for app to request mode 1 (`\033[>4;1m`). Claude Code (Ink/React) never sends this request.
- **Fix:** `set -s extended-keys always` — forces CSI u without app request
- Must be server option (`-s`), not session (`-g`)
- `xterm-keys on` is legacy no-op since tmux 2.4 — removed

### Mouse Copy
- **Root cause:** Claude Code's mouse mode captures all mouse events. `smcup@:rmcup@` override confused tmux's alternate screen detection, making it worse.
- **Fix:** Removed `smcup@:rmcup@`. Primary copy method: **Shift+drag** (Kitty) or **Option+drag** (iTerm2) bypasses all mouse capture. Manual: Prefix+[ for copy mode.
- Added `set -s copy-command 'pbcopy'` (tmux 3.2+ default pipe target)

## tmux Status Line Integration
- `statusline.py` writes `.pennyfarthing/tmux-status` as side-channel on each hook invocation
- tmux reads with `#(cat #{pane_current_path}/.pennyfarthing/tmux-status 2>/dev/null)`
- Content: agent abbreviation, theme character, story ID, project dir, context bar
- tmux format uses `#[fg=colour...]` tags (NOT ANSI escapes — tmux strips those in status)
- `_tmux_context_bar()` builds tmux-formatted progress bar with color tiers

## tmux Features Used

| Feature | Version | Our Usage |
|---------|---------|-----------|
| `extended-keys always` | 3.2+ | Force CSI u for Shift+Enter |
| `copy-command` | 3.2+ | Default clipboard pipe |
| `display-popup` | 3.2+ | Prefix+Space popup shell |
| `display-menu` | 3.0+ | Prefix+a agent menu |
| `pane-border-status` | 2.3+ | Agent labels on pane borders |
| `pane-border-format` | 2.3+ | Custom border content |
| `allow-passthrough all` | 3.3+ | Kitty image protocol |
| Status `#(cmd)` | 1.0+ | Shell commands in status line |

## Pane Naming
- `select-pane -T "title"` sets pane title
- `pane-border-format " #{pane_index}: #{pane_title} "` displays in borders
- tmux-dev sets: pane 0 = "Claude Code", pane 1 = "TUI"

## Known Issues
- `TERM_PROGRAM=tmux` inside tmux hides Kitty — pass via `-e TERM_PROGRAM=$TERM_PROGRAM`
- Claude Code issue #6072 tracks TERM_PROGRAM detection
- tmux status line `#()` commands run every `status-interval` seconds (5s default)
- `#{pane_current_path}` must resolve to project root for cache file path
- **TUI startup race:** SGR mouse events and focus-in (`^[[I`) arrive before Textual initializes terminal modes, printing raw escape sequences. Fix: `clear &&` before `just tui` in tmux-dev. If it happens mid-session, resize the pane to force a full Textual redraw: `tmux resize-pane -t %1 -y 24 && tmux resize-pane -t %1 -y 25`

## Real-Time Tool Activity
- PostToolUse hook (`bell_mode.py`) writes `.pennyfarthing/tmux-activity` on each tool use
- Derives human-readable label from tool_name + tool_input:
  - Bash: uses `description` field (or truncated command)
  - Read/Edit/Write: shows tool + filename
  - Grep/Glob: shows tool + pattern
  - Task: shows subagent description
- tmux reads with `#(cat .pennyfarthing/tmux-activity 2>/dev/null)`
- Displayed in italics between context bar and clock

## Cache Files
- `.pennyfarthing/tmux-status` — written by statusline.py (agent, story, dir, context bar)
- `.pennyfarthing/tmux-activity` — written by bell_mode.py PostToolUse (current tool label)

## Config Files
- `tmux.conf.sample` — project config (loaded via `tmux -L pf -f`)
- `tmux-dev` — launcher script (creates session, splits panes, labels)
- Templates at `pennyfarthing/pennyfarthing-dist/templates/tmux*.template`
