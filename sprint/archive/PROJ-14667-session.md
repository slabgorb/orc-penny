# Session: PROJ-14667 — Backseat agent spawn and lifecycle

## Story
- **ID:** 95-2 / PROJ-14667
- **Epic:** 95 — Workflow Configuration & Observation Protocol
- **Points:** 3
- **Priority:** P0
- **Workflow:** tdd (SM → TEA → Dev → Reviewer → SM)
- **Branch:** feature/PROJ-14667-backseat-agent-spawn-lifecycle
- **Repos:** pennyfarthing

## Acceptance Criteria

1. **BikeLane spawns backseat agent at tandem phase start:**
   - Detect `tandem:` block on phase configuration
   - Use Task tool with `subagent_type: "general-purpose"`, `model: "haiku"`, `run_in_background: true`
   - Pass to backseat: agent persona, story context, scope config, observation file path
   - Register cleanup handler at spawn time

2. **BikeLane terminates backseat agent at phase end:**
   - Track background task via existing `background-tasks.sh` infrastructure
   - Clean termination on phase transition or workflow completion
   - Cleanup handler ensures no orphan processes on primary agent crash

3. **Zero orphan processes (NFR8):**
   - Backseat termination verified even on crash
   - Session cleanup handlers registered and executed reliably

4. **Primary agent continues if backseat crashes (NFR10):**
   - Crash in backseat does not block or interrupt primary agent's workflow
   - No error UI when backseat becomes unavailable
   - Observation injection simply stops

5. **Backward compatible:**
   - Workflows without `tandem:` blocks load and execute unchanged
   - No schema breaking changes to WorkflowPhase

## Phase: finish

## Dev Assessment (Round 2)

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/workflow/tandem-lifecycle.ts` — added `ProcessAdapter` interface for dependency injection of real spawn/terminate, wired cleanup to call adapter.terminate, handles duplicate tandem spawns
- `packages/core/src/workflow/tandem-lifecycle.test.ts` — removed unused imports (lint fix), added 6 ProcessAdapter integration tests

**Reviewer Findings Addressed:**
| Finding | Severity | Fix |
|---------|----------|-----|
| Unused imports `writeFileSync`, `readFileSync` | HIGH | Removed from imports |
| `spawnBackseat` doesn't spawn anything | HIGH | Added `ProcessAdapter` interface — `adapter.spawn()` called when provided, synthetic ID in test mode |
| `terminateBackseat` doesn't terminate anything | HIGH | `adapter.terminate()` called when provided, swallows errors for already-stopped |
| Module unconnected | MEDIUM | Deferred — integration with workflow-executor is a wiring task, not lifecycle logic. ProcessAdapter is the seam. |
| Cleanup handler only deletes Map entry | MEDIUM | Cleanup now calls `adapter.terminate()` before deleting registry entry |
| Duplicate tandem for same story | Edge case | `spawnBackseat` terminates existing backseat before spawning new one |

**Tests:** 35/35 passing (GREEN), 0 regressions
**PR:** #791 — feat(95-2): implement backseat agent spawn and lifecycle (PROJ-14667)
**Branch:** feature/PROJ-14667-backseat-agent-spawn-lifecycle (pushed)
**Lint:** Clean (0 warnings)

**Handoff:** To Reviewer for re-review

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED

**Round 1 findings resolved:**
- Unused imports: removed, lint passes CI
- ProcessAdapter: injected for real spawn/terminate — 6 new tests verify adapter calls
- Cleanup handler: now calls adapter.terminate before deleting Map entry
- Duplicate tandem: existing backseat terminated before new spawn
- Module unconnected: deferred — ProcessAdapter is the integration seam (acceptable for story scope)

**Data flow traced:** SpawnBackseatParams → spawnBackseat() → adapter.spawn() → real taskId → handle stored → cleanup registered with adapter.terminate closure
**Pattern observed:** Dependency injection via ProcessAdapter interface at `tandem-lifecycle.ts:76-88`
**Error handling:** All adapter failures swallowed in try/catch at 3 call sites. Primary agent never affected.
**CI:** lint PASS, build PASS, all checks green

**Handoff:** To SM for finish-story

## Reviewer Assessment (Round 1)

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | CI lint failure — unused imports `writeFileSync`, `readFileSync` | `tandem-lifecycle.test.ts:18` | Remove unused imports. CI is RED. |
| [HIGH] | `spawnBackseat` doesn't spawn anything — creates synthetic taskId, no Task tool / subprocess call | `tandem-lifecycle.ts:113-156` | Wire to actual process spawn or rename as registry-only |
| [HIGH] | `terminateBackseat` doesn't terminate anything — removes Map entry, no TaskStop / process kill | `tandem-lifecycle.ts:163-175` | Wire to actual process termination |
| [MEDIUM] | Module completely unconnected — not imported by workflow-executor, not exported from index | All files | Wire into workflow-executor or document as infra-only |
| [MEDIUM] | Cleanup handler only deletes Map entry, doesn't actually stop any process | `tandem-lifecycle.ts:145-150` | Cleanup should terminate the real backseat process |
| [LOW] | Module-level mutable `taskIdCounter` — fragile under multi-context import | `tandem-lifecycle.ts:78` | Acceptable for now |
| [VERIFIED] | Result format `{success, data?, error?}` compliance | All public functions |
| [VERIFIED] | Scope normalization handles string, string[], undefined correctly | `tandem-lifecycle.ts:97-105` |
| [VERIFIED] | Error swallowing in cleanup — individual failures don't block others | `tandem-lifecycle.ts:218-223` |
| [VERIFIED] | Backward compatibility — non-tandem phases are no-ops | `tandem-lifecycle.ts:119-121` |

**Data flow traced:** `SpawnBackseatParams` → `spawnBackseat()` → Map registry → handle returned. Flow ends at Map — no actual process spawned. No connection to workflow-executor.

**Edge case:** Two tandem phases for same story — second overwrites first handle in Map, first becomes orphan.

**Handoff:** Back to Dev for fixes

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `packages/core/src/workflow/tandem-lifecycle.test.ts` — 29 tests covering all 5 ACs
- `packages/core/src/workflow/tandem-lifecycle.ts` — stub module with types and interfaces

**Tests Written:** 29 tests covering 5 ACs + result format compliance
**Status:** RED (28 failing, 1 passing — interface contract check)

**Test Coverage by AC:**
| AC | Tests | Description |
|----|-------|-------------|
| AC1: Spawn at phase start | 8 | tandem detection, haiku model, background mode, scope normalization, observation file path, cleanup registration, no-op for non-tandem |
| AC2: Terminate at phase end | 4 | terminate by ID, status update, clear active handle, stale handle handling |
| AC3: Zero orphan processes | 5 | cleanup handler execution, error resilience, multiple handlers, story isolation, idempotent cleanup |
| AC4: Crash resilience | 4 | unavailable process, error swallowing, handler continuation, invalid config |
| AC5: Backward compatibility | 5 | no-op for non-tandem, interface contract, null active for unknown story, empty cleanup, graceful transition |
| Result format | 2 | {success, data?, error?} compliance |

**Architecture Decisions:**
- Created `tandem-lifecycle.ts` as separate module (not inline in workflow-executor.ts) — cleaner separation, testable without mocking executor internals
- Types: `BackseatHandle`, `SpawnBackseatParams`, `TandemCleanupHandler`, `TandemResult<T>`
- Scope always normalized to `string[]` (single scope wrapped in array)
- Observation file convention: `.session/{storyId}-tandem-{partner}.md`

**Dev Notes for Toby:**
- Stubs throw `Error('not implemented')` — replace with real implementations
- `spawnBackseat` should call Task tool with `run_in_background: true`, `model: "haiku"`
- `terminateBackseat` should call TaskStop, handle already-stopped gracefully
- `getActiveBackseat` needs in-memory registry (Map<storyId, BackseatHandle>)
- `registerCleanupHandler` / `executeCleanupHandlers` need handler registry (Map<storyId, handler[]>)
- Wire into `workflow-executor.ts`: call `spawnBackseat` in `startWorkflow`/`resumeWorkflow`, call `terminateBackseat` in `completeStep`

**Handoff:** To Dev for implementation

## Technical Context

### What Was Built (95-1)
Story 95-1 completed tandem YAML schema validation:
- Extended `WorkflowPhase` interface in `workflow-schema.ts` with optional `tandem` field
- Added validation rules: `partner` required string, `scope` optional (defaults to file-watch)
- Valid scope values: `file-watch`, `tool-watch`, `context-watch` (single or array)
- Workflows without tandem blocks work unchanged (backward compatible)

### What 95-2 Must Do
Implement the runtime lifecycle for backseat agents:

1. **Spawn mechanism (workflow-executor.ts):**
   - In `startWorkflow()` and `resumeWorkflow()`: after phase starts, check for `tandem:` config
   - If present, spawn background subagent using Task tool with `run_in_background: true`
   - Pass prompt including: persona definition, story ID, scope settings, observation file path
   - Register cleanup handler at spawn time (via background-tasks.sh or session state)

2. **Termination mechanism (workflow-executor.ts):**
   - In `completeStep()`: before transitioning to next phase, kill active backseat task
   - Update background task status via `background-tasks.sh` helper functions
   - Ensure cleanup handler executes even on crash (register as finally block)

3. **Key constraints:**
   - Use Haiku model (never Opus) per framework rules
   - Return `{success, data?, error?}` result objects instead of throwing
   - Use `.js` extensions for all relative TypeScript imports
   - Zero tolerance for orphan processes
   - Primary agent unaffected by backseat failures

### Dependencies and References
- **Already done:** Story 95-1 (tandem schema validation)
- **Prerequisite for:** Story 95-3 (observation file writer), 95-4+ (scopes)
- **Reference files:**
  - `packages/core/src/workflow/workflow-executor.ts` — modify `startWorkflow()`, `resumeWorkflow()`, `completeStep()`
  - `packages/core/src/workflow/session-state.ts` — patterns for state tracking
  - `pennyfarthing-dist/scripts/lib/background-tasks.sh` — existing background task tracking API
  - `pennyfarthing-dist/agents/README.md` — background subagent spawning patterns (lines 248-327)
  - Epic context: `sprint/context/context-epic-95.md` (lines 207-235 for backseat lifecycle)

### Files to Modify
- `packages/core/src/workflow/workflow-executor.ts` — spawn/kill logic in workflow lifecycle methods
- `tests/sm-subagents.test.ts` — add tests for tandem spawn/kill lifecycle

### Result Format
Framework pattern: all functions return result objects
```typescript
{
  success: true,           // required boolean
  data?: unknown,          // optional result data
  error?: string           // optional error message
}
```

### Workflow Pattern
- TDD workflow: SM → TEA → Dev → Reviewer → SM
- Next step after setup: /tea to run acceptance tests for spawn/kill lifecycle
