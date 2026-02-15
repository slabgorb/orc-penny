# Epic 108: Full Migration & Cleanup

**Jira:** (not yet created)
**ADR:** 0025
**Repo:** pennyfarthing
**PRD:** `sprint/planning/gate-prd.md`

## Overview

Migrate all remaining gate types to declarative files. Remove the `handoff.md` and `sm-handoff.md` subagents. Remove the inline `gate.type` fallback from `handoff-cli.sh`. Single code path for phase transitions — no legacy branches.

## Stories

| ID | Title | Pts | Priority | Workflow |
|----|-------|-----|----------|----------|
| 108-1 | Migrate tests-fail and approval gates to files | 2 | P3 | tdd |
| 108-2 | Remove handoff subagents and inline fallback | 2 | P3 | tdd |

## Prerequisite

**Epics 105 + 106** must be complete and validated. All agents must be using the new exit protocol with `handoff-cli.sh`. The TDD green phase must be successfully running with `gates/tests-pass.md`.

## Story 108-1: Migrate Remaining Gates

### Gate Files to Create

| File | Gate Type | Used By | Logic Source |
|------|-----------|---------|-------------|
| `pennyfarthing-dist/gates/tests-fail.md` | `tests_fail` | tdd (red), bdd (red), 2party-tdd (red, review-fix-tea) | `handoff.md` tests_fail branch |
| `pennyfarthing-dist/gates/approval.md` | `approval` | tdd (review), trivial (review), bdd (review), 2party-tdd (multiple) | `handoff.md` approval branch |
| `pennyfarthing-dist/gates/design-review.md` | `design_review` | bdd (design), bdd-tandem (design) | Not in handoff.md — needs definition |
| `pennyfarthing-dist/gates/quality-pass.md` | `quality_pass` | 2party-tdd (verify, review-fix-verify) | Not in handoff.md — silently passes today |
| `pennyfarthing-dist/gates/validation.md` | `validation` | agent-docs (implement) | Not in handoff.md — needs definition |

### Gate Content (Extracted from handoff.md)

**tests-fail.md:**
```xml
<gate name="tests-fail" model="haiku">
  <purpose>
    Verify tests are RED — failing tests exist that cover the acceptance
    criteria. TEA has written tests but implementation hasn't started.
  </purpose>
  <pass>
    Check:
    - Failing tests exist in the test suite
    - Tests cover the acceptance criteria from the session file
    - Tests are committed to the branch
    Return GATE_RESULT with status: pass, list test files
  </pass>
  <fail>
    Check what's missing:
    - No failing tests found → TEA didn't write tests
    - Tests don't cover ACs → incomplete coverage
    - Tests aren't committed → uncommitted work
    Return GATE_RESULT with status: fail, list gaps
  </fail>
</gate>
```

**approval.md:**
```xml
<gate name="approval" model="haiku">
  <purpose>
    Verify the reviewer has issued an explicit verdict on the code review.
  </purpose>
  <pass>
    Check the Reviewer Assessment section in the session file for
    an explicit APPROVED verdict.
    Return GATE_RESULT with status: pass
  </pass>
  <fail>
    Check for:
    - REJECTED verdict → list the findings that need addressing
    - No verdict found → reviewer hasn't completed review
    Return GATE_RESULT with status: fail, include verdict details
  </fail>
</gate>
```

**design-review.md, quality-pass.md, validation.md:** These don't have existing logic in handoff.md. They need to be defined from scratch based on their workflow phase conditions.

### Workflow YAML Updates

Every workflow phase that has `gate.type` gets a corresponding `gate.file`:

**tdd.yaml:**
```yaml
- name: red
  gate:
    file: gates/tests-fail
    type: tests_fail        # kept during transition, removed in 108-2
- name: green
  gate:
    file: gates/tests-pass  # already done in epic 106
    type: tests_pass
- name: review
  gate:
    file: gates/approval
    type: approval
```

**trivial.yaml:**
```yaml
- name: implement
  gate:
    file: gates/tests-pass
    type: tests_pass
- name: review
  gate:
    file: gates/approval
    type: approval
```

**bdd.yaml:**
```yaml
- name: design
  gate:
    file: gates/design-review
    type: design_review
- name: red
  gate:
    file: gates/tests-fail
    type: tests_fail
- name: green
  gate:
    file: gates/tests-pass
    type: tests_pass
- name: review
  gate:
    file: gates/approval
    type: approval
```

Same pattern for: `tdd-tandem.yaml`, `bdd-tandem.yaml`, `2party-tdd.yaml`, `agent-docs.yaml`

---

## Story 108-2: Remove Handoff Subagents and Inline Fallback

### Files to Delete

| File | Reason |
|------|--------|
| `pennyfarthing-dist/agents/handoff.md` | Replaced by handoff-cli.sh + gate files |
| `pennyfarthing-dist/agents/sm-handoff.md` | Replaced by handoff-cli.sh + gate files |

### Code to Remove

**In `handoff-cli.sh resolve-gate`:**
Remove the `gate.type` fallback branch. After this change, `resolve-gate` only resolves via `gate.file`. Unknown or missing gate files return `status: blocked`.

```bash
# BEFORE (with fallback):
GATE_FILE=$(yq "... .gate.file" "$WORKFLOW_FILE")
if [ "$GATE_FILE" != "null" ]; then
  resolve_gate_file "$GATE_FILE"
else
  # Fallback to inline type
  GATE_TYPE=$(yq "... .gate.type" "$WORKFLOW_FILE")
  # ... inline logic
fi

# AFTER (no fallback):
GATE_FILE=$(yq "... .gate.file" "$WORKFLOW_FILE")
if [ "$GATE_FILE" == "null" ] || [ -z "$GATE_FILE" ]; then
  echo "ERROR: No gate.file defined for phase $PHASE" >&2
  exit 1
fi
resolve_gate_file "$GATE_FILE"
```

**In workflow YAML files:**
Remove `gate.type` lines (only `gate.file` remains):

```yaml
# BEFORE:
gate:
  file: gates/tests-pass
  type: tests_pass
  condition: "All tests passing"

# AFTER:
gate:
  file: gates/tests-pass
  condition: "All tests passing"
```

**In agent files:**
Verify no agent file still references `handoff` or `sm-handoff` subagent.

### Cyclist TypeScript Layer

**File:** `packages/cyclist/src/` — check for `checkGate()` in handoff-related code.

If Cyclist has TypeScript gate logic (from `handoff.ts` or `gate-handler.ts`), evaluate:
- If it's only used by the now-removed inline gate system → remove
- If it's used by stepped workflows → keep (ADR-0025 only addresses phased workflows)

### Verification Checklist

Before shipping 108-2:
- [ ] All workflow YAMLs use `gate.file` (no `gate.type` remaining)
- [ ] `handoff.md` and `sm-handoff.md` deleted
- [ ] No agent file references handoff/sm-handoff subagent
- [ ] `handoff-cli.sh resolve-gate` has no `gate.type` fallback
- [ ] All existing workflows pass end-to-end (TDD, trivial, BDD at minimum)
- [ ] `pf gate validate` passes on all built-in gate files

## Complete Gate File Inventory (After Migration)

```
pennyfarthing-dist/gates/
  tests-pass.md       # Created in epic 106
  tests-fail.md       # Created in 108-1
  approval.md         # Created in 108-1
  design-review.md    # Created in 108-1
  quality-pass.md     # Created in 108-1
  validation.md       # Created in 108-1
```

## Dependencies

- **Blocked by:** Epic 105 (script infrastructure), Epic 106 (gate file format + first migration)
- **Soft dependency on:** Epic 107 (validation command useful but not required)
- **Blocks:** Nothing — this is the final cleanup epic

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Removing fallback breaks a workflow we missed | High | Grep all workflow YAMLs for `gate.type` without `gate.file`; test all workflows |
| Deleting handoff.md breaks references elsewhere | Medium | Grep entire codebase for `handoff.md` and `sm-handoff.md` references |
| Stepped workflow gates affected | Low | ADR-0025 explicitly scopes to phased only; verify stepped workflows untouched |
| design-review and quality-pass gates untested | Medium | These gate types have no existing logic — define carefully, test manually |
