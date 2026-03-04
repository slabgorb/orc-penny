# Story 131-2: SM Auto-Triggers Context Creation on Gate Failure

**Status:** in-progress
**Phase:** finish
**Workflow:** tdd
**Repos:** pennyfarthing
**Branch:** feature/131-2-sm-auto-triggers-context-creation
**Points:** 2
**Epic:** 131 — Gate-Enforced Context Pipeline
**Jira:** MSSCI-15678

---

## Context

### Acceptance Criteria

(ACs from sprint YAML to be added during story work)

### Epic Context

**Epic 131 Overview:** Wire the validator and creation skill into the gate system so context is enforced, not optional. SM's setup gate checks for epic and story context before handoff. TEA's gate checks for validated story context before RED phase. When context is missing, SM auto-triggers creation. This is the integration epic — it makes the pipeline mandatory.

**Key Dependencies:**
- Epic 129-3 (Validator CLI) — `pf context-docs validate` command
- Epic 130-2 (Story Creation Skill) — `/pf-context create` invoked by SM on failure

### Story 131-2 Purpose

Update SM agent behavior so that when `sm-setup-exit` gate reports `epic-context-validated` or `story-context-validated` as failed (exit 2 = not found), SM automatically invokes `/pf-context create` for the missing level, then re-runs the gate.

**Failure messaging:**
- Creation succeeded, re-validation passed: continue silently
- Creation succeeded, re-validation failed: "Context created but has validation errors. Manual fix needed at {path}"
- Creation failed: "Context creation failed. Run `/pf-context create {type} {id}` manually"

**Key constraint:** One attempt per level (Rule #6), then fail. No retry loops.

### Key Files

**Modified:**
- `pennyfarthing-dist/agents/sm.md` — Update SM agent to intercept gate failures and auto-trigger context creation

**Referenced (from prior epics):**
- `pennyfarthing-dist/gates/sm-setup-exit.md` — Gate that 131-1 updated with validation cascade
- `pf/context_docs/cli.py` — Validator CLI (from Epic 129-3)
- `pennyfarthing-dist/skills/pf-context/skill.md` — Context creation skill (from Epic 130)

**Context Files:**
- `sprint/context/context-epic-131.md` — Epic architecture and planning

### Approach

1. **Understand SM agent handoff flow:** Read `pennyfarthing-dist/agents/sm.md` to see where handoff is invoked and where gate failures are caught
2. **Implement auto-trigger logic:**
   - After `pf handoff resolve-gate` call, parse gate report
   - If gate fails with exit code 2 on `epic-context-validated` or `story-context-validated` checks
   - Invoke `/pf-context create` for the failed level
   - Re-run `pf handoff resolve-gate` immediately
3. **Add failure messaging:** Implement the three failure scenarios (created + passed, created + failed, creation failed)
4. **Test with TDD:** Write tests for the auto-trigger flow, then implement to pass tests
5. **Verify:** Ensure session context cascade, message clarity, and one-attempt constraint are met

---

## Assessments

### SM Assessment

**Setup Complete:** Yes
**Jira:** MSSCI-15678 (claimed, In Progress)
**Branch:** feature/131-2-sm-auto-triggers-context-creation (pushed)
**Session:** Created with ACs, key files, approach, epic context
**Dependencies:** 129-3 (validator), 130-2 (creation skill), 131-1 (gate cascade) — all completed
**Handoff:** To Igor (TEA) for RED phase — test design for auto-trigger flow

### TEA Assessment

**Tests Required:** Yes
**Reason:** New Python module with testable logic — gate recovery detection, cascade ordering, outcome formatting

**Architecture Decision:** Recovery config lives in workflow YAML (`gate.recovery:` block), not in agent markdown. New Python module `pf.handoff.gate_recovery` provides the detection and formatting logic. SM agent instructions will reference the recovery pipeline.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_gate_recovery.py` — 36 tests covering all 8 ACs
- `pennyfarthing-dist/src/pf/handoff/gate_recovery.py` — stub module (NotImplementedError)

**Tests Written:** 36 tests covering 8 ACs
- AC1: Epic missing → epic creation action (4 tests)
- AC2: Story missing → story creation action (4 tests)
- AC3: Cascade order: epic first, then story (3 tests)
- AC4: One attempt per level / max_attempts (3 tests)
- AC5: Validation errors do NOT trigger recovery (3 tests)
- AC6: Created + validated → continue silently (2 tests)
- AC7: Created + invalid → warning with path (5 tests)
- AC8: Creation failed → error with manual command (4 tests)
- Utility: parse_story_id (5 tests)

**Status:** RED (36 failing — all on NotImplementedError, no import/syntax errors)

**Dev Notes:**
- Recovery config should be added to `pennyfarthing-dist/workflows/tdd.yaml` setup phase gate
- SM.md needs instructions to call recovery actions after gate failure
- Consider "starting square" pattern for consistent SM-initiated handoff paths

**Handoff:** To Ponder Stibbons (Dev) for GREEN phase

### Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/handoff/gate_recovery.py` — Implemented get_recovery_actions, format_recovery_outcome, parse_story_id
- `pennyfarthing-dist/workflows/tdd.yaml` — Added recovery config to setup gate
- `pennyfarthing-dist/workflows/trivial.yaml` — Added recovery config to setup gate
- `pennyfarthing-dist/workflows/bdd.yaml` — Added recovery config to setup gate
- `pennyfarthing-dist/workflows/bdd-tandem.yaml` — Added recovery config to setup gate
- `pennyfarthing-dist/workflows/tdd-tandem.yaml` — Added recovery config to setup gate
- `pennyfarthing-dist/agents/sm.md` — Added gate-recovery section with recovery pipeline instructions

**Tests:** 36/36 passing (GREEN)
**Branch:** feature/131-2-sm-auto-triggers-context-creation (pushed)

**Handoff:** To TEA for verify phase

### TEA Verify Assessment

**Tests Verified:** 36/36 GREEN
**Runner:** Cousin Igor (testing-runner subagent)

**Implementation Review:**
- `gate_recovery.py` — 3 public functions, 1 private helper, all clean
- `_is_recoverable()` correctly distinguishes "missing" from "validation error" (AC5)
- Cascade order preserved from gate result input order (AC3)
- `format_recovery_outcome()` covers all 3 AC scenarios (AC6/AC7/AC8)
- `parse_story_id()` validates with regex, raises ValueError on bad input

**Wiring Verified:**
- Recovery config added to 5 workflow YAMLs (tdd, bdd, bdd-tandem, trivial, tdd-tandem)
- SM agent `<gate-recovery>` section documents full recovery pipeline
- Config structure matches test fixtures exactly

**Edge Cases Noted (acceptable):**
- Cascade order depends on gate result ordering, not enforced by module — workflow YAML defines epic before story, so gate runner produces correct order
- `_is_recoverable()` substring match on "validation error" handles both singular/plural forms

**Status:** VERIFIED — all 36 tests passing, implementation matches ACs
**Handoff:** To Granny Weatherwax (Reviewer) for review phase

### Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
| Severity | Finding | Location |
|----------|---------|----------|
| [VERIFIED] | `get_recovery_actions` correctly scans, filters, orders recovery actions | `gate_recovery.py:22-76` |
| [VERIFIED] | `_is_recoverable` distinguishes missing vs validation errors safely | `gate_recovery.py:148-157` |
| [VERIFIED] | `format_recovery_outcome` handles all 3 outcome paths with correct messages | `gate_recovery.py:79-123` |
| [MEDIUM] | Python module not wired to CLI — SM follows markdown prose, not code | `gate_recovery.py` (whole module) |
| [VERIFIED] | Recovery config consistent across 5 workflow YAMLs | `workflows/*.yaml` |
| [VERIFIED] | SM gate-recovery instructions match Python module behavior | `sm.md:204-255` |
| [LOW] | `path` computed unconditionally even when unused in `created=False` branch | `gate_recovery.py:103` |
| [VERIFIED] | `parse_story_id` strict regex with proper ValueError on invalid input | `gate_recovery.py:126-145` |

**Data flow traced:** Gate subagent check results → `get_recovery_actions` (scan+filter+order) → SM agent invokes `/pf-context create` → `format_recovery_outcome` → user messaging. Pure functions, controlled inputs, no injection vectors.

**Pattern observed:** Clean separation — detection logic in Python (testable), orchestration in agent markdown, config in workflow YAML. Follows existing handoff module patterns.

**Error handling:** Defensive `.get()` calls throughout. Empty/None config returns `[]`. Invalid story IDs raise ValueError. No silent failures.

**Handoff:** To Captain Carrot (SM) for finish-story