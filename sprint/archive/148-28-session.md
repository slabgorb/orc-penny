---
story_id: "148-28"
jira_key: ""
epic: "MSSCI-16421"
workflow: "trivial"
---
# Story 148-28: Peloton teammates must be pre-primed

## Story Details
- **ID:** 148-28
- **Workflow:** trivial
- **Branch:** feat/148-28-peloton-pre-prime
- **Repos:** pennyfarthing

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-18T06:50:19Z

## Context

Peloton teammates are currently spawned with minimal instructional prompts ("Load agent with /pf-dev"). Instead, the full agent prompt from `pf agent start <role>` should be injected into the TeamCreate spawn prompt so teammates are pre-primed with their persona, agent definition, and session context before they begin work.

## Acceptance Criteria
- [x] Peloton spawn captures `pf agent start <role>` output and injects it into teammate prompt
- [x] Teammates activate with full agent context (persona, definition, session file)
- [x] Test coverage for prompt injection into TeamCreate

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/peloton/live.py` - Changed `--minimal` to `--no-register --quiet` in `pf agent start` call; bumped timeout 15s→30s
- `pennyfarthing-dist/src/pf/tests/test_peloton_pre_prime.py` - 6 tests covering args, injection, fallback, partial failure

**Tests:** 6/6 passing (GREEN)
**Branch:** feat/148-28-peloton-pre-prime (pushed)

**Handoff:** To Reviewer for code review

## Design Deviations

### Dev (implementation)
- No deviations from spec.

## Delivery Findings

### Dev (implementation)
- No upstream findings during implementation.

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes (direct) | clean | none | confirmed 0 |
| 2 | reviewer-edge-hunter | Yes | findings | 4 | confirmed 2, dismissed 2 |
| 3 | reviewer-silent-failure-hunter | Yes (direct) | findings | 1 | confirmed 1 |
| 4 | reviewer-test-analyzer | Yes (direct) | findings | 2 | confirmed 1, dismissed 1 |
| 5 | reviewer-comment-analyzer | Yes (direct) | findings | 1 | confirmed 1 |
| 6 | reviewer-type-design | Yes (direct) | findings | 1 | dismissed 1 |
| 7 | reviewer-security | Yes (direct) | clean | none | confirmed 0 |
| 8 | reviewer-simplifier | Yes (direct) | clean | none | confirmed 0 |
| 9 | reviewer-rule-checker | Yes (direct) | findings | 3 | confirmed 3 |

Note: Subagents 1, 3-9 returned persistent API 529 overload errors across 3+ retry attempts. Analysis performed directly by reviewer from diff examination, test runs, and code reading. Edge-hunter (2) succeeded on retry 3 and findings are confirmed.

**All received:** Yes
**Total findings:** 5 confirmed, 3 dismissed (with rationale), 0 deferred

## Reviewer Assessment

**Verdict:** APPROVED

**Fixes applied by reviewer (minor violations, fixed in-phase):**
- Added `import logging` + `logger = logging.getLogger(__name__)` to `live.py`
- Changed `except Exception: pass` → `except Exception as e: logger.debug(...)` with explanatory comment
- Removed unused `import json` from test file

**Files reviewed:**
- `pennyfarthing-dist/src/pf/peloton/live.py` — core change: `--minimal` → `--no-register --quiet`, timeout 15→30s
- `pennyfarthing-dist/src/pf/tests/test_peloton_pre_prime.py` — 6 new tests

### Preflight
- Tests: 6/6 passing ✓
- Direct run confirmed (API overload prevented subagent; confirmed via Bash tool)

### Specialist Findings

[EDGE] Edge hunter found 2 confirmed issues: (1) `except Exception: pass` silently swallows FileNotFoundError/TimeoutExpired with zero diagnostic output — HIGH confidence. (2) No size cap on primer output — MEDIUM confidence, low practical risk. Also found 2 dismissed: empty agents list (guarded upstream), sequential timeout (acceptable design). **RC-1 applied: logging added.**

[SILENT] Silent failure hunter (direct analysis): `except Exception: pass` at live.py:300 is a silent swallower. No logging means pf not-in-PATH failures are invisible. **RC-1 applied: debug logging added with explanatory comment.**

[TEST] Test analyzer (direct analysis): `import json` at test_peloton_pre_prime.py:13 unused — Rule #10 violation. No tests for exception-raising paths (TimeoutExpired, FileNotFoundError) — dismissed as fallback behavior is covered via returncode path. **RC-2 applied: unused import removed.**

[DOC] Comment analyzer (direct analysis): `except Exception: pass` had no comment explaining intentional fallback — Rule violation. SOUL #11 citation accurate. Docstring updated correctly for layout param and return value. **RC-1 applied: comment added.**

[TYPE] Type design (direct analysis): `VALID_LAYOUTS` as mutable set vs frozenset — trivial, dismissed. `layout: str | None` vs `Literal[...]` acceptable given runtime validation against VALID_LAYOUTS. All public functions annotated. **No action required.**

[SEC] Security (direct analysis): `shell=False` (list form) throughout — no injection risk. Agent primer is trusted internal content. No user-controlled input at boundaries. **Clean.**

[SIMPLE] Simplifier (direct analysis): Two loops over agents is readable. String concatenation with += for small N is fine. No unnecessary abstraction. **Clean.**

### Preflight
- Working tree: clean (untracked: `.claude/`, `test_peloton_max_panes.py` — not part of this story) ✓
- Branch: `feat/148-28-peloton-pre-prime` pushed ✓

### Rule Compliance

**Rule #1 — Silent exception swallowing (VIOLATION):**
`live.py:297` — `except Exception: pass` swallows `FileNotFoundError` (pf not in PATH), `subprocess.TimeoutExpired`, `PermissionError`, and all other exceptions with zero logging. The fallback to instructional text is correct design (best-effort priming), but complete silence means if priming silently fails for all agents, the caller gets `success=True` with no indication anything went wrong. Debug-level logging at minimum is required.

**Rule #4 — Logging on error paths (VIOLATION):**
The `except Exception` block is an error/exception path with no `logger.debug()`, `logger.warning()`, or any diagnostic output.

**Rule #10 — Import hygiene (VIOLATION):**
`test_peloton_pre_prime.py:13` — `import json` is unused. Not referenced anywhere in the 185-line file.

**Rules #2, 5, 7, 8, 9, 11, 12, 13:** Pass.

### Edge Cases
**Confirmed:**
- **Silent degradation with non-existent project_root:** If `project_root` doesn't exist on disk, `subprocess.run(cwd=...)` raises `FileNotFoundError` — caught silently, all agents fall back to instructional text, `success=True` returned with no warning.
- **Unbounded primer output:** No size cap on `prime_result.stdout`. A verbose `pf agent start` could produce large output injected verbatim into the prompt. Low practical risk (prime output is bounded by context), but no defensive truncation.

**Dismissed:**
- Empty agents list: `_extract_agents` returns `None` for empty results, caught upstream. Not a real edge case.
- Sequential 30s timeout per agent: Best-effort design, acceptable trade-off for a non-critical enhancement.

### Test Coverage
**Confirmed:**
- `import json` at line 13 — unused import, clear Rule #10 violation.

**Dismissed:**
- No test for `subprocess.TimeoutExpired`/`FileNotFoundError` exception raising: The fallback behavior is functionally identical to non-zero returncode (which IS tested). The exception path produces the same result. Not blocking.

### Type Design
**Dismissed:**
- `VALID_LAYOUTS = {"horizontal", "vertical", "grid"}` as mutable set vs `frozenset`: Trivial, module-level constant. Not blocking.

### Security
Clean. `shell=False` (list form) prevents injection. Agent primer is internal content from trusted `pf agent start`. No user-controlled input.

### Simplicity
Clean. Two-loop structure is readable. String concatenation for small N is fine.

### Required Changes

**RC-1 (Rule #1, #4): Add debug logging to exception handler**
In `live.py` around line 297:
```python
        except Exception as e:
            logger.debug("pf agent start failed for %s: %s", agent, e)
```
Also ensure `import logging` and `logger = logging.getLogger(__name__)` exist in the module.

**RC-2 (Rule #1): Add comment explaining intentional fallback**
```python
        except Exception as e:  # Pre-priming is best-effort; fall back to instructional text
            logger.debug("pf agent start failed for %s: %s", agent, e)
```

**RC-3 (Rule #10): Remove unused import**
In `test_peloton_pre_prime.py`, remove line 13: `import json`

### Summary

The core change is correct and minimal — the 2-flag change from `--minimal` to `--no-register --quiet` is exactly right. Tests cover the happy path, fallback, and partial failure well. Three quick fixes needed before approval: add debug logging + comment to the exception handler, and remove the unused import. None of these require architectural changes.

### Delivery Findings

#### Reviewer (review)
- **Gap** (non-blocking): `live.py` has no `import logging` and no module-level logger. When RC-1 is applied, the logger must be added. Check if the module already imports logging before adding.
  Affects `pennyfarthing-dist/src/pf/peloton/live.py` (add `import logging; logger = logging.getLogger(__name__)` at top).
  *Found by Reviewer during review.*