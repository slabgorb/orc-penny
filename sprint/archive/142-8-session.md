# Story 142-8: Events-first storage model

**Story ID:** 142-8
**Jira:**
**Status:** in_progress
**Points:** 3
**Type:** refactor
**Repos:** pennyfarthing
**Branch:** feature/story-142-8-events-first-storage-model
**Workflow:** tdd
**Phase:** finish
**Started:** 2026-03-12T10:00:54Z

## Story Context

### Business Context

With events captured (142-4), auto-generate structured summaries at write time — tool counts, files touched, reasoning word count — making cross-run comparison richer without post-hoc parsing.

### Technical Guardrails

**Key files:** `events.py` — add `generate_events_summary()`. `pipeline_replay.py` — `save_result()` writes `events-summary.yaml` per phase.

**Summary generated at write time** inside `save_result()`, not read time. Fallback: `has_events: false` with zero counts for old runs. Do NOT make `reconstruct_pipeline_result()` depend on events-summary — breaks pre-142-8 re-scoring.

### Scope Boundaries

**In scope:** `generate_events_summary()`, write in `save_result()`, fallback for old runs, optional use in compare
**Out of scope:** Migrating old runs, SQLite

### Acceptance Criteria

| AC | Detail |
|----|--------|
| Summary auto-generated | `events-summary.yaml` exists per phase after `save_result()` |
| Old runs work | Missing events.jsonl → `has_events: false` |
| Compare can use it | Shows files touched and tool patterns when available |

### Epic Context

This story is part of **Epic 142: Peloton Benchmark Simplification**, which makes pipeline replay benchmarks reliable, self-documenting, and debuggable.

**Epic Priority:** P0
**Epic Stories:** 9 (18 points total)

Key files:
- `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` — Core pipeline logic
- `pennyfarthing-dist/src/pf/benchmark/events.py` — Event parsing (new, from 142-6)
- `internal/results/pipeline-replay/scenarios/*.yaml` — Scenario definitions

## SM Assessment

Story 142-8 setup complete. Context loaded from story and epic context files. Branch `feature/story-142-8-events-first-storage-model` created off develop in pennyfarthing repo. Clear scope: add `generate_events_summary()` to events.py, call from `save_result()`, with fallback for old runs. 3-point refactor, TDD workflow — handing off to TEA for red phase.

## Design Deviations

### TEA (test design)
- **Event source:** Context says "events.jsonl" but actual OTEL data is stored as `{phase}-otel.jsonl`. Tests use the actual file format. Reason: OTEL collector (OTELFileCollector in pipeline_replay.py) writes `{phase}-otel.jsonl`, not `events.jsonl`. → ✓ ACCEPTED by Reviewer: correct — matches actual OTELFileCollector output format.
- **reasoning_word_count deferred:** AC mentions "reasoning word count" but tests focus on tool_counts and files_touched which are extractable from OTEL log records. Reason: reasoning text is in assistant messages not captured in OTEL logs — may need separate source. Dev should assess feasibility. → ✓ ACCEPTED by Reviewer: OTEL logs genuinely lack assistant text. Deferral is correct.

### Dev (implementation)
- No deviations from spec. → ✓ ACCEPTED by Reviewer.

### Reviewer (audit)
- No undocumented deviations found.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core story — new function + integration with save_result()

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_events_summary.py` - 27 tests across 7 test classes
- `pennyfarthing-dist/src/pf/benchmark/events.py` - stub with NotImplementedError

**Tests Written:** 27 tests covering 3 ACs
- AC1 (Summary auto-generated): 7 tests — return type, has_events flag, per-phase keys, tool counts, files touched, dedup, totals
- AC2 (Old runs work): 5 tests — has_events false, zero counts, empty files, per-phase flag, multiple missing phases
- AC2 extended (Partial OTEL): 6 tests — mixed has_events, per-phase correctness
- AC1 extended (save_result integration): 3 tests — events-summary.yaml created, parseable, reconstruct independence
- AC3 (Compare can use it): 2 tests — tool_patterns and files_touched available
- Edge cases: 4 tests — empty file, malformed JSON, empty phases, non-log signals

**Status:** RED (26 failing, 1 passing — the reconstruct independence guardrail test)

**Handoff:** To Dev (The White Rabbit) for implementation

### Dev (implementation)
- No deviations from spec.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/benchmark/events.py` - implemented generate_events_summary() with OTEL JSONL parsing
- `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` - added events-summary.yaml write to save_result()
- `pennyfarthing-dist/src/pf/tests/test_events_summary.py` - fixed Scenario constructor (added phase_prompts)

**Tests:** 27/27 passing (GREEN)
**Branch:** feature/story-142-8-events-first-storage-model (pushed)

**Handoff:** To TEA (The Caterpillar) for verify phase

## Delivery Findings
### TEA (test design)
- **Question** (non-blocking): AC mentions "reasoning word count" as a summary field, but OTEL log records only contain tool events — assistant reasoning text is not captured in the OTEL JSONL. Dev should determine if reasoning word count is feasible from available data or should be deferred. *Found by TEA during test design.*

### Dev (implementation)
- **Question** (non-blocking): Confirmed TEA's finding — reasoning word count is not feasible from OTEL JSONL data. OTEL logs only contain tool_decision and tool_result events, not assistant message text. Would require a separate capture mechanism (e.g., parsing stream-json output). Deferred to future story. *Found by Dev during implementation.*

## TEA Verify Assessment

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 5 findings | Duplicated OTEL attr parsing (high), duplicated traversal pattern (high), 3 medium |
| simplify-quality | 2 findings | Unsafe dict access (high), conditional assertion gap (medium) |
| simplify-efficiency | 4 findings | Single-use helper (high), 3 medium |

**Applied:** 2 high-confidence fixes
- Inlined `_empty_phase_summary()` (single-use 4-property dict)
- Fixed `a["key"]` to `a.get("key", "")` for safe OTEL attribute extraction

**Flagged for Review:** 7 medium-confidence findings
- Attribute parsing duplication between events.py and pipeline_replay.py (refactor scope beyond story)
- OTEL traversal pattern duplication (same — cross-file refactor)
- Empty line check redundant with JSON error handling
- Nested .get() readability
- Test fixture over-parameterization (sequence param)
- Magic string event type constants
- Conditional assertion in test_events_summary_yaml_parseable

**Noted:** 2 high-confidence findings downgraded (cross-file refactor beyond story scope)

**Reverted:** 0

**Overall:** simplify: applied 2 fixes

**Tests:** 27/27 passing (GREEN confirmed post-simplify)

**Handoff:** To The Queen of Hearts (Reviewer)

## Reviewer Assessment

**Verdict:** APPROVED

| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | [VERIFIED] | Data flow: OTEL JSONL → parse → dict → YAML. Linear, no surprises | events.py → pipeline_replay.py:1791 |
| 2 | [VERIFIED] | Wiring: deferred import avoids circular, `_` phases excluded | pipeline_replay.py:1793 |
| 3 | [VERIFIED] | Guardrail: reconstruct_pipeline_result unchanged, test confirms | pipeline_replay.py:1857, test:344 |
| 4 | [VERIFIED] | Error handling: malformed JSON, missing files, empty files, non-log signals | events.py:26-34 |
| 5 | [VERIFIED] | AC coverage: 27 tests across all 3 ACs + edge cases | test_events_summary.py |
| 6 | [LOW] | read_text() loads full OTEL file into memory | events.py:25 |
| 7 | [MEDIUM] | Conditional assertion silently passes if file missing | test_events_summary.py:340 |

**Data flow traced:** OTEL JSONL files → `_parse_phase_otel()` → `generate_events_summary()` → `save_result()` writes YAML (safe — internal benchmark tool, no user input)
**Pattern observed:** Safe `.get()` chains with defaults throughout — consistent with `_extract_tool_attrs()` pattern
**Error handling:** Malformed JSON skipped, missing files produce fallback, empty files detected by size check
**Security:** No external input vectors. Internal benchmark tool only.

**Handoff:** To The Mad Hatter (SM) for finish-story

### Reviewer (code review)
- **Improvement** (non-blocking): `test_events_summary_yaml_parseable` uses `if summary_path.exists()` guard that silently passes on missing file. Consider changing to `assert` in future. Affects `pennyfarthing-dist/src/pf/tests/test_events_summary.py` (line 340). *Found by Reviewer during code review.*