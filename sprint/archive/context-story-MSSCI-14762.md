# Context: MSSCI-14762 — Quick agent picker in control bar

## Summary
Add a compact agent picker dropdown to the ControlBar component, positioned before the Bell Mode toggle. Uses a Lucide icon as trigger. Lightweight dropdown (not a modal) for rapid agent switching.

## Acceptance Criteria
1. Compact agent picker in ControlBar, positioned before Bell Mode toggle
2. Appropriate Lucide icon as trigger button
3. Lightweight dropdown listing available agents (role + character name)
4. Selecting an agent sends `/{role}` command to switch agents
5. Picker updates in real-time when active agent changes (WebSocket persona)
6. Existing AgentPopup (PersonaHeader click) unchanged
7. Tests: rendering, dropdown open/close, agent selection, real-time updates

## Architecture
- **Component:** New `AgentQuickPicker` in ControlBar
- **Data:** `/api/theme-agents/full` endpoint (same as AgentPopup)
- **Switch mechanism:** `useClaudeContext().send("/{role}")`
- **Real-time:** `usePersona()` hook for current agent state
- **Position:** Before Bell Mode in `.control-bar-toggles`

## Key Files
- `packages/cyclist/src/public/components/ControlBar.tsx` — add picker here
- `packages/cyclist/src/public/components/AgentPopup.tsx` — reference for data fetching/switching
- `packages/cyclist/src/public/hooks/usePersona.ts` — persona WebSocket hook
- `packages/cyclist/src/public/contexts/ClaudeContext.tsx` — send() for commands
- `packages/cyclist/src/public/styles/tailwind.css` — styles
