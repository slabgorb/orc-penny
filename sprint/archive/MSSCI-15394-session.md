# Story 121-3 Session

**Story ID:** 121-3
**Jira Key:** MSSCI-15394
**Title:** Fix footer keybinding labels — bracket display is inaccurate
**Type:** bug
**Points:** 1
**Priority:** p1
**Status:** backlog
**Workflow:** trivial
**Assignee:** keith.avery@1898andco.io
**Repos:** pennyfarthing

## Description

The footer bar in BikeRack TUI shows keybinding hints with incorrect bracket formatting. The bracket characters around key names are wrong or inconsistent, making the menu hard to read. Fix the keybinding label rendering in the footer widget to display accurate bracket notation matching the actual key shortcuts.

## Acceptance Criteria

- Footer bar bracket formatting is accurate and consistent
- Keybinding labels display correct bracket notation around key names
- Footer widget renders readable and properly formatted menu hints
- BikeRack TUI footer keybindings are visually clear and match intended shortcuts

## Technical Approach

This is a UI rendering fix in the BikeRack TUI footer widget. The issue involves:
1. Locating the footer keybinding label rendering code
2. Identifying the incorrect bracket character or formatting logic
3. Fixing the bracket notation to match actual key shortcuts
4. Ensuring consistent formatting across all keybinding labels
5. Testing the footer display in BikeRack TUI

## Branch

Created: `fix/121-3-fix-footer-keybinding-labels`

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/pf/bikerack/context_meter_footer.py` — Rewrote as StatusFooter: unified status bar with project name, model indicator, right-aligned context progress bar. Subscribes to both /ws/context and /ws/stats. Backward compat alias preserved.
- `pennyfarthing-dist/pf/bikerack/tui.py` — Removed BindingFooter class, removed #project-dir Static from header area, replaced ContextMeterFooter + BindingFooter with single StatusFooter. Fixed bracket descriptions in BINDINGS. Updated CSS.
- `pennyfarthing-dist/pf/bikerack/portrait_resolver.py` — Added `_is_lfs_pointer()` to detect git-lfs pointer files and skip them, preventing broken portrait rendering.
- `tests/python/test_bikerack_context_meter.py` — Updated layout tests for StatusFooter, replaced BindingFooter coexistence tests with StatusFooter-only tests.
- `tests/python/test_bikerack_context_meter_redraws.py` — Updated DOM queries from ContextMeterFooter to StatusFooter.

**Tests:** 50/50 passing (GREEN)
**Branch:** fix/121-3-fix-footer-keybinding-labels (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Tests:** 50/50 passing, lint clean, no code smells
**Data flow traced:** `/ws/context` and `/ws/stats` → WheelHubClient → StatusFooter WS handlers → `_throttled_redraw` → `_render_status` → `post_message(MeterUpdate)` → Textual repaint (safe, thread-safe)
**Pattern observed:** Clean widget consolidation — three widgets merged into one StatusFooter with backward compat aliases at `context_meter_footer.py:118-131,217-218`
**Error handling:** All exception paths prevent widget crash. LFS detection fails safe via `OSError` catch at `portrait_resolver.py:50`.
**Security:** No secrets, no user input flows, no injection surfaces.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [LOW] | Model name regex strips minor version (`opus-4-6` → `opus-4`) | `context_meter_footer.py:28-29` | Non-blocking cosmetic |

**Handoff:** To SM for finish-story