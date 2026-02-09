# Story Context: 94-2 - Apply Thinking Throbber to PersonaHeader Portrait

## Summary

Apply the existing `.avatar-thinking` CSS class to the PersonaHeader primary portrait when `isStreaming` is `true`. This completes the baseline thinking indicator by connecting the streaming state (from story 94-1) to the visual throbber animation already used on message avatars. Also adds `prefers-reduced-motion` fallback for the `.avatar-thinking` class, improving accessibility for all consumers.

## Planning References

- **PRD:** Implements FR20 (primary portrait throbber), NFR6 (CSS-only animation). See `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** See "Animation Hierarchy" table (Tier 1: primary thinking), "Desired Emotional Response" (trust through consistency) in `sprint/planning/tandem-mode-ux-design.md`
- **Epics Breakdown:** Story 1.2 in `sprint/planning/tandem-mode-epics.md` under "Epic 1: Primary Portrait Thinking Indicator"

## Current State

### PersonaHeader component (existing)

**File:** `pennyfarthing/packages/cyclist/src/public/components/PersonaHeader.tsx` (196 lines)

The component currently:
- Consumes `usePersona()` to get `persona` object (line 62)
- Renders portrait image at `/portraits/${theme}/medium/${slug}.png` (lines 105-114)
- Has compact mode toggle reducing portrait to 40px (lines 66, 174-183)
- Uses dynamic CSS class `.persona-header` with optional `.clickable` and `.compact` modifiers (line 94)
- Has ARIA labels and keyboard navigation for accessibility (lines 96-101)
- Does NOT consume any streaming state
- Does NOT apply `.avatar-thinking` class

### Avatar-throb animation (existing)

**File:** `pennyfarthing/packages/cyclist/src/public/styles/tailwind.css` (4212 lines)

- **Lines 756-765:** `@keyframes avatar-throb` — scale 1→1.08→1 with accent box-shadow glow
- **Lines 767-769:** `.avatar-thinking` — applies `avatar-throb 1.2s ease-in-out infinite`
- Uses CSS custom property `var(--accent-color, #007acc)` — theme-aware
- **No `prefers-reduced-motion` rule exists** — animation runs unconditionally

### How message avatars use it (reference)

**File:** `pennyfarthing/packages/cyclist/src/public/components/Message.tsx`
- Line 40: `isStreaming` prop on message controls `.avatar-thinking` class on the 32px message avatar
- Line 175-181: Conditional class application pattern

## Target State

After implementation:

1. PersonaHeader destructures `isStreaming` from `usePersona()` (depends on 94-1)
2. The `.persona-portrait` div conditionally gets `.avatar-thinking` class when `isStreaming` is `true`
3. The 100px header portrait throbs with the same animation users see on 32px message avatars
4. Compact mode (40px portrait) works correctly — `scale(1.08)` is proportional
5. `prefers-reduced-motion` media query added to `.avatar-thinking` — degrades to static opacity change (0.85) for all consumers (message avatars and header portrait)

## Key Files

### Files to Modify

| File | Path | Purpose |
|------|------|---------|
| `PersonaHeader.tsx` | `pennyfarthing/packages/cyclist/src/public/components/PersonaHeader.tsx` | Consume `isStreaming` from `usePersona()`, conditionally apply `.avatar-thinking` class |
| `tailwind.css` | `pennyfarthing/packages/cyclist/src/public/styles/tailwind.css` | Add `prefers-reduced-motion` fallback after `.avatar-thinking` rule (line 769) |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| `Message.tsx` | `pennyfarthing/packages/cyclist/src/public/components/Message.tsx` | Pattern for conditional `.avatar-thinking` class application (line 40, 175-181) |
| `usePersona.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/usePersona.ts` | Verify `isStreaming` is available in hook return (from 94-1) |

## Technical Approach

### PersonaHeader Changes

**Current (line 62):**
```tsx
const { persona } = usePersona();
```

**After:**
```tsx
const { persona, isStreaming } = usePersona();
```

**Portrait rendering (lines 105-114).** Apply `.avatar-thinking` conditionally to the `.persona-portrait` wrapper div:

```tsx
<div className={`persona-portrait${isStreaming ? ' avatar-thinking' : ''}`} data-testid="persona-portrait">
```

### CSS Accessibility Addition

Add after the existing `.avatar-thinking` rule (after line 769 in `tailwind.css`):

```css
@media (prefers-reduced-motion: reduce) {
  .avatar-thinking {
    animation: none;
    opacity: 0.85;
  }
}
```

This applies to all `.avatar-thinking` consumers — both message avatars and the header portrait — improving baseline accessibility.

### Implementation Steps

1. Destructure `isStreaming` from `usePersona()` in PersonaHeader
2. Add conditional `.avatar-thinking` class to `.persona-portrait` div
3. Add `prefers-reduced-motion` media query to `tailwind.css`
4. Verify compact mode (40px) renders correctly with animation
5. Verify standard mode (100px) renders correctly with animation

## Acceptance Criteria

- PersonaHeader portrait throbs when agent is actively streaming
- Animation uses existing `avatar-throb` keyframes — same duration (1.2s), scale (1.08), glow effect
- Animation stops when streaming ends (`isStreaming` becomes `false`)
- Compact mode (40px portrait) displays throbber proportionally
- `prefers-reduced-motion` users see static opacity change (1.0 → 0.85) instead of animation
- No new CSS animation vocabulary introduced — reuses existing patterns exactly
- Existing message avatar throbber behavior unchanged

## Dependencies

### Depends On

- **94-1** (Extend usePersona hook with streaming state) — `isStreaming` must be available in the hook return value

### Depended On By

- **96-3** (Observation pulse on primary portrait) — builds on the throbber vocabulary, adds pulse overlay for tandem observations
- **96-4** (Tandem UI accessibility and responsive) — extends the `prefers-reduced-motion` pattern for tandem-specific animations

## Risks / Open Questions

1. **Portrait size scaling:** The `avatar-throb` animation uses `scale(1.08)`. On a 100px portrait this means 108px during pulse — verify this doesn't cause layout shift or overflow on the `.persona-portrait` container. The 32px message avatars scale to ~34.5px with no issues, but 8px growth on 100px is more visible.

2. **Box-shadow on large portraits:** The `box-shadow: 0 0 8px 2px` glow effect designed for 32px avatars may appear too subtle on 100px portraits. If so, this is a follow-up refinement — do NOT change the animation values in this story (NFR6 requires reusing existing CSS exactly).

3. **Theme accent color:** The glow uses `var(--accent-color, #007acc)`. Verify this CSS custom property is set correctly in all themes. If missing, the fallback `#007acc` is fine.
