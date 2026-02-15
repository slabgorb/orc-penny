# Story 106-4: Gate file discovery and resolution

**Jira:** MSSCI-15007
**Epic:** 106 — Gate Files & First Migration
**Points:** 1
**Priority:** P1
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/106-4-gate-file-discovery
**Assigned:** K. Avery

---

## Context

Gate file resolution order: `.pennyfarthing/gates/{name}.md` (project-local) first, then `pennyfarthing-dist/gates/{name}.md` (built-in). Project-local overrides built-in. Non-existent file with no type fallback returns status:blocked.

Add `gates/` symlink to pennyfarthing init/update following existing symlink pattern.

## Acceptance Criteria

- [ ] `resolve_gate_file()` function resolves gate names to file paths
- [ ] Resolution order: `.pennyfarthing/gates/{name}.md` → `pennyfarthing-dist/gates/{name}.md`
- [ ] Non-existent gate file returns error/blocked status
- [ ] `gates/` symlink added to init/update commands following existing pattern
- [ ] Tests cover: found in local, found in built-in, not found, symlink resolution

## Technical Approach

### Files to Modify
| File | Change |
|------|--------|
| `pennyfarthing-dist/scripts/core/handoff-cli.sh` or new helper | Add `resolve_gate_file()` function |
| `packages/core/src/commands/init.ts` | Add `gates/` to symlink list |
| `packages/core/src/commands/update.ts` | Add `gates/` to symlink update |

### Resolution Logic
1. Strip `gates/` prefix from ref if present
2. Check `.pennyfarthing/gates/{name}.md` — return if exists
3. Check `pennyfarthing-dist/gates/{name}.md` — return if exists
4. Return error (no fallback)

### Corrected Files to Modify
| File | Change |
|------|--------|
| `pennyfarthing_scripts/handoff/gate_file.py` | Implement `resolve_gate_file()` (stub exists) |
| `packages/core/src/cli/utils/constants.ts` | Add `gates` to `DIRECTORY_SYMLINKS`, `ALL_SYMLINKS`, `MANAGED_PATHS` |

Note: init.ts and update.ts iterate `DIRECTORY_SYMLINKS` automatically — no direct edits needed there.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core discovery function needs thorough coverage

**Test Files:**
- `pennyfarthing_scripts/tests/test_gate_file_resolution.py` — 21 Python tests for `resolve_gate_file()`
- `packages/core/src/cli/utils/constants.test.ts` — 4 TypeScript tests for `gates` in symlink constants

**Tests Written:** 25 tests covering 5 ACs
- AC1: 6 tests — function resolves names to paths, returns required fields
- AC2: 4 tests — local overrides built-in, fallback to pennyfarthing-dist
- AC3: 5 tests — not-found handling, empty name, missing directories
- AC4: 4 tests — DIRECTORY_SYMLINKS, ALL_SYMLINKS, MANAGED_PATHS include gates
- AC5: 3 tests — symlink resolution, content readable through symlink
- Edge cases: 3 tests — `.md` suffix handling, path traversal rejection

**Status:** RED (all 25 failing — NotImplementedError + assertion failures)

**Implementation hints for Dev:**
- `resolve_gate_file()` stub is at `pennyfarthing_scripts/handoff/gate_file.py`
- Pattern matches existing `_find_workflow_yaml()` in resolve_gate.py
- `DIRECTORY_SYMLINKS` in constants.ts just needs `{ name: 'gates', link: '.pennyfarthing/gates' }`
- Tests handle `.md` suffix stripping — accept both `tests-pass` and `tests-pass.md`
- Tests reject path traversal (`../escape/tests-pass`) — validate gate name

**Handoff:** To Dev (Sergeant Carter) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/handoff/gate_file.py` — Implemented `resolve_gate_file()` with priority discovery, name sanitization, path traversal rejection
- `packages/core/src/cli/utils/constants.ts` — Added `gates` to `DIRECTORY_SYMLINKS`, `ALL_SYMLINKS`, `MANAGED_PATHS`

**Tests:** 25/25 passing (GREEN)
- 21 Python tests: all passing
- 4 TypeScript tests: all passing
- 53 existing handoff tests: no regressions
- 18 existing symlink tests: no regressions

**PR:** #910 — feat(106-4): gate file discovery and resolution
**Branch:** feature/106-4-gate-file-discovery (pushed)

**Handoff:** To Reviewer (General Burkhalter) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Tests verified:** 25/25 passing (21 Python + 4 TypeScript). 77 existing handoff tests pass — zero regressions. 2 pre-existing e2e failures (sidecar migration) confirmed on develop, not introduced by PR.

**Data flow traced:** `gate_ref` → `_sanitize_gate_name()` (strip prefix/suffix, reject traversal) → check local `.pennyfarthing/gates/` → check built-in `pennyfarthing-dist/gates/` → return result dict with resolved path or error.

**Observations:**

| Severity | Description | Location |
|----------|-------------|----------|
| [VERIFIED] | Priority discovery order local → built-in correct | `gate_file.py:45-47` |
| [VERIFIED] | Path traversal rejected | `gate_file.py:81` |
| [VERIFIED] | Constants follow alphabetical pattern, propagate automatically | `constants.ts:31,44,57` |
| [LOW] | `_sanitize_gate_name('.')` passes through — harmless | `gate_file.py:66-84` |
| [LOW] | Module docstring says "blocked" but returns "not_found" | `gate_file.py:8` |
| [LOW] | `_find_project_root()` duplicated with resolve_gate.py | `gate_file.py:99` |
| [MEDIUM] | Not yet wired into resolve_gate.py (expected per scope) | `resolve_gate.py:70` |

**Error handling:** Result objects returned, no exceptions thrown. Follows framework pattern.
**Security:** Path traversal blocked. No injection risk.

**Handoff:** To SM (Colonel Hogan) for finish-story

## Handoff Log

| Phase | Agent | Status |
|-------|-------|--------|
| setup | SM (Colonel Hogan) | complete |
| red | TEA (Major Hochstetter) | pending |
| green | Dev (Sergeant Carter) | pending |
| review | Reviewer (General Burkhalter) | pending |
| finish | SM (Colonel Hogan) | pending |