# Story Context: 96-3 - Observation Pulse on Primary Portrait

## Summary

Add new `observation-pulse` CSS keyframe animation — a one-shot 600ms accent glow burst on the primary portrait when a backseat observation is injected via bell mode. Distinct from the looping thinking throb. Auto-removes class after animation completes. Communicates "the backseat has something to say."

## Planning References

- **PRD:** FR21 (observation pulse), NFR6 (CSS-only animation). See `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** "Animation Hierarchy" table (Tier 3: observation pulse) in `sprint/planning/tandem-mode-ux-design.md`
- **Epics Breakdown:** Story 3.3 in `sprint/planning/tandem-mode-epics.md` under "Epic 3"

## Current State

### Existing animation tiers

**File:** `pennyfarthing/packages/cyclist/src/public/styles/tailwind.css` (4212 lines)

- **Tier 1:** `avatar-throb` (lines 756-769) — 1.2s looping, scale 1.08, 8px/2px glow. Primary thinking.
- **Tier 2:** `tandem-throb` (from 96-2) — 1.8s looping, scale 1.04, 6px/1px glow. Backseat thinking.
- **Tier 3:** Does not exist yet — this story adds it.

### PersonaHeader primary portrait

**File:** `pennyfarthing/packages/cyclist/src/public/components/PersonaHeader.tsx` (196 lines)

- Lines 104-115: `.persona-portrait` div wraps the primary portrait image
- After Epic 94: conditionally applies `.avatar-thinking` when `isStreaming` is true
- No observation pulse awareness

### Bell mode injection (from 95-7)

When a tandem observation is injected, the primary agent receives `[Tandem] {persona}: {observation}` via `additionalContext`. The UI needs to detect this injection to trigger the pulse.

## Target State

After implementation:

1. New `@keyframes observation-pulse` — 600ms ease-out, accent glow burst (12px/4px → 0)
2. New `.avatar-observation-pulse` class — one-shot animation (`forwards` fill)
3. Primary portrait gets the pulse class when a backseat observation is injected
4. Class auto-removed after animation completes (600ms) via `onAnimationEnd` or `setTimeout`
5. Distinct from thinking throb — no scale, just a burst of glow that fades
6. If multiple observations arrive in quick succession, each pulse fires independently

## Key Files

### Files to Modify

| File | Path | Purpose |
|------|------|---------|
| `tailwind.css` | `pennyfarthing/packages/cyclist/src/public/styles/tailwind.css` | Add `@keyframes observation-pulse` and `.avatar-observation-pulse` |
| `PersonaHeader.tsx` | `pennyfarthing/packages/cyclist/src/public/components/PersonaHeader.tsx` | Add one-shot pulse class to `.persona-portrait` when observation arrives |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| `tailwind.css` | (lines 756-769) | Existing animation pattern |
| `usePersona.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/usePersona.ts` | Hook that may deliver observation event |

## Technical Approach

### New CSS

```css
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
```

Key differences from thinking throb:
- No `transform: scale()` — pure glow effect
- One-shot (`forwards` fill mode, not `infinite`)
- Shorter duration (600ms vs 1.2s/1.8s)
- Starts bright, fades to zero — opposite of throb's oscillation

### Trigger Mechanism

The pulse fires when the primary agent receives a tandem observation. Detection options:

**Option A: WebSocket event**
The WheelHub server detects tandem observation injection (from 95-7's bell mode hook output) and sends a WebSocket event to the UI. `usePersona` or a dedicated hook exposes `lastObservationTimestamp` that changes on each injection.

**Option B: Message content detection**
The MessagePanel detects `[Tandem]` prefix in injected content and triggers a callback. PersonaHeader subscribes to this callback.

**Option C: State-based**
A shared context or state atom tracks "observation injected" events. Bell mode hook signals via WheelHub API, WheelHub broadcasts to UI.

### One-Shot Class Management

```tsx
// In PersonaHeader
const [showPulse, setShowPulse] = useState(false);

useEffect(() => {
  if (observationReceived) {
    setShowPulse(true);
    const timer = setTimeout(() => setShowPulse(false), 600);
    return () => clearTimeout(timer);
  }
}, [observationReceived]);

// In render:
<div className={`persona-portrait${isStreaming ? ' avatar-thinking' : ''}${showPulse ? ' avatar-observation-pulse' : ''}`}>
```

Alternatively, use `onAnimationEnd`:
```tsx
<div
  className={`persona-portrait${showPulse ? ' avatar-observation-pulse' : ''}`}
  onAnimationEnd={() => setShowPulse(false)}
>
```

### Animation Stacking

The primary portrait can be in `.avatar-thinking` (looping throb) AND receive a `.avatar-observation-pulse` (one-shot). CSS handles this:
- Both classes can coexist — `animation` property from the last-applied class wins
- The pulse temporarily overrides the throb's box-shadow, then the throb resumes
- Alternatively, use a separate pseudo-element (`::after`) for the pulse overlay to avoid animation conflicts

## Acceptance Criteria

- New `@keyframes observation-pulse` with 600ms duration, 12px/4px accent glow fading to 0
- One-shot animation (not looping) with `forwards` fill mode
- Applied to primary portrait when backseat observation is injected
- Class auto-removed after animation completes
- Distinct from Tier 1 (thinking throb) — no scale, just glow burst
- Works correctly when primary is also in `.avatar-thinking` state
- Rapid observations each trigger independent pulses (no debouncing)
- CSS-only animation — no JS-driven frame updates

## Dependencies

### Depends On

- **96-1** (TandemPortrait component) — establishes tandem UI infrastructure
- **95-7** (Bell mode injection) — the event that triggers the pulse

### Depended On By

- **96-4** (Accessibility/responsive) — adds `prefers-reduced-motion` fallback for observation pulse

## Risks / Open Questions

1. **Animation stacking:** If `.avatar-thinking` (throb) and `.avatar-observation-pulse` (pulse) are both active, CSS `animation` property conflict. The pulse should temporarily override, then throb resumes. Solutions: separate pseudo-element for pulse, or explicitly re-apply throb class after pulse completes.

2. **Trigger detection:** How the UI learns that an observation was injected is an integration question. The bell mode hook (95-7) runs server-side. The result flows through Claude Code's tool output. The UI may need WheelHub to broadcast an event when it detects tandem injection in the OTEL stream.

3. **Rapid pulses:** If the backseat writes observations rapidly (e.g., 3 in 2 seconds), each should trigger a pulse. The `setTimeout` approach naturally handles this — each pulse fires independently. But verify visually that rapid pulses don't create a distracting strobe effect.
