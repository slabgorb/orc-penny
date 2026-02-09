# Epic 96: Cyclist Tandem UI

## Overview

Users watching agents in Cyclist see the backseat portrait below the primary, with distinct animation states (idle, thinking, observation pulse). TandemPortrait component wraps shadcn Avatar with tandem-specific styling. Three CSS animation tiers with no ambiguity. Container queries for dockview panel resize. WCAG AA accessibility compliance.

**Total points:** 9
**Priority:** P1
**Marker:** feature
**Repo:** pennyfarthing
**Stories:** 4

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **PRD** (`sprint/planning/tandem-mode-prd.md`) | FR18-FR21 (backseat portrait, throbber, portrait resolution), NFR6 (CSS-only animation), NFR13 (dockview layout) |
| **UX Design Spec** (`sprint/planning/tandem-mode-ux-design.md`) | Entire document is the primary reference -- "Design Direction Decision" (Direction A: Inline Below), "Animation Hierarchy" table, "Component Strategy" (TandemPortrait spec), "Responsive Design & Accessibility", "Portrait Presence Pattern" |
| **Epic Breakdown** (`sprint/planning/tandem-mode-epics.md`) | Epic 3 full section (Stories 3.1-3.4), FR Coverage Map (FR18-FR21), NFR Coverage (NFR6, NFR13) |

## Background

### The Design Decision

Four layout directions were evaluated for backseat portrait placement (see UX spec "Design Directions Explored"). **Direction A: Inline Below** was chosen -- backseat portrait appears directly below the primary portrait, left-aligned, as a subordinate element in the existing vertical flow.

Rationale: clear visual hierarchy (below = subordinate), low layout impact (+56px height, acceptable), follows existing PersonaHeader vertical flow, graceful degradation (height shrinks smoothly when tandem ends).

### Three Animation Tiers

The UX spec defines three distinct animation tiers with no overlap:

| Tier | Animation | Duration | Scale | Glow | Meaning |
|------|-----------|----------|-------|------|---------|
| 1: Primary thinking | `avatar-throb` | 1.2s | 1.08 | 8px/2px | "I'm working" |
| 2: Backseat thinking | `tandem-throb` | 1.8s | 1.04 | 6px/1px | "I'm watching" |
| 3: Observation pulse | `observation-pulse` | 600ms | none | 12px/4px → 0 | "I have something" |

Tiers 1 and 2 loop. Tier 3 fires once (one-shot). No two looping animations on the same portrait simultaneously. Tier 1 is established by Epic 94 (baseline fix); this epic adds Tiers 2 and 3.

## Technical Architecture

### Component Map

```
usePersona hook (hooks/usePersona.ts)
  +-- persona: PersonaData
  +-- isStreaming: boolean (from Epic 94)
  +-- tandemAgent: TandemAgentData | null  <-- NEW (from Epic 95 state)
  |
  v
PersonaHeader (components/PersonaHeader.tsx)
  +-- .persona-portrait (100px, primary)
  |    +-- .avatar-thinking (conditional, Epic 94)
  |    +-- .avatar-observation-pulse (conditional, one-shot)  <-- NEW
  |
  +-- TandemPortrait (conditional child)  <-- NEW COMPONENT
       +-- shadcn Avatar (48px, opacity 0.55)
       +-- AvatarImage (portrait from /portraits/{theme}/medium/{slug}.png)
       +-- AvatarFallback (emoji)
       +-- role Badge (16px, bottom-right)
       +-- .avatar-tandem-thinking (conditional)  <-- NEW CLASS
  |
  v
tailwind.css (styles/tailwind.css)
  +-- @keyframes avatar-throb (EXISTING, line ~756)
  +-- .avatar-thinking (EXISTING, line ~767)
  +-- @keyframes tandem-throb  <-- NEW
  +-- .avatar-tandem-thinking  <-- NEW
  +-- @keyframes observation-pulse  <-- NEW
  +-- .avatar-observation-pulse  <-- NEW
  +-- .persona-tandem-portrait  <-- NEW (container, opacity, sizing)
  +-- @container queries  <-- NEW (hide backseat below 180px)
```

### Key Files (Existing, to be Modified)

| File | Path | Lines | Change |
|------|------|-------|--------|
| PersonaHeader | `packages/cyclist/src/public/components/PersonaHeader.tsx` | 195 | Add conditional `TandemPortrait` child below primary portrait. Add observation pulse class to primary portrait when observation arrives. Consume tandem agent state from `usePersona()` |
| usePersona hook | `packages/cyclist/src/public/hooks/usePersona.ts` | 89 | Add `tandemAgent` to return type. The tandem state comes from Epic 95's backseat lifecycle -- either via WebSocket persona channel or a new tandem state endpoint |
| tailwind.css | `packages/cyclist/src/public/styles/tailwind.css` | ~4200+ | Add three new CSS blocks: `@keyframes tandem-throb`, `@keyframes observation-pulse`, `.persona-tandem-portrait` container class, `@container` queries for responsive behavior |
| hooks index | `packages/cyclist/src/public/hooks/index.ts` | 50 | Export updated `usePersona` types if interface changes |

### Key Files (New)

| File | Path | Purpose |
|------|------|---------|
| TandemPortrait | `packages/cyclist/src/public/components/TandemPortrait.tsx` | New React component -- backseat portrait with animation states |

### Key Files (Reference Only)

| File | Path | Purpose |
|------|------|---------|
| Message.tsx | `packages/cyclist/src/public/components/Message.tsx` | Reference for `isStreaming` → `.avatar-thinking` pattern (line 40). `AssistantAvatar` component shows portrait + fallback pattern (lines 32-54) |
| MessagePanel.tsx | `packages/cyclist/src/public/components/panels/MessagePanel.tsx` | Layout context -- PersonaHeader sits at top, flex column, `overflow: hidden` |
| DockviewWorkspace.tsx | `packages/cyclist/src/public/components/DockviewWorkspace.tsx` | Center region (sacred, non-closable) contains MessagePanel. Three-region layout with sidebars |
| AgentPopup.tsx | `packages/cyclist/src/public/components/AgentPopup.tsx` | Portrait size convention: small=32px (messages), medium=100px (header), large=200px (popup). Path: `/portraits/{theme}/{size}/{slug}.png` |
| portrait-resolver.ts | `packages/shared/src/portrait-resolver.ts` (242 lines) | Portrait resolution pipeline -- theme directory lookup, agent-to-filename mappings, fallback chain |
| useColorScheme.ts | `packages/cyclist/src/public/hooks/useColorScheme.ts` | `useColorScheme()` → `'light' | 'dark'`. PersonaHeader uses it for logo variant (line 63) |
| message.ts | `packages/cyclist/src/public/types/message.ts` | `MessageData` interface with `isStreaming`, `agentSlug`, `agentTheme`, `agentCharacter` fields |

### Existing PersonaHeader Layout

Current structure (`PersonaHeader.tsx`):

```
.persona-header (display: flex, align-items: center, gap: 12px, flex-shrink: 0)
  .persona-portrait-group (position: relative, flex-shrink: 0)
    .persona-portrait (100x100px, border-radius: 50%, overflow: hidden)
      img (src=/portraits/{theme}/medium/{slug}.png)
      span.avatar-emoji (🤖 fallback)
  .persona-info
    .persona-name-row (flex, gap: 8px)
      Badge (role badge, color-coded)
      span (character name)
      span (theme name)
    .persona-catchphrase (from quote field)
  .persona-branding (cyclist logo, 80px, 50% opacity)
  button.persona-collapse-toggle
```

The portrait group uses a flex column. Adding the backseat below the primary requires:
1. Making `.persona-portrait-group` a flex column with `gap: 8px`
2. Appending `TandemPortrait` as a conditional child
3. MessagePanel absorbs the ~56px height increase internally (flex layout, no impact on dockview)

### Existing CSS Animation

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

Uses `--accent-color` which is theme-aware. Works at any portrait size.

### New CSS Animations

```css
/* Tier 2: Backseat thinking (slower, subtler) */
@keyframes tandem-throb {
  0%, 100% {
    transform: scale(1);
    box-shadow: 0 0 0 0 var(--accent-color, #007acc);
  }
  50% {
    transform: scale(1.04);
    box-shadow: 0 0 6px 1px var(--accent-color, #007acc);
  }
}

.avatar-tandem-thinking {
  animation: tandem-throb 1.8s ease-in-out infinite;
}

/* Tier 3: Observation pulse (one-shot on primary) */
@keyframes observation-pulse {
  0% {
    box-shadow: 0 0 12px 4px var(--accent-color, #007acc);
  }
  100% {
    box-shadow: 0 0 0 0 var(--accent-color, #007acc);
  }
}

.avatar-observation-pulse {
  animation: observation-pulse 600ms ease-out forwards;
}

/* Reduced motion fallbacks */
@media (prefers-reduced-motion: reduce) {
  .avatar-tandem-thinking {
    animation: none;
    opacity: 0.85;
  }
  .avatar-observation-pulse {
    animation: none;
    border-color: var(--accent-color, #007acc);
  }
}

/* Backseat portrait container */
.persona-tandem-portrait {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  opacity: 0.55;
  transition: opacity 300ms ease-in-out;
  position: relative;
}

/* Container queries for panel resize */
@container (max-width: 180px) {
  .persona-tandem-portrait {
    display: none;
  }
}
```

### Portrait Resolution

Backseat portrait uses the same pipeline as primary (`portrait-resolver.ts`):
- Path: `/portraits/{theme}/medium/{slug}.png`
- Agent-to-slug mapping already exists for all agents (sm, tea, dev, reviewer, architect, etc.)
- Fallback: emoji (🤖) on image load error, same as message avatars
- No new infrastructure needed

### CSS Variables (Existing)

All relevant variables are already defined in `tailwind.css`:
- `--accent-color` (default: #007acc) -- used by all animation glows
- `--bg-secondary` (default: #252526) -- PersonaHeader background
- `--text-primary` (default: #d4d4d4) -- role badge text
- `--text-secondary` (default: #8b8b8b) -- subordinate text
- `--border-color` (default: #3c3c3c) -- PersonaHeader border

### shadcn Avatar Usage Pattern

From existing code (Message.tsx AssistantAvatar):

```tsx
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar';

// Backseat portrait would follow same pattern:
<Avatar className="persona-tandem-portrait">
  <AvatarImage
    src={`/portraits/${theme}/medium/${slug}.png`}
    alt={`${character} (${role}) - observing`}
    onError={() => setTandemPortraitError(true)}
  />
  <AvatarFallback>🤖</AvatarFallback>
</Avatar>
```

### Compact Mode Consideration

PersonaHeader has compact mode (`.persona-header.compact`) that shrinks primary portrait to 40px. In compact mode, the backseat portrait should be hidden entirely -- there's not enough space for a meaningful subordinate portrait at that scale.

## Stories

| Story | Title | Points | Priority | Dependencies |
|-------|-------|--------|----------|-------------|
| 96-1 | TandemPortrait component | 3 | P0 | Epic 95 (tandem state), Epic 94 (usePersona isStreaming) |
| 96-2 | Backseat thinking animation | 2 | P0 | 96-1 |
| 96-3 | Observation pulse on primary portrait | 2 | P0 | 96-1, Epic 95-7 (bell mode injection) |
| 96-4 | Tandem UI accessibility and responsive behavior | 2 | P1 | 96-1, 96-2, 96-3 |

## Story Notes

### 96-1: TandemPortrait component

**What to do:** Create `TandemPortrait.tsx` React component. Render below primary portrait in PersonaHeader when tandem phase is active. 48px circular, opacity 0.55, 8px gap from primary, role badge at bottom-right. Fade-in (0 → 0.55, 300ms ease-in) on mount, fade-out (0.55 → 0, 300ms ease-out) on unmount. Emoji fallback on portrait error.

**Key files:**
- **Create:** `packages/cyclist/src/public/components/TandemPortrait.tsx`
- **Modify:** `PersonaHeader.tsx` -- add conditional render of `TandemPortrait` inside `.persona-portrait-group`
- **Modify:** `tailwind.css` -- add `.persona-tandem-portrait` container class
- **Modify:** `usePersona.ts` -- extend return type with `tandemAgent` data (or create a separate `useTandem` hook)

**Props:**
```typescript
interface TandemPortraitProps {
  character: string;
  role: string;
  slug: string;
  theme: string;
  isActive: boolean;
  isThinking: boolean;
}
```

**Layout:** Make `.persona-portrait-group` a flex column:
```css
.persona-portrait-group {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 8px;
}
```

**Key constraint:** No layout shifts in adjacent dockview panels (NFR13). MessagePanel absorbs height change internally.

### 96-2: Backseat thinking animation

**What to do:** Add `@keyframes tandem-throb` and `.avatar-tandem-thinking` class to `tailwind.css`. Apply class to TandemPortrait when `isThinking` is true.

**CSS placement:** After existing `avatar-throb` keyframes (line ~769 in tailwind.css).

**Visual distinction from primary:** Slower (1.8s vs 1.2s), smaller scale (1.04 vs 1.08), less glow (6px/1px vs 8px/2px). Both use `--accent-color` for theme consistency but are visually distinguishable at a glance.

**Key constraint:** CSS-only, no JS polling or layout recalculation (NFR6).

### 96-3: Observation pulse on primary portrait

**What to do:** Add `@keyframes observation-pulse` and `.avatar-observation-pulse` class. Apply one-shot pulse to primary portrait when backseat observation is injected via bell mode.

**Trigger mechanism:** When `usePersona` (or a new hook) detects a new tandem observation has been injected, apply `.avatar-observation-pulse` class to the primary portrait. Auto-remove class after animation completes (600ms) via `onAnimationEnd` handler or `setTimeout`.

**Key constraint:** One-shot, not looping. If multiple observations arrive in quick succession, each pulse fires independently (previous pulse completes or is replaced).

**Visual distinction from thinking throb:** Different gesture entirely -- no scale, just a burst of accent glow that fades to zero. Thinking is continuous oscillation; pulse is a single flash.

### 96-4: Tandem UI accessibility and responsive behavior

**What to do:** Add `prefers-reduced-motion` fallbacks for all three animation tiers. Add screen reader support (`alt` text, `aria-live` region). Add container queries for panel resize. Verify WCAG AA compliance.

**Accessibility:**
- Alt text: `"{character} ({role}) - observing"` on backseat `AvatarImage`
- `aria-live="polite"` region in PersonaHeader for state changes: "Backseat agent joined: {character}" / "Backseat agent left"
- Backseat is non-interactive in MVP -- no tab stop, no focus ring
- Primary AgentPopup keyboard support unchanged

**Reduced motion:**
- All animations → static opacity or border changes
- Thinking: opacity toggle (1.0 → 0.85)
- Observation pulse: border-color change
- Fade-in/out: instant show/hide

**Container queries:**
- `@container (max-width: 180px)` → hide TandemPortrait entirely
- `@container (max-width: 280px)` → both portraits visible, metadata may truncate
- Use CSS container queries on MessagePanel wrapper, not viewport media queries

**Testing:**
- Snapshot tests: PersonaHeader in four states (no tandem, idle, thinking, pulse)
- VoiceOver (macOS): verify alt text and aria-live announcements
- Color filters (grayscale, protanopia): verify role badge identifiable
- Panel resize: test at 150px, 200px, 280px, 400px, 600px widths

## Constraints

- **CSS-only animations** (NFR6): All throbbers and pulses use CSS `@keyframes`, not JS
- **No layout shifts** (NFR13): Backseat portrait integrates without affecting existing panel resizing
- **Same portrait pipeline**: Use identical `/portraits/{theme}/medium/{slug}.png` resolution
- **shadcn components**: Use `Avatar`/`AvatarImage`/`AvatarFallback` for backseat portrait
- **Existing design tokens**: Use `--accent-color`, `--bg-secondary`, `--text-primary` -- no new colors
- **WCAG AA**: All new UI elements meet accessibility standards
- **Backward-compatible**: PersonaHeader looks identical when no tandem phase is active

## Dependencies

**Depends on:**
- Epic 94 (Primary Portrait Thinking Indicator) -- establishes the Tier 1 throbber vocabulary that tandem builds on. Story 96-3 (observation pulse on primary) assumes primary portrait already has a working throbber from 94-2.
- Epic 95 (Workflow Configuration & Observation Protocol) -- provides the tandem state that drives the UI. Story 96-1 needs to know when a tandem phase is active and which agent is the backseat.

**Depended on by:**
- Nothing directly. This is the visual layer for Cyclist users.
