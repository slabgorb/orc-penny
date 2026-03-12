---
parent: context-epic-142.md
workflow: tdd
---

# Story 142-8: Events-first storage model

## Business Context

With events captured (142-4), auto-generate structured summaries at write time — tool counts, files touched, reasoning word count — making cross-run comparison richer without post-hoc parsing.

## Technical Guardrails

**Key files:** `events.py` — add `generate_events_summary()`. `pipeline_replay.py` — `save_result()` writes `events-summary.yaml` per phase.

**Summary generated at write time** inside `save_result()`, not read time. Fallback: `has_events: false` with zero counts for old runs. Do NOT make `reconstruct_pipeline_result()` depend on events-summary — breaks pre-142-8 re-scoring.

## Scope Boundaries

**In scope:** `generate_events_summary()`, write in `save_result()`, fallback for old runs, optional use in compare
**Out of scope:** Migrating old runs, SQLite

## AC Context

| AC | Detail |
|----|--------|
| Summary auto-generated | `events-summary.yaml` exists per phase after `save_result()` |
| Old runs work | Missing events.jsonl → `has_events: false` |
| Compare can use it | Shows files touched and tool patterns when available |
