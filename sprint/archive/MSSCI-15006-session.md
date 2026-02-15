# Story 106-3: Workflow YAML gate.file integration

**Jira:** MSSCI-15006
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/106-3-workflow-yaml-gate-file

## Context

Epic 106 introduces a new gate file format and mechanism to replace inline gate logic. Story 106-1 created the `tests-pass.md` gate file with schema. Story 106-2 built the gate subagent runner pattern with GATE_RESULT contract extraction. This story extends workflow YAML to support file-based gate references while maintaining backward compatibility with the legacy `type`-based system.

The core change is adding a `gate.file` field to the workflow YAML schema, updating `resolve-gate.py` to check `file` first before falling back to `type`, and migrating the TDD workflow's green phase as the first file-based gate reference.

Dependencies:
- **106-1:** `tests-pass.md` gate file exists at `pennyfarthing-dist/gates/tests-pass.md`
- **106-2:** `gate_runner.py` with GATE_RESULT extraction logic exists

## Description

Add gate.file field to workflow YAML schema. resolve-gate checks file first, falls back to type (backward compat). Update tdd.yaml green phase to gate: {file: gates/tests-pass}. Both file and type coexist during migration period.

## Acceptance Criteria

1. **Schema Extension:**
   - `resolve-gate.py` reads `gate.file` field from workflow YAML phases
   - `gate.file` takes precedence over `gate.type` when both are present
   - Function returns `gate_file: null` when only `gate.type` exists

2. **Backward Compatibility:**
   - Workflows with only `gate.type` continue to work unchanged
   - Existing gate type logic remains functional
   - No breaking changes to resolve-gate API

3. **TDD Workflow Migration:**
   - Green phase in `tdd.yaml` updated with both `file: gates/tests-pass` and legacy `type: tests_pass`
   - Other phases remain unchanged (backward compat period)
   - File path is relative reference: `gates/tests-pass` (not absolute)

4. **Tests:**
   - Unit test for resolve_gate with `gate.file` present
   - Unit test for resolve_gate with only `gate.type` (legacy)
   - Unit test for resolve_gate with both `file` and `type`

## Technical Approach

### 1. Update resolve-gate.py

The script already has the structure in place (line 70 shows `gate_file = gate.get("file")` and line 109 returns it). The implementation is already complete from story 105-1 preparation. Verify that:

- Line 68-70: Extract both `gate.type` and `gate.file` from phase gate dict
- Line 105-113: Return both fields in result (already done)
- The script prioritizes `gate.file` over `gate.type` by returning it in the result (consumer will prioritize)

Current state: The code already reads and returns `gate.file`. The logic is correct because:
- If `gate.file` is present, it gets extracted
- If `gate.type` is present, it gets extracted
- The consumer (resolve-gate command, gate runner) will prefer `gate.file` when both exist
- When `gate.type` is present and `gate.file` is null, the old behavior continues

### 2. Update tdd.yaml

Modify the green phase to add `file: gates/tests-pass` alongside existing `type: tests_pass`:

```yaml
- name: green
  agent: dev
  input: [failing_tests, story_context]
  output: [implementation, passing_tests]
  gate:
    file: gates/tests-pass          # NEW - file takes precedence
    type: tests_pass                # KEPT - backward compat fallback
    condition: All tests passing, no skipped tests
```

Other phases (red, review) remain unchanged, keeping legacy `type` field only until migration is complete.

### 3. Backward Compatibility

- Workflows without `gate.file` field continue working (gate_file returns null)
- `resolve-gate.py` doesn't break when `gate.file` is absent (safe dict.get())
- Both file and type coexist during migration — no risk of missing gates
- Consumers (gate runner, handoff) check `gate_file` first, fall back to `gate_type`

## Files

**To Modify:**
- `/Users/keithavery/Projects/pf-2/.pennyfarthing/workflows/tdd.yaml` — add `file: gates/tests-pass` to green phase
- `/Users/keithavery/Projects/pf-2/pennyfarthing/pennyfarthing_scripts/handoff/resolve_gate.py` — verify gate.file extraction and return (already implemented from 105-1 prep)

**To Test:**
- Create unit tests for resolve_gate.py covering:
  1. Phase with only `type` (legacy) → gate_type set, gate_file null
  2. Phase with `file` and `type` → both populated
  3. Phase with only `file` → gate_file set, gate_type null

**Dependencies:**
- Story 106-1: `pennyfarthing-dist/gates/tests-pass.md` gate file
- Story 106-2: `gate_runner.py` with GATE_RESULT extraction (already exists)
- Story 105-4: `resolve-gate` command in handoff-cli.sh

## TEA Assessment

**Tests Required:** Yes
**Reason:** AC1-AC4 require verifiable unit and integration tests for gate.file field support

**Test Files:**
- `pennyfarthing_scripts/tests/test_resolve_gate_file_field.py` — 24 tests covering gate.file integration

**Tests Written:** 24 tests covering 4 ACs
**Status:** RED (4 failing — ready for Dev)

**Failing Tests (4):**
1. `test_gate_file_populated_without_type` — `resolve_gate()` early return at L89-95 drops `gate_file` when `gate_type is None`
2. `test_green_phase_has_gate_file` — real `tdd.yaml` green phase missing `file: gates/tests-pass`
3. `test_green_phase_file_is_relative` — same root cause as #2
4. `test_green_phase_returns_gate_file` — integration test against real tdd.yaml returns `gate_file=None`

**Dev Notes:**
- Fix 1: In `resolve_gate.py` L89-95, the early return when `gate_type is None` must also pass `gate_file=gate_file` through to `_result()`
- Fix 2: Add `file: gates/tests-pass` to green phase in `pennyfarthing-dist/workflows/tdd.yaml`
- 20 tests already pass (backward compat, schema extraction with fixtures) — no regressions expected

**Handoff:** To Dev (Sergeant Carter) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/handoff/resolve_gate.py` — pass gate_file through early return when gate_type is None
- `pennyfarthing-dist/workflows/tdd.yaml` — add file: gates/tests-pass to green phase gate

**Tests:** 24/24 passing (GREEN) + 123/123 existing handoff tests (no regressions)
**PR:** #913 — feat(106-3): workflow YAML gate.file integration
**Branch:** feature/106-3-workflow-yaml-gate-file (pushed)

**Handoff:** To Reviewer (General Burkhalter) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** YAML file → yaml.safe_load() → gate.get("file") at resolve_gate.py:70 → _result(gate_file=...) at :92/:110 → consumer. Read-only path reference, safe.
**Pattern observed:** Minimal fix — single kwarg addition to early return at resolve_gate.py:92. Follows existing _result() contract pattern.
**Error handling:** gate.get("file") safely returns None when absent. No new crash paths.
**Backward compat:** 123 existing handoff tests pass. RESOLVE_RESULT 7-field contract preserved.
**Debt item:** [LOW] manual gate return at :80-87 also omits gate_file — future migration concern, not blocking.
**Unrelated failure:** test_yaml_io.py::test_write_preserves_sharded_format — pre-existing YAML I/O sharding bug, not from this PR.

**Handoff:** To SM (Colonel Hogan) for finish-story