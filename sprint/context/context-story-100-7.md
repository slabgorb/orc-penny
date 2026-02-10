# Story 100-7: Sprint panel: fix next-up to honor assigned_to field

## Overview

The EnhancedSprintPanel's "Next Up" section currently shows the next backlog story by finding the first unstarted story in epic order, completely ignoring the `assigned_to` field on stories. This causes the UI to suggest stories that may be assigned to other team members rather than surfacing work that belongs to the current user first.

The fix should:
1. Fetch the current user's Jira email via `/api/identity`
2. Sort backlog stories to surface those assigned to the current user first
3. Fall back to priority-based ordering when a user has no assignments or when showing unassigned stories

## Key Files

**Frontend (UI and data fetching):**
- `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/public/components/panels/SprintPanel.tsx` — EnhancedSprintPanel component, renders "Next Up" section at lines 402-407
- `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/sprint-data.ts` — `getSprintData()` function that calculates `nextStory` at lines 353-362
- `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/public/hooks/useSprint.ts` — `useSprint()` hook that fetches sprint data via WebSocket `/ws/sprint`

**Backend (server-side sprint data):**
- `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/websocket.ts` — Sprint WebSocket handler at lines 825-847, calls `getSprintData(projectDir)`
- `/Users/keithavery/Projects/pf-1/pennyfarthing/packages/cyclist/src/api/identity.ts` — Identity API endpoint `GET /api/identity` that returns current user's Jira email

**Data structure:**
- `/Users/keithavery/Projects/pf-1/sprint/current-sprint.yaml` — Sprint YAML with stories containing `assigned_to` field (e.g., line 78 in yaml)

## Technical Approach

### Step 1: Fetch Current User Identity (Frontend)
The UI already has access to the Jira email via `/api/identity`. The useSprint hook can fetch this once on mount and pass it to the data fetching layer.

### Step 2: Modify Sprint Data Aggregation (Backend)
Update `getSprintData()` in `sprint-data.ts`:
- Accept an optional `currentUserEmail` parameter
- When determining `nextStory` (lines 353-362), filter and sort backlog stories:
  1. First, find all backlog stories assigned to `currentUserEmail`
  2. Return the first one (highest priority among user's assignments)
  3. If no user assignments exist, fall back to the current logic (first backlog story)

### Step 3: Pass User Identity to Sprint Data
Modify the sprint WebSocket handler in `websocket.ts`:
- When a client connects to `/ws/sprint`, fetch the user's Jira email
- Pass it to `getSprintData(projectDir, currentUserEmail)`
- Include user email in the initial message so the frontend knows whose assignments it's showing

Alternatively (simpler):
- Have the useSprint hook fetch `/api/identity` on mount
- Send the user email in the WebSocket connection query string or initial handshake
- Use it to filter nextStory on the server side before broadcasting

### Step 4: Update Type Definitions
Ensure SprintData interface and SprintStory interface properly reflect the `assignedTo` field (already present in `sprint-data.ts` at line 29).

## Implementation Notes

- **Comparison:** The `assigned_to` field in YAML is a string (email). Compare against `jiraEmail` from `/api/identity` which is also a string.
- **Fallback behavior:** If user identity cannot be determined or no email is available, gracefully fall back to existing priority-based ordering.
- **WebSocket architecture:** The sprint data is computed server-side in `getSprintData()` and sent to the client via `/ws/sprint`. No client-side filtering needed.
- **Story assignment:** Currently shown in the UI at lines 507-530 of SprintPanel.tsx (formatAssignee function and assignee display). Reuse the same assignment logic for filtering.

## Acceptance Criteria

- [x] Current user's Jira email is available to sprint data calculation
- [x] nextStory prioritizes stories assigned to current user
- [x] nextStory falls back to priority ordering if user has no assignments
- [x] nextStory gracefully handles missing user identity
- [x] UI "Next Up" section displays the correctly prioritized story
- [x] Tests verify user-assigned stories surface before unassigned/other-assigned stories
- [x] Story context file exists (this file)
