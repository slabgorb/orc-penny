# Story 103-8: Panel persistence (extend ERB mechanism)

## Story Details
- **ID:** 103-8
- **Workflow:** tdd
- **Jira:** MSSCI-14963
- **Points:** 2
- **Epic:** 103 (BikeRack TUI — Terminal-Native Dashboard)
- **Repo:** pennyfarthing

## Description
Extend the existing Cyclist panel saving mechanism to persist last-viewed panel for TUI. On launch, restore last panel instead of defaulting to Sprint (Sprint remains default if no saved state). Single source of truth shared with ERB version.

**Functional Requirements:** FR8
**Non-Functional Requirements:** NFR12

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-14T17:24:33Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-14T00:56:58-05:00 | 2026-02-14T05:58:36+0000 | 1m |
| red | 2026-02-14T05:58:36+0000 | 2026-02-14T06:10:48Z | 12m |
| green | 2026-02-14T06:10:48Z | 2026-02-14T08:37:22Z | 2h 26m |
| review | 2026-02-14T08:37:22Z | 2026-02-14T17:24:33Z | 8h 47m |
| finish | 2026-02-14T17:24:33Z | - | - |

## Technical Context

### Existing Infrastructure (from Epic 103 Context)

The TUI is being built as a terminal companion to WheelHub that connects over WebSocket. The panel persistence mechanism needs to be shared with the existing Electron-based BikeRack (ERB) implementation.

**Current ERB Panel Persistence (Browser Mode):**
- Likely stored in localStorage or a config file
- Single source of truth needed for both ERB and TUI

**TUI Architecture:**
- Python-based using Textual framework
- Connects to WheelHub via WebSocket
- 10 panels total, each switchable via `/bc` command
- Port discovery via `.bikerack-port` file

### Dependencies
- Story 103-1: Textual app scaffold with basic layout (prerequisite for TUI to exist)
- Story 103-5: Base panel abstraction (prerequisite for panel switching mechanism)

### Notes
- This is a P1 story with 2 points (likely for both ERB and TUI implementation)
- Should be a "trivial" workflow but marked as "tdd" in incoming params — verify classification
- Focus: extend existing mechanism, not create new persistence system

## TEA Assessment

**Tests Required:** Yes
**Reason:** Panel persistence requires config I/O validation, TUI integration, and cross-platform consistency

**Test Files:**
- `pennyfarthing_scripts/tests/test_tui_panel_persistence.py` — Python tests (20 tests, 5 ACs)
- `packages/cyclist/tests/MSSCI-14963-panel-persistence.test.ts` — TypeScript tests (15 tests, 3 ACs)

**Stubs Created:**
- `pennyfarthing_scripts/bc/focus.py` — `get_last_panel()`, `save_last_panel()` (return `success: False`)
- `packages/cyclist/src/focus.ts` — `getLastPanel()`, `saveLastPanel()` (throw not-implemented)
- `pennyfarthing_scripts/bikerack/tui.py` — added import for persistence functions

**Tests Written:** 35 tests covering 5 ACs
- AC1: `get_last_panel()` reads `last_panel` from `config.local.yaml` (6 Python + 6 TS)
- AC2: `save_last_panel()` writes `last_panel` to `config.local.yaml` (5 Python + 5 TS)
- AC3: TUI restores last panel on startup, defaults to sprint (3 Python)
- AC4: TUI persists panel on focus change (4 Python)
- AC5: Shared config key + roundtrip (2 Python + 4 TS edge cases)

**Status:** RED (15 Python failing, 15 TypeScript failing — all on assertions/stubs)
**5 Python tests pass coincidentally** (negative cases: reject invalid, no-op on null/init, graceful error)

**Architecture Notes for Dev:**
- `config.local.yaml:last_panel` is the shared key (both ERB and TUI)
- Python: implement `get_last_panel()` / `save_last_panel()` in `bc/focus.py` using existing `_read_config`/`_write_config` helpers
- TypeScript: implement `getLastPanel()` / `saveLastPanel()` in `focus.ts` using existing `parseYaml` pattern from `getConfigFocus()`
- TUI: wire `get_last_panel()` into `on_mount()` for restore, `save_last_panel()` into `_handle_focus_message()` for persist
- Validate panel names against `VALID_PANELS` / `VALID_FOCUS_PANELS`

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bc/focus.py` — implement `get_last_panel()` / `save_last_panel()` using existing `_read_config`/`_write_config` helpers
- `packages/cyclist/src/focus.ts` — implement `getLastPanel()` / `saveLastPanel()` following `getConfigFocus()` pattern
- `pennyfarthing_scripts/bikerack/tui.py` — restore last panel on `on_mount()`, persist on focus change

**Tests:** 35/35 passing (GREEN) — 20 Python + 15 TypeScript
**PR:** #863 — feat(103-8): panel persistence (extend ERB mechanism)
**Branch:** feat/103-8-panel-persistence-erb (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** WS focus message → `_handle_focus_message` → `save_last_panel()` → YAML write → next launch `on_mount()` → `get_last_panel()` → YAML read → `_focused_panel` restored (safe: allowlist validation on both read and write)
**Pattern observed:** Read-modify-write YAML at `focus.py:289-296` and `focus.ts:59-76` — follows existing `set_panel_focus()` and `getConfigFocus()` patterns exactly
**Error handling:** Python returns `{success: True, last_panel: None}` on all error paths; TS returns `null`; TUI checks both keys before acting (`tui.py:71-72`)
**Low observations:** (1) `VALID_PANELS` has `tty` but `VALID_FOCUS_PANELS` doesn't — correct, tty is TUI-only. (2) `isValidFocusPanel()` exists but not reused — minor duplication.
**Tests:** 35/35 GREEN (20 Python + 15 TypeScript)
**Handoff:** To SM for finish-story

### Handoff History
| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| red (tea) | green (dev) | tests_fail | PASSED | 2026-02-14T06:10:48Z |
| green (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-14T08:37:22Z |
| review (reviewer) | finish (sm) | review_approved | PASSED | 2026-02-14T17:24:33Z |
