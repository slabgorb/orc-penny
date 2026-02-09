---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-03-core-experience
  - step-04-emotional-response
  - step-05-inspiration
  - step-06-design-system
  - step-07-defining-experience
  - step-08-visual-foundation
  - step-09-design-directions
  - step-10-user-journeys
  - step-11-component-strategy
  - step-12-ux-patterns
  - step-13-responsive-accessibility
  - step-14-complete
lastStep: 14
inputDocuments:
  - artifacts/prd.md
  - docs/planning/ux-design-specification-cyclist-baseline.md
---

# UX Design Specification: Tandem Mode

**Author:** Joey Lucas (UX Designer)
**Date:** 2026-02-09

---

## Executive Summary

### Project Vision

Tandem Mode adds persistent background observer agents ("backseats") to Pennyfarthing's phased workflows. A backseat watches the primary agent's work through configurable observation scopes — file changes, tool calls, or conversation summaries — and writes observations to a shared file. The primary agent surfaces these in their own voice. The UX goal: the backseat should feel like a helpful presence in the room, not noise.

The UI surface is deliberately small — a subordinate portrait in the existing PersonaHeader, activity indicators, and a CLI statusline update. No new panels, no new navigation. Presence, not interface.

### Target Users

**Workflow Authors** — Solo developers and team leads who configure workflow YAML. They already understand phased workflows and want backseat pairing with minimal configuration (3 lines of YAML). Success means fewer review rejections.

**Developers Watching Agents** — Users monitoring agent work in Cyclist. They check in periodically and want visual confidence that a specialist is observing. They read the conversation and expect backseat observations to appear naturally in the primary agent's voice.

### Key Design Challenges

1. **Visual hierarchy** — The backseat portrait must be clearly subordinate to the primary. Size, opacity, and position must communicate "present but not driving" without making the header feel cluttered.

2. **Three throbber states** — Primary thinking (baseline gap fix), backseat processing, and observation injection into primary. Three distinct events on the same panel that users must distinguish at a glance.

3. **Graceful absence** — Most phases have no backseat. The PersonaHeader must feel complete with or without the tandem portrait — additive when active, invisible when not.

### Design Opportunities

1. **Baseline throbber fix** — The PersonaHeader portrait currently lacks a thinking indicator (the `avatar-thinking` animation exists but is only applied to message avatars). Fixing this for all users is the foundation that tandem builds on.

2. **Existing visual vocabulary** — The `avatar-throb` keyframe animation (scale + box-shadow pulse) is already understood by users in message avatars. We extend this to PersonaHeader rather than inventing new patterns.

3. **The observation moment** — When a backseat observation arrives and the primary portrait briefly pulses with a distinct animation, that's the design's signature interaction. It should feel like a tap on the shoulder — noticeable, not alarming.

## Core User Experience

### Defining Experience

The core user action is **ambient monitoring** — glancing at the PersonaHeader to instantly assess agent team state. Tandem Mode is a monitoring experience, not an interaction experience. Users see the backseat portrait and feel informed; they don't click it to perform actions.

The PersonaHeader becomes a team dashboard: who's driving (primary portrait, full opacity), who's watching (backseat portrait, muted), and whether anything needs attention (throbber animations).

### Platform Strategy

- **Primary:** Electron desktop (Cyclist) — PersonaHeader within dockview MessagePanel
- **Secondary:** CLI statusline (`[Primary] + Backseat`)
- **Input:** Mouse/keyboard only, no touch considerations
- **Layout constraint:** PersonaHeader sits at the top of MessagePanel (sacred center panel). Backseat portrait must fit within this existing vertical space without forcing layout shifts or panel resizing.

### Effortless Interactions

- **Automatic appearance** — Backseat portrait fades in when a tandem phase starts. No user action, no configuration UI, no toggle.
- **Automatic disappearance** — Backseat portrait fades out when the phase ends. No cleanup, no dismissal button.
- **Peripheral absorption** — Throbber states are designed for peripheral vision. Users absorb them while reading the conversation, never needing to stop and decode.
- **Consistent thinking indicator** — Primary portrait thinking throb uses the same `avatar-throb` animation already established in message avatars. Zero new visual vocabulary for the baseline fix.

### Critical Success Moments

1. **First appearance** — The backseat portrait appears for the first time in a tandem phase. Users should think "someone's watching" not "what is that?" Smooth fade-in, familiar portrait style, muted but recognizable.
2. **The shoulder tap** — Primary portrait pulses distinctly when a backseat observation is injected. The user connects the visual event to the observation they'll find in the conversation. This is the design's signature moment.
3. **The clean review** — The downstream payoff. Fewer review rejections validate the backseat presence users saw during implementation.

### Experience Principles

1. **Ambient, not interactive** — Tandem UI communicates state through presence and animation, not buttons or controls.
2. **Subordinate by design** — The backseat portrait is always visually smaller, muted, and positioned below the primary. The hierarchy is never ambiguous.
3. **Same vocabulary, new word** — All visual treatments build on existing Cyclist patterns. One new concept maximum: the observation pulse.
4. **Present or absent, never half** — The backseat portrait either exists fully or doesn't exist at all. No loading skeletons, no empty placeholders, no intermediate states.

## Desired Emotional Response

### Primary Emotional Goals

**Confidence** — Users see the backseat portrait and feel "someone competent is watching." Not excitement or delight — steady confidence that a specialist is observing the work.

**Calm** — The backseat presence is ambient and non-demanding. Users should never feel alert fatigue or interruption anxiety from the tandem UI.

**Trust** — Each observation that surfaces in the conversation reinforces that the backseat is doing useful work, not burning tokens.

### Emotional Journey Mapping

| Stage | Feeling | Design Driver |
|-------|---------|---------------|
| Backseat appears | Reassurance | Smooth fade-in, recognizable portrait, muted presence |
| During phase | Background trust | Static muted portrait, occasional subtle throb |
| Observation injected | Mild alertness | Primary portrait one-shot pulse, distinct from thinking |
| Reading observation | Respect | Conversation UX (already handled by agent voice) |
| Backseat disappears | Completeness | Smooth fade-out, phase done |
| Clean review | Vindication | Absence of review pain validates the feature |

### Micro-Emotions

- **Confidence vs. Confusion** — Most critical. Visual hierarchy between primary and backseat must be instantly parseable. If users pause to decode, confusion wins.
- **Trust vs. Skepticism** — Built incrementally through throbber activity and useful observations. Each good catch reinforces trust.
- **Calm vs. Anxiety** — No red, no urgency patterns, no "attention required" signals. Muted opacity and gentle animation maintain calm.

**Emotions to actively avoid:** Anxiety ("is something wrong?"), Annoyance ("stop interrupting"), Confusion ("did my agent switch?").

### Design Implications

| Emotion | Design Choice |
|---------|---------------|
| Confidence | Same portrait pipeline, same circular style — familiar = trustworthy |
| Calm | Muted opacity (0.5-0.6), smaller size (48-56px), no bright borders |
| Mild alertness | Observation pulse is one-shot (not looping), accent color glow |
| Trust | Backseat throbber slower (1.8s vs 1.2s), smaller scale (1.04 vs 1.08) |
| Completeness | Fade-out transition (300ms) when phase ends |

### Emotional Design Principles

1. **Confidence through familiarity** — Every backseat visual uses existing portrait patterns. New presence, zero new vocabulary.
2. **Calm through restraint** — The backseat is the quietest element in the header. Muted, small, slow. It whispers.
3. **Trust through consistency** — Throbber means "working." Observation pulse means "I have something." No ambiguity.
4. **Respect through non-interruption** — The observation pulse happens on the primary portrait, not the backseat. The backseat never demands attention directly.

## UX Pattern Analysis & Inspiration

### Inspiring Products Analysis

**PersonaHeader (Cyclist — existing component)** — Circular portrait (100px), role badge, character name, theme, catchphrase. Compact mode (40px) proves the pattern works at reduced sizes. Click opens AgentPopup team roster. Real-time updates via WebSocket. Emoji fallback on portrait error. Clean hierarchy where portrait anchors and text metadata is secondary.

**Message Avatars (Cyclist — existing component)** — 32px inline portraits with `avatar-thinking` class that applies `avatar-throb` animation (scale 1.08 + accent box-shadow glow, 1.2s ease-in-out) during streaming. Same portrait resolution pipeline. The throbber is the established visual vocabulary: "pulsing portrait = agent is working."

**shadcn/ui Avatar (component library)** — `Avatar`, `AvatarImage`, `AvatarFallback` primitives with standardized sizing, built-in fallback handling, and accessibility defaults. Composable for wrapping with additional state indicators.

### Transferable UX Patterns

**Size hierarchy for role distinction** — Primary 100px, backseat 48px. The ~2:1 ratio clearly communicates "supporting, not leading." Validated by existing compact mode.

**Throbber vocabulary** — `avatar-throb` at 1.2s ease-in-out with scale(1.08) + box-shadow glow. Already in users' visual vocabulary from message avatars. Extend to PersonaHeader, don't reinvent.

**Portrait resolution pipeline** — Backseat uses identical `/portraits/{theme}/{size}/{slug}.png` path resolution. Zero new infrastructure.

**shadcn Avatar composability** — Wrap backseat in Avatar component with outer ring or badge for observation state, using shadcn's composition model.

### Anti-Patterns to Avoid

- **Separate dockview panel for backseat** — Elevates backseat to peer status, fragments user attention. The whole point is subordinate presence within PersonaHeader.
- **Notification badges / counts** — No red dots, no "3 observations" counters. This isn't email. The observation pulse is the only signal.
- **Status text on backseat** — No "Observing...", "Idle", "Processing" labels. The throbber communicates state; text forces reading instead of glancing.
- **Interactive backseat portrait (MVP)** — No click, no tooltip, no context menu. Post-MVP can add tandem log behind a click. MVP is presence-only.

### Design Inspiration Strategy

| Strategy | Pattern | Rationale |
|----------|---------|-----------|
| **Adopt** | `avatar-throb` on PersonaHeader primary | Baseline fix — same animation, new location |
| **Adopt** | Portrait resolution for backseat | Same infrastructure, new consumer |
| **Adopt** | shadcn Avatar + AvatarFallback for backseat | Consistent component model, built-in error handling |
| **Adapt** | `avatar-throb` timing for backseat (1.8s, scale 1.04) | Slower/subtler = "working quietly" |
| **Adapt** | Compact sizing (48px) for backseat | Slightly larger than compact (40px) for recognizability |
| **Create** | One-shot observation pulse on primary | New animation — single accent glow burst, not looping |
| **Avoid** | Separate panel for backseat | Elevates to peer status |
| **Avoid** | Notification badges/counts | Wrong metaphor |
| **Avoid** | Status text labels | Breaks ambient monitoring |

## Design System Foundation

### Design System Choice

**shadcn/ui + Tailwind v4** — The existing Cyclist design system. Tandem Mode is a feature addition, not a new application. All UI work uses the established component library, design tokens, and animation patterns already in place.

### Rationale for Selection

- **Already adopted** — Every Cyclist panel, dialog, and component uses shadcn/ui primitives. Introducing a different system would create inconsistency.
- **Avatar component available** — shadcn's `Avatar` / `AvatarImage` / `AvatarFallback` provides the backseat portrait with built-in error handling and accessible markup.
- **Theme bridge established** — Cyclist's CSS custom properties (`--accent-color`, `--border`, `--text-secondary`) are already mapped to Tailwind tokens via `tailwind.config.js`. Backseat portrait inherits theme automatically.
- **Animation infrastructure exists** — Custom keyframes are defined in `tailwind.css`. We add new keyframes to the same file, following the same pattern.

### Implementation Approach

- Use shadcn `Avatar` for backseat portrait component
- Apply Tailwind utilities for sizing (`w-12 h-12`), opacity (`opacity-55`), and transitions (`transition-opacity duration-300`)
- Define new CSS keyframes in `tailwind.css` alongside existing `avatar-throb`
- No new component library dependencies required

### Customization Strategy

| Addition | Type | Purpose |
|----------|------|---------|
| `@keyframes observation-pulse` | CSS keyframe | One-shot accent glow on primary portrait when observation injected |
| `.avatar-tandem-thinking` | CSS class | Slower/subtler throbber variant for backseat (1.8s, scale 1.04) |
| `.persona-tandem-portrait` | CSS class | Backseat portrait container positioning and opacity |
| Theme inheritance | CSS variables | Backseat portrait uses existing `--accent-color`, `--border` tokens |

## Defining Experience

### Experience Description

"My agents watch each other's work." Users witness collective intelligence — two agent portraits in the header, one driving, one observing. The defining moment is seeing the primary agent surface a backseat observation naturally in conversation: "Will Bailey suggests we extract this into an adapter." The backseat's presence is felt through its contributions, not its interface.

### User Mental Model

**Familiar metaphor:** Pair programming for AI agents. The backseat is the navigator; the primary is the driver. Users already understand this dynamic from IDE pairing, mob programming, and code review.

**Mental model shift:** From "sequential gatekeepers" (implement → review → reject → fix → re-review) to "collaborative observers" (implement with real-time specialist oversight → clean review).

**Key risk:** First-time users may mistake the backseat portrait for an agent switch. Defense: clear size/opacity hierarchy and visible role badge on the backseat portrait.

### Success Criteria

| Criterion | "It just works" when... |
|-----------|------------------------|
| Instant recognition | User sees backseat portrait and immediately knows who it is and that it's subordinate |
| Zero configuration | Backseat appears because the workflow defined it — no user action |
| Natural surfacing | Observations appear as conversation, not system messages |
| Review payoff | Fewer review rejections on tandem stories |
| No attention tax | User never feels they need to manage or monitor the backseat |

### Novel UX Patterns

**Established patterns in novel combination.** Every individual element (circular portrait, throbber animation, size hierarchy, opacity for subordination) is already proven in Cyclist. The novelty is composing two portraits with distinct animation states in the same header — the combination is new, the vocabulary is familiar. No user education required.

### Experience Mechanics

**Initiation:** Automatic. Phase with `tandem:` config starts → backseat portrait fades in (opacity 0 → 0.55, 300ms ease-in). No user action.

**Interaction:** None. Monitoring experience. User watches; system handles spawn, observe, write, inject, surface.

**Feedback:**
- Backseat working → subtle throbber (1.8s, scale 1.04)
- Backseat has observation → one-shot pulse on primary portrait (accent glow, ~600ms)
- Observation delivered → primary agent's next message includes it in their voice
- Backseat crash → portrait stops throbbing, fades out. Primary continues. No error UI.

**Completion:** Phase transitions → backseat portrait fades out (opacity 0.55 → 0, 300ms ease-out). CLI drops `+ Backseat` suffix. Seamless.

## Visual Design Foundation

### Color System

Tandem Mode introduces zero new colors. All visual treatments map to existing Cyclist theme tokens:

| Token | Tandem Usage | Purpose |
|-------|-------------|---------|
| `--accent-color` | Primary throbber glow, observation pulse glow | Activity indication |
| `--text-primary` | Backseat role badge text | Readability |
| `--text-secondary` | Backseat character name (if shown post-MVP) | Subordinate text |
| `--bg-secondary` | Backseat portrait background fallback | Subtle container |

The observation pulse uses `--accent-color` — same color family as the thinking throbber, different animation gesture.

### Typography System

No new typography. Backseat portrait in MVP is image-only with a role badge. Role badge inherits existing PersonaHeader badge styling: uppercase, `text-xs`, `font-medium`, color-coded by agent role.

### Spacing & Layout Foundation

```
PersonaHeader layout with tandem:
┌───────────────────────────────────────────────┐
│  ┌──────────┐  Character Name                 │
│  │ Primary  │  [ROLE]  Theme                  │
│  │  100px   │  "Catchphrase"                  │
│  └──────────┘                                 │
│    ┌──────┐  ← 48px backseat (opacity 0.55)   │
│    │[ROLE]│  ← role badge (16px, bottom-right) │
│    └──────┘                                   │
└───────────────────────────────────────────────┘
Gap: 8px between primary and backseat portraits
Height increase: ~56px when tandem active (temporary)
```

- Backseat left-aligned with primary portrait
- 48px circular portrait, 0.55 opacity
- 8px gap from primary portrait bottom edge
- Header height grows only when tandem is active; fade-in animation makes growth feel intentional
- No layout shifts in other panels — MessagePanel absorbs the height change internally

### Accessibility Considerations

- **Alt text:** `"{character} ({role}) - observing"` on backseat portrait for screen readers
- **Reduced motion:** Throbber animations fall back to static opacity change when `prefers-reduced-motion` is set
- **Role identification:** Role badge provides text-based identification alongside visual portrait
- **Contrast:** Backseat at 0.55 opacity against dark backgrounds exceeds 3:1 for decorative/informational elements

## Design Direction Decision

### Design Directions Explored

Four layout approaches evaluated for backseat portrait placement within PersonaHeader:

- **A: Inline Below** — Backseat portrait below primary, left-aligned, vertical stack
- **B: Overlapping Satellite** — Backseat overlaps primary corner, badge-like positioning
- **C: Side-by-Side** — Backseat to the right of primary, horizontal arrangement
- **D: Portrait Group Stack** — Both portraits in a bordered container group

### Chosen Direction

**Direction A: Inline Below** — Backseat portrait appears directly below the primary portrait, left-aligned, as a subordinate element in the existing vertical flow.

```
┌──────────────────────────────────────────┐
│  ┌──────────┐  Toby Ziegler              │
│  │ Primary  │  [DEV]  West Wing          │
│  │  100px   │  "What kind of day..."     │
│  │  ●throb  │                            │
│  └──────────┘                            │
│    ┌──────┐                              │
│    │Back  │  ← 48px, opacity 0.55        │
│    │[ARC] │  ← role badge bottom-right   │
│    └──────┘                              │
└──────────────────────────────────────────┘
```

### Design Rationale

| Criterion | A: Inline | B: Overlap | C: Side-by-Side | D: Group |
|-----------|-----------|-----------|-----------------|----------|
| Visual hierarchy | Clear — below = subordinate | Ambiguous — badge-like | Weak — peers | Muddled — container equalizes |
| Layout impact | +56px height (acceptable) | None | None | +40px, smaller primary |
| Pattern fit | Follows existing vertical flow | No precedent in Cyclist | Changes horizontal layout | Novel container |
| Graceful absence | Height shrinks smoothly | Clean | Text space recovers | Container disappears — jarring |
| Implementation | Low — append to flex column | Medium — absolute positioning | Medium — flex row change | High — refactor group |

Direction A wins on hierarchy clarity, implementation simplicity, and graceful degradation.

### Implementation Approach

- Backseat portrait rendered as conditional child in PersonaHeader's portrait column
- Positioned via flex column with `gap-2` (8px) between primary and backseat
- Fade-in/out via `transition-opacity duration-300` on mount/unmount
- Height change absorbed by MessagePanel scroll area — no impact on dockview layout
- Role badge absolute-positioned at bottom-right of backseat avatar container

## User Journey Flows

### Journey 1: Workflow Author — Configuring Tandem

YAML-only journey. Author adds `tandem:` block (partner + scope) to a workflow phase definition. BikeLane validates at load time. Success = 3 lines of config. No UI involved — the UX surface is documentation clarity and error message quality.

Entry: Author opens workflow YAML → Adds tandem block → Specifies partner and scope → Saves → BikeLane validates → Ready

Error path: Invalid schema → clear error message → fix → retry

### Journey 2: User Watching Tandem in Cyclist

Passive monitoring journey. Entirely observation-based — user takes no actions.

1. Phase starts → backseat portrait fades in below primary (300ms)
2. User glances at header → sees two portraits → registers subordinate presence via size/opacity/role badge
3. User reads conversation (main loop)
4. Backseat throbber pulses subtly when working → user absorbs peripherally
5. Observation pulse fires on primary portrait → user notices "shoulder tap"
6. User reads primary agent's next message → sees backseat observation in agent voice
7. Loop continues until phase ends → backseat portrait fades out

Error path: If user confused by second portrait → role badge resolves identity immediately

### Journey 3: CLI User with Tandem

Statusline-only journey. `[Primary Agent] + Backseat Agent` appears at phase start, drops `+ Backseat` at phase end. Observations surface in conversation text.

### Journey 4: Backseat Crash Recovery

Silent degradation. Backseat crashes → portrait stops throbbing → fades out → primary continues unaffected → no error UI → phase completes normally without backseat help.

### Journey Patterns

- **Zero-action entry** — All journeys start automatically from workflow config. No runtime initiation.
- **Peripheral monitoring loop** — Tandem inserts into the existing read-conversation-glance-header loop without adding steps.
- **Graceful degradation** — Every error path resolves without user intervention.
- **One-shot feedback** — Observation pulse fires once per observation. No persistent or accumulating indicators.

### Flow Optimization Principles

- **Steps to value: 0** — User does nothing to receive backseat value
- **Cognitive load: Minimal** — One new visual element, one new animation, both using familiar patterns
- **Error recovery: Invisible** — No modals, no toasts, no retry buttons. System heals silently.

## Component Strategy

### Design System Components

**From shadcn/ui (used directly):**
- `Avatar` / `AvatarImage` / `AvatarFallback` — backseat portrait rendering with error handling
- `Badge` — role badge on backseat portrait

**From Cyclist (extended):**
- `PersonaHeader` — modified to conditionally render `TandemPortrait` child
- `usePersona` hook — extended to include tandem agent state and `isStreaming` flag
- `.avatar-thinking` class — applied to PersonaHeader primary portrait (baseline fix)
- Portrait resolution pipeline — used unchanged for backseat portrait URLs

### Custom Components

**`TandemPortrait` (React component)**

Renders backseat agent portrait below primary in PersonaHeader. Wraps shadcn `Avatar` with tandem-specific styling and animation states.

| State | Visual | Trigger |
|-------|--------|---------|
| Idle | Static portrait, opacity 0.55 | Backseat spawned, not processing |
| Thinking | Subtle throb (1.8s, scale 1.04) | Backseat actively processing |
| Entering | Fade-in (0 → 0.55, 300ms) | Phase starts with tandem config |
| Exiting | Fade-out (0.55 → 0, 300ms) | Phase ends or backseat crashes |
| Error | Emoji fallback | Portrait image load failure |

Props: `tandemAgent: { character, role, slug, theme, isActive, isThinking }`
Accessibility: `alt="{character} ({role}) - observing"`

**`.avatar-tandem-thinking` (CSS animation)**

Slower, subtler variant of `avatar-throb`: 1.8s duration, scale(1.04), 6px/1px box-shadow. Communicates "working quietly."

**`.avatar-observation-pulse` (CSS animation)**

One-shot accent glow on primary portrait: 600ms ease-out, fires once. Applied when backseat observation injected, removed after animation ends.

### Component Implementation Strategy

- All custom components built using existing design system tokens (CSS variables, Tailwind utilities)
- `TandemPortrait` is a leaf component — no children, no composition
- CSS animations defined in `tailwind.css` alongside existing `avatar-throb` keyframes
- `usePersona` hook extended (not replaced) — backward compatible
- `prefers-reduced-motion` respected on all animations

### Implementation Roadmap

| Phase | Component | Priority |
|-------|-----------|----------|
| **1: Baseline** | `.avatar-thinking` on PersonaHeader primary + `usePersona` isStreaming | Critical — standalone UX fix |
| **2: Tandem Core** | `TandemPortrait` + `.avatar-tandem-thinking` + `.avatar-observation-pulse` | Core — main feature |
| **3: CLI** | Statusline `+ Backseat` indicator | Supporting — CLI parity |

## UX Consistency Patterns

### Animation Hierarchy

Three distinct animation tiers with no ambiguity or overlap:

| Tier | Animation | Duration | Scale | Glow | Meaning |
|------|-----------|----------|-------|------|---------|
| 1: Primary thinking | `avatar-throb` | 1.2s | 1.08 | 8px/2px | "I'm working" |
| 2: Backseat thinking | `tandem-throb` | 1.8s | 1.04 | 6px/1px | "I'm watching" |
| 3: Observation pulse | `observation-pulse` | 600ms | none | 12px/4px → 0 | "I have something" |

Tier 1 and 2 loop. Tier 3 fires once. No two looping animations on the same portrait simultaneously.

### State Transition Patterns

| Transition | Duration | Easing |
|------------|----------|--------|
| Appear / Disappear | 300ms | ease-in / ease-out |
| Start/stop thinking | immediate | class add/remove |
| Observation pulse | 600ms | ease-out, one-shot, auto-removes |

No transition exceeds 300ms. No snapping — everything fades. `prefers-reduced-motion` replaces animations with opacity-only changes.

### Portrait Presence Pattern

| Property | Primary | Backseat |
|----------|---------|----------|
| Size | 100px | 48px |
| Opacity | 1.0 | 0.55 |
| Position | Top | Below, 8px gap |
| Role badge | Standard | 16px |
| Click | AgentPopup | None (MVP) |

The backseat is subordinate on every visual axis. No property equals or exceeds the primary.

### Feedback Patterns

| Event | Cyclist | CLI |
|-------|---------|-----|
| Phase starts | Portrait fades in | `+ Backseat` in statusline |
| Processing | Subtle throbber | None |
| Observation | Pulse on primary | Text in conversation |
| Phase ends | Portrait fades out | Drops `+ Backseat` |
| Crash | Silent fade out | Drops `+ Backseat` |

No toasts, no modals, no error dialogs. All feedback is animation or conversation text.

### Empty & Loading States

No tandem → no placeholder. Portrait loading → emoji fallback. Agent spawning → no loading spinner. Present or absent, never half.

## Responsive Design & Accessibility

### Responsive Strategy

Desktop-only Electron app. No mobile or tablet breakpoints. The responsive concern is **dockview panel resize**, not viewport size.

**Panel Resize Behavior:**
- PersonaHeader adapts within MessagePanel width constraints
- Below ~280px panel width: backseat portrait and primary metadata stack vertically (already the default layout)
- Below ~180px panel width: hide backseat portrait entirely, maintain primary portrait only
- Portrait sizes are fixed (100px primary, 48px backseat) — no fluid scaling

**Container Query Strategy:**
- Use CSS container queries on MessagePanel wrapper rather than viewport media queries
- `@container (max-width: 180px)` → hide `TandemPortrait`
- Portraits and animations are invariant to panel width above the minimum threshold

### Breakpoint Strategy

No viewport breakpoints. Two container-query thresholds:

| Threshold | Behavior |
|-----------|----------|
| `> 280px` | Full layout — primary + backseat + metadata |
| `180px – 280px` | Compact — primary + backseat, metadata may truncate |
| `< 180px` | Minimal — primary only, backseat hidden |

Mobile-first vs desktop-first is not applicable. Cyclist is desktop-only Electron. The container queries are defensive fallbacks for narrow dockview splits, not a responsive design strategy.

### Accessibility Strategy

**WCAG AA compliance** — industry standard, appropriate for a developer tool.

**Color Contrast:**
- Backseat portrait at 0.55 opacity is decorative/informational, not interactive — 3:1 contrast sufficient per WCAG 1.4.11
- Role badge text meets 4.5:1 against badge background (inherited from existing PersonaHeader badges)
- All existing Cyclist contrast ratios maintained — Tandem Mode adds no new text or interactive color pairings

**Keyboard Navigation:**
- Backseat portrait is non-interactive in MVP — no tab stop, no focus ring
- Primary portrait click (AgentPopup) already has keyboard support — unchanged
- Post-MVP: if backseat click is added, it will receive `tabindex="0"`, focus ring, and Enter/Space activation

**Screen Reader Support:**
- Backseat portrait: `alt="{character} ({role}) - observing"` on `AvatarImage`
- State changes announced via `aria-live="polite"` region: "Backseat agent joined: {character}" / "Backseat agent left"
- Observation pulse: no screen reader announcement (visual-only, observation content appears in conversation text which is already read sequentially)

**Reduced Motion:**
- `@media (prefers-reduced-motion: reduce)` disables all three animation tiers
- Thinking state falls back to static opacity change (1.0 → 0.85 toggle)
- Observation state falls back to brief border-color change
- Fade-in/out transitions reduced to instant show/hide

**Touch Targets:**
- Not applicable — Electron desktop, mouse/keyboard only
- If future touch support added: backseat portrait (48px) meets 44x44px minimum

### Testing Strategy

**Responsive Testing:**
- Test PersonaHeader at dockview panel widths: 150px, 200px, 280px, 400px, 600px
- Verify container query thresholds trigger correctly
- Confirm no layout shifts in adjacent panels when backseat appears/disappears
- Test with dockview panel drag-resize while tandem is active

**Accessibility Testing:**
- Automated: axe-core on MessagePanel with tandem active and inactive
- Screen reader: VoiceOver (macOS) — verify backseat portrait alt text and aria-live announcements
- Keyboard: confirm backseat portrait is not in tab order (MVP), primary AgentPopup still accessible
- Reduced motion: toggle `prefers-reduced-motion` in Electron — verify all animations gracefully degrade
- Color: test with macOS color filters (grayscale, protanopia) — verify role badge remains identifiable

**Visual Regression:**
- Snapshot tests for PersonaHeader in four states: no tandem, tandem idle, tandem thinking, observation pulse
- Compare across Cyclist themes to verify `--accent-color` glow renders correctly per theme

### Implementation Guidelines

**Responsive Development:**
- Use CSS container queries (`@container`) not viewport media queries (`@media`)
- Portrait sizes are fixed `px` values — no `rem`, `%`, or `vw` units for portrait dimensions
- Spacing uses Tailwind's `gap-2` (8px) — standard spacing token
- Test with dockview's panel resize handle, not browser resize

**Accessibility Development:**
- Semantic HTML: backseat portrait wrapped in `<figure>` with `role="img"` or shadcn Avatar (which provides correct semantics)
- `aria-live="polite"` container for tandem state change announcements — place in PersonaHeader, not on the portrait itself
- `prefers-reduced-motion` query wraps all `@keyframes` declarations — define reduced variants alongside full animations in `tailwind.css`
- No `aria-hidden="true"` on backseat portrait — it carries meaningful state information via alt text
- Role badge: use `aria-label` on badge element for screen readers, not just visual text
