# Story 91-12: Agent Definition Structural Validation

**Story:** 91-12
**Jira:** PROJ-14710
**Epic:** epic-91 (Cross-File Reference & Schema Validation Pipeline)
**Points:** 5
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/91-12-agent-definition-validation
**Assigned:** K. Avery

## Context

Add `pf validate agent` subcommand to validate 18 agent definition files. Layer 2 schema validation within epic-91's validation pyramid.

**Story Context:** `sprint/context/context-story-91-12.md`
**Epic Context:** `sprint/context/context-epic-91.md`

## Acceptance Criteria

- [ ] `pf validate agent` validates all agent definition files in `pennyfarthing-dist/agents/`
- [ ] Main agents checked for required sections: `<role>`, `<critical>`, `<helpers>`, `<skills>`
- [ ] Subagents checked for YAML frontmatter with required fields: name, description, tools, model
- [ ] Model values validated: haiku/sonnet/opus for main agents, haiku-only for subagents
- [ ] Subagent references in helpers tables cross-checked against actual agent files (warnings)
- [ ] `pf validate` (no args) includes agent validation
- [ ] `--strict` promotes warnings to errors
- [ ] README.md excluded from validation
- [ ] Zero false positives on current develop branch
- [ ] Tests cover all error and warning cases

## Work Log

### Setup
- Session created
- Branch: `feat/91-12-agent-definition-validation` (pennyfarthing)
- Story context: `sprint/context/context-story-91-12.md`

### Handoff: SM → TEA
- Story setup complete
- Story context written with Architect consultation
- Jira claimed, branch created
- TDD workflow: TEA designs tests first (red phase)
- Next: TEA writes failing tests for agent definition validator

## TEA Assessment

**Tests Required:** Yes
**Reason:** 5-point TDD story — full test coverage before implementation

**Test Files:**
- `tests/python/test_agent_validator.py` — 39 failing tests covering all 10 ACs

**Tests Written:** 39 tests covering 10 ACs
**Status:** RED (all 39 failing — 37 NotImplementedError, 2 AssertionError on CLI registration)

**Test Breakdown by AC:**

| AC | Tests | What |
|----|-------|------|
| AC1: Discovery/classification | 4 | File discovery, main vs subagent classification, report contract |
| AC2: Main agent required sections | 6 | role, critical, helpers, skills, multiple-missing |
| AC3: Subagent frontmatter | 6 | name, description, tools, model, output section |
| AC4: Model validation | 5 | Valid model, invalid model, case insensitivity, subagent haiku-only |
| AC5: Subagent references | 3 | Valid ref, invalid ref, built-in (Explore) whitelist |
| AC6: CLI registration | 2 | VALIDATORS dict contains "agent", correct module path |
| AC7: Strict mode | 2 | Warning in normal mode, error in strict mode |
| AC8: README exclusion | 2 | Skipped in classification, no impact on report |
| AC9: Real agent files | 2 | Zero errors, all 17 files counted (integration) |
| AC10: Warnings/edge cases | 7 | on-activation, exit, exit-sequence variant, arguments, report format |

**Module Stub:** `pennyfarthing_scripts/validate/adapters/agent.py` — 4 functions raising NotImplementedError

**Public API for Dev to implement:**
- `classify_agent_files(agents_dir) → (main, sub, skipped)`
- `validate_main_agent(path, agents_dir) → (errors, warnings)`
- `validate_subagent(path) → (errors, warnings)`
- `run(root, fix, strict) → ValidateReport`

**Commit:** `e74eda922` — test + stub on `feat/91-12-agent-definition-validation`

**Handoff:** To Dev (White Rabbit) for implementation

### Handoff: TEA → Dev
- 39 failing tests written covering all 10 ACs
- Module stub in place with 4 public functions
- RED state confirmed — all tests fail on NotImplementedError or AssertionError
- Dev implements: classify_agent_files, validate_main_agent, validate_subagent, run
- Dev also registers "agent" in VALIDATORS dict in cli.py

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/validate/adapters/agent.py` — Full validator implementation (240 lines)
- `pennyfarthing_scripts/validate/cli.py` — Register agent adapter, add CLI subcommand

**Tests:** 39/39 passing (GREEN)
**PR:** #794 — feat(91-12): agent definition structural validation
**Branch:** feat/91-12-agent-definition-validation (pushed)

**Implementation Details:**
- `classify_agent_files()` — YAML frontmatter detection to distinguish main/sub, README skipped
- `validate_main_agent()` — regex tag detection, model extraction from helpers, subagent ref checking with builtin whitelist
- `validate_subagent()` — YAML frontmatter parsing, required fields, haiku-only model enforcement
- `run()` — orchestrator with [ERROR]/[WARN] prefixed details, strict mode promotes warnings

**Real agent files:** 17/17 pass, 0 warnings, 0 errors

**Handoff:** To Reviewer for code review

### Handoff: Dev → Reviewer
- 39/39 tests passing (GREEN)
- PR #794 created targeting develop
- 2 files changed: agent.py (240 lines), cli.py (+12 lines)
- Zero false positives on 17 real agent files
- Ready for code review

## Reviewer Assessment

**Verdict:** APPROVED

| Severity | Observation | Location |
|----------|------------|----------|
| [VERIFIED] | Tag regex scoping limits false positives — only runs against extracted `<helpers>` section | `agent.py:112-140` |
| [VERIFIED] | Frontmatter classifier sound — 10 main, 7 sub, 1 README correctly classified | `agent.py:62-85` |
| [VERIFIED] | YAML parsing safe — `yaml.safe_load()`, catches `YAMLError`, no injection risk | `agent.py:36-47` |
| [VERIFIED] | Data flow clean — CLI → importlib → run() → classify → validate → ValidateReport | `cli.py:26-32`, `agent.py:191-239` |
| [VERIFIED] | Error handling robust — missing dir check, YAML errors caught, regex non-matches handled | `agent.py:196-199` |
| [VERIFIED] | Test quality excellent — 39 tests, 976 lines (4:1 ratio), integration test against real files | `test_agent_validator.py` |
| [VERIFIED] | CLI integration clean — minimal changes, follows sprint/schema pattern exactly | `cli.py:22,121-128` |
| [LOW] | Typo in warning message: double negative "but no matching agent file not found" | `agent.py:139` |
| [LOW] | Header row filter only handles "Subagent" header name — works today, fragile for future | `agent.py:133` |
| [VERIFIED] | `fix` param accepted but unused — consistent with adapter interface contract | `agent.py:191` |

**Data flow traced:** `pf validate agent` → Click CLI → `_run_validator("agent")` → `importlib` → `run(root)` → classifies files → validates each → returns `ValidateReport` → colored output → exit code
**Pattern observed:** Clean adapter pattern matching sprint/schema validators at `cli.py:19-23`
**Error handling:** Missing dir returns early report (agent.py:196-199), YAML errors silently return empty (agent.py:44-47), regex non-matches return None
**Security:** yaml.safe_load (not yaml.load), no user-supplied paths beyond project root

**Handoff:** To SM (Mad Hatter) for finish-story

### Handoff: Reviewer → SM
- Verdict: APPROVED
- PR #794 has auto-merge enabled
- Ready for SM finish-story handoff
- Session and history updated

## Phase History

| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-10T14:00:00Z | 2026-02-10T14:05:00Z | 5m |
| red | 2026-02-10T14:05:00Z | 2026-02-10T14:10:00Z | 5m |
| green | 2026-02-10T14:10:00Z | 2026-02-10T14:20:00Z | 10m |
| review | 2026-02-10T14:20:00Z | 2026-02-10T14:31:46Z | 11m |

## Handoff History

| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| setup (sm) | red (tea) | manual | PASSED | 2026-02-10T14:05:00Z |
| red (tea) | green (dev) | tests_fail | PASSED | 2026-02-10T14:10:00Z |
| green (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-10T14:20:00Z |
| review (reviewer) | finish (sm) | approval | PASSED | 2026-02-10T14:31:46Z |
