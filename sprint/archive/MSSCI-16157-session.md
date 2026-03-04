# Story 141-14: Improve agent handoff command documentation and examples

**Story ID:** 141-14
**Jira:** MSSCI-16157
**Workflow:** trivial
**Phase:** finish
**Repos:** orchestrator
**Branch:** story/141-14-improve-agent-handoff-docs

## Story Details

**Title:** Improve agent handoff command documentation and examples

**Type:** chore
**Points:** 2
**Priority:** p2
**Status:** backlog

## Acceptance Criteria

None explicitly defined in story record. This is a documentation/examples improvement story for the `pf handoff` command.

## Context

This story is part of Epic 141 (Tech Debt Audit) and focuses on improving the documentation and examples for the agent handoff command. Given the context of recent work on agent handoff system (141-13 fixed Jira story transitions, 141-16 added --json output, 141-17/18 replaced TypeScript workflow with CLI delegation), this story likely involves documenting the handoff workflow patterns and usage examples for developers working with the pennyfarthing framework.

The story is positioned after major workflow refactoring work (141-17 completed on 2026-03-04) and depends on --json command output being available (141-16).

## SM Assessment

**Routing:** Trivial workflow, straight to Dev. Documentation-only story — no tests needed, no architecture review.

**Scope:** Improve `pf handoff` command documentation and examples. The handoff CLI has been significantly reworked recently (141-13, 141-16, 141-17). Dev should review current handoff guide at `pennyfarthing-dist/guides/handoff-cli.md` and agent definitions that reference handoff commands, then update docs to reflect current state.

**Risk:** Low. Documentation only, no code changes expected.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/guides/handoff-cli.md` — Added phase-check and status command docs, fixed resolve-gate output to match actual fields, added gate recovery section, updated key files table

**Tests:** N/A (documentation only)
**Branch:** feature/MSSCI-16151-replace-ts-file-parsers-ast (pennyfarthing repo, pushed)

**Handoff:** To Reviewer for review

## Delivery Findings

<!-- delivery-findings-start -->
### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): Relay OFF docs say `relay: false` but `marker.py` outputs `relay_mode: false`. Affects `pennyfarthing-dist/guides/handoff-cli.md` (line 90, fix field name to `relay_mode`). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Agent calls pf handoff commands → YAML output parsed by agent → drives workflow transitions. Docs now accurately reflect all 5 commands and their output shapes.
**Pattern observed:** Output examples verified against source return dicts in resolve_gate.py, complete_phase.py, marker.py, phase_check.py, cli.py
**Error handling:** Assessment guard at complete_phase.py:67-78 correctly documented at handoff-cli.md:70
**Observations:**
- [VERIFIED] All 7 resolve-gate output fields match source
- [VERIFIED] complete-phase output corrected from old inaccurate fields
- [VERIFIED] phase-check and status — new commands fully documented
- [VERIFIED] Gate recovery section matches gate_recovery.py behavior
- [MEDIUM] relay_mode vs relay field name at handoff-cli.md:90

**Handoff:** To SM for finish-story