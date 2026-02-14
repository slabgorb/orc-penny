---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
  - step-05-import-to-future
inputDocuments:
  - sprint/planning/progress-panel-prd.md
  - sprint/planning/progress-panel-ux-design.md
  - sprint/planning/pf-architecture.md
---

# ProgressPanel - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for ProgressPanel, decomposing the requirements from the PRD, UX Design, and Architecture requirements into implementable stories.

## Requirements Inventory

### Functional Requirements

- FR-1: Display current story ID, title, points, and epic name from `useSprint()` / `useStory()`
- FR-2: Display workflow type badge and phase progression for both phased and stepped workflows from `useStory()`
- FR-3: Display acceptance criteria as a progress bar with count (done/total) from `useStory()` criteria
- FR-4: Display todo items as a progress bar with count (done/total) and current active task from `useTodos()`
- FR-5: Display git summary — branch name, dirty file count (modified/untracked), ahead/behind — from `useGitStatus()`
- FR-6: All data updates in real-time via existing WebSocket channels (no polling)
- FR-7: Panel exports from `panels/index.ts` like all other panels
- FR-8: Panel registers in dockview layout and BikeRack `PANEL_REGISTRY`
- FR-9: Panel handles loading, error, and empty states per established pattern
- FR-10: Display context window usage as a progress bar with percentage and color thresholds (normal <70%, elevated 70-89%, high 90%+) from `useContextIndicator()`

### Non-Functional Requirements

- NFR-1: Panel renders within <500ms from data event to display
- NFR-2: No additional WebSocket connections beyond what the 5 existing hooks establish
- NFR-3: Responsive layout that works in narrow dockview slots (200-300px) and full-width BikeRack standalone view

### Additional Requirements

**From UX Design:**

- UX-1: Progressive disclosure — summary counts visible by default, expandable detail sections optional
- UX-2: Graceful degradation — missing data (no AC, no todos) collapses that section entirely; no "0/0" progress bars
- UX-3: Accessibility — `data-testid` on root and sections, `aria-valuenow/min/max` on progress bars, `aria-label` on status icons, color never the sole indicator
- UX-4: Status icon vocabulary matches existing panels: `✓` (done), `●` (current), `◯` (pending)
- UX-5: Reuse existing CSS patterns (`.progress-bar-container`, `.phase-step`, Badge variant="secondary")
- UX-6: Empty state: centered "No active story" message with hint to start a story
- UX-7: No CSS breakpoints needed — vertical stack layout works at any width via natural wrapping and truncation

**From Architecture:**

- None applicable (document covers Python CLI migration, unrelated to this panel)

### FR Coverage Map

| FR | Epic | Story | Description |
|----|------|-------|-------------|
| FR-1 | Epic 1 | 1.1 | Story ID, title, points, epic name |
| FR-2 | Epic 1 | 1.2 | Workflow type badge + phase progression |
| FR-3 | Epic 1 | 1.2 | AC progress bar with count |
| FR-4 | Epic 1 | 1.2 | Todo progress bar with count + active task |
| FR-5 | Epic 1 | 1.3 | Git summary (branch, dirty, ahead/behind) |
| FR-6 | Epic 1 | 1.2, 1.3 | Real-time WebSocket updates |
| FR-7 | Epic 1 | 1.1 | Panel exports from `panels/index.ts` |
| FR-8 | Epic 1 | 1.1 | Dockview + BikeRack registration |
| FR-9 | Epic 1 | 1.1 | Loading, error, empty states |
| FR-10 | Epic 1 | 1.3 | Context window usage with color thresholds |

## Epic List

### Epic 1: ProgressPanel — At-a-Glance Story Dashboard

Developer sees story context, workflow phase, AC completion, todo status, git changes, and context window usage in a single panel — answering "where am I on this story?" without switching between multiple panels.

**FRs covered:** FR-1, FR-2, FR-3, FR-4, FR-5, FR-6, FR-7, FR-8, FR-9, FR-10
**NFRs addressed:** NFR-1, NFR-2, NFR-3
**UX addressed:** UX-1, UX-2, UX-3, UX-4, UX-5, UX-6, UX-7

**Hooks:**

| Hook | Channel | Data |
|------|---------|------|
| `useStory()` | `/ws/story` | Story, phase, workflow, criteria |
| `useTodos()` | `/ws/todos` | Todo items + status |
| `useGitStatus()` | `/ws/git` | Repos, branch, file counts |
| `useSprint()` | `/ws/sprint` | Current story context |
| `useContextIndicator()` | `/ws/context` | Percent, used/total tokens |

## Epic 1: ProgressPanel — At-a-Glance Story Dashboard

Developer sees story context, workflow phase, AC completion, todo status, git changes, and context window usage in a single panel — answering "where am I on this story?" without switching between multiple panels.

### Story 1.1: Panel Scaffold with Story Header

As a developer using Cyclist,
I want a ProgressPanel that shows my current story identity and handles all edge states,
So that I can see what story I'm working on without checking SprintPanel.

**Acceptance Criteria:**

**Given** Cyclist is running with an active story
**When** the ProgressPanel renders
**Then** it displays the story ID, title, points, and epic name from `useSprint()` / `useStory()`

**Given** Cyclist is loading story data from WebSocket channels
**When** the ProgressPanel renders before data arrives
**Then** it displays a skeleton loading state matching panel spacing (`space-y-2 p-2`)

**Given** no story is currently active
**When** the ProgressPanel renders
**Then** it displays a centered "No active story" empty state with a hint to start a story

**Given** a WebSocket connection error occurs
**When** the ProgressPanel renders
**Then** it displays an error message following the established `.error-message` pattern

**Given** the ProgressPanel component exists
**When** it is imported
**Then** it is exported from `panels/index.ts` and registered in both dockview layout config and BikeRack `PANEL_REGISTRY`

### Story 1.2: Workflow Phase and Progress Sections

As a developer mid-story,
I want to see my workflow phase, AC completion, and todo progress in the ProgressPanel,
So that I know how far along I am without switching to three separate panels.

**Acceptance Criteria:**

**Given** the active story has a phased workflow (e.g., tdd)
**When** the ProgressPanel renders the workflow row
**Then** it displays a `Badge variant="secondary"` with the workflow type and phase dots using `✓` (done), `●` (current), `◯` (pending) matching WorkflowPanel's `.phase-step` pattern

**Given** the active story has a stepped workflow
**When** the ProgressPanel renders the workflow row
**Then** it displays the workflow type badge and step progress appropriately

**Given** the active story has acceptance criteria defined
**When** the ProgressPanel renders the AC row
**Then** it displays a progress bar with done/total count (e.g., "5/7") using `.progress-bar-container` CSS pattern

**Given** the active story has no acceptance criteria
**When** the ProgressPanel renders
**Then** the AC section is not rendered (no "0/0" bar, no placeholder text)

**Given** there are active todo items
**When** the ProgressPanel renders the todo row
**Then** it displays a progress bar with done/total count and the current active task name

**Given** there are no todo items
**When** the ProgressPanel renders
**Then** the todo section is not rendered

**Given** a workflow phase changes via `/ws/story`
**When** the WebSocket pushes the update
**Then** the workflow row updates in real-time without user interaction

### Story 1.3: Git Status and Context Meter

As a developer working on a story,
I want to see git status and context window usage in the ProgressPanel,
So that I know what's changed in my repos and how much context I have left.

**Acceptance Criteria:**

**Given** `useGitStatus()` returns repo data
**When** the ProgressPanel renders the git row
**Then** it displays branch name, modified file count (`{N}M`), untracked count (`{N}U`), and ahead/behind (`↑{N} ↓{N}`) in a compact single line

**Given** the branch name is longer than the available width
**When** the ProgressPanel renders in a narrow dockview slot
**Then** the branch name truncates with ellipsis

**Given** `useContextIndicator()` returns context data
**When** the ProgressPanel renders the context row
**Then** it displays a progress bar with percentage, colored by threshold: normal (<70% green), elevated (70-89% amber), high (90%+ red)

**Given** context usage reaches 90%+
**When** the ProgressPanel renders
**Then** the context bar displays in the high/danger color state

**Given** the ProgressPanel is fully rendered
**When** inspecting the DOM
**Then** root and each section have `data-testid` attributes, progress bars have `aria-valuenow/min/max`, and status icons have `aria-label` descriptions

**Given** the panel is rendered in a 200px narrow dockview slot
**When** content wraps or truncates
**Then** layout remains intact with no horizontal overflow, and progress bars scale to container width

**Given** any of the 5 WebSocket channels push an update
**When** the data changes
**Then** the corresponding section updates within <500ms (NFR-1) with no additional WebSocket connections created (NFR-2)
