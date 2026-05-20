# PRD: Peloton Benchmark Simplification (Epic 142)

## Epic Vision

Make pipeline replay benchmarks reliable, self-documenting, and debuggable so we can confidently iterate on agent definitions and measure whether changes help.

## Why Now

1. **Blocking:** proj-10836 and pprof scenarios can't run — cross-repo context resolution is broken (KeyError in `load_scenario()`). Epic 47 stories (PM/Architect benchmarks) will hit the same wall.
2. **Corrupting:** Double-nested `run-N/run-N/` directories silently invalidate results. We built a cleanup script but never fixed the root cause.
3. **Blind:** After 152 runs, we still can't answer "why didn't the reviewer catch C1?" The reasoning is in the stream-json events but we throw it away. Recent agent def changes showed no effect — we can't tell if agents ignored the changes or if the changes didn't matter.

## Success Metrics

- All 4 existing scenarios (`dpgd-116`, `dpgd-117`, `proj-10836`, `pprof-cobra-15`) run without manual path fixups
- Zero nesting bugs in new runs (cleanup extension finds 0 issues)
- Every new run has a `{role}-events.jsonl` trace that can be replayed
- `pf benchmark replay trace <run>` answers "did the agent read the relevant file and what did it think?"
- **Single-run diagnostic cycle < 30 min** — from "change agent def" to "understand why score did/didn't change" using trace/explain

## MoSCoW Prioritization

**Must Have (MVP):**
- Unified context resolution (scenarios run across repos)
- Nesting bug root-cause fix
- Event stream always captured to disk

**Should Have:**
- Worktree cleanliness verification
- Framework version reliability
- Run index with backfill

**Could Have:**
- `trace` and `explain` CLI commands
- Index-based run numbering

**Won't Have (this epic):**
- Module split of pipeline_replay.py (defer until next major change)
- SQLite result database
- Real-time BikeRack dashboard integration

## Stories

### Story 1: Unified context resolution in load_scenario() — 2 pts, P0
**Workflow:** trivial

**AC:**
- [ ] `load_scenario()` handles both `context: {epic, story}` and `context: {claude_md}` schemas without KeyError
- [ ] New optional `roots:` block in scenario YAML resolves `repo` and `context` paths relative to scenario file location
- [ ] Backward compatible — dpgd-116.yaml runs unchanged with no `roots:` block
- [ ] `setup_worktree_pf_context()` skips epic/story injection when `context_type="repo"`
- [ ] proj-10836.yaml and pprof-cobra-15.yaml run with correct `roots:` added

- [ ] Update `peloton.md` scenario YAML schema docs with `roots:` and `context_type`

**Out of scope:** Changing existing dpgd-116/dpgd-117 scenario files.

### Story 2: Fix save_result() nesting bug — 1 pt, P0
**Workflow:** trivial

**AC:**
- [ ] Single `compute_run_dir(output_base, scenario_id, tag, run_id) -> Path` function with no conditional branches
- [ ] `_compute_run_dir()` deleted
- [ ] `save_result()` uses `compute_run_dir()` — no duplicated path logic
- [ ] `run_pipeline()` OTEL dir uses same function
- [ ] `cli.py` start_id scan uses same function
- [ ] New runs produce `{base}/{scenario}/{theme}/run-{N}/` — never double-nested

**Out of scope:** Fixing existing double-nested directories (cleanup extension handles that).

### Story 3: Worktree cleanliness verification — 1 pt, P1
**Workflow:** trivial

**AC:**
- [ ] `verify_worktree(worktree_path, scenario)` validates only expected files differ from HEAD
- [ ] HEAD commit hash matches `scenario.base_commit`
- [ ] Called after `setup_worktree_pf_context()`, before first phase execution
- [ ] Aborts with clear error message listing unexpected files

### Story 4: Always capture stream-json events to disk — 3 pts, P0
**Workflow:** tdd

**AC:**
- [ ] Extract `buffer_stream_events(input_stream, output_path, verbose_callback=None)` as a testable pure function (takes line iterator, writes JSONL, optionally calls printer)
- [ ] `run_phase()` always uses `--output-format stream-json` (no json-only path)
- [ ] All events buffered to `{run_dir}/{role}-events.jsonl`
- [ ] Events file flushed on every write for real-time `tail -f` during runs
- [ ] `--verbose` still prints to terminal — events are captured regardless
- [ ] `_run_phase_streaming()` merged into `run_phase()`
- [ ] Each events.jsonl contains assistant text blocks (reasoning), tool_use blocks, tool_result blocks
- [ ] Existing `pf benchmark replay compare` works against old runs without events.jsonl (graceful degradation)
- [ ] Update `peloton.md` "How a Run Works" section to document event capture

**Out of scope:** Parsing/analyzing events — that's Story 6.

### Story 5: Fix framework_version reliability — 1 pt, P1
**Workflow:** trivial

**AC:**
- [ ] `_framework_version()` produces `tag` field via `git describe --tags --always`
- [ ] `agent_hashes` populated for each phase role
- [ ] `save_result()` warns (not errors) when `project_dir` is None
- [ ] New runs have complete `framework_version` in pipeline.yaml

### Story 6: Event parsing and trace/explain commands — 3 pts, P1
**Workflow:** tdd

**AC:**
- [ ] New `events.py` module with `parse_phase_events(path) -> dict`
- [ ] Returns: `text_blocks`, `tool_calls`, `files_read`, `files_written`, `subagents`
- [ ] Path normalization: strip worktree prefix from file paths, handle Bash/Grep indirect file access
- [ ] `pf benchmark replay trace <run-dir>` prints human-readable agent trace
- [ ] `pf benchmark replay explain <run-dir> <finding-id>` correlates finding files with agent reads + reasoning
- [ ] Engagement confidence per finding: High (Read + reasoning mentions issue), Low (Grep/Glob touched file), None (no evidence)
- [ ] Both commands degrade gracefully when events.jsonl is absent
- [ ] Update `peloton.md` with trace/explain usage examples

### Story 7: Run index with backfill — 2 pts, P2
**Workflow:** trivial

**AC:**
- [ ] `update_run_index()` generates `{scenario}/index.yaml` after each new run
- [ ] `pf benchmark replay index <scenario> [--backfill]` builds index from existing runs
- [ ] Index replaces filesystem scan for start_id computation in cli.py
- [ ] Backfill produces valid index for all 152 dpgd-116 runs

### Story 8: Events-first storage model — 3 pts, P2
**Workflow:** tdd

**AC:**
- [ ] `events.jsonl` is the primary run artifact; `pipeline.yaml` and `score.yaml` are derived summaries
- [ ] Auto-generated `events-summary.yaml` per phase at capture time: tool counts, files touched, reasoning word count, subagent count, duration
- [ ] Index (Story 7) builds from events-summary.yaml, not by scanning pipeline.yaml
- [ ] `save_result()` writes events-summary alongside pipeline.yaml
- [ ] Existing runs without events.jsonl still work (summary generated from pipeline.yaml fallback)
- [ ] `pf benchmark replay compare` can use events-summary for richer cross-run comparison (files touched, tool patterns)

### Story 9: LLM-narrated trace — 2 pts, P3
**Workflow:** trivial

**AC:**
- [ ] `pf benchmark replay narrate <run-dir> [--finding <id>]` generates a natural-language diagnostic narrative from events.jsonl
- [ ] Uses judge-model (default sonnet) to summarize: what the agent read, what it reasoned, what it missed and why
- [ ] Output saved as `{run-dir}/narrative.md` for reuse
- [ ] Cost ~$0.50 per narration — warn user before invoking

## Sizing Summary

| Story | Points | Priority | Workflow | Deps | Sprint |
|-------|--------|----------|----------|------|--------|
| 1. Context resolution | 2 | P0 | trivial | — | 2610 |
| 2. Nesting bug fix | 1 | P0 | trivial | — | 2610 |
| 4. Event stream capture | 3 | P0 | tdd | — | 2610 |
| 3. Worktree verification | 1 | P1 | trivial | — | 2610 |
| 5. Framework version | 1 | P1 | trivial | — | 2610 |
| 6. Trace/explain commands | 3 | P1 | tdd | 4 | 2610 |
| 7. Run index | 2 | P2 | trivial | 2 | 2611 |
| 8. Events-first storage | 3 | P2 | tdd | 4, 7 | 2611 |
| 9. LLM-narrated trace | 2 | P3 | trivial | 6 | 2611 |
| **Total** | **18** | | | | |

**Sprint 2610 commitment: 11 pts** (Stories 1-6). Stories 7-9 deferred to 2611 (7 pts).

## Execution Order

1. Stories 1 + 2 (P0, trivial, independent — can parallel)
2. Story 4 (P0, tdd — the big architectural change)
3. Stories 3 + 5 (P1, trivial, independent — can parallel)
4. Story 6 (P1, tdd — depends on Story 4's event capture)
5. Stories 7 + 8 (P2, 2611 — index then events-first storage)
6. Story 9 (P3, 2611 — LLM narration, depends on Story 6)

## Technical Design Reference

*(From White Queen's architectural plan — implementation details for Dev)*

## Phase 1: Foundation Fixes (Blocks new scenarios)

### 1A. Unified context resolution in `load_scenario()`

**Problem:** `load_scenario()` (pipeline_replay.py:156) hardcodes `ctx["epic"]` and `ctx["story"]` — the proj scenarios use `context: {claude_md: CLAUDE.md}` which raises `KeyError`.

**Fix:** Add a `roots` resolution block to scenario YAML and extend `Scenario` dataclass:

```yaml
# New optional field — backward compatible
roots:
  repo: ../axiathon       # relative to scenario file, not --project-dir
  context: ../             # defaults to --project-dir
```

- Add `context_type: str = "pf"` to `Scenario` (`"pf"` = epic/story/session, `"repo"` = repo CLAUDE.md only)
- `load_scenario()` resolves `roots.repo` relative to `Path(scenario_path).parent`
- When `roots` absent, existing behavior unchanged (resolve from `--project-dir`)
- `setup_worktree_pf_context()` skips epic/story injection for `context_type="repo"`

**Files:** `pipeline_replay.py` (Scenario dataclass, load_scenario, setup_worktree_pf_context)

### 1B. Fix `save_result()` nesting bug (root cause)

**Problem:** Duplicated path logic between `_compute_run_dir()` (line 995) and `save_result()` (line 1710) with subtly different conditions causes double-nested `run-N/run-N/` directories.

**Fix:** Single public function, no conditional branches:

```python
def compute_run_dir(output_base: Path, scenario_id: str, tag: str, run_id: int) -> Path:
    return output_base / scenario_id / tag / f"run-{run_id}"
```

- Delete `_compute_run_dir()`
- Update `save_result()` to use `compute_run_dir()` — caller must pass the base `output_dir` (not pre-nested)
- Update `run_pipeline()` OTEL dir computation to use same function
- Update `cli.py` start_id scan (line 143) to use same function for path

**Files:** `pipeline_replay.py`, `cli.py`

### 1C. Worktree cleanliness verification

**Problem:** No validation that worktree is clean after `setup_worktree_pf_context()`. A crashed run can leave orphaned files.

**Fix:** Add `verify_worktree(worktree_path, scenario)` after context setup:
1. `git diff --name-only HEAD` — only injected files (`.pennyfarthing`, `.claude/`, `.session/`, `sprint/context/`) should show. Any other change = abort.
2. `git rev-parse HEAD` must match `scenario.base_commit`.

**Files:** `pipeline_replay.py` (new function, called in `run_pipeline()`)

## Phase 2: Event Stream Capture (Zero token cost, highest insight value)

### 2A. Always buffer stream-json events to disk

**Problem:** `run_phase()` (line 908) splits into two paths: `--verbose` uses `stream-json` (prints to terminal, discards), non-verbose uses `json` (captures only final result). Agent reasoning text is NEVER persisted.

**Fix:** Merge into single execution path:
- Always use `--output-format stream-json`
- Buffer ALL events to `{run_dir}/{role}-events.jsonl`
- Print to terminal only when `verbose=True`
- Extract final result from the `result` event (same as current streaming path)

**New parameter:** `run_phase()` gets `events_dir: Path | None` — when set, writes `{role}-events.jsonl` there.

**What gets captured:** system prompts, assistant reasoning text, tool_use decisions, tool_result responses, final result with tokens/cost. This is the complete agent trace — ~50-200KB per phase.

**Files:** `pipeline_replay.py` (merge `_run_phase_streaming` into `run_phase`, add events_dir param, update `run_pipeline()` to pass it)

### 2B. Reasoning extractor utility

**Problem:** Raw JSONL events are unreadable for analysis.

**Fix:** Add `parse_phase_events(events_path: Path) -> dict`:
- `text_blocks: list[str]` — assistant reasoning
- `tool_calls: list[dict]` — tool name, key params, truncated result
- `files_read: list[str]` — from Read tool events
- `files_written: list[str]` — from Write/Edit tool events
- `subagents: list[dict]` — Agent tool invocations

This is a post-hoc utility for analysis commands, not called at runtime.

**Files:** New `events.py` module in `pf/benchmark/`

### 2C. Fix framework_version reliability

**Problem:** `_framework_version()` returns `None` when `project_dir` is None, and never produces a `tag` field.

**Fix:**
- Add `git describe --tags --always` for `tag` field
- Make `project_dir` effectively mandatory in `save_result()` (print warning if missing)
- Ensure `agent_hashes` dict is populated for each phase role

**Files:** `pipeline_replay.py` (`_framework_version`, `save_result`)

## Phase 3: Index Layer

### 3A. Run index per scenario

Add `{output_dir}/{scenario_id}/index.yaml` auto-updated after each run:

```yaml
scenario_id: dpgd-116
last_updated: "2026-03-11T..."
runs:
  - run_id: 2
    theme: control
    timestamp: "..."
    score_pct: 45.9
    score_source: majority_vote
    n_judges: 3
    framework_version: {commit: abc123, tag: v13.0.0}
    has_events: true
```

Add `update_run_index()` in persistence logic, called from `save_result()`.
Add `pf benchmark replay index <scenario> [--backfill]` command.

**Files:** `pipeline_replay.py` (new function), `cli.py` (new subcommand)

### 3B. Index-based run numbering

Replace filesystem scan in cli.py (line 142-152) with index lookup. Monotonically increasing, immune to `_rejected` dirs and nesting artifacts.

**Files:** `cli.py`

## Phase 4: Agent Visibility Tooling

### 4A. `pf benchmark replay trace <run-dir>` command

Reads `{role}-events.jsonl` and produces human-readable trace:

```
[TEA] Turn 1
  → Read: config.rs (42 lines)
  REASONING: "I'll examine the config loading code..."
  → Write: tests/config_loading.rs (new, 89 lines)
```

**This answers "are agents listening?"** — you can see the agent's reasoning about what it read.

### 4B. `pf benchmark replay explain <run-dir> <finding-id>`

Correlates a ground-truth finding with the agent trace:
1. Look up finding's `files` list
2. Search event traces for Read/Edit of those files
3. Extract surrounding reasoning context
4. Show whether the agent engaged with the relevant code

**Files:** `cli.py` (new subcommands), `events.py` (correlation logic)

## Key Files

| File | Stories |
|------|---------|
| `pennyfarthing/pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` | 1, 2, 3, 4, 5 |
| `pennyfarthing/pennyfarthing-dist/src/pf/benchmark/cli.py` | 2, 6, 7 |
| `pennyfarthing/pennyfarthing-dist/src/pf/benchmark/events.py` | 6 (new file) |
| `internal/results/pipeline-replay/scenarios/*.yaml` | 1 (add roots to proj/pprof) |
| `.pennyfarthing/extensions/benchmark/cleanup.py` | 2 (simplify after root-cause fix) |

## Reuse (existing code to preserve)

- `OTELFileCollector` — event capture supplements, doesn't replace OTEL
- `_print_stream_event()` — stays as-is, called conditionally from unified path
- Existing 152+ DPGD-116 runs — untouched, new features degrade gracefully

## Verification Plan

1. **Stories 1+2:** `pf benchmark replay run scenarios/dpgd-116.yaml --n 1 --skip-score --keep-worktree` — no nesting, no KeyError
2. **Story 4:** Run with and without `--verbose` — both produce `{role}-events.jsonl` with assistant text blocks
3. **Story 7:** `pf benchmark replay index dpgd-116 --backfill` — index.yaml covers all 152 runs
4. **Story 6:** `pf benchmark replay trace <run-dir>` — readable trace; `explain <run-dir> C1` — shows file reads + reasoning
5. **Regression:** `pf benchmark replay compare` works against old runs (no events.jsonl)

## Deferred (Won't Have)

- Module split of `pipeline_replay.py` into `scenario.py`, `worktree.py`, `phase.py`, `pipeline.py`, `scoring.py`, `persistence.py` — defer until the file crosses 2500 lines or next major feature
- SQLite index — YAML is git-friendly and sufficient at current scale
- BikeRack dashboard integration — separate epic if needed
