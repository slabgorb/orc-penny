# Story Context: 96-1 - TandemPortrait Component

## Summary

Create a new React component `TandemPortrait` that renders the backseat agent's portrait below the primary portrait in PersonaHeader. 48px circular, opacity 0.55, 8px gap from primary, role badge at bottom-right. Fade-in/out on mount/unmount (300ms). Emoji fallback on portrait error. Uses shadcn Avatar/AvatarImage/AvatarFallback. No layout shifts in adjacent dockview panels.

## Planning References

- **PRD:** FR18-FR19 (backseat portrait, portrait resolution), NFR13 (dockview layout). See `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** "Design Direction Decision" (Direction A: Inline Below), "Component Strategy" (TandemPortrait spec), "Portrait Presence Pattern" in `sprint/planning/tandem-mode-ux-design.md`
- **Epics Breakdown:** Story 3.1 in `sprint/planning/tandem-mode-epics.md` under "Epic 3: Cyclist Tandem UI"

## Current State

### PersonaHeader component (existing)

**File:** `pennyfarthing/packages/cyclist/src/public/components/PersonaHeader.tsx` (196 lines)

Current layout structure:
```
.persona-header (flex, align-items: center, gap: 12px)
  .persona-portrait-group (position: relative, flex-shrink: 0)  [line 103]
    .persona-portrait (100x100px, border-radius: 50%)  [lines 104-115]
      img (src=/portraits/{theme}/medium/{slug}.png)  [lines 105-111]
      span.avatar-emoji (🤖 fallback)  [lines 112-114]
  .persona-info  [lines 117-168]
  .persona-branding  [lines 169-173]
  button.persona-collapse-toggle  [lines 174-183]
```

Key details:
- Lines 62-72: Persona consumption via `usePersona()` — gets `persona` object
- Lines 105-111: Portrait image with fallback on error (line 64: `portraitError` state)
- Lines 93-102: Root div with accessibility attributes (ARIA labels, keyboard)
- Line 94: Compact mode class `.persona-header.compact`
- No tandem awareness — no conditional child below portrait

### Message.tsx AssistantAvatar (reference pattern)

**File:** `pennyfarthing/packages/cyclist/src/public/components/Message.tsx` (226 lines)

- Lines 32-54: `AssistantAvatar` component — pattern for portrait + fallback
- Line 40: `.avatar-thinking` conditional class application
- Line 45: Portrait path `/portraits/${theme}/small/${slug}.png`
- Lines 42-50: shadcn-style portrait rendering (img + fallback emoji)

### AgentPopup portrait sizes (reference)

**File:** `pennyfarthing/packages/cyclist/src/public/components/AgentPopup.tsx` (310 lines)

- Line 248: Popup uses `large` size: `/portraits/${theme}/large/${slug}.png`
- Convention: small=32px (messages), medium=100px (header), large=200px (popup)

### Portrait resolution (reference)

**File:** `pennyfarthing/packages/shared/src/portrait-resolver.ts` (242 lines)

- Lines 90-102: Size directory search order: `large → medium → small → original`
- Lines 110-123: Agent-to-slug mappings (architect→oberon/mimir/hannibal, etc.)
- Lines 210-227: `resolvePortraitPath()` — resolution pipeline
- Backseat portrait uses same pipeline — no new infrastructure needed

### usePersona hook (existing)

**File:** `pennyfarthing/packages/cyclist/src/public/hooks/usePersona.ts` (89 lines)

- Currently returns `{ persona, isLoading, error, isStreaming }` (after Epic 94)
- No tandem agent data — needs extension to provide backseat agent info

## Target State

After implementation:

1. New `TandemPortrait.tsx` component renders backseat portrait
2. PersonaHeader conditionally renders TandemPortrait below primary when tandem phase active
3. `.persona-portrait-group` becomes a flex column with 8px gap
4. Backseat portrait: 48px circular, opacity 0.55, role badge bottom-right
5. Fade-in (0→0.55 opacity, 300ms ease-in) on mount, fade-out on unmount
6. Emoji fallback on portrait load error
7. Hidden in compact mode
8. No layout shifts in adjacent dockview panels

## Key Files

### Files to Create

| File | Path | Purpose |
|------|------|---------|
| `TandemPortrait.tsx` | `pennyfarthing/packages/cyclist/src/public/components/TandemPortrait.tsx` | New component — backseat portrait with fade animation and role badge |

### Files to Modify

| File | Path | Purpose |
|------|------|---------|
| `PersonaHeader.tsx` | `pennyfarthing/packages/cyclist/src/public/components/PersonaHeader.tsx` | Add conditional TandemPortrait child in `.persona-portrait-group`; adjust layout to flex column |
| `tailwind.css` | `pennyfarthing/packages/cyclist/src/public/styles/tailwind.css` | Add `.persona-tandem-portrait` container class (48px, opacity 0.55, border-radius 50%) |
| `usePersona.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/usePersona.ts` | Extend return type with `tandemAgent` data (or create separate `useTandem` hook) |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| `Message.tsx` | `pennyfarthing/packages/cyclist/src/public/components/Message.tsx` | AssistantAvatar pattern — portrait + fallback (lines 32-54) |
| `AgentPopup.tsx` | `pennyfarthing/packages/cyclist/src/public/components/AgentPopup.tsx` | Portrait size convention (line 248) |
| `portrait-resolver.ts` | `pennyfarthing/packages/shared/src/portrait-resolver.ts` | Portrait resolution pipeline (lines 210-227) |

## Technical Approach

### TandemPortrait Component

```typescript
interface TandemPortraitProps {
  character: string;
  role: string;
  slug: string;
  theme: string;
  isActive: boolean;    // controls mount/unmount
  isThinking: boolean;  // drives animation (story 96-2)
}
```

Uses shadcn Avatar pattern (matching Message.tsx):

```tsx
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar';

function TandemPortrait({ character, role, slug, theme, isActive, isThinking }: TandemPortraitProps) {
  const [portraitError, setPortraitError] = useState(false);

  if (!isActive) return null;

  return (
    <div className={`persona-tandem-portrait${isThinking ? ' avatar-tandem-thinking' : ''}`}>
      <Avatar>
        <AvatarImage
          src={`/portraits/${theme}/medium/${slug}.png`}
          alt={`${character} (${role}) - observing`}
          onError={() => setPortraitError(true)}
        />
        <AvatarFallback>🤖</AvatarFallback>
      </Avatar>
      <span className="tandem-role-badge">{AGENT_ABBREV[role] || role.toUpperCase()}</span>
    </div>
  );
}
```

### PersonaHeader Layout Change

Make `.persona-portrait-group` (line 103) a flex column:

```css
.persona-portrait-group {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 8px;
}
```

Add conditional TandemPortrait after the primary portrait:

```tsx
<div className="persona-portrait-group">
  <div className="persona-portrait">
    {/* existing primary portrait */}
  </div>
  {tandemAgent && (
    <TandemPortrait
      character={tandemAgent.character}
      role={tandemAgent.role}
      slug={tandemAgent.slug}
      theme={tandemAgent.theme}
      isActive={!!tandemAgent}
      isThinking={tandemAgent.isThinking}
    />
  )}
</div>
```

### CSS Container Class

```css
.persona-tandem-portrait {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  opacity: 0.55;
  transition: opacity 300ms ease-in-out;
  position: relative;
}
```

### Fade Animation

Mount fade-in via CSS transition on opacity (0→0.55). For unmount fade-out, either:
- Use `react-transition-group` or `framer-motion` if already in deps
- Or a simple state-based approach: set opacity to 0, then remove after 300ms timeout

### Tandem State Source

The component needs to know when a tandem phase is active and who the backseat is. Options:
- Extend `usePersona` to return `tandemAgent` from WebSocket persona channel
- Create a new `useTandem` hook that reads tandem state
- Read tandem observation file existence (simpler but polling-based)

Decision deferred to implementation — follow the pattern established in the codebase.

### Compact Mode

In compact mode (`.persona-header.compact`), hide TandemPortrait entirely:

```css
.persona-header.compact .persona-tandem-portrait {
  display: none;
}
```

## Acceptance Criteria

- TandemPortrait renders below primary portrait when tandem phase is active
- Portrait is 48px circular with opacity 0.55
- 8px gap between primary and backseat portraits
- Role badge at bottom-right corner (16px, agent-colored)
- Fade-in (300ms ease-in) on mount
- Fade-out (300ms ease-out) on unmount
- Emoji fallback (🤖) on portrait load error
- Hidden in compact mode
- No layout shifts in adjacent dockview panels (MessagePanel absorbs height internally)
- Uses shadcn Avatar/AvatarImage/AvatarFallback components
- Portrait resolved via same pipeline as primary (same theme, medium size)

## Dependencies

### Depends On

- **Epic 94** (usePersona isStreaming) — usePersona hook must be extended (foundation)
- **Epic 95** (tandem state) — needs to know when tandem phase is active and which agent is backseat

### Depended On By

- **96-2** (Backseat thinking animation) — applies `.avatar-tandem-thinking` to this component
- **96-3** (Observation pulse) — fires pulse on primary portrait when observation arrives
- **96-4** (Accessibility/responsive) — adds ARIA, reduced motion, container queries to this component

## Risks / Open Questions

1. **Tandem state delivery:** How does the UI learn that a tandem phase is active? The backseat lifecycle (Epic 95-2) creates an observation file, but the UI needs a reactive signal. Options: WebSocket event from WheelHub, file polling, or extending the persona broadcast. This is an integration question between Epics 95 and 96.

2. **Height impact:** Adding 48px + 8px gap = 56px to PersonaHeader. The MessagePanel uses flex layout with `overflow: hidden` on the message list. The header grows, the message list shrinks by 56px. Verify this doesn't cause visible scroll jumps or re-render cascades on mount/unmount.

3. **Portrait availability:** Not all themes may have portraits for all agents. The backseat (often Architect) should have portraits in all shipped themes. If missing, the emoji fallback handles it gracefully.

4. **shadcn Avatar import:** Verify shadcn Avatar is already installed in the Cyclist package. Message.tsx uses a similar pattern but may not use the exact shadcn component. Match whatever pattern Message.tsx uses.
