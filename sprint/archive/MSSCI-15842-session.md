# Story 136-2: WheelHub pip-install support — remove monorepo path assumptions

**Story ID:** 136-2
**Jira:** MSSCI-15842
**Epic:** 136 (MSSCI-15839)
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/136-2/wheelhub-pip-install
**Assignee:** keithavery

---
## Assessments

### TEA Assessment

**Tests Required:** Yes
**Reason:** Core infrastructure change — path resolution affects every BikeRack launch in both monorepo and pip-installed environments

**Test Files:**
- `tests/python/test_wheelhub_discovery.py` — 13 tests for `_find_wheelhub_entry()` multi-strategy discovery (AC1, AC2, AC4)
- `packages/core/src/server/pennyfarthing-resolution.test.ts` — 5 tests for `resolvePackageRoot()` and `resolveContextScript()` (AC3, AC5)

**Tests Written:** 18 tests covering 4 ACs (AC1: 5 monorepo, AC2: 3 pip, AC4: 3 degradation + 2 contract, AC3+AC5: 5 TypeScript)
**Status:** RED (13 Python failing — NotImplementedError from stub, 5 TypeScript failing — Error('Not implemented') from stubs)

**Stubs Created:**
- `pennyfarthing-dist/src/pf/bikerack/launcher.py` — `_find_wheelhub_entry(start_path=None)` stub with multi-strategy docstring
- `packages/core/src/server/pennyfarthing.ts` — `resolvePackageRoot()` stub
- `packages/core/src/server/api/context.ts` — `resolveContextScript()` stub

**Key design decisions:**
- `_find_wheelhub_entry()` takes optional `start_path` for testability (defaults to `__file__`)
- Walk-up discovery (not hardcoded depth) so it works at any directory depth
- `resolveContextScript()` returns `{path, isPython, paths[]}` for diagnostics
- `start_wheelhub()` AC4 test asserts result-dict pattern, not exception propagation

**Handoff:** To Dev (Korben Dallas) for implementation

## Delivery Findings

### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- No upstream findings during implementation.

### Dev (review fix)
- No upstream findings during review fix.

---

### Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/bikerack/launcher.py` - Implemented `_find_wheelhub_entry()` with 3-strategy discovery (env var → monorepo walk-up → pip _dist); wrapped `start_wheelhub()` with FileNotFoundError → result dict
- `packages/core/src/server/pennyfarthing.ts` - Implemented `resolvePackageRoot()` using `resolvePennyfarthingDist()` with `__dirname` fallback
- `packages/core/src/server/api/context.ts` - Implemented `resolveContextScript()` with pip site-packages candidates
- `packages/core/src/server/pennyfarthing-resolution.test.ts` - Aligned type annotation with actual return type

**Tests:** 18/18 passing (GREEN)
**Branch:** feature/136-2/wheelhub-pip-install (pushed)

**Handoff:** To next phase (review)

### TEA (test verification)
- No upstream findings during test verification.

---

### TEA Verify Assessment

**Verification Complete:** Yes
**Tests:** 18/18 passing (GREEN confirmed)
- Python: 13/13 (test_wheelhub_discovery.py)
- TypeScript: 5/5 (pennyfarthing-resolution.test.js)

**Implementation Review:** Clean. Strategies ordered correctly (env var → monorepo → pip). Fallback chains work. Error messages include paths. No debug code.

**Handoff:** To Zorg (Reviewer) for code review

### Reviewer (code review)
- **Gap** (blocking): `start_wheelhub()` return type changed to `Popen | dict` but 3 callers (`launch/cli.py:40`, `bikerack/cli.py:77`, `hooks/session_start.py:158`) still call `proc.pid` unconditionally — will crash with `AttributeError` on broken installs instead of descriptive `FileNotFoundError`. Affects `pennyfarthing-dist/src/pf/bikerack/launcher.py` (either revert to raising or update all callers). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `resolveContextScript()` duplicates `getContextUsage()` path logic without replacing it. Affects `packages/core/src/server/api/context.ts` (should eventually replace inline logic in `getContextUsage()`). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `resolvePackageRoot()` not used by internal callers — `PACKAGE_ROOT` const still referenced directly at lines 253, 322. Affects `packages/core/src/server/pennyfarthing.ts` (swap const usage to function call). *Found by Reviewer during code review.*

---

### Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | `start_wheelhub()` returns `dict` but 3 callers access `.pid` unconditionally — `AttributeError` regression on broken installs | `launcher.py:157`, `launch/cli.py:40`, `bikerack/cli.py:77`, `session_start.py:158` | Either revert `start_wheelhub()` to raising `FileNotFoundError` (callers already handle exceptions) OR update all 3 callers to check `isinstance(proc, dict)` before `.pid` |
| [MEDIUM] | `resolveContextScript()` not wired into `getContextUsage()` — duplicates inline logic | `context.ts:211` vs `context.ts:41-75` | Non-blocking — can wire in follow-up |
| [MEDIUM] | `resolvePackageRoot()` exported but `PACKAGE_ROOT` const still used internally | `pennyfarthing.ts:253,322` | Non-blocking — can swap in follow-up |
| [LOW] | Strategy 3 pip walk-up `__init__.py` check overly broad | `launcher.py:132` | Negligible real-world risk |

**Handoff:** Back to Korben Dallas for fix — `start_wheelhub()` caller wiring

---

### Dev Assessment (review fix)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/launch/cli.py` - Handle dict return from `start_wheelhub()`, echo error, return None tuple
- `pennyfarthing-dist/src/pf/bikerack/cli.py` - Handle dict return, echo error, sys.exit(1)
- `pennyfarthing-dist/src/pf/hooks/session_start.py` - Handle dict return, return None silently

**Tests:** 18/18 passing (GREEN)
**Branch:** feature/136-2/wheelhub-pip-install (pushed)

**Handoff:** To next phase (verify → review)

### TEA (test verification — post review fix)
- No upstream findings during test verification.

---

### TEA Verify Assessment (post review fix)

**Verification Complete:** Yes
**Tests:** 18/18 passing (GREEN confirmed)
- Python: 13/13 (test_wheelhub_discovery.py)
- TypeScript: 5/5 (pennyfarthing-resolution.test.ts)

**Review Fix Verification:** All 3 callers now guard against dict returns from `start_wheelhub()`:
- `launch/cli.py:40` — echoes error, returns `(None, None, False)` ✓
- `bikerack/cli.py:77` — echoes error, `sys.exit(1)` ✓
- `session_start.py:158` — returns `None` silently ✓

Each caller handles the error path appropriately for its context. Zorg's blocking [HIGH] issue is resolved.

**Handoff:** To Zorg (Reviewer) for re-review

### Reviewer (re-review)
- **Gap** (blocking): `_ensure_wheelhub()` in `launch/cli.py:42` returns `(None, None, False)` on error, but transitive callers `gui()` (line 93) and `tui()` (line 148) don't check for `None` port — `gui()` constructs `http://localhost:None/bikerack` and opens it in browser; `tui()` passes `None` port to TUI launcher. Fix: raise `RuntimeError` in `_ensure_wheelhub` instead of returning None tuple (callers already have try/except for RuntimeError). Affects `pennyfarthing-dist/src/pf/launch/cli.py` (change return to raise). *Found by Reviewer during code review.*

---

### Reviewer Assessment (re-review)

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | `_ensure_wheelhub()` returns `(None, None, False)` but callers `gui()` and `tui()` proceed to use `port=None` — `gui` opens `http://localhost:None/bikerack`, `tui` passes None port to launcher | `launch/cli.py:42` (return), `launch/cli.py:93` (gui caller), `launch/cli.py:148` (tui caller) | Change `_ensure_wheelhub` line 42 from `return None, None, False` to `raise RuntimeError(proc['error'])`. Add `RuntimeError` to tui's except clause at line 149. |
| [VERIFIED] | Direct callers of `start_wheelhub()` — all 3 properly guard with `isinstance(proc, dict)` | `launch/cli.py:40`, `bikerack/cli.py:77`, `session_start.py:158` | Previous [HIGH] resolved |
| [VERIFIED] | Walk-up discovery — 3-strategy resolution, env var precedence, depth-independent | `launcher.py:80-147` | Implementation matches test expectations |
| [VERIFIED] | Error messages include attempted paths for diagnostics | `launcher.py:142-147` | User-facing quality checked |
| [VERIFIED] | Test suite — 13 Python + 5 TypeScript covering all 4 ACs, no forbidden patterns | `test_wheelhub_discovery.py`, `pennyfarthing-resolution.test.ts` | 18/18 GREEN |
| [MEDIUM] | `resolveContextScript()` still not wired into `getContextUsage()` | `context.ts` | Non-blocking — unchanged from R1 |
| [MEDIUM] | `resolvePackageRoot()` still unused internally | `pennyfarthing.ts` | Non-blocking — unchanged from R1 |

**Handoff:** Back to Korben Dallas for fix — `_ensure_wheelhub` error propagation (1-2 line change)

### Dev (review fix 2)
- No upstream findings during review fix.

---

### Dev Assessment (review fix 2)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/launch/cli.py` - Changed `_ensure_wheelhub` to raise `RuntimeError` instead of returning `(None, None, False)` on error; added `RuntimeError` to `tui()` except clause

**Tests:** 18/18 passing (GREEN)
**Branch:** feature/136-2/wheelhub-pip-install (pushed)

**Handoff:** To next phase (verify → review)

### TEA (test verification — post review fix 2)
- No upstream findings during test verification.

---

### TEA Verify Assessment (post review fix 2)

**Verification Complete:** Yes
**Tests:** 18/18 passing (GREEN confirmed)
- Python: 13/13 (test_wheelhub_discovery.py)
- TypeScript: 5/5 (pennyfarthing-resolution.test.ts)

**Review Fix 2 Verification:** Zorg's [HIGH] resolved correctly:
- `_ensure_wheelhub()` now raises `RuntimeError` instead of returning `(None, None, False)` — no more None port propagation
- `gui()` already catches `(TimeoutError, RuntimeError)` at line 94 — handles the error and exits cleanly
- `tui()` except clause updated to `(TimeoutError, RuntimeError)` at line 148 — now also handles the error

**Handoff:** To Zorg (Reviewer) for re-review

### Reviewer (re-review 2)
- **Improvement** (non-blocking): `resolveContextScript()` duplicates `getContextUsage()` path logic without replacing it. Affects `packages/core/src/server/api/context.ts` (should eventually replace inline logic in `getContextUsage()`). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `resolvePackageRoot()` not used by internal callers — `PACKAGE_ROOT` const still referenced directly. Affects `packages/core/src/server/pennyfarthing.ts` (swap const usage to function call). *Found by Reviewer during code review.*

---

### Reviewer Assessment (re-review 2)

**Verdict:** APPROVED

**Data flow traced:** `FileNotFoundError` → `start_wheelhub()` dict → `_ensure_wheelhub()` `RuntimeError` → caught by `gui()` (line 93) and `tui()` (line 148) → stderr + `sys.exit(1)`. No None port leaks. Clean termination on all error paths.
**Pattern observed:** Raise-not-return at `launch/cli.py:41` — correct pattern for typed-return functions that can't satisfy their contract on error.
**Error handling:** All 5 callers handle errors appropriately for their context: `gui/tui` exit with message, `bikerack/cli` exits, `session_start` returns None silently.

| Severity | Observation | Location |
|----------|-------------|----------|
| [VERIFIED] | `_ensure_wheelhub` raises RuntimeError — gui/tui catch it cleanly | `launch/cli.py:41,93,148` |
| [VERIFIED] | Direct callers of `start_wheelhub()` — isinstance guard intact | `bikerack/cli.py:77`, `session_start.py:158` |
| [VERIFIED] | Walk-up discovery — 3-strategy, env var precedence, depth-independent | `launcher.py:80-147` |
| [VERIFIED] | Test suite — 18/18 GREEN, no forbidden patterns, tree clean | `test_wheelhub_discovery.py`, `pennyfarthing-resolution.test.ts` |
| [VERIFIED] | Error messages include attempted paths for user diagnostics | `launcher.py:142-147` |
| [MEDIUM] | `resolveContextScript()` not wired into `getContextUsage()` | `context.ts` |
| [MEDIUM] | `resolvePackageRoot()` unused internally | `pennyfarthing.ts` |

**Handoff:** To Ruby Rhod (SM) for finish-story## Impact Summary

**Upstream Effects:** 4 findings (2 Gap, 0 Conflict, 0 Question, 2 Improvement)
**Blocking:** 2 BLOCKING items — see below

**BLOCKING:**
- **Gap:** `start_wheelhub()` return type changed to `Popen | dict` but 3 callers (`launch/cli.py:40`, `bikerack/cli.py:77`, `hooks/session_start.py:158`) still call `proc.pid` unconditionally — will crash with `AttributeError` on broken installs instead of descriptive `FileNotFoundError`. Affects `pennyfarthing-dist/src/pf/bikerack/launcher.py`.
- **Gap:** `_ensure_wheelhub()` in `launch/cli.py:42` returns `(None, None, False)` on error, but transitive callers `gui()` (line 93) and `tui()` (line 148) don't check for `None` port — `gui()` constructs `http://localhost:None/bikerack` and opens it in browser; `tui()` passes `None` port to TUI launcher. Fix: raise `RuntimeError` in `_ensure_wheelhub` instead of returning None tuple (callers already have try/except for RuntimeError). Affects `pennyfarthing-dist/src/pf/launch/cli.py`.

- **Improvement:** `resolvePackageRoot()` not used by internal callers — `PACKAGE_ROOT` const still referenced directly at lines 253, 322. Affects `packages/core/src/server/pennyfarthing.ts`.
- **Improvement:** `resolvePackageRoot()` not used by internal callers — `PACKAGE_ROOT` const still referenced directly. Affects `packages/core/src/server/pennyfarthing.ts`.

