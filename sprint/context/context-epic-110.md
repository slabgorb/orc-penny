# Epic 110: BikeRack TUI — Interactive Command Center

**Repos:** pennyfarthing
**Status:** in_progress

## Overview

Transform BikeRack Python TUI from passive monitor to interactive command center.
Four phases: event bus, drill-through, image header, split layouts.

## Architecture

- **Framework:** Python Textual 1.0+ with Rich rendering
- **Location:** `pennyfarthing_scripts/bikerack/`
- **Base class:** `BasePanel(Static)` — panels render Rich text, subscribe to WebSocket channels
- **Connection:** `WheelHubClient` with auto-reconnect, multi-channel WebSocket subscription
- **Layout:** Currently single-panel-at-a-time with show/hide toggling (7 panels, 1-7 keys)

## Key Files

| File | Purpose |
|------|---------|
| `tui.py` | Main app, layout, tab bar, keyboard bindings |
| `base_panel.py` | Abstract base (channel subscription, Rich rendering) |
| `ws_client.py` | WebSocket client with auto-reconnect |
| `sprint_panel.py` | Sprint status, epic grouping, j/k/e navigation |
| `diffs_panel.py` | Diff viewer, syntax highlighting, n/p file navigation |
| `changed_panel.py` | Changed files grouped by repo |
| `progress_panel.py` | Unified story/workflow/AC/git summary |

## Design Patterns

### Cross-Panel Event Bus (110-1)
Textual `Message` system for panel communication:
```python
class NavigateToFile(Message):
    def __init__(self, path: str): ...
# ChangedPanel posts it, App routes it, DiffsPanel handles it
```

### Story Drill-Through (110-2)
Textual `Screen.push()`/`pop()` for modal detail views:
```python
class StoryDetailScreen(Screen):
    BINDINGS = [("escape", "pop_screen", "Back")]
```

### Image Header (110-3)
`textual-image` library with pre-app protocol detection:
- Supports Kitty TGP, Sixel, halfcell/unicode fallback
- Protocol detection MUST run before `App.run()`
- Portrait assets exist: `portraits/{theme}/small/{slug}.png`

### Split Layouts (110-4)
Textual `Horizontal` container for side-by-side panes:
```python
with Horizontal():
    with VerticalScroll(id="split-left"): yield panel_a
    with VerticalScroll(id="split-right"): yield panel_b
```

## Dependencies

Current TUI deps: `textual>=1.0`, `websockets>=12.0`
New: `textual-image` (for 110-3)

## UX Design Reference

Full design patterns in: `.pennyfarthing/sidecars/ux-designer/textual-tui-patterns.md`
