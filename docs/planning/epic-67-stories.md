# Epic 67: Pennyfarthing Python CLI Migration

## Epic Overview

| Field | Value |
|-------|-------|
| **Epic ID** | epic-67 |
| **Priority** | P1 |
| **Total Points** | 19 |
| **Status** | planning |
| **Repos** | pennyfarthing |
| **PRD** | docs/planning/prd.md |
| **Architecture** | docs/planning/architecture.md |

## Description

Replace fragile bash script symlinks with a unified Python CLI (`pf`) that agents can invoke reliably via module resolution. Eliminates path-related errors that waste agent context on debugging instead of productive work.

Key decisions:
- Click library for decorator-based CLI (per PRD FR18)
- Lazy loading for <200ms startup time
- Phased migration: bash preserved during transition

## Stories

### Phase 1: MVP (Stop the Bleeding) - 12 points

#### 67-1: Add Click dependency and create CLI entry point
- **Points:** 2
- **Priority:** P1
- **Status:** backlog
- **Workflow:** tdd
- **Description:** Add `click>=8.0,<9.0` to pyproject.toml. Create `pennyfarthing_scripts/cli.py` with `@click.group()` entry point and lazy-loaded subgroups for agent, workflow, sprint.
- **Acceptance Criteria:**
  - click added to dependencies in pyproject.toml
  - `python -m pennyfarthing_scripts.cli --help` shows command groups
  - Startup time < 200ms verified
  - All imports are lazy (inside functions)

#### 67-2: Implement `pf workflow check` command
- **Points:** 2
- **Priority:** P1
- **Status:** backlog
- **Workflow:** tdd
- **Description:** Create `workflow/cli.py` with `check` command. Detects workflow state (FINISH, NEW_WORK, IN_PROGRESS, EMPTY_BACKLOG) and outputs story ID, phase, owner.
- **Acceptance Criteria:**
  - `python -m pennyfarthing_scripts.cli workflow check` returns workflow state
  - `--json` flag outputs JSON format
  - Exit code 0 for all states (including empty)
  - Output matches bash script format for parity

#### 67-3: Implement `pf workflow phase-check` command
- **Points:** 2
- **Priority:** P1
- **Status:** backlog
- **Workflow:** tdd
- **Description:** Create `phase-check` command that verifies phase ownership for a given workflow and phase. Returns owner agent name.
- **Acceptance Criteria:**
  - `python -m pennyfarthing_scripts.cli workflow phase-check <workflow> <phase>` returns owner
  - Exit code 0 always (valid query)
  - Matches phase-check-start.sh output format

#### 67-4: Implement `pf agent start` command
- **Points:** 3
- **Priority:** P1
- **Status:** backlog
- **Workflow:** tdd
- **Description:** Create `agent/cli.py` with `start` command. Loads agent session, persona, sidecar memory, and sprint context. This is the highest-frequency command.
- **Acceptance Criteria:**
  - `python -m pennyfarthing_scripts.cli agent start <name>` starts session
  - `--session-id` and `--no-persona` options work
  - Outputs session ID and full agent context
  - Calls existing prime module for context loading
  - Exit code 0 success, 1 error

#### 67-5: Update agent command files to use Python CLI
- **Points:** 2
- **Priority:** P1
- **Status:** backlog
- **Workflow:** trivial
- **Description:** Update agent command files (sm.md, dev.md, etc.) to use `python -m pennyfarthing_scripts.cli` instead of bash scripts. Preserve bash fallback during transition.
- **Acceptance Criteria:**
  - All agent commands use Python CLI invocation
  - Bash scripts remain available as fallback
  - Agent activation works correctly with new invocation
  - No path-related errors in testing

#### 67-6: Add startup benchmark to CI
- **Points:** 1
- **Priority:** P2
- **Status:** backlog
- **Workflow:** trivial
- **Description:** Add CI step that measures `python -m pennyfarthing_scripts.cli --help` startup time and fails if > 200ms.
- **Acceptance Criteria:**
  - CI job measures startup time
  - Fails build if startup > 200ms
  - Reports timing in CI output

### Phase 2: Core Operations - 7 points

#### 67-7: Migrate sprint/cli.py to Click
- **Points:** 2
- **Priority:** P2
- **Status:** backlog
- **Workflow:** tdd
- **Description:** Convert existing argparse-based sprint/cli.py to Click decorators. Integrate with main CLI entry point.
- **Acceptance Criteria:**
  - sprint commands use @click.command() decorators
  - Registered with main pf group
  - All existing functionality preserved
  - `pf sprint status` and `pf sprint backlog` work

#### 67-8: Implement `pf workflow handoff` command
- **Points:** 2
- **Priority:** P2
- **Status:** backlog
- **Workflow:** tdd
- **Description:** Create `handoff` command that emits CYCLIST handoff markers. Replaces handoff-marker.sh.
- **Acceptance Criteria:**
  - `python -m pennyfarthing_scripts.cli workflow handoff <agent>` emits marker
  - Output format matches handoff-marker.sh exactly
  - Exit code 0 success

#### 67-9: Implement `pf sprint story` command
- **Points:** 1
- **Priority:** P2
- **Status:** backlog
- **Workflow:** tdd
- **Description:** Add `story <id>` command to get story details by ID. Returns story metadata, acceptance criteria, status.
- **Acceptance Criteria:**
  - `pf sprint story 67-1` returns story details
  - `--json` flag for structured output
  - Exit code 0 found, 1 not found

#### 67-10: Integration tests for bash/Python parity
- **Points:** 2
- **Priority:** P2
- **Status:** backlog
- **Workflow:** tdd
- **Description:** Create integration tests that run both bash and Python versions of migrated commands and compare output for parity.
- **Acceptance Criteria:**
  - Test suite covers all Phase 1 commands
  - Compares bash vs Python output
  - Fails if outputs differ (excluding timestamps)
  - Runs in CI

## Success Criteria

- Zero path-related errors in agent sessions
- All Phase 1 commands working and tested
- Startup time < 200ms verified in CI
- Bash scripts preserved for fallback during migration
