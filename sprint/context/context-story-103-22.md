---
parent: context-epic-103.md
workflow: trivial
---

# Story 103-22: TUI pane shows raw SGR mouse/focus escape sequences on startup

## Business Context

When the BikeRack TUI launches, raw SGR (Select Graphic Rendition) escape sequences for mouse tracking and focus events appear briefly in the terminal pane. These sequences look like `\x1b[?1000h`, `\x1b[?1004h`, or similar control codes that leak into visible output instead of being consumed by the terminal emulator. This creates a poor first impression — the TUI is supposed to be a polished dashboard, and visible escape codes signal broken software.

This is a 1-point polish bug in the post-MVP batch of epic 103. Fixing it improves the startup experience for all TUI users.

## Technical Guardrails

- **TUI stack:** Python Rich/Textual app in `pennyfarthing-dist/src/pf/tui/`
- **Textual mouse/focus:** Textual enables mouse tracking and focus reporting via SGR escape sequences on startup. If these are emitted before the terminal is fully initialized or if they leak to a shared output stream, they appear as raw text.
- **tmux interaction:** The TUI runs in a tmux pane. tmux may intercept or relay escape sequences differently depending on terminal capabilities and `TERM` settings.
- **Do not modify:** WheelHub server, WebSocket channels, or any panel data pipeline — this is purely a TUI terminal initialization issue.

## Scope Boundaries

**In scope:**
- Identify where SGR mouse/focus escape sequences leak during TUI startup
- Suppress or properly sequence the escape code emission so they are consumed by the terminal, not displayed
- Verify fix works in iTerm2, Kitty, and tmux contexts

**Out of scope:**
- WheelHub or WebSocket changes (story 103-27 handles reconnection)
- Color threshold alignment (story 103-23)
- Debug panel prerequisites (story 103-24)
- tui.py deduplication (story 103-25)

## AC Context

**AC1: No raw escape sequences visible on TUI startup**
- Launch the TUI via `just tui` or `pf bikerack start`
- No `\x1b[...` or `^[[...` sequences should appear in the TUI pane or the adjacent Claude Code pane
- Verify in both tmux and standalone terminal contexts

**AC2: Mouse and focus tracking still functional after fix**
- If Textual uses mouse events or focus tracking, those features must still work correctly after the fix
- Panel switching, scrolling, and click interactions (if any) should be unaffected
