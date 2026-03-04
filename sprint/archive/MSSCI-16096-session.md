# Story 139-1: File-Overlap Independence Check

**Status:** in-progress
**Phase:** finish
**Workflow:** trivial
**Jira:** MSSCI-16096
**Repos:** orchestrator,pennyfarthing
**Branch:** feat/139-1-file-overlap-independence-check

## Story Context

Epic 139 — Pre-Fan-Out Safety: Developer is warned before fan-out if two units would touch the same file — preventing the worst failure mode of parallel work.

Story 139-1 is the first story in this epic. It focuses on implementing a File-Overlap Independence Check, which is a foundational capability for detecting when multiple fanout units would modify the same files.

**Points:** 1
**Priority:** P1
**Type:** Feature

## Technical Approach

This story establishes the core mechanism for checking file overlaps between units that would execute in parallel during a fan-out operation. This is critical infrastructure for the Pre-Fan-Out Safety epic to prevent concurrent modifications to the same files.

## Acceptance Criteria

- File overlap detection mechanism is implemented
- Independence check can identify conflicts between fanout units
- System prevents fan-out when conflicts would occur

## SM Assessment

**Routing:** Trivial workflow (1pt feature) → Dev (Toby Ziegler)
**Jira:** MSSCI-16096 — claiming deferred to Dev phase
**Context:** First story in Epic 139 (Pre-Fan-Out Safety). Establishes file-overlap detection to prevent concurrent modifications during fan-out. Straightforward 1-pointer — implement the check, no TDD ceremony needed.
**Blockers:** None identified.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/preflight/independence.py` — Core check_independence() function, JSON/session parsing, path normalization
- `pennyfarthing-dist/src/pf/preflight/cli.py` — Wired `independence` subcommand into preflight CLI
- `pennyfarthing-dist/gates/independence-check.md` — Gate definition for batch workflow decompose→fan-out transition
- `pennyfarthing-dist/src/pf/tests/test_independence.py` — 17 tests: core logic, JSON parsing, CLI integration

**Tests:** 17/17 passing (GREEN)
**Branch:** feat/139-1-file-overlap-independence-check (pushed)

**Handoff:** To Reviewer for code review

## Delivery Findings

<!-- delivery-findings-start -->
### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): Dead import `sys` in `independence.py:16`. Affects `pennyfarthing-dist/src/pf/preflight/independence.py` (remove unused import). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `parse_units_from_session()` at `independence.py:168-199` is dead code — not wired to CLI, not tested. Affects `pennyfarthing-dist/src/pf/preflight/independence.py` (remove or wire into CLI with `--session` flag). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Path normalization at `independence.py:202-208` could be hardened for trailing slashes, double slashes, `..` components. Affects `pennyfarthing-dist/src/pf/preflight/independence.py` (use `os.path.normpath` or `PurePosixPath`). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** JSON string (CLI arg/file/stdin) → `json.loads()` → `UnitDefinition.from_dict()` → `check_independence()` string comparison → `IndependenceResult.to_dict()` → JSON stdout. Safe — no file system ops on unit file paths.
**Pattern observed:** Follows `finish.py` preflight pattern exactly — dataclasses, structured result, `to_dict()`, CLI registration. Consistent at `independence.py:22-78` and `cli.py:88-142`.
**Error handling:** All parse failures caught at `cli.py:123-127` (JSONDecodeError, ValueError, KeyError). Returns structured error JSON + exit 1.
**Security:** No injection surface — input is JSON-parsed strings compared to other strings. `--file` reads arbitrary paths but that's expected CLI behavior.
**Tests:** 17/17 — good coverage of core logic, edge cases, parsing, CLI integration. Two Medium gaps (duplicate-in-unit false positive, `parse_units_from_session` untested) acceptable for 1pt MVP.
**Handoff:** To SM for finish-story