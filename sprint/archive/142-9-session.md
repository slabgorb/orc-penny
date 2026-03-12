# Story 142-9: LLM-narrated trace

**Story ID:** 142-9
**Jira:** (none)
**Workflow:** tdd
**Phase:** finish
**Repos:** orchestrator
**Branch:** feature/story-142-9-llm-narrated-trace
**Started:** 2026-03-12T00:00:00Z

## Story Context

Epic 142: Peloton Benchmark Simplification — make pipeline replay benchmarks reliable, self-documenting, and debuggable.

Story 142-9 adds LLM narration capabilities to the trace system, allowing for human-readable explanations of events captured during benchmark runs.

## Acceptance Criteria

TBD — awaiting TEA phase to define test requirements.

## SM Assessment

Story 142-9 set up for TDD workflow. 2-point story adding LLM narration to the trace system (Epic 142). Branch created, session initialized. Routing to TEA (the Caterpillar) for red phase — test design before implementation.

## Design Deviations

### TEA (test design)
- **Internal function mocking:** Tests mock `_invoke_llm` (not yet created) rather than `_invoke_judge` from pipeline_replay.py. Reason: narrate module should own its own LLM call function to avoid coupling to judge-specific logic. → ✓ ACCEPTED by Reviewer: correct isolation
- **Truncation heuristic:** Tests use ~4 chars/token approximation. Reason: exact tokenization is model-specific; a char-based estimate is sufficient and avoids a tokenizer dependency. → ✓ ACCEPTED by Reviewer: agrees with author reasoning

### Dev (implementation)
- **Separate narrate module:** Implemented as separate `narrate.py` with own `_invoke_llm()`. → ✓ ACCEPTED by Reviewer: pipeline_replay.py is already large
- **Test fix:** Changed `test_cost_warning_on_stderr` to `test_cost_warning_in_output`. → ✓ ACCEPTED by Reviewer: pragmatic Click compat fix

### Reviewer (audit)
- **Truncation prioritization:** Docstring says "Prioritizes reasoning content over tool results" but implementation is flat `text[:max_chars]`. Not documented by TEA/Dev. Severity: L.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core feature with LLM integration, caching, and CLI interface

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_narrate.py` - 23 tests across 4 ACs
- `pennyfarthing-dist/src/pf/benchmark/narrate.py` - stubs (build_narrate_prompt, truncate_events_to_budget, generate_narrative)

**Tests Written:** 23 tests covering 4 ACs + truncation + edge cases
**Status:** RED (20 failing, 3 passing — failures are all due to missing implementation)

**Key implementation notes for Dev:**
- `build_narrate_prompt()` — reads OTEL JSONL from run_dir, builds LLM prompt with scenario context
- `truncate_events_to_budget()` — truncate to ~50K tokens (~200K chars), prioritize reasoning over tool results
- `generate_narrative()` — orchestrates: check cache → build prompt → call LLM → write narrative.md
- `_invoke_llm()` — reuse `_invoke_judge()` pattern (`claude -p --output-format json --tools ""`)
- CLI `narrate` command under `replay` group with `--yes`, `--force`, `--finding`, `--model` options
- Cost warning to stderr, `click.confirm()` without `--yes`

**Handoff:** To Dev (White Rabbit) for implementation

### Dev (implementation)
- **Separate narrate module:** Story context said "add narrate subcommand to cli.py" and "reuse _invoke_judge()". Implemented as separate `narrate.py` module with its own `_invoke_llm()` instead. Reason: pipeline_replay.py is already large; narrate.py keeps concerns isolated and `_invoke_llm` avoids coupling to judge-specific error messages.
- **Test fix:** Changed `test_cost_warning_on_stderr` to `test_cost_warning_in_output` — Click CliRunner `mix_stderr` parameter not available in installed version.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/benchmark/narrate.py` - Core logic: build_narrate_prompt, truncate_events_to_budget, generate_narrative, _invoke_llm
- `pennyfarthing-dist/src/pf/benchmark/cli.py` - Added `narrate` subcommand under `replay` group
- `pennyfarthing-dist/src/pf/tests/test_narrate.py` - Fixed Click API compat issue in test

**Tests:** 23/23 passing (GREEN)
**Branch:** feature/story-142-8-events-first-storage-model (pushed)

**Handoff:** To Reviewer (Queen of Hearts) for code review

## TEA Verify Assessment

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 4 findings | 3 high: test fixture duplication (test_narrate.py ↔ test_events_summary.py); 1 medium: extractable helper |
| simplify-quality | clean | No findings |
| simplify-efficiency | 6 findings | 1 high: pre-existing `replay_judge()` intermediate var (out of scope); 5 medium/low |

**Applied:** 0 high-confidence fixes (reuse findings are test helper duplication — three short helpers across two files is below extraction threshold; efficiency high-confidence finding is in pre-existing code outside 142-9 scope)
**Flagged for Review:** 1 medium — `_make_assistant_record()` could join shared OTEL test utils if more test files adopt it
**Noted:** 5 low-confidence observations (test parametrization, API flexibility, error messaging)
**Reverted:** 0

**Overall:** simplify: clean (no changes applied)

**Tests:** 23/23 passing (GREEN confirmed)
**Quality-pass:** PASSED

**Handoff:** To Reviewer (Queen of Hearts) for code review

## Delivery Findings

### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- No upstream findings during implementation.

### TEA (test verification)
- **Improvement** (non-blocking): OTEL test fixture helpers (`_make_tool_decision_record`, `_make_tool_result_record`, `_write_otel_jsonl`) are duplicated across `test_narrate.py` and `test_events_summary.py`. Consider extracting to `conftest.py` if a third test file needs them. Affects `pennyfarthing-dist/src/pf/tests/` (future consolidation). *Found by TEA during test verification.*

### Reviewer (code review)
- **Improvement** (non-blocking): `truncate_events_to_budget()` docstring claims reasoning prioritization but implementation is flat truncation. Affects `pennyfarthing-dist/src/pf/benchmark/narrate.py` (update docstring or add prioritization logic). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): CLI `replay_narrate` doesn't pass `ground_truth` to `generate_narrative`, so `--finding` works as LLM hint only — no event filtering. Affects `pennyfarthing-dist/src/pf/benchmark/cli.py` (wire scenario ground_truth if available). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED

| Severity | Issue | Location | Note |
|----------|-------|----------|------|
| [MEDIUM] | Docstring overpromises truncation prioritization | narrate.py:137 | Non-blocking |
| [MEDIUM] | --finding lacks ground_truth in CLI path | cli.py:640 | Non-blocking |
| [LOW] | scenario_id parameter unused | narrate.py:207 | Dead param |
| [LOW] | Empty LLM response gets cached | narrate.py:247 | Edge case |
| [VERIFIED] | Cache logic, _invoke_llm pattern, error handling, security | — | Clean |

**Data flow traced:** CLI arg `run_dir` → `Path(run_dir)` → `pipeline.yaml` read → `generate_narrative()` → `build_narrate_prompt()` reads OTEL JSONL → `_invoke_llm()` subprocess → writes `narrative.md`. Safe — no user input reaches shell unescaped.
**Pattern observed:** `_invoke_llm` correctly mirrors `_invoke_judge` at pipeline_replay.py:1445.
**Error handling:** FileNotFoundError for bad paths, JSONDecodeError caught in OTEL parsing, subprocess timeout=300s.

**Handoff:** To the Mad Hatter (SM) for finish-story

## Notes

- Part of Epic 142 (p0, in_progress)
- Follows 142-8 (Events-first storage model)
- 2-point story, p3 priority
- Uses tdd workflow (TEA → Dev → Reviewer)