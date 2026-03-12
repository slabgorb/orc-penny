# Story 142-2: Fix save_result() nesting bug

**Status:** in-progress
**Phase:** finish
**Workflow:** trivial
**Repos:** pennyfarthing
**Jira:**
**Branch:** fix/142-2-fix-save-result-nesting

## Context

Duplicated path logic between `_compute_run_dir()` and `save_result()` causes double-nested `run-N/run-N/` directories that silently invalidate results. This story eliminates the bug class with a single canonical path function.

**Key files:**
- `pipeline_replay.py`: `_compute_run_dir()` (lines 995–1004, DELETE), `save_result()` (lines 1709–1716, replace), `run_pipeline()` (line 1120, update)
- `cli.py`: `start_id` scan (lines 142–152), `replay_score` (line 269, fragile `parent.parent.parent`)

## Acceptance Criteria

| AC | Detail |
|----|--------|
| Single function, no branches | `compute_run_dir()` is public, contains no `if` statements |
| `_compute_run_dir()` deleted | No references remain in codebase |
| All callers updated | `save_result()`, `run_pipeline()`, cli.py scan all use `compute_run_dir()` |
| No double nesting | `save_result()` with any `output_dir` produces `base/scenario/theme/run-N/` |

## Implementation Notes

**The fix:** `compute_run_dir(output_base, scenario_id, tag, run_id) -> Path` with zero conditional branches. `output_base` is always the top-level results dir. Export for cli.py import.

**Pitfall:** Audit all 3 callers: `run_pipeline()`, `replay_run`, `replay_score`. OTEL collector (line 1123) must use same path.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` - Replaced `_compute_run_dir()` (conditional, private) with `compute_run_dir()` (branchless, public); updated `save_result()` to use it
- `pennyfarthing-dist/src/pf/benchmark/cli.py` - Imported `compute_run_dir`, updated `start_id` scan to derive `theme_dir` from it

**Tests:** 57/57 passing (GREEN)
**Branch:** fix/142-2-fix-save-result-nesting (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `output_dir` → `compute_run_dir()` → `base/scenario/tag/run-N` → `mkdir` in `save_result()` (safe — pure Path math, no I/O in path function)
**Pattern observed:** Single source of truth for path construction eliminates DRY violation at `pipeline_replay.py:795`
**Error handling:** `compute_run_dir` is pure; caller `save_result` handles `mkdir(parents=True, exist_ok=True)` at `pipeline_replay.py:1483`
**Tests:** 57/57 passing, zero references to deleted `_compute_run_dir`
**Observations:**
- `[VERIFIED]` All 4 ACs met: branchless function, private deleted, 3 callers updated, canonical path structure
- `[VERIFIED]` `replay_score` path arithmetic (`parent.parent.parent`) still correct with canonical structure
- `[LOW]` cli.py:142 uses `compute_run_dir(..., 0).parent` — phantom run-0, stylistically odd but functionally correct
- `[VERIFIED]` `tag` always non-empty: `theme or "control"` guards in both callers
- `[VERIFIED]` Net -10 lines — complexity reduced

**Handoff:** To the Mad Hatter for finish-story

## Delivery Findings

<!-- delivery-findings -->
### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- No upstream findings during code review.