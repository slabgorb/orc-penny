# Epic 140: Batch Execution & Tracking

## Overview

Developer can select the batch workflow, have an architect decompose work into units, fan out parallel agents in worktrees, and see every unit's status in the session file. This is the core infrastructure for parallel agent execution within BikeLane ceremony.

**Priority:** P1
**Repo:** pennyfarthing
**Stories:** 4 (5 points)
**Jira:** PROJ-16090

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **Batch PRD** (`sprint/planning/batch-prd.md`) | Full PRD — success criteria, user journeys, functional requirements FR-1 through FR-5, technical architecture reference |
| **Epic Breakdown** (`sprint/planning/create-epics-and-stories.md`) | Requirements inventory, FR mapping, NFR constraints |
| **Fan-out/Fan-in Pattern** (`pennyfarthing-dist/patterns/fan-out-fan-in-pattern.md`) | Parallel execution model, implicit/explicit parallelism, error recovery, anti-patterns |
| **Workflow Schema** (`pennyfarthing-dist/schemas/workflow-schema.md`) | Workflow YAML validation rules — batch must conform without schema changes |
| **Session Schema** (`pennyfarthing-dist/schemas/session-schema.md`) | Existing XML structure that `<units>` element must integrate with |

## Background

### Why This Epic Exists

Pennyfarthing's current workflows (TDD, trivial, BDD) are sequential — one agent at a time, one story at a time. For stories with naturally parallelizable work (e.g., "add aria-labels to 40 components"), this creates a linear time bottleneck. Claude Code's `/batch` command already supports parallel execution in worktrees, but it operates outside BikeLane ceremony — no session tracking, no gates, no sprint integration.

### Current State

The fan-out/fan-in pattern is documented but not yet used by any workflow. The orchestrator agent exists but has no batch-specific instructions. Session files track phases and agents but have no concept of parallel work units. All the building blocks exist; this epic wires them together.

### Problem Being Solved

Give developers a way to run parallel agent work while preserving the full Pennyfarthing ceremony: workflow phases, gates, session tracking, and sprint integration. A batch run should produce the same artifacts (session file, PRs, sprint updates) as a sequential run — just faster.

### Design Constraints

- **NFR-1:** No workflow engine changes — batch must work within existing BikeLane infrastructure
- **NFR-2:** Additive only — no migration needed for existing workflows or data
- **NFR-4:** Failed units block at review gate — no silent partial success
- **NFR-5:** 5-30 units per batch run (Claude Code constraint)

## Technical Architecture

### Workflow Structure

```
batch workflow (4 phases):
  decompose (architect) ──[manual gate]──► fan-out (orchestrator) ──[manual gate]──► review (reviewer) ──[approval gate]──► finish (sm)
```

### Key Files

| File | Status | Purpose |
|------|--------|---------|
| `pennyfarthing-dist/workflows/batch-workflow.yaml` | **New** | Workflow definition — 4 phases, 3 gates |
| `pennyfarthing-dist/schemas/session-schema.md` | **Modified** | Document `<units>` XML element |
| `pennyfarthing-dist/agents/orchestrator.md` | **Modified** | Add batch fan-out execution flow |
| `pennyfarthing-dist/scripts/fix-session-phase` | **Modified** | Extend for `--unit <id> --status <status>` |

### Data Flow

1. **Decompose phase:** Architect breaks story into units, defines file boundaries per unit
2. **Fan-out phase:** Orchestrator spawns parallel agents via Task tool with `isolation: "worktree"`, each unit gets its own worktree
3. **Session tracking:** Each unit's status (pending → in_progress → completed/failed) is tracked in `<units>` XML within the session file
4. **Review phase:** Reviewer gets batch-wide diff context, approves/rejects the batch as a whole
5. **Finish phase:** SM archives session, updates sprint, cleans up

### Session XML Addition

```xml
<units>
  <unit id="1" status="completed" branch="batch-140-1" pr="https://...">
    Add aria-labels to form components A-E
  </unit>
  <unit id="2" status="failed" branch="batch-140-2">
    Add aria-labels to form components F-J
  </unit>
</units>
```

## Cross-Epic Dependencies

**Depends on:**
- None — all prerequisites (workflow engine, session schema, orchestrator agent, fan-out pattern) already exist

**Depended on by:**
- Epic 138 (Pre-Fan-Out Safety) — file-overlap independence check runs during the decompose phase of this workflow
