# Session: MSSCI-14676 — Observation pulse on primary portrait

## Story
- **ID:** MSSCI-14676 (96-3)
- **Epic:** MSSCI-14673 (Cyclist Tandem UI)
- **Points:** 2
- **Workflow:** trivial
- **Repo:** pennyfarthing

## Description
New observation-pulse CSS keyframe (600ms ease-out, 12px/4px accent box-shadow fading to 0).
One-shot animation on primary portrait when backseat observation injected.
Auto-removes class after animation. Distinct from thinking throb.

## Acceptance Criteria
- AC1: New `@keyframes observation-pulse` — 600ms ease-out, 12px blur / 4px spread accent box-shadow fading to 0
- AC2: One-shot animation applied to primary portrait (`.persona-portrait`) when backseat observation is injected
- AC3: Animation class auto-removed after 600ms (animationend event)
- AC4: Visually distinct from thinking throb (no scale transform, box-shadow only)
- AC5: Respects prefers-reduced-motion (animation: none)

## Implementation Plan
1. Add `@keyframes observation-pulse` to tailwind.css alongside existing avatar animations
2. Add `.avatar-observation-pulse` class that applies the one-shot animation
3. In PersonaHeader, detect tandemAgent.isThinking false→true transition
4. Apply `.avatar-observation-pulse` class to `.persona-portrait` on transition
5. Listen for `animationend` to auto-remove the class
6. Add reduced-motion rule
7. Write tests

## Key Files
- `packages/cyclist/src/public/styles/tailwind.css` — CSS keyframe + class
- `packages/cyclist/src/public/components/PersonaHeader.tsx` — wire observation pulse trigger
- `packages/cyclist/tests/MSSCI-14676-observation-pulse.test.tsx` — tests

## Phase
- [x] Setup (SM)
- [ ] Implementation (Dev)
- [ ] Review (Reviewer)
- [ ] Finish (SM)
