# Story 103-16: BackgroundPanel (task status)

**Jira:** MSSCI-14971
**Epic:** 103 — BikeRack TUI — Terminal-Native Dashboard
**Points:** 1
**Priority:** P1
**Workflow:** tdd
**Phase:** finish
**Branch:** feature/103-16-background-panel-task-status
**Repos:** orchestrator, pennyfarthing

---

## Context

BackgroundPanel is a BikeRack TUI panel that displays the status of background tasks running in Pennyfarthing's task system. It subscribes to the `/ws/background-tasks` WebSocket channel and renders a list of background tasks with their status indicators (running, completed, failed).

**FR17 (from TUI-PRD):** Developer can view background task statuses

This panel is part of the MVP panel roster and follows the standard BikeRack panel pattern: subscribe to a WebSocket channel, parse JSON payload, render Rich output via Textual widget.

## WebSocket Channel

- **Channel:** `background-tasks`
- **Path:** `/ws/background-tasks`
- **Message Format:** `{type:'init'|'update', tasks:[{taskId,description,subagentType,startedAt,isBackground,completedAt?,success?,result?,error?}]}`

## Technical Approach

Based on the base_panel.py pattern and diffs_panel.py reference:

1. **Create BackgroundPanel class** — extends BasePanel
2. **Set channel attribute** — `channel = "background-tasks"`
3. **Implement render_panel()** — returns Rich renderable (likely Table or Tree)
4. **Task data model:**
   - `taskId` (string) — unique identifier
   - `description` (string) — human-readable task description
   - `subagentType` (string) — agent type (e.g., "dev", "reviewer", "testing-runner")
   - `startedAt` (timestamp) — when task started
   - `isBackground` (boolean) — whether it's a background task
   - `completedAt?` (timestamp, optional) — when task completed
   - `success?` (boolean, optional) — whether task succeeded
   - `result?` (string, optional) — task result/output
   - `error?` (string, optional) — error message if failed

5. **Status rendering:**
   - Running tasks: show spinner icon + description + elapsed time
   - Completed (success) tasks: show checkmark + description + completion time
   - Failed tasks: show error icon + description + error message
   - Empty state: "No background tasks" message

6. **Icon:**
   - Use `PANEL_ICONS["background"][0]` (spinner icon `\uf110`)
   - Panel name: "Background" (displayed in header)

7. **Error handling:**
   - Handle missing `tasks` field gracefully
   - Handle malformed task objects (missing fields)
   - Render "No background tasks" for empty array
   - Gracefully handle None payload (inherited from BasePanel)

## Acceptance Criteria

- [ ] AC1: BackgroundPanel class extends BasePanel
- [ ] AC2: Subscribes to `background-tasks` WebSocket channel
- [ ] AC3: Renders background task list with task names and descriptions
- [ ] AC4: Shows status indicators (running/completed/failed) with appropriate styling and icons
- [ ] AC5: Handles empty state (no background tasks) with appropriate message
- [ ] AC6: Handles malformed/missing data gracefully (missing fields, empty arrays, None payload)
- [ ] AC7: All tests pass, lint clean
- [ ] AC8: Real-time updates when new background tasks arrive or status changes via WebSocket

## Key Files

**New files to create:**
- `pennyfarthing/pennyfarthing_scripts/bikerack/background_panel.py` (implementation)
- `pennyfarthing/tests/python/test_bikerack_background_panel.py` (tests)

**Reference files:**
- `pennyfarthing/pennyfarthing_scripts/bikerack/base_panel.py` — base class pattern, PANEL_ICONS registry, channel subscription, message handling
- `pennyfarthing/pennyfarthing_scripts/bikerack/diffs_panel.py` — example of render_panel implementation with Rich renderables (Table/Tree/Text/Group patterns)
- `pennyfarthing/tests/python/test_bikerack_diffs_panel.py` — test structure and patterns (fixture data, test organization, mocking strategy)

## Design Notes

- BackgroundPanel should render tasks in a table format (like SprintPanel) rather than a tree, since all tasks are at the same hierarchy level
- Status column could use emoji or Nerd Font icons (✓ for completed, ✗ for failed, ⟳ for running)
- Consider showing elapsed time for running tasks (current_time - startedAt)
- For completed tasks, show completion time or duration
- Fit table to terminal width; consider wrapping description if too long

---

## SM Assessment

**Story:** 103-16 — BackgroundPanel (task status)
**Points:** 1 | **Workflow:** tdd | **Priority:** P1

**Setup complete.** Session created with:
- FR17 specs from TUI PRD — WebSocket channel `/ws/background-tasks`
- Data model: taskId, description, subagentType, startedAt, isBackground, completedAt?, success?, result?, error?
- 8 acceptance criteria covering core rendering, status indicators, empty state, error handling, real-time updates
- Reference pattern: DiffsPanel (103-18) — recently completed, proven pattern

**Handoff:** → TEA (red phase) for test design

**Key context for TEA:**
- Channel: `background-tasks` (not `background`)
- Message format: `{type:'init'|'update', tasks:[...]}`
- Follow test_bikerack_diffs_panel.py pattern for test structure
- Status indicators: running (spinner), completed (checkmark), failed (error icon)

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing/tests/python/test_bikerack_background_panel.py` — 38 tests across 7 classes
- `pennyfarthing/pennyfarthing_scripts/bikerack/background_panel.py` — stub (NotImplementedError)

**Tests Written:** 38 tests covering 7 ACs (AC1-AC6, AC8)

| Class | AC | Tests | Focus |
|-------|-----|-------|-------|
| TestBackgroundPanelExists | AC1 | 6 | Imports, inheritance, channel, panel_name, icon |
| TestBackgroundPanelSubscription | AC2 | 5 | WebSocket subscribe, client, payload storage |
| TestBackgroundPanelRendering | AC3 | 4 | Task descriptions, subagent type visible |
| TestBackgroundPanelStatusIndicators | AC4 | 6 | Running/completed/failed indicators, error msg, ANSI styling |
| TestBackgroundPanelEmptyState | AC5 | 3 | Placeholder message, no task content |
| TestBackgroundPanelErrorHandling | AC6 | 9 | Missing fields, empty task, non-list tasks, None payload |
| TestBackgroundPanelRealTimeUpdates | AC8 | 5 | Render triggers, consecutive messages, unmount stops |

**Status:** RED (30 failing, 8 passing — all failures from NotImplementedError/assertion, not imports)

**Key design decisions:**
- Flexible status indicator assertions (accept emoji, text, or icon variants)
- Error handling tests cover every optional field individually
- Wire format fixtures match PRD spec exactly

**Handoff:** → Korben Dallas (Dev) for GREEN implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/background_panel.py` — 82 lines, full implementation

**Approach:** Rich Text objects with Group. Status via completedAt/success fields:
- Running (no completedAt): ⟳ yellow
- Done (completedAt + success): ✓ green, shows result
- Failed (completedAt + !success): ✗ red, shows error message
- All fields accessed via .get() with defaults for graceful degradation

**Tests:** 38/38 passing (GREEN), lint clean
**PR:** #880 — feat(103-16): BackgroundPanel task status display
**Branch:** feature/103-16-background-panel-task-status (pushed)

**Handoff:** → Zorg (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED

| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | [VERIFIED] | Pattern match — follows DiffsPanel convention (class attrs, render_panel, Group/Text) | background_panel.py:17-43 |
| 2 | [VERIFIED] | Data flow traced: WS → handle_message → render_panel → _render_task → Group → update | base_panel.py:79-92 → background_panel.py:28-43 |
| 3 | [VERIFIED] | Graceful degradation — all .get() with defaults, isinstance guards on tasks/items | background_panel.py:30-36, 48-53 |
| 4 | [VERIFIED] | Error handling — BasePanel short-circuits None/unmounted, try/except on update | base_panel.py:85-92 |
| 5 | [LOW] | Non-string task fields would raise TypeError — wire format contract violation, not realistic | background_panel.py:48, 60 |
| 6 | [VERIFIED] | Status branching logic correct — completedAt discriminator, safe-default to failed | background_panel.py:57-79 |
| 7 | [VERIFIED] | Test coverage — 38/38 pass, 7 classes, AC1-AC6+AC8, flexible assertions | test_bikerack_background_panel.py |
| 8 | [VERIFIED] | Security — read-only display, no injection surface, internal WebSocket data only | N/A |

**Tests:** 38/38 PASSED, lint clean, PR MERGEABLE
**Handoff:** → SM for finish-story
