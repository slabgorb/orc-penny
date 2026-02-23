# Epic 121: BikeRack TUI Debug Panel and Brownfield Tools Integration

## Overview

Enhance the BikeRack TUI (Python Textual terminal UI) debug panel with keybindings and interactive controls to trigger brownfield code analysis tools (hotspots, dead code, health score). Improve TUI refresh rates, fix footer keybinding labels, and resolve git sync cache staleness. Two of four stories are complete; the remaining two add tool triggers to the TUI debug panel and fix git state cache busting.

**Why now:** The BikeRack TUI is the primary interface for monitoring agent sessions in terminal environments. The debug panel currently displays context usage and token statistics but offers no way to trigger on-demand analysis. Story 121-2 integrates the Python brownfield analysis CLIs directly into the TUI, allowing agents to run hotspot, dead code, and health score analysis without leaving the terminal UI.

## Background

### BikeRack TUI Architecture

BikeRack is a Python terminal UI built on the **Textual** framework, running alongside the Claude Code CLI. Key architectural components:

- **Main app** (`tui.py`, 1,053 lines) — panel registry, keybinding routing, split-pane layout manager
- **BasePanel** (`base_panel.py`, 186 lines) — abstract base for all panels; handles WebSocket subscription to WheelHub channels
- **StatusFooter** (`context_meter_footer.py`, 266 lines) — unified footer showing keybinding labels and context meter (121-3 fixed bracket formatting here)
- **WebSocket client** (`ws_client.py`, 203 lines) — maintains persistent connection to WheelHub server
- **Panel implementations** — each panel extends BasePanel and renders Rich renderables via `render_panel()` method

### Debug Panel (TUI)

The debug panel (`debug_panel.py`, 248 lines) currently:
1. Subscribes to `context` and `token-stats` WebSocket channels from WheelHub
2. Displays context tier, token counts, injected context breakdown, and a sparkline
3. Renders metrics via Rich tables and progress bars
4. **No tool triggers** — display-only

Story 121-2 adds **keybindings or interactive menu options** to trigger brownfield analysis directly from the debug panel, with results rendered inline as Rich tables.

### Brownfield Analysis Tools (Python CLIs)

All tools are available as Python CLI commands and can be imported directly in Python:

- **Hotspots** (`pf/hotspots/`) — CLI: `pf debug hotspots analyze --format json` (cli.py: 155 lines, analyze.py: 613 lines)
- **Dead Code** (`pf/deadcode/`) — CLI: `pf debug deadcode stale --format json` (cli.py: 164 lines, analyze.py: 322 lines)
- **Health Score** (`pf/healthscore/`) — CLI: `pf debug healthscore analyze --format json` (cli.py: 81 lines, analyze.py: 606 lines)

The TUI can invoke these tools via:
- Direct Python import: `from pf.hotspots.analyze import analyze_all_repos`
- Subprocess: `subprocess.run(['pf', 'debug', 'hotspots', 'analyze', '--format', 'json'])`
- WheelHub API channels (if server-side router is available)

### Git Panel Caching Issue (121-4)

The git panel (`git_panel.py`, 402 lines) subscribes to the `git` WebSocket channel and displays branch name, dirty status, and stash state. The git cache doesn't invalidate after write operations (e.g., commit, checkout), causing stale display. Story 121-4 fixes cache busting in the WheelHub server's git module.

## Technical Architecture

### Component Map (TUI-Focused)

```
BikeRack TUI (tui.py, 1,053 lines)
  |-- Panel Registry & Keybindings
  |-- Split-pane layout manager
  |
  |-- DebugPanel (debug_panel.py, 248 lines)
  |     |-- Subscribes to: "context", "token-stats" WebSocket channels
  |     |-- Renders: Context Usage, Token Stats (Rich tables/progress)
  |     |-- [121-2] NEW: Tool triggers
  |     |     |-- Keybinding "h" → run hotspots analysis → render results inline
  |     |     |-- Keybinding "d" → run dead code analysis → render results inline
  |     |     |-- Keybinding "s" → run health score analysis → render results inline
  |     |     |-- OR: Add "Tools" submenu with interactive selection
  |
  |-- GitPanel (git_panel.py, 402 lines)
  |     |-- Subscribes to: "git" WebSocket channel
  |     |-- Displays: branch, dirty status, stash state
  |     |-- [121-4] Issue: Cache doesn't invalidate after writes
  |
  |-- BasePanel (base_panel.py, 186 lines)
  |     |-- Abstract base class
  |     |-- Handles WS subscription pattern
  |     |-- render_panel() method for Rich renderables
  |
  |-- StatusFooter (context_meter_footer.py, 266 lines)
  |     |-- [121-3 DONE] Fixed bracket labels in keybinding display
  |     |-- Displays active keybindings with corrected format
  |
  v
WheelHub WebSocket Server (packages/core, packages/cyclist)
  |-- Manages "context", "token-stats", "git" channels
  |-- Broadcasts deltas on context/token changes
  |-- Git module caches repo info (issue: stale cache in 121-4)
  |
  v
Python Brownfield Analysis Tools (pennyfarthing-dist/pf/)
  |-- hotspots/analyze.py (613 lines) — analyze repository churn
  |-- deadcode/analyze.py (322 lines) — find stale files and unused exports
  |-- healthscore/analyze.py (606 lines) — compute 8-dimension health score
```

### Key Files

| File | Path | Lines | Purpose | Stories |
|------|------|-------|---------|---------|
| `pf/bikerack/debug_panel.py` | `pennyfarthing-dist/` | 248 | TUI debug panel; add tool triggers | 121-2 |
| `pf/bikerack/tui.py` | `pennyfarthing-dist/` | 1,053 | Main TUI app; keybinding router, panel registry | 121-2 |
| `pf/bikerack/base_panel.py` | `pennyfarthing-dist/` | 186 | Abstract panel base; WS subscription pattern | — |
| `pf/bikerack/context_meter_footer.py` | `pennyfarthing-dist/` | 266 | StatusFooter with keybinding display | 121-3 |
| `pf/bikerack/git_panel.py` | `pennyfarthing-dist/` | 402 | TUI git panel; shows branch, dirty status | 121-4 |
| `pf/bikerack/ws_client.py` | `pennyfarthing-dist/` | 203 | WebSocket client; connection management | — |
| `pf/hotspots/analyze.py` | `pennyfarthing-dist/` | 613 | Core hotspot analysis engine | 121-2 |
| `pf/hotspots/cli.py` | `pennyfarthing-dist/` | 155 | Hotspots CLI: `pf debug hotspots analyze` | 121-2 |
| `pf/deadcode/analyze.py` | `pennyfarthing-dist/` | 322 | Core dead code analysis engine | 121-2 |
| `pf/deadcode/cli.py` | `pennyfarthing-dist/` | 164 | Dead code CLI: `pf debug deadcode stale` | 121-2 |
| `pf/healthscore/analyze.py` | `pennyfarthing-dist/` | 606 | Core health score computation (8 dimensions) | 121-2 |
| `pf/healthscore/cli.py` | `pennyfarthing-dist/` | 81 | Health score CLI: `pf debug healthscore analyze` | 121-2 |
| `packages/core/src/server/git.ts` | `pennyfarthing/` | — | Git cache management (server-side) | 121-4 |
| `packages/core/src/server/ws-routes.ts` | `pennyfarthing/` | — | WebSocket channel subscriptions | 121-4 |

All paths relative to `pennyfarthing/` unless noted as `pennyfarthing-dist/`.

### WebSocket Integration (TUI ↔ WheelHub)

The TUI communicates with WheelHub via persistent WebSocket connection. Channels:

- **`context`** — broadcasts token tier, counts, injected context breakdown on changes
- **`token-stats`** — broadcasts input/output/cache stats
- **`git`** — broadcasts git status (branch, dirty, stash) — currently **cached/stale**
- (Future) **`analysis-results`** — could stream brownfield analysis results as they complete (async analysis)

### Python Brownfield Tool Integration Approaches

**Option 1: Direct Python Import (Synchronous)**
```python
from pf.hotspots.analyze import analyze_all_repos

async def run_hotspots_analysis(self):
    try:
        results = analyze_all_repos(days=90)
        self.render_results(results)  # render as Rich table
    except Exception as e:
        self.display_error(str(e))
```

**Option 2: Subprocess (Allows async, isolates tool process)**
```python
import subprocess
import json

async def run_hotspots_analysis(self):
    try:
        output = subprocess.run(
            ['pf', 'debug', 'hotspots', 'analyze', '--format', 'json'],
            capture_output=True, text=True, timeout=30
        )
        results = json.loads(output.stdout)
        self.render_results(results)
    except subprocess.TimeoutExpired:
        self.display_error("Hotspots analysis timed out (30s)")
```

**Option 3: WheelHub API Router (if server-side route exists)**
```python
# Requires a WheelHub Express router that spawns Python CLI and returns JSON
# GET /api/hotspots → { data: HotspotData, ... }
# The TUI makes HTTP GET via ws_client or separate HTTP client
```

## Stories

| Story | Title | Points | Priority | Status | Dependencies |
|-------|-------|--------|----------|--------|-------------|
| 121-1 | Improve debug panel refresh rate for real-time token usage | 2 | P1 | done (2026-02-20) | None |
| 121-2 | Add code quality tool triggers to TUI debug panel | 3 | P2 | backlog | None (all tools exist) |
| 121-3 | Fix footer keybinding labels — bracket display inaccurate | 1 | P1 | done (2026-02-21) | None |
| 121-4 | Fix git sync cache busting for stale TUI state | 2 | P2 | backlog | None |

### Story Notes

**121-2: Add code quality tool triggers to TUI debug panel**

Integrate brownfield analysis tools (hotspots, dead code, health score) into the debug panel via keybindings or interactive menu controls. Users should be able to trigger analysis on-demand and see results rendered inline in the TUI.

**Implementation approach:**

1. **Add keybindings** to `DebugPanel` (or register at TUI level):
   - `h` — run hotspots analysis
   - `d` — run dead code analysis
   - `s` — run health score analysis
   - `?` — show tools help/menu (optional)

2. **Create analysis runner methods** in DebugPanel:
   ```python
   async def run_hotspots(self):
       # Show "Analyzing..." indicator
       # Spawn subprocess or direct import (decide: direct or subprocess)
       # Parse results → JSON
       # Render as Rich table inline
       # Update display
   ```

3. **Render results inline** using Rich renderables:
   - Hotspots: Table with (file path, churn rank, commit count, last change)
   - Dead code: Table with (stale files path, days unchanged) and (unused export name, usage count)
   - Health score: Table with (dimension name, score, status indicator)

4. **Handle timeouts and errors:**
   - Hotspots CLI timeout: 30s
   - Health score CLI timeout: 60s
   - Display error message if analysis fails or times out
   - Show "Loading..." state with a progress indicator

5. **Optional: Add submenu in StatusFooter:**
   - If keybindings feel crowded, add a "Tools" submenu accessible via `m` (menu) in the debug panel
   - Submenu lists: Hotspots, Dead Code, Health Score, Help
   - User navigates with arrow keys, selects with Enter

**Key considerations:**
- **No React dialogs in TUI** — render results as Rich tables inline in the panel
- **Async execution** — use `asyncio.to_thread()` or subprocess to avoid blocking TUI
- **Tool availability** — check if `pf` CLI is available; if not, display fallback message
- **Results storage** — cache last results so user can re-scroll without re-running analysis
- **Keybinding conflicts** — verify new keybindings don't shadow other panels' shortcuts (check `tui.py` keybinding registry)

**121-4: Fix git sync cache busting for stale TUI state**

See `sprint/context/context-story-121-4.md` for full technical context. The WheelHub git module caches repo metadata (branch, dirty status, stash count) but doesn't invalidate the cache after write operations (commit, checkout, stash). This causes the TUI git panel and Cyclist GUI to display stale information.

**Root cause:** The git cache key in WheelHub (`packages/core/src/server/git.ts`) has no cache invalidation trigger for post-write operations. The cache TTL is too long or nonexistent.

**Expected fix scope:**
- Add cache invalidation hooks in the WheelHub git module
- Invalidate cache on post-commit, post-checkout, post-branch, post-stash events
- Optionally implement a shorter TTL or on-demand bust endpoint
- Verify TUI git panel picks up fresh state immediately after operations

## Constraints

- **TUI only, no React changes** — 121-2 is purely TUI and Python CLI integration; Cyclist GUI is out of scope
- **No new WheelHub APIs required** — Python brownfield tools already exist as CLIs; TUI can invoke via subprocess or direct import
- **Tool timeouts** — hotspots (30s), health-score (60s). Long analyses may timeout on large repos; UI must show loading states and handle gracefully
- **Keybinding namespace** — all new keybindings must not conflict with existing TUI shortcuts (check `tui.py` registry before finalizing)
- **121-4 is independent of 121-2** — separate root causes; can be worked in any order
- **Backward compatibility** — status footer changes in 121-3 must not break existing keybinding display in other panels
