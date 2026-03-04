---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-18: Replace TypeScript Workflow Engine with pf CLI Delegation

## Business Context

The pennyfarthing framework maintains two parallel implementations of its workflow engine: approximately 2709 lines of TypeScript across six files in `packages/core/src/workflow/`, and the authoritative Python implementation in `pennyfarthing-dist/pf/`. When the Python implementation is updated — to add a new gate type, change session file format, or adjust routing priority — the TypeScript layer must also be updated manually. This drift has already caused byte-compatibility issues: `session-state.ts` reads and writes the `## Workflow State` session section using hardcoded regex patterns that must stay synchronized with what Python writes.

Story 141-16 adds `--json` output to key `pf` subcommands, creating a structured interface. This story (141-18) closes the loop: the TypeScript workflow engine is replaced with thin subprocess delegation to `pf handoff resolve-gate`, `pf workflow route`, and related subcommands. The Python CLI becomes the single source of truth for workflow state and gate logic. TypeScript becomes a rendering and API layer that never directly touches session files or workflow YAML.

## Technical Guardrails

### Files Being Replaced

All six files live at `pennyfarthing/packages/core/src/workflow/`:

| File | Lines | Responsibility |
|------|-------|----------------|
| `handoff.ts` | 595 | Gate condition checking, phase advancement, phase transition formatting |
| `session-state.ts` | 290 | `## Workflow State` section read/write via regex; must stay byte-compatible with Python |
| `workflow-router.ts` | 329 | 5-priority routing algorithm: explicit-tag, trigger-tag, type, points, default |
| `workflow-executor.ts` | 356 | Stepped workflow state machine: start, resume, status |
| `workflow-schema.ts` | 866 | Full TypeScript interfaces and YAML validation for `WorkflowDefinition`, `WorkflowPhase`, gates, tandem, team |
| `gate-handler.ts` | 273 | Gate detection from three sources (YAML, step-meta, `<!-- GATE -->` content marker), gate prompt extraction |

### Key Internal Interfaces (for understanding call sites)

- `handoff.ts` exports: `GateContext`, `GateCheckResult`, `HandoffContext`, `HandoffResult`, `PhaseTransitionParams`
- `session-state.ts` exports: `WorkflowState`, `SessionStateResult`, `UpdateResult`, plus `FIELD_PATTERNS` regex map and `initWorkflowState` / `updateWorkflowState` / `parseSessionState` / `updateSessionContent` functions
- `workflow-router.ts` exports: `StoryMetadata`, `RoutingResult`, and the 5-priority `routeStory()` function
- `workflow-executor.ts` imports from `session-state.ts` and `step-parser.ts`; exports workflow execution entry points
- `workflow-schema.ts` exports: `WorkflowPhase`, `WorkflowDefinition`, `WorkflowValidationError`, `TeamConfig`, `TeamMember`, `GateDefinition`
- `gate-handler.ts` exports: `GateInfo`, `DetectGateParams`; detects gates from workflow YAML, step-meta, and content markers

### pf CLI Delegation Targets (from 141-16)

- `pf workflow route <story-id> --json` — replaces `workflow-router.ts` routing algorithm
- `pf handoff resolve-gate --json` — replaces gate checking logic in `handoff.ts` and `gate-handler.ts`
- `pf workflow phases <story-id> --json` — replaces phase state reads in `workflow-executor.ts`
- `pf handoff status --json` — replaces `HandoffContext` / `HandoffResult` reads
- Session file mutations (writing `## Workflow State`, phase transition markers) must go through `pf handoff complete-phase` and `pf handoff marker` rather than direct file writes

### Subprocess Pattern

Subprocess calls follow the same pattern established in 141-17 for `story-parser.ts`:

```typescript
import { execFile } from 'child_process';
import { promisify } from 'util';
const execFileAsync = promisify(execFile);

async function callPfCli(args: string[]): Promise<{ success: boolean; data?: unknown; error?: string }> {
  try {
    const { stdout } = await execFileAsync('pf', args);
    return { success: true, data: JSON.parse(stdout) };
  } catch (err) {
    return { success: false, error: String(err) };
  }
}
```

### Byte-Compatibility Constraint

`session-state.ts` currently writes the `## Workflow State` markdown section with a specific field format (e.g., `**Workflow Name:** tdd`, `**Steps Completed:** [1,2]`). The Python CLI reads this same format. After this story, TypeScript must never write this section directly — only `pf` writes it. TypeScript reads it by calling `pf handoff status --json` or `pf story info --json`, not by regex-parsing the markdown.

### Result Object Pattern

All replacement functions must return `{success, data?, error?}`. No `throw`. This is a project-wide rule (CLAUDE.md rule 6) and these files are known violators.

### Import Paths

Use `.js` extensions in all relative TypeScript imports (CLAUDE.md rule 5). When removing a file that other modules import, update all call sites.

### Source of Truth for Edits

Edit files at `pennyfarthing/packages/core/src/workflow/` (the inlined framework source). Do not edit `.pennyfarthing/` symlink targets.

## Scope Boundaries

**In scope:**

- Replace `workflow-router.ts` routing logic with `pf workflow route --json` subprocess call
- Replace gate checking in `handoff.ts` and `gate-handler.ts` with `pf handoff resolve-gate --json`
- Replace phase advancement and session transition formatting in `handoff.ts` with `pf handoff complete-phase` and `pf handoff marker` subprocess calls
- Replace `workflow-executor.ts` stepped workflow state machine with `pf workflow` subcommand calls
- Replace `session-state.ts` direct session file read/write with `pf handoff status --json` reads and `pf handoff` mutations
- Replace `workflow-schema.ts` TypeScript YAML validation with delegation to `pf workflow` (pf owns schema validation)
- Update all TypeScript call sites that import from these six files
- Ensure result objects `{success, data?, error?}` are returned throughout
- Tests for the new thin delegation wrappers (TDD workflow: write failing tests first)

**Out of scope:**

- Adding `--json` flags to `pf` CLI commands — that is story 141-16 (this story depends on 141-16 being done)
- Replacing `story-parser.ts` — that is story 141-17
- Replacing `theme-loader.ts` or `pennyfarthing.ts` — that is story 141-19
- Modifying workflow YAML files in `pennyfarthing-dist/workflows/`
- Changing the Python implementation in `pennyfarthing-dist/pf/` (Python is the target, not the subject)
- GUI rendering components in `packages/cyclist/` (those consume the TypeScript API layer, not the workflow engine directly)
- The `step-parser.ts` and `variable-resolver.ts` files imported by `workflow-executor.ts` — only replace the workflow engine delegation, not the step parsing utilities unless they are solely called from these six files

## AC Context

**AC 1: TypeScript workflow files delegate to pf CLI**

- Each of the six files (`handoff.ts`, `session-state.ts`, `workflow-router.ts`, `workflow-executor.ts`, `workflow-schema.ts`, `gate-handler.ts`) either delegates to `pf` via subprocess or is deleted with call sites updated
- Testable: `grep -r "readFileSync\|writeFileSync\|WORKFLOW_STATE_SECTION_REGEX\|FIELD_PATTERNS" packages/core/src/workflow/` returns no matches
- Testable: `grep -r "from './workflow-schema.js'\|from './session-state.js'\|from './handoff.js'\|from './workflow-router.js'\|from './workflow-executor.js'\|from './gate-handler.js'" packages/core/src/` only appears in the replacement delegation modules (not in application code that bypasses them)

**AC 2: No direct session file mutation from TypeScript**

- TypeScript code never calls `writeFileSync` (or equivalent) on session files (`.session/*.md`)
- Phase transitions go through `pf handoff complete-phase`; markers go through `pf handoff marker`
- The `## Workflow State` section is never written by TypeScript
- Testable: `grep -rn "writeFileSync\|fs.write\|appendFileSync" packages/core/src/workflow/` returns no results
- Testable: Integration test calls a phase transition and confirms session file was updated by `pf`, not by TypeScript (file contains `pf`-formatted fields, no TypeScript-specific format variation)

**AC 3: Workflow routing uses pf workflow route**

- `routeStory()` (or its replacement) calls `pf workflow route <story-id> --json` via subprocess
- The 5-priority routing algorithm (explicit-tag, trigger-tag, type, points, default) is no longer implemented in TypeScript
- Testable: Unit test mocks `pf workflow route --json` output and asserts the TypeScript wrapper correctly parses and returns `{success: true, data: {workflow, reason}}`
- Testable: `grep -n "explicit-tag\|trigger-tag\|doesStoryMatchTrigger\|matchType" packages/core/src/workflow/workflow-router.ts` returns no results (algorithm removed)

**AC 4: Gate checking uses pf handoff resolve-gate**

- Gate detection (from YAML, step-meta, and `<!-- GATE -->` content markers) is no longer implemented in TypeScript
- `gate-handler.ts` delegates to `pf handoff resolve-gate --json`
- `handoff.ts` gate checking delegates to `pf handoff resolve-gate --json`
- Testable: Unit test mocks `pf handoff resolve-gate --json` and asserts the TypeScript wrapper returns `{success: true, data: {passed, gateType, message}}`
- Testable: `grep -n "GATE\|isGate\|gateType\|source.*workflow.*step-meta.*marker" packages/core/src/workflow/gate-handler.ts` returns no results (detection logic removed)

**AC 5: Depends on 141-16**

- This story cannot be implemented without `pf workflow route --json`, `pf handoff resolve-gate --json`, `pf handoff status --json`, and related `--json` flags added in story 141-16
- Pre-condition check: `pf workflow route --help` includes `--json` flag; `pf handoff resolve-gate --help` includes `--json` flag
- Testable: CI runs after 141-16 merges; this story's branch is rebased on the branch that includes 141-16 changes
