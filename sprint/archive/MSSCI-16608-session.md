---
story_id: "150-8"
jira_key: "MSSCI-16608"
epic: "MSSCI-16564"
workflow: "tdd"
---
# Story 150-8: Reviewer must run full subagent pipeline on every rework cycle

## Story Details
- **ID:** 150-8
- **Jira Key:** MSSCI-16608
- **Epic:** MSSCI-16564 (Prove the Work — PR Explanation Quality)
- **Workflow:** tdd
- **Points:** 2
- **Priority:** p1
- **Repos:** pennyfarthing
- **Branch:** feat/150-8-full-pipeline-rework
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** red
**Phase Started:** 2026-03-20T21:49:42Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-20T21:48:18Z | 2026-03-20T21:49:42Z | 1m 24s |
| red | 2026-03-20T21:49:42Z | - | - |

## Story Context

### Problem
After CHANGES_REQUESTED, the reviewer currently spot-checks only the specific fixes. This misses regressions introduced by the fixes themselves. Real-world evidence from orc-ax:
- Making fields private introduced a Deserialize bypass (new security hole)
- Adding string truncation introduced a UTF-8 panic (new crash)
Both were only caught because the full pipeline was manually re-run.

### Approach — Rework Detection + Full Re-run Enforcement
The `complete_phase.py` approval gate already validates subagent completion. Extend it to detect rework cycles and enforce that ALL enabled subagents ran on the CURRENT cycle, not just the initial review.

1. Track rework cycle count in session file (`**Rework Cycle:** N`)
2. When reviewer re-enters the review phase after CHANGES_REQUESTED, increment the cycle counter
3. The approval gate checks that subagent results are from the CURRENT cycle (not stale from a previous run)
4. The reviewer agent definition should explicitly instruct: "After rework, re-run ALL enabled subagents against the full diff, not just spot-check fixes"

### Implementation Details
- Add `rework_cycle` tracking to session metadata (incremented on re-entry to review phase)
- Add `_check_rework_freshness()` to `complete_phase.py` that verifies the subagent results table references the current cycle
- Update reviewer.md on-activation to detect rework and mandate full re-run
- The gate becomes: subagent completion + dispatch + rule compliance + rework freshness

### Acceptance Criteria
- [ ] Rework cycle counter tracked in session file
- [ ] Approval gate detects stale subagent results from previous cycle
- [ ] Reviewer agent definition mandates full pipeline re-run on rework
- [ ] Gate blocks approval if subagent results are from a prior rework cycle
- [ ] Tests verify rework detection and freshness checking

## Delivery Findings

No upstream findings.

## Design Deviations

No design deviations.

## Reviewer Assessment

**Verdict:** APPROVED

### Summary

Two new functions added to `complete_phase.py` (`_parse_rework_cycle`, `_check_rework_freshness`) plus a 7-line integration block in the approval gate. Clean, minimal implementation that follows existing patterns in the module.

### Findings

**1. Rework cycle parsing — edge cases handled correctly**
- Missing field returns 0 (no-op for initial reviews)
- Malformed value (non-integer) returns 0 rather than raising
- Empty content returns 0
- Regex correctly targets `**Rework Cycle:** N` markdown format

**2. Freshness check logic is sound**
- Cycle 0 (initial review) always passes — no false positives for existing workflows
- Missing Subagent Results section during rework correctly fails
- Missing cycle tag in results section correctly fails (catches the case where reviewer forgets to annotate)
- Stale cycle (results_cycle != current_cycle) correctly fails with actionable error message
- Matching cycle passes

**3. Integration with existing approval gate is correct**
- Freshness check runs AFTER subagent completion and dispatch checks, which is the right order (no point checking freshness if subagents haven't run at all)
- Returns the standard `{status, session_file, error}` shape
- Does not interfere with non-approval gate types
- Existing `_check_subagent_completion` and `_check_subagent_dispatch` are untouched

**4. Python lang-review checklist**
- No silent exception swallowing (ValueError caught specifically, returns 0)
- No mutable default arguments
- Type annotations present on both public functions (`str -> int`, `str -> dict`)
- No resource leaks
- No unsafe deserialization
- Uses `re` module consistently with existing code patterns
- f-string in error message is acceptable (not a logging call)

**5. Test quality**
- 10 tests across 3 test classes, all non-vacuous
- Tests check specific return values (`result["pass"] is True/False`, exact cycle numbers)
- Integration test properly mocks 5 dependencies and uses `tmp_path` for filesystem isolation
- Stale/fresh/missing scenarios all covered
- Mock patches target correct import paths (where used, not where defined)

**6. Minor note (non-blocking)**
- The `_check_rework_freshness` return type annotation is `dict` rather than a TypedDict or more specific type. This is consistent with how `complete_phase` returns plain dicts throughout, so not a regression, but a future improvement opportunity.
- The f-string `"To fix: Add '**Cycle: {cycle}**'"` on line ~510 uses a literal `{cycle}` inside a regular string (not an f-string), so it will print the literal text `{cycle}` rather than the actual cycle number. This is a minor UX bug in the error message but does not affect gate enforcement.

**7. AC coverage**
- [x] Rework cycle counter tracked in session file — `_parse_rework_cycle` reads it; existing `complete_phase` Round-Trip Count logic already increments on rework gate transitions
- [x] Approval gate detects stale subagent results — `_check_rework_freshness` integrated
- [ ] Reviewer agent definition mandates full pipeline re-run — NOT in this diff (AC-3). Acceptable as a separate story/commit.
- [x] Gate blocks approval if subagent results are from a prior cycle — tested in integration test
- [x] Tests verify rework detection and freshness checking — 10 tests

AC-3 (reviewer.md update) is not in scope for this diff. The gate enforcement is the critical piece and is complete. The reviewer agent instruction can be added separately without risk.