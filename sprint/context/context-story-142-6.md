---
parent: context-epic-142.md
workflow: tdd
---

# Story 142-6: Event parsing and trace/explain commands

## Business Context

After 142-4 captures events, this story makes them useful. `trace` shows what the agent read and thought. `explain` correlates a finding with the agent trace — "did the agent see the relevant code and what did it conclude?" Closes the diagnostic cycle.

## Technical Guardrails

**Key files:**
- `pf/benchmark/events.py` — NEW. Pure functions, no subprocess calls, no Click. Must be importable independently (no circular imports with pipeline_replay).
- `cli.py` — add `trace` and `explain` subcommands under `@replay`

**`parse_phase_events()` returns:** `text_blocks`, `tool_calls`, `files_read`, `files_written`, `subagents`

**Path normalization:** Read tool events have absolute worktree paths. Strip prefix using `pipeline.yaml`'s `worktree_path`. Finding files in scenario YAML are repo-relative. Normalize both before comparing.

**Engagement confidence:** High (Read + reasoning mentions issue), Low (Grep/Glob touched file), None (no evidence).

**Graceful degradation:** Return empty structure for missing files. Print "No events found" and exit 0 for pre-142-4 runs.

## Scope Boundaries

**In scope:** `events.py` module, `trace` and `explain` CLI commands, path normalization, graceful degradation, peloton.md examples
**Out of scope:** Auto summaries (142-8), LLM narration (142-9)

## AC Context

| AC | Detail |
|----|--------|
| Correct parse output | Known JSONL → correct `text_blocks`, `tool_calls`, `files_read`, etc. |
| Path normalization | Strips worktree prefix from absolute paths |
| `trace` readable | `[ROLE] Turn N` blocks with tools + reasoning |
| `explain` correlates | Shows which phase read finding files, engagement confidence |
| Graceful degradation | Pre-142-4 runs: "No events found", exit 0 |
