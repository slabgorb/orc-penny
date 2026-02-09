# Story Context: 96-2 - Backseat Thinking Animation

## Summary

Add new `tandem-throb` CSS keyframe animation and `.avatar-tandem-thinking` class for the backseat portrait. Visually distinct from primary `avatar-throb` — slower (1.8s vs 1.2s), smaller scale (1.04 vs 1.08), subtler glow (6px/1px vs 8px/2px). CSS-only, no JS polling. Applied to TandemPortrait when backseat is processing.

## Planning References

- **PRD:** NFR6 (CSS-only animation). See `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** "Animation Hierarchy" table (Tier 2: backseat thinking) in `sprint/planning/tandem-mode-ux-design.md`
- **Epics Breakdown:** Story 3.2 in `sprint/planning/tandem-mode-epics.md` under "Epic 3"

## Current State

### Existing animation (Tier 1: Primary thinking)

**File:** `pennyfarthing/packages/cyclist/src/public/styles/tailwind.css` (4212 lines)

- **Lines 756-765:** `@keyframes avatar-throb` — scale 1→1.08, box-shadow 0→8px/2px accent glow
- **Lines 767-769:** `.avatar-thinking` — `animation: avatar-throb 1.2s ease-in-out infinite`
- Uses `var(--accent-color, #007acc)` — theme-aware
- Applied to primary portrait (Epic 94) and message avatars

### No Tier 2 animation exists

- No `tandem-throb` keyframe
- No `.avatar-tandem-thinking` class
- No visual distinction between primary and backseat thinking states

### TandemPortrait component (from 96-1)

- `isThinking` prop controls animation class
- Component applies `.avatar-tandem-thinking` when `isThinking` is true
- 48px portrait at opacity 0.55

## Target State

After implementation:

1. New `@keyframes tandem-throb` with slower, subtler parameters
2. New `.avatar-tandem-thinking` class applied to TandemPortrait when backseat is processing
3. Visually distinct from Tier 1 at a glance — users can tell which agent is thinking
4. Uses same `--accent-color` for theme consistency
5. CSS-only — no JS polling or timer-based class toggling

## Key Files

### Files to Modify

| File | Path | Purpose |
|------|------|---------|
| `tailwind.css` | `pennyfarthing/packages/cyclist/src/public/styles/tailwind.css` | Add `@keyframes tandem-throb` and `.avatar-tandem-thinking` after existing avatar-throb (line ~769) |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| `tailwind.css` | `pennyfarthing/packages/cyclist/src/public/styles/tailwind.css` | Existing `avatar-throb` pattern (lines 756-769) |
| `TandemPortrait.tsx` | (from 96-1) | Where `.avatar-tandem-thinking` is applied |

## Technical Approach

### New CSS (add after line 769)

```css
/* Tier 2: Backseat thinking (slower, subtler than primary) */
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
```

### Animation Comparison

| Property | Tier 1 (Primary) | Tier 2 (Backseat) |
|----------|-------------------|-------------------|
| Keyframe | `avatar-throb` | `tandem-throb` |
| Duration | 1.2s | 1.8s |
| Scale | 1.08 | 1.04 |
| Glow spread | 8px blur, 2px spread | 6px blur, 1px spread |
| Easing | ease-in-out | ease-in-out |
| Loop | infinite | infinite |
| Meaning | "I'm working" | "I'm watching" |

The slower, subtler animation communicates subordination — the backseat is present but secondary. Users familiar with the primary throbber instantly understand the backseat is doing something similar but less urgent.

### Interaction with Opacity

The TandemPortrait container has `opacity: 0.55`. The `tandem-throb` scale and glow animate on top of this base opacity. The glow (`box-shadow`) is not affected by the container's opacity — it renders at full color intensity, creating a subtle "peek through" effect.

### Implementation Steps

1. Add `@keyframes tandem-throb` to `tailwind.css` after existing `avatar-throb`
2. Add `.avatar-tandem-thinking` class with the animation
3. Verify TandemPortrait (from 96-1) applies the class when `isThinking` is true
4. Visual verification: both animations running simultaneously should be distinguishable

## Acceptance Criteria

- New `@keyframes tandem-throb` with 1.8s duration, scale 1.04, 6px/1px glow
- New `.avatar-tandem-thinking` class applies the animation
- Visually distinct from primary `avatar-throb` (faster/larger)
- CSS-only — no JS polling or `requestAnimationFrame`
- Uses `var(--accent-color)` for theme consistency
- Works correctly on 48px portrait at opacity 0.55

## Dependencies

### Depends On

- **96-1** (TandemPortrait component) — the component that applies this class

### Depended On By

- **96-4** (Accessibility/responsive) — adds `prefers-reduced-motion` fallback for this animation

## Risks / Open Questions

1. **Opacity + animation interaction:** The container's `opacity: 0.55` may make the subtle glow hard to see on some displays. If testing reveals this, consider slightly increasing glow intensity for the backseat (e.g., 8px/2px instead of 6px/1px). But start with the spec values — don't over-tune before visual testing.

2. **Simultaneous animations:** When both primary and backseat are thinking simultaneously, verify the different durations (1.2s vs 1.8s) create a pleasant asynchronous rhythm rather than distracting phasing effects.
