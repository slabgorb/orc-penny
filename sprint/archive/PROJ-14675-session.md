# Story 96-2: Backseat thinking animation

**Jira:** PROJ-14675
**Epic:** epic-96 (PROJ-14673)
**Points:** 2
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/PROJ-14675-backseat-thinking-animation
**Assigned:** keith

## Acceptance Criteria

- Add `@keyframes tandem-throb` CSS animation to `tailwind.css` (after existing `avatar-throb` at line ~769)
- Create `.avatar-tandem-thinking` class that applies the tandem-throb animation
- Animation parameters: 1.8s ease-in-out infinite, scale 1.04 (vs 1.08 for primary), 6px/1px box-shadow (vs 8px/2px for primary)
- Apply `.avatar-tandem-thinking` class to TandemPortrait when `isThinking` is true
- Visually distinct from primary avatar-throb: slower and subtler
- CSS-only implementation, no JavaScript polling or layout recalculation
- Uses existing `--accent-color` CSS variable for theme consistency

## Technical Context

This story is part of Epic 96 (Cyclist Tandem UI), which implements the backseat agent visualization in Cyclist. The epic defines three animation tiers:

1. **Tier 1: Primary thinking** - `avatar-throb` (1.2s, scale 1.08) — "I'm working"
2. **Tier 2: Backseat thinking** - `tandem-throb` (1.8s, scale 1.04) — "I'm watching" ← **This story**
3. **Tier 3: Observation pulse** - `observation-pulse` (600ms one-shot) — "I have something"

The tandem-throb animation is applied to the TandemPortrait component (which renders a 48px circular backseat avatar below the primary 100px portrait). The animation should be visually distinct from the primary thinking indicator to prevent confusion at a glance.

Key files:
- `packages/cyclist/src/public/styles/tailwind.css` — where the CSS keyframes and class will be added
- `packages/cyclist/src/public/components/TandemPortrait.tsx` — component that applies the `.avatar-tandem-thinking` class (created in story 96-1)
- `packages/cyclist/src/public/components/PersonaHeader.tsx` — parent component that conditionally renders TandemPortrait
- Reference: `packages/cyclist/src/public/components/Message.tsx` — shows existing `avatar-thinking` pattern to follow

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/styles/tailwind.css` — added `@keyframes tandem-throb`, `.avatar-tandem-thinking` class, and `prefers-reduced-motion` fallback

**Tests:** Build passes, 28 pre-existing test failures unrelated to this CSS-only change
**PR:** #783 — feat(cyclist): backseat thinking animation (PROJ-14675)
**Branch:** feat/PROJ-14675-backseat-thinking-animation (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `usePersona().tandemAgent.isThinking` → `PersonaHeader.tsx:125` → `TandemPortrait.tsx:47` → `.avatar-tandem-thinking` CSS class → `tandem-throb` keyframes (safe: CSS-only, no JS side effects)
**Pattern observed:** Keyframe structure mirrors `avatar-throb` consistently at `tailwind.css:813` — same properties, same CSS variable fallback
**Error handling:** N/A — CSS animation, graceful degradation via reduced motion fallback at `tailwind.css:828-837`
**Accessibility:** Bonus improvement — added `prefers-reduced-motion` fallback for BOTH primary and tandem thinking animations
**Observations:** 5 verified-good, 1 low-severity (no `will-change`, consistent with existing pattern)
**Handoff:** To SM for finish-story

## Implementation Notes

- Trivial workflow: SM (setup complete) → Dev (implementation) → Reviewer (code review) → SM (completion)
- Depends on: Story 96-1 (TandemPortrait component) must be merged first
- CSS placement: Add new animation keyframes and class after existing avatar-throb animation (around line 769 in tailwind.css)
- Include reduced motion fallback: when `prefers-reduced-motion: reduce`, replace animation with static opacity change (opacity: 0.85)
- Container queries already handled in 96-1 for responsive behavior
- No new files to create, only modifications to existing CSS file
