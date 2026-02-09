# Story Context: 96-4 - Tandem UI Accessibility and Responsive Behavior

## Summary

Add accessibility and responsive behavior to all tandem UI elements. `prefers-reduced-motion` fallbacks for all three animation tiers (opacity/border instead of motion). Screen reader support with alt text and `aria-live` announcements. Container queries to hide backseat portrait below 180px panel width. Non-interactive MVP (no tab stop). WCAG AA compliance.

## Planning References

- **PRD:** NFR6 (CSS-only animation fallbacks), NFR13 (dockview layout). See `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** "Responsive Design & Accessibility" section in `sprint/planning/tandem-mode-ux-design.md`
- **Epics Breakdown:** Story 3.4 in `sprint/planning/tandem-mode-epics.md` under "Epic 3"

## Current State

### Existing accessibility in PersonaHeader

**File:** `pennyfarthing/packages/cyclist/src/public/components/PersonaHeader.tsx` (196 lines)

- Lines 96-101: ARIA attributes on root div (`aria-label`, `role="button"`, `tabIndex`)
- Lines 93-94: Keyboard handler (Enter key opens popup)
- Line 100: `aria-live="polite"` for state changes
- Compact mode (line 94, 174-183): toggle button with ▼/▲ icons
- No tandem-specific accessibility

### Existing animations (no reduced-motion support)

**File:** `pennyfarthing/packages/cyclist/src/public/styles/tailwind.css` (4212 lines)

- Lines 756-769: `avatar-throb` and `.avatar-thinking` — no `prefers-reduced-motion` override
- Epic 94-2 adds a `prefers-reduced-motion` rule for `.avatar-thinking` (opacity fallback)
- Tier 2 (`tandem-throb`) and Tier 3 (`observation-pulse`) from 96-2/96-3 need their own fallbacks

### No container queries exist

- PersonaHeader does not use CSS container queries
- MessagePanel is the parent container — would need `container-type: inline-size`
- Dockview panels can be resized to very narrow widths

## Target State

After implementation:

1. All three animation tiers degrade gracefully with `prefers-reduced-motion: reduce`
2. Screen reader announces backseat join/leave events via `aria-live="polite"`
3. Alt text on backseat portrait: `"{character} ({role}) - observing"`
4. Container queries hide backseat portrait below 180px panel width
5. Backseat portrait is non-interactive (no tab stop, no focus ring)
6. WCAG AA compliance for all new elements

## Key Files

### Files to Modify

| File | Path | Purpose |
|------|------|---------|
| `tailwind.css` | `pennyfarthing/packages/cyclist/src/public/styles/tailwind.css` | Add `prefers-reduced-motion` fallbacks, container query rules |
| `PersonaHeader.tsx` | `pennyfarthing/packages/cyclist/src/public/components/PersonaHeader.tsx` | Add `aria-live` region for tandem state changes |
| `TandemPortrait.tsx` | (from 96-1) | Add alt text, ensure non-interactive (no tabIndex) |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| `PersonaHeader.tsx` | Lines 96-101 | Existing ARIA pattern to extend |
| `Message.tsx` | Lines 32-54 | AssistantAvatar ARIA pattern |

## Technical Approach

### Reduced Motion Fallbacks

Add to `tailwind.css` (consolidated `prefers-reduced-motion` block):

```css
@media (prefers-reduced-motion: reduce) {
  /* Tier 1: Primary thinking (also covers message avatars) */
  .avatar-thinking {
    animation: none;
    opacity: 0.85;
  }

  /* Tier 2: Backseat thinking */
  .avatar-tandem-thinking {
    animation: none;
    opacity: 0.85;
  }

  /* Tier 3: Observation pulse */
  .avatar-observation-pulse {
    animation: none;
    border: 2px solid var(--accent-color, #007acc);
  }

  /* Fade transitions */
  .persona-tandem-portrait {
    transition: none;
  }
}
```

Each tier degrades differently:
- **Thinking (Tiers 1 & 2):** Static opacity change (1.0→0.85). Communicates "active" without motion.
- **Observation pulse (Tier 3):** Static border color change. Communicates "event happened" without glow animation.
- **Fade-in/out:** Instant show/hide instead of 300ms transition.

### Screen Reader Support

In PersonaHeader, add an `aria-live` region for tandem state:

```tsx
{/* Tandem status announcement for screen readers */}
<span className="sr-only" aria-live="polite">
  {tandemAgent
    ? `Backseat agent joined: ${tandemAgent.character}, role: ${tandemAgent.role}`
    : ''}
</span>
```

On TandemPortrait image:
```tsx
<AvatarImage
  src={`/portraits/${theme}/medium/${slug}.png`}
  alt={`${character} (${role}) - observing`}
/>
```

### Container Queries

Require `container-type` on the parent. Add to MessagePanel or PersonaHeader wrapper:

```css
.persona-header {
  container-type: inline-size;
}

@container (max-width: 180px) {
  .persona-tandem-portrait {
    display: none;
  }
}

@container (max-width: 280px) {
  .persona-info .persona-catchphrase {
    display: none;
  }
}
```

This hides the backseat portrait when the panel is too narrow, and also hides the catchphrase at moderate widths.

### Non-Interactive MVP

TandemPortrait must NOT be interactive:
- No `tabIndex` attribute
- No `role="button"` or click handler
- No focus ring CSS
- Users cannot click or tab to the backseat portrait
- Future story may add interactivity (popup, agent switch)

### WCAG AA Checklist

| Criterion | Requirement | Implementation |
|-----------|-------------|----------------|
| 1.1.1 Non-text Content | Alt text for images | `alt="{character} ({role}) - observing"` |
| 1.4.3 Contrast | 4.5:1 text contrast | Role badge text on colored background — verify |
| 1.4.11 Non-text Contrast | 3:1 for UI components | Portrait border/glow vs background |
| 2.1.1 Keyboard | All interactive elements keyboard accessible | Backseat is non-interactive — N/A for MVP |
| 4.1.2 Name, Role, Value | ARIA labels for dynamic content | `aria-live="polite"` for state changes |

### Testing Plan

1. **Reduced motion:** Enable `prefers-reduced-motion` in browser dev tools. Verify all animations degrade to static alternatives.
2. **Screen reader (VoiceOver macOS):** Verify alt text read on focus, aria-live announcements on tandem join/leave.
3. **Color filters:** Enable grayscale, protanopia, deuteranopia in dev tools. Verify role badge is identifiable by shape/position, not just color.
4. **Panel resize:** Test at 150px, 200px, 280px, 400px, 600px widths. Verify backseat hides below 180px, info truncates gracefully.

## Acceptance Criteria

- `prefers-reduced-motion: reduce` degrades all animations to opacity/border changes
- Screen reader announces "Backseat agent joined: {character}" when tandem starts
- Screen reader announces state change when tandem ends
- Alt text on backseat portrait: `"{character} ({role}) - observing"`
- Backseat portrait hidden below 180px panel width (container query)
- Backseat portrait is non-interactive — no tab stop, no focus ring
- Fade-in/out transitions become instant under reduced motion
- Role badge identifiable without relying solely on color
- WCAG AA compliance for all new UI elements

## Dependencies

### Depends On

- **96-1** (TandemPortrait component) — the component to add accessibility to
- **96-2** (Backseat thinking animation) — animation to add reduced-motion fallback for
- **96-3** (Observation pulse) — animation to add reduced-motion fallback for

### Depended On By

- Nothing. This is the accessibility polish story for the tandem UI.

## Risks / Open Questions

1. **Container query support:** CSS container queries are supported in all modern browsers (Chrome 105+, Firefox 110+, Safari 16+). Electron (Cyclist's runtime) uses Chromium — version must be 105+. Verify Cyclist's Electron version.

2. **aria-live timing:** If tandem join/leave happens rapidly (e.g., phase transition), multiple announcements could queue. VoiceOver handles this gracefully (reads in order), but verify no flooding occurs.

3. **Color contrast on role badge:** The role badge uses agent-specific colors (e.g., orange for Architect). At 48px portrait size with a 16px badge, the badge text must have 4.5:1 contrast against the badge background. Verify each agent color meets this — some lighter colors (yellow, pink) may need darker text.
