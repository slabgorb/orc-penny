---
parent: context-epic-142.md
workflow: trivial
---

# Story 142-2: Fix save_result() nesting bug

## Business Context

Duplicated path logic between `_compute_run_dir()` and `save_result()` causes double-nested `run-N/run-N/` directories that silently invalidate results. This story eliminates the bug class with a single canonical path function.

## Technical Guardrails

**Key files:**
- `pipeline_replay.py`: `_compute_run_dir()` (lines 995–1004, DELETE), `save_result()` (lines 1709–1716, replace), `run_pipeline()` (line 1120, update)
- `cli.py`: `start_id` scan (lines 142–152), `replay_score` (line 269, fragile `parent.parent.parent`)

**The fix:** `compute_run_dir(output_base, scenario_id, tag, run_id) -> Path` with zero conditional branches. `output_base` is always the top-level results dir. Export for cli.py import.

**Pitfall:** Audit all 3 callers: `run_pipeline()`, `replay_run`, `replay_score`. OTEL collector (line 1123) must use same path.

## Scope Boundaries

**In scope:** Single `compute_run_dir()`, delete `_compute_run_dir()`, update all callers
**Out of scope:** Fixing existing double-nested dirs (cleanup extension), changing cleanup extension

## AC Context

| AC | Detail |
|----|--------|
| Single function, no branches | `compute_run_dir()` is public, contains no `if` statements |
| `_compute_run_dir()` deleted | No references remain in codebase |
| All callers updated | `save_result()`, `run_pipeline()`, cli.py scan all use `compute_run_dir()` |
| No double nesting | `save_result()` with any `output_dir` produces `base/scenario/theme/run-N/` |
