---
parent: context-epic-137.md
workflow: trivial
---

# Story 137-4: Add Batch Fan-Out to Orchestrator Agent Definition

## Business Context

The orchestrator agent currently lacks instructions for executing batch fan-out within the BikeLane ceremony. During the fan-out phase, the orchestrator must spawn parallel agents via the Task tool with `isolation: "worktree"`, track unit completion/failure, and update the session file with status. Without these instructions, developers cannot execute the batch workflow end-to-end, and parallel work units have no agent guidance for their execution.

This story ensures the orchestrator can fulfill its role in the batch workflow's fan-out phase (phase 2 of 4), enabling developers to run parallel agent work while preserving ceremony gates and session tracking.

## Technical Guardrails

### Agent Definition Patterns

The orchestrator agent definition follows the strategic agent template (`agents/templates/agent-template-strategic.md`) with these core sections:

- `<role>` — Meta-operations focus (process improvement, coordination)
- `<critical>` — Core constraints (never write feature code)
- `<helpers>` — Subagent delegation model (Haiku for mechanical work)
- `<workflows>` — Process descriptions (agent file audit, skill maintenance, etc.)
- `<coordination>` — Agent roster and handoff patterns

The batch section must add guidance on **fan-out/fan-in execution**, not a new system concept. Per the fan-out/fan-in pattern, the orchestrator uses internal parallelism (multiple Task calls in a single message) to spawn worker agents.

### Fan-Out/Fan-In Mechanics

From `pennyfarthing-dist/patterns/fan-out-fan-in-pattern.md`:

- **Implicit Parallelism:** Multiple Task tool invocations in a single message execute concurrently
- **Isolation:** Each spawned agent gets `isolation: "worktree"` to run in parallel
- **Result Aggregation:** Orchestrator collects completion/failure from all units, updates session
- **Error Handling:** Failed units block batch at review gate (per NFR-4); partial success deferred to future growth

The orchestrator's batch instructions must:
1. Receive unit definitions and acceptance criteria from the decompose phase
2. Spawn N parallel Task calls (where 5 ≤ N ≤ 30)
3. Each Task spawns a worker agent (Dev, TEA, etc.) with unit scope + story AC
4. Collect results (branch, PR URL, status) from each unit
5. Call `fix-session-phase --unit <id> --status <status>` to update session
6. Aggregate results and prepare for review phase

### Worktree Isolation

Each unit executes in its own worktree (`.claude/worktrees/batch-<story-id>-<unit-id>`). The orchestrator does not manage worktree lifecycle — Claude Code's Task tool handles creation and cleanup. The orchestrator only passes `isolation: "worktree"` to each Task invocation.

## Scope Boundaries

**In scope:**

- Orchestrator agent definition (`pennyfarthing-dist/agents/orchestrator.md`):
  - Add new `<batch-workflow>` section with fan-out execution instructions
  - Include references to the fan-out/fan-in pattern
  - Describe Task tool usage with `isolation: "worktree"` parameter
  - Define unit result aggregation and session update flow
  - Include acceptance criteria pass-through to worker agents

**Out of scope:**

- Batch workflow YAML definition — that's story 137-1
- Session `<units>` XML schema or example — that's story 137-2
- Session update tooling (`fix-session-phase` extension) — that's story 137-3
- File-overlap independence check — that's story 138-1
- Worker agent behavior or implementations — those are separate stories

## AC Context

**AC 1: Batch section added to orchestrator agent definition**

- File: `pennyfarthing-dist/agents/orchestrator.md`
- New section titled `<batch-workflow>` or similar, placed in workflow-participation or delegation section
- Section explicitly states: "orchestrator spawns parallel agents via Task tool with `isolation: "worktree"`"
- References `pennyfarthing-dist/patterns/fan-out-fan-in-pattern.md` for parallelism model
- Testable via: `grep -A 10 "batch\|fan-out" pennyfarthing-dist/agents/orchestrator.md` returns section with fan-out instructions

**AC 2: Task tool invocation pattern documented**

- Instructions include concrete Task tool usage:
  - How to unpack unit definitions from decompose phase
  - How to construct Task calls with `isolation: "worktree"`
  - How to pass story acceptance criteria to each worker agent
- Example shows multiple Task calls in single message (implicit parallelism)
- Testable via: Section contains example code block showing multiple Task invocations

**AC 3: Session unit status update documented**

- Instructions describe calling `fix-session-phase --unit <id> --status <status>` after each unit completes
- Describes aggregating unit results (branch, PR URL, status)
- Testable via: Section mentions `fix-session-phase` and unit status tracking

**AC 4: Error handling and result aggregation described**

- Instructions state that failed units block batch at review gate
- Orchestrator collects all unit results (success/failure) before handoff
- Testable via: Section includes paragraph on partial failure handling and review gate blocking

**AC 5: Agent definition is syntactically valid and parseable**

- File passes `pf hooks schema-validation` for orchestrator.md
- No unclosed XML tags
- Testable via: `git commit` hook validation passes, agent can be activated via `/orchestrator`
