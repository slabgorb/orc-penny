---
parent: context-epic-142.md
workflow: trivial
---

# Story 142-7: Run index with backfill

## Business Context

The `start_id` filesystem scan is fragile with double-nested artifacts and `_rejected` dirs. An `index.yaml` per scenario provides reliable, queryable run metadata and replaces the scan.

## Technical Guardrails

**Key files:** `pipeline_replay.py` — add `update_run_index()`, call from `save_result()`. `cli.py` — replace scan (lines 142–152) with index lookup (fallback to scan), add `index` subcommand.

**Index at** `{output_base}/{scenario_id}/index.yaml` (same level as `comparison.yaml`). Prefer `majority_vote.yaml` over `score.yaml` for `score_pct`. Backfill must handle double-nested artifacts gracefully. `has_events` checks for `*-events.jsonl` files.

## Scope Boundaries

**In scope:** `update_run_index()`, `index --backfill` command, replace filesystem scan (with fallback)
**Out of scope:** SQLite, using index in compare command

## AC Context

| AC | Detail |
|----|--------|
| Index created/updated | `{scenario}/index.yaml` updated after each `save_result()` |
| Backfill works | `index dpgd-116 --backfill` covers all 152 runs |
| Replaces scan | cli.py reads index first, falls back to filesystem |
