# Story Context: 94-1 - Extend usePersona Hook with Streaming State

## Summary

Extend the existing `usePersona` React hook to expose an `isStreaming` boolean flag that reflects whether the active agent is currently generating a response. This provides the foundation for applying visual thinking indicators to the PersonaHeader portrait. The streaming state is derived from the existing WebSocket message stream already used by MessagePanel and must be available to any component that consumes `usePersona`.

## Planning References

- **PRD:** Implements FR20 (partial -- primary portrait throbber foundation). See "Cyclist UI" section and "Technical Architecture Considerations" in `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** See "Component Strategy > Design System Components" in `sprint/planning/tandem-mode-ux-design.md` -- specifically the `usePersona` hook extension with `isStreaming` flag. Also Section "Implementation Roadmap > Phase 1: Baseline"
- **Epics Breakdown:** Story 1.1 validation criteria in `sprint/planning/tandem-mode-epics.md` under "Epic 1: Primary Portrait Thinking Indicator"

## Current State

### usePersona hook (existing)

**File:** `pennyfarthing/packages/cyclist/src/public/hooks/usePersona.ts` (89 lines)

The hook currently:
- Connects to `/ws/persona` WebSocket endpoint (line 39)
- Returns `{ persona: PersonaData | null, isLoading: boolean, error: Error | null }` (line 88)
- `PersonaData` interface has: `character`, `theme`, `role`, `slug`, `quote` (lines 16-22)
- Does NOT track streaming/thinking state

### Streaming state exists elsewhere

**File:** `pennyfarthing/packages/cyclist/src/public/components/panels/MessagePanel.tsx`
- `isStreaming` is tracked as local state within MessagePanel (set to `true` on message events, `false` on complete events)
- Messages get `isStreaming: true` property when agent is actively streaming (lines 106-112, 137-141)
- On completion, all agent messages have `isStreaming` set to `false` (lines 327-333)

**File:** `pennyfarthing/packages/cyclist/src/public/hooks/useMessageStream.ts`
- `useMessageStream()` returns `isStreaming: boolean` (line 15)
- Tracks streaming state via WebSocket `message`/`complete` event types

**File:** `pennyfarthing/packages/cyclist/src/public/contexts/ClaudeContext.tsx`
- Provides `onMessage`, `onComplete` callbacks that components subscribe to
- Does NOT directly expose `isStreaming` -- consumers track it locally

### WebSocket persona server

**File:** `pennyfarthing/packages/cyclist/src/api/persona.ts` (62 lines)
- `broadcastPersona(persona: Persona)` broadcasts to all `/ws/persona` clients (line 14)
- Currently broadcasts character, theme, role, slug, quote
- Does NOT include streaming state in broadcasts

**File:** `pennyfarthing/packages/cyclist/src/pennyfarthing.ts`
- `Persona` interface: `character`, `displayName`, `role`, `roleDescription`, `style`, `theme`, `slug`, `quote`, `helper`, `ocean` (lines 29-39)
- No streaming-related fields

### Hook exports

**File:** `pennyfarthing/packages/cyclist/src/public/hooks/index.ts` (50 lines)
- Exports `usePersona` and `PersonaData` type (lines 27-28)
- Will need to export updated return type if it changes

## Target State

After implementation:

1. `usePersona()` returns `{ persona, isLoading, error, isStreaming }` where `isStreaming` is a boolean
2. `isStreaming` reflects the active agent's generation state -- `true` while streaming, `false` when idle
3. Components importing `usePersona` can use `isStreaming` to apply visual indicators (e.g., PersonaHeader thinking throbber in story 94-2)
4. The streaming state is derived from one of two approaches:
   - **Option A (preferred):** Subscribe to the existing `/ws/claude` WebSocket stream within `usePersona` and track `message`/`complete` events
   - **Option B:** Extend the `/ws/persona` server-side broadcast to include streaming state, with the server tracking Claude's streaming state
5. `PersonaData` interface may optionally be extended, or `isStreaming` may live on the hook result directly (outside persona)
6. Default value is `false` when no agent is active or no connection exists

## Key Files

### Files to Modify

| File | Path | Purpose |
|------|------|---------|
| `usePersona.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/usePersona.ts` | Add `isStreaming` to hook return value |
| `index.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/index.ts` | Update exports if return type changes |

### Files to Potentially Modify (Option B only)

| File | Path | Purpose |
|------|------|---------|
| `persona.ts` | `pennyfarthing/packages/cyclist/src/api/persona.ts` | Broadcast streaming state changes |
| `websocket.ts` | `pennyfarthing/packages/cyclist/src/websocket.ts` | Wire streaming state to persona broadcasts |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| `useMessageStream.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useMessageStream.ts` | Pattern for tracking `isStreaming` via WebSocket (lines 13-16, 30-33) |
| `MessagePanel.tsx` | `pennyfarthing/packages/cyclist/src/public/components/panels/MessagePanel.tsx` | How `isStreaming` is currently derived from message/complete events (lines 106-112, 327-333) |
| `ClaudeContext.tsx` | `pennyfarthing/packages/cyclist/src/public/contexts/ClaudeContext.tsx` | `onMessage`/`onComplete` subscription pattern |
| `Message.tsx` | `pennyfarthing/packages/cyclist/src/public/components/Message.tsx` | How `isStreaming` drives `avatar-thinking` class on message avatars (line 40) |
| `pennyfarthing.ts` | `pennyfarthing/packages/cyclist/src/pennyfarthing.ts` | Server-side `Persona` interface (lines 29-39) |

## Technical Approach

### Recommended: Option A -- Subscribe to ClaudeContext within usePersona

This keeps streaming state on the client side without server changes. The hook subscribes to `onMessage` and `onComplete` from `ClaudeContext`:

```typescript
// In usePersona.ts
import { useClaudeContext } from '../contexts/ClaudeContext';

export function usePersona(): UsePersonaResult {
  const [persona, setPersona] = useState<PersonaData | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const [isStreaming, setIsStreaming] = useState(false);
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<ReturnType<typeof setTimeout>>();

  // Track streaming state from Claude context
  const claude = useClaudeContext();

  useEffect(() => {
    const unsubMessage = claude.onMessage(() => setIsStreaming(true));
    const unsubComplete = claude.onComplete(() => setIsStreaming(false));
    return () => { unsubMessage(); unsubComplete(); };
  }, [claude]);

  // ... existing WebSocket connection logic unchanged ...

  return { persona, isLoading, error, isStreaming };
}
```

Update the `UsePersonaResult` interface:

```typescript
interface UsePersonaResult {
  persona: PersonaData | null;
  isLoading: boolean;
  error: Error | null;
  isStreaming: boolean;
}
```

### Alternative: Option B -- Server-side streaming broadcast

If `usePersona` cannot access `ClaudeContext` (e.g., it's used outside the ClaudeContext provider), the server can broadcast streaming state changes on the `/ws/persona` channel:

1. In `websocket.ts`, listen for Claude streaming events and call `broadcastPersona` with a streaming flag
2. Extend `PersonaData` to include `isStreaming`
3. `usePersona` picks it up automatically from the existing WebSocket handler

### Implementation Steps

1. Add `isStreaming` state to `usePersona` hook (default `false`)
2. Subscribe to streaming state changes (via ClaudeContext or WebSocket)
3. Update `UsePersonaResult` interface
4. Update exports in `hooks/index.ts` if needed
5. Write tests confirming `isStreaming` transitions correctly

## Acceptance Criteria

- `usePersona()` returns `isStreaming: boolean` in its result object
- When the primary agent is actively streaming, `isStreaming` is `true`
- When streaming stops (complete event), `isStreaming` transitions to `false`
- When no agent is active, `isStreaming` defaults to `false`
- Existing `usePersona` consumers (PersonaHeader, MessagePanel) are not broken
- The `PersonaData` interface remains backward-compatible

## Dependencies

### Depends On

- No other Tandem Mode stories -- this is the foundation story with no blockers
- Existing infrastructure: `ClaudeContext` or `/ws/persona` WebSocket

### Depended On By

- **94-2** (Apply thinking throbber to PersonaHeader portrait) -- consumes `isStreaming` from this hook
- **96-1** (TandemPortrait component) -- will extend `usePersona` further with tandem agent state
- **96-3** (Observation pulse on primary portrait) -- uses streaming state for animation coordination

## Risks / Open Questions

1. **ClaudeContext availability:** If `usePersona` is used in components that render outside the `ClaudeContext` provider tree, Option A will fail. Need to verify the component hierarchy. If this is a concern, use Option B (server-side broadcast) instead.

2. **Duplicate streaming state tracking:** Multiple components already track `isStreaming` locally (MessagePanel, useMessageStream). Adding it to `usePersona` creates another source. Consider whether to consolidate into a single source of truth, or accept the duplication since each consumer has different lifecycle needs.

3. **Timing edge case:** If `usePersona` subscribes to `onComplete` and the component unmounts/remounts during streaming, `isStreaming` could get stuck. Ensure cleanup handlers properly reset state.

4. **Performance:** Adding a WebSocket subscription or context subscription adds minimal overhead, but verify no unnecessary re-renders cascade from frequent `isStreaming` state changes during active streaming.
