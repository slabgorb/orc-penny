---
parent: context-epic-142.md
workflow: trivial
---

# Story 142-9: LLM-narrated trace

## Business Context

`trace` and `explain` show raw data. For complex runs, a natural-language narrative answering "what did the agent do, what did it miss, and why?" saves significant analysis time. ~$0.50 per narration.

## Technical Guardrails

**Key files:** `cli.py` — add `narrate` subcommand. Reuse `_invoke_judge()` from pipeline_replay.py (same `claude -p --output-format json --tools ""` pattern).

**Cost warning** to stderr, `--yes` to skip confirmation. Cache `narrative.md` — reuse unless `--force`. `--finding <id>` filters to specific finding. Default model `claude-sonnet-4-6`. Truncate events to ~50K tokens (prioritize reasoning over tool results).

## Scope Boundaries

**In scope:** `narrate` command with `--finding`, `--model`, `--yes`, `--force`; cached `narrative.md`
**Out of scope:** Batch narration, BikeRack integration

## AC Context

| AC | Detail |
|----|--------|
| Generates narrative | `narrate <run-dir> --yes` produces `narrative.md` |
| Cost warning | Without `--yes`, prompts for confirmation |
| Cached reuse | Second call reuses unless `--force` |
| `--finding` filters | Focuses narrative on specific finding's files and detection |
