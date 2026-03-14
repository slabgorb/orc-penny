# Textual TUI Patterns for TUI

## Reference: Textual Widget Gallery Patterns

### High-Value Widgets for TUI

| Widget | Pattern | TUI Application |
|--------|---------|---------------------|
| **DataTable** | Row/col/cell cursors, sorting, arrow key nav | Story drill-through — selectable story list |
| **Tree** | Expandable hierarchical nodes, Enter to select | Epic → story → detail navigation |
| **DirectoryTree** | File/folder icons, lazy expand, keyboard nav | Changed files browser (replace flat list) |
| **TabbedContent** | Tabs + ContentSwitcher, keyboard tab switching | Replace show/hide panel pattern with native tabs |
| **Collapsible** | Native expand/collapse with ▼/▶ indicators | Epic groups (currently hand-rolled in SprintPanel) |
| **MarkdownViewer** | Rendered markdown + table of contents sidebar | Story context/session file viewer |
| **Sparkline** | Compact `▁▂▃▄▅▆▇█` bar charts | Already used in DebugPanel — could extend |
| **OptionList** | Vertical selectable list with Rich renderables | File picker, story selector |
| **ProgressBar** | Built-in ETA + percentage | Replace hand-rolled `render_progress_bar()` |
| **Select** | Dropdown with keyboard nav | Epic filter, status filter |
| **ListView** | Items as other widgets, arrow key selection | Composable list for stories with rich formatting |
| **ContentSwitcher** | Toggle child visibility without reflow | Split-view panel switching |
| **Footer** | Dynamic key binding display | Already used — extend with context-sensitive bindings |
| **Log/RichLog** | Append-only scrolling text | Audit log panel, streaming output |
| **Rule** | `<hr>` separator styles (solid, heavy, dashed, double) | Section dividers |
| **Switch** | Toggle on/off | Settings toggles (bell mode, relay mode) |
| **Input** | Single-line text with cursor | Filter/search within panels |
| **TextArea** | Multi-line with syntax highlighting + line numbers | Inline diff editing (future) |

### Interaction Patterns

**Cursor-based navigation (DataTable model):**
- Arrow keys move cursor between items
- Enter/Space activates selected item
- Home/End jump to first/last
- Page Up/Down for fast scrolling
- This is the pattern for drill-through

**Tree navigation (DirectoryTree model):**
- Up/Down moves between visible nodes
- Right expands, Left collapses
- Enter activates leaf node
- This fits epic → story hierarchy perfectly

**Tab navigation (TabbedContent model):**
- Click tab or keyboard shortcut
- Content switches without layout reflow
- Active tab has underline indicator
- Current TUI already does this but hand-rolled

### Layout Patterns

**Horizontal/Vertical containers:**
```python
from textual.containers import Horizontal, Vertical

# Split view: two panels side by side
with Horizontal():
    yield SprintPanel()
    yield DiffsPanel()
```

**Screen push/pop (modal drill-through):**
```python
from textual.screen import Screen

class StoryDetailScreen(Screen):
    """Full-screen story detail view pushed on Enter."""
    BINDINGS = [("escape", "pop_screen", "Back")]

    def compose(self):
        yield StoryDetail(story_id=self.story_id)
```

---

## Image Rendering Options

### Option A: `textual-imageview` (half-block characters)
- **Rendering:** Each character = 2 pixels using Unicode half-blocks
- **Compatibility:** Any terminal with truecolor support
- **Quality:** Low resolution but universally works
- **Dependency:** `pip install textual-imageview`
- **Use case:** Portrait header — acceptable at small size (e.g., 20x10 chars)
- **Limitation:** GPU-accelerated terminal recommended (Alacritty)

### Option B: `textual-image` (protocol-aware)
- **Rendering:** Auto-detects Kitty TGP, Sixel, or falls back to halfcell/unicode
- **Compatibility:** Best quality on Kitty/WezTerm/iTerm2; fallback everywhere else
- **Quality:** Near-native image quality on supported terminals
- **Dependency:** `pip install textual-image`
- **Key gotcha:** Protocol detection must happen BEFORE `App.run()` — Textual's background threads interfere with terminal capability handshake
- **Terminal support:** Kitty, WezTerm, Konsole, foot, iTerm2 (full); tmux Sixel-only; NO support in GNOME Terminal, Warp, Windows Console

### Option C: Rich-native (no extra dependency)
- **Rendering:** Convert image to colored block characters using Pillow
- **Compatibility:** Anywhere Rich works
- **Quality:** Lowest, but fine for small decorative headers
- **Dependency:** Just Pillow (already in `portraits` optional dep)

### Recommendation: Option B (`textual-image`)
Best bang for buck. Auto-detection means it looks amazing on modern terminals and degrades gracefully. Portrait images already exist in the asset pipeline.

### Implementation Pattern for Image Header
```python
# In AgentHeader or new PersonaImageHeader widget
from textual_image.widget import Image as TextualImage

class PersonaHeader(Static):
    def compose(self):
        # Portrait path from theme + agent
        portrait_path = f"portraits/{theme}/small/{slug}.png"
        with Horizontal():
            yield TextualImage(portrait_path, classes="portrait")  # 10-char wide
            yield AgentInfo()  # name, role, quote
```

---

## Design Patterns for Requested Features

### 1. Story Drill-Through

**Current state:** SprintPanel renders flat `Rich.Text` lines. No item selection beyond epic j/k navigation.

**Pattern:** Replace story list rendering with Textual's `DataTable` or `ListView` for per-story cursor. Enter on a story pushes a `StoryDetailScreen`.

**Data available from `/ws/sprint`:**
- id, title, points, status, jiraKey, hasContext, assignedTo, workflow, priority

**Data needed for detail (new endpoint or file read):**
- Acceptance criteria, session file contents, PR status, branch name, context file

**Implementation approach:**
1. Add `s` keybinding for "select story" mode within SprintPanel
2. Arrow keys move story cursor (separate from epic j/k)
3. Enter pushes `StoryDetailScreen` via `self.app.push_screen()`
4. Escape pops back to sprint overview
5. Detail screen shows: full AC list, session state, workflow phase, git branch, PR link

### 2. Changed File → Diffs Cross-Panel Navigation

**Current state:** ChangedPanel uses `FullFileTree` (React) / flat file list (TUI). No cross-panel linking.

**Pattern:** Make changed files selectable. Enter on a file:
1. Switches to Diffs panel
2. Sets `_current_file_index` to match the selected file

**Implementation:**
1. Replace flat `Text` rendering in `ChangedPanel` with `OptionList` or `ListView`
2. Add Enter handler that:
   - Finds the file in diffs payload by path match
   - Calls `diffs_panel._current_file_index = matched_index`
   - Calls `app.action_switch_panel('diffs')`
3. This is cross-panel communication — use `app.query_one()` to reach DiffsPanel

### 3. Panel Splits

**Current state:** One panel visible at a time (show/hide pattern).

**Pattern:** Textual's `Horizontal` container for side-by-side splits.

**Implementation options:**
- **Quick:** `Shift+S` toggles split mode, shows current panel + a second selectable panel
- **Better:** Named split layouts (e.g., "sprint+diffs", "changed+diffs", "progress+debug")
- **Best:** User-configurable split with `pf bc split <left> <right>`

**Layout change:**
```python
# Current: VerticalScroll with hidden panels
with VerticalScroll():
    yield SprintPanel(display=True)
    yield GitPanel(display=False)

# Split: Horizontal container with two visible panels
with Horizontal():
    with VerticalScroll(id="split-left"):
        yield SprintPanel()
    with VerticalScroll(id="split-right"):
        yield DiffsPanel()
```

### 4. Image Header (Portrait)

**Current state:** AgentHeader shows text only (role badge, character name, theme, quote).

**Pattern:** Add persona portrait image next to agent info text.

**Asset pipeline:** Already exists — `portrait-resolver.ts` finds `portraits/{theme}/small/{slug}.png`. Need a Python equivalent or HTTP fetch from Frame `/api/portrait`.

**Implementation:**
1. Add `textual-image` to `[tui]` optional deps
2. Create `PersonaImageHeader` widget using `Horizontal` layout
3. Left: `textual_image.widget.Image` (8-10 char width for small portrait)
4. Right: existing `AgentHeader` text content
5. Fetch portrait path from persona WebSocket data or resolve locally
6. Graceful fallback: if no portrait or unsupported terminal, show text-only header

---

## Textual CSS Patterns

```tcss
/* Split layout */
Horizontal > VerticalScroll {
    width: 1fr;           /* Equal split */
    border-right: solid dim;
}

/* Story detail screen */
StoryDetailScreen {
    align: center middle;
    background: $surface;
}

/* DataTable in panel */
DataTable {
    height: 1fr;
    scrollbar-size: 1 1;
}
DataTable > .datatable--cursor {
    background: $accent 30%;
}

/* Portrait image sizing */
.portrait {
    width: 12;
    height: 6;
    margin-right: 1;
}
```

---

## Priority Order for Implementation

1. **Changed → Diffs cross-nav** (smallest change, biggest daily UX win)
2. **Story drill-through** (high value, moderate effort — needs detail screen)
3. **Image header** (delightful, needs new dependency + fallback handling)
4. **Panel splits** (most architectural change, biggest layout refactor)
