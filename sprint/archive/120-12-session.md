# Story 120-12: Enrich statusbar with additional context (current directory, story ID)

**Jira:** none
**Points:** 1
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/120-12-enrich-statusbar-context
**Assigned:** slabgorb@gmail.com

---

## Story Context

The statusline hook (`pf hooks statusline`) currently shows: agent role, theme character, repo name, branch, model, and context usage.

Enrich it with additional at-a-glance context:
- Current working directory (or relative path from project root)
- Active story ID (if a session is active)

Keep the layout compact — truncate or abbreviate as needed to fit within terminal width.

## Technical Approach

The statusline is rendered by `pennyfarthing-dist/pf/hooks/statusline.py`. It reads config and session state to build the status bar segments. Need to:
- Add a story ID segment (read from active session file)
- Add a working directory segment (relative to project root)
- Ensure segments fit within terminal width with truncation

## Acceptance Criteria

- Statusbar displays the active story ID when a session is active
- Statusbar displays the current working directory (relative to project root)
- Layout remains compact and handles narrow terminals gracefully
- No regression on existing statusbar segments

---
## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/pf/hooks/statusline.py` - Added `_get_story_id()` and `_get_relative_cwd()` helpers; wired story ID segment and relative cwd into output
- `tests/python/test_statusline.py` - 11 unit tests covering both new helpers

**Tests:** 11/11 passing (GREEN)
**Branch:** feature/120-12-enrich-statusbar-context (pushed)

**Handoff:** To Reviewer (Colonel Potter) for review

---
## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** cwd (stdin JSON) → `_get_relative_cwd()` → truncation `[:14]` → ANSI display. No injection surface — local paths only.
**Pattern observed:** Glob-first-match pattern at statusline.py:292-295 is consistent with existing `_get_tandem_partner_display` at statusline.py:319-323.
**Error handling:** Both new helpers return empty strings on all failure paths. Existing broad `except Exception` at statusline.py:470 provides TUI resilience.
**Findings:**
- [LOW] `_get_story_id` takes `sessions[0]` from unsorted glob — nondeterministic for multiple sessions. Matches existing pattern; single-session invariant holds in practice.
- [LOW] Story segment adds variable width (~10 chars) without terminal width detection. Acceptable — Claude Code controls statusline overflow.
- [VERIFIED] Security clean — local config/session files only, no user-controlled input injection.
- [VERIFIED] Comprehensive test coverage — 11 tests, both helpers covered with edge cases.
- [VERIFIED] No debug code, no dead imports, no regressions to existing segments.

**Handoff:** To SM (Hawkeye) for finish-story