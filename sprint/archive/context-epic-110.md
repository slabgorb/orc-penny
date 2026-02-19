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

### Context Meter Footer Bar (110-5)
Add a persistent footer status bar showing context window usage.

**Approach:**
- New `ContextFooter` widget (or augment existing `BindingFooter`) at bottom of layout
- Subscribe to `/ws/context` WebSocket channel (already consumed by DebugPanel)
- Render a Rich progress bar: `[████░░░░░░] 45%` with tier badge (FULL/REFRESH/HANDOFF)
- Color-code by tier: green (<50%), yellow (50-80%), red (>80%)
- Placement: between `VerticalScroll` and `BindingFooter`, always visible regardless of active panel

**Key files:**
- `tui.py` — layout composition (`compose()` method), mount new widget
- `debug_panel.py` — reference impl for context progress bar rendering (lines 167-169)
- `base_panel.py` — channel subscription pattern

**ACs:**
1. Footer bar displays context usage percentage, always visible
2. Bar color reflects tier thresholds (green/yellow/red)
3. Updates in real-time via `/ws/context` channel
4. Does not interfere with keybinding footer display

### Project Directory Indicator in TUI Header (110-6)
Show the active project directory in the TUI header area.

**Approach:**
- Extend `AgentHeader` widget to include project path after theme name
- Data source: resolve from WheelHub connection URL or `.wheelhub-port` parent directory
- Display truncated path: `~/Projects/pf-1` or just basename `pf-1`
- Dim styling to avoid visual competition with agent character name

**Key files:**
- `tui.py` — `AgentHeader` class (lines 152-213), `_render_header()` method
- `ws_client.py` — connection metadata may carry project path

**ACs:**
1. Project directory name visible in header area
2. Path is human-readable (~ expansion, truncation for long paths)
3. Updates if WheelHub reconnects to a different project
4. Fits within AgentHeader's 3-line max height constraint

### Fix Velocity and Sprint Count Points (110-7)
Bug fix: velocity metric shows 0 or missing in sprint panel.

**Approach:**
- Investigate `sprint-data.ts` aggregation logic for `metrics.velocity` field
- The sprint panel reads `metrics.get("velocity", 0)` but the field may not be populated
- Fix: calculate velocity from completed points across recent sprints, or from archive data
- Ensure `done`/`remaining`/`inProgress` counts reflect points (not just story counts) where appropriate

**Key files:**
- `packages/cyclist/src/sprint-data.ts` — `getSprintData()` aggregation, `SprintMetrics` interface
- `pennyfarthing_scripts/bikerack/sprint_panel.py` — rendering (lines 221-234)
- `sprint/archive/` — historical sprint data for velocity calculation

**ACs:**
1. Velocity displays a non-zero value based on actual completed work
2. Sprint story counts match YAML source of truth
3. Points totals are accurate across done/in-progress/remaining

### Hook Up Audit Log Panel (110-8)
Create an AuditLogPanel that displays tool use events in real-time.

**Approach:**
- Add `/ws/audit` WebSocket channel in `packages/cyclist/src/websocket.ts` (follow existing channel pattern)
- Broadcast OTLP tool events to subscribed audit clients
- Create `audit_log_panel.py` subclassing `BasePanel`, subscribe to `"audit"` channel
- Render with Rich Table: timestamp | tool name | input excerpt | success/fail badge
- Panel icon already registered: `"audit-log": ("\uf15c", "L")` in `base_panel.py`
- Mount in `tui.py` `compose()`, add to tab bar and keybinding

**Key files:**
- `packages/core/src/server/api/audit-log.ts` — existing REST API (data model reference)
- `packages/core/src/server/otlp-receiver.ts` — `ToolEvent` interface, event store
- `packages/cyclist/src/websocket.ts` — add new channel (lines 160-164 pattern)
- `pennyfarthing_scripts/bikerack/tui.py` — register panel in compose/bindings
- `pennyfarthing_scripts/bikerack/base_panel.py` — panel icon already registered

**ACs:**
1. Audit log panel renders tool events with timestamp, tool name, and result
2. Events stream in real-time via WebSocket
3. Panel accessible via keybinding (consistent with other panels)
4. Scrollable history with newest events at bottom

## Dependencies

Current TUI deps: `textual>=1.0`, `websockets>=12.0`
New: `textual-image` (for 110-3)

## UX Design Reference

Full design patterns in: `.pennyfarthing/sidecars/ux-designer/textual-tui-patterns.md`
