# Story 103-14: ChangedPanel (file list with status)

**Jira:** PROJ-14969
**Epic:** 103 — BikeRack TUI — Terminal-Native Dashboard
**Points:** 1
**Workflow:** tdd
**Phase:** red
**Repos:** pennyfarthing
**Branch:** feature/103-14-changedpanel-file-list
**Assigned:** slabgorb@gmail.com

---

## Description

Subscribes to /ws/changed channel. Renders changed files as Rich table with file path, change type icon, and status.

## Functional Requirements

- FR15: Changed file list with status icons

## Technical Context

### Epic Context
- BikeRack TUI is a Python terminal-native dashboard using Rich/Textual
- Connects to WheelHub server over WebSocket on port 2898
- Consumes existing WebSocket channels — zero server-side modifications

### Key References
- Epic context: `sprint/context/context-epic-103.md`
- WebSocket channel: `/ws/git` provides `repos[].dirtyFiles[{status, path}]`
- Existing React hook reference: `packages/cyclist/src/public/hooks/useGitStatus.ts`
- WheelHub WebSocket: `packages/cyclist/src/websocket.ts`

### Note on Channel
The story says "/ws/changed" but the epic context shows changed files come from the `/ws/git` channel's `dirtyFiles` array. TEA should verify which channel to use.

## Acceptance Criteria

- [ ] Panel subscribes to correct WebSocket channel for changed file data
- [ ] Renders Rich table with columns: file path, change type icon, status
- [ ] Updates in real-time when file changes are detected
- [ ] Tests written following TDD (red-green-refactor)

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** New panel implementation with rendering, subscription, and real-time update behavior

**Test Files:**
- `tests/python/test_bikerack_changed_panel.py` — 44 tests covering all 4 ACs

**Tests Written:** 44 tests covering 4 ACs
- AC1 (subscription): 11 tests — exists, inherits BasePanel, channel=git, subscribes on mount
- AC2 (rendering): 21 tests — Rich table output, file paths, status icons per git status code (M/A/D/?/R), multi-repo aggregation, empty state
- AC3 (real-time): 5 tests — message triggers render, consecutive updates, payload tracking, unmount stops
- AC4 (edge cases): 7 tests — missing fields, malformed data, non-list types

**Status:** RED (36 failing, 8 passing — all failures from stub `NotImplementedError` or unset class attrs)

**Stub:** `pennyfarthing_scripts/bikerack/changed_panel.py` — minimal `BasePanel` subclass with `raise NotImplementedError`

**Key Design Notes for Dev:**
- Channel is `git` (same as GitPanel) — extract `dirtyFiles` from `repos[]`
- 2-char status codes: index + working tree (M=modified, A=added, D=deleted, ?=untracked, R=renamed)
- Multi-repo: flatten files from all repos, show repo context
- Return `Rich.Table` with columns, use ANSI styling for status icons
- Follow `BackgroundPanel`/`GitPanel` patterns

**Handoff:** To Dev for implementation

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/changed_panel.py` — ChangedPanel implementation (channel=git, Rich Table rendering, status icons, multi-repo support)

**Tests:** 44/44 passing (GREEN)
**PR:** #898 — feat(103-14): ChangedPanel file list with status
**Branch:** feature/103-14-changedpanel-file-list (pushed)

**Handoff:** To Reviewer for code review

---

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `/ws/git` → `BasePanel.handle_message()` → `render_panel()` → flattens `repos[].dirtyFiles[]` → `Table` rows (safe — pure rendering of trusted WheelHub data)
**Pattern observed:** Follows BasePanel convention exactly at `changed_panel.py:54-64` — matches GitPanel, BackgroundPanel
**Error handling:** Defensive `isinstance` checks at every nesting level at `changed_panel.py:68-86`, `.get()` with defaults
**Status parsing:** Correct 2-char git status priority at `changed_panel.py:28-51` (untracked → index → working tree → default)
**Low:** Missing "C"/"!" status codes at `changed_panel.py:17-23` — falls to default, acceptable
**Tests:** 44/44 passing, no forbidden patterns
**Handoff:** To SM for finish-story

---

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-14 19:10:00

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-14 18:42 | 2026-02-14 18:47:06 | 5m |
| red | 2026-02-14 18:47:06 | 2026-02-14 19:00:00 | 12m 54s |
| green | 2026-02-14 19:00:00 | 2026-02-14 19:05:00 | 5m |
| review | 2026-02-14 19:05:00 | 2026-02-14 19:10:00 | 5m |
| finish | 2026-02-14 19:10:00 | - | - |
