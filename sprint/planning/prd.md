---
stepsCompleted:
  - step-01-init
  - step-01b-continue
  - step-02-discovery
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
inputDocuments:
  - sprint/planning/bikerack-prd.md
  - sprint/planning/bikerack-prd-ideas.md
  - docs/adr/0024-bikerack-mode.md
workflowType: 'prd'
documentCounts:
  briefCount: 0
  researchCount: 0
  brainstormingCount: 0
  projectDocsCount: 3
classification:
  projectType: Developer Tooling (UI Component)
  domain: Developer Experience (DX)
  complexity: Low
  projectContext: brownfield
---

# Product Requirements Document - ProgressPanel

**Author:** Keith Avery
**Date:** 2026-02-14

## Overview

A new Cyclist panel that combines acceptance criteria, todos, workflow phase, current story context, and git status into a single at-a-glance view. Follows the same patterns as SprintPanel and ChangedPanel — a React component subscribing to existing WebSocket channels. No backend work required.

## Success Criteria

### User Success

- Developer sees story progress without switching between AC, Todo, Workflow, and Git panels
- At a glance: what story am I on, what phase, what's left to do, what's changed

### Business Success

- Reduces panel clutter in Cyclist and BikeRack layouts
- Makes progress visible in a single panel slot instead of four

### Technical Success

- Uses existing hooks: `useStory()`, `useTodos()`, `useGitStatus()`, `useSprint()`
- Zero new WebSocket channels or backend endpoints
- Follows established panel component pattern (loading/error/empty states, shadcn/ui)

### Measurable Outcomes

| Metric | Target |
|--------|--------|
| Data sources | 4 existing WS channels (`/ws/story`, `/ws/todos`, `/ws/git`, `/ws/sprint`) |
| New backend code | 0 lines |
| Panel renders | All 5 data sections visible with live updates |

## Product Scope

### MVP

1. **ProgressPanel component** — single panel combining:
   - Current story identity (ID, title, points, epic)
   - Workflow phase indicator (current phase highlighted in sequence)
   - Acceptance criteria progress (count done / total, checklist)
   - Todo progress (count done / total, active task)
   - Git summary (branch, dirty file count per repo, ahead/behind)

### Out of Scope

- New WebSocket channels or API endpoints
- Backend changes of any kind
- Replacing existing standalone panels (AC, Todo, Workflow, Git remain available)
- BikeRack-specific behavior (panel works identically in both modes)

## User Journeys

### Journey 1: Mid-Story Check-In

Developer is deep in code. Glances at ProgressPanel. Sees: "Story 98-17 / green phase / 3/7 AC done / 2 todos left / 4 modified files on feat branch." Knows exactly where they stand without context-switching.

### Journey 2: Workflow Handoff

Agent completes work and hands off. ProgressPanel shows the workflow phase advancing from "green" to "review." Developer sees the transition in real-time alongside the AC and todo state.

### Journey 3: Session Start

Developer opens Cyclist or BikeRack. ProgressPanel immediately shows current story context — no need to check SprintPanel for "what was I working on?" and then flip to AC/Todo for progress.

## Functional Requirements

### Data Display

- **FR-1:** Display current story ID, title, points, and epic name from `useSprint()` / `useStory()`
- **FR-2:** Display workflow type badge and phase progression from `useStory()` (phased and stepped workflows)
- **FR-3:** Display acceptance criteria as a progress bar with count (done/total) from `useStory()` criteria
- **FR-4:** Display todo items as a progress bar with count (done/total) and current active task from `useTodos()`
- **FR-5:** Display git summary — branch name, dirty file count, ahead/behind — from `useGitStatus()`
- **FR-6:** All data updates in real-time via existing WebSocket channels

### Component Integration

- **FR-7:** Panel exports from `panels/index.ts` like all other panels
- **FR-8:** Panel registers in dockview layout and BikeRack `PANEL_REGISTRY`
- **FR-9:** Panel handles loading, error, and empty states per established pattern

## Non-Functional Requirements

- **NFR-1:** Panel renders within the same latency budget as existing panels (<500ms from data event to display)
- **NFR-2:** No additional WebSocket connections beyond what the 4 hooks already establish
- **NFR-3:** Responsive layout that works in narrow dockview slots and full-width BikeRack standalone view

## Technical Architecture

### Hooks Used

| Hook | Channel | Data Extracted |
|------|---------|---------------|
| `useStory()` | `/ws/story` | Story ID, title, phase, workflow phases, criteria |
| `useTodos()` | `/ws/todos` | Todo items with status |
| `useGitStatus()` | `/ws/git` | Repo status, branch, file counts |
| `useSprint()` | `/ws/sprint` | Current story context, points, epic |

### New Files

| File | Purpose |
|------|---------|
| `src/public/components/panels/ProgressPanel.tsx` | Panel component |

### Modified Files

| File | Change |
|------|--------|
| `src/public/components/panels/index.ts` | Export ProgressPanel |
| Dockview layout config | Register panel |
| BikeRack `PANEL_REGISTRY` (if exists) | Register panel |

### Component Pattern

```typescript
import { useStory } from '../../hooks/useStory';
import { useTodos } from '../../hooks/useTodos';
import { useGitStatus } from '../../hooks/useGitStatus';
import { useSprint } from '../../hooks/useSprint';

export function ProgressPanel(): React.ReactElement {
  const { story } = useStory();
  const { todos } = useTodos();
  const { repos } = useGitStatus();
  const { data: sprintData } = useSprint();

  // Sections: Story Header → Workflow → AC → Todos → Git
}
```
