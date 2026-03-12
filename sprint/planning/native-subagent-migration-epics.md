---
stepsCompleted:
  - step-01-validate
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
  - step-05-import-to-future
inputDocuments:
  - sprint/planning/native-subagent-migration-prd.md
  - docs/adr/0037-native-subagent-migration.md
---

# Native Subagent Migration - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for Native Subagent Migration, decomposing the requirements from the PRD and Architecture ADR into implementable stories.

## Requirements Inventory

### Functional Requirements

- FR1: SM can spawn any of the 10 non-SM agents as native Claude Code subagents
- FR2: Each agent definition includes role-specific tool restrictions
- FR3: Each agent definition includes its persona from the active theme
- FR4: Agent definitions converted from `pennyfarthing-dist/agents/*.md` to `.claude/agents/*.md` format
- FR5: Each spawned agent starts with fresh context: agent def + story context + handoff doc only
- FR6: No conversational state from prior phases carries into a new agent spawn
- FR7: Multiple sequential spawns of the same role get independent context windows
- FR8: SM can pass a handoff document to a spawned agent
- FR9: Each agent produces a structured handoff document at phase completion
- FR10: Gate enforcement validates phase completion before transition
- FR11: Existing phased workflow definitions work without modification
- FR12: TEA can write/edit test files but cannot modify production code
- FR13: Dev can write/edit production code but cannot modify test files
- FR14: Reviewer can read all files but cannot write or edit
- FR15: Tool restrictions enforced by Claude Code's native `tools` allowlist
- FR16: PreToolUse hooks block pushes to protected branches
- FR17: Branch protection rules configured per-repo via `repos.yaml`
- FR18: Tandem mode works with native subagents
- FR19: Team mode works with native subagents
- FR20: PF activation skills spawn native subagents instead of switching personas
- FR21: SM orchestration (session setup, story finish, sprint commands) unchanged

### Non-Functional Requirements

- NFR1: Handoff documents compact enough to leave >80% context budget for agent work
- NFR2: Context isolation adds no meaningful latency beyond native subagent overhead
- NFR3: All existing phased workflows (TDD, trivial, BDD, agent-docs) work without modification
- NFR4: Gate enforcement, Tandem mode, Team mode function with native subagents
- NFR5: Existing PF CLI commands require no changes
- NFR6: Spawned agent always receives complete handoff document (partial = hard failure)
- NFR7: SM detects and reports subagent spawn failures (not silent)
- NFR8: BikeRack TUI portrait panel tracks active agent across subagent transitions
- NFR9: SM emits agent change events to WheelHub before spawning each subagent
- NFR10: Subagents don't need TUI awareness; observability is SM's responsibility

### Additional Requirements

- Persona injected dynamically via `pf prime` output, NOT baked into static agent definitions
- Gate checks run in SM's context as Haiku subagents, not inside phase agents
- Handoff documents use identical format regardless of authoring agent
- Session file append-only during phase; only `pf handoff complete-phase` does atomic transitions
- SM never reads subagent conversation history — only return message + filesystem artifacts
- Relay mode replaced by SM orchestration loop (pause vs auto-proceed)

### FR Coverage Map

- FR1: Epic 1 (Stories 1.1-1.3) — SM can spawn 10 agents as native subagents
- FR2: Epic 1 (Stories 1.1-1.3) — Tool restrictions per agent
- FR3: Epic 1 (Story 1.4) — Persona from active theme
- FR4: Epic 1 (Stories 1.1-1.3) — Convert agent definitions
- FR5: Epic 2 (Stories 2.2, 2.3) — Fresh context per spawn
- FR6: Epic 2 (Story 2.2) — No prior phase state carries over
- FR7: Epic 2 (Stories 2.3, 2.6) — Independent context per sequential spawn
- FR8: Epic 2 (Story 2.3) — SM passes handoff document
- FR9: Epic 2 (Story 2.1) — Agent produces structured handoff
- FR10: Epic 2 (Story 2.4) — Gate enforcement at transitions
- FR11: Epic 2 (Stories 2.5, 2.7) — Existing workflows unchanged
- FR12: Epic 3 (Story 3.1) — TEA writes tests only
- FR13: Epic 3 (Story 3.1) — Dev writes code only
- FR14: Epic 3 (Story 3.1) — Reviewer read-only
- FR15: Epic 1 (Stories 1.1-1.3) — Native tools allowlist enforcement
- FR16: Epic 3 (Story 3.2) — PreToolUse hooks block protected pushes
- FR17: Epic 3 (Story 3.2) — Branch protection via repos.yaml
- FR18: Epic 3 (Story 3.3) — Tandem mode with subagents
- FR19: Epic 3 (Story 3.4) — Team mode with subagents
- FR20: Epic 2 (Story 2.7) — Activation skills spawn subagents
- FR21: Epic 2 (Story 2.7) — SM orchestration unchanged

## Epic List

### Epic 1: Agent Definition Migration
Convert all 10 non-SM agents to `.claude/agents/*.md` format with native tool restrictions and dynamic persona injection.
**FRs covered:** FR1, FR2, FR3, FR4, FR15

### Epic 2: SM Orchestration Loop
SM spawns subagents, passes handoff docs, enforces gates, and transitions phases for full story cycles.
**FRs covered:** FR5, FR6, FR7, FR8, FR9, FR10, FR11, FR20, FR21

### Epic 3: Enforcement & Compatibility
Tool restrictions validated, branch protection hooks, tandem/team mode adapted for subagent isolation.
**FRs covered:** FR12, FR13, FR14, FR16, FR17, FR18, FR19

## Epic 1: Agent Definition Migration

Convert all 10 non-SM agents to `.claude/agents/*.md` format with native tool restrictions, ready to be spawned with isolated context windows.

### Story 1.1: Create `.claude/agents/` directory and Dev agent definition

As a developer using Pennyfarthing,
I want the Dev agent defined as a native Claude Code subagent,
So that it can be spawned with an isolated context window and enforced tool restrictions.

**Acceptance Criteria:**

**Given** the `.claude/agents/` directory does not exist
**When** the Dev agent definition is created at `.claude/agents/dev.md`
**Then** it contains YAML frontmatter with `tools:` allowlist permitting Write/Edit for production code, Read, Glob, Grep, Bash
**And** it contains the Dev role definition extracted from `pennyfarthing-dist/agents/dev.md`
**And** it does NOT contain persona content (persona is injected dynamically)
**And** it can be referenced by Claude Code's Agent tool

### Story 1.2: Create TEA and Reviewer agent definitions

As a developer using Pennyfarthing,
I want TEA and Reviewer defined as native Claude Code subagents,
So that the core TDD triad (TEA/Dev/Reviewer) can all be spawned as isolated agents.

**Acceptance Criteria:**

**Given** `.claude/agents/dev.md` exists from Story 1.1
**When** TEA and Reviewer definitions are created
**Then** `.claude/agents/tea.md` has `tools:` allowing Write/Edit for test files, Read, Glob, Grep, Bash
**And** `.claude/agents/reviewer.md` has `tools:` allowing Read, Glob, Grep, and limited Bash (read-only commands)
**And** Reviewer definition cannot Write or Edit any files
**And** each definition contains its role extracted from `pennyfarthing-dist/agents/`

### Story 1.3: Create remaining 7 agent definitions

As a developer using Pennyfarthing,
I want all remaining agents (Architect, PM, Tech Writer, UX Designer, DevOps, Orchestrator, BA) defined as native subagents,
So that SM can spawn any of the 10 non-SM agents.

**Acceptance Criteria:**

**Given** Dev, TEA, and Reviewer definitions exist from Stories 1.1-1.2
**When** the 7 remaining agent definitions are created in `.claude/agents/`
**Then** each has appropriate `tools:` allowlist matching the PRD tool restriction table
**And** Architect, PM, UX Designer, BA have read-only + limited Bash
**And** Tech Writer has Read, Bash, Write/Edit for documentation files
**And** DevOps has Read, Bash, Write/Edit for infrastructure and CI/CD files
**And** Orchestrator has Read, Bash for meta-operations

### Story 1.4: Adapt `pf prime` for subagent-compatible context output

As a developer using Pennyfarthing,
I want `pf prime` to produce context payloads suitable for Agent tool prompts,
So that SM can assemble complete spawn prompts with persona, story context, and sidecars.

**Acceptance Criteria:**

**Given** `pf prime <agent> --json` currently outputs context for in-conversation activation
**When** a new output mode is added (e.g., `pf prime <agent> --subagent`)
**Then** it outputs a prompt-ready payload containing: persona block, story context, session state, and sidecars
**And** it excludes workflow routing XML, agent behavior guide, and other SM-only content
**And** the output is compact enough that handoff doc + prime output < 20% of context budget (NFR1)

## Epic 2: SM Orchestration Loop

SM can run a full story cycle by spawning subagents, passing handoff docs, enforcing gates, and transitioning phases automatically.

### Story 2.1: Define handoff document contract format

As a developer using Pennyfarthing,
I want a standardized handoff document format,
So that every agent produces and consumes inter-phase contracts identically.

**Acceptance Criteria:**

**Given** no standardized handoff document format exists for native subagents
**When** the handoff contract is defined
**Then** a schema/template exists at `pennyfarthing-dist/schemas/handoff-document-schema.md`
**And** it specifies required sections: Summary, Deliverables, Key Decisions, Open Questions, Test Status
**And** the format is compact (target <500 tokens)
**And** agent definitions reference the schema in their exit protocol

### Story 2.2: SM spawns a single subagent via Agent tool

As a developer using Pennyfarthing,
I want SM to spawn a Dev subagent using the Agent tool,
So that SM can delegate phase work to an isolated context window.

**Acceptance Criteria:**

**Given** SM is the active main conversation and a story session exists
**When** SM needs to run the Dev phase
**Then** SM calls `pf prime dev --subagent` to get the context payload
**And** SM spawns Dev via the Agent tool with the context payload as the prompt
**And** the Agent tool references `.claude/agents/dev.md` for tool restrictions
**And** Dev executes in an isolated context window with no prior phase state (FR5, FR6)
**And** SM receives Dev's return message after completion

### Story 2.3: SM reads handoff documents and chains phases

As a developer using Pennyfarthing,
I want SM to read the outgoing agent's handoff document and pass it to the next agent,
So that phases are connected through file-based contracts without implicit context.

**Acceptance Criteria:**

**Given** a subagent has completed and written `.session/{story}-handoff-{phase}.md`
**When** SM prepares to spawn the next phase's agent
**Then** SM reads the handoff document from the filesystem
**And** SM includes it in the next agent's spawn prompt alongside `pf prime` output
**And** the next agent receives only: its definition + prime context + handoff doc (FR5)
**And** multiple sequential spawns of the same role each get independent context (FR7)

### Story 2.4: SM enforces gates between phases

As a developer using Pennyfarthing,
I want SM to run gate checks after each subagent completes,
So that quality is validated before transitioning to the next phase.

**Acceptance Criteria:**

**Given** a subagent has completed its phase work
**When** SM calls `pf handoff resolve-gate {story} {workflow} {phase}`
**Then** if status is `ready`, SM spawns a Haiku subagent to evaluate the gate
**And** if the gate passes, SM calls `pf handoff complete-phase` to transition
**And** if the gate fails, SM re-spawns the phase agent with failure context for a fix attempt
**And** gate checks run in SM's context, not inside the phase agent (ADR-0037 rule)
**And** existing workflow YAML gate definitions work without modification (FR10, FR11)

### Story 2.5: Full TDD cycle end-to-end validation

As a developer using Pennyfarthing,
I want SM to run a complete TEA-Dev-Reviewer cycle using native subagents,
So that the core TDD workflow works with context isolation.

**Acceptance Criteria:**

**Given** a story session exists with TDD workflow assigned
**When** SM orchestrates the full cycle
**Then** SM spawns TEA, TEA writes tests and produces handoff doc
**And** SM gates TEA, transitions, spawns Dev with TEA's handoff
**And** Dev implements and produces handoff doc
**And** SM gates Dev, transitions, spawns Reviewer with Dev's handoff
**And** Reviewer reviews and produces handoff doc
**And** SM gates Reviewer, transitions back to SM finish
**And** each agent started with <20% context utilization (NFR1)
**And** the session file reflects all phase transitions correctly

### Story 2.6: Reviewer-Dev fix round-trip support

As a developer using Pennyfarthing,
I want fix round-trips to work without degradation,
So that Reviewer findings can be addressed across multiple cycles.

**Acceptance Criteria:**

**Given** Reviewer has found issues and written findings in its handoff doc
**When** SM re-spawns Dev with the Reviewer's findings
**Then** Dev gets a fresh context window with only the findings and relevant files
**And** Dev fixes the issues and produces a new handoff doc
**And** SM re-spawns Reviewer with the new diff and prior findings
**And** this cycle can repeat 3+ times without context degradation (PRD success criteria)
**And** each spawn is fully independent (FR7)

### Story 2.7: Update PF activation skills for native subagents

As a developer using Pennyfarthing,
I want `/pf-dev`, `/pf-tea`, etc. to spawn native subagents instead of switching personas,
So that the existing skill interface works with the new execution model.

**Acceptance Criteria:**

**Given** activation skills currently call `pf agent start` and output context in-conversation
**When** the skills are updated for native subagent mode
**Then** each skill triggers SM to spawn the corresponding agent via Agent tool (FR20)
**And** SM orchestration commands (session setup, story finish, sprint) remain unchanged (FR21)
**And** existing workflow definitions (TDD, trivial, BDD, agent-docs) work without modification (FR11)

## Epic 3: Enforcement & Compatibility

Tool restrictions validated, branch protection works, and tandem/team modes function with isolated subagents.

### Story 3.1: Validate per-role tool restrictions

As a developer using Pennyfarthing,
I want tool restrictions enforced natively by Claude Code,
So that agents cannot perform unauthorized actions.

**Acceptance Criteria:**

**Given** agent definitions have `tools:` allowlists in their frontmatter
**When** TEA attempts to edit a production code file
**Then** Claude Code blocks the edit (FR12)
**When** Dev attempts to edit a test file
**Then** Claude Code blocks the edit (FR13)
**When** Reviewer attempts to Write or Edit any file
**Then** Claude Code blocks the action (FR14)
**And** enforcement is at the Claude Code level, not prompt-level (FR15)

### Story 3.2: PreToolUse hooks for branch protection

As a developer using Pennyfarthing,
I want pushes to protected branches blocked by hooks,
So that agents cannot push directly to main or develop.

**Acceptance Criteria:**

**Given** PreToolUse hooks exist for branch protection
**When** any subagent attempts `git push` to a protected branch (main, develop)
**Then** the hook blocks the push and returns an error (FR16)
**And** branch protection rules are read from `repos.yaml` per-repo (FR17)
**And** hooks work identically for native subagents as they do today

### Story 3.3: Tandem mode with native subagents

As a developer using Pennyfarthing,
I want tandem background observers to work within native subagent contexts,
So that paired workflows (tdd-tandem) function with context isolation.

**Acceptance Criteria:**

**Given** a workflow defines a tandem partner for a phase (e.g., Dev + TEA backseat)
**When** the primary agent is spawned as a native subagent
**Then** the primary agent spawns its tandem partner as a background sub-subagent
**And** the partner writes observations to `.session/{story}-tandem-{partner}.md`
**And** PostToolUse hooks inject observations into the primary agent's context
**And** the primary agent terminates the tandem partner before writing its handoff doc (FR18)

### Story 3.4: Team mode with native subagents

As a developer using Pennyfarthing,
I want team mode (multi-agent collaboration) to work with native subagents,
So that team workflow phases function with context isolation.

**Acceptance Criteria:**

**Given** a workflow defines team members for a phase
**When** the phase is executed with native subagents
**Then** team members can be spawned as parallel subagents by SM or by the lead agent
**And** each team member operates in its own isolated context
**And** results are aggregated through filesystem artifacts (FR19)

### Story 3.5: BikeRack observability for subagent transitions

As a developer using Pennyfarthing,
I want BikeRack TUI to show which agent is active during subagent transitions,
So that I can see workflow progress in real time.

**Acceptance Criteria:**

**Given** SM is about to spawn a subagent
**When** SM emits an agent change event to WheelHub before spawning (NFR9)
**Then** BikeRack portrait panel updates to show the new active agent (NFR8)
**And** the subagent does NOT need TUI awareness (NFR10)
**And** observability is entirely SM's responsibility
