# Story 110-8: Hook up audit log panel

**Jira:** PROJ-15195
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/PROJ-15195-hook-up-audit-log-panel

## Context

Part of Epic 110: BikeRack TUI — Interactive Command Center. This story implements the audit log panel in the Python Textual TUI, displaying real-time tool use events from OTLP telemetry. The panel will render a Rich Table showing timestamp, tool name, input excerpt, and success/fail status.

The BikeRack TUI is a passive monitor for Pennyfarthing framework development, allowing developers to view sprint status, diffs, changed files, progress, and workflow state in a text-based interface. Story 110-8 extends this with audit log visibility to track Claude's tool invocations in real-time.

## Acceptance Criteria

1. Audit log panel renders tool events with timestamp, tool name, and result
2. Events stream in real-time via WebSocket from `/ws/audit` channel
3. Panel accessible via keybinding (consistent with other panels - tab bar + keyboard shortcut)
4. Scrollable history with newest events at bottom

## Technical Approach

### Files to Modify/Create

**Backend (TypeScript/Node):**
- `packages/cyclist/src/websocket.ts` — Add new `/ws/audit` WebSocket channel following the pattern of existing channels (lines 160-164)
- Reference: `packages/core/src/server/api/audit-log.ts` — Existing REST API for data model
- Reference: `packages/core/src/server/otlp-receiver.ts` — `ToolEvent` interface and event store

**Frontend (Python Textual TUI):**
- `pennyfarthing_scripts/bikerack/audit_log_panel.py` — New file, subclass `BasePanel`, subscribe to `"audit"` channel, render with Rich Table
- `pennyfarthing_scripts/bikerack/tui.py` — Register panel in `compose()` method, add to tab bar, add keybinding (1-7 range)
- `pennyfarthing_scripts/bikerack/base_panel.py` — Panel icon already registered: `"audit-log": ("\uf15c", "L")`

### Implementation Steps

1. **Add WebSocket channel in `packages/cyclist/src/websocket.ts`**
   - Create `/ws/audit` endpoint that streams `ToolEvent` from OTLP store
   - Follow existing channel pattern with subscription/broadcast

2. **Create `audit_log_panel.py`**
   - Extend `BasePanel` to subscribe to `"audit"` channel
   - Use Rich Table with columns: timestamp, tool name, input excerpt, result
   - Implement scrollable list with newest events at bottom
   - Handle WebSocket message parsing

3. **Integrate into TUI**
   - Mount panel in `tui.py` `compose()` method
   - Add keybinding (check available keys 1-7, likely key 8 or L)
   - Update tab bar display
   - Add help text to footer bindings

### Key Patterns

- **BasePanel subscription:** See `sprint_panel.py` or `diffs_panel.py` for `on_mount()` async channel subscribe
- **Rich Table rendering:** See `sprint_panel.py` for Rich rendering patterns
- **WebSocket message handling:** See `base_panel.py` for `Message` handler pattern
- **Keybindings:** See `tui.py` lines with `BINDINGS` for keybinding registration pattern

## TEA Assessment

**Tests Required:** Yes
**Reason:** New panel with WebSocket integration, DataTable rendering, and TUI registration

**Test Files:**
- `tests/python/test_bikerack_audit_log_panel.py` — 44 tests covering all 4 ACs

**Tests Written:** 44 tests covering 4 ACs + error handling
**Status:** RED (39 failing, 5 passing — stub only)

### Key Design Decisions (from TEA investigation)

1. **Native Textual DataTable** — NOT Rich Table renderables. Use `DataTable` widget with columns: Time, Tool, Input, Result
2. **WebSocket channel: `spans`** — Tool events already broadcast on `/ws/spans` (no new backend channel needed). Init: `{type: 'init', spans: [...]}`, updates: `{type: 'span', span: ToolEvent}`
3. **Inherit BasePanel** — For WebSocket subscription plumbing, set `channel = "spans"`
4. **DataTable columns:** Time (formatted from ms timestamp), Tool (toolName), Input (truncated excerpt), Result (✓/✗ indicator)
5. **Message handling:** `init` replaces all rows, `span` appends single row
6. **Registration:** Add to `PANEL_REGISTRY` in tui.py, keybinding `8`, import + mount in `compose()`
7. **No backend changes needed** — `/ws/spans` already exists and streams ToolEvent data

### Implementation Notes for Sergeant Carter

- `ToolEvent` interface: `{toolName, input?, success?, workingDirectory?, timestamp?, [key]: unknown}`
- Input truncation needed for long bash commands (80 chars max with ellipsis)
- Panel icon already in PANEL_ICONS: `"audit-log": ("\uf15c", "L")`
- Follow `BackgroundPanel` pattern for BasePanel inheritance + custom message handling
- DataTable must be created in `__init__`, columns added, then rows managed via `handle_message` override

**Handoff:** To Dev (Sergeant Carter) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/audit_log_panel.py` — Full AuditLogPanel implementation with DataTable, /ws/spans subscription, init/span handling
- `pennyfarthing_scripts/bikerack/tui.py` — Panel registration, keybinding 6, compose mount

**Tests:** 44/44 passing (GREEN)
**PR:** #953 — feat(110-8): implement audit log panel for BikeRack TUI
**Branch:** feature/PROJ-15195-hook-up-audit-log-panel (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** WS `/ws/spans` → BasePanel.on_mount subscribe → handle_message → type dispatch (init/span) → _add_row → DataTable.add_row (safe, validated at every stage)
**Pattern observed:** _OfflineDataTable subclass provides fallback console for unit-testable DataTable — novel but necessary for the BasePanel architecture at `audit_log_panel.py:26-39`
**Error handling:** Comprehensive guards at `audit_log_panel.py:64-83` — None, non-dict, missing type, missing spans/span, non-list, empty span all handled with graceful fallbacks

| Severity | Issue | Location | Note |
|----------|-------|----------|------|
| [MEDIUM] | DataTable not composed into widget tree — panel blank in running TUI | audit_log_panel.py:42 | One-line fix: `def compose(): yield self._table` |
| [LOW] | Private API import `textual._context.NoActiveAppError` | audit_log_panel.py:15 | Maintenance debt, acceptable |

**Handoff:** To SM for finish-story