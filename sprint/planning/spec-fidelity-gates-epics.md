---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
inputDocuments:
  - sprint/planning/prd.md
---

# Specification Fidelity Gates - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Specification Fidelity Gates, decomposing the requirements from the PRD into implementable stories. No separate Architecture or UX document — the PRD's Technical Architecture section serves as the architecture input. This is workflow configuration, gate scripts, and agent definition work.

## Requirements Inventory

### Functional Requirements

- FR-1: Deviation Entry Format Specification — structured 6-field format (spec source, spec text, implementation, rationale, severity, forward impact) with agent-specific subsections (TEA/Dev/Architect)
- FR-2: Deviation Gate Format Validation — upgrade `deviations-logged` from existence check to format validation; missing fields fail with specific recovery message
- FR-3: AC-Completion Gate — standalone composable gate; reads ACs from context, requires DONE/DEFERRED/DESCOPED status, DEFERRED prompts operator with default "do it"
- FR-4: Architect Spec-Check Phase — new phase between setup and RED; validates story context assumptions against sibling stories; gate: `spec-check-pass`
- FR-5: Architect Spec-Reconcile Phase — new phase after Reviewer; compares final implementation against all specs; produces definitive deviation manifest; gate: `spec-reconcile-pass`
- FR-6: Assumptions Section in Story Context — required `## Assumptions` section in context schema; references sibling story IDs and what's assumed
- FR-7: Simplify Toggle — `simplify_enabled` in repos.yaml per-repo; default false; controls simplify teammate spawning in verify phase
- FR-8: Tandem Workflow Removal — delete tdd-tandem.yaml, review-tandem.yaml, bdd-tandem.yaml; reassign stories
- FR-9: TDD Workflow Update — add spec-check and reconcile phases; wire all gates per gate architecture table

### Non-Functional Requirements

- NFR-1: Gate failures are recoverable — agent gets specific error, can fix and re-trigger without restarting phase
- NFR-2: No silent gate bypass — crashed/missing gate script blocks, never auto-passes
- NFR-3: Graceful degradation for missing context — falls back to story titles + ACs from sprint YAML
- NFR-4: Idempotent gate checks — no side effects from re-runs
- NFR-5: Deviation format is machine-parseable — strict markdown, parseable by regex
- NFR-6: Gate contracts are composable — ac-completion works standalone
- NFR-7: Session file is single coordination artifact — no external state files
- NFR-8: repos.yaml read at runtime — not cached at workflow start

### Additional Requirements

- Architect phases add two agent invocations per story — acceptable by design (Principle 13: Excellence Over Optimization)
- AC-completion gate blocks for operator input — no timeout, human-in-loop by design
- Tandem workflow rethink is explicitly out of scope — future epic
- No backward compatibility shim for tdd.yaml version bump — clean cut
- Existing `deviations-logged` and `deviations-audited` gate files exist but are unwired in tdd.yaml

### FR Coverage Map

| FR | Story | Description |
|----|-------|-------------|
| FR-1 | 1.1 | Deviation format spec + gate upgrade to format validation |
| FR-2 | 1.1 | Gate validates 6-field structure, not just existence |
| FR-1 | 1.2 | TEA and Dev agent definitions mandate deviation logging |
| FR-3 | 1.3 | AC-completion gate with operator approval |
| FR-7 | 1.4 | Simplify toggle in repos.yaml |
| FR-6 | 1.5 | Assumptions section in context schema |
| FR-4 | 1.6 | Architect spec-check phase and gate |
| FR-5 | 1.7 | Architect spec-reconcile phase and gate |
| FR-8 | 1.8 | Tandem workflow deletion and story reassignment |
| FR-9 | 1.9 | TDD workflow updated with all phases and gates |

**Coverage: 9/9 FRs mapped. Zero orphans.**

## Epic List

### Epic 1: Specification Fidelity Gates
After this epic: every spec departure is documented in structured format with gate enforcement. Operator approves AC deferrals in real-time. Architect validates assumptions before coding and produces the definitive audit manifest after review. TDD workflow updated with all new phases and gates. Dead tandem workflows removed. Simplify is toggleable per-project.
**FRs covered:** FR-1 through FR-9
**NFRs addressed:** NFR-1 through NFR-8
**Points:** 19

---

## Epic 1: Specification Fidelity Gates

Enforce spec fidelity end-to-end: structured deviation documentation, AC accountability with operator approval, Architect spec alignment phases, and modernized TDD workflow.

### Story 1.1: Deviation Format Spec and Gate Validation Upgrade

As an operator,
I want deviation entries validated against a structured 6-field format at every gate check,
So that every spec departure is documented completely and consistently — no half-baked entries slip through.

**Acceptance Criteria:**

**Given** the deviation entry format is documented in a guide at `pennyfarthing-dist/guides/deviation-format.md`
**When** an agent reads the guide
**Then** it specifies 6 required fields: spec source, spec text, implementation, rationale, severity, forward impact
**And** it specifies agent-specific subsections: `### TEA (test design)`, `### Dev (implementation)`, `### Architect (reconcile)`

**Given** a session file with a `## Design Deviations` section containing entries with all 6 fields
**When** the `deviations-logged` gate runs
**Then** it passes validation

**Given** a session file with a deviation entry missing the "Forward impact" field
**When** the `deviations-logged` gate runs
**Then** it fails with message: "Entry '{description}' missing: Forward impact"

**Given** a session file with `## Design Deviations` containing "No deviations from spec."
**When** the `deviations-logged` gate runs
**Then** it auto-passes with zero entries (explicit no-deviation is valid)

**Given** a session file with no `## Design Deviations` section at all
**When** the `deviations-logged` gate runs
**Then** it fails with message: "Missing '## Design Deviations' section in session file"

**Given** the gate fails
**When** the agent fixes the entry and re-triggers the gate
**Then** the gate re-evaluates without restarting the phase (idempotent)

**FRs:** FR-1, FR-2
**NFRs:** NFR-1, NFR-2, NFR-4, NFR-5
**Points:** 3

### Story 1.2: Update TEA and Dev Agent Definitions for Deviation Logging

As a TEA or Dev agent,
I want clear instructions in my agent definition mandating deviation logging against all available specs,
So that I document every departure as I work — not as an afterthought at gate time.

**Acceptance Criteria:**

**Given** the TEA agent definition at `pennyfarthing-dist/agents/tea.md`
**When** TEA activates for the RED phase
**Then** the definition includes a `<deviation-logging>` section mandating: log deviations against story context, epic context, and sibling story ACs
**And** the section specifies the 6-field format with example
**And** the section explicitly states: "Never assume simplification is acceptable — log it as a deviation"

**Given** the Dev agent definition at `pennyfarthing-dist/agents/dev.md`
**When** Dev activates for the GREEN phase
**Then** the definition includes the same `<deviation-logging>` section as TEA
**And** Dev entries go under `### Dev (implementation)`, not `### TEA (test design)`

**Given** TEA or Dev encounters a spec departure during their phase
**When** they decide to deviate
**Then** the agent definition instructs them to log the deviation immediately in the session file, not defer to phase exit

**FRs:** FR-1 (enforcement)
**Points:** 2

### Story 1.3: Create AC-Completion Gate

As an operator watching Dev work,
I want every acceptance criterion accounted for at Dev exit — with real-time prompts for any deferrals,
So that I can approve or reject each deferral with full justification before handoff proceeds.

**Acceptance Criteria:**

**Given** a story context document with 10 acceptance criteria
**When** the `ac-completion` gate runs after Dev's GREEN phase
**Then** it reads the AC list from the story context document
**And** it checks the session file for each AC's status

**Given** all 10 ACs are marked DONE in the session file
**When** the gate evaluates
**Then** it passes with a full AC accountability table logged in the session

**Given** AC-7 is marked `DEFERRED` with justification "Requires config infrastructure from Story 1.20"
**When** the gate evaluates AC-7
**Then** it prompts the operator in real-time: "AC-7 deferred: 'Requires config infrastructure from Story 1.20'. Default action: complete it. Approve deferral? [y/N]"

**Given** the operator approves the deferral
**When** the approval is recorded
**Then** the session file logs: AC-7 DEFERRED (operator-approved), justification, and timestamp

**Given** the operator rejects the deferral (default action: "complete it")
**When** the rejection is recorded
**Then** the gate fails and Dev must address AC-7 before re-triggering

**Given** AC-3 is marked `DESCOPED` with justification
**When** the gate evaluates AC-3
**Then** it prompts the operator for approval the same way as DEFERRED

**Given** AC-5 has no status (not marked DONE, DEFERRED, or DESCOPED)
**When** the gate evaluates
**Then** it fails with: "AC-5 has no status. Mark as DONE, DEFERRED, or DESCOPED."

**Given** the `ac-completion` gate definition
**When** referenced from any workflow phase (not just dev-exit)
**Then** it works standalone — composable, not coupled to a specific phase

**FRs:** FR-3
**NFRs:** NFR-1, NFR-6, NFR-7
**Points:** 3

### Story 1.4: Add Simplify Toggle to repos.yaml

As a project operator,
I want a per-repo `simplify_enabled` setting in repos.yaml,
So that I can control whether simplify teammates spawn during verify — OFF by default, ON for repos that benefit from refactoring suggestions.

**Acceptance Criteria:**

**Given** `repos.yaml` with no `simplify_enabled` field for a repo
**When** the workflow engine reads the config at TEA verify phase entry
**Then** it defaults to `false` (simplify teammates do not spawn)

**Given** `repos.yaml` with `simplify_enabled: true` for the pennyfarthing repo
**When** TEA enters the verify phase for a story in that repo
**Then** simplify teammates (simplify-reuse, simplify-quality, simplify-efficiency) spawn as teammates

**Given** `repos.yaml` with `simplify_enabled: false` for the orchestrator repo
**When** TEA enters the verify phase for a story in that repo
**Then** simplify teammates do not spawn; verify runs quality-pass gate only

**Given** an operator changes `simplify_enabled` from false to true between phases
**When** TEA enters verify
**Then** it reads the current value from repos.yaml (not cached at workflow start)

**FRs:** FR-7
**NFRs:** NFR-8
**Points:** 1

### Story 1.5: Add Assumptions Section to Story Context Schema

As a PM creating story context,
I want a required `## Assumptions` section in the context schema,
So that each story explicitly declares what it assumes about sibling stories' outputs — giving Architect a structural anchor for cross-story comparison.

**Acceptance Criteria:**

**Given** the context schema at `pennyfarthing-dist/schemas/context-schema.md`
**When** a PM creates a new story context document
**Then** the schema requires a `## Assumptions` section

**Given** the `## Assumptions` section
**When** populated by the PM
**Then** each assumption references: sibling story ID, what's assumed, which spec/AC it's based on
**And** format example: "Assumes story 5-1 delivers `Regex { pattern: String, flags: String }` per AC-3"

**Given** a story with no cross-story assumptions
**When** the PM fills the section
**Then** "No cross-story assumptions" is valid (explicit declaration, not empty)

**Given** a story context document with an empty `## Assumptions` section (no content, not even "No cross-story assumptions")
**When** the context gate validates the document
**Then** it fails with: "Assumptions section must be non-empty — list assumptions or state 'No cross-story assumptions'"

**FRs:** FR-6
**Points:** 1

### Story 1.6: Create Architect Spec-Check Phase and Gate

As a TEA about to write tests,
I want the Architect to validate my story's assumptions against sibling stories before I start,
So that I write tests against the actual state of the codebase, not outdated assumptions.

**Acceptance Criteria:**

**Given** the Architect activates for the spec-check phase on story 5-2
**When** loading context
**Then** it reads: story 5-2 context (including `## Assumptions`), epic context, sibling story ACs from sprint YAML, and prior sibling session archives

**Given** story 5-2 assumes "5-1 delivers `Regex { pattern: String, flags: String }`"
**And** story 5-1's session archive shows a deviation: Regex flattened to `Regex(String)`
**When** the Architect compares assumptions against deviations
**Then** it flags the assumption as **broken** with: story ID, assumption text, actual implementation from deviation manifest

**Given** story 5-2 assumes something about story 5-3 which has no context document
**When** the Architect attempts to validate
**Then** it falls back to story 5-3's title and ACs from sprint YAML
**And** logs: "Story 5-3 context document not found — validated against sprint YAML only"

**Given** the Architect completes spec-check with 2 broken assumptions and 1 validated
**When** the `spec-check-pass` gate evaluates
**Then** it passes — findings are documented, not blocking (spec-check is advisory)

**Given** the story context document is missing entirely
**When** the `spec-check-pass` gate evaluates
**Then** it fails: "Story context document required for spec-check"

**Given** the story context exists but `## Assumptions` section is absent
**When** the `spec-check-pass` gate evaluates
**Then** it fails: "Assumptions section required in story context"

**Given** the Architect produces spec-check findings
**When** TEA activates for the RED phase next
**Then** TEA reads the Architect's findings and adjusts test design accordingly

**FRs:** FR-4
**NFRs:** NFR-3
**Points:** 3

### Story 1.7: Create Architect Spec-Reconcile Phase and Gate

As a boss auditing a completed story,
I want a definitive deviation manifest produced by the Architect after review,
So that I can read one section in the session file and know every spec departure — without opening code, without re-reading specs, without diffing anything.

**Acceptance Criteria:**

**Given** the Architect activates for the spec-reconcile phase after Reviewer
**When** loading context
**Then** it reads: story context, epic context, PRD references, sibling story ACs, and all in-flight deviation logs from TEA and Dev sections

**Given** TEA and Dev logged 8 deviations during their phases
**When** the Architect reviews each entry
**Then** it confirms accuracy and completeness of each existing entry

**Given** the Architect finds a deviation that Dev missed (e.g., simplified cost model vs spec AC-6)
**When** documenting the finding
**Then** it adds the entry under `### Architect (reconcile)` with the full 6-field format

**Given** the session file has AC deferrals logged by the ac-completion gate
**When** the Architect reviews them
**Then** it verifies each deferral justification is still accurate post-review

**Given** the Architect completes the reconcile pass
**When** the `spec-reconcile-pass` gate evaluates
**Then** it passes when the `### Architect (reconcile)` section exists (even if "No additional deviations found")

**Given** the `### Architect (reconcile)` section is missing
**When** the `spec-reconcile-pass` gate evaluates
**Then** it fails: "Architect reconcile section required — run spec-reconcile phase"

**Given** the completed reconcile manifest
**When** the boss reads the session archive
**Then** `## Design Deviations` contains three subsections (TEA, Dev, Architect) — the Architect section is the definitive audit

**FRs:** FR-5
**NFRs:** NFR-7
**Points:** 3

### Story 1.8: Remove Tandem Workflows

As a developer selecting a workflow for a story,
I want obsolete tandem workflows removed,
So that there's no confusion about which workflows are active — tandem needs a full rethink now that Architect has explicit phases.

**Acceptance Criteria:**

**Given** the workflow files `tdd-tandem.yaml`, `review-tandem.yaml`, `bdd-tandem.yaml`
**When** this story is complete
**Then** all three files are deleted from `pennyfarthing-dist/workflows/`

**Given** any stories in sprint YAML with `workflow: tdd-tandem`
**When** this story is complete
**Then** those stories are reassigned to `workflow: tdd`

**Given** any stories with `workflow: review-tandem` or `workflow: bdd-tandem`
**When** this story is complete
**Then** those stories are reassigned to `workflow: tdd` (or appropriate equivalent)

**Given** `pf workflow list` is run after deletion
**When** inspecting the output
**Then** `tdd-tandem`, `review-tandem`, and `bdd-tandem` do not appear

**FRs:** FR-8
**Points:** 1

### Story 1.9: Update TDD Workflow with New Phases and Gates

As a workflow engine,
I want `tdd.yaml` updated with spec-check and reconcile phases and all gates wired,
So that the full pipeline enforces spec fidelity end-to-end: setup → spec-check → red → green → verify → review → reconcile → finish.

**Acceptance Criteria:**

**Given** the updated `tdd.yaml`
**When** inspecting its phases
**Then** it defines 8 phases in order: setup (SM), spec-check (Architect), red (TEA), green (Dev), verify (TEA), review (Reviewer), reconcile (Architect), finish (SM)

**Given** the spec-check phase
**When** inspecting its gate
**Then** it references `spec-check-pass`

**Given** the red phase (TEA exit)
**When** inspecting its gates
**Then** it references `deviations-logged`

**Given** the green phase (Dev exit)
**When** inspecting its gates
**Then** it references `deviations-logged` and `ac-completion`

**Given** the review phase (Reviewer exit)
**When** inspecting its gates
**Then** it references `deviations-audited`

**Given** the reconcile phase (Architect exit)
**When** inspecting its gate
**Then** it references `spec-reconcile-pass`

**Given** the workflow version
**When** comparing to the previous version
**Then** it has a version bump (not a silent edit)

**Given** the updated workflow passes through the existing workflow validator
**When** `pf workflow show tdd` is run
**Then** it displays all 8 phases with their agents and gates

**FRs:** FR-9
**Points:** 2
