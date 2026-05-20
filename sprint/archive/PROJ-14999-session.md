# Story 105-1: Create handoff-cli.sh with resolve-gate and complete-phase

**Story ID:** 105-1
**Epic:** 105 — Script-First Handoff
**Jira:** PROJ-14999
**Points:** 3
**Workflow:** tdd
**Phase:** setup
**Phase Started:** 2026-02-15T07:52:25Z
**Repos:** pennyfarthing
**Branch:** feature/105-1-handoff-cli-script

## Acceptance Criteria

- [ ] `handoff-cli.sh resolve-gate` reads workflow YAML, finds current phase gate, checks assessment, returns structured RESOLVE_RESULT YAML
- [ ] `handoff-cli.sh complete-phase` atomically updates session file (temp+mv) with phase transition, timestamps, and history tables
- [ ] Script uses zsh shebang (`#!/usr/bin/env zsh`)
- [ ] Script stdout is the only communication channel — no side-channel files
- [ ] Exit codes: 0 = ready/skip, 1 = blocked
- [ ] All YAML parsing via yq
- [ ] Session parsing via grep/sed for markdown

## Technical Context

**File to create:** `pennyfarthing-dist/scripts/core/handoff-cli.sh`

**Subcommand: resolve-gate**
- Input: `handoff-cli.sh resolve-gate <story-id> <workflow> <current-phase>`
- Finds project root via find-root.sh
- Reads workflow YAML at `.pennyfarthing/workflows/{workflow}/workflow.yaml`
- Finds current phase, extracts gate.type (and later gate.file)
- If gate.type == manual → status: skip
- Checks session for `## Assessment` heading → if missing, status: blocked
- Returns RESOLVE_RESULT YAML struct

**Subcommand: complete-phase**
- Input: `handoff-cli.sh complete-phase <story-id> <workflow> <from-phase> <to-phase> <gate-type>`
- Reads session, creates temp copy
- Updates Phase line, Phase Started timestamp
- Fills in Ended/Duration for current phase in Phase History
- Adds new row for next phase
- Adds row to Handoff History
- Atomic mv temp over original

**Output contracts** — see epic context for RESOLVE_RESULT and COMPLETE_RESULT YAML schemas.

**Dependencies:**
- find-root.sh (existing)
- phase-owner.sh (existing)
- handoff-marker.sh (unchanged)
- yq v4

**Existing scripts for reference:**
- `pennyfarthing-dist/scripts/core/handoff-marker.sh`
- `pennyfarthing-dist/scripts/core/find-root.sh`
- `pennyfarthing-dist/scripts/workflow/phase-owner.sh`

## TEA Assessment

**Tests Required:** Yes
**Implementation changed to Python:** User directed Python instead of bash.
The `pf handoff` CLI command group replaces the originally-planned `handoff-cli.sh`.
ACs adapted: zsh shebang → Python module, yq → PyYAML, grep/sed → Python regex.

**Test Files:**
- `pennyfarthing_scripts/tests/test_handoff_cli.py` — 53 pytest tests

**Tests Written:** 53 tests covering 7 ACs across 13 test classes
- resolve-gate: ready/blocked/skip/error paths, output contract, multi-workflow
- complete-phase: session updates, atomicity, output contract, errors
- CLI: command existence, YAML output format, exit codes
- Side-channel: no unexpected file creation

**Status:** RED (42 failing — NotImplementedError stubs, 11 passing — CLI help/mocks)

**Stubs Created:**
- `pennyfarthing_scripts/handoff/__init__.py`
- `pennyfarthing_scripts/handoff/cli.py` — Click command group registered in main CLI
- `pennyfarthing_scripts/handoff/resolve_gate.py` — function signature, raises NotImplementedError
- `pennyfarthing_scripts/handoff/complete_phase.py` — function signature, raises NotImplementedError

**Handoff:** To Dev (Jack Torrance) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/handoff/resolve_gate.py` — resolve-gate: reads workflow YAML, checks assessment, returns RESOLVE_RESULT
- `pennyfarthing_scripts/handoff/complete_phase.py` — complete-phase: atomic session update with phase transition, timestamps, history tables

**Tests:** 53/53 passing (GREEN)
**PR:** #904 — feat(105-1): implement handoff CLI resolve-gate and complete-phase
**Branch:** feature/105-1-handoff-cli-script (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `story_id` → session path construction → `Path.read_text()` → regex check (safe — internal CLI, no external input surface)
**Pattern observed:** Correct POSIX atomic write (mkstemp→close→write→rename) at `complete_phase.py:101-112`
**Error handling:** All failure paths return structured result dicts — `resolve_gate.py:45-66`, `complete_phase.py:48-53`
**Security:** `yaml.safe_load` everywhere, no shell execution, no network calls
**Observations:** 7 items checked (5 verified good, 1 low-severity, 1 data flow trace). No Critical/High issues.
**Handoff:** To SM for finish-story

## Workflow Tracking

**Phase:** finish
**Phase Started:** 2026-02-15T09:40:58Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-15T07:52:25Z | 2026-02-15T07:53:07Z | 42s |
| red | 2026-02-15T07:53:07Z | 2026-02-15T08:15:30Z | 22m 23s |
| green | 2026-02-15T08:15:30Z | 2026-02-15T08:30:45Z | 15m 15s |
| review | 2026-02-15T08:30:45Z | 2026-02-15T09:40:58Z | 70m 13s |

### Handoff History
| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| setup (sm) | red (tea) | - | PASSED | 2026-02-15T07:53:07Z |
| red (tea) | green (dev) | tests_fail | PASSED | 2026-02-15T08:15:30Z |
| green (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-15T08:30:45Z |
| review (reviewer) | finish (sm) | approval | PASSED | 2026-02-15T09:40:58Z |
