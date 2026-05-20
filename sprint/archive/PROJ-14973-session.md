# Story 103-18: DiffsPanel — Rich diff rendering with syntax highlighting

**Jira:** PROJ-14973
**Epic:** 103 — BikeRack TUI — Terminal-Native Dashboard
**Points:** 3
**Priority:** P0
**Workflow:** tdd
**Phase:** finish
**Branch:** feature/103-18-diffs-panel-rich-rendering
**Repos:** orchestrator, pennyfarthing

## Description

The one Redesign panel. Subscribes to `/ws/diffs` channel. Renders file diffs with syntax highlighting using Rich's built-in diff support. File headers, added/removed line coloring, line numbers.

## Acceptance Criteria

1. **DiffsPanel implementation** exists in the TUI codebase under `pennyfarthing/pennyfarthing_scripts/bikerack/panels/`
2. **WebSocket subscription** to `/ws/diffs` channel receives JSON payloads with structure: `{type:'init'|'refresh', diffs:[]}`
3. **Syntax highlighting** applied to diffs using `rich.syntax` for language-specific coloring
4. **Diff rendering** displays:
   - File headers (filename, change type)
   - Added lines (green coloring)
   - Removed lines (red coloring)
   - Line numbers
   - Context lines (unchanged code with reduced contrast)
5. **Real-time updates** when new diffs arrive via WebSocket
6. **Error handling** for invalid/malformed diff data
7. **Unit tests** covering panel rendering and WebSocket message handling
8. **Integration tests** verifying panel connects and renders correctly in TUI layout

## Technical Context

### Architecture
- **Epic:** BikeRack TUI — Terminal-Native Dashboard (Epic 103)
- **Framework:** Python TUI using Textual + Rich libraries
- **Dependencies:** textual, rich, websockets (or websocket-client)
- **Data Source:** WheelHub WebSocket server at configurable port
- **Port discovery:** Reads `.bikerack-port` file or defaults to 2898

### Key Files & References

**WheelHub (reference only, TypeScript):**
- WebSocket setup: `pennyfarthing/packages/cyclist/src/websocket.ts:44`
- Diffs channel schema: `{type:'init'|'refresh', diffs:[]}`
- Existing React panel hook reference: `pennyfarthing/packages/cyclist/src/public/hooks/useDiffs.ts` (if exists)

**Python TUI Structure:**
- Entry point: `pennyfarthing/pennyfarthing_scripts/bikerack/app.py`
- Base panel class: `pennyfarthing/pennyfarthing_scripts/bikerack/panels/base_panel.py` (created in story 103-5)
- Panel directory: `pennyfarthing/pennyfarthing_scripts/bikerack/panels/`
- WebSocket client: `pennyfarthing/pennyfarthing_scripts/bikerack/client.py` (created in story 103-2)
- Config loader: `pennyfarthing/pennyfarthing_scripts/common/config.py`

### Dependencies (Must Exist)
- **Story 103-5:** Base panel abstraction with channel subscription + Rich rendering
- **Story 103-2:** WebSocket client with auto-reconnect

### Implementation Pattern

All TUI panels follow the same pattern:
1. Inherit from `BasePanel` class
2. Implement `render()` method returning Rich renderable
3. Subscribe to WebSocket channel in `__init__()`
4. Receive JSON payload with `type:'init'|'update'` or `'refresh'` for diffs
5. Call `render()` on each message
6. Display in main content area of TUI

**Key differences for DiffsPanel:**
- Uses `rich.syntax.Syntax` for language-specific syntax highlighting
- Parses unified diff format or custom format from WebSocket
- Handles added/removed line coloring directly (Rich's diff rendering)
- Must handle large diffs gracefully (see story 103-19 for pagination)

### Data Contract (ACTUAL from `/ws/diffs` channel — verified from WheelHub source)

```typescript
// Messages: {type: 'init'|'refresh', diffs: DiffData[]}
interface DiffData {
  id: string;           // e.g. "diff-path-timestamp"
  path: string;         // file path (may include repo prefix)
  original: string;     // deprecated — always ""
  modified: string;     // deprecated — always ""
  diff: string;         // RAW UNIFIED GIT DIFF (parse this!)
  toolName: string;     // "Git"
  timestamp: number;
  status: 'modified' | 'added' | 'deleted' | 'renamed';
  additions: number;
  deletions: number;
}
```

**Key insight:** The `diff` field is raw `git diff HEAD` output in unified format.
Parse it line-by-line: `+` = added, `-` = removed, ` ` = context, `@@` = hunk header.
See `pennyfarthing/packages/cyclist/src/git-diff.ts` for the server-side parser and
`pennyfarthing/packages/cyclist/src/public/components/panels/DiffsPanel.tsx:30` for
the React reference implementation of `parseGitDiffLines()`.

### Testing Strategy (TDD)
1. **Unit tests** for diff parsing and rendering logic
2. **Integration tests** verifying WebSocket subscription and message handling
3. **Mock WebSocket server** for testing without running real WheelHub
4. **Snapshot tests** for diff output consistency

### Development Checklist
- [ ] Read React panel hook for exact WebSocket payload format
- [ ] Implement DiffsPanel class inheriting from BasePanel
- [ ] Add syntax highlighting using `rich.syntax`
- [ ] Implement diff parsing logic (unified or custom format)
- [ ] Write unit tests for rendering logic
- [ ] Write integration tests for WebSocket handling
- [ ] Test with live WheelHub WebSocket connection
- [ ] Verify large diff handling (respects story 103-19 constraints)
- [ ] Add error handling for malformed diffs
- [ ] Verify integration with TUI layout (panels can be switched to DiffsPanel via `/bc show diffs`)

## Session Log

- 2026-02-14T13:18:00Z SM: Story setup complete. Feature branches created in both repos. Jira PROJ-14973 claimed and moved to In Progress. Session file created with full technical context. Blocker 103-5 (base panel) confirmed done. Handing off to TEA for test design phase.
- 2026-02-14T13:20:00Z SM: Handoff to TEA for red phase (test design)
- 2026-02-14T13:35:00Z TEA: RED state confirmed. 45 tests (24 pass structural, 21 fail on assertions). All failures are correct — stub returns placeholder, no rendering logic. Corrected data contract in session from hypothetical hunks to actual WheelHub wire format (raw unified git diff strings). Committed test + stub to pennyfarthing repo.
- 2026-02-14T13:40:00Z TEA: Handoff to Dev for green phase (implementation)
- 2026-02-14T13:50:00Z Dev: GREEN state confirmed. 45/45 tests passing. Implementation committed, pushed, PR #878 created targeting develop. Handing off to Reviewer.
- 2026-02-14T13:52:00Z Dev: Handoff to Reviewer for review phase
- 2026-02-14T14:05:00Z Reviewer: REJECTED. 2x HIGH: (1) AC3 unmet — no rich.syntax.Syntax usage, only line-type coloring; (2) AC3 tests are sham — check content words not syntax highlighting. Back to Dev for fixes. TEA should strengthen AC3 tests first.
- 2026-02-14T14:15:00Z Dev: Fixed both HIGH issues. Added rich.syntax.Syntax for language-specific token highlighting via Syntax.highlight(). Strengthened AC3 tests: import verification + truecolor ANSI code count. 47/47 passing. Pushed to PR #878. Handing back to Reviewer.
- 2026-02-14T14:25:00Z Reviewer: APPROVED (round 2). Both HIGH issues resolved. 47/47 tests pass, lint clean. No blocking issues remain. Merging PR #878.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bikerack/diffs_panel.py` — Full DiffsPanel with rich.syntax.Syntax highlighting (131 lines)
- `tests/python/test_bikerack_diffs_panel.py` — Strengthened AC3 tests (47 tests)

**Approach:** Parse raw unified git diff line-by-line. Each code line highlighted via `Syntax.highlight()` for language-specific token coloring. Language detected from file extension via `_detect_language()`. Added lines: green line number prefix + syntax-highlighted content. Removed lines: red dash prefix + syntax-highlighted content. Context lines: dim line number + syntax-highlighted content. Hunk headers cyan, file headers bold cyan with status + stats.

**Reviewer Fix (round 2):** Added `rich.syntax.Syntax` import and `_highlight_code()` helper per AC3. Strengthened AC3 tests to verify truecolor ANSI codes from Syntax (not just content words). Added `test_module_imports_rich_syntax` and `test_python_file_has_language_specific_colors`.

**Tests:** 47/47 passing (GREEN)
**PR:** #878 — feat(103-18): DiffsPanel rich diff rendering
**Branch:** feature/103-18-diffs-panel-rich-rendering (pushed)

**Handoff:** To Reviewer (Zorg) for re-review

## TEA Assessment

**Tests Required:** Yes
**Reason:** 3-point P0 feature with rendering logic, parsing, and styling

**Test Files:**
- `tests/python/test_bikerack_diffs_panel.py` — 45 tests across 6 classes
- `pennyfarthing_scripts/bikerack/diffs_panel.py` — minimal stub (compile-only)

**Tests Written:** 45 tests covering 6 ACs (existence, subscription, syntax highlighting, rendering, real-time updates, error handling)
**Passing:** 24 (structural wiring — imports, channel, BasePanel inheritance, message handling)
**Failing:** 21 (rendering content, styling, parsing — all on assertions)
**Status:** RED (failing — ready for Dev)

**Critical discovery:** Session data contract was wrong. Actual WheelHub sends `DiffData` with raw unified git diff in `diff` field (NOT pre-parsed hunks). Updated session accordingly. Dev should reference `parseGitDiffLines()` in the React DiffsPanel.tsx for the parsing pattern.

**Handoff:** To Dev (Korben Dallas) for implementation

## Reviewer Assessment (Round 1)

**Verdict:** REJECTED — 2x HIGH (AC3 unmet, sham tests). See session log.

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED

**Round 1 issues resolved:**
- [HIGH→FIXED] AC3: `from rich.syntax import Syntax` at `diffs_panel.py:14`, used in `_highlight_code()` at line 69 via `Syntax.highlight()` for per-token language-specific coloring
- [HIGH→FIXED] Tests: `test_python_file_has_language_specific_colors` at `test_bikerack_diffs_panel.py:293` counts unique truecolor ANSI codes (>= 2) — impossible to pass without real syntax highlighting

**Non-blocking observations:**
- [MEDIUM] Per-line `Syntax()` creation at `diffs_panel.py:69` — performance concern for large diffs. Acceptable given 103-19 scopes pagination.
- [MEDIUM] DiffsPanel not in `tui.py` compose tree — matches GitPanel pattern, deferred to panel-switching story.
- [LOW] `_LANG_MAP` limited to 20 extensions — safe fallback to "text".

**Data flow traced:** WebSocket payload → `BasePanel.handle_message()` → `DiffsPanel.render_panel()` → `_render_file_diff()` → `_detect_language(path)` → `_parse_diff_lines(raw_diff, language)` → `_highlight_code(line, language)` → `Syntax.highlight()` → styled `Text` → `Group` → `Static.update()`. Safe — no injection vectors.

**Pattern observed:** Defensive `_highlight_code` try/except fallback at `diffs_panel.py:73` — Pygments failure degrades to plain text, not crash.

**Error handling:** All round-1 verified patterns intact plus new exception guard at `_highlight_code:73`.

**Tests:** 47/47 passing, lint clean (ruff).

**Handoff:** Merging PR #878, then to SM (Ruby Rhod) for finish-story.
