# Standalone: tmux config overhaul — CSI u fix, mouse copy, integrated status bar

**Jira:** MSSCI-15736
**Points:** 3
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** both
**Branch:** feat/MSSCI-15736-tmux-config-overhaul
**PR:** pennyfarthing#1149, orc-penny#123
**Started:** 2026-02-25
**Completed:** 2026-02-25

---

## Description

Two hard blockers fixed and several enhancements to the tmux development setup for Pennyfarthing (Kitty + tmux 3.5a + Claude Code).

### Blocker Fixes
- **Shift+Enter:** `extended-keys always` forces CSI u mode without waiting for app request (Claude Code/Ink never sends mode-1 request)
- **Mouse copy:** Removed `smcup@:rmcup@` override that confused alternate screen detection. Added `copy-command 'pbcopy'`. Documented Shift+drag (Kitty) / Option+drag (iTerm2).

### Integrated tmux Status Bar
- statusline.py writes `tmux-status-left` (story + dir) and `tmux-status-right` (context bar) to `.pennyfarthing/`
- bell_mode.py writes `tmux-activity` with real-time tool descriptions from PostToolUse hook
- tmux reads cache files via `#()` shell expansion every 5 seconds
- Layout: story+dir left, tool activity center, context bar+clock right

### New Settings
- `workflow.tui_statusbar` — independent toggle for TUI footer (separate from `workflow.statusbar` which controls CLI statusline)

### Other Enhancements
- Popup shell: Prefix+Space (display-popup, 80%x75%, centered)
- Agent menu: Prefix+a (display-menu with role-based agent list)
- Pane border labels with titles ("Claude Code", "TUI")
- `escape-time 0`, `clipboard` terminal feature

## Files Changed

| File | Change |
|------|--------|
| tmux.conf.sample | Full overhaul — blockers + enhancements |
| tmux-dev | Pane labeling, team spawn recipe |
| pennyfarthing-dist/src/pf/hooks/statusline.py | tmux cache writing, story ID |
| pennyfarthing-dist/src/pf/hooks/bell_mode.py | Tool activity cache for tmux |
| pennyfarthing-dist/src/pf/bikerack/layout_order.py | tui_statusbar toggle |
| pennyfarthing-dist/src/pf/settings/settings.py | tui_statusbar default |
| pennyfarthing-dist/templates/tmux.conf.template | Mirror of tmux.conf.sample |
| pennyfarthing-dist/templates/tmux-dev.template | Mirror of tmux-dev |
| .pennyfarthing/sidecars/tmux-expertise.md | Sidecar with tmux knowledge |
