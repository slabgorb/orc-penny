# Story 141-23: Add actionable fix instructions to all validators that can halt agents

**Session ID:** 141-23
**JIRA:** MSSCI-16160
**Title:** Add actionable fix instructions to all validators that can halt agents
**Points:** 3
**Priority:** P1
**Status:** in_progress
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/validator-fix-instructions
**Assignee:** keith.avery@1898andco.io

## Story Description

Audit all validators/gates/hooks in the pennyfarthing system that can halt an agent's work. For each validation failure, add actionable fix instructions so the agent can self-correct and continue instead of dead-ending.

Current state: Validators reject invalid input but provide minimal guidance on how to fix the issue. This forces agents to guess at corrections or escalate to the human operator.

Target state: Every validator error message includes specific, actionable instructions that agents can follow to resolve the issue and retry their work.

## Acceptance Criteria

1. All validators that can halt agents are identified and cataloged
2. Each validator produces error messages with specific fix instructions
3. Fix instructions are actionable — agents can follow them to resolve the issue
4. Tests verify that error messages include fix guidance

## Technical Approach

Survey key validation points:
- **PreToolUse hooks** — validators that check tool invocations before execution
- **Gate checks** — validators in `resolve-gate` and phase transition gates
- **Schema validators** — input validation for story/sprint/workflow data
- **Handoff validators** — assessment format and session state validation
- **CLI validators** — command argument and option validation

For each validator:
1. Identify failure modes (what can go wrong?)
2. Generate actionable fix instructions (what should the user do?)
3. Update error messages to include "To fix:" section
4. Add tests that verify error message structure and guidance

Example pattern:
```
Error: Validator 'schema' failed for input
  Field: title
  Reason: Title is empty
  To fix: Provide a non-empty string between 3 and 255 characters
```

## Key Files to Review

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/src/pf/hooks/pre-tool-use.py` | PreToolUse hook validators |
| `pennyfarthing-dist/src/pf/gates/` | Gate validation logic |
| `pennyfarthing-dist/src/pf/schemas/` | Schema validators |
| `packages/core/src/validation/` | TypeScript validators |
| `pennyfarthing-dist/scripts/lib/validators.sh` | Bash validation utilities |

## References

- ADR: Validator Error Message Standards (to be created)
- Epic 141: Agent Reliability and Recovery

## Workflow: tdd

Flow:
1. SM (setup) → Create session, branch, context
2. TEA (red) → Design tests for validator error messages
3. Dev (green) → Add fix instructions to validators
4. TEA (verify) → Verify tests passing and coverage complete
5. Reviewer (review) → Code review and approval
6. SM (finish) → Merge and archive session

## Context Links

- Parent Epic: 141 — Agent Reliability and Recovery
- Related Stories: 141-22 (gate recovery patterns), 141-24 (validator framework improvements)

---

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)

- **Improvement** (non-blocking): `pre_edit_check.py` protected-pattern blocks (`.env`, `.pem`, etc.) have no fix instructions — only the managed-pennyfarthing case does. Affects `pennyfarthing-dist/src/pf/hooks/pre_edit_check.py` (add per-pattern guidance). *Found by TEA during test design.*
- **Gap** (non-blocking): `resolve_gate.py` doesn't discover available workflows when reporting "not found" — needs to glob `workflows/*.yaml`. Affects `pennyfarthing-dist/src/pf/handoff/resolve_gate.py` (add workflow discovery). *Found by TEA during test design.*
- **Improvement** (non-blocking): `complete_phase.py` assessment error says "write your assessment" but doesn't specify the `## {Agent} Assessment` heading format the regex expects. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py` (include heading format in error). *Found by TEA during test design.*

### Dev (implementation)

- No upstream findings during implementation.

## SM Assessment (setup phase)

Story 141-23 is set up and ready for TEA. Session file created, branch `feat/validator-fix-instructions` cut from develop, Jira MSSCI-16160 claimed and In Progress. Context document written at `sprint/context/context-story-141-23.md`.

**Scope:** Broad audit of all validators that can halt agents — PreToolUse hooks, gate checks, schema validators, handoff validators, CLI validators. Each must produce actionable fix instructions on failure.

**Routing:** TDD workflow, 3 points. Sam Seaborn (TEA) takes the red phase to design tests for validator error messages before implementation begins.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Every validator error message must include actionable fix instructions

**Test Files:**
- `tests/python/test_validator_fix_instructions.py` - 34 tests covering all 6 validator categories

**Tests Written:** 34 tests covering 4 ACs
**Status:** RED (31 failing, 3 passing — all failures are assertion-based, not import errors)

**Validator Categories Tested:**
1. **Schema validation hook** (11 tests) — session, skill, step file schema errors
2. **Resolve gate** (3 tests) — workflow-not-found, phase-not-found, parse errors
3. **Complete phase** (2 tests) — missing assessment, missing session
4. **Sprint validator** (11 tests) — missing fields, bad types, invalid formats
5. **Pre-edit check** (2 tests) — protected patterns, managed files
6. **Independence check** (3 tests) — file overlaps, affected units, decomposition
7. **Cross-cutting** (2 tests) — format consistency across all error types

**Key Files for Dev (GREEN phase):**
- `pennyfarthing-dist/src/pf/hooks/schema_validation.py` — add "To fix:" to each `_validate_*` error
- `pennyfarthing-dist/src/pf/handoff/resolve_gate.py` — list available workflows/phases in errors
- `pennyfarthing-dist/src/pf/handoff/complete_phase.py` — describe `## Assessment` heading format
- `pennyfarthing-dist/src/pf/sprint/validator.py` — add "To fix:" to missing field / bad format errors
- `pennyfarthing-dist/src/pf/hooks/pre_edit_check.py` — add fix guidance for protected patterns
- `pennyfarthing-dist/src/pf/preflight/independence.py` — add resolution guidance for overlaps

**Handoff:** To Toby Ziegler (Dev) for GREEN phase implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/hooks/schema_validation.py` - Added "To fix:" with examples to all session, skill, and step validation errors
- `pennyfarthing-dist/src/pf/handoff/resolve_gate.py` - Lists available workflows/phases on not-found errors, added `_list_available_workflows` helper
- `pennyfarthing-dist/src/pf/handoff/complete_phase.py` - Describes `## {Agent} Assessment` heading format, guides to `/pf-sm` for missing sessions
- `pennyfarthing-dist/src/pf/sprint/validator.py` - Added "To fix:" with examples to all missing field, bad type, invalid format errors
- `pennyfarthing-dist/src/pf/hooks/pre_edit_check.py` - Added per-pattern fix hints via `_PATTERN_FIX_HINTS` map
- `pennyfarthing-dist/src/pf/preflight/independence.py` - Shows overlapping files with unit IDs and decomposition guidance

**Tests:** 34/34 passing (GREEN)
**Branch:** feat/validator-fix-instructions (pushed)

**Handoff:** To TEA for verify phase

## TEA Assessment (verify phase)

**Tests:** 34/34 passing (GREEN confirmed)

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 7

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | clean | 0 |
| simplify-quality | clean | 0 |
| simplify-efficiency | 8 findings | All minor, pre-existing patterns |

**Applied:** 0 (no high-confidence fixes)
**Flagged for Review:** 0 medium-confidence
**Noted:** 8 low/minor observations (pre-existing code patterns, not introduced by this story)

**Overall:** simplify: clean

**Handoff:** To Josh Lyman (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**PR:** #1267 — feat(141-23): add fix instructions to all validators

**Review Notes:**
- All changes are error message text updates with "To fix:" + backtick examples
- No logic changes to any validator — zero regression risk
- One new helper `_list_available_workflows` in resolve_gate — simple directory glob
- 34/34 tests passing, simplify clean across all three lenses

**Handoff:** To Leo McGarry (SM) for finish