---
stepsCompleted: [1, 2, 3]
inputDocuments:
  - sprint/planning/gate-prd.md
  - docs/adr/0025-script-first-gate-extraction.md
---

# BikeLane Gate Extraction - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for BikeLane Gate Extraction, decomposing the requirements from the PRD and Architecture (ADR-0025) into implementable stories.

## Requirements Inventory

### Functional Requirements

FR-1: Gate File Schema — Gate files are markdown with XML-tagged blocks (`<gate>`, `<purpose>`, `<pass>`, `<fail>`). Required: name attribute, purpose, pass, fail. Optional: model attribute, nested `<gate>` blocks.

FR-2: Gate Subagent Runner — Parse gate file, validate schema, check cycles/depth, spawn subagent via Task tool, return structured `GATE_RESULT: {status, gate, message, children}`.

FR-3: Model Inheritance — Gate `model` attribute sets subagent model. Omitted = inherit from parent. Root omitted = default haiku. Children can override.

FR-4: Acyclic Validation — At parse time, build directed graph, detect cycles via DFS/topological sort, reject before any subagent spawns.

FR-5: Depth Limit — Hard limit 3 levels nesting. Enforced at parse time (static) and runtime (subagent refuses). Error with gate name and depth.

FR-6: Validation Gate on Gate Creation — Gate creation tool runs validation gate: schema check, acyclic check, depth check, mandatory pass/fail presence. Invalid gates rejected at authoring time.

FR-7: Workflow YAML Integration — Phase definitions reference gate files via `gate: { file: gates/tests-pass.md }`. Both `file:` (new) and `type:` (old) coexist. Engine checks `file:` first, falls back to `type:`.

FR-8: Handoff Subagent Elimination — Per ADR-0025: replace handoff subagent entirely with `handoff-cli.sh` (bash scripts). Agent drives exit directly. No intermediate subagent.

FR-9: Gate File Location — Built-in: `pennyfarthing-dist/gates/`. Project-specific: `.pennyfarthing/gates/`. Discovery: project-local → built-in (two paths for MVP per ADR-0025; workflow-local deferred).

### NonFunctional Requirements

NFR-1: Backward Compatibility — Existing workflows with `gate: { type: tests_pass }` must work unchanged. Migration is opt-in per workflow.

NFR-2: Performance — Gate subagents use haiku by default. Manual gates short-circuit with no LLM spawn (ADR-0025).

NFR-3: Observability — Gate results are structured (`GATE_RESULT`) for logging/reporting. No framework-level audit logging for MVP.

NFR-4: Authoring Experience — A workflow author should write a working gate file from a single example. Small schema (gate, purpose, pass, fail), same tag for nesting.

### Additional Requirements (from ADR-0025)

AR-1: `handoff-cli.sh` script with `resolve-gate` and `complete-phase` subcommands — pure bash, no LLM.

AR-2: Atomic session updates — `complete-phase` writes temp file + `mv`. Agents must NOT manually edit phase/history fields.

AR-3: Assessment pre-check — `resolve-gate` verifies `## Assessment` section exists in session before returning gate file. Fail-fast.

AR-4: Agent exit protocol update — New 7-step sequence replaces current `<agent-exit-protocol>` in all ~10 agent files simultaneously.

AR-5: Default-deny on gate failure — No valid `GATE_RESULT` = treat as fail. Max 3 retries before blocking.

AR-6: `GATE_RESULT` extraction via regex/grep — Not a full YAML parser. Exact extraction snippet provided in agent exit protocol.

AR-7: Script stdout is the ONLY communication channel — No side-channel files or environment variables.

AR-8: Gate files are read-only at runtime — Subagent evaluates, never modifies gate definitions.

### FR Coverage Map

| Requirement | Epic | Story | Description |
|-------------|------|-------|-------------|
| FR-1 | Epic 2 | 2.1 | Gate file schema |
| FR-2 | Epic 2 | 2.2 | Gate subagent runner |
| FR-3 | Epic 2 | 2.2 | Model inheritance |
| FR-4 | Epic 3 | 3.2 | Acyclic validation |
| FR-5 | Epic 3 | 3.2 | Depth limit |
| FR-6 | Epic 3 | 3.3 | Validation gate on creation |
| FR-7 | Epic 2 | 2.3 | Workflow YAML integration |
| FR-8 | Epic 1 | 1.1, 1.2 | Handoff elimination |
| FR-9 | Epic 2 | 2.4 | Gate file location |
| NFR-1 | Epic 2 | 2.3 | Backward compatibility |
| NFR-2 | Epic 2 | 2.2 | Performance (haiku default, manual short-circuit) |
| NFR-3 | Epic 2 | 2.2 | Observability (structured GATE_RESULT) |
| NFR-4 | Epic 3 | 3.3 | Authoring experience |
| AR-1 | Epic 1 | 1.1 | handoff-cli.sh script |
| AR-2 | Epic 1 | 1.1 | Atomic session updates |
| AR-3 | Epic 1 | 1.1 | Assessment pre-check |
| AR-4 | Epic 1 | 1.2 | Agent exit protocol update |
| AR-5 | Epic 2 | 2.2 | Default-deny on failure |
| AR-6 | Epic 2 | 2.2 | GATE_RESULT extraction |
| AR-7 | Epic 1 | 1.1 | Script stdout only |
| AR-8 | Epic 2 | 2.2 | Gate files read-only |

## Epic List

### Epic 1: Script-First Handoff
Agents hand off faster and more reliably using bash scripts instead of LLM subagents. Session updates are atomic. Manual gates cost zero tokens.
**FRs covered:** FR-8, AR-1, AR-2, AR-3, AR-4, AR-7

### Epic 2: Gate Files & First Migration
The `tests-pass` gate runs from a declarative file. TDD workflow uses file-based gates. Workflow authors see the pattern for writing their own.
**FRs covered:** FR-1, FR-2, FR-3, FR-7, FR-9, NFR-1, NFR-2, NFR-3, AR-5, AR-6, AR-8

### Epic 3: Gate Validation & Authoring
Workflow authors write custom gates with confidence — the framework catches schema errors, cycles, and depth violations at authoring time, not at runtime.
**FRs covered:** FR-4, FR-5, FR-6, NFR-4

### Epic 4: Full Migration & Cleanup
All built-in gates are declarative files. `handoff.md` and `sm-handoff.md` subagents removed. No legacy fallback code. Clean, maintainable system.
**FRs covered:** Remaining migration (tests-fail, approval gates), remove inline fallback, remove dead subagents.

---

## Epic 1: Script-First Handoff

Agents hand off faster and more reliably using bash scripts instead of LLM subagents. Session updates are atomic. Manual gates cost zero tokens.

### Story 1.1: Create handoff-cli.sh with resolve-gate and complete-phase

As a framework developer,
I want a bash script that resolves gate info and atomically updates session files,
So that handoffs don't require an LLM subagent for routing and session management.

**Acceptance Criteria:**

**Given** a TDD workflow with a story in the `green` phase
**When** `handoff-cli.sh resolve-gate {story-id} tdd green` is called
**Then** it returns RESOLVE_RESULT YAML with `status: ready`, `gate_type: tests_pass`, `next_agent: reviewer`, `next_phase: review`

**Given** a session file with no `## Assessment` section
**When** `handoff-cli.sh resolve-gate` is called for a non-manual gate
**Then** it returns `status: blocked`, `assessment_found: false`, exit code 1

**Given** a phase with `gate: { type: manual }`
**When** `handoff-cli.sh resolve-gate` is called
**Then** it returns `status: skip` without checking for assessment

**Given** a completed gate evaluation
**When** `handoff-cli.sh complete-phase {story-id} tdd green review tests_pass` is called
**Then** the session file is updated atomically (temp+mv) with new Phase, Phase Started, Phase History row, and Handoff History row

**Given** an invalid phase name
**When** `handoff-cli.sh resolve-gate` is called
**Then** it returns exit code 1 with a descriptive error message

### Story 1.2: Update agent exit protocol across all agent files

As a framework developer,
I want all agent files to use the new 7-step exit sequence with handoff-cli.sh,
So that agents drive their own exit without spawning a handoff subagent.

**Acceptance Criteria:**

**Given** the new `<agent-exit-protocol>` definition from ADR-0025
**When** all agent files (~10) are updated
**Then** each contains the identical 7-step sequence: write assessment, terminate tandem, resolve-gate, gate subagent (if needed), complete-phase, handoff-marker, emit marker, EXIT

**Given** an agent with the updated exit protocol
**When** the agent reaches its exit flow
**Then** it calls `handoff-cli.sh resolve-gate` instead of spawning the `handoff` subagent

**Given** the handoff subagent references in agent files
**When** the update is applied
**Then** no agent file references `handoff` or `sm-handoff` subagent for phase transitions

### Story 1.3: End-to-end handoff smoke test

As a framework developer,
I want to verify a TDD handoff works with the new script-based exit flow,
So that I have confidence the migration doesn't break existing workflows.

**Acceptance Criteria:**

**Given** a TDD story in the `green` phase with passing tests and an assessment written
**When** the Dev agent runs the new exit protocol
**Then** `resolve-gate` returns `status: ready`, the gate subagent evaluates `tests_pass` (inline fallback), `complete-phase` updates the session, and `handoff-marker.sh reviewer` emits the correct marker

**Given** a trivial story in the `implement` phase with no gate
**When** the Dev agent runs the new exit protocol
**Then** `resolve-gate` returns `status: skip`, `complete-phase` updates the session directly, and handoff proceeds without any LLM spawn

---

## Epic 2: Gate Files & First Migration

The `tests-pass` gate runs from a declarative file. TDD workflow uses file-based gates. Workflow authors see the pattern for writing their own.

### Story 2.1: Create tests-pass gate file with schema

As a workflow author,
I want a `tests-pass.md` gate file that defines pass/fail criteria for the TDD green phase,
So that gate logic is declarative and reviewable instead of buried in agent code.

**Acceptance Criteria:**

**Given** the gate file schema from FR-1
**When** `pennyfarthing-dist/gates/tests-pass.md` is created
**Then** it contains `<gate name="tests-pass" model="haiku">` with `<purpose>`, `<pass>`, and `<fail>` blocks

**Given** the `<pass>` block
**When** all tests are green and working tree is clean
**Then** the block instructs the evaluator to report test count, coverage, and branch status

**Given** the `<fail>` block
**When** tests are failing or working tree is dirty
**Then** the block instructs the evaluator to report failing test files/lines and uncommitted files, with recovery guidance

### Story 2.2: Gate subagent runner with GATE_RESULT contract

As a framework developer,
I want a gate runner that spawns a gate file as a haiku subagent and returns structured results,
So that gate evaluation is isolated, stateless, and returns a consistent contract.

**Acceptance Criteria:**

**Given** a gate file path and session context
**When** the gate runner spawns a Task subagent with the gate file content
**Then** the subagent returns `GATE_RESULT: {status: pass|fail, message: "...", checks: [...]}`

**Given** a gate file with `model="sonnet"` attribute
**When** the gate runner spawns the subagent
**Then** it uses `model: "sonnet"` in the Task tool call

**Given** a gate file with no `model` attribute
**When** the gate runner spawns the subagent
**Then** it defaults to `model: "haiku"`

**Given** a gate subagent that crashes or returns no GATE_RESULT
**When** the calling agent reads the result
**Then** it treats the outcome as `status: fail` (default-deny)

**Given** a gate subagent result
**When** the calling agent extracts GATE_RESULT
**Then** it uses regex/grep extraction, not a full YAML parser

### Story 2.3: Workflow YAML gate.file integration

As a workflow author,
I want to reference gate files from workflow YAML using `gate: { file: gates/tests-pass }`,
So that workflows use declarative gate files instead of inline type references.

**Acceptance Criteria:**

**Given** a workflow phase with `gate: { file: gates/tests-pass }`
**When** `handoff-cli.sh resolve-gate` processes this phase
**Then** it returns the resolved gate file path in `gate_file` field

**Given** a workflow phase with both `gate: { file: ..., type: ... }`
**When** `resolve-gate` processes this phase
**Then** `file` takes precedence over `type`

**Given** a workflow phase with only `gate: { type: tests_pass }` (legacy)
**When** `resolve-gate` processes this phase
**Then** it falls back to inline type handling (backward compatibility)

**Given** the updated schema
**When** `tdd.yaml` green phase is updated to `gate: { file: gates/tests-pass }`
**Then** the TDD workflow uses the gate file for the green to review transition

### Story 2.4: Gate file discovery and resolution

As a workflow author,
I want gate files resolved from project-local first, then built-in,
So that projects can override built-in gates without modifying the framework.

**Acceptance Criteria:**

**Given** a gate reference `gates/tests-pass`
**When** `.pennyfarthing/gates/tests-pass.md` exists (project-local)
**Then** it is used instead of the built-in `pennyfarthing-dist/gates/tests-pass.md`

**Given** a gate reference `gates/tests-pass`
**When** no project-local override exists
**Then** the built-in `pennyfarthing-dist/gates/tests-pass.md` is used

**Given** a gate reference to a non-existent file
**When** no file is found in either location and no `gate.type` fallback exists
**Then** `resolve-gate` returns `status: blocked` with error "Gate file not found: gates/{name}"

**Given** the `pennyfarthing-dist/gates/` directory
**When** the framework is installed
**Then** `.pennyfarthing/gates/` symlinks to it (following existing symlink pattern)

---

## Epic 3: Gate Validation & Authoring

Workflow authors write custom gates with confidence — the framework catches schema errors, cycles, and depth violations at authoring time, not at runtime.

### Story 3.1: Gate schema validation at parse time

As a workflow author,
I want gate files validated for required elements when parsed,
So that I get clear errors before any subagent is spawned.

**Acceptance Criteria:**

**Given** a gate file missing the `<pass>` block
**When** the gate runner parses it
**Then** it rejects with error: "Gate '{name}' missing required <pass> block"

**Given** a gate file missing the `name` attribute on `<gate>`
**When** the gate runner parses it
**Then** it rejects with error: "Gate element missing required 'name' attribute"

**Given** a gate file with a nested `<gate>` missing `<fail>`
**When** the gate runner parses it
**Then** it rejects with the child gate name and missing element

**Given** a valid gate file with all required elements
**When** the gate runner parses it
**Then** parsing succeeds and the gate is ready for execution

### Story 3.2: Acyclic validation and depth limit enforcement

As a workflow author,
I want circular gate references and excessive nesting caught at parse time,
So that gate evaluation never enters infinite loops or spirals in cost.

**Acceptance Criteria:**

**Given** a gate file where child gate A references parent gate B which references A
**When** the gate runner validates at parse time
**Then** it rejects with error: "Cycle detected: gate-A → gate-B → gate-A"

**Given** a gate file with 4 levels of nesting (depth > 3)
**When** the gate runner validates at parse time
**Then** it rejects with error: "Gate depth limit exceeded: {gate-name} at depth 4 (max 3)"

**Given** a gate file with exactly 3 levels of nesting
**When** the gate runner validates at parse time
**Then** validation passes (depth 3 is the maximum allowed)

**Given** a gate file with no nesting
**When** the gate runner validates at parse time
**Then** validation passes immediately

### Story 3.3: Gate authoring guide and validation command

As a workflow author,
I want a guide and validation command for writing gate files,
So that I can author gates from a single example and verify them before use.

**Acceptance Criteria:**

**Given** a new workflow author
**When** they read `pennyfarthing-dist/guides/gate-schema.md`
**Then** they find the complete schema, a working example, and authoring best practices

**Given** a gate file authored by the user
**When** they run the validation command
**Then** it checks schema, acyclic, depth, and mandatory pass/fail — reporting all errors at once

**Given** an invalid gate file
**When** the validation command runs
**Then** all errors are listed (not just the first one), each with the gate name and issue

**Given** a valid gate file
**When** the validation command runs
**Then** it confirms "Gate '{name}' is valid" with a summary of structure (depth, child count)

---

## Epic 4: Full Migration & Cleanup

All built-in gates are declarative files. `handoff.md` and `sm-handoff.md` subagents removed. No legacy fallback code. Clean, maintainable system.

### Story 4.1: Migrate tests-fail and approval gates to files

As a framework developer,
I want the remaining inline gate types migrated to declarative files,
So that all gate logic lives in reviewable, overridable files.

**Acceptance Criteria:**

**Given** the inline `tests_fail` gate logic from handoff.md
**When** `pennyfarthing-dist/gates/tests-fail.md` is created
**Then** it checks that tests are RED, covers all ACs, and the assessment exists — matching current behavior

**Given** the inline `approval` gate logic from handoff.md
**When** `pennyfarthing-dist/gates/approval.md` is created
**Then** it checks reviewer verdict (APPROVED/REJECTED) — matching current behavior

**Given** the new gate files
**When** all workflow YAMLs are updated to use `gate: { file: ... }`
**Then** `tdd.yaml`, `trivial.yaml`, `2party-tdd.yaml`, and `bdd.yaml` reference gate files for all phases

### Story 4.2: Remove handoff subagents and inline fallback

As a framework developer,
I want the legacy `handoff.md`, `sm-handoff.md`, and inline `gate.type` fallback removed,
So that there's a single code path for phase transitions — no dead code.

**Acceptance Criteria:**

**Given** all workflows now use `gate: { file: ... }`
**When** `handoff.md` and `sm-handoff.md` are deleted from `pennyfarthing-dist/agents/`
**Then** no agent file references either subagent

**Given** the inline `gate.type` fallback in `handoff-cli.sh`
**When** it is removed
**Then** `resolve-gate` only resolves via `gate.file` — unknown types return `status: blocked`

**Given** the Cyclist TypeScript layer
**When** `checkGate()` in `handoff.ts` is updated
**Then** it delegates to the script-based gate system (or is removed if unused)

---

## Summary

| Epic | Stories | Points |
|------|---------|--------|
| Epic 1: Script-First Handoff | 3 | 6 |
| Epic 2: Gate Files & First Migration | 4 | 7 |
| Epic 3: Gate Validation & Authoring | 3 | 6 |
| Epic 4: Full Migration & Cleanup | 2 | 4 |
| **Total** | **12** | **23** |
