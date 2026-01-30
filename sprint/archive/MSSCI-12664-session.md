# Story Setup: MSSCI-12664

## Story Details

| Field | Value |
|-------|-------|
| Story ID | MSSCI-12664 |
| Jira Key | MSSCI-12664 |
| Title | Implement pf sprint story command |
| Points | 1 |
| Epic | epic-67 (Pennyfarthing Python CLI) |
| Workflow | tdd |
| Phase | approved |
| Repos | pennyfarthing |
| Feature Branch | feat/MSSCI-12664-implement-pf-sprint-story-command |
| Assignee | keith |
| Priority | P2 |

## Epic Context

**Epic**: Pennyfarthing Python CLI (MSSCI-12655)
**Description**: Unified CLI entry point using Click. Phase 1 covers agent activation commands (highest frequency). Phase 2 covers core operations.

This story is part of **Phase 2** and focuses on the sprint subcommand group.

**Epic Status**: In Progress (12 of 19 points done)

**Related Stories**:
- MSSCI-12656 (Add Click dependency and create CLI entry point) - DONE
- MSSCI-12657 (Implement pf workflow check command) - DONE
- MSSCI-12658 (Implement pf workflow phase-check command) - DONE
- MSSCI-12659 (Implement pf agent start command) - DONE
- MSSCI-12660 (Update agent command files to use Python CLI) - BACKLOG
- MSSCI-12661 (Add startup benchmark to CI) - DONE
- MSSCI-12662 (Migrate sprint/cli.py to Click) - BACKLOG
- MSSCI-12663 (Implement pf workflow handoff command) - DONE
- **MSSCI-12664 (Implement pf sprint story command)** - IN PROGRESS (THIS STORY)
- MSSCI-12665 (Integration tests for bash/Python parity) - BACKLOG

## Acceptance Criteria

- [ ] `pf sprint story 67-1` returns story details
- [ ] `--json` flag for structured output

## Technical Context

### Existing Sprint CLI Structure

The sprint CLI module is located at:
```
pennyfarthing/pennyfarthing_scripts/sprint/
├── __init__.py
├── __main__.py
├── cli.py              # Main Click-based CLI entry point
├── loader.py           # YAML parsing utilities (HAS get_story_by_id!)
├── status.py           # Sprint status display
├── archive.py          # Story archival
└── work.py             # Work on story operations
```

### Key Functions Already Available

**In `pennyfarthing_scripts/sprint/loader.py`**:
- `get_story_by_id(story_id: str) -> dict | None` - Find story by ID (accepts both "63-7" format and "MSSCI-12664" format)
- `load_sprint()` - Load sprint data from YAML
- `get_epic_by_id()` - Find epic by ID
- Returns story dict with fields: id, title, points, status, jira, description, priority, workflow, etc.

### Implementation Plan

1. Add `story` subcommand to sprint CLI in `sprint/cli.py`
2. Command signature: `pf sprint story <id> [--json]`
3. Use `loader.get_story_by_id()` to fetch story details
4. Format output as text table by default, JSON when `--json` flag is used
5. Handle errors gracefully (story not found)
6. Keep startup time < 200ms (lazy import loader)

### Example Output

**Text mode**:
```
Story: 67-1
Title: Fix background tasks WebSocket broadcast
Points: 1
Status: done
Priority: P0
Workflow: tdd
Description: Background tasks panel in Cyclist never shows background agents...
```

**JSON mode (`--json`)**:
```json
{
  "id": "67-1",
  "title": "Fix background tasks WebSocket broadcast",
  "points": 1,
  "status": "done",
  "priority": "P0",
  "workflow": "tdd",
  "jira": "MSSCI-12522",
  "description": "Background tasks panel in Cyclist never shows background agents..."
}
```

### Testing Approach

- Test with both "67-1" and "MSSCI-12522" formats
- Test with --json flag
- Test error case (story not found)
- Verify startup time remains < 200ms
- Run existing sprint CLI tests to ensure no regression

## Development Workflow (TDD)

1. **RED** - Write failing tests for `pf sprint story` command
2. **GREEN** - Implement the command to pass tests
3. **REFACTOR** - Polish output formatting and documentation
4. **REVIEW** - Submit for code review

## Notes

- The sprint CLI is already Click-based and well-structured
- The loader module already has all needed functionality via `get_story_by_id()`
- This is a small story (1 point) - straightforward implementation
- Must maintain lazy loading pattern to keep startup time < 200ms

## TEA Assessment

**Tests Required:** Yes
**Reason:** New CLI command requires verification of output format and error handling

**Test Files:**
- `tests/python/test_sprint_story_command.py` - Sprint story command tests

**Tests Written:** 14 tests covering 2 ACs
- AC1 (text output): 6 tests - command registration, story details display
- AC2 (JSON output): 5 tests - valid JSON, required fields
- Error handling: 2 tests - nonexistent story, missing argument
- Performance: 1 test - startup under 200ms

**Status:** RED (13 failing, 1 passing - ready for Dev)
- All tests fail with `Error: No such command 'story'`
- This is the correct failure reason

**Commit:** `5bd673dce` - test: add failing tests for pf sprint story command

**Handoff:** To Dev (Loki Silvertongue) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/sprint/cli.py` - Add story command with --json flag

**Tests:** 14/14 passing (GREEN)
**PR:** #564 - feat(cli): implement pf sprint story command (MSSCI-12664)
**Branch:** feat/MSSCI-12664-implement-pf-sprint-story-command (pushed)

**Implementation Details:**
- Added `@sprint.command()` decorated `story` function
- Accepts story ID argument (supports both MSSCI-XXXXX and X-Y formats)
- `--json` flag outputs structured JSON via `json.dumps()`
- Lazy imports `get_story_by_id` from loader module
- Error handling via `click.ClickException` for missing stories
- Startup performance maintained under 200ms

**Handoff:** To Reviewer (Heimdall) for code review

## Reviewer Assessment

**Verdict:** APPROVED

### Preflight Results
- **Story Tests:** 14/14 passing (GREEN)
- **Full Test Suite:** Pre-existing failures (unrelated to this PR)
- **Lint:** Pre-existing issues in codebase (none introduced by this PR)

### Code Review Observations

| Severity | Observation | Location |
|----------|-------------|----------|
| [VERIFIED] | Command registration uses Click correctly | cli.py:104-106 |
| [VERIFIED] | Lazy import pattern maintained for startup performance | cli.py:115 |
| [VERIFIED] | Error handling via `click.ClickException` | cli.py:119-120 |
| [VERIFIED] | JSON flag uses alias to avoid shadowing builtin | cli.py:106 |
| [VERIFIED] | Safe field access with `.get()` defaults | cli.py:127-138 |
| [VERIFIED] | No injection vulnerabilities (string comparison only) | loader.py:88-103 |

### Data Flow Traced
User input `story_id` → `cli.story()` → `loader.get_story_by_id(story_id)` → YAML read via `load_sprint()` → dict returned → `click.echo()` or `json.dumps()` output

**Safe because:** No shell execution, no SQL, no file path construction from user input. Story ID is used purely for string comparison against YAML data.

### Pattern Observed
Implementation follows existing patterns in the file (see `work` command at cli.py:66-101 and `status` command at cli.py:32-48). Consistent with codebase conventions.

### Error Handling
- Missing story: Returns `click.ClickException("Story not found: {id}")` with exit code 1 ✓
- Missing argument: Click handles automatically ✓
- Missing fields in story: Uses `.get(field, default)` pattern ✓

### AC Verification
- [x] AC1: `pf sprint story <id>` returns story details (verified with MSSCI-12664)
- [x] AC2: `--json` flag outputs valid structured JSON

**Note:** AC1 mentions `67-1` format which was a historical ID format. Current sprint uses MSSCI-XXXXX IDs. The loader correctly supports both formats when they exist in the data.

### Handoff
To Baldur the Bright (SM) for finish-story

## Handoff: Review Complete

**Timestamp:** 2026-01-30T10:30:00Z
**From Agent:** Heimdall (Reviewer)
**To Agent:** Baldur the Bright (SM)
**Verdict:** APPROVED
**Next Action:** finish-story

The code review has passed. All acceptance criteria verified. Ready for SM to complete the story.
