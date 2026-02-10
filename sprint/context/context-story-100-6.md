# Story 100-6: Sprint panel: play button to start stories inline

## Overview

Add a play button (or similar action button) next to each backlog story in the EnhancedSprintPanel that allows users to immediately start work on a story without manually running `/sprint work [story-id]`. The button should:

1. Be visible only when no active workflow exists (no `.session/*-session.md` file for that story)
2. Launch the story workflow immediately (create session file, invoke SM agent to set up work)
3. Be disabled when a workflow is already active globally to prevent concurrent story work
4. Provide visual feedback during the start process

## Key Files

### Frontend Components
| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/src/public/components/panels/SprintPanel.tsx` | EnhancedSprintPanel component — renders story items in epic tree |
| `pennyfarthing/packages/cyclist/src/public/hooks/useSprint.ts` | useSprint hook — provides sprint data via WebSocket |
| `pennyfarthing/packages/cyclist/src/sprint-data.ts` | Sprint data aggregation — parses YAML, detects active sessions |

### Backend/API
| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/src/websocket.ts` | WebSocket server setup and broadcast logic |
| `pennyfarthing/packages/cyclist/src/server.ts` | Express API router setup |
| `pennyfarthing/packages/cyclist/src/api/` | API endpoint handlers |

### Data & Session Management
| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/src/story-parser.ts` | Session file parsing, story info extraction |
| `.session/{story-id}-session.md` | Session marker files (existence indicates active workflow) |
| `sprint/context/context-story-{id}.md` | Story context files (checked via hasContext flag) |

## Technical Approach

### 1. Detect Active Workflows

In `sprint-data.ts`, enhance the session detection logic (currently in `getStoryInfo()`) to:

- Check if any `.session/*-session.md` file exists globally (indicates active workflow)
- Store this as a new `activeWorkflow` property on `SprintData`
- Return the story ID of the currently active story to UI

**Changes:**
- Add `activeStoryId: string | null` and `hasActiveWorkflow: boolean` to `SprintData` interface
- Enhance `getSprintData()` to detect active sessions and pass to WebSocket broadcast

### 2. Add UI Play Button

In `SprintPanel.tsx`, modify the story item rendering (around line 504-558) to:

- Import `Play` icon from lucide-react (already imported for other icons)
- Render a small play button next to each backlog story (status === 'backlog')
- Hide button if story already has a session (`story.hasSession` flag)
- Disable button if global workflow is active (`data?.activeWorkflow`)
- Add hover tooltip: "Start this story immediately"

**Changes:**
- Add `PlayButton` component (or inline button) with click handler
- Pass callback to handle story start action

### 3. Create API Endpoint

Add `/api/sprint/start-story/{storyId}` POST endpoint in new file `pennyfarthing/packages/cyclist/src/api/sprint.ts`:

```typescript
export function createSprintRouter(getProjectDir: () => string): Router {
  const router = Router();

  router.post('/start-story/:storyId', async (req, res) => {
    try {
      const projectDir = getProjectDir();
      const storyId = req.params.storyId;

      // 1. Verify story exists in sprint YAML
      // 2. Create session file with initial metadata
      // 3. Invoke the SM setup workflow
      // 4. Return success with session info
    } catch (err) {
      res.status(500).json({ error: (err as Error).message });
    }
  });

  return router;
}
```

**Key logic:**
- Use `getSprintData()` to validate story exists and is in backlog
- Create `.session/{story-id}-session.md` with initial content (workflow type, story ID, phase: "setup")
- Call out to `sm-setup` subagent (via Task or direct invoke) to claim Jira, create branch
- Return session file path and initial state

### 4. Wire UI to API

In `EnhancedSprintPanel`, add click handler for play button:

```typescript
const handleStartStory = async (storyId: string) => {
  setLoadingActions((prev) => new Set(prev).add(`start-${storyId}`));
  try {
    const response = await fetch(`/api/sprint/start-story/${storyId}`, {
      method: 'POST'
    });
    if (!response.ok) throw new Error('Failed to start story');
    // UI will refresh via WebSocket broadcast of updated session
  } catch (err) {
    setActionError(err instanceof Error ? err : new Error('Start story failed'));
  } finally {
    setLoadingActions((prev) => {
      const next = new Set(prev);
      next.delete(`start-${storyId}`);
      return next;
    });
  }
};
```

### 5. Enhance SprintStory Interface

Update `useSprint.ts` to include:

```typescript
export interface SprintStory {
  // ... existing fields ...
  hasSession?: boolean;  // True if .session/{story-id}-session.md exists
}
```

### 6. Broadcast Active Workflow State

In `websocket.ts`, enhance the sprint WebSocket broadcast to include:
- `activeWorkflow: boolean` - true if any session file exists
- `activeStoryId: string | null` - ID of story in current session

This prevents concurrent work and disables the play button globally when a workflow is active.

## Implementation Sequence

1. **Phase 1 - Backend Infrastructure**
   - Create `sprint.ts` router with `/api/sprint/start-story/{storyId}` endpoint
   - Wire router into `server.ts`
   - Implement session creation and SM handoff logic
   - Add active workflow detection to `sprint-data.ts`
   - Broadcast active state via WebSocket

2. **Phase 2 - Frontend UI**
   - Add `Play` icon import and `PlayButton` component to `SprintPanel.tsx`
   - Update story item rendering to show play button
   - Add click handler and loading state management
   - Disable button when workflow active or story has session
   - Add tooltips

3. **Phase 3 - Testing**
   - Manual test: Click play button on backlog story
   - Verify session file created
   - Verify SM agent invoked
   - Verify button disabled during workflow
   - Verify button hidden after story starts
   - Test concurrent prevention (global lock)

## Acceptance Criteria

- [ ] Play button renders next to each backlog story in current epics section
- [ ] Button shows only when no `.session/{story-id}-session.md` exists AND no global workflow active
- [ ] Clicking button immediately creates session and invokes SM setup workflow
- [ ] Button shows loading spinner during start process
- [ ] Button is disabled when any workflow is active (prevents concurrent work)
- [ ] Disabled button has tooltip explaining why (e.g., "Workflow already active")
- [ ] Button is hidden once story starts (session file exists)
- [ ] Play icon is visually consistent with other action icons (Archive, Promote)
- [ ] No errors in browser console or server logs
- [ ] SM agent receives correct story context and begins workflow
- [ ] Button works for stories in all epics, not just first epic

## Implementation Notes

### Session File Format

When creating a session file via the play button, use the same format as SM would:

```markdown
# Story: {story-id}

**Story:** {story-id}
**Title:** {title}
**Points:** {points}
**Workflow:** {workflow}
**Status:** setup
**Phase:** setup

## Workflow State
- Started: {timestamp}
- Active: true
```

### Global Workflow Detection

A "global workflow" is active when ANY `.session/*-session.md` file exists. This ensures:
- Only one agent is working at a time
- UI prevents accidental concurrent story starts
- The SM can coordinate handoffs properly

### Electronify Consideration

The SprintPanel already handles Electron API for archive/promote:
```typescript
if (typeof window !== 'undefined' && (window as any).electronAPI?.sprint?.archiveEpic) {
  await (window as any).electronAPI.sprint.archiveEpic(epicId);
}
```

The play button should use the REST endpoint approach for now (no Electron API), since the backend API is being created fresh. Can add Electron API bridge later if needed.

### Related Stories

- Story 100-3: Enhanced Epic/Story management UI
- Story 100-5: Archive/Promote buttons (parallel pattern)
- Story MSSCI-14189: Original EnhancedSprintPanel implementation

## References

- Reflector markers: `pennyfarthing/pennyfarthing-dist/guides/reflector.md` (for UI handoff protocol)
- Sprint skill: `pennyfarthing/pennyfarthing-dist/skills/sprint/skill.md` (workflow start logic)
- Session format: `.session/*.md` files in project root
- SM agent: `pennyfarthing/pennyfarthing-dist/agents/sm.md` (workflow coordinator)
