# Story MSSCI-12662: Migrate sprint/cli.py to Click

**Epic:** 67 - Pennyfarthing Python CLI (MSSCI-12655)
**Assigned:** keith
**Points:** 2
**Workflow:** tdd
**Repos:** pennyfarthing-orchestrator
**Jira:** MSSCI-12662

## Story Summary

Migrate the existing argparse-based sprint CLI (`pennyfarthing_scripts/sprint/cli.py`) to use Click, integrating it as a subgroup under the main `pf` CLI. This aligns sprint commands with the Click-based CLI architecture established in MSSCI-12656 and enables consistent command invocation via `pf sprint <command>`.

## Acceptance Criteria

- [ ] Sprint commands available under `pf sprint` group
- [ ] `pf sprint status [filter]` shows sprint status (optional filter: backlog, in-progress, done)
- [ ] `pf sprint backlog` shows available stories
- [ ] `pf sprint work [story-id]` starts work on a story
- [ ] `pf sprint archive <id> [pr]` archives a completed story
- [ ] Default behavior (no subcommand) shows status
- [ ] Lazy loading pattern maintained for fast startup (<200ms)
- [ ] Existing module interfaces preserved (status.main, work.main, archive.main)
- [ ] Original `python -m pennyfarthing_scripts.sprint` entry point still works

## Technical Approach

### Architecture

The migration follows the established Click CLI pattern from MSSCI-12656:

1. **Add `sprint` group to main CLI** (`cli.py`):
   ```python
   @cli.group()
   def sprint():
       """Sprint status and story operations."""
       pass
   ```

2. **Convert subcommands to Click commands**:
   - `status` - Click command with optional `filter` argument
   - `backlog` - Click command (no arguments)
   - `work` - Click command with optional `story-id` argument
   - `archive` - Click command with `id` argument and optional `pr` argument

3. **Lazy import pattern** (per epic requirements):
   ```python
   @sprint.command("status")
   @click.argument("filter", required=False)
   def sprint_status(filter: str | None):
       from pennyfarthing_scripts.sprint.status import main as status_main
       # ...
   ```

4. **Preserve backward compatibility**:
   - Keep `cli()` function in `sprint/cli.py` as alias for standalone invocation
   - `python -m pennyfarthing_scripts.sprint` continues to work

### Key Files

| File | Purpose |
|------|---------|
| `pennyfarthing/pennyfarthing_scripts/cli.py` | Main CLI entry point - add sprint group |
| `pennyfarthing/pennyfarthing_scripts/sprint/cli.py` | Current argparse CLI - migrate to Click |
| `pennyfarthing/pennyfarthing_scripts/sprint/status.py` | Status subcommand implementation |
| `pennyfarthing/pennyfarthing_scripts/sprint/work.py` | Work subcommand implementation |
| `pennyfarthing/pennyfarthing_scripts/sprint/archive.py` | Archive subcommand implementation |
| `pennyfarthing/pennyfarthing_scripts/sprint/loader.py` | Sprint data loading utilities |

### Testing Strategy (TDD)

Tests should verify:
1. `pf sprint` group exists and is accessible
2. Each subcommand (status, backlog, work, archive) works via Click
3. Default behavior shows status
4. Arguments and options work correctly
5. Lazy imports maintain startup performance
6. Exit codes match original behavior

## Workflow Tracking

**Workflow:** tdd
**Phase:** approved
**Feature Branch:** feat/MSSCI-12662-migrate-sprint-cli-click
**Phase Started:** 2026-01-30T00:00:00Z
**Status:** APPROVED - ready for SM to finish

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-01-30T00:00:00Z | 2026-01-30T00:00:00Z | 0m |

### Handoff: SM -> TEA (setup -> red)
**Timestamp:** 2026-01-30T00:00:00Z
**SM Assessment:** Story setup complete, technical context documented, ready for TEA
**Next Agent:** TEA (Tyr One-Handed)
**Next Phase:** red (write failing tests)

**Handoff Notes:**
- Story scope defined: Migrate sprint/cli.py from argparse to Click
- Technical approach documented with architecture and key files
- Acceptance criteria established with 9 testable requirements
- Related completed stories provide implementation patterns
- Testing strategy outlined for TDD red phase

### Handoff: TEA -> Dev (red -> implement)
**Timestamp:** 2026-01-30T00:00:00Z
**TEA Assessment:** RED state confirmed - 43 tests written, 27 failing, 16 passing
**Test Result:** RED
**Next Agent:** Dev (Loki Silvertongue)
**Next Phase:** implement (make tests GREEN)

**Handoff Notes:**
- 43 tests covering all 9 acceptance criteria written to `pennyfarthing/tests/python/test_sprint_cli.py`
- 27 tests failing with `No such command 'sprint'` - sprint group not yet added to main CLI
- 16 tests passing (module interface preservation and backward compatibility already satisfied)
- Implementation guidance provided in TEA Assessment section
- Ready for Dev to implement sprint group and make tests GREEN

## Context & References

### Epic Context
- Epic 67 context: `sprint/context/context-epic-67.md`
- CLI Architecture: Click with lazy-loaded subgroups for fast startup (<200ms)

### Related Stories (Completed)
- MSSCI-12656: Add Click dependency and create CLI entry point (done)
- MSSCI-12657: Implement pf workflow check command (done)
- MSSCI-12658: Implement pf workflow phase-check command (done)
- MSSCI-12659: Implement pf agent start command (done)
- MSSCI-12663: Implement pf workflow handoff command (done)

### Core Files for TEA (Test Writing)
- `pennyfarthing/pennyfarthing_scripts/cli.py` - Main CLI with Click groups
- `pennyfarthing/pennyfarthing_scripts/sprint/cli.py` - Current argparse implementation
- `pennyfarthing/pennyfarthing_scripts/sprint/*.py` - Subcommand modules

### Key Technical Points for Tests
1. `pf sprint` group should be registered on main CLI
2. All subcommands accessible via `pf sprint <cmd>`
3. `pf sprint` with no subcommand defaults to status
4. Arguments match original CLI interface
5. Exit codes preserved from original implementation
6. Startup time remains under 200ms target

## TEA Assessment

**Tests Required:** Yes
**Reason:** Story adds new CLI commands requiring test coverage

**Test File:**
- `pennyfarthing/tests/python/test_sprint_cli.py` - Click CLI tests for sprint group

**Tests Written:** 43 tests covering 9 ACs
**Status:** RED (27 failing, 16 passing - ready for Dev)

**Failure Reason:** `No such command 'sprint'` - the sprint group has not been added to the main CLI yet.

**Passing Tests:** Module interface preservation (AC8) and backward compatibility (AC9) tests pass because the existing sprint/cli.py and submodules are already correctly structured.

**Implementation Notes for Dev:**
1. Add `@cli.group()` for sprint to `pennyfarthing_scripts/cli.py`
2. Register subcommands: status, backlog, work, archive
3. Use lazy imports inside each command function
4. Default behavior: `pf sprint` → invoke status
5. Wire commands to existing `main()` functions in submodules

**Handoff:** To Dev for implementation (GREEN phase)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/pennyfarthing_scripts/cli.py` - Added sprint group with status, backlog, work, archive commands

**Tests:** 43/43 passing (GREEN)
**PR:** #560 - feat(MSSCI-12660): update agent commands to use Python CLI
**Branch:** feat/MSSCI-12660-agent-python-cli (pushed)

**Implementation Details:**
- Added `@cli.group(invoke_without_command=True)` for sprint with default status behavior
- Implemented status, backlog, work, archive subcommands with lazy imports
- All commands wire to existing module `main()` functions
- Startup time remains <200ms due to lazy loading

**Commits:**
- `933fd4ef2` - test(sprint-cli): add failing tests for Click migration
- `f7c67adbd` - feat(sprint-cli): add sprint group to Click CLI

**Handoff:** To Reviewer for code review

### Handoff: Dev -> Reviewer (implement -> review)
**Timestamp:** 2026-01-30T00:00:00Z
**Dev Assessment:** GREEN state confirmed - 43/43 tests passing, implementation complete
**Test Result:** GREEN
**Next Agent:** Reviewer (Heimdall)
**Next Phase:** review (code review)

**Handoff Notes:**
- Sprint CLI migrated to Click with all 9 acceptance criteria satisfied
- Added sprint group to main CLI with status, backlog, work, archive commands
- Lazy import pattern maintained for <200ms startup time
- All commands wire to existing module `main()` functions preserving interfaces
- PR #560 ready for review
- 43 tests passing, covering all acceptance criteria

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
| Severity | Observation | Location |
|----------|-------------|----------|
| [VERIFIED] | Lazy imports working - 10.3ms import, no sprint modules loaded at CLI import | cli.py:173,189,200,221,240 |
| [VERIFIED] | Data flow safe - reads from local YAML only | loader.py → config.py |
| [VERIFIED] | Pattern consistency - matches existing workflow/agent groups | cli.py:156-246 |
| [VERIFIED] | Error handling delegated to existing modules | cli.py (all commands) |
| [VERIFIED] | Default behavior works via invoke_without_command | cli.py:156,171 |
| [VERIFIED] | Backward compatibility preserved | TestBackwardCompatibility passes |
| [LOW] | story.get('title') could print None - matches existing pattern | cli.py:207 |

**Data Flow Traced:** `pf sprint backlog` → sprint_backlog() → get_stories_by_status() → get_all_stories() → load_sprint() → load_yaml_config() → YAML file read (safe)

**Security Analysis:** No user input passed unsanitized. All data from local YAML files. No injection vectors.

**Tests:** 43/43 passing, linter passes

**Handoff:** To SM for finish-story

### Handoff: Reviewer -> SM (review -> approved)
**Timestamp:** 2026-01-30T00:00:00Z
**Reviewer Assessment:** APPROVED - no Critical/High issues found
**Next Agent:** SM (Baldur the Bright)
**Next Phase:** approved (finish story)

**Handoff Notes:**
- All 9 acceptance criteria verified through tests
- Lazy import pattern confirmed working (10.3ms import time)
- Code follows existing patterns from workflow/agent groups
- No security concerns - local YAML file access only
- Ready for story completion and archival

## Notes

- Feature branch: feat/MSSCI-12662-migrate-sprint-cli-click
- This is Phase 2 of Epic 67 (Core Operations)
- Follows pattern established in workflow commands (MSSCI-12656)
- Must maintain backward compatibility with `python -m pennyfarthing_scripts.sprint`
