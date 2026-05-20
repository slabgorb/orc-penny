# Story 110-2: Story drill-through with dossier detail screen

**Jira:** PROJ-15186
**Points:** 5
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/110-2-story-drill-through-dossier
**Epic:** 110 — BikeRack TUI — Interactive Command Center

## Description

Add Enter-to-drill-through on sprint stories. Pushes a StoryDetailScreen
showing a mission-dossier layout with AC checklist, workflow phase dots,
git branch, PR link, and session notes.

## Acceptance Criteria

1. Add per-story cursor to SprintPanel (arrow keys within expanded epic)
2. Create StoryDetailScreen extending Textual Screen with push/pop
3. Fetch story detail data (AC, session, workflow) via file read or API
4. Render dossier layout: header, AC progress, workflow phase, git info
5. Escape pops back to sprint overview
6. Enter on PR link opens browser via webbrowser.open()

## Technical Context

### Architecture
- **Framework:** Python Textual 1.0+ with Rich rendering
- **Location:** `pennyfarthing_scripts/bikerack/`
- **Base class:** `BasePanel(Static)` — panels render Rich text, subscribe to WebSocket channels
- **Current SprintPanel:** Renders Group+Text lines (not Table), epic-level j/k/e nav only, no story cursor

### Files to Modify
- `sprint_panel.py` — Add per-story cursor (up/down/enter), `get_selected_story()`, `drill_into_story()`, render cursor indicator
- `tui.py` — May need app-level bindings for story nav delegation (like existing j/k/e pattern)

### Files Created (Stubs)
- `story_detail_screen.py` — StoryDetailScreen(Screen) with escape/enter bindings, compose stub
- `story_detail_data.py` — `fetch_story_detail()` stub returning empty dict

### Key Patterns
- `_selected_story: int` (-1 = no selection, 0+ = index into expanded epic's stories)
- `next_story()`/`prev_story()` wrap within story list; no-op when epic collapsed or no payload
- `next_epic()` must reset `_selected_story` to -1
- `drill_into_story()` pushes `StoryDetailScreen` via `self.app.push_screen()`
- `fetch_story_detail()` reads session file, sprint YAML, git info — returns dict with: id, title, points, status, jiraKey, acceptance_criteria, workflow, workflow_phase, git_branch, pr_url, session_notes
- StoryDetailScreen `compose()` yields widgets for dossier layout
- `get_pr_url()` extracts from `_story_data["pr_url"]`
- `action_open_pr_link()` calls `webbrowser.open()`, returns True/False

### Data Contract
```python
fetch_story_detail() → {
    "id": str,
    "title": str,
    "points": int,
    "status": str,
    "jiraKey": str,
    "acceptance_criteria": [{"text": str, "done": bool}, ...],
    "workflow": str,
    "workflow_phase": str,
    "git_branch": str,
    "pr_url": str | None,
    "session_notes": str,
}
```

## TEA Assessment

**Tests Required:** Yes
**Test File:** `tests/python/test_bikerack_story_detail.py`

**Tests Written:** 59 tests covering 6 ACs
**Status:** RED — 30 failing (assertion failures), 29 passing (structural scaffolding)

| AC | Tests | Failing | Passing |
|----|-------|---------|---------|
| AC1: Per-story cursor | 16 | 8 | 8 |
| AC2: StoryDetailScreen | 7 | 0 | 7 |
| AC3: Fetch story data | 11 | 8 | 3 |
| AC4: Dossier layout | 7 | 6 | 1 |
| AC5: Escape pops back | 2 | 1 | 1 |
| AC6: PR link browser | 4 | 2 | 2 |
| Integration + Edge | 12 | 5 | 7 |

**Handoff Notes for Dev:**
- SprintPanel stub methods (`next_story`, `prev_story`, `get_selected_story`, `drill_into_story`) need full implementation
- `story_detail_data.py` `fetch_story_detail()` needs to read from session file + sprint YAML
- `story_detail_screen.py` `compose()` needs full Textual widget layout
- `get_pr_url()` and `action_open_pr_link()` need `webbrowser` integration
- Integration tests expect `app.push_screen()` after Enter on selected story

**Handoff:** To Dev (Sergeant Carter) for GREEN implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/sprint_panel.py` — Per-story cursor nav (up/down/enter), get_selected_story(), drill_into_story(), epic switch resets cursor, render ▸ marker
- `pennyfarthing_scripts/bikerack/story_detail_screen.py` — StoryDetailScreen with dossier compose (header, ACs, workflow, git, notes), action_pop_screen(), action_open_pr_link()
- `pennyfarthing_scripts/bikerack/story_detail_data.py` — fetch_story_detail() with session file parsing, CWD walk-up detection, subprocess fallbacks for status/PR
- `pennyfarthing_scripts/bikerack/tui.py` — _get_dom_base() override so app.query() finds pushed screen widgets

**Tests:** 59/59 passing (GREEN)
**PR:** #944 — feat(110-2): story drill-through with dossier detail screen
**Branch:** feature/110-2-story-drill-through-dossier (pushed)

**Handoff:** To Reviewer (General Burkhalter) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Enter key → drill_into_story() → get_selected_story() → push_screen(StoryDetailScreen) → compose() renders dossier → Escape → dismiss() (safe, linear, no external calls during screen push)
**Pattern observed:** Proper bounds checking in get_selected_story() at sprint_panel.py:128-138 — guards all edge cases
**Error handling:** fetch_story_detail returns {} on missing session; subprocess calls have try/except with 10s timeouts; compose() uses .get() defaults throughout
**Security:** No injection risk — subprocess uses list args, webbrowser.open gated behind explicit keypress
**Low findings:** Dead code `_find_project_root()` at story_detail_data.py:15; silent except in drill_into_story() at sprint_panel.py:106

**Handoff:** To SM (Colonel Hogan) for finish-story

## Session Log

- [setup] Story initialized by SM
- [red] TEA wrote 59 failing tests for 6 ACs, committed to feature branch
- [green] Dev implemented all 4 files, 59/59 tests GREEN, PR #944 created
- [review] Reviewer approved — no blocking issues, clean data flow, merging PR #944