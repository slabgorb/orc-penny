# Story 86-1: Workflow schema: tandem: block

**Jira:** PROJ-14496
**Epic:** 86 — Agent Collaboration — Tandem to Teams
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** story/86-1-workflow-schema-tandem-block
**Assigned:** slabgorb@gmail.com

---

## Acceptance Criteria
- [ ] `tandem:` block parsed from workflow YAML phases
- [ ] Properties: `partner`, `mode`, `model`, `token_budget`, `triggers`
- [ ] Schema validation: unknown modes rejected, `consultation` accepted
- [ ] Backward compatible: existing workflows without `tandem:` unchanged
- [ ] `workflow-status-check` subagent reports tandem configuration

## Key Files
- `pennyfarthing-dist/workflows/*.yaml` (schema extension)
- `pennyfarthing-dist/agents/workflow-status-check.md` (update)

## Technical Context
This is the first story in Epic 86 (Agent Collaboration — Tandem to Teams). It extends BikeLane workflow YAML schema to support `tandem:` configuration blocks on phases, per ADR-0012.

The `tandem:` block allows phases to specify a consultation partner agent:
```yaml
phases:
  - name: green
    agent: dev
    tandem:
      partner: architect
      mode: consultation
      model: sonnet
      token_budget: 1000
      triggers:
        - request: true
        - complexity: high
```

Properties: partner (agent name), mode (consultation), model (sonnet/haiku), token_budget (max tokens), triggers (when to activate).

Backward compatibility is critical — existing workflows without `tandem:` must continue unchanged.

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Schema validation story — needs comprehensive test coverage for YAML parsing, property validation, mode enforcement, backward compat, and config extraction.

**Test Files:**
- `tests/python/test_tandem_schema.py` — 28 tests covering all 5 ACs

**Tests Written:** 28 tests covering 5 ACs
**Status:** RED (12 failing on assertions, 16 passing for backward compat)

**Failure Breakdown:**
- AC1 (parsing): 1 fail — tandem block type validation missing
- AC2 (properties): 8 fails — partner required, partner cross-ref, model validation, token_budget validation (positive int), triggers list type
- AC3 (mode validation): 1 fail — unknown mode rejection not implemented
- AC4 (backward compat): 0 fails — all 5 backward compat tests PASS
- AC5 (config extraction): 2 fails — `get_phase_tandem_config()` stub returns None

**Stubs Added:**
- `VALID_TANDEM_MODES` and `VALID_TANDEM_MODELS` constants in `validate/adapters/workflow.py`
- `get_phase_tandem_config()` stub in `prime/workflow.py`

**Implementation Notes for Dev:**
1. Extend `validate_phased()` in `validate/adapters/workflow.py` to validate tandem blocks on phases
2. Implement `get_phase_tandem_config()` in `prime/workflow.py` to extract tandem config from workflow YAML
3. Existing `tdd-tandem.yaml` and `bdd-tandem.yaml` use `partner`+`scope` only — mode must be optional for backward compat

**Handoff:** To Sergeant Carter (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/validate/adapters/workflow.py` - Added tandem block validation in validate_phased(): type check, partner required + cross-ref, mode validation, model warning, token_budget positive int, triggers list type
- `pennyfarthing_scripts/prime/workflow.py` - Implemented get_phase_tandem_config() to read workflow YAML and extract tandem dict for a given phase

**Tests:** 28/28 passing (GREEN)
**PR:** #921 — feat(86-1): workflow schema tandem block validation
**Branch:** story/86-1-workflow-schema-tandem-block (pushed)

**Handoff:** To General Burkhalter (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
- `[VERIFIED]` bool guard on token_budget correctly excludes YAML booleans at `workflow.py:215`
- `[VERIFIED]` Falsy check for required partner field at `workflow.py:184`
- `[VERIFIED]` Mode optional for backward compat at `workflow.py:197-202`
- `[VERIFIED]` Shallow copy via `dict(tandem)` at `prime/workflow.py:311`
- `[MEDIUM]` Missing `.pennyfarthing/workflows/` fallback in `get_phase_tandem_config` at `prime/workflow.py:298-300` — inconsistent with sibling `get_phase_owner()`. Non-blocking: degrades gracefully, runtime wiring out of scope.
- `[VERIFIED]` Reuses `_check_agent_ref` helper — consistent with existing patterns
- `[VERIFIED]` Backward compat tests with real workflow files — no regressions

**Data flow traced:** Workflow YAML (tandem block) → `validate_phased()` validates structure → `get_phase_tandem_config()` extracts for runtime. Safe: validation is pure (no side effects), extraction returns copy.
**Pattern observed:** Tandem validation follows existing gate validation pattern (same loop, same error/warning distinction) at `workflow.py:173-229`
**Error handling:** `get_phase_tandem_config` returns None on all failure paths (missing file, bad YAML, missing phase) — safe fallback at `prime/workflow.py:300-316`

**Handoff:** To Colonel Hogan (SM) for finish-story