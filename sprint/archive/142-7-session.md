---
story: 142-7
title: Run index with backfill
workflow: trivial
phase: setup
repos: pennyfarthing
epic: 142
---

# Story 142-7: Run index with backfill

**Workflow:** trivial
**Repos:** pennyfarthing
**Status:** setup

## Story Overview

The `start_id` filesystem scan in `cli.py` is fragile with double-nested artifacts and `_rejected` dirs. An `index.yaml` per scenario provides reliable, queryable run metadata and replaces the scan. This story adds `index.yaml` generation during `save_result()` and a backfill command to populate indexes for existing runs.

## Key Files to Modify

- `pipeline_replay.py` — add `update_run_index()` function
  - Called from `save_result()` after writing results
  - Creates `{output_base}/{scenario_id}/index.yaml`
  - Prefers `majority_vote.yaml` over `score.yaml` for `score_pct`
  - Detects `has_events` by checking for `*-events.jsonl` files

- `cli.py` — replace filesystem scan with index lookup
  - Add `index` subcommand with `--backfill` flag
  - Replace scan logic (lines 142–152) with index lookup (fallback to scan)
  - `index --backfill <scenario_id>` covers all runs in scenario

## Acceptance Criteria

| AC | Detail |
|----|--------|
| Index created/updated | `{scenario}/index.yaml` updated after each `save_result()` |
| Backfill works | `index dpgd-116 --backfill` covers all 152 runs |
| Replaces scan | cli.py reads index first, falls back to filesystem |

## Scope Boundaries

**In scope:**
- `update_run_index()` function
- `index --backfill` command
- Replace filesystem scan with index lookup (fallback)

**Out of scope:**
- SQLite integration
- Using index in compare command

## SM Assessment

**Routing:** Trivial workflow (2pt refactor) → straight to Dev, no TEA needed.
**Context:** Story has clear ACs, context doc exists, scope is well-defined — implement index generation and backfill.
**Handoff:** White Rabbit (Dev) to implement. No Jira key to claim.
**Risk:** Low. Index is supplementary to existing scan; fallback ensures backward compatibility.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` — added `update_run_index()`, `_build_index_entry()`, `backfill_run_index()`. Called from `save_result()` to auto-maintain index.
- `pennyfarthing-dist/src/pf/benchmark/cli.py` — added `replay index` subcommand with `--backfill` flag. Replaced filesystem scan with `_next_run_id()` using index-first lookup with fallback.

**Tests:** 1874/1874 passing (GREEN). Pre-existing packaging error unrelated.
**Branch:** feature/story-142-7-run-index-backfill (pushed)

**AC verification:**
- Index created/updated: `save_result()` calls `update_run_index()` automatically
- Backfill works: `pf benchmark replay index dpgd-116 --backfill` indexed 168 runs
- Replaces scan: `_next_run_id()` reads index first, falls back to filesystem scan

**Note:** Discovered pipeline.yaml `run_id` diverges from directory names in historical runs. Auto-increment uses directory name number (consistent with original behavior), not pipeline.yaml `run_id`.

**Handoff:** To Reviewer (The Queen of Hearts) for code review.

## Reviewer Assessment

**Verdict:** APPROVED

| Severity | Issue | Location | Note |
|----------|-------|----------|------|
| [MEDIUM] | Upsert key uses `run_id` (pipeline.yaml) not `run_dir` (directory name) — historical collisions exist | `pipeline_replay.py:1291-1293` | Not exploitable in normal flow; only affects manual update_run_index on old data |
| [MEDIUM] | No YAML parse error handling in `_build_index_entry` — corrupt file aborts entire backfill | `pipeline_replay.py:1316` | Resilience improvement, not correctness bug |
| [LOW] | `has_events` materializes full list vs `any()` short-circuit | `pipeline_replay.py:1333-1334` | Minor performance nit |
| [VERIFIED] | `scenario_dir = run_dir.parent.parent` correct for all 3 save_result path branches | `pipeline_replay.py:1261` | |
| [VERIFIED] | Fallback scan preserved in `_next_run_id` — backward compatible | `cli.py:625-634` | |
| [VERIFIED] | `_next_run_id` uses directory name for auto-increment, matching original behavior | `cli.py:616-623` | |
| [VERIFIED] | Backfill skips `_rejected` dirs, non-dirs, non-run entries | `pipeline_replay.py:1358-1363` | |

**Data flow traced:** `save_result()` → builds `run_dir` → writes files → `run_dir.parent.parent` → `update_run_index()` → reads/upserts `index.yaml`. Safe — all paths produce correct scenario_dir.
**Pattern observed:** Index-first-with-fallback pattern in `_next_run_id` is sound and preserves backward compatibility.
**Error handling:** `_build_index_entry` returns `None` for missing `pipeline.yaml` but does not catch YAML parse errors (MEDIUM, non-blocking).

**Handoff:** To The Mad Hatter (SM) for finish-story.

## Delivery Findings

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): Upsert dedup key in `update_run_index` should use `run_dir` instead of `run_id` for robustness with historical data. Affects `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` (upsert filter at line 1291). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_build_index_entry` should catch `yaml.YAMLError` and return `None` to make backfill resilient to corrupt files. Affects `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` (YAML load at line 1316). *Found by Reviewer during code review.*