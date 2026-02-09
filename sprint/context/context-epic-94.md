# Epic 94: Primary Portrait Thinking Indicator (Baseline Fix)

## Overview

Users see a thinking throbber on the main agent portrait in Cyclist's PersonaHeader, resolving a current UX gap where the portrait is static even when the agent is actively working. This is a standalone improvement for all users regardless of Tandem Mode -- it fixes a baseline gap that Tandem builds on.

**Total points:** 4
**Priority:** P1
**Marker:** feature
**Repo:** pennyfarthing
**Stories:** 2

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **PRD** (`sprint/planning/tandem-mode-prd.md`) | FR20 (primary portrait throbber), NFR6 (CSS-only animation) |
| **UX Design Spec** (`sprint/planning/tandem-mode-ux-design.md`) | "Design Opportunities" section (baseline throbber fix), "Animation Hierarchy" table (Tier 1: primary thinking), "Component Strategy" section (Implementation Roadmap Phase 1), "Desired Emotional Response" section (trust through consistency) |
| **Epic Breakdown** (`sprint/planning/tandem-mode-epics.md`) | Epic 1 full section (Stories 1.1-1.2), FR Coverage Map (FR20 partial), NFR Coverage (NFR6) |

## Background

### The Current Gap

The `avatar-throb` animation already exists in Cyclist and is applied to **message avatars** in the conversation stream (the 32px inline portraits next to each message). When a message is streaming, the `Message.tsx` component applies the `.avatar-thinking` CSS class to the avatar, which triggers the `avatar-throb` keyframe animation (1.2s ease-in-out, scale 1.08, accent box-shadow glow).

However, the **PersonaHeader portrait** (the large 100px portrait at the top of the MessagePanel) has no thinking indicator at all. The `PersonaHeader.tsx` component does not consume any streaming state. The `usePersona` hook returns `{ persona, isLoading, error }` but has no `isStreaming` field. This means users looking at the header have no indication whether the agent is working or idle.

### What This Epic Adds

Two changes:
1. Extend `usePersona` to expose `isStreaming` by consuming the WebSocket persona state updates
2. Apply the existing `.avatar-thinking` class to the PersonaHeader portrait when streaming is active

This is deliberately scoped as a baseline fix -- it uses existing CSS, existing animation vocabulary, and existing WebSocket infrastructure. No new visual patterns. The result is that users see the same throbber they already know from message avatars, now also on the header portrait.

## Technical Architecture

### Component Map

```
WebSocket (ws/persona)
  |
  v
usePersona hook (hooks/usePersona.ts)
  +-- persona: PersonaData
  +-- isStreaming: boolean  <-- NEW
  |
  v
PersonaHeader (components/PersonaHeader.tsx)
  +-- .persona-portrait
       +-- .avatar-thinking class (conditional on isStreaming)  <-- NEW
  |
  v
tailwind.css (styles/tailwind.css)
  +-- @keyframes avatar-throb (EXISTING, line ~756)
  +-- .avatar-thinking (EXISTING, line ~767)
```

### Key Files (Existing, to be Modified)

| File | Path | Lines | Change |
|------|------|-------|--------|
| usePersona hook | `packages/cyclist/src/public/hooks/usePersona.ts` | 89 | Add `isStreaming` field to `PersonaData` interface and `UsePersonaResult`; derive from WebSocket state or from `useMessageStream` |
| PersonaHeader | `packages/cyclist/src/public/components/PersonaHeader.tsx` | 195 | Destructure `isStreaming` from `usePersona()`; conditionally apply `.avatar-thinking` class to `.persona-portrait` div |
| tailwind.css | `packages/cyclist/src/public/styles/tailwind.css` | ~4200+ | No changes needed -- `@keyframes avatar-throb` (line 756) and `.avatar-thinking` (line 767) already exist |

### Key Files (Reference Only)

| File | Path | Purpose |
|------|------|---------|
| Message.tsx | `packages/cyclist/src/public/components/Message.tsx` | Reference for how `isStreaming` drives `.avatar-thinking` on message avatars (lines 40, 53, 175-181) |
| useMessageStream | `packages/cyclist/src/public/hooks/useMessageStream.ts` | Source of `isStreaming` state derived from WebSocket message stream (line 15, 32) |
| WebSocket setup | `packages/cyclist/src/websocket.ts` | WebSocket server setup; persona clients managed via `getPersonaClients()` |
| Persona API | `packages/cyclist/src/api/persona.ts` | `broadcastPersona()` sends persona state to WebSocket clients; `createPersonaRouter()` handles REST |

### How isStreaming Gets to PersonaHeader

There are two plausible approaches:

**Option A: Extend the WebSocket persona payload.** The server already broadcasts persona data via `broadcastPersona()` in `api/persona.ts`. The server could include `isStreaming` in the persona payload by detecting active streaming from the OTLP receiver or message stream. The `usePersona` hook already parses WebSocket messages -- adding `isStreaming` to the `PersonaData` interface is minimal.

**Option B: Compose hooks.** `PersonaHeader` could import `useMessageStream` directly to get `isStreaming`, without changing `usePersona` at all. This avoids touching the WebSocket persona protocol but means PersonaHeader imports two hooks.

The PRD and UX spec specify extending `usePersona` (Option A) so that any component consuming persona state automatically gets streaming awareness.

### Existing Animation Details

From `tailwind.css` (lines 756-769):

```css
@keyframes avatar-throb {
  0%, 100% {
    transform: scale(1);
    box-shadow: 0 0 0 0 var(--accent-color, #007acc);
  }
  50% {
    transform: scale(1.08);
    box-shadow: 0 0 8px 2px var(--accent-color, #007acc);
  }
}

.avatar-thinking {
  animation: avatar-throb 1.2s ease-in-out infinite;
}
```

The animation uses `--accent-color` which is theme-aware. It works at any portrait size (already proven on 32px message avatars; PersonaHeader uses 100px and compact mode uses 40px).

## Stories

| Story | Title | Points | Priority | Dependencies |
|-------|-------|--------|----------|-------------|
| 94-1 | Extend usePersona hook with streaming state | 2 | P0 | None |
| 94-2 | Apply thinking throbber to PersonaHeader portrait | 2 | P0 | 94-1 |

## Story Notes

### 94-1: Extend usePersona hook with streaming state

**What to do:** Add `isStreaming: boolean` to the `PersonaData` interface (line 16) and `UsePersonaResult` (line 24) in `usePersona.ts`. The hook currently connects to `ws/persona` and parses incoming JSON as `PersonaData`. The server needs to include `isStreaming` in the persona broadcast.

**Server-side change:** In `packages/cyclist/src/api/persona.ts`, the `broadcastPersona()` function sends persona objects. The `Persona` type (from `pennyfarthing.ts`) needs an `isStreaming` field. The streaming state can be derived from the OTLP receiver -- when tool events or message events indicate active generation, `isStreaming` is `true`.

**Alternatively:** The server-side `websocket.ts` already processes message stream events (it handles `assistant:text`, `tool_use`, etc.). When an `assistant:text` event arrives, streaming is active. When a turn-complete event fires, streaming stops. This state can be broadcast as part of persona updates.

**Key constraint:** `isStreaming` must default to `false` when no agent is active (AC from epic breakdown).

**Workflow:** trivial (SM -> Dev -> Reviewer -> SM)

### 94-2: Apply thinking throbber to PersonaHeader portrait

**What to do:** In `PersonaHeader.tsx`, consume `isStreaming` from `usePersona()` and conditionally apply the `.avatar-thinking` CSS class to the `.persona-portrait` div.

**Current code (line 62):**
```tsx
const { persona } = usePersona();
```

**After change:**
```tsx
const { persona, isStreaming } = usePersona();
```

**Portrait rendering (lines 103-116):** The `.persona-portrait` div wraps the `<img>` element. Apply `.avatar-thinking` conditionally:
```tsx
<div className={`persona-portrait${isStreaming ? ' avatar-thinking' : ''}`} data-testid="persona-portrait">
```

**Compact mode:** The CSS `.persona-header.compact .persona-portrait` reduces the portrait to 40px. The `avatar-throb` animation (scale 1.08) works correctly at this size -- the scale is proportional.

**Reduced motion:** The UX spec requires `prefers-reduced-motion` support. The existing `.avatar-thinking` class does not currently have a reduced-motion fallback. This story should add:

```css
@media (prefers-reduced-motion: reduce) {
  .avatar-thinking {
    animation: none;
    opacity: 0.85;
  }
}
```

This goes in `tailwind.css` after the existing `.avatar-thinking` rule (line 769).

**Workflow:** trivial (SM -> Dev -> Reviewer -> SM)

## Constraints

- **CSS-only animation** (NFR6): The throbber must use CSS `animation` with `@keyframes`, not JS `setInterval`, `requestAnimationFrame`, or polling. The existing `avatar-throb` already satisfies this.
- **No new visual vocabulary**: Reuse `avatar-throb` exactly. Same duration (1.2s), same scale (1.08), same glow. Users should recognize it instantly from message avatars.
- **Backward-compatible**: The `usePersona` hook must continue to work for all existing consumers. `isStreaming` defaults to `false`.
- **`prefers-reduced-motion` support**: All animations must degrade to static opacity change (1.0 to 0.85) when the user has reduced motion enabled. This is a new requirement that improves the existing `.avatar-thinking` class for all consumers (message avatars too).

## Dependencies

**Depends on:** Nothing. This is a standalone baseline fix.

**Depended on by:**
- Epic 96 (Cyclist Tandem UI) -- builds on the throbber vocabulary established here. Story 96-3 (observation pulse on primary portrait) assumes the primary portrait already has a working throbber.
- Epic 96, Story 96-4 (accessibility/responsive) -- the `prefers-reduced-motion` pattern established in 94-2 is extended for tandem-specific animations.
