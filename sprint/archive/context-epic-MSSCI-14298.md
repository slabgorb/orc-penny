# Epic: MSSCI-14298 - Stepped Workflow Infrastructure

## Overview

Fix stepped workflow support in Cyclist and the framework. Stepped workflows (epics-and-stories, prd, research, etc.) use a subdirectory pattern with `workflow.yaml` + `steps/` that is not fully handled by existing code paths. Three bugs identified:

1. **Session state never updates** - step advancement API exists but nothing calls it
2. **WorkflowPanel can't find subdirectory workflow definitions** - only flat-file lookup
3. **No workflow discovery in panel** - users can't see which workflows are available/applicable

## Stories

| ID | Title | Points | Priority | Status |
|----|-------|--------|----------|--------|
| MSSCI-14299 | Wire up stepped workflow session state advancement | 5 | P0 | in_progress |
| MSSCI-14300 | Add subdirectory workflow lookup to getWorkflowPhases | 3 | P0 | backlog |
| MSSCI-14301 | Show available applicable workflows in WorkflowPanel | 3 | P1 | backlog |

## Technical Context

### Stepped Workflow Architecture

Pennyfarthing has two workflow types:
- **Phased workflows** (tdd, bdd, trivial, agent-docs, patch) - agent-driven with automatic handoffs, defined as flat YAML files (e.g., `tdd.yaml`)
- **Stepped workflows** (15 total) - progressive disclosure with gates, defined in subdirectories (e.g., `epics-and-stories/workflow.yaml` + `steps/step-*.md`)

### 15 Stepped Workflows

architecture, brainstorming, code-review, dev-story, epics-and-stories, git-cleanup, implementation-readiness, interactive-debug, prd, product-brief, project-context, project-setup, quick-dev, quick-spec, release, research, retrospective, sprint-planning, ux-design

### Existing TypeScript API (packages/core/src/workflow/)

The framework has a complete but **unwired** TypeScript API for stepped workflow state:

- **session-state.ts** - `WorkflowState` interface, `initWorkflowState()`, `updateWorkflowState()`, `parseSessionState()`, `updateSessionContent()`, `formatWorkflowState()`
- **step-parser.ts** - `parseStepFile()`, `parseStepFromPath()` for reading `<step-meta>` blocks and `<!-- GATE -->` markers
- **workflow-executor.ts** - `startWorkflow()`, `resumeWorkflow()`, `completeStep()`, `getWorkflowStatus()`, `loadStep()`, `hasActiveWorkflow()`, `detectIncompleteWorkflow()`
- **variable-resolver.ts** - Template variable substitution in step content
- **gate-handler.ts** - Gate checkpoint handling
- **trimodal.ts** - Tri-modal (create/validate/edit) mode support

### The Core Problem (MSSCI-14299)

`completeStep()` in `workflow-executor.ts` works correctly in unit tests but **nothing invokes it** at runtime. There is:
- No CLI command to advance step state
- No HTTP endpoint on WheelHub
- No skill definition for step completion
- No hook that fires after step execution

The `/workflow` command (commands/workflow.md) references `start`, `resume`, and `status` but these are documentation-only -- no actual step completion mechanism exists.

### Session File Format

Workflow state is tracked in a `## Workflow State` markdown section within session files:

```markdown
## Workflow State
- **Workflow Name:** architecture
- **Type:** stepped
- **Mode:** create
- **Started:** 2026-01-20T10:00:00.000Z
- **Last Updated:** 2026-01-20T11:30:00.000Z
- **Current Step:** 3
- **Steps Completed:** [1, 2]
- **Status:** in_progress
```

### WorkflowPanel (MSSCI-14300)

`WorkflowPanel.tsx` displays workflow type badge and phase progress but:
- Only receives data from `story-parser.ts` `getWorkflowPhases()` which only checks flat-file paths
- Shows "No active workflow" for all 15+ subdirectory workflows
- Needs `{name}/workflow.yaml` search paths added alongside `{name}.yaml`

### Available Workflows Display (MSSCI-14301)

`WorkflowPanel.tsx` currently shows only the active workflow. When no workflow is active (or even when one is), users have no way to see which workflows are available and applicable. The panel should list available workflows that can be started, filtered by relevance to the current project context (e.g., based on triggers, tags, or project type).

## Key Files

- `pennyfarthing/packages/core/src/workflow/session-state.ts` - State read/write API
- `pennyfarthing/packages/core/src/workflow/workflow-executor.ts` - Step completion logic
- `pennyfarthing/packages/core/src/workflow/step-parser.ts` - Step file parsing
- `pennyfarthing/packages/core/src/workflow/index.ts` - Module exports (does NOT export executor/session-state)
- `pennyfarthing/packages/cyclist/src/public/components/panels/WorkflowPanel.tsx` - UI panel
- `pennyfarthing/packages/cyclist/src/story-parser.ts` - `getWorkflowPhases()` lookup
- `pennyfarthing/pennyfarthing-dist/commands/workflow.md` - `/workflow` command definition
- `pennyfarthing/pennyfarthing-dist/workflows/*/workflow.yaml` - Stepped workflow definitions
