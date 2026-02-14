# Story 103-20: TUI launcher entry point (just tui)

**Epic:** 103 — BikeRack TUI — Terminal-Native Dashboard
**Jira:** (no Jira key assigned)
**Points:** 2
**Status:** In Progress
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/103-20-tui-launcher-entry-point

## Acceptance Criteria

This story represents a TUI entry point refactoring to standardize how the BikeRack TUI launcher is invoked. Likely encompasses:
- Streamlining the launcher CLI path (`just tui` → BikeRackApp)
- Simplifying entry points in `pennyfarthing_scripts/bikerack/`
- Ensuring `pf bikerack start` correctly initializes the TUI

See `sprint/epic-MSSCI-14951.yaml` for full story definition.

## Technical Context

**Epic 103 Overview:**
Replace browser-based BikeRack dashboard with a terminal-native TUI companion built on Rich/Textual (Python). Connects to WheelHub over WebSocket, renders 10 panels via `/bc` slash command. Consumes existing WebSocket channels unchanged — zero server-side modifications.

**Key Architecture:**
- WheelHub server runs on port 2898 (BikeRack mode)
- WebSocket channels already exist: `/ws/sprint`, `/ws/git`, `/ws/diffs`, `/ws/todos`, `/ws/story`, `/ws/background-tasks`, `/ws/spans`, `/ws/context`, `/ws/persona`, `/ws/focus`
- TUI connects as pure Python client consuming these channels
- Panel persistence uses existing ERB mechanism (`.pennyfarthing/state/`)
- `/bc show <panel>` slash command sends focus messages via `/ws/focus` channel

**Critical Path Dependencies:**
- Story 103-1: Textual app scaffold ✓ DONE
- Story 103-2: WheelHub WebSocket client ✓ DONE
- Story 103-3: `pf bikerack` launcher command ✓ DONE
- Story 103-4: Connection status indicator ✓ DONE
- Story 103-5: Base panel abstraction ✓ DONE
- Story 103-6: SprintPanel implementation ✓ DONE
- Story 103-7: `/bc` slash command ✓ DONE
- Story 103-8: Panel persistence ✓ DONE

**Current State:**
- BikeRackApp class fully implemented in `tui.py`
- PanelIndicator and ConnectionStatus widgets complete
- WebSocket client with auto-reconnect in `ws_client.py`
- Base panel abstraction and SprintPanel working
- GitPanel implemented
- Focus channel subscription active
- Panel persistence via `.pennyfarthing/sidecars/bc_state.json`

## Files of Interest

| File | Purpose | Status |
|------|---------|--------|
| `pennyfarthing_scripts/bikerack/tui.py` | BikeRackApp main class, layout, event handlers | Complete |
| `pennyfarthing_scripts/bikerack/ws_client.py` | WebSocket client with auto-reconnect, subscriptions | Complete |
| `pennyfarthing_scripts/bikerack/base_panel.py` | BasePanel abstraction, Rich rendering | Complete |
| `pennyfarthing_scripts/bikerack/sprint_panel.py` | SprintPanel implementation | Complete |
| `pennyfarthing_scripts/bikerack/git_panel.py` | GitPanel implementation | Complete |
| `pennyfarthing_scripts/bikerack/cli.py` | BikeRack CLI entry point (`pf bikerack start/stop/status`) | Complete |
| `pennyfarthing_scripts/bikerack/launcher.py` | Launcher orchestration, port discovery, process management | Complete |
| `pennyfarthing_scripts/bikerack/__main__.py` | Entry point for `python -m pennyfarthing_scripts.bikerack` | Complete |
| `pennyfarthing_scripts/cli.py` | Main pf CLI, bikerack command registration (line 99) | Complete |
| `pennyfarthing_scripts/bc/focus.py` | Panel persistence: `get_last_panel()`, `save_last_panel()` | Referenced |
| `.pennyfarthing/config.local.yaml` | Theme, launcher port config | Referenced |

## Implementation Notes

**Story 103-20 Scope:**
This story likely involves streamlining the TUI launcher entry point. Possible focus areas:
1. Simplify `bikerack/__main__.py` if needed
2. Ensure `just tui` command works correctly (if Justfile exists)
3. Verify clean initialization path from CLI → launcher → TUI
4. Possibly refactor launcher CLI to be more direct

**Testing Strategy (TDD):**
1. Write tests that verify CLI entry point returns success
2. Verify WheelHub connection is attempted on startup
3. Verify BikeRackApp initializes with proper layout
4. Verify last panel is restored correctly

**Known Working Patterns:**
- WebSocket subscriptions in `ws_client.py` handle both `init` and `update` messages
- Panel render methods return Rich renderable objects
- Focus channel uses `{type:'init'|'update', focus:'<panel>'|null}` schema
- Connection state reactive properties trigger widget updates
- Worker tasks safely manage async WebSocket loops

---

**Session Start:** 2026-02-14
**Assigned To:** (setup mode)
**Next Phase:** Development by test engineer

## TEA Assessment

**Tests Required:** Yes
**Reason:** Story needs a standalone TUI launcher entry point — currently `tui.py` has no `main()`, no CLI parsing, no port discovery. Core functionality.

**Test Files:**
- `tests/python/test_bikerack_tui_launcher.py` — 11 tests across 8 classes

**Tests Written:** 11 tests covering 6 ACs
- AC1: `main()` function exists and is callable (2 tests)
- AC2: `main(port=N)` passes port to WheelHubClient (2 tests)
- AC3: `main(project_dir=X)` reads `.bikerack-port` for port discovery (1 test)
- AC4: `main()` creates WheelHubClient, passes to BikeRackApp, calls `app.run()` (2 tests)
- AC5: Falls back to default port 2898 when no port file exists (1 test)
- AC6: `just tui` recipe exists in orchestrator and pennyfarthing justfiles (2 tests)
- CLI: `tui.py` has `if __name__ == '__main__'` block (1 test)

**Status:** RED (all 11 failing — ImportError for missing `main()`, missing justfile recipes)

**Implementation guidance for Dev:**
1. Add `main(port=None, project_dir=None)` to `tui.py` — reads `.bikerack-port`, creates `WheelHubClient(port=...)`, creates `BikeRackApp(client=client)`, calls `app.run()`
2. Add `if __name__ == '__main__'` block with argparse for `--port` flag
3. Add `tui` recipe to `pennyfarthing/justfile` and orchestrator `justfile`

**Handoff:** To Dev (Korben Dallas) for GREEN phase

## SM → TEA Handoff

**Timestamp:** 2026-02-14
**From:** SM (Ruby Rhod)
**To:** TEA (Leeloo)
**Phase:** setup → red
**Notes:** Story 103-20 set up with TDD workflow. All 8 dependency stories (103-1 through 103-8) are complete. TEA should design tests for the TUI launcher entry point — focusing on `just tui` command, CLI initialization path, and BikeRackApp startup verification.

## TEA → Dev Handoff

**Timestamp:** 2026-02-14
**From:** TEA (Leeloo)
**To:** Dev (Korben Dallas)
**Phase:** red → green
**Test Result:** RED — 11 tests failing, ready for implementation
**Test File:** tests/python/test_bikerack_tui_launcher.py
**Notes:** All tests fail on ImportError (main() missing) and missing justfile recipes. Dev needs to implement main() in tui.py, add __main__ block, and create just tui recipes in both justfiles.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/tui.py` — Added `main(port, project_dir)` function, `WheelHubClient` import, `if __name__` CLI block with argparse
- `pennyfarthing/justfile` — Added `tui` recipe delegating to `python -m pennyfarthing_scripts.bikerack.tui`
- `justfile` (orchestrator) — Added `tui` recipe delegating to pennyfarthing

**Tests:** 11/11 passing (GREEN), 15/15 existing TUI tests — no regressions
**PR:** #871 (pennyfarthing), #19 (orchestrator)
**Branch:** feat/103-20-tui-launcher-entry-point (both repos)

**Handoff:** To Reviewer (Zorg) for code review

## Dev → Reviewer Handoff

**Timestamp:** 2026-02-14
**From:** Dev (Korben Dallas)
**To:** Reviewer (Jean-Baptiste Emanuel Zorg)
**Phase:** green → review
**Test Result:** GREEN — 11/11 passing, 0 regressions
**PRs:** #871 (pennyfarthing), #19 (orchestrator)
**Notes:** Minimal implementation — main() in tui.py, argparse CLI, just tui recipes in both justfiles. Port discovery reads .bikerack-port with 2898 fallback.

## Reviewer Assessment

**Verdict:** APPROVED

| Severity | Observation | Location |
|----------|-------------|----------|
| [VERIFIED] | Data flow traced: just tui → argparse → main() → WheelHubClient → BikeRackApp → app.run() | `tui.py:159-181` |
| [VERIFIED] | start_tui() in launcher.py now works (previously broken — no __main__ block) | `launcher.py:220` |
| [VERIFIED] | Error handling: invalid port file caught, falls back to default | `tui.py:170-173` |
| [VERIFIED] | Security: port int-validated by argparse, project_dir is Path | `tui.py:184-193` |
| [LOW] | Duplicated DEFAULT_PORT constant (also in ws_client.py:30) | `tui.py:156` |
| [LOW] | Unused `import subprocess` in test file | `test_bikerack_tui_launcher.py:14` |
| [MEDIUM] | Source inspection test per DEC-REV-003 — acceptable | `test_bikerack_tui_launcher.py:174-183` |

**Handoff:** To SM (Ruby Rhod) for finish-story

## Reviewer → SM Handoff

**Timestamp:** 2026-02-14
**From:** Reviewer (Jean-Baptiste Emanuel Zorg)
**To:** SM (Ruby Rhod)
**Phase:** review → finish
**Verdict:** APPROVED
**PRs Merged:** #871 (pennyfarthing), #19 (orchestrator)
**Notes:** Clean implementation. No Critical or High issues. 4 verified items, 2 LOW, 1 MEDIUM (acceptable per DEC-REV-003). Both PRs merged to develop.
