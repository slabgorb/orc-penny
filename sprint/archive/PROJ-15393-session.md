# Session: PROJ-15393 — Add code quality rules trigger from debug panel

## Story
- **ID:** 121-2 / PROJ-15393
- **Title:** Add code quality rules trigger from debug panel
- **Epic:** 121 — BikeRack TUI Debug Panel and Brownfield Tools Integration
- **Points:** 3
- **Workflow:** tdd (SM → TEA → Dev → Reviewer → SM)
- **Branch:** feature/PROJ-15393-tui-debug-panel-code-quality-triggers
- **Assignee:** keith.avery@slabgorb.io

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

## Context Reference

See `sprint/context/context-story-121-2.md` for full technical architecture and implementation details.

## Key Files

| File | Path | Purpose | Change |
|------|------|---------|--------|
| `pf/bikerack/debug_panel.py` | `pennyfarthing-dist/` | Debug panel display | Add tool trigger methods, workers, results display (80-120 lines) |
| `pf/bikerack/tui.py` | `pennyfarthing-dist/` | TUI app and keybindings | Add hotspots/deadcode/healthscore actions (30-50 lines) |
| `pf/bikerack/base_panel.py` | `pennyfarthing-dist/` | BasePanel base class | No changes (worker pattern already available) |
| `pf/hotspots/analyze.py` | `pennyfarthing-dist/` | Hotspots analysis engine | No changes (import and call directly) |
| `pf/deadcode/analyze.py` | `pennyfarthing-dist/` | Dead code analysis engine | No changes (import and call directly) |
| `pf/healthscore/analyze.py` | `pennyfarthing-dist/` | Health score analysis engine | No changes (import and call directly) |

## Implementation Strategy

### Direct Python Import (Preferred)
Import analysis functions directly and call them in a Textual worker, avoiding subprocess overhead:
- Import: `from pf.hotspots.analyze import analyze_all_repos as analyze_hotspots`
- Use Textual workers with `@work(exclusive=True)` to run sync functions without blocking TUI
- Use `to_thread` for sync analysis functions to avoid freezing the terminal

### Keybindings
Add to `tui.py` Binding registry:
- `h` — hotspots analysis
- `d` — dead code analysis
- `s` — health score analysis
- `escape` — return to normal view

### View State Management
Implement in DebugPanel:
- `current_view` state: "normal" | "hotspots" | "deadcode" | "healthscore"
- `loading` flag to prevent duplicate triggers
- `last_results` to cache results

## Phase: red

## TEA Assessment

**Tests Required:** Yes
**Reason:** 10 ACs require new interactive methods, keybindings, view state, and error handling

**Test Files:**
- `tests/python/test_bikerack_debug_panel_tools.py` — 48 tests covering all 10 ACs

**Tests Written:** 48 tests covering 10 ACs
**Status:** RED (47 failing, 1 pass from Textual built-in `loading` — ready for Dev)

**Coverage by AC:**
- AC1: 9 tests — keybindings (h, d, s, escape), action methods on BikeRackApp
- AC2: 3 tests — `run_hotspots_analysis` method, loading state on trigger
- AC3: 5 tests — hotspots table rendering (file paths, churn, sort order, last_results)
- AC4: 2 tests — `run_dead_code_analysis` method, loading state
- AC5: 5 tests — stale files display, unused exports display, section headers
- AC6: 2 tests — `run_health_score_analysis` method, loading state
- AC7: 5 tests — composite score, dimension names, dimension scores, last_results
- AC8: 5 tests — escape from each view resets to normal, context data renders again
- AC9: 3 tests — loading attribute, show_loading flag, loading indicator renders
- AC10: 5 tests — show_error method, error message rendering, error clears on escape
- Cross-cutting: 4 tests — view state transitions, render_panel dispatches by view

**Key interfaces for Dev:**
- `DebugPanel.current_view` — "normal" | "hotspots" | "deadcode" | "healthscore"
- `DebugPanel.show_loading(message)` — set loading state
- `DebugPanel.show_normal_view()` — reset to normal token/context display
- `DebugPanel.show_error(message)` — display error with retry
- `DebugPanel.display_hotspots_results(result)` — render hotspots table
- `DebugPanel.display_dead_code_results(stale, exports)` — render dead code tables
- `DebugPanel.display_health_score_results(result)` — render health dimensions
- `DebugPanel.run_hotspots_analysis()` — async worker method
- `DebugPanel.run_dead_code_analysis()` — async worker method
- `DebugPanel.run_health_score_analysis()` — async worker method
- `BikeRackApp.action_debug_hotspots/deadcode/healthscore/back` — TUI actions
- Keybindings: h, d, s, escape

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/pf/bikerack/debug_panel.py` — view state management, display methods, worker methods, render functions for hotspots/deadcode/healthscore/error views
- `pennyfarthing-dist/pf/bikerack/tui.py` — keybindings (h, d, s, escape) and action_debug_* handlers

**Tests:** 48/48 passing (GREEN) + 35 existing tests pass (83 total, 0 regressions)
**Branch:** feature/PROJ-15393-tui-debug-panel-code-quality-triggers (pushed)

**Handoff:** To Reviewer

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** keypress h → action_debug_hotspots → query_one → run_worker(exclusive) → analyze_all_repos → display_hotspots_results → render_panel dispatch (safe — guarded by panel focus check, error handling wraps analysis)
**Pattern observed:** View state machine with loading priority at debug_panel.py:175, deferred imports at debug_panel.py:131-172
**Error handling:** try/except in all run_*_analysis methods routes to show_error(); show_normal_view() clears all state atomically
**Observations:** 7 items (5 verified good, 1 low severity, 1 verified pattern)
**Handoff:** To SM for finish-story

## Status
- Created: 2026-02-23
- Phase: review
- Reviewer approved, ready for SM finish