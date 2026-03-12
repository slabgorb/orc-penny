# Epic 143: Native Subagent Migration

## Overview

Migrate all Pennyfarthing agent personas from in-conversation persona switching to native Claude Code subagents, giving each agent an isolated context window with role-specific tool restrictions. Agent definitions live in `pennyfarthing-dist/agents/native/` (distributed source of truth); consumer projects access them via `.claude/agents/` symlink. SM remains the main conversation orchestrator, spawning 10 agents as subagents.

**Priority:** P0
**Repo:** pennyfarthing
**Stories:** 16 (various points)

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **ADR-0007** (`docs/adr/0007-subagent-delegation-model.md`) | Subagent delegation patterns, model selection |
| **Agent Templates** (`pennyfarthing-dist/agents/templates/`) | Strategic/tactical agent structure |
| **Prime Guide** (`pennyfarthing-dist/guides/prime.md`) | Context loading, tiers, invocation |

## Background

Currently, all Pennyfarthing agents share the main conversation's context window. When SM activates `/pf-dev`, it loads the Dev agent definition, persona, and behavioral guides into the same conversation. This has several problems:

1. **Context pollution** — Each agent's instructions compete for attention with all previous agents' context in the conversation history.
2. **No tool isolation** — All agents have access to all tools. TEA can write production code; Reviewer can edit files. Role restrictions are advisory, not enforced.
3. **Token overhead** — The full prime output (~4000 tokens) is loaded every time an agent switches, even though most of it is shared boilerplate.

Native Claude Code subagents solve these problems by giving each agent its own isolated context window with explicit tool restrictions defined in YAML frontmatter. The SM spawns subagents via the Agent tool, and they return results when complete.

### Current State (completed)

- **143-1 (done):** Dev native subagent definition created at `pennyfarthing-dist/agents/native/dev.md`
- **143-2 (done):** TEA and Reviewer native subagent definitions created
- **143-3 (done):** Remaining 7 agent definitions (architect, ba, devops, orchestrator, pm, tech-writer, ux-designer) created
- All 10 native agent definitions exist in `pennyfarthing-dist/agents/native/`

### Next Phase

With agent definitions in place, the focus shifts to making the Prime system output context that native subagents can consume (143-4), defining the handoff document contract (143-5), and then wiring SM to actually spawn subagents (143-6+).

## Technical Architecture

### Component Relationships

```
SM (main conversation)
  │
  ├── pf agent start <role>     ← Current: loads into main context
  │
  └── Agent tool (native)       ← Target: spawns isolated subagent
        │
        ├── agents/native/*.md  ← Agent definition (YAML frontmatter + markdown)
        │
        └── Prime output        ← Context injected into subagent prompt
              ├── Session context
              ├── Sprint context
              ├── Repos topology
              ├── Sidecars
              └── Story context (NOT agent def — that's the .md file itself)
```

### Key Files

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/agents/native/*.md` | Native subagent definitions (10 agents) |
| `pennyfarthing-dist/agents/*.md` | Existing in-conversation agent definitions |
| `pennyfarthing-dist/src/pf/prime/cli.py` | Prime CLI — assembles context output |
| `pennyfarthing-dist/src/pf/prime/loader.py` | Context loading functions |
| `pennyfarthing-dist/src/pf/prime/tiers.py` | Tiered context selection (FULL/REFRESH/HANDOFF/MINIMAL) |
| `pennyfarthing-dist/src/pf/prime/models.py` | Data structures (PrimeResult, ContextTier) |
| `pennyfarthing-dist/src/pf/prime/persona.py` | Persona loading and formatting |
| `pennyfarthing-dist/src/pf/prime/workflow.py` | Workflow state detection |

### Data Flow

1. SM decides to spawn a subagent (e.g., TEA for red phase)
2. SM calls `pf prime tea --tier subagent` (new tier)
3. Prime outputs context suitable for injecting into the Agent tool prompt
4. SM passes this context + task description to Agent tool
5. Agent tool creates isolated context with `agents/native/tea.md` as the agent definition
6. Subagent executes with isolated tools and context, returns result

### Interface Contract (143-5)

The handoff document format (defined in 143-5) will be the contract between SM and subagents. Subagents write handoff documents; SM reads them to chain phases.

## Cross-Epic Dependencies

**Depends on:**
- None (self-contained migration)

**Depended on by:**
- Future workflow improvements that assume tool isolation
- BikeRack observability for subagent transitions (143-16, within this epic)
