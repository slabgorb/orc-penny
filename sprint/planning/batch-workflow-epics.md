---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
  - step-05-import-to-future
inputDocuments:
  - sprint/planning/batch-prd.md
  - pennyfarthing/pennyfarthing-dist/patterns/fan-out-fan-in-pattern.md
  - pennyfarthing/pennyfarthing-dist/schemas/workflow-schema.md
---

# Batch Workflow Integration - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Batch Workflow Integration, decomposing the requirements from the PRD and embedded Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

- **FR-1: Batch Workflow YAML** (MVP #1, 2pt) — As a developer, I can select the `batch` workflow for a story so that parallel execution follows BikeLane ceremony. `workflows/batch-workflow.yaml` passes existing validator without schema changes. 4 phases: decompose (architect), fan-out (orchestrator), review (reviewer), finish (sm). Gates: manual on decompose, manual on fan-out, approval on review. Triggers: `batch` tag on stories.

- **FR-2: Session Units Tracking** (MVP #2, 1pt) — As a developer, I can see all batch units and their status in the session file. `<units>` XML element in session file. Each `<unit>` has: id, status (pending/in_progress/completed/failed), description, worktree path, branch, PR URL. Grep-parseable, consistent with existing session schema. Session schema documentation updated.

- **FR-3: Orchestrator Batch Prompt** (MVP #3, 1pt) — As the orchestrator agent, I have instructions to invoke `/batch` with story context and track results back to session units. Orchestrator agent definition includes batch fan-out execution flow. Spawns parallel agents via Task tool with `isolation: "worktree"`. Updates session unit status on completion/failure. Passes story acceptance criteria to each worker agent.

- **FR-4: Session Update Tooling** (MVP #4, 1pt) — As an agent, I can update individual unit status in the session file. `fix-session-phase` extended to handle `--unit <id> --status <status>` arguments. Updates single unit without clobbering other units. Supports all unit status values: pending, in_progress, completed, failed.

- **FR-5: File-Overlap Independence Check** (MVP #5, 1pt) — As a developer, I'm warned before fan-out if two units touch the same file. Pre-fan-out gate checks unit file lists for intersection. If overlap found, blocks with warning listing conflicting files and units. Developer can override or request re-decomposition.

### NonFunctional Requirements

- **NFR-1: No workflow engine changes** — Batch workflow must work within existing BikeLane infrastructure. Zero modifications to workflow-schema.ts or handoff.ts.
- **NFR-2: Additive only** — No migration needed for existing workflows, sessions, or sprint data. Batch is a new workflow alongside tdd/trivial/bdd.
- **NFR-3: Worktree cleanup** — No stale `.claude/worktrees/batch-*` directories after 24h. Claude Code manages lifecycle; Pennyfarthing monitors.
- **NFR-4: Graceful failure** — Failed units report status clearly in session. Batch blocks at review gate on any failure — doesn't silently pass.
- **NFR-5: Unit count range** — Respects `/batch` hard constraint of 5-30 units per run.

### Additional Requirements

**From Embedded Architecture (PRD Technical Architecture Reference):**
- Fan-out is a single phase — orchestrator agent uses internal fan-out/fan-in pattern, not a new workflow engine concept
- Session uses XML `<units>` element, not YAML — consistent with session schema
- Failed units block the batch — strict by default, partial completion deferred to Growth
- No tandem observers — unnecessary overhead for isolated worktree execution
- New standalone `batch` workflow type, not a modifier on existing workflows
- No starter template — brownfield, all code exists within Pennyfarthing framework

**From Fan-out/Fan-in Pattern:**
- Implicit parallelism via multiple Task calls in single message, or explicit background with `run_in_background: true`
- Result aggregation after all parallel tasks complete
- Partial failure handling: log failures, mark status, block at review gate
- Concurrency: 5-10 items use explicit background with batching

**From Workflow Schema:**
- Must conform to existing YAML schema: `name`, `phases[]` (each with `name`, `agent`, optional `input`/`output`/`gate`), `triggers`
- Gate types available: `manual`, `approval`, `tests_pass`, `tests_fail`, `quality_pass`
- Validated at load time — invalid workflows report field-path errors

### FR Coverage Map

| FR | Epic | Story | Description |
|----|------|-------|-------------|
| FR-1 | Epic 1 | 1.1 | Batch workflow YAML definition (4 phases, gates, triggers) |
| FR-2 | Epic 1 | 1.2 | Session `<units>` XML tracking element |
| FR-3 | Epic 1 | 1.4 | Orchestrator agent batch fan-out instructions |
| FR-4 | Epic 1 | 1.3 | `fix-session-phase` extended for per-unit status |
| FR-5 | Epic 2 | 2.1 | File-overlap intersection check before fan-out |

**Coverage: 5/5 FRs mapped. Zero orphans.**

## Epic List

### Epic 1: Batch Execution & Tracking
After this epic: developer can select the `batch` workflow, have an architect decompose work into units, fan out parallel agents in worktrees, and see every unit's status in the session file. Full happy path and partial-failure path work end-to-end.
**FRs covered:** FR-1, FR-2, FR-3, FR-4
**NFRs addressed:** NFR-1, NFR-2, NFR-3, NFR-4, NFR-5
**Points:** 5

### Epic 2: Pre-Fan-Out Safety
After this epic: developer is warned before fan-out if two units would touch the same file — preventing the worst failure mode of parallel work.
**FRs covered:** FR-5
**Points:** 1

---

## Epic 1: Batch Execution & Tracking

Developer can select the `batch` workflow, have an architect decompose work into units, fan out parallel agents in worktrees, and see every unit's status in the session file.

### Story 1.1: Create Batch Workflow YAML

As a developer,
I want a `batch` workflow definition that follows BikeLane ceremony,
So that parallel story execution uses the same phase/gate/handoff infrastructure as all other workflows.

**Acceptance Criteria:**

**Given** the workflow file is created at `pennyfarthing-dist/workflows/batch.yaml`
**When** the existing workflow validator loads it
**Then** it passes validation without any schema changes to `workflow-schema.ts` or `handoff.ts`

**Given** the batch workflow definition
**When** inspecting its phases
**Then** it defines 4 phases in order: decompose (architect), fan-out (orchestrator), review (reviewer), finish (sm)

**Given** the decompose phase
**When** the architect completes unit decomposition
**Then** a `manual` gate requires developer approval of unit boundaries before proceeding

**Given** the fan-out phase
**When** the orchestrator completes parallel execution
**Then** a `manual` gate requires all batch units to be resolved before proceeding

**Given** the review phase
**When** the reviewer completes batch consistency review
**Then** an `approval` gate requires reviewer approval before proceeding

**Given** the workflow triggers section
**When** a story has the `batch` tag
**Then** the batch workflow is selected by the routing engine

**Given** the workflow is added to the workflows directory
**When** `pf workflow list` is run
**Then** `batch` appears in the available workflows list

**FRs:** FR-1
**NFRs:** NFR-1, NFR-2
**Points:** 2

### Story 1.2: Add Session Units XML Tracking

As a developer,
I want batch units tracked as `<units>` XML in the session file,
So that I can see all units and their status at a glance.

**Acceptance Criteria:**

**Given** a batch workflow session file
**When** the orchestrator begins the fan-out phase
**Then** a `<units>` XML element is present in the session file

**Given** the `<units>` element
**When** inspecting its structure
**Then** each `<unit>` has attributes: `id`, `status`, `description`
**And** each `<unit>` has optional child elements: `worktree`, `branch`, `pr`

**Given** a unit's status attribute
**When** reading it
**Then** the value is one of: `pending`, `in_progress`, `completed`, `failed`

**Given** the `<units>` XML block
**When** running `grep` against the session file
**Then** unit IDs and statuses are parseable with standard text tools

**Given** the session schema documentation at `pennyfarthing-dist/schemas/session-schema.md`
**When** this story is complete
**Then** the schema includes the `<units>` element definition with all attributes and child elements documented

**FRs:** FR-2
**NFRs:** NFR-4
**Points:** 1

### Story 1.3: Extend Session Tooling for Unit Status Updates

As an agent running in a batch worktree,
I want to update my unit's status in the session file,
So that the orchestrator and developer can track progress without parsing agent output.

**Acceptance Criteria:**

**Given** a session file with a `<units>` block containing 5 units
**When** `pf workflow fix-phase --unit 3 --status completed` is run
**Then** unit 3's status attribute changes to `completed`
**And** all other units remain unchanged

**Given** a session file with a `<units>` block
**When** `pf workflow fix-phase --unit 3 --status failed` is run
**Then** unit 3's status attribute changes to `failed`

**Given** `pf workflow fix-phase --unit 3 --status invalid_value` is run
**When** the status value is not one of pending/in_progress/completed/failed
**Then** the command exits with an error message listing valid status values

**Given** `pf workflow fix-phase --unit 99 --status completed` is run
**When** unit 99 does not exist in the `<units>` block
**Then** the command exits with an error message indicating the unit was not found

**Given** optional metadata fields `--branch` and `--pr`
**When** `pf workflow fix-phase --unit 3 --status completed --branch batch-unit-3 --pr https://github.com/org/repo/pull/42` is run
**Then** the unit's `branch` and `pr` child elements are updated alongside the status

**FRs:** FR-4
**NFRs:** NFR-4
**Points:** 1

### Story 1.4: Add Batch Fan-Out to Orchestrator Agent Definition

As the orchestrator agent entering the fan-out phase,
I want batch execution instructions in my agent definition,
So that I can decompose, spawn parallel agents, and track results back to session units.

**Acceptance Criteria:**

**Given** the orchestrator agent definition at `pennyfarthing-dist/agents/orchestrator.md`
**When** the orchestrator is activated for the `fan-out` phase of a batch workflow
**Then** the agent definition contains a batch execution section with fan-out instructions

**Given** the batch execution instructions
**When** the orchestrator reads the unit definitions from the decompose phase output
**Then** the instructions direct spawning one agent per unit via Task tool with `isolation: "worktree"`

**Given** the orchestrator spawns parallel agents
**When** each agent completes or fails
**Then** the instructions direct updating unit status via `pf workflow fix-phase --unit <id> --status <status>`
**And** the instructions direct updating `--branch` and `--pr` metadata on completion

**Given** the orchestrator spawns parallel agents
**When** passing context to each worker agent
**Then** the instructions direct passing the story's acceptance criteria and the unit's specific scope/file list

**Given** the batch uses the fan-out/fan-in pattern
**When** the orchestrator tracks unit count
**Then** the instructions enforce the 5-30 unit constraint from `/batch`
**And** the instructions direct using explicit background execution (`run_in_background: true`) for 5+ units

**FRs:** FR-3
**NFRs:** NFR-3, NFR-5
**Points:** 1

---

## Epic 2: Pre-Fan-Out Safety

Developer is warned before fan-out if two units would touch the same file — preventing the worst failure mode of parallel work.

### Story 2.1: File-Overlap Independence Check

As a developer reviewing the architect's unit decomposition,
I want a warning if two units touch the same file,
So that I can prevent merge conflicts from parallel worktree execution.

**Acceptance Criteria:**

**Given** the architect has produced unit definitions with file lists
**When** the decompose phase's manual gate is evaluated
**Then** a file-overlap check runs before presenting the gate to the developer

**Given** units 1 and 4 both list `src/components/Button.tsx` in their file lists
**When** the overlap check runs
**Then** it blocks with a warning listing the conflicting file and the unit IDs (1 and 4)

**Given** no units share any files in their file lists
**When** the overlap check runs
**Then** it passes silently and the manual gate proceeds normally

**Given** an overlap is detected
**When** the warning is presented to the developer
**Then** the developer can choose to override (proceed anyway) or request re-decomposition

**Given** multiple overlaps exist across several units
**When** the overlap check reports
**Then** all conflicting file/unit pairs are listed, not just the first one found

**FRs:** FR-5
**Points:** 1
