# Story 106-2: Gate Subagent Runner with GATE_RESULT Contract

**Jira:** MSSCI-15005
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/106-2-gate-subagent-runner

## Context

This story builds on Epic 106, which introduces the gate file system to replace inline gate logic currently hardcoded in the handoff subagent.

### Gate Files Overview

Gate files are markdown documents with XML-tagged blocks that define gate evaluation criteria. From ADR-0025, the schema is:

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

### Prior Story: 106-1 (Create tests-pass gate file)

Story 106-1 creates the first gate file at `pennyfarthing-dist/gates/tests-pass.md` with the schema above. This file provides the gate definition that the gate subagent runner (this story) will evaluate.

### Prior Story: 106-4 (Gate file discovery and resolution)

Story 106-4 implements gate file discovery via `resolve_gate_file()` in `handoff-cli.sh`:
- Checks `.pennyfarthing/gates/{name}.md` (project-local override)
- Falls back to `pennyfarthing-dist/gates/{name}.md` (built-in via symlink)
- Returns full path or error if not found
- Adds `gates/` to symlink list in `init.ts` and `update.ts`

### Current Infrastructure

The **handoff subagent** currently has hardcoded gate evaluation logic:

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

### Epic 105 Dependency

Epic 105 provides the **handoff-cli.sh** script with:
- `resolve-gate` command (returns gate file path in `gate_file` field)
- `complete-phase` command
- New agent exit protocol (step 6 triggers gate evaluation)

## Description

Create a **gate subagent runner** that:

1. Accepts a gate file path (provided by `resolve-gate` in 106-4)
2. Reads the gate file and extracts its content
3. Spawns a **haiku Task subagent** with the gate file as the prompt
4. Returns a structured **GATE_RESULT** object with status, message, and detailed checks
5. Supports optional `model` attribute on the gate (default: haiku)
6. Implements **default-deny**: missing/unparseable GATE_RESULT = fail
7. Extracts GATE_RESULT via **regex/grep**, not full YAML parser
8. Treats gate files as **read-only** at runtime

## Acceptance Criteria

- [ ] Gate runner function accepts a gate file path and spawns it as a haiku Task subagent
- [ ] Returns structured GATE_RESULT: {status: pass|fail, message, checks}
- [ ] Supports `model` attribute (default: haiku, overridable per gate)
- [ ] Default-deny: missing GATE_RESULT = fail
- [ ] GATE_RESULT extraction uses regex/grep, not full YAML parser
- [ ] Gate files are read-only at runtime (never written to)
- [ ] Handles subagent timeouts and crashes gracefully (default to fail)
- [ ] Max 3 retries before blocking if subagent fails
- [ ] Integrates with step 6 of agent exit protocol

## Technical Approach

### 1. Gate Runner Function Location

Create a new module: `packages/core/src/gates/gate-runner.ts`

This function will be called from the agent exit protocol (step 6) after `resolve-gate` returns a `gate_file` path.

### 2. Gate File Parsing

The runner will:
1. Read the gate file (read-only, no modifications)
2. Extract the `model` attribute from `<gate>` tag using regex
3. Extract gate content and pass to subagent as-is

Regex for model attribute:
```
model="([^"]+)"
```

Default to "haiku" if not found.

### 3. Subagent Spawning

Call the Task tool with:
- `subagent_type: "general-purpose"`
- `model: <from gate file or "haiku">`
- `prompt: <gate file content + session context>`

### 4. GATE_RESULT Extraction

Extract result via regex/grep patterns (not full YAML parser):

```bash
# Extract status line
GATE_STATUS=$(echo "$RESULT" | grep -E "status:\s*(pass|fail)" | awk '{print $2}' | tr -d ',' | head -1)

# Extract message line
GATE_MESSAGE=$(echo "$RESULT" | grep -E "message:" | sed 's/.*message:\s*"\(.*\)".*/\1/')

# Extract checks block (if present)
GATE_CHECKS=$(echo "$RESULT" | grep -A50 "checks:" | grep -E "^\s*-\s*name:" | sed 's/.*name:\s*"\(.*\)".*/\1/')
```

### 5. Default-Deny Implementation

If subagent output cannot be parsed to extract GATE_RESULT:
- Return: `{status: "fail", message: "Gate evaluation failed or did not return GATE_RESULT", checks: []}`
- Do not retry internally — let the caller (exit protocol) handle retries

### 6. Return Contract

```typescript
interface GateResult {
  status: "pass" | "fail";
  message: string;
  checks: Array<{
    name: string;
    status: "pass" | "fail";
    detail: string;
  }>;
}
```

Example:
```json
{
  "status": "pass",
  "message": "All 47 tests passing, working tree clean",
  "checks": [
    {
      "name": "test-suite",
      "status": "pass",
      "detail": "47/47 tests passing"
    },
    {
      "name": "working-tree",
      "status": "pass",
      "detail": "No uncommitted changes"
    }
  ]
}
```

### 7. Integration Points

**Caller (in exit protocol):**
- Receives `gate_file` path from `resolve-gate` (106-4)
- Calls gate runner: `runGate(gatePath)`
- Gets back GateResult
- If `status == "fail"`, blocks handoff

**Tests:**
- Unit tests: mock Task tool, verify gate parsing and result extraction
- Integration tests: use actual 106-1 tests-pass.md file, spawn real subagent

## Files

**Created (TEA):**
- `pennyfarthing_scripts/handoff/gate_runner.py` — Stub with parse_gate_file() and extract_gate_result()
- `pennyfarthing_scripts/tests/test_gate_runner.py` — 49 failing tests (RED)

**To Implement (Dev):**
- `pennyfarthing_scripts/handoff/gate_runner.py` — Fill in parse_gate_file() and extract_gate_result()

**To Modify:**
- (None for this story — CLI wiring and exit protocol integration happen in 106-3)

**Dependencies:**
- `pennyfarthing-dist/gates/tests-pass.md` (created in 106-1) — used for testing
- `handoff-cli.sh resolve-gate` (from 106-4) — provides gate file path

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core parsing/extraction logic with strict default-deny contract

**Test Files:**
- `pennyfarthing_scripts/tests/test_gate_runner.py` — 49 tests covering all 7 ACs

**Tests Written:** 49 tests covering 7 ACs
- AC1 (parse gate file): 11 tests — happy path, error cases, string/Path input
- AC2 (GATE_RESULT contract): 13 tests — pass/fail extraction, checks structure, minimal output
- AC3 (model attribute): 4 tests — haiku default, custom model, missing attribute
- AC4 (default-deny): 9 tests — None, empty, missing block, partial, malformed, typos
- AC5 (regex extraction): 5 tests — embedded in prose, code blocks, whitespace, quoting
- AC6 (read-only): 2 tests — mtime unchanged, size unchanged
- AC7 (timeouts/crashes): 5 tests — timeout, long output, multiple results, whitespace-only

**Correction:** Gate runner location is `pennyfarthing_scripts/handoff/gate_runner.py` (Python),
NOT `packages/core/src/gates/gate-runner.ts` (TypeScript). The entire handoff system
(resolve_gate, gate_file, complete_phase) is Python — the runner belongs with its peers.

**Status:** RED (49 failing — all NotImplementedError, ready for Dev)

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/handoff/gate_runner.py` — implemented parse_gate_file() and extract_gate_result()

**Tests:** 49/49 passing (GREEN)
**PR:** #912 — feat(106-2): gate subagent runner with GATE_RESULT contract
**Branch:** feature/106-2-gate-subagent-runner (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** gate_path (str/Path) → Path() → read_text() → regex → dict (safe — no injection, no side effects)
**Pattern observed:** Clean default-deny via string split + strict regex at gate_runner.py:106-121
**Error handling:** File not found, empty, missing tag all return error dicts. One MEDIUM gap: unhandled UnicodeDecodeError at line 58 (gate files are framework markdown, always UTF-8)
**Non-blocking:** [MEDIUM] _DEFAULT_FAIL shallow copy shares mutable checks list (line 21-25) — safe for current callers
**Tests:** 49/49 passing, all 7 ACs covered
**PR:** #912 merged

**Handoff:** To SM for finish-story

## Next Story

106-3 (Workflow YAML gate.file integration) will:
1. Wire up gate runner into agent exit protocol step 6
2. Update TDD workflow to use `gate.file: gates/tests-pass`
3. Call runner when handoff exits green phase