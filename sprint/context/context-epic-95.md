# Epic 95: Workflow Configuration & Observation Protocol

## Overview

Workflow authors can add `tandem:` blocks to their workflow YAML, and BikeLane spawns/terminates backseat agents with working observation scopes. The tandem system works end-to-end -- backseat observes, writes observations, bell mode injects them, primary surfaces them.

**Total points:** 20
**Priority:** P1
**Marker:** feature
**Repo:** pennyfarthing
**Stories:** 7

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **PRD** (`sprint/planning/tandem-mode-prd.md`) | FR1-FR17 (workflow config, agent lifecycle, observation protocol, injection), NFR1-NFR5 + NFR7-NFR12 + NFR15 (performance, reliability, integration), "Observation Protocol -- Three Scopes" table, "Technical Architecture Considerations" |
| **UX Design Spec** (`sprint/planning/tandem-mode-ux-design.md`) | "Journey 1: Workflow Author" (YAML config experience), "Observation File Format" block, "Bell Mode Integration" section |
| **Epic Breakdown** (`sprint/planning/tandem-mode-epics.md`) | Epic 2 full section (Stories 2.1-2.7), FR Coverage Map (FR1-FR17), NFR Coverage (NFR1-NFR5, NFR7-NFR12, NFR15) |

## Background

### What This Epic Adds

Seven capabilities that together form the complete tandem observation loop:

1. **YAML schema** -- `tandem:` block on workflow phases with `partner` and `scope` fields
2. **Backseat spawn/kill** -- BikeLane manages a long-lived background subagent per tandem phase
3. **Observation file** -- Append-only markdown at `.session/{story-id}-tandem-{agent}.md`
4. **File-watch scope** -- Backseat detects file changes in working tree
5. **Tool-watch scope** -- Backseat receives tool call data from primary agent
6. **Context-watch scope** -- Backseat receives periodic conversation summaries
7. **Bell mode injection** -- PostToolUse hook injects observations into primary agent's context

### How It Connects

Epic 94 (baseline throbber) is a standalone UX fix with no tandem dependency. This epic (95) is the core engine -- everything that makes tandem work. Epic 96 (Cyclist UI) and Epic 97 (CLI + shipping workflow) are the visual layers that depend on this epic's observation protocol being functional.

## Technical Architecture

### Component Map

```
Workflow YAML (.pennyfarthing/workflows/tdd-tandem.yaml)
  |  tandem: { partner: architect, scope: file-watch }
  v
BikeLane Loader (workflow-loader.ts)
  |  loadWorkflowFile() → parseYAML → validateWorkflow()
  v
BikeLane Schema (workflow-schema.ts)
  |  validates tandem: block (partner required, scope enum)
  v
BikeLane Executor (workflow-executor.ts)
  |  phase start → spawn backseat (Task tool, run_in_background: true)
  |  phase end → terminate backseat (cleanup handler)
  v
Backseat Agent (long-lived background subagent)
  |  receives: persona, story context, scope config, observation file path
  |  observes: file changes / tool calls / conversation summaries
  |  writes: .session/{story-id}-tandem-{agent}.md
  v
Bell Mode Hook (bell-mode-hook.sh / bellmode_hook.py)
  |  PostToolUse → check tandem file mtime → inject as bell message
  |  format: [Tandem] {persona_name}: {observation_summary}
  v
Primary Agent
  |  receives injected observation → surfaces in own voice
  |  "Will Bailey suggests we extract this into an adapter."
```

### Key Files (Existing, to be Modified)

| File | Path | Lines | Change |
|------|------|-------|--------|
| Workflow schema | `packages/core/src/workflow/workflow-schema.ts` | 626 | Add `tandem` field validation in phase loop (~line 360-375, after gate validation). New optional `tandem: { partner: string, scope: string \| string[] }` in `WorkflowPhase` interface |
| Workflow loader | `packages/core/src/workflow/workflow-loader.ts` | 185 | No changes needed -- loader passes raw YAML to validator |
| Workflow executor | `packages/core/src/workflow/workflow-executor.ts` | 357 | Add tandem spawn at phase start (`startWorkflow`/`resumeWorkflow`), tandem kill at phase transition (`completeStep`). Register cleanup handlers for crash recovery |
| Bell mode hook (bash) | `pennyfarthing-dist/scripts/hooks/bell-mode-hook.sh` | 107 | Add tandem observation file check after bell queue check. Check `.session/*-tandem-*.md` mtime, read new entries, inject as `additionalContext` |
| Bell mode hook (python) | `pennyfarthing_scripts/bellmode_hook.py` | 155 | Same tandem observation check in Python implementation |
| BikeLane tests | `tests/sm-subagents.test.ts` | 903 | Add tests for tandem phase detection, spawn/kill lifecycle, gate behavior with tandem |

### Key Files (Reference Only)

| File | Path | Purpose |
|------|------|---------|
| Session state | `packages/core/src/workflow/session-state.ts` (291 lines) | `WorkflowState` interface, `parseSessionState()`, `updateWorkflowState()` -- patterns for state tracking |
| Background tasks | `pennyfarthing-dist/scripts/lib/background-tasks.sh` | `bg_task_add`, `bg_task_update`, `bg_task_cleanup` -- existing background task tracking |
| Agent README | `pennyfarthing-dist/agents/README.md` (lines 248-327) | Background subagent spawning patterns with Task tool |
| Bell mode guide | `pennyfarthing-dist/guides/bell-mode.md` | Bell queue format, PostToolUse hook protocol, config structure |
| Relay mode guide | `pennyfarthing-dist/guides/relay-mode.md` | Orthogonal to tandem -- relay handles handoff execution, tandem handles observation |
| Workflow schema guide | `pennyfarthing-dist/guides/workflow-schema.md` | Documented schema for workflow YAML -- needs update after tandem field added |
| tdd.yaml | `pennyfarthing-dist/workflows/tdd.yaml` | Base workflow that tdd-tandem will extend |
| 2party-tdd.yaml | `pennyfarthing-dist/workflows/2party-tdd.yaml` | Complex workflow with `next:` directives, `instructions:` blocks -- reference for advanced phase config |

### WorkflowPhase Interface Extension

Current interface (`workflow-schema.ts` lines 21-37):

```typescript
export interface WorkflowPhase {
  name: string;
  agent: string;
  input?: string[];
  output?: string[];
  gate?: {
    type: string;
    condition?: string;
  };
}
```

After tandem:

```typescript
export interface WorkflowPhase {
  name: string;
  agent: string;
  input?: string[];
  output?: string[];
  gate?: {
    type: string;
    condition?: string;
  };
  tandem?: {                        // NEW
    partner: string;                // Agent name (architect, tea, etc.)
    scope: string | string[];       // file-watch, tool-watch, context-watch, or array
  };
}
```

### Validation Pattern

The existing validation at lines 360-375 validates `gate:` per phase. Tandem validation follows the same pattern:

```typescript
// After gate validation in phase loop
if ('tandem' in phaseObj && phaseObj.tandem !== undefined) {
  if (!phaseObj.tandem || typeof phaseObj.tandem !== 'object') {
    errors.push({ field: `workflow.phases[${index}].tandem`, message: 'must be an object' });
  } else {
    const t = phaseObj.tandem as Record<string, unknown>;
    if (!t.partner || typeof t.partner !== 'string') {
      errors.push({ field: `workflow.phases[${index}].tandem.partner`, message: 'is required and must be a string' });
    }
    if (t.scope !== undefined) {
      const validScopes = ['file-watch', 'tool-watch', 'context-watch'];
      const scopes = Array.isArray(t.scope) ? t.scope : [t.scope];
      for (const s of scopes) {
        if (!validScopes.includes(s)) {
          errors.push({ field: `workflow.phases[${index}].tandem.scope`, message: `invalid scope "${s}". Valid: ${validScopes.join(', ')}` });
        }
      }
    }
  }
}
```

### Observation File Format

From the PRD:

```markdown
# Tandem Observations: {story-id}
**Observer:** {agent} ({persona})
**Phase:** {phase}
**Started:** {ISO timestamp}

---

## [{HH:MM}] Observation
**Trigger:** {trigger_type}: {trigger_detail}
{observation text}

---
```

Location: `.session/{story-id}-tandem-{agent}.md`

Key properties:
- Append-only (new entries appended, never modified)
- Entry-atomic (each entry is complete markdown; crash mid-write leaves prior entries valid)
- Valid markdown throughout lifecycle (NFR11)

### Bell Mode Integration

The existing PostToolUse hook (`bell-mode-hook.sh`) checks `.pennyfarthing/bell-queue.json` for queued messages. Tandem extends this:

1. After bell queue check, check for tandem observation files matching `.session/*-tandem-*.md`
2. Track last-read position (mtime or byte offset) in a sidecar file
3. If new content since last check, extract latest observation entry
4. Format as `additionalContext`: `[Tandem] {persona_name}: {observation_summary}`
5. Inject via same `hookSpecificOutput` mechanism

The hook output format is already established:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[Tandem] Will Bailey: The event handler pattern here differs from the notification module."
  }
}
```

No bell mode schema changes required (NFR12).

### Backseat Agent Lifecycle

**Spawn:** At tandem phase start, BikeLane spawns backseat via Task tool:
- `subagent_type: "general-purpose"`
- `model: "haiku"` (per framework rules -- never Opus for mechanical tasks)
- `run_in_background: true`
- Prompt includes: agent persona, story context, scope config, observation file path

**Run:** Backseat is long-lived for the full phase. It accumulates context across observations (FR9). Each scope triggers observations differently:
- `file-watch`: polls or watches working tree for changes
- `tool-watch`: receives tool call data (mechanism TBD -- file-based or hook-based)
- `context-watch`: receives periodic conversation summaries at configurable intervals

**Kill:** At phase transition, BikeLane terminates the background task. Cleanup handler registered at spawn time ensures no orphans even on crash (NFR8, NFR9).

**Crash recovery:** If backseat crashes, primary continues unaffected (NFR10). Observation injection simply stops. No error UI.

### Background Task Tracking

Existing infrastructure in `background-tasks.sh`:

```bash
bg_task_add "$SESSION_FILE" "$TASK_ID" "tandem-architect" "Tandem observer"
bg_task_update "$SESSION_FILE" "$TASK_ID" "completed"
bg_task_cleanup "$SESSION_FILE"
```

Key constraint: No concurrent state mutation -- don't have multiple background tasks writing to same file. The tandem observation file is write-only by the backseat agent; the bell mode hook is read-only.

## Stories

| Story | Title | Points | Priority | Dependencies |
|-------|-------|--------|----------|-------------|
| 95-1 | Tandem YAML schema and BikeLane validation | 3 | P0 | None |
| 95-2 | Backseat agent spawn and lifecycle | 3 | P0 | 95-1 |
| 95-3 | Observation file format and writer | 2 | P0 | 95-2 |
| 95-4 | File-watch observation scope | 3 | P0 | 95-3 |
| 95-5 | Tool-watch observation scope | 3 | P1 | 95-3 |
| 95-6 | Context-watch observation scope | 3 | P1 | 95-3 |
| 95-7 | Bell mode observation injection | 3 | P0 | 95-3 |

## Story Notes

### 95-1: Tandem YAML schema and BikeLane validation

**What to do:** Extend the `WorkflowPhase` interface in `workflow-schema.ts` with an optional `tandem` field. Add validation in the phase validation loop (after gate validation at ~line 375). Update `workflow-schema.md` guide with tandem documentation.

**Key files:**
- `packages/core/src/workflow/workflow-schema.ts` -- add interface field + validation
- `pennyfarthing-dist/guides/workflow-schema.md` -- document tandem schema
- `tests/sm-subagents.test.ts` -- add validation tests (valid tandem, invalid scope, missing partner, backward compatibility)

**Validation rules:**
- `partner` required string (valid agent name)
- `scope` optional, defaults to `file-watch`; valid values: `file-watch`, `tool-watch`, `context-watch`; can be string or string array
- Workflows without `tandem:` blocks load unchanged (NFR15)

### 95-2: Backseat agent spawn and lifecycle

**What to do:** Modify `workflow-executor.ts` to detect tandem config on phase start and spawn a background subagent. Register cleanup handler at spawn time. Terminate on phase end.

**Key files:**
- `packages/core/src/workflow/workflow-executor.ts` -- spawn/kill logic in `startWorkflow()` and `completeStep()`
- `pennyfarthing-dist/scripts/lib/background-tasks.sh` -- use existing bg task tracking

**Spawn pattern (from agents/README.md):**
```
Task tool:
  subagent_type: "general-purpose"
  model: "haiku"
  run_in_background: true
  prompt: |
    You are {agent_persona} observing {primary_agent}'s work.
    Story: {story_id}
    Scope: {scope}
    Write observations to: {observation_file_path}
    ...
```

**Key constraints:**
- Zero orphan processes (NFR8)
- Cleanup handlers registered at spawn time (NFR9)
- Primary continues if backseat crashes (NFR10)

### 95-3: Observation file format and writer

**What to do:** Implement the observation file creation and append logic. The backseat agent creates the file at phase start and appends entries as observations occur.

**Location:** `.session/{story-id}-tandem-{agent}.md`

**Key constraint:** Entry-atomic appends -- each write is a complete markdown entry. File remains valid markdown even on crash (NFR11).

**Pattern reference:** Existing session files in `.session/` use markdown format with metadata headers. The tandem observation file follows the same convention.

### 95-4: File-watch observation scope

**What to do:** Implement file change detection for the backseat agent. The backseat polls or watches the working tree for create/modify/delete events and writes observations.

**Key constraints:**
- Detect changes within 5 seconds (NFR3)
- Non-blocking to primary agent (NFR1)
- Accumulate context across observations (FR9)

**Implementation options:**
- `fs.watch` / `chokidar` for real-time detection
- Periodic `git status` or `git diff` polling (simpler, works without dependencies)
- The backseat runs as a Claude Code subagent, so it can use Bash/Glob/Grep tools to detect changes

### 95-5: Tool-watch observation scope

**What to do:** Deliver tool call information (name, params, results) to the backseat within one tool-use cycle (NFR4).

**Key challenge:** The backseat runs as a separate process. Tool call data from the primary agent needs to reach it. Options:
- File-based: primary's hook writes tool calls to a shared file; backseat reads it
- OTEL-based: intercept OTEL spans from primary agent
- The PostToolUse hook already fires after each tool -- it could append tool data to a file the backseat reads

**Key constraint:** Truncate large tool results to configurable max size.

### 95-6: Context-watch observation scope

**What to do:** Deliver periodic conversation summaries from the primary agent at configurable turn intervals (NFR5).

**Key constraint:** Summary generation must not block primary agent's conversation flow. Token overhead stays under 25% per phase when combined with other scopes (NFR7).

### 95-7: Bell mode observation injection

**What to do:** Extend the PostToolUse hook to check the tandem observation file for new content and inject it as a bell message.

**Key files:**
- `pennyfarthing-dist/scripts/hooks/bell-mode-hook.sh` -- add tandem file check
- `pennyfarthing_scripts/bellmode_hook.py` -- same check in Python

**Implementation:**
1. After existing bell queue check, look for `.session/*-tandem-*.md` files
2. Track last-read mtime in `.session/.tandem-mtime-{agent}` sidecar
3. If file modified since last check, extract last observation entry
4. Format: `[Tandem] {persona_name}: {observation_summary}`
5. Output via existing `hookSpecificOutput.additionalContext` mechanism
6. No bell mode schema changes (NFR12)

**Key constraint:** Must complete within existing hook time budget (NFR2).

## Constraints

- **Non-blocking** (NFR1): Backseat observation must never delay primary agent's tool execution
- **Hook time budget** (NFR2): Bell mode injection completes within existing PostToolUse hook time budget
- **Backward-compatible** (NFR15): Workflows without `tandem:` blocks work unchanged
- **No bell mode schema changes** (NFR12): Tandem uses existing bell message format
- **Token budget** (NFR7): Combined scope overhead stays under 25% per phase
- **Haiku for subagents**: Backseat agents use Haiku model, never Opus
- **Return result objects**: Framework functions return `{success, data?, error?}` instead of throwing
- **Use `.js` extensions**: All relative TypeScript imports use `.js` extensions

## Dependencies

**Depends on:** Nothing. This is the core tandem engine with no prerequisite epics.

**Depended on by:**
- Epic 96 (Cyclist Tandem UI) -- reads tandem state to render backseat portrait, needs observation events for pulse animation
- Epic 97 (CLI Tandem & Shipping Workflow) -- statusline reads tandem state, tdd-tandem workflow uses tandem YAML schema
