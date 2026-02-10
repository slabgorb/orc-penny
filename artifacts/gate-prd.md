---
stepsCompleted:
  - step-01-initialization
  - step-02-discovery
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation-skipped
  - step-07-functional-requirements
  - step-08-scoping
  - step-09-architecture
  - step-10-nonfunctional
  - step-11-complete
classification:
  projectType: developer-framework-extension
  domain: developer-tooling-ai-agent-orchestration
  complexity: high
  projectContext: brownfield
partyModeInsights:
  adopted:
    - handoff-subagent-thins-or-disappears
    - depth-limit-3
    - model-inheritance-from-parent
    - structured-gate-output-contract
  deferred:
    - gate-test-runner-dry-run
    - audit-logging
    - timeout-cost-budget
    - phase-vs-step-gate-distinction
inputDocuments:
  - pennyfarthing/pennyfarthing-dist/guides/bikelane.md
  - pennyfarthing/pennyfarthing-dist/guides/workflow-schema.md
  - pennyfarthing/pennyfarthing-dist/guides/workflow-step-schema.md
  - pennyfarthing/pennyfarthing-dist/guides/patterns/approval-gates-pattern.md
  - pennyfarthing/pennyfarthing-dist/agents/handoff.md
  - pennyfarthing/pennyfarthing-dist/workflows/tdd.yaml
  - pennyfarthing/pennyfarthing-dist/workflows/2party-tdd.yaml
  - pennyfarthing/pennyfarthing-dist/workflows/architecture.yaml
documentCounts:
  guides: 4
  agents: 1
  workflows: 3
workflowType: 'prd'
---

# Product Requirements Document - BikeLane Gate Extraction

**Author:** Keith Avery
**Date:** 2026-02-10

## Success Criteria

### User Success

| Criterion | Measure |
|-----------|---------|
| Workflow authors can define custom gates | A non-framework-developer (DevOps, QA) can write a gate file from a single example and have it execute |
| Gates express domain-specific risk | DevOps security gates coexist with app-dev test gates in the same workflow, each with appropriate model/depth |
| Gate results are always informative | Calling agent receives actionable pass/fail context — never "blocked" without explanation |
| Composition is intuitive | Nesting uses the same `<gate>` tag — no new concepts to learn |

### Business Success

| Criterion | Measure |
|-----------|---------|
| Reusable gates | A gate file written for one workflow can be referenced from another without modification |
| Extensible without engine changes | New gate types (security, compliance, performance) added as files — no handoff subagent edits |
| Team-specific workflows | Colleagues with different risk profiles (DevOps vs app-dev) each define gates appropriate to their domain |

### Technical Success

| Criterion | Measure |
|-----------|---------|
| Recursive parsing with safety | Acyclic validation catches cycles at parse time; max depth 3 enforced at runtime |
| Model configurability | Gate `model` attribute works; children inherit parent unless overridden |
| Backward compatibility | Existing `tdd`, `trivial`, `2party-tdd` workflows work unchanged during migration |
| Handoff subagent thins | Handoff becomes a router — finds gate file, spawns it, reads result. Gate owns the logic |

### Measurable Outcomes

- A DevOps colleague can author a deploy-safety gate with nested sub-gates and have it run in their workflow without framework code changes
- Existing TDD workflow gate behavior is identical before and after migration (no regression)
- Gate file count grows independently of handoff subagent complexity (decoupled)

## Product Scope

### MVP — Minimum Viable Product

- Gate file schema: `<gate>`, `<purpose>`, `<pass>`, `<fail>`, `model` attribute
- Recursive nesting with acyclic validation and depth limit 3
- Gate subagent runner (spawns gate as Task, returns structured result)
- At least one existing gate type (`tests_pass`) migrated from handoff to gate file
- Model inheritance (child inherits parent unless overridden)

### Growth Features (Post-MVP)

- All existing gate types migrated to gate files
- Handoff subagent fully thinned to router
- Workflow YAML `gate:` field accepts file references alongside inline types
- Gate discovery/registry for listing available gates

### Vision (Future)

- Gate test runner with dry-run mode
- Audit logging for gate execution history
- Timeout/cost budget per gate
- Gate marketplace — share gates across projects

## User Journeys

### Journey 1: Ravi (DevOps) — Deploy Safety Gate with Recovery

Ravi writes a `deploy-safety.md` gate for his release workflow. It has three nested gates: `ci-green`, `secrets-rotated`, `staging-smoke`. The `ci-green` child gate passes. The `secrets-rotated` child gate fails — two keys expired. The parent gate's `<fail>` block fires with: "Deploy blocked. secrets-rotated failed: AWS_KEY_PROD and STRIPE_KEY expired. Run `just rotate-secrets` and re-trigger gate." The calling agent reports this verbatim. Ravi fixes it, re-runs. Now all three pass. The parent `<pass>` fires: "All 3 deploy safety checks green. CI passing, secrets current, staging smoke passed. Safe to deploy." The agent proceeds to the deploy phase.

### Journey 2: Keith (App Dev) — Same TDD, Different Plumbing

Keith is mid-sprint on a TDD story. TEA writes failing tests, triggers handoff. The workflow engine finds the `tests-fail.md` gate file, spawns it as a haiku subagent. The gate checks test results, confirms tests are RED. `<pass>`: "14 tests failing as expected. Test coverage spans all 5 acceptance criteria. Ready for Dev." Handoff proceeds to Dev. Keith didn't notice anything changed — it just works. If tests were accidentally GREEN, `<fail>`: "All tests passing — TEA's tests don't exercise new code. Return to TEA with: tests must fail against unimplemented acceptance criteria."

### Journey 3: Sam (Workflow Author) — Composing a Quality Gate

Sam creates `quality-pass.md` for the 2party-tdd workflow. She nests four child gates: `lint`, `typecheck`, `unit-tests`, `license-scan`. She sets `model="haiku"` on the parent (cheap checks), but `model="sonnet"` on `license-scan` (needs reasoning about license compatibility). She accidentally has `lint` reference `quality-pass` as a nested gate — the acyclic validator catches the cycle at parse time before anything runs. She fixes it, and the gate tree is 2 levels deep (well within the depth-3 limit). On execution, `lint` and `typecheck` pass, `unit-tests` fails. The parent `<fail>`: "Quality gate failed. unit-tests: 3 failures in auth_handler_test.go. lint: clean. typecheck: clean. license-scan: skipped (blocked by test failure). Fix test failures and re-run."

### Journey 4: The Dev Agent — Actionable Context Both Ways

Dev finishes implementation. The workflow engine spawns the `tests-pass.md` gate. The gate runs tests, checks lint, verifies clean working tree. Everything passes. The gate returns its `<pass>` block: "All 47 tests green (12 new, 35 existing). Lint clean. Working tree clean. Branch pushed to origin." Dev agent uses this to write a handoff assessment with specific evidence. If the gate had failed, the `<fail>` block: "3 tests failing in auth_test.go:44,67,89. Working tree has uncommitted changes in handler.go." Dev agent knows exactly what to fix.

### Journey Requirements Summary

| Capability | Revealed By |
|------------|-------------|
| Gate file schema with `<gate>`, `<pass>`, `<fail>` | All journeys |
| Nested gate composition | Journeys 1, 3 |
| Model attribute per gate with inheritance | Journey 3 |
| Acyclic validation at parse time | Journey 3 |
| Depth limit enforcement | Journey 3 |
| Gate subagent runner returning structured results | Journeys 2, 4 |
| Backward-compatible migration of existing gates | Journey 2 |
| Recovery guidance in `<fail>` blocks | Journeys 1, 3, 4 |

## Domain-Specific Requirements

### Safety Constraints
- **Cost control via depth limit** — max depth 3 for nested gates, enforced at runtime. Primary guardrail against runaway subagent spawning
- **Parse-time validation** — acyclic check and depth limit must fail before any subagent is spawned, not during execution
- **Subagent context isolation** — gate subagents must not pollute the calling agent's context window. They run, return results, and die

### Validation at Creation (Dogfooding)
- The gate creation tool itself runs a validation gate: schema check, acyclic check, depth check, mandatory `<pass>`/`<fail>` presence
- Gates validating gates — the framework eats its own cooking
- Invalid gates are rejected at authoring time, never at execution time

### Integration Constraints
- **Workflow YAML coexistence** — during migration, both inline `gate: {type}` (old) and gate file references (new) must work
- **Step file `<gate>` tag** — existing checklist-style `<gate>` in stepped workflow steps needs migration path or coexistence with executable gates

### Best Practices (Not Enforced)
- **Idempotency** — re-running a gate after fixing an issue should be safe. Gates should be read-only checks, not state mutators. This is a gate author responsibility, not framework enforcement

### Explicitly Out of Scope
- LLM model availability/fallback — user handles their own token problems
- Timeout/cost budgets — depth limit covers safety for now

## Functional Requirements

### FR-1: Gate File Schema

Gate files are markdown files with XML-tagged blocks. Every gate file must contain:

```xml
<gate name="{gate-name}" model="{model}">
  <purpose>What this gate checks</purpose>

  <!-- Optional: nested child gates (same <gate> tag, recursive) -->
  <gate name="{child-gate-name}">
    <purpose>What the child checks</purpose>
    <pass>Instructions/context when child passes</pass>
    <fail>Instructions/context when child fails, including recovery</fail>
  </gate>

  <pass>Instructions/context when this gate passes</pass>
  <fail>Instructions/context when this gate fails, including recovery</fail>
</gate>
```

**Required elements:**
- `<gate>` — root element with `name` attribute
- `<purpose>` — what the gate checks
- `<pass>` — instructions executed on pass, returned to calling agent
- `<fail>` — instructions executed on fail, returned to calling agent (must include recovery guidance)

**Optional elements:**
- `model` attribute — LLM model for gate subagent (default: `haiku`)
- Nested `<gate>` blocks — child gates executed before parent evaluates

**Schema validation rules:**
- Every `<gate>` must have exactly one `<pass>` and one `<fail>`
- Every `<gate>` must have a `name` attribute
- Every `<gate>` must have a `<purpose>`
- Max nesting depth: 3
- No circular references (acyclic validation)

### FR-2: Gate Subagent Runner

The gate runner spawns a gate file as a subagent via the Task tool:

1. Parse the gate file, validate schema
2. Check for cycles and depth limit
3. Spawn subagent with gate file content as prompt
4. Subagent executes checks described in the gate
5. Subagent evaluates nested child gates depth-first
6. Subagent returns the `<pass>` or `<fail>` block content to the calling agent

**Subagent contract:**
- Input: gate file content + runtime context (session state, workflow phase)
- Output: `GATE_RESULT: {status: passed|failed, gate: {name}, message: {pass or fail block content}, children: [{child results}]}`

### FR-3: Model Inheritance

- If a gate specifies `model="sonnet"`, the subagent runs on sonnet
- If a gate omits `model`, it inherits from its parent gate
- If the root gate omits `model`, it defaults to `haiku`
- Child gates can override parent model

### FR-4: Acyclic Validation

At parse time (before any subagent spawns):
- Build a directed graph of gate references
- Detect cycles using topological sort or DFS
- Reject with error: "Cycle detected: gate-A → gate-B → gate-A"
- This is a static check on the gate file structure

### FR-5: Depth Limit

- Hard limit: 3 levels of nesting
- Enforced at parse time (static check on gate file)
- Enforced at runtime (subagent refuses to execute beyond depth 3)
- Error: "Gate depth limit exceeded: {gate-name} at depth 4 (max 3)"

### FR-6: Validation Gate on Gate Creation

The tool/command that creates gate files runs a validation gate itself:
- Schema check: all required elements present
- Acyclic check: no circular references
- Depth check: within limit
- Mandatory `<pass>` and `<fail>` on every `<gate>`
- Invalid gates rejected at authoring time

### FR-7: Workflow YAML Integration

Workflow phase definitions reference gate files:

```yaml
# New: file reference
- name: green
  agent: dev
  gate:
    file: gates/tests-pass.md

# Old: inline type (still works during migration)
- name: green
  agent: dev
  gate:
    type: tests_pass
```

Both forms coexist. The workflow engine checks for `file:` first, falls back to `type:`.

### FR-8: Handoff Subagent Thinning

The handoff subagent (`agents/handoff.md`) transitions from gate executor to gate router:
- **Before:** Handoff contains inline gate logic (tests_fail, tests_pass, approval, manual checks)
- **After:** Handoff discovers the gate file for the current phase, spawns it, reads the result, updates session

The handoff subagent retains:
- Session file updates (phase, timestamps, handoff history)
- Next-phase determination
- HANDOFF_RESULT generation

The handoff subagent loses:
- All inline gate check logic (moved to gate files)

### FR-9: Gate File Location

Gate files live in:
- `pennyfarthing-dist/gates/` — built-in gates (tests-pass, tests-fail, approval, manual)
- `.pennyfarthing/gates/` — user/project-specific gates (symlinked at runtime)
- Workflow-local: `workflows/{name}/gates/` — gates specific to a workflow

Discovery order: workflow-local → project gates → built-in gates.

## Technical Architecture

### Gate Execution Flow

```
Calling Agent (e.g., Dev)
    │
    │ completes work, triggers handoff
    │
    ▼
Handoff Subagent (router)
    │
    │ reads workflow YAML → finds gate file for current phase
    │
    ▼
Gate Runner
    │
    ├── parse gate file
    ├── validate schema (required tags)
    ├── validate acyclic (no cycles)
    ├── validate depth (≤ 3)
    │
    ▼
Gate Subagent (spawned via Task tool)
    │
    ├── execute child gates depth-first
    │   ├── child 1: pass ✓
    │   ├── child 2: fail ✗
    │   └── child 3: skipped (parent fails on child 2)
    │
    ├── evaluate parent gate result
    │
    ▼
Returns GATE_RESULT to Handoff
    │
    ▼
Handoff updates session, returns HANDOFF_RESULT to Calling Agent
```

### File Structure

```
pennyfarthing-dist/
├── gates/                    # Built-in gate files
│   ├── tests-pass.md
│   ├── tests-fail.md
│   ├── approval.md
│   └── manual.md
├── agents/
│   └── handoff.md            # Thinned to router
├── workflows/
│   ├── tdd.yaml              # gate: { file: gates/tests-pass.md }
│   └── 2party-tdd.yaml
└── guides/
    └── gate-schema.md         # Gate file authoring guide
```

## Non-Functional Requirements

### NFR-1: Backward Compatibility
Existing workflows with `gate: { type: tests_pass }` must continue to work unchanged. Migration is opt-in per workflow.

### NFR-2: Performance
Gate subagents use haiku by default for fast, cheap execution. Model override to sonnet only when gate author explicitly needs it.

### NFR-3: Observability
Gate results are structured (`GATE_RESULT`) so calling agents can log and report them. No framework-level audit logging required (deferred to future).

### NFR-4: Authoring Experience
A workflow author should be able to write a working gate file from a single example. The schema is small (gate, purpose, pass, fail) and the nesting model uses the same tag.

## Migration Strategy

### Phase 1: MVP
1. Define gate file schema and validation
2. Implement gate subagent runner
3. Migrate `tests_pass` gate from handoff to gate file
4. Add `gate: { file: ... }` support to workflow YAML loader
5. Handoff subagent checks for gate file first, falls back to inline logic

### Phase 2: Growth
1. Migrate remaining gates (tests_fail, approval, manual)
2. Remove inline gate logic from handoff subagent
3. Add gate discovery command (`/workflow gates` or similar)

### Phase 3: Vision
- Gate test runner, audit logging, timeout/cost budgets
