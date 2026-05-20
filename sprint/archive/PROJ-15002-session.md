# Story 105-3: End-to-end handoff smoke test

**Jira:** PROJ-15002
**Epic:** PROJ-14999
**Points:** 1
**Workflow:** trivial
**Phase:** finish
**Repos:** orchestrator, pennyfarthing
**Branch:** feature/PROJ-15002-e2e-handoff-smoke-test

---

## Description

Verify TDD handoff works with new script-based exit flow. Test resolve-gate returns status:ready for green phase with assessment, gate subagent evaluates tests_pass (inline fallback), complete-phase updates session, handoff-marker emits correct marker. Also verify trivial workflow skips gate (status:skip) with no LLM spawn.

## Acceptance Criteria

- [ ] resolve-gate returns status:ready for green phase with assessment written
- [ ] Gate subagent evaluates tests_pass using inline fallback
- [ ] complete-phase updates session file phase correctly
- [ ] handoff-marker emits correct CYCLIST marker
- [ ] Trivial workflow skips gate (status:skip) with no LLM spawn

## Technical Context

### Script-First Gate Extraction (ADR-0025)

The new handoff system replaces the handoff subagent with bash scripts and LLM-only gate evaluation:

**Agent Exit Protocol (7-step sequence):**
1. Write assessment to session file
2. Terminate tandem backseat (if active)
3. Call `handoff-cli.sh resolve-gate` → returns RESOLVE_RESULT (status: ready|skip|blocked)
4. If skip → jump to step 6. If ready → spawn gate subagent to evaluate pass/fail criteria
5. If fail → fix + retry. If pass → continue
6. Call `handoff-cli.sh complete-phase` → atomically update session (temp file + mv)
7. Call `handoff-marker.sh {next_agent}` → emit CYCLIST marker → EXIT

**Key Components:**

- `handoff-cli.sh resolve-gate` — Pure bash. Finds gate file, pre-checks assessment section, returns RESOLVE_RESULT YAML with status (ready|blocked|skip), gate_type, next_agent, next_phase
- `handoff-cli.sh complete-phase` — Pure bash. Atomically updates session file with phase transition, timestamps, and history tables using temp file + mv
- Gate subagent — Haiku-only LLM spawn (if gate status is "ready"). Evaluates pass/fail criteria from gate file. Returns GATE_RESULT with status (pass|fail)
- `handoff-marker.sh` — Generates environment-aware CYCLIST marker for next agent

**RESOLVE_RESULT Schema:**
```yaml
status: ready | blocked | skip
gate_type: tests_pass | tests_fail | approval | manual
gate_file: .pennyfarthing/gates/tests-pass.md
next_agent: dev | tea | reviewer | sm
next_phase: green | review | approved | finish
assessment_found: true | false
error: null | "message"
```

**Gate file resolution order:**
1. `.pennyfarthing/gates/{name}.md` (project-local)
2. `pennyfarthing-dist/gates/{name}.md` (built-in)
3. Inline type fallback (migration compatibility)

**Trivial Workflow Short-Circuit:**
Trivial workflows skip gate evaluation entirely. `resolve-gate` returns `status:skip` with no LLM spawn, jumping directly to `complete-phase`.

## Implementation Notes

Single test file: `pennyfarthing_scripts/tests/test_handoff_e2e.py`

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/tests/test_handoff_e2e.py` - 24 e2e smoke tests covering all 5 ACs

**Tests:** 24/24 passing (GREEN), 53/53 existing handoff tests unchanged
**PR:** #907 - test(handoff): e2e smoke tests for handoff flow [PROJ-15002]
**Branch:** feature/PROJ-15002-e2e-handoff-smoke-test (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** resolve_gate output dict → complete_phase parameters → session file update → readback verification (TestFullChainE2E, safe — file ops confined to tmp_path)
**Pattern observed:** Test classes map 1:1 to ACs with dedicated assertions at test_handoff_e2e.py:161-468
**Error handling:** pytest.skip on missing marker script (line 361), success/error checked on every complete_phase call
**Observations:** 2 LOW (workflow data duplication, indirect timestamp assertion) — no blocking issues
**Preflight:** 24/24 new + 53/53 existing = 77/77 GREEN, no forbidden patterns

**Handoff:** To SM for finish-story

---

## Session History

| Phase | Agent | Timestamp | Status |
|-------|-------|-----------|--------|
| setup | sm-setup | 2026-02-15 | completed |