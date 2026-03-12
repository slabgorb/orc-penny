# Session: 143-4 Adapt pf prime for subagent-compatible context output

**Date:** 2026-03-12
**Story ID:** 143-4 / MSSCI-16362
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/143-4-native-subagent-prime-output
**Jira:** MSSCI-16362

---

## Story Description

Adapt pf prime for subagent-compatible context output. The Prime system currently outputs full context for in-conversation agents. For subagents with isolated context windows, Prime must support selective context output compatible with native Claude Code agent definitions.

**Points:** 5
**Priority:** P0
**Assigned to:** keithavery

---

## Key Files

- `pennyfarthing-dist/src/pf/prime/` — Prime system (Python)
- `pennyfarthing-dist/src/pf/prime/cli.py` — Prime CLI entry point
- `pennyfarthing-dist/src/pf/prime/tiers.py` — Token tier definitions
- `pennyfarthing-dist/src/pf/prime/loader.py` — Context loader
- `pennyfarthing/packages/core/src/prime/prime.ts` — Prime TypeScript API

---

## Context & Approach

**Epic Context:** Native Subagent Migration (143) — replacing in-conversation persona switching with isolated Claude Code subagents.

**Completed Dependencies:**
- 143-1: Dev native subagent definition
- 143-2: TEA and Reviewer native subagent definitions
- 143-3: Remaining 7 agent native subagent definitions

**What needs to happen:**
- Analyze current Prime output format and token tiers
- Design subagent-compatible context format (stripped down vs. full)
- Implement filtering/selection modes in Prime
- Test with actual subagent invocations

---

## Workflow: TDD (Phased)

**Phase 1 (TEA):** Write tests for subagent context output — what data structures, what fields
**Phase 2 (Dev):** Implement Prime changes to support selective context
**Phase 3 (Reviewer):** Code review and validation
**Gate progression:** confidence → quality → marker → next phase

---

## Session Notes

- Context documents created: `sprint/context/context-epic-143.md` and `sprint/context/context-story-143-4.md`
- Subagent definitions created in 143-1/143-2/143-3 are available in `pennyfarthing-dist/agents/native/`
- Handoff document contract (143-5) depends on this story's output format

---

## SM Assessment

**Setup complete.** Story 143-4 is ready for TEA (red phase).

- Session file created with story context, key files, and workflow details
- Branch `feat/143-4-native-subagent-prime-output` created and checked out
- Epic context (`sprint/context/context-epic-143.md`) and story context (`sprint/context/context-story-143-4.md`) created
- Jira MSSCI-16362 already in progress
- Story context document includes detailed AC expansion, technical guardrails, and scope boundaries

**Handoff to TEA:** Write failing tests for the new SUBAGENT context tier in Prime. Focus on:
1. New `ContextTier.SUBAGENT` enum value and CLI flag
2. Component inclusion/exclusion (no agent def, no behavior guide; yes persona, session, sidecars, story context)
3. Story context loader (finds `sprint/context/context-story-{id}.md` from session)
4. Token estimation for new tier

---

### TEA (test design)
- No deviations from spec.

## Delivery Findings

### TEA (test design)
- No upstream findings during test design.

## TEA Assessment

**Tests Required:** Yes
**Reason:** New SUBAGENT context tier needs comprehensive coverage across 6 ACs.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_subagent_tier.py` — 37 tests covering all ACs

**Tests Written:** 37 tests covering 6 ACs
**Status:** RED (28 failing, 9 passing edge cases — ready for Dev)

**Key implementation needed by Dev:**
1. Add `SUBAGENT = "SUBAGENT"` to `ContextTier` enum in `tiers.py`
2. Add SUBAGENT branch to `load_tier_components()` — include persona, sprint, repos, session, sidecars, story_context; exclude agent_def, guide, soul, style
3. Add `load_story_context()` to `loader.py` — reads session file for story ID, loads `sprint/context/context-story-{id}.md`
4. Add "subagent" to CLI `--tier` choices in `cli.py`
5. Wire SUBAGENT tier through `_prime_tiered()` in `cli.py`

**Handoff:** To Dev (White Rabbit) for implementation

### Dev (implementation)
- No deviations from spec.

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): `_component_source` in `cli.py:152-170` missing `"story_context"` mapping. JSON output will have `source: null` for story_context component. Affects `pennyfarthing-dist/src/pf/prime/cli.py` (add `"story_context": None` or dynamic path to mapping dict). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Pre-existing stale inline import at `cli.py:656` — `load_repos_topology` is already imported at module level (line 37). Not introduced by 143-4 but noticed during review. Affects `pennyfarthing-dist/src/pf/prime/cli.py` (remove inline import). *Found by Reviewer during code review.*

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/prime/tiers.py` — Added SUBAGENT to ContextTier enum and load_tier_components
- `pennyfarthing-dist/src/pf/prime/loader.py` — Added load_story_context() function
- `pennyfarthing-dist/src/pf/prime/cli.py` — Wired SUBAGENT tier through CLI, argparse, Click, and _prime_tiered

**Tests:** 37/37 passing (GREEN) + 86 existing tests unaffected
**Branch:** feat/143-4-native-subagent-prime-output (committed in pennyfarthing repo)

**Handoff:** To Queen of Hearts for review

## TEA Verify Assessment

**Simplify Analysis:** Complete (fan-out/fan-in with 3 Haiku subagents)
**Findings:** 1 actionable (high confidence)
- `cli.py`: Moved 2 inline `from pf.prime.loader import ...` statements to module-level imports (load_repos_topology, load_story_context were already importable from the top of the file)

**Regression:** 123/123 tests GREEN after fix
**Commit:** `refactor(prime): move inline imports to module level per simplify review`

**Quality Gate:** PASS — no dead code, no naming issues, no over-engineering, no duplication.

**Handoff:** To Queen of Hearts (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Preflight:** 123/123 tests GREEN (37 subagent + 43 tiers + 43 prime)
**Subagents dispatched:** 6 (preflight, edge-hunter, silent-failure-hunter, test-analyzer, type-design, security)

**Review Checklist:**
- [x] **5+ observations** — see below
- [x] **Data flow traced:** Story ID extracted from session `**Story ID:**` field → split on `/` → first part → used in `sprint/context/context-story-{id}.md` path. Safe: `.md` suffix appended, `exists()` check, session files are trusted internal artifacts.
- [x] **Wiring:** CLI (argparse + Click) → `prime()` → `_prime_tiered()` → tier-specific block. SUBAGENT wired correctly in both entry points.
- [x] **Pattern observed:** [VERIFIED] SUBAGENT tier follows established patterns from FULL/REFRESH/HANDOFF/MINIMAL at `tiers.py:192-237` and `cli.py:317-381`
- [x] **Error handling:** SUBAGENT requires `--agent` (returns 1 without). All loaders return None on missing data (graceful degradation). Pre-existing pattern across all tiers.
- [x] **Security analysis:** [SEC] Path traversal theoretical only — session files are agent-written internal artifacts, `.md` suffix enforced, `exists()` gate, path resolves within project root. LOW.
- [x] **Hard questions:** Missing story context → gracefully skipped. Missing sidecars → gracefully skipped. Missing persona → gracefully skipped. All tested.
- [x] **Subagent findings incorporated:** See below.

**Observations:**
1. [VERIFIED] ContextTier.SUBAGENT enum and tier_from_string wired correctly at `tiers.py:67`
2. [VERIFIED] Component exclusions correct — no agent_def, guide, soul, style in SUBAGENT branch at `tiers.py:192-237`
3. [VERIFIED] Component inclusions correct — persona (full), sprint, repos, session (header+assessment), sidecars, story_context at `tiers.py:198-233`
4. [VERIFIED] `load_story_context()` follows established `_find_session_file()` + `read_text()` pattern at `loader.py:174-216`
5. [VERIFIED] Tests comprehensive: 37 tests across 7 classes covering all 6 ACs + edge cases
6. [TYPE] `_component_source` missing `"story_context"` mapping at `cli.py:154-170` — JSON output has `source: null` for story_context. Non-blocking (returns None by default).
7. [TEST] No integration test for `--json` with SUBAGENT tier. Non-blocking — JSON path delegates to `_build_json_result` → `load_tier_components` which IS tested.
8. [SIMPLE] Pre-existing stale inline import at `cli.py:656` (not introduced by this story).

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [MEDIUM] | `_component_source` missing story_context | `cli.py:154-170` | Add mapping (non-blocking) |
| [LOW] | No JSON integration test for SUBAGENT | `test_subagent_tier.py` | Optional future improvement |
| [LOW] | Stale inline import (pre-existing) | `cli.py:656` | Cleanup (not 143-4 scope) |
| [LOW] | Path traversal theoretical | `loader.py:212` | Session files are trusted |

**No Critical or High issues. APPROVED.**

**Handoff:** To the Mad Hatter (SM) for finish-story

---

## Handoff Destinations

- **TEA completes:** writes test expectations → passes to Dev
- **Dev completes:** implements context changes → passes to Reviewer
- **Reviewer approves:** merges PR → marks story complete

---