# Epic 142: Peloton Benchmark Simplification

## Overview

Make pipeline replay benchmarks reliable, self-documenting, and debuggable so we can confidently iterate on agent definitions and measure whether changes help. The epic fixes three blocking problems: cross-repo scenario resolution failures, double-nested run directories corrupting results, and the complete loss of agent reasoning traces after each run.

**Priority:** P0
**Repo:** pennyfarthing
**Stories:** 9 (18 points)

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **Peloton Simplification PRD** (`sprint/planning/peloton-simplification-prd.md`) | Full PRD — stories, technical design, verification plan |
| **Peloton Guide** (`pennyfarthing-dist/guides/peloton.md`) | Scenario YAML schema, "How a Run Works" (needs updating) |

## Background

### Current State

The pipeline replay system (`pf benchmark replay`) runs TDD pipelines (TEA -> Dev -> Reviewer) against real code at known commits, then scores output against ground-truth findings from external reviews. We have 152+ runs across 4 scenarios (`dpgd-116`, `dpgd-117`, `proj-10836`, `pprof-cobra-15`), but only `dpgd-116` and `dpgd-117` actually work — the other two fail with `KeyError` because `load_scenario()` hardcodes `ctx["epic"]` and `ctx["story"]` while those scenarios use `context: {claude_md: CLAUDE.md}`.

### Problems

1. **Cross-repo context resolution is broken.** `load_scenario()` assumes all scenarios live in the orchestrator's sprint/context structure. Scenarios referencing external repos (poller-cobra) with their own CLAUDE.md cannot resolve paths. This blocks proj-10836 and pprof-cobra-15 scenarios entirely, and will block Epic 47's PM/Architect benchmarks.

2. **Double-nested run directories.** Duplicated path logic between `_compute_run_dir()` and `save_result()` with subtly different conditional branches produces `run-N/run-N/` nesting. A cleanup extension exists but the root cause persists.

3. **Agent reasoning is discarded.** `run_phase()` splits into two paths: `--verbose` uses `stream-json` (prints to terminal but discards events), non-verbose uses `json` (captures only final result). Neither path persists the agent's reasoning text, tool decisions, or file reads.

### Why Now

Recent agent definition changes showed no measurable effect on scores. Without event traces, we can't distinguish "agents ignored the changes" from "changes didn't matter." Epic 47 (PM/Architect benchmarks) will hit the same cross-repo wall.

## Technical Architecture

### Component Structure

```
pf/benchmark/
├── pipeline_replay.py    # Core: Scenario, load_scenario, run_phase, run_pipeline, save_result
├── cli.py                # Click commands: replay run/score/compare/judge/trace/explain
├── events.py             # NEW: Event parsing, trace correlation (Story 142-6)
└── bmad_adapter.py       # BMAD framework adapter (untouched)
```

### Key Files

| File | Role | Stories |
|------|------|---------|
| `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` | Core pipeline logic | 142-1, 142-2, 142-3, 142-4, 142-5 |
| `pennyfarthing-dist/src/pf/benchmark/cli.py` | CLI commands | 142-2, 142-6, 142-7 |
| `pennyfarthing-dist/src/pf/benchmark/events.py` | Event parsing (new) | 142-6 |
| `internal/results/pipeline-replay/scenarios/*.yaml` | Scenario definitions | 142-1 |

### Data Flow

```
Scenario YAML → load_scenario() [142-1: unified context resolution]
  → create_worktree() + setup_worktree_pf_context()
  → verify_worktree() [142-3: cleanliness check]
  → run_phase() per phase [142-4: always stream-json, capture events]
    → {role}-events.jsonl written to run_dir
  → save_result() [142-2: single compute_run_dir(), 142-5: framework_version]
  → update_run_index() [142-7: index.yaml]

Post-hoc: events.jsonl → parse_phase_events() [142-6]
  → trace / explain / narrate commands
```

### Key Interfaces

- **`compute_run_dir(output_base, scenario_id, tag, run_id) -> Path`** — single path source of truth (142-2)
- **`buffer_stream_events(input_stream, output_path, verbose_callback)`** — testable event capture (142-4)
- **`parse_phase_events(path) -> dict`** — event parsing for analysis (142-6)
- **`verify_worktree(worktree_path, scenario)`** — pre-execution gate (142-3)

## Cross-Epic Dependencies

**Depends on:** None

**Depended on by:**
- Epic 47 (PM/Architect Benchmarks) — needs unified context resolution (142-1)
