---
parent: context-epic-142.md
workflow: tdd
---

# Story 142-4: Always capture stream-json events to disk

## Business Context

The highest-insight-value change. Neither verbose nor non-verbose paths persist agent reasoning. After 152 runs we can't answer "why didn't the reviewer catch C1?" This story captures the complete agent trace to JSONL on every run.

## Technical Guardrails

**Key files:** `pipeline_replay.py` — DELETE `_run_phase_streaming()` (lines 832–905), rewrite `run_phase()` (lines 908–987) to always use `--output-format stream-json`, add `events_dir: Path | None` param.

**Extract testable pure function:**
```python
def buffer_stream_events(
    input_stream: Iterator[str],
    output_path: Path,
    verbose_callback: Callable | None = None,
) -> dict | None:
```
Takes `Iterator[str]` for testability. `_print_stream_event()` (lines 783–829) stays unchanged, passed as callback.

**Pitfalls:** Use `f.flush()` after every write for `tail -f`. Call `proc.wait()` after stdout loop. Stream-json `result` event has same keys as JSON but different nesting — validate against real output. OTEL and stream-json are parallel captures, not competing.

## Scope Boundaries

**In scope:** Merge streaming paths, `buffer_stream_events()`, always write `{role}-events.jsonl`, update peloton.md
**Out of scope:** Parsing/analyzing events (142-6), generating summaries (142-8)

## AC Context

| AC | Detail |
|----|--------|
| `buffer_stream_events()` testable | Takes `Iterator[str]`, writes JSONL. Testable with fake iterator |
| Always stream-json | No `--output-format json` path remains |
| Events written to JSONL | `{events_dir}/{role}-events.jsonl` exists after every phase |
| Flushed per write | Real-time `tail -f` works during runs |
| Verbose still prints | `--verbose` terminal output unchanged |
| `_run_phase_streaming()` deleted | No references remain |
| Old runs still work | `compare` on runs without events.jsonl succeeds |
