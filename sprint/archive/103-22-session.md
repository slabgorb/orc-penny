# Story 103-22: TUI pane shows raw SGR mouse/focus escape sequences on startup

## Story Details
- **ID:** 103-22
- **Workflow:** trivial

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-02T11:22:37Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-02T11:12:09Z | 2026-03-02T11:13:09Z | 1m |
| implement | 2026-03-02T11:13:09Z | 2026-03-02T11:20:10Z | 7m 1s |
| review | 2026-03-02T11:20:10Z | 2026-03-02T11:22:37Z | 2m 27s |
| finish | 2026-03-02T11:22:37Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- No upstream findings during code review.

## SM Assessment

**Story:** 103-22 — TUI pane shows raw SGR mouse/focus escape sequences on startup
**Routing:** trivial → Dev (Toby Ziegler)
**Repos:** pennyfarthing
**Branch:** feat/103-22-tui-raw-sgr-escape-filtering

1-point fix. TUI pane is displaying raw SGR escape sequences (mouse enable/disable, focus tracking) instead of filtering them. Straight to Dev for implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/bikerack/tui.py` — pass `mouse=False` to `app.run()` to disable SGR mouse tracking sequences

**Root Cause:** Textual enables SGR mouse mode (`\x1b[?1000h`, `\x1b[?1003h`, `\x1b[?1006h`) by default in `LinuxDriver.start_application_mode()`. These sequences leak as visible text in tmux panes. BikeRack is keyboard-navigated — mouse support is unnecessary.

**Tests:** 82/103 passing (21 pre-existing failures from other stories — focus system, panel persistence, launcher defaults). No regressions from this change.
**Branch:** feat/103-22-tui-raw-sgr-escape-filtering (pushed)

**Handoff:** To Reviewer for code review.

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `main()` → `App.run(mouse=False)` → `LinuxDriver.__init__(mouse=False)` → `_enable_mouse_support()` early-returns on `not self._mouse`. SGR sequences never written.
**Pattern observed:** Correct use of Textual's `mouse` kwarg to disable terminal escape sequences at tui.py:1304.
**Error handling:** N/A — single config parameter, no error paths introduced.
**Observations:**
1. [VERIFIED] `mouse=False` is valid Textual API (keyword-only, defaults True)
2. [VERIFIED] `_enable_mouse_support()` guards on `self._mouse` — all 4 SGR sequences suppressed
3. [VERIFIED] `dev_main` path covered — subprocess re-enters `main()`
4. [VERIFIED] No mouse event handlers in bikerack panels — keyboard-only
5. [LOW] Mouse wheel scroll disabled for VerticalScroll containers; keyboard scroll bindings at tui.py:783,801 provide alternative

**Handoff:** To SM (Leo McGarry) for finish-story.