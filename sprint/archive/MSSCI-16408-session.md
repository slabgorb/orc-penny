---
story_id: "146-3"
jira_key: "MSSCI-16408"
epic: "MSSCI-16405"
workflow: "tdd"
---
# Story 146-3: Hook into story_finish pipeline — auto-trigger on completion

## Story Details
- **ID:** 146-3
- **Jira Key:** MSSCI-16408
- **Epic:** MSSCI-16405 (Demo Artifact Generator — Integration & Config)
- **Workflow:** tdd
- **Stack Parent:** none
- **Points:** 2
- **Priority:** p0

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-13T19:51:38Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-13T19:31:52Z | 2026-03-13T19:33:35Z | 1m 43s |
| red | 2026-03-13T19:33:35Z | 2026-03-13T19:39:53Z | 6m 18s |
| green | 2026-03-13T19:39:53Z | 2026-03-13T19:43:16Z | 3m 23s |
| spec-check | 2026-03-13T19:43:16Z | 2026-03-13T19:44:25Z | 1m 9s |
| verify | 2026-03-13T19:44:25Z | 2026-03-13T19:46:24Z | 1m 59s |
| review | 2026-03-13T19:46:24Z | 2026-03-13T19:50:55Z | 4m 31s |
| spec-reconcile | 2026-03-13T19:50:55Z | 2026-03-13T19:51:38Z | 43s |
| finish | 2026-03-13T19:51:38Z | - | - |

## Story Context

Hook into the `story_finish` pipeline to auto-trigger demo artifact generation when a story completes. This integrates the demo generator (146-1, 146-2) into the standard story completion workflow.

### Acceptance Criteria
1. Create a `story_finish` hook that detects story completion
2. Invoke demo generation with correct configuration
3. Handle errors gracefully without blocking story completion
4. Add test coverage for hook invocation

### Dependencies
- **146-1** (pf demo generate CLI command + dry-run) — DONE
- **146-2** (/pf-demo skill wrapper) — DONE
- **146-4** (demo.yaml configuration) — DONE

## Delivery Findings

### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- No upstream findings during implementation.

## SM Assessment

**Setup:** Complete
**Session:** Created with story context and ACs
**Branch:** feat/146-3-hook-story-finish-demo-artifact (pennyfarthing/)
**Jira:** MSSCI-16408 claimed, In Progress
**Dependencies:** 146-1, 146-2, 146-4 all DONE
**Handoff:** To TEA (Thufir Hawat) for RED phase — TDD workflow

## Design Deviations

### TEA (test design)
- No deviations from spec.

### Dev (implementation)
- No deviations from spec.

### Architect (reconcile)
- No additional deviations found.

## TEA Assessment

**Tests Required:** Yes
**Reason:** All 4 ACs require test coverage for a new integration point in the finish pipeline.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_demo_finish_hook.py` - 13 tests covering all 4 ACs

**Tests Written:** 13 tests covering 4 ACs
- AC1 (hook triggers on completion): 3 tests — calls generate, passes correct story_id, skips when session missing
- AC2 (correct configuration): 3 tests — passes project_root, skips in dry-run, dry-run mentions demo step
- AC3 (error handling): 5 tests — failure doesn't block, exception doesn't block, failure recorded in steps, exception recorded in steps, success recorded without warning
- AC4 (test coverage): this file itself
- Ordering: 2 tests — runs before session removal, runs after session archive

**Status:** RED (failing — ready for Dev)
**Commit:** `test: add failing tests for 146-3 story_finish demo hook`

**Implementation guidance for Dev:**
- Integration point: `story_finish.py` `finish_story()` — add demo generation after `_add_story_to_completed()` (step 4b) and before epic archiving (step 5)
- Import: `from pf.demo.orchestrator import generate as demo_generate`
- Call: `demo_generate(story_id, project_root=project_root)`
- Wrap in try/except, record result as step with optional "warning" field
- Add to dry-run output as a planned step mentioning "demo"

**Handoff:** To Reverend Mother (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` - Added step 4c: non-fatal demo generation after story completion, with try/except and dry-run support

**Tests:** 13/13 passing (GREEN)
**Branch:** feat/146-3-hook-story-finish-demo-artifact (pushed)

**Handoff:** To Leto II (Reviewer) for code review

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None

All 4 ACs are satisfied:
- AC1: Demo generation integrated as step 4c in `finish_story()`, after session archive and YAML update
- AC2: Calls `orchestrator.generate(story_id, project_root=project_root)` — correct params per `orchestrator.generate()` signature
- AC3: Wrapped in `try/except Exception`, records warnings in steps, never blocks story completion
- AC4: 13 tests covering trigger, config, error handling, and ordering

**Decision:** Proceed to verify

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 2

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 4 findings | Duplicated session parsing across modules (pre-existing) |
| simplify-quality | clean | No issues |
| simplify-efficiency | 6 findings | Redundant lookups, test boilerplate (pre-existing) |

**Applied:** 0 high-confidence fixes
**Flagged for Review:** 8 findings (all in pre-existing code, out of story scope)
**Noted:** 2 low-confidence observations
**Reverted:** 0

**Overall:** simplify: clean (no changes in story-scoped code warranted)

**Quality Checks:** All passing (13/13 tests)
**Handoff:** To Leto II (Reviewer) for code review

## Subagent Results

| Subagent | Status | Findings |
|----------|--------|----------|
| reviewer-preflight | clean | 2-file diff, 13/13 tests pass |
| reviewer-edge-hunter | clean | All 3 code paths (success/failure/exception) covered by tests |
| reviewer-silent-failure-hunter | clean | try/except logs warning in steps, never swallows silently |
| reviewer-test-analyzer | clean | 13 tests, no vacuous assertions, all ACs covered |
| reviewer-comment-analyzer | clean | No public API docs needed for internal pipeline step |
| reviewer-type-design | clean | Uses existing types (dict, Path, str) — no new APIs |
| reviewer-security | clean | No user input, no injection surface, no secrets |
| reviewer-simplifier | clean | 28 lines, no over-engineering |

All received: Yes

## Reviewer Assessment

**Decision:** APPROVE

**Findings:**
- [TEST] (minor) `import pytest` unused in test file — no pytest features used directly
- [TEST] (minor) Dead variables `original_generate` and `session_path` in `test_demo_runs_before_session_removal`
- [EDGE] All 3 code paths (success/failure/exception) tested — no uncovered edges
- [SILENT] try/except records warning in steps dict — no silent swallowing
- [SEC] No user input, no injection surface, no secrets exposed
- [TYPE] Uses existing types (dict, Path, str) — no new type contracts
- [DOC] Internal pipeline step, no public API docs required
- [SIMPLE] 28 lines of implementation, minimal and focused

**Implementation quality:** Clean. Follows existing `story_finish.py` patterns (lazy import, try/except for non-fatal steps, step recording). Error handling covers both result-failure and exception paths.

**Handoff:** To Stilgar (SM) for finish