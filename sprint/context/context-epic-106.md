# Epic 106: Gate Files & First Migration

**Jira:** (not yet created)
**ADR:** 0025
**Repo:** pennyfarthing
**PRD:** `sprint/planning/gate-prd.md`

## Overview

Create the gate file format and the first gate file (`tests-pass.md`). Build a gate subagent runner that spawns a haiku Task to evaluate gate criteria. Extend workflow YAML to support `gate.file` references alongside legacy `gate.type`. Migrate TDD's green phase as the first file-based gate.

## Stories

| ID | Title | Pts | Priority | Workflow |
|----|-------|-----|----------|----------|
| 106-1 | Create tests-pass gate file with schema | 1 | P1 | trivial |
| 106-2 | Gate subagent runner with GATE_RESULT contract | 3 | P1 | tdd |
| 106-3 | Workflow YAML gate.file integration | 2 | P1 | tdd |
| 106-4 | Gate file discovery and resolution | 1 | P1 | trivial |

## Prerequisite

**Epic 105** must be complete — `handoff-cli.sh` with `resolve-gate` and `complete-phase`, and the new agent exit protocol. This epic extends `resolve-gate` to return `gate_file` paths and adds the gate subagent as step 6 in the exit protocol.

## Gate File Schema

From ADR-0025, gate files are markdown with XML-tagged blocks:

```xml
<gate name="tests-pass" model="haiku">
  <purpose>
    Verify that all tests pass and working tree is clean before
    handing off to the reviewer.
  </purpose>

  <pass>
    Instructions for what to check and how to report success.
    - Run the test suite
    - Check working tree is clean
    - Report test count and coverage
    Return GATE_RESULT with status: pass
  </pass>

  <fail>
    Instructions for what to report on failure.
    - List failing test files and line numbers
    - List uncommitted files
    - Suggest recovery steps
    Return GATE_RESULT with status: fail
  </fail>
</gate>
```

**Required elements:** `<gate name="...">`, `<purpose>`, `<pass>`, `<fail>`
**Optional attributes:** `model` (default: haiku)
**Optional elements:** Nested `<gate>` blocks (max depth 3, validated in epic 107)

## Existing Infrastructure

### Workflow YAML Phase Schema (Current)

```yaml
# pennyfarthing-dist/workflows/tdd/workflow.yaml
phases:
  - name: green
    agent: dev
    gate:
      type: tests_pass
      condition: "All tests passing, no skipped tests"
```

### Inline Gate Logic (Current — in handoff.md)

The handoff subagent has hardcoded branches per gate type:

```
if gate_type == "tests_pass":
  - Verify all tests passing
  - Check working tree clean
  - Check PR exists
elif gate_type == "tests_fail":
  - Verify tests are RED
  - Check test coverage of ACs
elif gate_type == "approval":
  - Check reviewer verdict
elif gate_type == "manual":
  - Always pass
```

This inline logic is what gate files replace.

### Gate Subagent Pattern (New)

The gate file content becomes the **prompt** for a haiku Task subagent:

```
Agent calls: Task tool
  subagent_type: "general-purpose"
  model: "haiku"  (or from gate file's model attribute)
  prompt: |
    You are a gate evaluator. Read the gate definition below and
    evaluate whether the gate passes or fails.

    {gate file content}

    Session context:
    {relevant session excerpts}

    Return your evaluation as:
    GATE_RESULT:
      status: pass | fail
      message: "summary"
      checks:
        - name: "check name"
          status: pass | fail
          detail: "specifics"
```

## Story 106-1: Create tests-pass Gate File

### File to Create

`pennyfarthing-dist/gates/tests-pass.md`

### Content Guidance

The `<pass>` block should instruct the evaluator to:
1. Use the `testing-runner` approach — run the project test suite
2. Check that working tree is clean (`git status --porcelain`)
3. Report: test count, pass/fail counts, branch name
4. Return `GATE_RESULT` with `status: pass`

The `<fail>` block should instruct the evaluator to:
1. List failing test files with line numbers
2. List uncommitted/untracked files
3. Suggest: "Fix failing tests" or "Commit changes before handoff"
4. Return `GATE_RESULT` with `status: fail`

### Directory Structure

```
pennyfarthing-dist/
  gates/                    # NEW directory
    tests-pass.md           # First gate file
```

The `gates/` directory will be symlinked like other dist directories:
`.pennyfarthing/gates/` → `pennyfarthing-dist/gates/`

---

## Story 106-2: Gate Subagent Runner

### Where It Lives

The gate subagent runner is **not a script** — it's a pattern that agents follow in step 6 of the exit protocol. The agent reads the gate file and spawns a Task subagent.

However, a helper script could assist with gate file content extraction:

**Option A (recommended):** Agent reads gate file directly, constructs prompt, spawns Task
**Option B:** Shell script `gate-runner.sh` that outputs the prompt template

### GATE_RESULT Contract

```yaml
GATE_RESULT:
  status: pass | fail
  message: "All 47 tests passing, working tree clean"
  checks:
    - name: "test-suite"
      status: pass
      detail: "47/47 tests passing"
    - name: "working-tree"
      status: pass
      detail: "No uncommitted changes"
```

### Extraction Pattern

Agent extracts GATE_RESULT via regex/grep, not a full YAML parser:

```bash
# From subagent output, extract the GATE_RESULT block
GATE_STATUS=$(echo "$RESULT" | grep -A1 "GATE_RESULT:" | grep "status:" | awk '{print $2}')
```

### Default-Deny

If the gate subagent crashes, times out, or returns no parseable `GATE_RESULT`:
- Treat as `status: fail`
- Max 3 retries before blocking

### Model Inheritance

- Gate file has `model="haiku"` → use haiku
- Gate file has `model="sonnet"` → use sonnet
- Gate file has no `model` attribute → default to haiku
- Nested gates: child inherits parent's model unless overridden

---

## Story 106-3: Workflow YAML gate.file Integration

### Schema Extension

```yaml
# Before (current)
gate:
  type: tests_pass
  condition: "All tests passing"

# After (with file support)
gate:
  file: gates/tests-pass        # NEW - takes precedence
  type: tests_pass               # legacy fallback
  condition: "All tests passing"
```

### resolve-gate Changes

Update `handoff-cli.sh resolve-gate` to:
1. Check for `gate.file` first (new field)
2. If present, resolve to full path and return in `gate_file` field
3. If absent, fall back to `gate.type` (existing behavior)

```bash
GATE_FILE=$(yq ".workflow.phases[] | select(.name == \"$PHASE\") | .gate.file" "$WORKFLOW_FILE")
if [ "$GATE_FILE" != "null" ] && [ -n "$GATE_FILE" ]; then
  # Resolve gate file path (106-4 handles discovery)
  RESOLVED_PATH=$(resolve_gate_file "$GATE_FILE")
fi
```

### First Migration Target

Update `tdd.yaml` green phase only:

```yaml
# pennyfarthing-dist/workflows/tdd/workflow.yaml
- name: green
  agent: dev
  gate:
    file: gates/tests-pass          # NEW
    type: tests_pass                 # kept for backward compat
    condition: "All tests passing, no skipped tests"
```

### Backward Compatibility

- Workflows with only `gate.type` continue to work unchanged
- `gate.file` takes precedence when both are present
- `resolve-gate` returns `gate_file: null` when only `gate.type` exists

---

## Story 106-4: Gate File Discovery and Resolution

### Resolution Order

1. `.pennyfarthing/gates/{name}.md` — project-local override
2. `pennyfarthing-dist/gates/{name}.md` — built-in (via symlink, same as #1 unless overridden)

### Implementation

In `handoff-cli.sh` (or a helper function):

```bash
resolve_gate_file() {
  local gate_ref="$1"   # e.g., "gates/tests-pass"
  local name="${gate_ref#gates/}"  # strip prefix
  local root=$(find_project_root)

  # Project-local first
  local local_path="$root/.pennyfarthing/gates/${name}.md"
  if [ -f "$local_path" ]; then
    echo "$local_path"
    return 0
  fi

  # Built-in fallback (for non-symlinked setups)
  local builtin_path="$root/pennyfarthing-dist/gates/${name}.md"
  if [ -f "$builtin_path" ]; then
    echo "$builtin_path"
    return 0
  fi

  echo "ERROR: Gate file not found: ${name}" >&2
  return 1
}
```

### Symlink Setup

Follow existing pattern — `pennyfarthing-dist/gates/` gets symlinked:

```
.pennyfarthing/gates/ → pennyfarthing-dist/gates/
```

This means in practice, `.pennyfarthing/gates/tests-pass.md` resolves through the symlink to `pennyfarthing-dist/gates/tests-pass.md`. Projects can break the symlink to provide local overrides.

### Files to Modify

| File | Change |
|------|--------|
| `packages/core/src/commands/init.ts` | Add `gates/` to symlink list |
| `packages/core/src/commands/update.ts` | Add `gates/` to symlink update |

## Dependencies

- **Blocked by:** Epic 105 (handoff-cli.sh must exist)
- **Blocks:** Epic 107 (validation operates on gate file format created here)
- **Blocks:** Epic 108 (remaining gate files follow the pattern established here)

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Gate file prompt too vague for haiku | Medium | Test with real scenarios, iterate on `<pass>`/`<fail>` instructions |
| GATE_RESULT extraction regex fragile | Medium | Use simple, strict patterns; default-deny on parse failure |
| Symlink setup missed in init/update | Low | Follow exact pattern of existing symlinks (agents, scripts, etc.) |
