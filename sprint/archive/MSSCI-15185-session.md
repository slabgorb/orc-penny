# Story 110-1: Cross-panel event bus with Changed-to-Diffs navigation

**Status:** in_progress
**Workflow:** tdd
**Phase:** finish
**Jira:** MSSCI-15185
**Repos:** pennyfarthing
**Assigned:** keith.avery@1898andco.io
**Branch:** feat/110-1-cross-panel-event-bus
**Started:** 2026-02-16
**Epic:** 110 — BikeRack TUI — Interactive Command Center
**Context:** sprint/context/context-epic-110.md

## SM Assessment

Story setup complete. Epic 110 synced to Jira (MSSCI-15184), story claimed as MSSCI-15185.
Branch `feat/110-1-cross-panel-event-bus` created off `develop` in pennyfarthing repo.
Epic context file documents architecture — Textual Message-based event bus pattern.
5 ACs defined, all testable. TDD workflow: routing to TEA for red phase (test design).

## Acceptance Criteria

- [ ] PanelEvent base message class and NavigateToFile event defined in events.py
- [ ] ChangedPanel renders selectable file list with arrow key navigation
- [ ] Enter on a changed file switches to DiffsPanel showing that file's diff
- [ ] Footer shows context-sensitive bindings per active panel
- [ ] Existing j/k/e/n/p bindings continue to work unchanged

## Story Context

Cross-panel event bus using Textual's Message system. First use case: Enter on a file in ChangedPanel posts NavigateToFile, DiffsPanel handles it by filtering to that file, App routes the event and switches active panel.

Key files:
- `pennyfarthing_scripts/bikerack/tui.py` — Main app, layout, keybindings
- `pennyfarthing_scripts/bikerack/base_panel.py` — Abstract base panel
- `pennyfarthing_scripts/bikerack/changed_panel.py` — Changed files panel (sender)
- `pennyfarthing_scripts/bikerack/diffs_panel.py` — Diff viewer panel (receiver)
- `pennyfarthing_scripts/bikerack/sprint_panel.py` — Sprint panel (future receiver)

## Technical Approach

1. Create `events.py` with PanelEvent base Message and NavigateToFile subclass
2. Migrate ChangedPanel from Static rendering to OptionList/ListView with selectable entries
3. Add Enter key handler to ChangedPanel that posts NavigateToFile
4. DiffsPanel handles NavigateToFile by matching file and re-rendering
5. App-level handler switches active panel on navigation events
6. Context-sensitive footer bindings per active panel

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing_scripts/bikerack/events.py` — PanelEvent + NavigateToFile stubs (AC1)
- `tests/python/test_bikerack_event_bus.py` — 44 tests across all 5 ACs

**Tests Written:** 44 tests covering 5 ACs
**Status:** RED (26 failing, 18 passing, 0 errors)

**Passing (18):** AC1 event definitions (9), AC5 regression j/k/e/n/p (8), 1 AC4 sprint binding
**Failing (26):** AC2 selectable list (14), AC3 navigate action (8), AC4 context bindings (3), AC5 edge (1)

**Implementation notes for Dev:**
- `events.py` is complete — just Message subclasses, no behavior changes needed
- `ChangedPanel` needs: `_selected_index`, `select_next()`, `select_prev()`, `get_selected_path()`, `action_select_file()`, BINDINGS with Enter, visual highlight in `render_panel()`
- `DiffsPanel` needs: `navigate_to_file(path)` method that sets `_current_file_index`
- `BikeRackApp` needs: handler for `NavigateToFile` → switch to diffs + call `navigate_to_file()`
- Footer: Make n/p/j/k/e bindings `show=True` conditionally based on active panel

**Handoff:** To Dev for implementation (GREEN phase)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/changed_panel.py` — Selectable file list with `_selected_index`, arrow navigation (`select_next`/`select_prev`), `get_selected_path()`, `action_select_file()` posting NavigateToFile, reverse-video highlight in render, BINDINGS with Enter
- `pennyfarthing_scripts/bikerack/diffs_panel.py` — `navigate_to_file(path)` method, BINDINGS with n/p, `can_focus=True`
- `pennyfarthing_scripts/bikerack/sprint_panel.py` — BINDINGS with j/k/e, `can_focus=True`, action wrapper methods
- `pennyfarthing_scripts/bikerack/tui.py` — `on_navigate_to_file` handler (switch to diffs + navigate), `BindingFooter` subclass for testable binding text, panel focus on switch

**Tests:** 44/44 passing (GREEN) — 381/381 full suite, zero regressions
**PR:** #943 — feat(110-1): cross-panel event bus with Changed-to-Diffs navigation
**Branch:** feat/110-1-cross-panel-event-bus (pushed)

**Handoff:** To General Burkhalter for code review

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | `navigate_to_file()` sets index but doesn't re-render — user sees stale file until next WS message. Breaks AC3 "showing that file's diff" | `diffs_panel.py:97-105` | Add `self.update(self.render_panel(self._last_payload))` after setting index, matching `next_file()`/`prev_file()` pattern |
| [LOW] | `# noqa: F401` on NavigateToFile import is wrong — import IS used in handler signature | `tui.py:26` | Remove noqa |

**Data flow traced:** Enter → action_select_file → NavigateToFile → on_navigate_to_file → switch + navigate. Wiring correct but terminal render missing.
**Verified:** Index clamping, boundary handling, multi-repo consistency, no forbidden patterns, no security concerns.

**Handoff:** Back to Dev for navigate_to_file re-render fix

## Dev Assessment (Review Fix Round 2)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/diffs_panel.py` — Added re-render in `navigate_to_file()` matching `next_file()`/`prev_file()` pattern
- `pennyfarthing_scripts/bikerack/tui.py` — Removed incorrect `# noqa: F401`; AgentHeader now shows random catchphrase instead of role description
- `pennyfarthing_scripts/bikerack/changed_panel.py` — Added up/down arrow key bindings with action wrappers, re-render on selection change

**Tests:** 381/381 passing (GREEN) — zero regressions
**Branch:** feat/110-1-cross-panel-event-bus (pushed, commit `3251415a9`)

**Handoff:** To General Burkhalter for re-review

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED

| # | Type | Observation | Location |
|---|------|-------------|----------|
| 1 | [VERIFIED] | `navigate_to_file()` re-render fix — now matches `next_file()`/`prev_file()` pattern exactly. Previous HIGH resolved. | `diffs_panel.py:97-110` |
| 2 | [VERIFIED] | Data flow end-to-end: Enter → `action_select_file` → `NavigateToFile` → `on_navigate_to_file` → `action_switch_panel("diffs")` → `navigate_to_file(path)` → re-render. Complete wiring confirmed. | `changed_panel.py:143` → `tui.py:345` → `diffs_panel.py:97` |
| 3 | [VERIFIED] | Arrow key bindings: up/down → `action_select_prev_key`/`action_select_next_key` → `select_prev()`/`select_next()` → `_rerender()`. Selection highlight via `flat_idx == self._selected_index` in render. | `changed_panel.py:70-133` |
| 4 | [LOW] | Ruff lint: unsorted imports (`events` before `base_panel`), unused `style` var (leftover from catchphrase refactor), unused loop vars `enabled`/`tooltip` in `BindingFooter` | `tui.py:26,117,178` |
| 5 | [VERIFIED] | AgentHeader catchphrase: `quote` (random from `selectCatchphrase()`) shown as subtitle, `roleDescription` as fallback. Matches user request. | `tui.py:207-211` |
| 6 | [VERIFIED] | Index clamping: `_build_file_paths` clamps on message update, `get_selected_path` bounds-checks, `render_panel` clamps `_current_file_index`. No out-of-bounds possible. | `changed_panel.py:104`, `diffs_panel.py:139` |
| 7 | [VERIFIED] | No forbidden patterns: no console.log, no hardcoded secrets, no `t.Skip()`, no `dangerouslySetInnerHTML`. All localhost WebSocket data. | All files |

**Data flow traced:** User Enter on ChangedPanel → `post_message(NavigateToFile)` → bubbles to App → `on_navigate_to_file` switches panel + calls `navigate_to_file(path)` → re-renders with target file. Safe — all data from localhost WheelHub.

**Error handling:** All re-renders wrapped in try/except (pre-existing pattern). `navigate_to_file` no-ops on unknown path. `get_selected_path` returns None for empty list.

**Lint note:** 4 LOW ruff findings in tui.py — import order, unused vars. Cosmetic, not blocking.

**Handoff:** To Colonel Hogan for finish-story

## Phase Log

| Phase | Agent | Status | Notes |
|-------|-------|--------|-------|
| setup | sm | done | Session created |
| red | tea | done | 44 tests, RED confirmed |
| green | dev | pending | |
| review | reviewer | pending | |
| finish | sm | pending | |