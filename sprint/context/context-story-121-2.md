# Context: Story 121-2 — Add code quality rules trigger from debug panel

**GitHub Issue:** slabgorb/pennyfarthing-orchestrator#(TBD)
**Jira:** PROJ-15393
**Points:** 3
**Epic:** 121 — Debug Panel and Brownfield Tools Fixes

## Problem

Users currently access brownfield code quality analysis tools (hotspots, dead code, health score) only through the CLI. The BikeRack TUI debug panel is display-only, showing context tokens and message counts, but provides no interactive controls to trigger analysis directly from the terminal UI.

The fix is to add **interactive keybindings and tool triggers** to the BikeRack TUI debug panel, allowing users to run code quality analysis without dropping to the command line.

## Architecture

### BikeRack TUI Components

The BikeRack TUI is a Python Textual-based terminal UI with Rich rendering:

```
tui.py (1,053 lines) — Main TUI app with keybindings
  ├── Keybindings (Textual Binding system)
  │   └── Action handlers → panel methods
  │
base_panel.py (186 lines) — BasePanel(Static) base class
  ├── render_panel(payload) → Rich renderable (Table, Text, Group)
  ├── ws_client subscription model
  └── Support for async workers (Textual.work decorator)
  │
debug_panel.py (248 lines) — Debug panel display
  ├── Shows context tokens (system, user, messages)
  ├── Shows token stats (input, output, cache read/write)
  ├── [NEW] Tool trigger methods (hotspots, dead code, health score)
  ├── [NEW] Async workers for analysis
  └── [NEW] Dynamic view switching (normal view ↔ tool results view)
```

### Current Debug Panel State

Lines 1-80: Token/message counts from WheelHub
Lines 81-248: Static tables (no interactive controls)

### Brownfield Tools (Python)

All tools are available as importable Python modules:

| Tool | Module | Key Functions | Models | CLI |
|------|--------|---------------|--------|-----|
| Hotspots | `pf.hotspots.analyze` (613 lines) | `analyze_all_repos()`, `analyze_repo()` | `FileHotspot`, `DirectoryHotspot`, `HotspotResult` | `pf debug hotspots analyze --format json` |
| Dead Code | `pf.deadcode.analyze` (322 lines) | `analyze_stale()`, `analyze_unused_exports()` | `StaleFile`, `UnusedExport` | `pf debug deadcode stale --format json` |
| Health Score | `pf.healthscore.analyze` (606 lines) | `analyze_all_repos()`, `analyze_repo()` | `HealthScoreResult`, `HealthScoreDimension` | `pf debug healthscore analyze --format json` |

All paths relative to `pennyfarthing/pennyfarthing-dist/`.

### Implementation Strategy: Option A (Direct Python Import)

**Preferred approach:** Import analysis functions directly and call them in a Textual worker, avoiding subprocess overhead.

```python
# In debug_panel.py

from pf.hotspots.analyze import analyze_all_repos as analyze_hotspots
from pf.deadcode.analyze import analyze_stale as analyze_dead_code
from pf.healthscore.analyze import analyze_all_repos as analyze_health

class DebugPanel(BasePanel):
    # ... existing code ...

    @work(exclusive=True)  # Textual worker, blocks duplicates
    async def run_hotspots_analysis(self):
        """Trigger hotspots analysis in background."""
        self.show_loading("Running hotspot analysis...")
        try:
            result = analyze_hotspots()  # Direct Python call
            self.display_hotspots_results(result)
        except Exception as e:
            self.show_error(f"Hotspots failed: {e}")

    @work(exclusive=True)
    async def run_dead_code_analysis(self):
        """Trigger dead code analysis in background."""
        self.show_loading("Running dead code analysis...")
        try:
            stale = analyze_dead_code()
            self.display_dead_code_results(stale)
        except Exception as e:
            self.show_error(f"Dead code failed: {e}")

    @work(exclusive=True)
    async def run_health_score_analysis(self):
        """Trigger health score analysis in background."""
        self.show_loading("Running health score analysis...")
        try:
            result = analyze_health()
            self.display_health_score_results(result)
        except Exception as e:
            self.show_error(f"Health score failed: {e}")
```

### Keybindings

Add to `tui.py` Binding registry (lines ~300-350):

```python
# When debug panel is active
Binding("h", "debug_hotspots", "Hotspots (h)", show=True),
Binding("d", "debug_deadcode", "Dead Code (d)", show=True),
Binding("s", "debug_healthscore", "Health Score (s)", show=True),
Binding("escape", "debug_back", "Back (esc)", show=True),
```

Action handlers in tui.py:

```python
def action_debug_hotspots(self):
    """Trigger hotspots analysis from debug panel."""
    debug_panel = self.query_one("DebugPanel")
    debug_panel.run_hotspots_analysis()

def action_debug_deadcode(self):
    """Trigger dead code analysis from debug panel."""
    debug_panel = self.query_one("DebugPanel")
    debug_panel.run_dead_code_analysis()

def action_debug_healthscore(self):
    """Trigger health score analysis from debug panel."""
    debug_panel = self.query_one("DebugPanel")
    debug_panel.run_health_score_analysis()

def action_debug_back(self):
    """Return to normal debug view from tool results."""
    debug_panel = self.query_one("DebugPanel")
    debug_panel.show_normal_view()
```

### Display Results

Tool results render as Rich Tables in the debug panel, replacing the normal token view:

**Hotspots table:**
```
File                          Churn  Avg Days  Frequency
─────────────────────────────────────────────────────────
src/core/server/api.ts        45     12.3      3.2x/week
src/public/hooks/useGit.ts    38     8.1       2.1x/week
```

**Dead Code table:**
```
Stale Files (Last Modified >90 days ago)
─────────────────────────────────────────────
File                              Days Stale
src/legacy/old-component.tsx       287
packages/example/unused.js         156
```

**Health Score radar/dimension table:**
```
Dimension           Score  Trend
────────────────────────────────
Churn               65%    ↑
Complexity          72%    →
Test Coverage       81%    ↑
```

### View State Management

Add to DebugPanel:

```python
class DebugPanel(BasePanel):
    def __init__(self):
        super().__init__()
        self.current_view = "normal"  # "normal" | "hotspots" | "deadcode" | "healthscore"
        self.loading = False
        self.last_results = None

    def show_loading(self, message: str):
        """Display loading state."""
        self.loading = True
        # Render: "Analyzing... [message]"

    def show_normal_view(self):
        """Return to token/context display."""
        self.current_view = "normal"
        self.loading = False
        self.refresh()

    def display_hotspots_results(self, result):
        """Show hotspots data as table."""
        self.current_view = "hotspots"
        self.last_results = result
        self.refresh()

    # Similar for dead_code, health_score...
```

## Key Files

| File | Lines | Purpose | Change |
|------|-------|---------|--------|
| `pf/bikerack/debug_panel.py` | 248 | Debug panel display | Add tool trigger methods, workers, results display (80-120 lines) |
| `pf/bikerack/tui.py` | 1,053 | TUI app and keybindings | Add hotspots/deadcode/healthscore actions (30-50 lines) |
| `pf/bikerack/base_panel.py` | 186 | BasePanel base class | No changes (worker pattern already available) |
| `pf/hotspots/analyze.py` | 613 | Hotspots analysis engine | No changes (import and call directly) |
| `pf/deadcode/analyze.py` | 322 | Dead code analysis engine | No changes (import and call directly) |
| `pf/healthscore/analyze.py` | 606 | Health score analysis engine | No changes (import and call directly) |

All paths relative to `pennyfarthing/pennyfarthing-dist/`.

## Acceptance Criteria

### AC1: Tool keybindings register in TUI
- **Given** the BikeRack TUI is running with debug panel active
- **When** keybinding help is displayed
- **Then** hotspots (h), dead code (d), and health score (s) actions appear with descriptions

### AC2: Hotspots analysis triggers from TUI
- **Given** the debug panel is displayed
- **When** the user presses `h`
- **Then** the panel shows "Analyzing hotspots..." and runs `analyze_all_repos()` in a background worker

### AC3: Hotspots results display as table
- **Given** hotspots analysis completes successfully
- **When** the worker finishes
- **Then** a Rich Table renders showing files sorted by churn, with columns: File, Churn, Avg Days, Frequency

### AC4: Dead code analysis triggers from TUI
- **Given** the debug panel is displayed
- **When** the user presses `d`
- **Then** the panel shows "Analyzing dead code..." and runs stale file detection in a background worker

### AC5: Dead code results display with tabs
- **Given** dead code analysis completes successfully
- **When** the worker finishes
- **Then** the panel displays tabs: "Stale Files" and "Unused Exports" with sortable tables

### AC6: Health score analysis triggers from TUI
- **Given** the debug panel is displayed
- **When** the user presses `s`
- **Then** the panel shows "Analyzing health score..." and runs `analyze_all_repos()` in a background worker

### AC7: Health score results display dimensions
- **Given** health score analysis completes successfully
- **When** the worker finishes
- **Then** a Rich Table renders dimensions (churn, complexity, coverage, etc.) with scores and trend indicators

### AC8: Escape returns to normal debug view
- **Given** tool results are displayed
- **When** the user presses `escape`
- **Then** the panel returns to the normal token/context display (no regression)

### AC9: Loading state prevents duplicate triggers
- **Given** a tool analysis is running
- **When** the user presses the hotkey again
- **Then** the duplicate request is ignored (Textual `@work(exclusive=True)` prevents concurrency)

### AC10: Errors are displayed gracefully
- **Given** an analysis fails (timeout, import error, etc.)
- **When** the worker catches the exception
- **Then** the panel displays "Error: [message]" with option to retry

## Implementation Notes

### Direct Python Import (Option A)

**Advantages:**
- No subprocess overhead
- Direct data access (no JSON serialization/deserialization)
- Shared Python process (memory efficient)
- Can pass options to functions (e.g., `analyze_repo(repo_path)`)

**Risks:**
- Import errors if `pf` package structure changes
- Analysis functions must be async-compatible or run in a thread
- Textual workers use `asyncio` — may need wrapping for sync functions

**Solution:** Use Textual's `to_thread` for sync analysis functions:

```python
from textual.work import work

@work(exclusive=True)
async def run_hotspots_analysis(self):
    from pf.hotspots.analyze import analyze_all_repos
    # Block in thread pool, don't freeze TUI
    result = await self.app.run_worker(analyze_all_repos)
    self.display_hotspots_results(result)
```

### Alternative: Subprocess (Option B)

If import issues arise, fall back to subprocess:

```python
import subprocess
import json

@work(exclusive=True)
async def run_hotspots_analysis(self):
    try:
        output = subprocess.check_output(
            ["pf", "debug", "hotspots", "analyze", "--format", "json"],
            text=True
        )
        result = json.loads(output)
        self.display_hotspots_results(result)
    except subprocess.CalledProcessError as e:
        self.show_error(f"Hotspots failed: {e}")
```

**Trade-off:** Subprocess is slower but more isolated.

### View Switching

The debug panel renders different content based on `self.current_view`:

```python
def render_panel(self, payload):
    if self.current_view == "normal":
        return self.render_token_stats()
    elif self.current_view == "hotspots":
        return self.render_hotspots_results()
    elif self.current_view == "deadcode":
        return self.render_dead_code_results()
    elif self.current_view == "healthscore":
        return self.render_health_score_results()
```

### Timeout Handling

Analysis functions may take 10-60 seconds depending on repo size. The TUI should:
- Show "Analyzing..." immediately (responsive UX)
- Display a cancel hint (optional: `Ctrl+C` to abort)
- Handle timeout gracefully (show error, return to normal view)

## Testing Strategy

### Unit Tests (Python)

- Mock `analyze_all_repos`, `analyze_stale`, etc.
- Verify `run_hotspots_analysis()` calls the correct function
- Verify `display_hotspots_results()` sets correct view state
- Verify `show_normal_view()` resets view state

### Integration Tests

- Render DebugPanel in Textual test harness
- Simulate keypress: `h` → check worker runs
- Mock analysis result → verify table renders
- Simulate `escape` → check return to normal view

### Manual QA

- Run `pf bikerack start`
- Press `d` to open debug panel
- Press `h` → Hotspots analysis starts, table appears after 5-30 seconds
- Press `escape` → return to token display
- Press `d` → Dead code analysis, verify stale files table
- Press `s` → Health score analysis, verify dimension scores
- Press `escape` → return to normal view (no errors in terminal)

## Risks & Constraints

### Analysis Timeout

Hotspots and health score analysis may take 30-60 seconds on large multi-repo workspaces. The TUI should remain responsive (workers run in thread pool, not blocking event loop).

### Import Path Brittleness

If `pf.hotspots`, `pf.deadcode`, or `pf.healthscore` modules are restructured, imports will fail at runtime. Consider wrapping in try/except with helpful error message.

### No React or Express Involved

This story is **pure Python Textual**. Do not add React hooks, Express routes, or GUI components. The Cyclist GUI (React) already has tool dialogs (story 121-3).

## Dependencies

- **Story 121-1** (optional context dependency) — understanding hotspots/dead code/health score modules
- All brownfield analysis modules already exist and are importable
- No external API or database changes required
