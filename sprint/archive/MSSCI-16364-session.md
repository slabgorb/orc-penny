# Session: 143-6 SM spawns single subagent via Agent tool

**Story:** 143-6
**Jira:** MSSCI-16364
**Epic:** 143 — Native Subagent Migration
**Repos:** pennyfarthing
**Branch:** feat/143-6-sm-spawns-single-subagent
**Workflow:** tdd
**Phase:** finish
**Status:** in_progress

## Acceptance Criteria
- SM can spawn a native subagent using the Agent tool
- Subagent receives correct context from pf prime
- Subagent runs in isolated context with role-specific tool restrictions
- Subagent returns results to SM when complete

## Context
This is the first story that wires SM to actually spawn native subagents. Stories 143-1 through 143-5 created the agent definitions, adapted prime output, and defined the handoff contract. Now SM needs to use the Agent tool to spawn a single subagent (e.g., Dev or TEA) with the correct context.

## Story Context
See sprint/context/context-epic-143.md for epic-level architecture.
The handoff document contract from 143-5 defines the interface between SM and subagents.

## Design Deviations

### TEA (test design)
- **Module structure:** Epic context shows `pf prime tea --tier subagent` as the approach, tests assume a new `pf.subagent` module with `loader`, `prompt`, `result`, and `spawn` submodules. Reason: separating subagent orchestration from prime keeps concerns clean — prime assembles context, subagent module handles spawning. → ✓ ACCEPTED by Reviewer: Clean separation of concerns. Prime handles tiers, subagent handles orchestration.
- **SUBAGENT tier:** Tests expect a new `ContextTier.SUBAGENT` that excludes agent_definition, behavior_guide, and persona (since native agent .md files carry those). Reason: avoids duplicate context injection — the Agent tool loads the .md definition automatically. → ✓ ACCEPTED by Reviewer: Correct — native .md files carry agent definition, persona would duplicate.

### Reviewer (audit)
- **workflow_state handling:** SUBAGENT tier loads workflow_state (WorkflowStatus object) per "all tiers include workflow state" (tiers.py:128), but `build_subagent_prompt` (prompt.py:29) silently drops non-string components. Not documented by TEA/Dev. Severity: M — subagent receives task description from SM which provides sufficient context.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core infrastructure for native subagent spawning — 4 ACs all testable.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_143_6_subagent_spawn.py` — 28 tests across 6 classes

**Tests Written:** 28 tests covering 4 ACs
- AC1 (spawn via Agent tool): 4 tests — native agent loading, listing, path resolution
- AC2 (correct context): 11 tests — SUBAGENT tier contents, prompt construction with/without handoff
- AC3 (tool restrictions): 4 tests — frontmatter extraction, reviewer vs dev restriction diff, model extraction
- AC4 (returns results): 5 tests — result parsing (success/error/unknown), handoff validation
- Integration: 4 tests — full spawn config assembly, reviewer restrictions, nonexistent agent error

**Status:** RED (28 failing — ModuleNotFoundError: No module named 'pf.subagent')

**Implementation needed:**
- New `pf/subagent/` module: `loader.py`, `prompt.py`, `result.py`, `spawn.py`
- New `ContextTier.SUBAGENT` in `pf/prime/tiers.py`
- SUBAGENT tier handling in `load_tier_components()`

**Handoff:** To Dev for implementation (GREEN)

## Delivery Findings

### TEA (test design)
- **Gap** (non-blocking): No story-level context document exists for 143-6. SM setup created session but not `sprint/context/context-story-143-6.md`. Affects `sprint/context/` (create context doc). *Found by TEA during test design.*
- **Improvement** (non-blocking): The handoff document schema from 143-5 was committed to pennyfarthing develop in pf-2 but the pennyfarthing checkout here was on a stale feature branch. Had to manually merge. Affects `pennyfarthing/` repo state (ensure develop is current before starting work). *Found by TEA during test design.*

### Dev (implementation)
- No deviations from spec.

## Impact Summary

**Upstream Effects:** 1 findings (1 Gap, 0 Conflict, 0 Question, 0 Improvement)
**Blocking:** None

- **Gap:** No story-level context document exists for 143-6. SM setup created session but not `sprint/context/context-story-143-6.md`. Affects `sprint/context/`.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/subagent/__init__.py` - module init
- `pennyfarthing-dist/src/pf/subagent/loader.py` - native agent loading, frontmatter parsing, tool/model extraction
- `pennyfarthing-dist/src/pf/subagent/prompt.py` - SUBAGENT-tier prompt assembly with handoff injection
- `pennyfarthing-dist/src/pf/subagent/result.py` - SUBAGENT_RESULT YAML parsing, handoff validation
- `pennyfarthing-dist/src/pf/subagent/spawn.py` - complete spawn config assembly for Agent tool
- `pennyfarthing-dist/src/pf/prime/tiers.py` - added SUBAGENT context tier

**Tests:** 28/28 passing (GREEN)
**Branch:** feat/143-6-sm-spawns-single-subagent (pushed)

**Handoff:** To TEA for verify phase

### Dev (implementation)
- No upstream findings during implementation.

## TEA Verify Assessment

**Tests:** 28/28 passing (GREEN) — confirmed post-Dev implementation
**Simplify:** Applied 1 high-confidence fix, 0 regressions

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 7

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 6 findings | duplicated frontmatter extraction (high), tiers.py session unpacking 3x (high, out of scope), test fixture duplication (high, flagged) |
| simplify-quality | 5 findings | {status} vs {success} pattern in spawn.py/result.py (all high — downgraded to medium, domain-specific semantics) |
| simplify-efficiency | 6 findings | tiers.py duplication (medium, out of scope), test parametrization (high+medium, flagged) |

**Applied:** 1 high-confidence fix — extracted `_get_frontmatter_field` helper in `loader.py` to deduplicate `get_agent_tool_restrictions`/`get_agent_model`
**Flagged for Review:** 5 medium-confidence findings (test fixture DRY, result object patterns)
**Noted:** 4 low/out-of-scope observations (pre-existing tiers.py duplication)
**Reverted:** 0

**Overall:** simplify: applied 1 fix

**Quality Gate:** 28/28 tests passing, no regressions after simplify commit
**Handoff:** To The Queen of Hearts for review

### TEA (test verification)
- No upstream findings during test verification.

### Reviewer (code review)
- **Improvement** (non-blocking): `parse_subagent_result` in result.py takes everything after `SUBAGENT_RESULT:` marker to end-of-string. Trailing conversational text after YAML block causes parse failure. Consider requiring marker at end of output or adding end-delimiter detection. Affects `pennyfarthing-dist/src/pf/subagent/result.py` (harden YAML block extraction). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `build_subagent_prompt` in prompt.py silently drops `workflow_state` component because it's a WorkflowStatus object (not string). If workflow context is needed by subagents, serialize it. Affects `pennyfarthing-dist/src/pf/subagent/prompt.py` (handle non-string tier components). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED

**Specialists deployed:** 6 (preflight, edge-hunter, silent-failure-hunter, test-analyzer, type-design, security)
**Total findings aggregated:** 12 (0 critical, 0 high, 10 medium, 2 low)

| Severity | Count | Description |
|----------|-------|-------------|
| [MEDIUM] | 2 | workflow_state dropped from prompt (prompt.py:29), trailing text breaks result parser (result.py:22) |
| [MEDIUM] | 3 | Missing type guards on yaml.safe_load results, path traversal theoretical (internal API), silent defaults |
| [MEDIUM] | 3 | Stringly-typed dict returns could use TypedDict, test vacuous assertions, YAML error swallowed |
| [MEDIUM] | 2 | Prompt injection via handoff (theoretical — framework agents author content), no encoding param |
| [LOW] | 2 | Marker word boundary, .exists() vs .is_file() |

**Data flow traced:** agent_name → loader → definition → spawn config → prompt. Safe — fixed path structure, None-checks at every stage.
**Pattern observed:** Consistent None-or-value returns with caller checks. Clean module separation (loader/prompt/result/spawn).
**Error handling:** All not-found cases return None or error dict. spawn.py converts to structured error.
**Security:** yaml.safe_load throughout. Path traversal in validate_handoff_reference is theoretical (internal API, bool-only return).

**Why approved:** All findings are MEDIUM or LOW. This is internal orchestration infrastructure where inputs come from trusted framework code (SM). The 28 tests cover all 4 ACs. The identified gaps (workflow_state serialization, result parser robustness) are non-blocking improvements for future stories.

**Handoff:** To The Mad Hatter for finish-story

## SM Assessment
Story 143-6 is set up and ready for TDD red phase. Foundation stories 143-1 through 143-5 are complete — all 10 native agent definitions exist in `pennyfarthing-dist/agents/native/`, prime outputs subagent-compatible context, and the handoff document contract is defined. TEA should design tests for SM's ability to spawn a native subagent via the Agent tool, verify context injection from prime, and confirm subagent returns results. Key files: `pennyfarthing-dist/src/pf/prime/`, `pennyfarthing-dist/agents/native/`, and the handoff contract from 143-5.