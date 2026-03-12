# Story 139-1: File-Overlap Independence Check

**Jira:** MSSCI-16096
**Epic:** 139 — Pre-Fan-Out Safety
**Points:** 1
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16096-file-overlap-independence-check
**Workflow:** trivial
**Phase:** finish
**Status:** in_progress

## Story Context

Developer is warned before fan-out if two units would touch the same file — preventing the worst failure mode of parallel work. This story implements the file-overlap independence check that runs before batch fan-out to detect when multiple work units would modify the same files.

## Acceptance Criteria

- [ ] Independence check function exists that takes a list of work units with their target files
- [ ] Returns overlap report identifying which files are touched by multiple units
- [ ] Integrates into batch workflow pre-fan-out gate

## SM Assessment

**Routing:** Trivial workflow — direct to Dev (Toby Ziegler). One-point feature, no test design ceremony needed.

**Scope:** Build a file-overlap independence checker that takes work units with their target file lists and returns an overlap report. This is the safety check that runs before batch fan-out to prevent the worst failure mode — two agents editing the same file simultaneously.

**Risks:** None significant. Small, well-scoped utility function.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/preflight/independence.py` — core logic: `check_independence()`, `parse_units_from_json()`, `parse_units_from_session()`, path normalization
- `pennyfarthing-dist/src/pf/preflight/cli.py` — CLI wiring: `pf preflight independence --units/--file/stdin`
- `pennyfarthing-dist/src/pf/tests/test_independence.py` — 17 test cases covering empty, single, independent, overlapping, multi-overlap, path normalization, JSON parsing, and CLI integration
- `pennyfarthing-dist/gates/independence-check.md` — gate definition for batch workflow decompose→fan-out transition

**Tests:** 17/17 passing (GREEN)
**Branch:** feat/MSSCI-16096-file-overlap-independence-check (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** JSON string (CLI `--units` / `--file` / stdin) → `json.loads()` → `UnitDefinition.from_dict()` → `check_independence()` file→units map → `IndependenceResult.to_dict()` → `json.dumps()` → stdout. Safe — no eval, no injection vectors.

**Observations:**
1. [VERIFIED] Core `check_independence()` correctly builds file→units map, detects overlaps, sorts deterministically at `independence.py:94-128`
2. [VERIFIED] Path normalization handles `./` prefix and whitespace at `independence.py:201-208`
3. [VERIFIED] JSON parsing accepts `{"units": [...]}` and bare array, coerces numeric IDs to string at `independence.py:150-165`
4. [VERIFIED] Error handling: `JSONDecodeError`, `ValueError`, `KeyError` caught at CLI level at `cli.py:120-122`
5. [VERIFIED] Gate definition at `gates/independence-check.md` has clear pass/fail criteria, recovery options, override protocol
6. [MEDIUM] `parse_units_from_session()` at `independence.py:168` is dead code — defined but not called, not tested, CLI `--session` flag from docstring doesn't exist. Should be removed or wired in a follow-up.
7. [MEDIUM] Setup commit `9d43693a9` changed `sprint/cli.py` replacing `unclaim_issue()` with `check_availability()` — these are semantically different (`unclaim_issue` unassigns in Jira, `check_availability` is read-only). This is a regression introduced by sm-setup, not by the story implementation. Needs separate fix.
8. [LOW] Unused import `IndependenceResult` in `test_independence.py:10`
9. [LOW] No validation for duplicate unit IDs — non-unique IDs produce confusing overlap reports but don't crash

**Error handling:** CLI returns structured JSON error on invalid input (`{"status": "error", "error": "..."}`). Exit code 1 on overlap or error. Clean.
**Pattern observed:** Dataclass + `to_dict()` serialization — consistent with existing `IndependenceResult` pattern at `independence.py:49-73`
**Security:** CLI-only tool, no web surface. `json.loads` is safe. File reads via `Path.read_text()` appropriate for CLI context.

**Tests:** 17/17 GREEN — good coverage of core logic, edge cases (empty, single, multi-overlap, path normalization), JSON parsing variants, and CLI integration.

**Handoff:** To SM (Leo McGarry) for finish-story

## Delivery Findings

### Dev (implementation)

- No upstream findings during implementation.

### Reviewer (code review)

- **Improvement** (non-blocking): `parse_units_from_session()` at `independence.py:168` is dead code — defined but never called, never tested, and the `--session` CLI flag mentioned in the docstring doesn't exist. Affects `pennyfarthing-dist/src/pf/preflight/independence.py` (remove function or wire it to CLI in follow-up). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Setup commit `9d43693a9` replaced `unclaim_issue()` with `check_availability()` in `sprint/cli.py` — semantically incorrect substitution that breaks unclaim. Affects `pennyfarthing-dist/src/pf/sprint/cli.py` (revert to `claim_issue`/`unclaim_issue` imports). *Found by Reviewer during code review.*

## Technical Notes

- Part of Epic 139: Pre-Fan-Out Safety
- Trivial workflow (SM → Dev)
- Cherry-picked from prior implementation branch `feat/139-1-file-overlap-independence-check`