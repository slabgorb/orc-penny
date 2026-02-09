---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-03-success
  - step-04-journeys
  - step-05-domain (skipped)
  - step-06-innovation (skipped)
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
inputDocuments:
  - docs/adr/0012-tandem-agent-pairing.md
  - docs/planning/ux-design-specification.md
  - pennyfarthing/pennyfarthing-dist/guides/bikelane.md
workflowType: 'prd'
documentCounts:
  briefCount: 0
  researchCount: 0
  brainstormingCount: 0
  projectDocsCount: 3
projectContext: brownfield
classification:
  projectType: Framework Feature / Developer Tooling
  domain: Developer Experience (DX) / AI Agent Orchestration
  complexity: High
  projectContext: brownfield
partyModeContext: |
  Key insights from party mode brainstorm:
  - Bell mode as injection mechanism for backseat-to-primary communication (Toby)
  - File-based observation contract: .session/{story-id}-tandem-{agent}.md (Bartlet/Toby)
  - Pluggable observation scope: file-watch and context-summary modes (Will)
  - Relevance filtering with include/exclude patterns (Sam)
  - Muted portrait with activity pulse in Cyclist, headphone emoji in CLI statusline (Joey)
  - Advisory board mode (multiple backseats) as future extension (Bartlet)
---

# Product Requirements Document - Tandem Mode

**Author:** CJ Cregg (PM Agent)
**Date:** 2026-02-09

## Executive Summary

Tandem Mode extends Pennyfarthing's phased workflows with persistent background observer agents ("backseats") that run alongside the primary agent during a workflow phase. A backseat agent watches the primary agent's work through configurable observation scopes — file changes, tool calls, or conversation summaries — and writes observations to a shared file. The primary agent receives these observations via bell mode injection and surfaces them in their own voice: "Will Bailey suggests we extract this into an adapter." The result: specialist expertise stays in the room during implementation, catching issues that would otherwise surface only at review time.

**Prior art:** ADR-0012 proposed on-demand consultation mode (pull-based). Tandem Mode is push-based — the backseat proactively observes and comments without being asked.

## Success Criteria

### User Success

- Primary agent surfaces backseat suggestions naturally in their own voice ("Will Bailey suggests...")
- Backseat catches cross-phase issues *during* the phase — duplicate code, contrast violations, API mismatches — that would otherwise surface only at review
- Users report fewer surprises during review phase
- The backseat feels like a helpful presence, not noise — relevant observations, not commentary on every file save

### Business Success

- Review rejection rate decreases for stories using tandem workflows vs non-tandem
- Rework cycles (reviewer sends back to dev) decrease measurably
- Workflow authors voluntarily add `tandem:` blocks — adoption is organic, not mandated
- Token cost increase stays under 25% per phase (the value must exceed the cost)

### Technical Success

- Backseat agent spawns and runs for the full phase duration without crashes or orphan processes
- Observation file (`.session/{story-id}-tandem-{agent}.md`) is the single source of truth — Cyclist, CLI, and primary agent all read from it
- All three observation scopes (file-watch, tool-watch, context-watch) work reliably
- Bell mode injection delivers backseat observations to primary agent without disrupting flow
- Portrait panel renders in Cyclist without layout shifts or performance degradation
- CLI statusline updates correctly when tandem is active

### Measurable Outcomes

| Metric | Target | Measurement |
|--------|--------|-------------|
| Review rejections | -30% on tandem stories | Compare reject rate tandem vs non-tandem |
| Backseat relevance | >70% of observations acted on or acknowledged | Tandem log analysis |
| Token overhead | <25% increase per phase | Token tracking |
| Workflow config effort | 3-5 lines of YAML | Schema complexity |
| Crash/orphan rate | 0 orphan processes after phase end | Process monitoring |

## Product Scope & Phased Development

### MVP Strategy

**Approach:** Problem-solving MVP — deliver the complete tandem observation loop with all three observation scopes, both UI surfaces (Cyclist + CLI), and one shipping workflow.

**Rationale:** The three scopes serve fundamentally different backseat roles. Shipping only `file-watch` limits tandem to Architect-style observation. TEA backseating during green needs `tool-watch` (seeing test runs). The observation protocol is the core innovation — it ships complete.

### Observation Protocol — Three Scopes

| Scope | Observes | Cost | Best For |
|-------|----------|------|----------|
| `file-watch` | File changes on disk (diffs, creates, deletes) | Low | Architect spotting pattern drift, code duplication |
| `tool-watch` | Tool calls by primary agent (name, params, results) | Medium | TEA watching test runs, seeing edit patterns |
| `context-watch` | Primary agent's conversation stream (periodic summaries) | High | PM/UX watching for scope drift, AC alignment |

Scopes are combinable: `scope: [file-watch, tool-watch]`

### MVP Feature Set (Phase 1)

| # | Capability | System |
|---|-----------|--------|
| 1 | `tandem:` block in workflow YAML (partner, scope) | BikeLane |
| 2 | Long-lived background subagent spawn/kill per phase | Agent runtime |
| 3 | Observation protocol with 3 scopes: file-watch, tool-watch, context-watch | Observation protocol |
| 4 | Combinable scopes (`scope: [file-watch, tool-watch]`) | Observation protocol |
| 5 | Append-only observation file (`.session/{story-id}-tandem-{agent}.md`) | Observation protocol |
| 6 | Bell mode PostToolUse hook for observation injection | Bell mode |
| 7 | Primary agent surfaces observations in own voice | Agent behavior |
| 8 | Thin portrait panel in Cyclist with throbber (backseat active) | Cyclist UI |
| 9 | Throbber on main portrait when observation injected | Cyclist UI |
| 10 | CLI statusline indicator (`[Primary] + Backseat`) | CLI |
| 11 | `tdd-tandem` shipping workflow (Architect + TEA backseats) | Workflow |

### Post-MVP Features (Phase 2)

- Relevance filtering (include/exclude patterns per scope)
- Tandem log panel in Cyclist (click portrait for observation history)
- Multiple backseat agents per phase (advisory board mode)
- Tandem metrics in sprint retrospective data

### Vision (Phase 3)

- Bidirectional tandem (backseat asks primary clarifying questions)
- Cross-phase memory (backseat carries observations between phases)
- User-configurable tandem at runtime
- Real-time message passing (beyond file protocol)

### Risk Mitigation Strategy

| Risk | Impact | Mitigation |
|------|--------|------------|
| `context-watch` token cost exceeds budget | High | Periodic summaries (every N turns), not full stream; configurable interval |
| `tool-watch` result data too large | Medium | Truncate tool results in observation feed; configurable max size |
| Backseat noise across combined scopes | Medium | Each scope produces distinct trigger types; primary agent can triage by type |
| Orphan processes on phase crash | High | BikeLane cleanup handler; process monitoring |
| Portrait throbber performance | Low | CSS animation only |

## User Journeys

### Journey 1: The Workflow Author — "Making the team smarter"

**Persona:** Alex, a solo developer using Pennyfarthing. Experienced with TDD workflow, has been burned by review rejections catching things the Architect would have spotted during implementation.

**Opening Scene:** Alex has had three stories in a row where Josh (Reviewer) kicked code back because of architectural patterns that Will (Architect) would have flagged immediately. Alex thinks: "Why does Will only show up at the end?"

**Rising Action:** Alex opens their workflow YAML. They see the `tdd` workflow phases — setup, red, green, review, finish. They add a `tandem:` block under the green phase:

```yaml
- name: green
  agent: dev
  tandem:
    partner: architect
    scope: file-watch
```

Three lines. That's it.

**Climax:** First story runs with the new workflow. During green phase, Toby is implementing and the statusline shows `[Toby Ziegler] + Will Bailey`. Midway through, Toby says: "Will Bailey suggests we extract this into an adapter — the current approach will create coupling with the payment module." Alex sees this and thinks: "That's exactly what Josh would have caught in review."

**Resolution:** The PR goes through review cleanly. No rework. Alex adds `tandem:` blocks to two more phases across their workflows. It becomes how they work.

### Journey 2: The Developer Watching Agents Work — "The extra pair of eyes"

**Persona:** Sam, a team lead who uses Cyclist to watch agent workflows on complex stories. Checks in periodically to make sure agents aren't going off the rails.

**Opening Scene:** Sam kicks off an 8-point feature story using `tdd-tandem`. The Cyclist UI shows Toby's portrait in the main panel. Below it, a smaller, muted portrait of Will — just enough to know he's there.

**Rising Action:** Sam checks in 20 minutes later. The conversation shows Toby working through implementation. A few messages back, Toby mentioned: "Will Bailey notes that the event handler pattern here differs from what we established in the notification module — suggests aligning with the existing pattern for consistency." Sam reads it and nods — that's exactly the kind of drift they'd normally catch in their own review pass.

**Climax:** Will's portrait briefly pulses — new observation. Toby acknowledges it in his next message: "Will Bailey raises a good point about the error boundary — adjusting to match the pattern in `ErrorBoundary.tsx`." Sam doesn't have to intervene. The backseat is doing the job.

**Resolution:** When the story reaches review, Josh's review is fast and clean. Sam notices the tandem log shows 4 observations, 3 acted on, 1 acknowledged but deferred. The review cycle that usually takes two rounds takes one.

### Journey Requirements Summary

| Journey | Capabilities Revealed |
|---------|----------------------|
| **Workflow Author** | Simple YAML config (3 lines), workflow validation, sensible defaults |
| **Developer Watching** | Portrait panel (Cyclist), activity pulse, tandem observations surfaced in conversation, tandem log for audit |

Both journeys converge on the same truth: the value is in what *doesn't* happen at review time.

## Developer Tooling Specific Requirements

### Project-Type Overview

Tandem Mode is a framework feature for Pennyfarthing's BikeLane workflow engine. It extends phased workflows with a persistent background observer agent ("backseat") that runs alongside the primary agent for the duration of a phase. The feature spans four systems: workflow YAML schema, agent spawning/observation, Cyclist UI, and CLI statusline.

### Technical Architecture Considerations

**Workflow Engine (BikeLane)**
- Parse `tandem:` block from phase definitions in workflow YAML
- Spawn backseat agent as a long-lived background subagent at phase start
- Terminate backseat agent cleanly at phase end (process cleanup, no orphans)
- Pass observation file path and scope configuration to both agents
- Validate `tandem:` schema during workflow loading (fail fast on bad config)

**Observation Protocol**
- Backseat agent is long-lived for the full phase — accumulates context across all observations
- Three scopes available (see Observation Protocol — Three Scopes table in Product Scope)
- Scopes are combinable: `scope: [file-watch, tool-watch]`
- Backseat writes observations to `.session/{story-id}-tandem-{agent}.md`
- Observation file is append-only during a phase
- Each observation entry includes timestamp, trigger type, trigger detail, and observation text

**Injection Mechanism**
- Bell mode PostToolUse hook detects new entries in the tandem observation file
- Injects observation as a bell-mode message into the primary agent's context
- Primary agent surfaces observation in their own voice using backseat agent's persona name

**Agent Lifecycle**
- Backseat spawned via Task tool with `run_in_background: true`
- Backseat receives: agent persona, story context, scope config, observation file path
- Backseat observes through configured scope(s) — file changes, tool calls, and/or conversation summaries
- Backseat dies when phase transitions (BikeLane terminates the background task)

### Implementation Considerations

**Workflow YAML Schema Extension**
```yaml
tandem:
  partner: architect          # agent name
  scope: file-watch           # single scope

tandem:
  partner: tea
  scope: [file-watch, tool-watch]  # combined scopes
```

**Observation File Format**
```markdown
# Tandem Observations: {story-id}
**Observer:** {agent} ({persona})
**Phase:** {phase}
**Started:** {ISO timestamp}

---

## [{HH:MM}] Observation
**Trigger:** {trigger_type}: {trigger_detail}
{observation text}

---
```

**Bell Mode Integration**
- New hook checks tandem file mtime on PostToolUse
- If new content since last check, injects as bell message
- Message format: `[Tandem] {persona_name}: {observation_summary}`

**Cyclist UI**
- Thin portrait component below active agent portrait in dockview
- Muted opacity (0.6), throbber on portrait when backseat is actively processing
- Throbber on main portrait when backseat observation is injected
- Portrait resolves from theme using standard portrait resolution

**CLI Statusline**
- Format: `[Primary Agent] + Backseat Agent`
- Updates on phase start/end via existing statusline infrastructure

## Functional Requirements

### Workflow Configuration

- **FR1:** Workflow author can add a `tandem:` block to any phase in a phased workflow definition
- **FR2:** Workflow author can specify which agent serves as the backseat partner
- **FR3:** Workflow author can specify one or more observation scopes (`file-watch`, `tool-watch`, `context-watch`)
- **FR4:** Workflow author can combine multiple scopes for a single backseat (`scope: [file-watch, tool-watch]`)
- **FR5:** BikeLane engine can validate `tandem:` schema at workflow load time and report errors before phase execution

### Agent Lifecycle

- **FR6:** BikeLane can spawn a backseat agent as a long-lived background subagent when a tandem-configured phase begins
- **FR7:** BikeLane can terminate the backseat agent cleanly when the phase ends (no orphan processes)
- **FR8:** Backseat agent can receive its persona, story context, scope configuration, and observation file path at spawn
- **FR9:** Backseat agent can accumulate context across multiple observations within a single phase

### Observation Protocol

- **FR10:** Backseat agent with `file-watch` scope can detect file changes in the working tree and write observations about them
- **FR11:** Backseat agent with `tool-watch` scope can receive tool call information (name, params, results) from the primary agent and write observations about them
- **FR12:** Backseat agent with `context-watch` scope can receive periodic conversation summaries from the primary agent and write observations about them
- **FR13:** Backseat agent can write observations to an append-only observation file (`.session/{story-id}-tandem-{agent}.md`)
- **FR14:** Each observation entry can include timestamp, trigger type, trigger detail, and observation text

### Observation Injection

- **FR15:** Bell mode hook can detect new entries in the tandem observation file after each tool use
- **FR16:** Bell mode hook can inject backseat observations into the primary agent's context as bell messages
- **FR17:** Primary agent can surface backseat observations in their own voice, attributing to the backseat agent's persona name

### Cyclist UI

- **FR18:** Cyclist can display a thin portrait panel for the backseat agent below the active agent's portrait
- **FR19:** Backseat portrait can display a throbber when the backseat agent is actively processing
- **FR20:** Main agent portrait can display a throbber when a backseat observation is being injected
- **FR21:** Backseat portrait can resolve from the current theme using standard portrait resolution

### CLI Experience

- **FR22:** CLI statusline can indicate when a tandem backseat is active alongside the primary agent
- **FR23:** CLI statusline can display both the primary agent name and backseat agent name

### Shipping Workflow

- **FR24:** Framework can ship a `tdd-tandem` workflow with Architect backseating during red and green phases
- **FR25:** `tdd-tandem` workflow can configure appropriate scopes per phase (e.g., `file-watch` for Architect during green, `tool-watch` for TEA during green)

## Non-Functional Requirements

### Performance

- **NFR1:** Backseat agent observation must not block or delay the primary agent's tool execution
- **NFR2:** Bell mode injection of tandem observations must complete within the existing PostToolUse hook time budget (no perceptible delay)
- **NFR3:** `file-watch` scope must detect file changes within 5 seconds of write
- **NFR4:** `tool-watch` scope must deliver tool call data to the backseat within one tool-use cycle
- **NFR5:** `context-watch` summaries must be generated without blocking the primary agent's conversation flow
- **NFR6:** Cyclist portrait throbber animation must use CSS-only (no JS polling or layout recalculation)
- **NFR7:** Token overhead for tandem observation across all scopes must stay under 25% per phase

### Reliability

- **NFR8:** Zero orphan backseat processes after phase completion, even on unexpected phase termination or crash
- **NFR9:** BikeLane must register cleanup handlers for backseat processes at spawn time
- **NFR10:** If backseat agent crashes mid-phase, the primary agent must continue unaffected (observation injection simply stops)
- **NFR11:** Observation file must remain valid markdown even if backseat crashes mid-write (append-only, entry-atomic)

### Integration

- **NFR12:** Tandem must integrate with existing bell mode infrastructure without requiring bell mode schema changes
- **NFR13:** Tandem portrait panel must integrate with Cyclist's dockview layout without affecting existing panel resizing or arrangement
- **NFR14:** CLI statusline indicator must integrate with existing statusline infrastructure without requiring protocol changes
- **NFR15:** Workflow YAML schema extension must be backward-compatible — workflows without `tandem:` blocks must work unchanged

