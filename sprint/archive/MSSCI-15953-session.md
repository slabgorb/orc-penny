# Story 103-22: TUI pane shows raw SGR mouse/focus escape sequences on startup

**Status:** in_progress
**Phase:** finish
**Workflow:** trivial
**Repos:** pennyfarthing
**Branch:** fix/103-22-tui-sgr-escape-sequences
**Jira:** MSSCI-15953
**Assigned:** keithavery
**Points:** 1

---
## SM Assessment

**Story:** 103-22 — TUI pane shows raw SGR mouse/focus escape sequences on startup
**Type:** Bug fix (1pt trivial)
**Workflow:** trivial → Dev implements directly

**Setup completed:**
- Branch `fix/103-22-tui-sgr-escape-sequences` created from `develop`
- Jira MSSCI-15953 claimed and moved to In Progress
- Epic context created: `sprint/context/context-epic-103.md`
- Story context created: `sprint/context/context-story-103-22.md`

**Routing:** Handoff to Korben Dallas (Dev) for implement phase. 1pt terminal polish bug — investigate SGR escape sequence leakage in the Textual TUI startup sequence.

---
## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/bikerack/tui.py` — Added `_flush_terminal_input()` to drain stale terminal responses after `detect_image_protocol()`, re-enabled mouse mode

**Root Cause:** `detect_image_protocol()` calls `textual_image.get_cell_size()` which sends `\x1b[16t` to query cell pixel size via cbreak mode. Late/timed-out responses leave residual bytes in stdin. When Textual enters application mode and enables SGR mouse/focus tracking, the stale input confuses the terminal state and enable sequences leak as raw text. `mouse=False` was a workaround that disabled mouse entirely.

**Fix:** `termios.tcflush(stdin, TCIFLUSH)` after protocol detection drains any pending bytes before Textual takes over. Mouse mode re-enabled (Textual default).

**Tests:** 48/49 passing (1 pre-existing async failure unrelated to changes)
**Branch:** fix/103-22-tui-sgr-escape-sequences (pushed)

**Handoff:** To Jean-Baptiste Emanuel Zorg for review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `detect_image_protocol()` → `get_cell_size()` → `\x1b[16t` query → timeout leaves stale bytes → `tcflush(TCIFLUSH)` drains → `app.run()` starts clean (safe — no user input in flow)
**Pattern observed:** Defensive terminal state cleanup before framework handoff at `tui.py:1269-1284`
**Error handling:** `isatty()` guard + `(termios.error, OSError)` catch at `tui.py:1280-1284` — covers non-TTY and permission failures
**Handoff:** To Ruby Rhod (SM) for finish-story

## Delivery Findings

- No upstream findings during implementation.

### Reviewer (code review)
- No upstream findings during code review.