# Story Context: 95-2 - Backseat Agent Spawn and Lifecycle

## Summary

Modify the BikeLane workflow executor to detect `tandem` configuration on workflow phases and spawn a long-lived background subagent (the "backseat") at phase start. Register cleanup handlers at spawn time for crash recovery. Terminate the backseat cleanly at phase end. Zero orphan processes.

## Planning References

- **PRD:** FR4-FR6 (agent lifecycle, spawn, termination), NFR8 (zero orphans), NFR9 (cleanup handlers), NFR10 (primary continues on crash). See `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** "Backseat Agent Lifecycle" in `sprint/planning/tandem-mode-ux-design.md`
- **Epics Breakdown:** Story 2.2 in `sprint/planning/tandem-mode-epics.md` under "Epic 2"

## Current State

### Workflow executor (existing)

**File:** `pennyfarthing/packages/core/src/workflow/workflow-executor.ts` (357 lines)

Key functions:
- **Lines 128-157:** `startWorkflow()` — initializes workflow state, loads first step
- **Lines 166-199:** `resumeWorkflow()` — resumes from last completed step
- **Lines 299-318:** `completeStep()` — completes step, advances state
- No tandem awareness — phases start and complete without spawning anything

Phase transition flow:
1. `startWorkflow()` → `initWorkflowState()` → loads step 1
2. `completeStep()` → `updateWorkflowState()` → advances to next step
3. No hooks for phase start/end side effects

### Background task tracking (existing)

**File:** `pennyfarthing/pennyfarthing-dist/scripts/lib/background-tasks.sh` (178 lines)

- **Lines 34-83:** `bg_task_add()` — adds task row to session file's Background Tasks table
- **Lines 87-105:** `bg_task_update()` — updates task status (running → completed/error)
- **Lines 108-127:** `bg_task_cleanup()` — removes completed/error rows
- **Lines 130-146:** `bg_task_list()` — lists active running tasks
- Table format: `| Task ID | Type | Started | Status | Description |`

### Agent spawning patterns (reference)

**File:** `pennyfarthing/pennyfarthing-dist/agents/README.md` (lines 248-327)
- Background subagent spawning via Task tool with `run_in_background: true`
- `subagent_type: "general-purpose"`, `model: "haiku"`

### Session state (existing)

**File:** `pennyfarthing/packages/core/src/workflow/session-state.ts` (291 lines)

- **Lines 11-30:** `WorkflowState` interface — `name`, `type`, `currentStep`, `stepsCompleted[]`, `status`
- **Lines 80-96:** `initWorkflowState()` — creates initial state
- **Lines 106-122:** `updateWorkflowState()` — advances state after step completion
- No tandem state tracking

## Target State

After implementation:

1. When a workflow phase has `tandem` config, BikeLane spawns a background subagent at phase start
2. The backseat agent receives: persona identity, story context, scope config, observation file path
3. Cleanup handler registered at spawn time ensures termination even on crash
4. At phase transition (`completeStep`), the backseat is terminated
5. If backseat crashes, primary agent continues unaffected — observation injection simply stops
6. Background task tracking records the backseat in the session file
7. Zero orphan processes after any phase transition or crash

## Key Files

### Files to Modify

| File | Path | Purpose |
|------|------|---------|
| `workflow-executor.ts` | `pennyfarthing/packages/core/src/workflow/workflow-executor.ts` | Add tandem spawn at phase start, tandem kill at phase transition |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| `workflow-schema.ts` | `pennyfarthing/packages/core/src/workflow/workflow-schema.ts` | `WorkflowPhase.tandem` interface (from 95-1) |
| `session-state.ts` | `pennyfarthing/packages/core/src/workflow/session-state.ts` | State tracking patterns |
| `background-tasks.sh` | `pennyfarthing/pennyfarthing-dist/scripts/lib/background-tasks.sh` | Background task tracking API |
| `agents/README.md` | `pennyfarthing/pennyfarthing-dist/agents/README.md` | Background subagent spawn patterns (lines 248-327) |

## Technical Approach

### Spawn Logic

At phase start (in `startWorkflow()` or when loading a step with tandem config):

1. Read `tandem` config from the current phase definition
2. Construct backseat prompt with persona, story context, scope, observation file path
3. Spawn via Task tool: `subagent_type: "general-purpose"`, `model: "haiku"`, `run_in_background: true`
4. Record task ID via `bg_task_add()` in session file
5. Register cleanup handler (process exit hook or signal trap)

### Kill Logic

At phase transition (`completeStep()`):

1. Check if current phase has an active backseat task (via `bg_task_list()` or stored task ID)
2. Terminate the background task
3. Update task status via `bg_task_update()` → "completed"
4. Clean up tracking via `bg_task_cleanup()`

### Crash Recovery

- Register cleanup handler at spawn time (e.g., `process.on('exit')` or shell trap)
- If primary crashes, cleanup handler kills the backseat process
- If backseat crashes, primary continues — no error propagation
- On next `resumeWorkflow()`, check for orphaned backseat tasks and clean up

### Backseat Prompt Template

```
You are {agent_persona} observing {primary_agent}'s work on story {story_id}.

Your scope: {scope}
Write observations to: .session/{story-id}-tandem-{agent}.md

Observation format:
---
## [{HH:MM}] Observation
**Trigger:** {trigger_type}: {trigger_detail}
{observation text}
---

{scope-specific instructions}
```

## Acceptance Criteria

- Backseat agent spawns as background subagent when phase has `tandem` config
- Backseat receives persona identity, story context, scope config, observation file path
- Backseat terminates cleanly at phase transition
- Cleanup handlers prevent orphan processes on crash
- Primary agent continues unaffected if backseat crashes
- Background task tracking records backseat in session file
- Backseat uses Haiku model (never Opus)
- Phases without `tandem` config behave unchanged

## Dependencies

### Depends On

- **95-1** (Tandem YAML schema) — tandem config must be parsed and validated

### Depended On By

- **95-3** (Observation file format and writer) — backseat needs to be running to write observations
- **95-4, 95-5, 95-6** (scope implementations) — all scopes run within the spawned backseat

## Risks / Open Questions

1. **Task tool availability:** The backseat is spawned via the Task tool. Need to verify that `workflow-executor.ts` (a TypeScript module) can invoke the Task tool, or if this spawn must happen through a shell script wrapper.

2. **Task ID tracking:** The Task tool returns a task ID for background agents. This ID must be stored somewhere accessible for the kill step. Options: session file (via `bg_task_add`), in-memory state, or a sidecar file.

3. **Multiple tandem phases:** If consecutive phases both have tandem configs, the previous backseat must be killed before the next one spawns. Verify the completeStep → startNextStep flow handles this ordering.

4. **Backseat prompt size:** The prompt includes persona, story context, and scope instructions. Keep it focused to minimize Haiku token usage.
