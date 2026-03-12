# ADR-0037: Native Subagent Migration

**Status:** Proposed
**Date:** 2026-03-12
**Author:** Architect
**PRD:** `sprint/planning/native-subagent-migration-prd.md`

## Context

Pennyfarthing's multi-agent workflow currently operates within a single conversation context. SM activates other agents by switching personas in-conversation via `pf agent start`, which outputs the agent's context (definition, persona, session state, sidecars) into the shared context window. Each phase consumes context budget, and by the Reviewer phase, context utilization is typically 60-80%. This causes rushed reviews, missed findings, and conversation restarts mid-story.

### Problem Statement

Context exhaustion is the #1 friction source: 150 wrong-approach events across 622 sessions. Fix round-trips (Reviewer→Dev→Reviewer) degrade after 1-2 cycles because each iteration further exhausts the shared context window.

### Decision Drivers

- Each agent phase needs a full context budget dedicated to its work, not the remainder from prior phases
- Fix round-trips must work without degradation regardless of cycle count
- Zero persona confusion — no behavioral bleed between phases
- Existing workflow definitions (TDD, trivial, BDD) must work without modification
- Tandem and Team mode must be preserved
- Python runtime architecture (ADR-0034) is unchanged

## Considered Options

### Option 1: Native Claude Code Subagents (SM spawns via Agent tool)

SM remains the main conversation. All other agents (TEA, Dev, Reviewer, Architect, PM, Tech Writer, UX Designer, DevOps, Orchestrator, BA) are defined as `.claude/agents/*.md` files and spawned via Claude Code's Agent tool. Each gets an isolated context window.

**Pros:**
- Complete context isolation — each agent starts fresh
- Unlimited fix round-trips without degradation
- Claude Code enforces tool restrictions natively via `tools:` frontmatter
- Aligned with Claude Code's intended agent model

**Cons:**
- SM must reconstruct context per spawn (prompt engineering overhead)
- Subagent results come back as a single message — SM can't observe intermediate work
- Dependency on Claude Code's agent format (evolving spec)

### Option 2: Conversation Restart with Context Injection

Keep in-conversation persona switching but automatically restart conversations when context budget exceeds a threshold. Re-inject relevant context via prime.

**Pros:**
- Minimal changes to existing system
- No dependency on Claude Code agent format

**Cons:**
- Doesn't solve fix round-trip degradation (same problem recurs)
- User loses conversation continuity
- Context injection is lossy — not all prior decisions survive restart

### Option 3: External Orchestrator (Python process spawns Claude CLI)

A Python process outside Claude Code manages the pipeline, spawning `claude -p` for each phase.

**Pros:**
- Full control over agent lifecycle
- No dependency on Agent tool behavior

**Cons:**
- Cannot nest `claude` CLI sessions (known limitation)
- Loses Claude Code's native tool management
- Complex process orchestration in Python

## Decision Outcome

**Chosen option:** Option 1 — Native Claude Code Subagents

This is the only option that provides true context isolation while staying within Claude Code's execution model. The Agent tool is purpose-built for this pattern, and tool restrictions via `tools:` frontmatter provide enforcement that prompt-level instructions cannot guarantee.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User's Terminal                        │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │              SM (Main Conversation)               │   │
│  │                                                   │   │
│  │  1. pf workflow check        → detect phase       │   │
│  │  2. pf prime <agent> --json  → build prompt       │   │
│  │  3. Agent tool               → spawn subagent     │   │
│  │  4. Read result + handoff doc                     │   │
│  │  5. pf handoff resolve-gate  → check quality      │   │
│  │  6. pf handoff complete-phase → transition         │   │
│  │  7. Loop or finish                                │   │
│  └──────────┬───────────────────────────────────┬────┘   │
│             │ Agent tool                        │         │
│             ▼                                   ▼         │
│  ┌──────────────────┐            ┌──────────────────┐    │
│  │  TEA Subagent    │            │  Dev Subagent    │    │
│  │  .claude/agents/ │            │  .claude/agents/ │    │
│  │  tea.md          │            │  dev.md          │    │
│  │                  │            │                  │    │
│  │  Tools: Write*,  │            │  Tools: Write*,  │    │
│  │  Read, Bash, ... │            │  Read, Bash, ... │    │
│  │  (*test files)   │            │  (*prod code)    │    │
│  └──────────────────┘            └──────────────────┘    │
│                                                          │
│  Shared Filesystem:                                      │
│  .session/{story}-session.md          (state machine)    │
│  .session/{story}-handoff-{phase}.md  (phase contracts)  │
└─────────────────────────────────────────────────────────┘
```

### Component Structure

| Component | Responsibility | Data Owned |
|-----------|---------------|------------|
| SM (main conversation) | Orchestrate phases, spawn agents, gate enforcement | Session file phase state |
| `.claude/agents/*.md` | Define agent behavior + tool restrictions | Agent identity (static) |
| `pf prime` | Assemble context payload for subagent prompts | None (read-only facade) |
| `pf handoff` | Phase transitions, gate resolution, session updates | Session file transitions |
| Handoff documents | Inter-phase contracts on filesystem | Phase deliverables |
| Gate subagents | Quality checks at phase boundaries | Gate pass/fail results |

### Interfaces

**SM → Subagent (Agent tool prompt):**

SM assembles a prompt containing: agent definition (from `pf prime --json`), story context, and the previous phase's handoff document. The subagent's `.claude/agents/{role}.md` file provides tool restrictions and base behavior.

**Subagent → SM (return + filesystem):**

Subagent writes a handoff document to `.session/{story}-handoff-{phase}.md` and returns a summary message to SM. SM reads the handoff doc for the next spawn.

**Handoff Document Contract:**

```markdown
# Handoff: {phase} → {next_phase}
**Story:** {story_id}  |  **Agent:** {role}  |  **Timestamp:** {ISO}

## Summary
{what was done, 2-3 sentences}

## Deliverables
- {file}: {what changed}

## Key Decisions
- {decision}: {rationale}

## Open Questions
- {anything the next agent should know}

## Test Status
{pass/fail counts}
```

### Tool Restrictions

| Agent | `tools:` allowlist | Enforcement |
|-------|-------------------|-------------|
| TEA | Read, Glob, Grep, Bash, Write (test files), Edit (test files) | Claude Code native |
| Dev | Read, Glob, Grep, Bash, Write (prod code), Edit (prod code) | Claude Code native |
| Reviewer | Read, Glob, Grep, Bash (read-only commands) | Claude Code native |
| Architect | Read, Glob, Grep, Bash (limited) | Claude Code native |

Note: Exact `tools:` syntax depends on Claude Code's current allowlist format. File-path restrictions (e.g., "test files only") may require `allowed_tools` with glob patterns or may need enforcement via agent instructions + gate validation.

### SM Orchestration Loop

```
while phase != "finish":
    phase_info = pf workflow check --json
    agent = phase_info.phase_owner
    prime_output = pf prime {agent} --json
    handoff = read .session/{story}-handoff-{prev_phase}.md

    result = Agent(
        name=agent,
        prompt=build_prompt(prime_output, handoff),
        # .claude/agents/{agent}.md provides tool restrictions
    )

    gate = pf handoff resolve-gate {story} {workflow} {phase}
    if gate.blocked: handle_failure(gate, agent)

    pf handoff complete-phase {story} {workflow} {phase} {next}
```

### Relay Mode Replacement

ADR-0017 (Deprecated) used HANDOFF markers detected by Cyclist. With native subagents, relay mode is inherent — SM spawns directly. User control shifts to:
- SM pauses between phases and asks "Continue to {next agent}?" (manual mode)
- SM proceeds automatically through all phases (auto mode)
- Controlled via existing `relay_mode` config, but mechanism is now SM behavior, not marker detection

### Tandem Mode Adaptation

Tandem's background observer pattern works within native subagents:
- Primary agent spawns tandem partner as a background sub-subagent (Agent tool with `run_in_background: true`)
- Observation file (`.session/{story}-tandem-{partner}.md`) remains the interface
- PostToolUse hooks still inject observations into the primary agent's context
- Primary agent terminates tandem before writing handoff doc

### Persona Injection

Persona content from the active theme is baked into `.claude/agents/*.md` at activation time, or injected by `pf prime` into the prompt SM passes to the Agent tool. The agent definition file itself can be static (role + tools) while persona is dynamic (passed in prompt).

Recommended approach: Static `.claude/agents/*.md` for role + tools. Dynamic persona via `pf prime` output in the Agent tool prompt. This avoids regenerating agent definition files when themes change.

## Consequences

### Positive

- **Full context budget per phase** — each agent starts at 0% utilization
- **Unlimited fix round-trips** — Reviewer→Dev→Reviewer cycles never degrade
- **Native tool enforcement** — Claude Code blocks disallowed tools, not just prompt instructions
- **Clean separation** — SM orchestrates, agents execute, filesystem contracts connect them
- **Existing workflow compatibility** — phase definitions unchanged, only execution model differs

### Negative

- **SM becomes more complex** — must manage the spawn-check-transition loop
- **No intermediate observability** — SM can't watch subagent work in progress (only final result)
- **Agent format dependency** — tied to Claude Code's `.claude/agents/*.md` spec (evolving)
- **Prompt engineering overhead** — context assembly for each spawn requires careful construction

### Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Claude Code agent format changes | High | Keep definitions simple; test on each CC update |
| Subagent doesn't write handoff doc | High | Gate check validates file existence; explicit prompt instruction |
| SM context exhaustion from many spawns | Medium | SM summarizes each spawn result; doesn't store full output |
| Tool restriction granularity insufficient | Medium | Supplement with gate validation (e.g., verify no test files modified by Dev) |
| Tandem sub-subagent doesn't work | Medium | Fall back to hook-only observation without live tandem partner |

## Implementation Consistency Rules

1. **Handoff documents use identical format** regardless of authoring agent — SM parses generically
2. **Session file is append-only during a phase** — only `pf handoff complete-phase` does atomic transitions
3. **Tool restrictions in `.claude/agents/*.md` frontmatter are the enforcement layer** — agent prose is guidance, frontmatter is enforcement
4. **SM never reads subagent conversation history** — only return message + filesystem artifacts
5. **Persona is prompt-injected, not baked into agent definitions** — agent files are theme-independent
6. **Gate checks run in SM's context** (as Haiku subagents of SM) — not inside the phase agent's context

## Migration Path

### Phase 1: MVP

1. Create `.claude/agents/*.md` for all 10 non-SM agents with tool restrictions
2. Modify SM's agent definition to include the orchestration loop
3. Adapt `pf prime` to output in a format suitable for Agent tool prompts
4. Define handoff document contract format
5. Validate on one full TDD cycle (SM→TEA→Dev→Reviewer→SM with fix round-trip)

### Phase 2: New Capabilities (post-MVP)

- Intra-phase delegation (Reviewer spawns Dev for lint fix)
- `isolation: worktree` for clean git state per agent
- Context budget telemetry in BikeRack
- Handoff document quality scoring

## Related Decisions

- [ADR-0007: Subagent Delegation Model](0007-subagent-delegation-model.md) — Opus/Haiku split; preserved but execution model changes
- [ADR-0012: Tandem Agent Pairing](0012-tandem-agent-pairing.md) — Consultation protocol; adapted for sub-subagent spawning
- [ADR-0017: Relay Mode](0017-relay-mode-automatic-handoff.md) — **Deprecated**; replaced by SM direct spawning
- [ADR-0034: Post-Migration Architecture](0034-post-migration-architecture.md) — Python runtime boundary; unchanged

---

*Generated by Pennyfarthing architecture workflow*
