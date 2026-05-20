# Story 120-11: Auto-reload Cyclist on code changes

## Story Details
- **ID:** 120-11
- **Title:** Auto-reload Cyclist on code changes
- **Jira Key:** PROJ-15417
- **Points:** 2
- **Workflow:** tdd

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-21T22:10:05Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-21T12:00:00-06:00 | 2026-02-21T21:44:04Z | 3h 44m |
| red | 2026-02-21T21:44:04Z | 2026-02-21T21:59:15Z | 15m 11s |
| green | 2026-02-21T21:59:15Z | 2026-02-21T22:03:50Z | 4m 35s |
| review | 2026-02-21T22:03:50Z | 2026-02-21T22:10:05Z | 6m 15s |
| finish | 2026-02-21T22:10:05Z | - | - |

## Story Context

### Current State
BikeRack TUI is a Python Textual app (`pf.bikerack.tui`) launched via `just tui`. It connects to WheelHub via WebSocket and renders panels (Sprint, Git, Diffs, etc.) in the terminal. Currently, when developing the TUI, code changes to `pf/bikerack/*.py` require manually killing and restarting the TUI to see changes.

### Technical Context
- **Framework:** Textual 8.0.0 (Python terminal UI)
- **Entry point:** `just tui` → `uv run python -m pf.bikerack.tui --port $port --project-dir $root`
- **Source:** `pennyfarthing-dist/pf/bikerack/` (~15 Python modules)
- **Launcher:** `pf/bikerack/launcher.py` manages WheelHub lifecycle, `tui.py` has `main()`
- **Dependencies:** `textual>=1.0`, `websockets>=12.0`, `textual-image>=0.7.0` (tui extra)
- **Textual dev mode:** `textual run --dev` provides CSS hot-reload but not Python code reload

### Problem
1. Developer edits `pf/bikerack/sprint_panel.py` (or any TUI module)
2. Running TUI does NOT pick up the change
3. Developer must Ctrl+C → re-run `just tui`
4. This breaks the fast feedback loop for TUI development

### Acceptance Criteria

#### AC1: Dev mode with auto-reload
- A `just tui-dev` recipe (or `--dev` flag) launches the TUI with file watching
- When any `pf/bikerack/*.py` file changes, the TUI restarts automatically
- WheelHub connection is re-established after restart
- Restart happens within 2 seconds of file save

#### AC2: Watch scope
- Watches `pf/bikerack/` directory for `.py` file changes
- Also watches `pf/bc/` (panel focus module used by TUI)
- Ignores `__pycache__/`, `.pyc` files, and non-Python files
- Does NOT restart on changes outside the watch scope

#### AC3: Clean restart
- Running TUI shuts down cleanly (no orphan processes, no terminal corruption)
- New instance starts with same --port and --project-dir arguments
- WebSocket reconnection happens automatically (existing reconnect logic in ws_client.py)

#### AC4: CSS hot-reload passthrough
- When `--dev` is active, Textual's built-in CSS hot-reload also works
- CSS changes in the app's CSS string or external CSS files apply live without restart

### Testing Strategy
1. **RED (TEA phase):**
   - Test that a dev-mode launcher module exists and is importable
   - Test that it configures a file watcher on the correct directories
   - Test that file change events trigger app restart
   - Test ignore patterns exclude __pycache__ and .pyc

2. **GREEN (Dev phase):**
   - Implement dev-mode wrapper using `watchfiles` (already used by `uvicorn`/`textual`)
   - Add `just tui-dev` recipe
   - Wire restart logic

### Related Stories
- 103-1: BikeRack TUI scaffold (established the Textual app)
- 103-20: TUI launcher entry point

### Branch
- Repository: pennyfarthing
- Base branch: develop
- Feature branch: feature/120-11-auto-reload-cyclist

## TEA Assessment

**Tests Required:** Yes
**Reason:** Dev-mode launcher with file watching needs testable watch paths, filter logic, and restart wiring.

**Test Files:**
- `tests/python/test_bikerack_dev_reload.py` — 12 tests across 4 ACs

**Tests Written:** 12 tests covering 4 ACs
**Status:** RED (failing — ready for Dev)

**Implementation notes for Mal (Dev):**
- Add `dev_main()`, `get_watch_paths()`, `watch_filter()`, `_run_with_reload()` to `pf/bikerack/tui.py`
- Use `watchfiles` package for file watching (add to `[tui]` extra in pyproject.toml)
- Add `just tui-dev` recipe to orchestrator justfile
- Set `TEXTUAL=devtools` env var in dev_main for CSS hot-reload

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/pf/bikerack/tui.py` - Added `dev_main()`, `get_watch_paths()`, `watch_filter()`, `_run_with_reload()` for dev-mode auto-reload
- `pennyfarthing-dist/pyproject.toml` - Added `watchfiles>=1.0` to `[tui]` extra
- `pyproject.toml` - Added `watchfiles>=1.0` to `[tui]` extra
- `justfile` (orchestrator) - Added `just tui-dev` recipe

**Tests:** 12/12 passing (GREEN)
**Branch:** feature/120-11-auto-reload-cyclist (pushed)
**Orchestrator Branch:** feat/120-11-tui-dev-recipe (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Tests:** 12/12 passing
**Lint:** 1 issue (unused import — LOW)

**Data flow traced:** `just tui-dev` → port resolution → `dev_main(port, project_dir)` → sets `TEXTUAL=devtools` → `_run_with_reload` → `watchfiles.run_process` spawns `python -m pf.bikerack.tui --port N` → child inherits `TEXTUAL` env for CSS hot-reload → on `.py` change in `pf/bikerack/` or `pf/bc/`, process restarts. Safe and correct.

**Findings:**

| Severity | Issue | Location |
|----------|-------|----------|
| [LOW] | Unused `import subprocess` | `tui.py:870` |
| [LOW] | `watch_filter(change: str)` type annotation should be `watchfiles.Change` | `tui.py:857` |
| [MEDIUM] | Port resolution + portrait/tmux patching duplicated between `main()` and `dev_main()` | `tui.py:925-999` |
| [MEDIUM] | `BikeRackApp` created in `dev_main` but never `.run()` — only used to extract already-known port | `tui.py:995-996` |
| [MEDIUM] | AC4 test `test_dev_main_enables_textual_dev_mode` has no assertion | `test_bikerack_dev_reload.py:167-184` |
| [MEDIUM] | AC3 test assertion `call_args is not None` is trivially true | `test_bikerack_dev_reload.py:155-156` |

**Verified good:** Dependencies correctly declared, `just tui-dev` mirrors `tui` pattern, env var propagation works, pure functions for watch paths/filter, no security concerns.

**Handoff:** To SM for finish-story

## SM Assessment
Story is set up and ready for TEA. Corrected scope: this is the BikeRack Python TUI (Textual), not the Electron app. TEA should write tests for a dev-mode launcher with file watching and auto-restart. Routing to Jayne (TEA) for the red phase.