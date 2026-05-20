# Session: 143-7 SM reads handoff documents and chains phases

**Story:** 143-7
**Jira:** PROJ-16365
**Epic:** 143 — Native Subagent Migration
**Repos:** pennyfarthing
**Branch:** feat/143-7-sm-reads-handoff-documents
**Workflow:** tdd
**Phase:** finish
**Status:** in_progress

## Acceptance Criteria
- SM can read handoff documents produced by subagents
- SM extracts gate resolution data from handoff documents
- SM chains the next workflow phase based on gate results
- Handoff document format is validated before processing

## Context
Story 143-6 established that SM can spawn native subagents and receive results. Now SM needs to consume those results by reading the handoff documents they produce, extracting gate decision data, and chaining to the next workflow phase. This enables multi-phase workflows where subagents handoff to each other (e.g., TEA → Dev → Reviewer).

The handoff document contract from 143-5 defines the interface. This story implements SM's side of that contract — the reader, validator, and phase-chaining logic.

## Story Context
See sprint/context/context-epic-143.md for epic-level architecture.
The handoff document contract from 143-5 defines the schema and validation rules.
Story 143-6 established subagent spawning and result collection.

## SM Assessment

3-point TDD story on the critical path for native subagent migration. Prerequisites 143-5 (handoff contract) and 143-6 (single subagent spawning) are both done. This story builds the phase-chaining orchestration: SM reads handoff documents from completed subagents and uses them to spawn the next phase's agent with prior context injected.

The subagent module already has the building blocks — `parse_subagent_result()`, `build_spawn_config(prior_handoff_path=...)`, `validate_handoff_reference()`. This story adds the chaining logic that connects them: extract handoff path → validate → resolve next phase/agent → build next spawn config.

Story context written at `sprint/context/context-story-143-7.md`. Route to the Caterpillar (TEA) for test design.

## Design Deviations

### TEA (test design)
- **AC granularity:** Session ACs are high-level (4 items). Tests decompose into 5 ACs matching the story context document, which provides clearer edge cases per function. Reason: story context has the precise AC definitions; session ACs are summaries.
- **Module structure:** Story context suggests `chain.py` as a NEW file in `pf/subagent/`. Tests assume three public functions (`extract_handoff_path`, `validate_handoff_document`, `resolve_next_phase`) plus one compositor (`chain_next_phase`). Reason: clean separation of concerns — each step is independently testable.
- **Validation scope:** AC2 in story context says "reuse `validate_handoff_reference()` from result.py". Tests introduce a separate `validate_handoff_document()` that also checks for empty/whitespace-only content. Reason: existing `validate_handoff_reference()` only checks existence (returns bool) — we need richer validation that returns result objects and catches empty files.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core infrastructure for multi-phase native subagent workflows — all 5 ACs are testable.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_143_7_chain_phases.py` — 29 tests across 6 classes

**Tests Written:** 29 tests covering 5 ACs
- AC1 (extract handoff path): 5 tests — relative path, absolute path, missing key, empty string, None
- AC2 (validate handoff document): 4 tests — valid, missing, empty, whitespace-only
- AC3 (resolve next phase): 9 tests — TDD full chain (setup→red→green→verify→review→finish), last phase returns None, unknown phase, unknown workflow, trivial workflow
- AC4 (chain next phase): 6 tests — successful red→green, missing handoff path, missing file, last phase complete, missing agent def, trivial workflow
- AC5 (result contract): 5 tests — never throws for garbage input, corrupt YAML, empty inputs, consistent shape across all functions

**Stub module:** `pennyfarthing-dist/src/pf/subagent/chain.py` — 4 functions with `NotImplementedError`
**Status:** RED (29 failing — all NotImplementedError, no import/syntax errors)
**Branch:** feat/143-6-sm-spawns-single-subagent (pennyfarthing repo, develop base)

**Handoff:** To the White Rabbit (Dev) for implementation (GREEN)

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- **AC granularity:** → ✓ ACCEPTED by Reviewer: Story context ACs are the authoritative spec; session ACs are summaries.
- **Module structure:** → ✓ ACCEPTED by Reviewer: Clean separation, each function independently testable.
- **Validation scope:** → ✓ ACCEPTED by Reviewer: `validate_handoff_reference()` returns bare bool — result-object wrapper is the right call per SOUL #10.
- **Dev: No deviations** claim is accurate for the stated ACs.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/subagent/chain.py` — Phase-chaining orchestration with 4 functions: `extract_handoff_path`, `validate_handoff_document`, `resolve_next_phase`, `chain_next_phase`

**Tests:** 29/29 passing (GREEN)
**Branch:** feat/143-6-sm-spawns-single-subagent (pushed)

**AC Verification:**
- [x] SM can extract handoff document path from subagent result — `extract_handoff_path()` handles relative/absolute paths, missing/empty/None values
- [x] SM can validate handoff document exists on disk — `validate_handoff_document()` checks existence + non-empty content
- [x] SM can resolve next phase and agent from workflow — `resolve_next_phase()` reads workflow YAML, handles last-phase and unknown-phase cases
- [x] SM can build spawn config for next phase with prior handoff — `chain_next_phase()` composes all steps, delegates to `build_spawn_config()`
- [x] Chain function returns result objects, never throws — all functions wrapped in try/except, return `{success, data/error}`

**Handoff:** To the Caterpillar (TEA) for verify phase

## Delivery Findings

### TEA (test design)
- **Gap** (non-blocking): Tests committed to branch `feat/143-6-sm-spawns-single-subagent` (leftover from 143-6) instead of `feat/143-7-sm-reads-handoff-documents`. The branch field in the session says 143-7 but pennyfarthing was still on the 143-6 branch. Affects `pennyfarthing/` repo (Dev should create the correct branch or continue on this one). *Found by TEA during test design.*
- **Improvement** (non-blocking): `validate_handoff_reference()` in `result.py` returns a bare `bool`, inconsistent with the result-object pattern (SOUL #10). Suggest refactoring to return `{success, error?}` in a future story. Affects `pennyfarthing-dist/src/pf/subagent/result.py`. *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation.

## TEA Verify Assessment

**Tests:** 29/29 passing (GREEN confirmed)

### Simplify Report

**Teammates:** skipped (single new file, 170 lines, context at 60%)
**Files Analyzed:** 1 (chain.py)
**Overall:** simplify: clean — implementation is minimal, follows result-object pattern, no duplication detected

### Quality-Pass

- [x] All tests passing (29/29)
- [x] No debug code
- [x] Result objects on all paths (SOUL #10)
- [x] Reuses existing `build_spawn_config` from 143-6

**Handoff:** To the Queen of Hearts (Reviewer) for code review

### TEA (test verification)
- No upstream findings during test verification.

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** subagent_result dict → extract_handoff_path (resolve relative/absolute) → validate_handoff_document (exists + non-empty) → resolve_next_phase (workflow YAML lookup) → build_spawn_config (safe — internal SM→subagent, no user input)
**Pattern observed:** Result-object pattern consistently applied across all 4 functions at `chain.py:28,57,86,135`
**Error handling:** Every public function wrapped in try/except returning `{success: False, error}`. Inner functions gate outer — early return on failure at `chain.py:138,145,150`.
**Observations:**
- [VERIFIED] SOUL #10 (Return Results, Don't Throw) — all paths return result dicts
- [VERIFIED] Reuses `build_spawn_config` from 143-6 — no logic duplication in spawn path
- [VERIFIED] Test coverage: 29 tests, 5 ACs, edge cases include corrupt YAML, empty files, garbage input, cross-workflow
- [MEDIUM] `_load_workflow_phases` duplicates `complete_phase._load_workflow_phases` — same logic at `chain.py:196` vs `complete_phase.py:256`. Consolidate in future story (SOUL #2).
- [LOW] `_load_workflow_phases` doesn't catch `yaml.safe_load` exceptions internally — acceptable since all callers wrap in try/except

**Handoff:** To the Mad Hatter (SM) for finish-story

## Delivery Findings

### TEA (test design)
- **Gap** (non-blocking): Tests committed to branch `feat/143-6-sm-spawns-single-subagent` (leftover from 143-6) instead of `feat/143-7-sm-reads-handoff-documents`. The branch field in the session says 143-7 but pennyfarthing was still on the 143-6 branch. Affects `pennyfarthing/` repo (Dev should create the correct branch or continue on this one). *Found by TEA during test design.*
- **Improvement** (non-blocking): `validate_handoff_reference()` in `result.py` returns a bare `bool`, inconsistent with the result-object pattern (SOUL #10). Suggest refactoring to return `{success, error?}` in a future story. Affects `pennyfarthing-dist/src/pf/subagent/result.py`. *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): `_load_workflow_phases` is duplicated between `chain.py:196` and `complete_phase.py:256`. Extract to a shared utility in `pf/handoff/` or `pf/workflow/` to satisfy SOUL #2 (One Truth, One Place). Affects `pennyfarthing-dist/src/pf/subagent/chain.py` and `pennyfarthing-dist/src/pf/handoff/complete_phase.py`. *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** 3 findings (1 Gap, 2 Improvement, 0 Conflict, 0 Question)
**Blocking:** None

## Workflow Steps

### Red Phase (Test Design)
TEA designs tests for:
1. Handoff document parsing (valid YAML, required fields)
2. Gate resolution extraction (GATE_ID → decision mapping)
3. Workflow phase chaining (current phase + gate decision → next phase)
4. Error handling (missing handoff, invalid YAML, gate resolution failure)

### Green Phase (Implementation)
Dev implements:
1. Handoff document reader in `pf/subagent/`
2. Gate resolution parser
3. Workflow phase chaining logic in SM orchestration
4. Validation and error handling

### Verify Phase (Test Verification)
TEA verifies all tests pass post-implementation.

### Review Phase (Code Review)
Reviewer audits implementation and test coverage.

### Finish Phase
SM marks story complete and documents findings.