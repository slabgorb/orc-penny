---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
  - step-05-import-to-future
inputDocuments:
  - artifacts/prd.md
  - artifacts/ux-design-specification.md
---

# Tandem Mode - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Tandem Mode, decomposing the requirements from the PRD and UX Design Specification into implementable stories.

## Requirements Inventory

### Functional Requirements

- **FR1:** Workflow author can add a `tandem:` block to any phase in a phased workflow definition
- **FR2:** Workflow author can specify which agent serves as the backseat partner
- **FR3:** Workflow author can specify one or more observation scopes (`file-watch`, `tool-watch`, `context-watch`)
- **FR4:** Workflow author can combine multiple scopes for a single backseat (`scope: [file-watch, tool-watch]`)
- **FR5:** BikeLane engine can validate `tandem:` schema at workflow load time and report errors before phase execution
- **FR6:** BikeLane can spawn a backseat agent as a long-lived background subagent when a tandem-configured phase begins
- **FR7:** BikeLane can terminate the backseat agent cleanly when the phase ends (no orphan processes)
- **FR8:** Backseat agent can receive its persona, story context, scope configuration, and observation file path at spawn
- **FR9:** Backseat agent can accumulate context across multiple observations within a single phase
- **FR10:** Backseat agent with `file-watch` scope can detect file changes in the working tree and write observations about them
- **FR11:** Backseat agent with `tool-watch` scope can receive tool call information (name, params, results) from the primary agent and write observations about them
- **FR12:** Backseat agent with `context-watch` scope can receive periodic conversation summaries from the primary agent and write observations about them
- **FR13:** Backseat agent can write observations to an append-only observation file (`.session/{story-id}-tandem-{agent}.md`)
- **FR14:** Each observation entry can include timestamp, trigger type, trigger detail, and observation text
- **FR15:** Bell mode hook can detect new entries in the tandem observation file after each tool use
- **FR16:** Bell mode hook can inject backseat observations into the primary agent's context as bell messages
- **FR17:** Primary agent can surface backseat observations in their own voice, attributing to the backseat agent's persona name
- **FR18:** Cyclist can display a thin portrait panel for the backseat agent below the active agent's portrait
- **FR19:** Backseat portrait can display a throbber when the backseat agent is actively processing
- **FR20:** Main agent portrait can display a throbber when a backseat observation is being injected
- **FR21:** Backseat portrait can resolve from the current theme using standard portrait resolution
- **FR22:** CLI statusline can indicate when a tandem backseat is active alongside the primary agent
- **FR23:** CLI statusline can display both the primary agent name and backseat agent name
- **FR24:** Framework can ship a `tdd-tandem` workflow with Architect backseating during red and green phases
- **FR25:** `tdd-tandem` workflow can configure appropriate scopes per phase (e.g., `file-watch` for Architect during green, `tool-watch` for TEA during green)

### NonFunctional Requirements

- **NFR1:** Backseat agent observation must not block or delay the primary agent's tool execution
- **NFR2:** Bell mode injection of tandem observations must complete within the existing PostToolUse hook time budget (no perceptible delay)
- **NFR3:** `file-watch` scope must detect file changes within 5 seconds of write
- **NFR4:** `tool-watch` scope must deliver tool call data to the backseat within one tool-use cycle
- **NFR5:** `context-watch` summaries must be generated without blocking the primary agent's conversation flow
- **NFR6:** Cyclist portrait throbber animation must use CSS-only (no JS polling or layout recalculation)
- **NFR7:** Token overhead for tandem observation across all scopes must stay under 25% per phase
- **NFR8:** Zero orphan backseat processes after phase completion, even on unexpected phase termination or crash
- **NFR9:** BikeLane must register cleanup handlers for backseat processes at spawn time
- **NFR10:** If backseat agent crashes mid-phase, the primary agent must continue unaffected (observation injection simply stops)
- **NFR11:** Observation file must remain valid markdown even if backseat crashes mid-write (append-only, entry-atomic)
- **NFR12:** Tandem must integrate with existing bell mode infrastructure without requiring bell mode schema changes
- **NFR13:** Tandem portrait panel must integrate with Cyclist's dockview layout without affecting existing panel resizing or arrangement
- **NFR14:** CLI statusline indicator must integrate with existing statusline infrastructure without requiring protocol changes
- **NFR15:** Workflow YAML schema extension must be backward-compatible — workflows without `tandem:` blocks must work unchanged

### Additional Requirements

**From PRD Technical Architecture:**
- Parse `tandem:` block from phase definitions in workflow YAML
- Spawn backseat agent as long-lived background subagent at phase start via Task tool with `run_in_background: true`
- Terminate backseat agent cleanly at phase end (process cleanup, no orphans)
- Pass observation file path and scope configuration to both agents
- Validate `tandem:` schema during workflow loading (fail fast on bad config)
- Observation file format: append-only markdown with timestamp, trigger type, trigger detail, observation text
- Bell mode PostToolUse hook checks tandem file mtime for new content
- Message format for injection: `[Tandem] {persona_name}: {observation_summary}`
- `tdd-tandem` shipping workflow with Architect + TEA backseats

**From UX Design Specification:**
- Baseline fix: Apply `.avatar-thinking` throbber to PersonaHeader primary portrait (currently only on message avatars) — standalone UX improvement
- Extend `usePersona` hook with `isStreaming` flag for primary portrait throbber
- `TandemPortrait` React component wrapping shadcn `Avatar` / `AvatarImage` / `AvatarFallback`
- Three CSS animation tiers: primary thinking (1.2s, scale 1.08), backseat thinking (1.8s, scale 1.04), observation pulse (600ms one-shot)
- New CSS keyframes: `@keyframes tandem-throb` and `@keyframes observation-pulse` in `tailwind.css`
- Backseat portrait: 48px, opacity 0.55, below primary with 8px gap, role badge at bottom-right
- Fade-in/out transitions: 300ms ease-in/ease-out on mount/unmount
- Container queries for dockview panel resize: hide backseat below 180px panel width
- `prefers-reduced-motion` support: all animations degrade to opacity/border-color changes
- Screen reader: `alt="{character} ({role}) - observing"`, `aria-live="polite"` for state changes
- WCAG AA compliance for all new UI elements
- Visual regression snapshot tests: PersonaHeader in four states (no tandem, idle, thinking, pulse)
- Implementation roadmap: Phase 1 (baseline fix) → Phase 2 (tandem core) → Phase 3 (CLI)

### FR Coverage Map

| FR | Epic | Description |
|----|------|-------------|
| FR1 | 2 | `tandem:` block in workflow YAML |
| FR2 | 2 | Partner agent specification |
| FR3 | 2 | Observation scope specification |
| FR4 | 2 | Combinable scopes |
| FR5 | 2 | Schema validation at load time |
| FR6 | 2 | Spawn backseat as background subagent |
| FR7 | 2 | Clean backseat termination |
| FR8 | 2 | Backseat receives persona, context, config |
| FR9 | 2 | Backseat accumulates context across observations |
| FR10 | 2 | `file-watch` scope implementation |
| FR11 | 2 | `tool-watch` scope implementation |
| FR12 | 2 | `context-watch` scope implementation |
| FR13 | 2 | Append-only observation file |
| FR14 | 2 | Observation entry format |
| FR15 | 2 | Bell mode hook detects new entries |
| FR16 | 2 | Bell mode injects observations |
| FR17 | 2 | Primary surfaces observations in own voice |
| FR18 | 3 | Backseat portrait in Cyclist |
| FR19 | 3 | Backseat thinking throbber |
| FR20 | 1+3 | Primary portrait throbber (baseline in Epic 1, observation pulse in Epic 3) |
| FR21 | 3 | Portrait resolution for backseat |
| FR22 | 4 | CLI statusline tandem indicator |
| FR23 | 4 | CLI displays both agent names |
| FR24 | 4 | `tdd-tandem` shipping workflow |
| FR25 | 4 | Per-phase scope configuration in shipping workflow |

## Epic List

### Epic 1: Primary Portrait Thinking Indicator (Baseline Fix)
Users see a thinking throbber on the main agent portrait in Cyclist, resolving a current UX gap where it's unclear when the agent is working. Standalone improvement for all users regardless of tandem.
**FRs covered:** FR20 (partial — primary portrait throbber)
**NFRs addressed:** NFR6 (CSS-only animation)

### Epic 2: Workflow Configuration & Observation Protocol
Workflow authors can add `tandem:` blocks to their workflow YAML, and BikeLane spawns/terminates backseat agents with working observation scopes. The tandem system works end-to-end — backseat observes, writes observations, bell mode injects them, primary surfaces them.
**FRs covered:** FR1-FR17
**NFRs addressed:** NFR1-NFR5, NFR7-NFR12, NFR15

### Epic 3: Cyclist Tandem UI
Users watching agents in Cyclist see the backseat portrait below the primary, with distinct animation states (idle, thinking, observation pulse). The tandem system has its visual layer.
**FRs covered:** FR18-FR21
**NFRs addressed:** NFR6, NFR13

### Epic 4: CLI Tandem & Shipping Workflow
CLI users see tandem status in their statusline, and the framework ships `tdd-tandem` — a ready-to-use workflow demonstrating tandem in action.
**FRs covered:** FR22-FR25
**NFRs addressed:** NFR14

## Epic 1: Primary Portrait Thinking Indicator (Baseline Fix)

Users see a thinking throbber on the main agent portrait in Cyclist, resolving a current UX gap where it's unclear when the agent is working. Standalone improvement for all users regardless of tandem.

### Story 1.1: Extend usePersona Hook with Streaming State

As a Cyclist developer,
I want the `usePersona` hook to expose an `isStreaming` flag reflecting whether the agent is actively generating,
So that components can react to agent thinking state.

**Acceptance Criteria:**

**Given** the primary agent is actively streaming a response
**When** the WebSocket delivers persona state updates
**Then** `usePersona` returns `isStreaming: true`
**And** when streaming stops, `isStreaming` transitions to `false`

**Given** no agent is active
**When** `usePersona` is called
**Then** `isStreaming` defaults to `false`

### Story 1.2: Apply Thinking Throbber to PersonaHeader Portrait

As a user watching an agent work in Cyclist,
I want the primary agent's portrait in PersonaHeader to pulse with the existing `avatar-throb` animation when the agent is thinking,
So that I can tell at a glance whether the agent is working.

**Acceptance Criteria:**

**Given** the agent is streaming (`isStreaming: true` from `usePersona`)
**When** the PersonaHeader renders
**Then** the primary portrait has the `.avatar-thinking` CSS class applied
**And** the portrait pulses with `avatar-throb` (1.2s ease-in-out, scale 1.08, accent box-shadow glow)

**Given** the agent stops streaming
**When** `isStreaming` transitions to `false`
**Then** the `.avatar-thinking` class is removed immediately (no fade-out on the throb)

**Given** the user has `prefers-reduced-motion` enabled
**When** the agent is streaming
**Then** the portrait shows a static opacity change (1.0 → 0.85) instead of the scale/glow animation

**Given** the PersonaHeader is in compact mode (40px portrait)
**When** the agent is streaming
**Then** the throbber animation still applies correctly at the smaller size

## Epic 2: Workflow Configuration & Observation Protocol

Workflow authors can add `tandem:` blocks to their workflow YAML, and BikeLane spawns/terminates backseat agents with working observation scopes. The tandem system works end-to-end — backseat observes, writes observations, bell mode injects them, primary surfaces them.

### Story 2.1: Tandem YAML Schema & BikeLane Validation

As a workflow author,
I want to add a `tandem:` block to any phase in my workflow YAML specifying a partner agent and observation scope,
So that BikeLane understands which phases should run a backseat observer.

**Acceptance Criteria:**

**Given** a workflow YAML phase with a valid `tandem:` block (`partner: architect`, `scope: file-watch`)
**When** BikeLane loads the workflow
**Then** the tandem configuration is parsed and associated with the phase

**Given** a `tandem:` block with combined scopes (`scope: [file-watch, tool-watch]`)
**When** BikeLane loads the workflow
**Then** all specified scopes are parsed and validated

**Given** a `tandem:` block with an invalid scope value (e.g., `scope: banana`)
**When** BikeLane loads the workflow
**Then** validation fails with a clear error message before phase execution begins

**Given** a workflow YAML with no `tandem:` blocks
**When** BikeLane loads the workflow
**Then** the workflow loads and runs unchanged (backward-compatible)

### Story 2.2: Backseat Agent Spawn & Lifecycle

As a workflow engine,
I want BikeLane to spawn a backseat agent as a long-lived background subagent when a tandem-configured phase begins and terminate it cleanly when the phase ends,
So that the backseat runs for the full phase duration without orphan processes.

**Acceptance Criteria:**

**Given** a phase with a valid `tandem:` configuration starts
**When** BikeLane transitions into the phase
**Then** a backseat agent is spawned via Task tool with `run_in_background: true`
**And** the backseat receives its persona, story context, scope configuration, and observation file path

**Given** a tandem phase completes normally
**When** BikeLane transitions to the next phase
**Then** the backseat agent process is terminated cleanly
**And** no orphan processes remain

**Given** a tandem phase terminates unexpectedly (crash)
**When** BikeLane's cleanup handler fires
**Then** the backseat agent process is terminated
**And** no orphan processes remain (NFR8, NFR9)

**Given** the backseat agent crashes mid-phase
**When** BikeLane detects the process is gone
**Then** the primary agent continues unaffected (NFR10)
**And** observation injection simply stops

### Story 2.3: Observation File Format & Writer

As a backseat agent,
I want to write observations to an append-only markdown file with a consistent format,
So that the bell mode hook and any future consumers can reliably read my observations.

**Acceptance Criteria:**

**Given** a backseat agent is spawned for a phase
**When** the observation file is initialized
**Then** it is created at `.session/{story-id}-tandem-{agent}.md` with header (observer, phase, timestamp)

**Given** the backseat has an observation to record
**When** it writes to the observation file
**Then** the entry includes timestamp, trigger type, trigger detail, and observation text in the specified markdown format

**Given** the backseat writes multiple observations
**When** each is appended
**Then** the file remains valid markdown throughout (NFR11)

**Given** the backseat crashes mid-write
**When** the file is read later
**Then** all previously completed entries remain valid (append-only, entry-atomic)

### Story 2.4: File-Watch Observation Scope

As a backseat agent with `file-watch` scope,
I want to detect file changes in the working tree and write observations about them,
So that I can spot architectural drift, code duplication, or pattern violations as files change.

**Acceptance Criteria:**

**Given** the backseat is configured with `scope: file-watch`
**When** a file is created, modified, or deleted in the working tree
**Then** the backseat detects the change within 5 seconds (NFR3)
**And** writes an observation with trigger type `file-watch` and the file path as trigger detail

**Given** multiple files change in rapid succession
**When** the backseat processes them
**Then** observations are written without blocking the primary agent's tool execution (NFR1)

**Given** the backseat accumulates context across multiple file observations within the phase
**When** later files are observed
**Then** the backseat can reference patterns from earlier observations (FR9)

### Story 2.5: Tool-Watch Observation Scope

As a backseat agent with `tool-watch` scope,
I want to receive tool call information from the primary agent and write observations about them,
So that I can watch test runs, edit patterns, and tool usage for quality signals.

**Acceptance Criteria:**

**Given** the backseat is configured with `scope: tool-watch`
**When** the primary agent executes a tool call
**Then** the backseat receives the tool name, parameters, and results within one tool-use cycle (NFR4)
**And** writes an observation with trigger type `tool-watch`

**Given** tool results are very large
**When** the data is delivered to the backseat
**Then** results are truncated to a configurable max size to manage token cost

**Given** the backseat observes tool calls
**When** it writes observations
**Then** it does not block or delay the primary agent's tool execution (NFR1)

### Story 2.6: Context-Watch Observation Scope

As a backseat agent with `context-watch` scope,
I want to receive periodic conversation summaries from the primary agent and write observations about them,
So that I can watch for scope drift, AC alignment issues, or strategic concerns.

**Acceptance Criteria:**

**Given** the backseat is configured with `scope: context-watch`
**When** the primary agent has completed N turns (configurable interval)
**Then** a conversation summary is generated and delivered to the backseat
**And** the summary generation does not block the primary agent's conversation flow (NFR5)

**Given** the backseat receives a conversation summary
**When** it analyzes the summary
**Then** it writes an observation with trigger type `context-watch`

**Given** `context-watch` is combined with other scopes
**When** the backseat processes all scope triggers
**Then** token overhead stays under 25% per phase (NFR7)

### Story 2.7: Bell Mode Observation Injection

As a primary agent working in a tandem phase,
I want backseat observations to be injected into my context via bell mode so I can surface them in my own voice,
So that the user reads observations as natural conversation rather than system messages.

**Acceptance Criteria:**

**Given** the backseat has written a new observation to the tandem file
**When** the primary agent's PostToolUse hook fires
**Then** the bell mode hook detects the new entry by checking file mtime
**And** injects it as a bell message: `[Tandem] {persona_name}: {observation_summary}`

**Given** bell mode injection occurs
**When** the primary agent processes the injected message
**Then** it surfaces the observation in its own voice, attributing to the backseat's persona name (e.g., "Will Bailey suggests...")

**Given** no new observations exist in the tandem file
**When** the PostToolUse hook fires
**Then** no injection occurs and the hook completes within the existing time budget (NFR2)

**Given** the existing bell mode infrastructure
**When** tandem injection is added
**Then** no bell mode schema changes are required (NFR12)

## Epic 3: Cyclist Tandem UI

Users watching agents in Cyclist see the backseat portrait below the primary, with distinct animation states (idle, thinking, observation pulse). The tandem system has its visual layer.

### Story 3.1: TandemPortrait Component

As a user watching a tandem phase in Cyclist,
I want to see a smaller, muted backseat agent portrait below the primary portrait in PersonaHeader,
So that I know a specialist is observing the primary agent's work.

**Acceptance Criteria:**

**Given** a tandem phase is active and `usePersona` provides tandem agent state
**When** PersonaHeader renders
**Then** a `TandemPortrait` component renders below the primary portrait
**And** the backseat portrait is 48px, circular, opacity 0.55, with 8px gap from primary
**And** a role badge (16px) appears at bottom-right of the backseat portrait

**Given** the tandem phase starts
**When** the backseat portrait appears
**Then** it fades in from opacity 0 to 0.55 over 300ms ease-in

**Given** the tandem phase ends (or backseat crashes)
**When** the backseat portrait disappears
**Then** it fades out from opacity 0.55 to 0 over 300ms ease-out

**Given** no tandem phase is active
**When** PersonaHeader renders
**Then** no `TandemPortrait` is rendered and no placeholder or empty space exists

**Given** the backseat portrait image fails to load
**When** `AvatarFallback` triggers
**Then** an emoji fallback is displayed (consistent with existing portrait error handling)

**Given** the PersonaHeader layout with tandem active
**When** the backseat portrait appears
**Then** MessagePanel absorbs the ~56px height increase internally without layout shifts in adjacent dockview panels (NFR13)

### Story 3.2: Backseat Thinking Animation

As a user watching a tandem phase in Cyclist,
I want the backseat portrait to pulse subtly when the backseat agent is actively processing,
So that I can tell at a glance whether the backseat is working.

**Acceptance Criteria:**

**Given** the backseat agent is actively processing (`isThinking: true`)
**When** `TandemPortrait` renders
**Then** the `.avatar-tandem-thinking` class is applied
**And** the portrait pulses with `tandem-throb` keyframes (1.8s ease-in-out, scale 1.04, 6px/1px accent box-shadow)

**Given** the backseat stops processing
**When** `isThinking` transitions to `false`
**Then** the `.avatar-tandem-thinking` class is removed immediately

**Given** the primary portrait is also throbbing (agent thinking)
**When** both animations run simultaneously
**Then** they are visually distinct — primary is faster/larger (1.2s, 1.08), backseat is slower/subtler (1.8s, 1.04)

**Given** both CSS keyframes (`avatar-throb` and `tandem-throb`) exist in `tailwind.css`
**When** the animations render
**Then** they use CSS-only — no JS polling or layout recalculation (NFR6)

### Story 3.3: Observation Pulse on Primary Portrait

As a user watching a tandem phase in Cyclist,
I want the primary portrait to briefly pulse with a distinct glow when a backseat observation is injected,
So that I notice the "shoulder tap" and look for the observation in the conversation.

**Acceptance Criteria:**

**Given** a backseat observation is injected via bell mode
**When** the primary agent receives the observation
**Then** the `.avatar-observation-pulse` class is applied to the primary portrait
**And** the portrait glows with `observation-pulse` keyframes (600ms ease-out, 12px/4px accent box-shadow fading to 0)

**Given** the observation pulse animation completes
**When** 600ms has elapsed
**Then** the `.avatar-observation-pulse` class is automatically removed (one-shot, not looping)

**Given** the primary portrait is already throbbing (agent thinking)
**When** an observation pulse fires
**Then** the observation pulse is visually distinct from the thinking throb (different glow intensity, one-shot vs looping)

**Given** multiple observations arrive in quick succession
**When** each triggers a pulse
**Then** each pulse fires independently (previous pulse completes or is replaced)

### Story 3.4: Tandem UI Accessibility & Responsive Behavior

As a user with accessibility needs or narrow dockview panels,
I want the tandem UI to degrade gracefully with reduced motion preferences and narrow panels,
So that I can use Cyclist effectively regardless of my settings or layout.

**Acceptance Criteria:**

**Given** the user has `prefers-reduced-motion` enabled
**When** tandem animations would normally play
**Then** all three animation tiers are disabled
**And** thinking states fall back to static opacity change (1.0 → 0.85)
**And** observation pulse falls back to a brief border-color change
**And** fade-in/out transitions are instant show/hide

**Given** the backseat portrait is rendered
**When** a screen reader encounters it
**Then** the alt text reads `"{character} ({role}) - observing"`
**And** an `aria-live="polite"` region announces "Backseat agent joined: {character}" on appear and "Backseat agent left" on disappear

**Given** the MessagePanel is resized below 180px width
**When** container queries evaluate
**Then** the `TandemPortrait` is hidden entirely, maintaining primary portrait only

**Given** the MessagePanel is between 180px and 280px width
**When** container queries evaluate
**Then** both portraits display but metadata may truncate

**Given** the backseat portrait is non-interactive (MVP)
**When** keyboard navigation reaches the PersonaHeader
**Then** the backseat portrait has no tab stop and no focus ring
**And** the primary portrait's AgentPopup keyboard support remains unchanged

## Epic 4: CLI Tandem & Shipping Workflow

CLI users see tandem status in their statusline, and the framework ships `tdd-tandem` — a ready-to-use workflow demonstrating tandem in action.

### Story 4.1: CLI Statusline Tandem Indicator

As a CLI user running a tandem workflow,
I want the statusline to show both the primary and backseat agent names when tandem is active,
So that I know a backseat observer is running without needing Cyclist.

**Acceptance Criteria:**

**Given** a tandem phase starts
**When** the CLI statusline updates
**Then** it displays `[Primary Agent] + Backseat Agent` (e.g., `[Toby Ziegler] + Will Bailey`)

**Given** a tandem phase ends (normal completion or backseat crash)
**When** the CLI statusline updates
**Then** the `+ Backseat Agent` suffix is dropped, returning to `[Primary Agent]` only

**Given** the existing statusline infrastructure
**When** tandem indicator is added
**Then** no statusline protocol changes are required (NFR14)

**Given** a workflow with no `tandem:` configuration
**When** the CLI statusline renders
**Then** the statusline displays as it does today — no tandem indicator, no empty suffix

### Story 4.2: Ship `tdd-tandem` Workflow

As a workflow author,
I want a ready-to-use `tdd-tandem` workflow that pairs Architect as backseat during implementation phases,
So that I can adopt tandem mode without writing custom workflow YAML.

**Acceptance Criteria:**

**Given** the framework's workflow directory
**When** a user lists available workflows
**Then** `tdd-tandem` appears with a description indicating it extends TDD with backseat observation

**Given** the `tdd-tandem` workflow definition
**When** it is loaded by BikeLane
**Then** it follows the standard TDD phase sequence (setup → red → green → review → finish)
**And** the `green` phase has `tandem: { partner: architect, scope: file-watch }` configured
**And** scope configuration is appropriate per phase as defined in the PRD (FR25)

**Given** a user runs a story with the `tdd-tandem` workflow
**When** the green phase executes
**Then** Will Bailey (Architect) spawns as the backseat observer
**And** the full tandem loop operates (observation → injection → surfacing)

**Given** a user runs `tdd-tandem` on a story
**When** non-tandem phases execute (setup, red, review, finish)
**Then** those phases run identically to the standard `tdd` workflow — no backseat, no tandem indicator
