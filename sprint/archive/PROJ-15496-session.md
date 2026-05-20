# Story 126-8: Reduce doctor to ~10 health checks with --fix mode

**Jira:** PROJ-15496
**Points:** 3
**Status:** in_progress
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/PROJ-15496-reduce-doctor-health-checks
**Assigned:** keith.avery@slabgorb.io

---

## Context

Reduce doctor from 30 health checks to ~10 that reflect the simplified Python-first architecture. Add --fix flag that offers to repair problems instead of just reporting them.

### Acceptance Criteria

- Doctor reduced to ~10 relevant health checks
- --fix flag offers interactive repair for each failed check
- Checks cover Python install, Node packages, config, hooks, directories
- Removed checks for things that can no longer break

---

## Setup

Feature branch created: `feature/PROJ-15496-reduce-doctor-health-checks`

Workflow: TDD — write tests first, then implementation.

---

## SM Assessment

Story setup complete. Jira claimed (PROJ-15496, In Progress). Feature branch created from develop. Session file created with ACs.

TDD workflow: handoff to TEA (Igor) for red phase — write failing tests for the reduced doctor checks and --fix mode before implementation begins.

## TEA Assessment

**Tests Required:** Yes
**Reason:** New Python module with 10 health checks and --fix mode

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_doctor.py` — 45 tests across 7 test classes

**Stub Files:**
- `pennyfarthing-dist/src/pf/doctor/__init__.py` — module init
- `pennyfarthing-dist/src/pf/doctor/models.py` — CheckResult, DoctorReport dataclasses
- `pennyfarthing-dist/src/pf/doctor/checks.py` — 10 check function stubs + CHECKS registry
- `pennyfarthing-dist/src/pf/doctor/core.py` — run_doctor stub
- `pennyfarthing-dist/src/pf/doctor/cli.py` — Click command stub

**Tests Written:** 45 tests covering 4 ACs
- TestCheckRegistry (3): ~10 checks in CHECKS registry
- TestIndividualChecks (22): pass/fail for all 10 checks with healthy/broken projects
- TestFixMode (4): fix_fn attached to failures, --fix creates missing dirs/config
- TestRunDoctor (6): DoctorReport structure, success/fail based on project health
- TestCLI (6): --help, --fix, --json flags, exit codes, JSON output
- TestReduction (3): fewer than 15 checks, no legacy/cyclist checks
- TestCLIRegistration (2): doctor in _LAZY_COMMANDS

**Status:** RED (38 failing, 7 passing — failures are NotImplementedError stubs, not imports)

**Handoff:** To Ponder Stibbons (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/doctor/checks.py` — 10 check functions + CHECKS registry + fix helpers
- `pennyfarthing-dist/src/pf/doctor/core.py` — run_doctor with check dispatch and fix mode
- `pennyfarthing-dist/src/pf/doctor/cli.py` — Click command with --fix, --json, exit codes
- `pennyfarthing-dist/src/pf/cli.py` — registered doctor in _LAZY_COMMANDS

**Tests:** 45/45 passing (GREEN)
**Branch:** feature/PROJ-15496-reduce-doctor-health-checks

**Handoff:** To next phase (review)

## TEA Verify Assessment

**Tests:** 45/45 passing (GREEN confirmed)
**Verification:** Independent run, all 7 test classes pass
**AC Coverage:**
- AC1: TestCheckRegistry + TestReduction — 10 checks, < 15 total, no legacy/cyclist
- AC2: TestFixMode — fix_fn on failures, creates .pennyfarthing/ and config
- AC3: TestIndividualChecks — all 10 checks verified pass/fail
- AC4: TestReduction — strictly fewer than old TS doctor

**Handoff:** To Granny Weatherwax (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** CLI doctor() → get_project_root() → run_doctor(root) → CHECKS dispatch → CheckResult → DoctorReport → JSON/text output + exit code (safe, linear)
**Pattern observed:** Consistent CheckResult return pattern across all 10 checks at checks.py:24-177
**Error handling:** YAML errors caught at checks.py:91, JSON errors at checks.py:103, missing paths return fail/warn appropriately
**Observations:**
- [MEDIUM] _CHECK_FNS dict must stay manually in sync with CHECKS list (core.py:26-37) — maintenance risk, not current bug
- [LOW] fix_fn return value ignored at core.py:31 — fixed count increments regardless of success
- [VERIFIED] Fix ordering correct, CLI wiring correct, security clean, no forbidden patterns

**Handoff:** To Captain Carrot (SM) for finish-story