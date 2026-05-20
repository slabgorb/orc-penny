# Story 103-1: Textual app scaffold with basic layout

**Jira:** PROJ-14956
**Epic:** 103 — BikeRack TUI — Terminal-Native Dashboard
**Points:** 2
**Priority:** P0
**Workflow:** tdd
**Phase:** finish
**Branch:** feature/103-1-bikerack-tui-scaffold
**Repos:** pennyfarthing

## Description

Create the core Textual application shell for BikeRack TUI. Single-panel layout with header (connection status area), main content area (panel render target), and footer (panel name, keybindings). Entry point for `pf bikerack` to launch.

## Acceptance Criteria

- [ ] Textual app launches with header, main content area, and footer
- [ ] Header has placeholder for connection status
- [ ] Footer shows panel name and keybinding hints
- [ ] Main content area serves as panel render target
- [ ] App exits cleanly on quit keybinding (q)
- [ ] Entry point callable from Python (`from pennyfarthing_scripts.bikerack.tui import BikeRackApp`)

## Technical Context

- **Stack:** Python — Textual (TUI framework), Rich (rendering)
- **New deps:** `textual` (pip)
- **Existing code:** `pennyfarthing/pennyfarthing_scripts/bikerack/` has launcher and CLI
- **Epic context:** `sprint/context/context-epic-103.md`
- **Key pattern:** All panels share channel subscription + Rich rendering pattern
- **Port discovery:** `.bikerack-port` file in project root
- **Config:** `.pennyfarthing/config.local.yaml` via `load_pennyfarthing_config()`

## Key Files

- `pennyfarthing/pennyfarthing_scripts/bikerack/tui.py` — NEW: BikeRackApp Textual application
- `pennyfarthing/pennyfarthing_scripts/bikerack/` — Existing launcher/CLI code
- `pennyfarthing/packages/cyclist/src/server.ts` — WheelHub server (reference)

## TEA Assessment

**Tests Required:** Yes
**Test File:** `pennyfarthing/tests/python/test_bikerack_tui.py`

**Tests Written:** 15 tests covering 6 ACs
**Passing:** 3 (import/entry point — stub works)
**Failing:** 12 (layout, widgets, bindings — need implementation)
**Status:** RED (failing on assertions, not imports)

**Test Classes:**
- `TestImportAndEntryPoint` (3 tests) — AC6: import, subclass, title
- `TestAppLayout` (4 tests) — AC1: Header, Footer, #main-content, three regions
- `TestConnectionStatusHeader` (2 tests) — AC2: #connection-status widget, default disconnected state
- `TestFooter` (2 tests) — AC3: Footer presence, 'q' keybinding in BINDINGS
- `TestMainContentArea` (2 tests) — AC4: Container type, placeholder content
- `TestQuitBehavior` (2 tests) — AC5: 'q' exits app, quit action defined

**Stub:** `pennyfarthing_scripts/bikerack/tui.py` — minimal BikeRackApp(App) with no compose/bindings
**Dep installed:** `textual==7.5.0`, `rich==14.3.2` (add to pyproject.toml dependencies)

**Handoff:** To Dev (Winchester) for GREEN implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/tui.py` — BikeRackApp with compose(), BINDINGS, Header/Footer/VerticalScroll layout
- `pyproject.toml` — Added `[tui]` optional dependency group with `textual>=1.0`

**Tests:** 15/15 passing (GREEN)
**PR:** #845 — feat(103-1): BikeRack TUI scaffold with Textual
**Branch:** feature/103-1-bikerack-tui-scaffold (pushed)

**Implementation notes:**
- `TITLE = "BikeRack"` for app identification
- `Binding("q", "quit", "Quit")` for clean exit
- `Static("● Disconnected", id="connection-status")` for header status placeholder
- `VerticalScroll(id="main-content")` with placeholder Static child as panel render target
- textual added as optional dep `[tui]` — not in core dependencies since only BikeRack TUI needs it

**Handoff:** To Reviewer (Colonel Potter) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Tests:** 15/15 GREEN — confirmed via preflight
**Lint:** Implementation clean; test file has 9x LOW F841 (standard Textual pattern)
**Data flow traced:** Static content only — no external data, zero security surface
**Pattern observed:** Correct Textual `App` subclass with `compose()` + `Binding` at `tui.py:12-26`
**Error handling:** N/A for scaffold — Textual framework manages event loop errors
**Wiring:** Scaffold only — launcher integration (103-3) and WebSocket (103-2) are separate stories

| Severity | Observation | Location |
|----------|-------------|----------|
| `[LOW]` | Unused `pilot` vars in tests (F841) | test_bikerack_tui.py:55,61,67,76,94,103,123,149,157 |
| `[LOW]` | `#connection-status` at root, not inside Header | tui.py:23 |
| `[MEDIUM]` | Test uses private `_exit` attr | test_bikerack_tui.py:182 |

**No Critical or High issues.**
**Handoff:** To SM (Hawkeye) for finish

## SM Assessment

Foundation story for the BikeRack TUI epic. TDD workflow — Radar (TEA) writes tests first for the Textual app scaffold, then Winchester (Dev) implements. No server-side changes needed. Pure Python consumer of existing WebSocket infrastructure.
