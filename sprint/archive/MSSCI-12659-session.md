# Story Session: MSSCI-12659

**Story:** Implement pf agent start command
**Jira:** MSSCI-12659
**Epic:** epic-67 (Pennyfarthing Python CLI)
**Points:** 3
**Workflow:** tdd
**Phase:** approved
**Repos:** pennyfarthing
**Feature Branch:** feat/MSSCI-12659-agent-start-cmd

---

## Description

Create agent/cli.py with start command. Loads agent session, persona,
sidecar memory, and sprint context. Highest-frequency command.

## Acceptance Criteria

- [ ] pf agent start <name> starts session
- [ ] --session-id and --no-persona options work
- [ ] Outputs session ID and full agent context
- [ ] Calls existing prime module

## Technical Context

- **Base:** pennyfarthing/pennyfarthing_scripts/cli.py (main CLI entry point)
- **Target:** pennyfarthing/pennyfarthing_scripts/agent/cli.py (new subgroup)
- **Reference:** Existing prime module at pennyfarthing_scripts/prime/

## Phase History

| Phase | Agent | Status | Notes |
|-------|-------|--------|-------|
| setup | SM | complete | Session created |
| red | TEA | complete | 18 failing tests written |
| implement | Dev | complete | 19/19 tests GREEN, PR #558 |
| review | Reviewer | complete | APPROVED |
| approved | SM | in_progress | Ready for finish |

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] Lazy import pattern at `cli.py:69` - maintains <200ms startup
2. [VERIFIED] All required options present at `cli.py:44-50`
3. [VERIFIED] Exit code propagation at `cli.py:79` via `SystemExit`
4. [VERIFIED] Parameter passing matches prime signature at `cli.py:71-78`
5. [VERIFIED] Tests cover all 4 ACs with 19 tests
6. [LOW] Missing `--quiet`, `--no-workflow`, `--no-register` - not in ACs, not blocking

**Data flow traced:** CLI → Click parser → `agent_start()` → lazy import → `prime()` → context → exit code

**Security:** No concerns - local CLI, no network calls, no untrusted input

**Handoff:** To SM for finish-story

## TEA Assessment

**Tests Required:** Yes
**Test File:** `tests/python/test_agent_cli.py`

**Tests Written:** 19 tests covering 4 ACs
- AC1 (start session): 5 tests - agent group, start command, requires name
- AC2 (options): 4 tests - --session-id, --no-persona passed correctly
- AC3 (output): 2 tests - session ID and context output
- AC4 (prime module): 3 tests - delegates to prime, returns exit code
- Additional options: 4 tests - --json, --minimal, --full
- Module invocation: 1 test

**Status:** RED (18 failing, 1 passing - "agent" mentioned in help)

**Implementation Notes:**
- Add `@cli.group() def agent()` to cli.py
- Add `@agent.command("start")` with options
- Delegate to `pennyfarthing_scripts.prime.prime()`
- Pass through all options: agent_name, session_id, no_persona, json_output, minimal, full

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/cli.py` - Added agent group with start command

**Tests:** 19/19 passing (GREEN) + 13 existing CLI tests pass
**PR:** #558 - feat(cli): add agent start command (MSSCI-12659)
**Branch:** feat/MSSCI-12659-agent-start-cmd (pushed)

**Implementation Details:**
- Added `@cli.group() def agent()` command group
- Added `@agent.command("start")` with all required options
- Delegates to `pennyfarthing_scripts.prime.prime()` with lazy import
- Uses `SystemExit(exit_code)` to propagate prime's exit code

**Handoff:** To Reviewer for code review

## Session Log

- **2026-01-30:** Session created for MSSCI-12659
- **2026-01-30:** SM setup complete, starting TEA red phase
- **2026-01-30:** TEA wrote 19 failing tests, handoff to Dev
- **2026-01-30:** Dev implemented, 19/19 GREEN, PR #558 created
- **2026-01-30:** Reviewer APPROVED, handoff to SM for finish
