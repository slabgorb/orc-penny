---
parent: context-epic-136.md
workflow: tdd
---

# Story 136-20: Integrate Perplexity MCP for agent research tasks

## Business Context

Pennyfarthing agents operate in a knowledge bubble — they know what's in their context window and nothing else. When an agent encounters an unfamiliar library API, a breaking change in a dependency, or needs to verify a best practice, it has two options: guess, or stop and ask the user. Both are bad. Guessing produces wrong code. Stopping breaks flow and burns user goodwill.

Perplexity MCP tools (`perplexity_ask`, `perplexity_search`, `perplexity_research`, `perplexity_reason`) are already available in the Claude Code environment via MCP server configuration. But zero agent definitions reference them, no guide mentions them, and no skill wraps them. They're loaded but unused.

This story teaches agents when and how to use Perplexity for scoped, cited research — without turning every implementation task into a research project. The sibling story 136-19 (Context7) handles library documentation lookups; this story covers broader knowledge needs: best practices, vulnerability checks, ecosystem changes, error diagnosis.

## Technical Guardrails

### Key Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing-dist/guides/agent-coordination.md` | Add a "Research Tools" section defining when agents should use Perplexity vs Context7 vs existing knowledge. Include the tool-to-activity mapping and speed-tier routing. |
| `pennyfarthing-dist/agents/dev.md` | Add research tool guidance in the agent definition — scoped lookups for dependency changes, error diagnosis. Default to `perplexity_ask`. |
| `pennyfarthing-dist/agents/tea.md` | Add research tool guidance — test pattern discovery, framework capability checks via `perplexity_ask` and `perplexity_reason`. |
| `pennyfarthing-dist/agents/reviewer.md` | Add research tool guidance — best practice verification, CVE/vulnerability checks during code review via `perplexity_ask`. |
| `pennyfarthing-dist/agents/architect.md` | Add research tool guidance — technology evaluation, trade-off analysis via `perplexity_research` and `perplexity_reason`. |
| `pennyfarthing-dist/agents/tech-writer.md` | Add research tool guidance — fact verification, external API reference checks via `perplexity_ask`. |

### Key Files to Consume (Read-Only)

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/agents/*.md` | All agent definitions — understand current structure before adding research sections |
| `pennyfarthing-dist/guides/agent-coordination.md` | Shared behavior guide — understand existing patterns to integrate with |
| `pennyfarthing-dist/schemas/skill-schema.md` | Skill file structure if a `/research` wrapper skill is added |
| `.pennyfarthing/sidecars/` | Agent learning file structure for potential research audit trail |

### Patterns to Follow

- **Tool-to-activity mapping:** Each agent gets specific Perplexity tools for specific activities, not blanket access
- **Speed-tiered routing:** Default to `perplexity_ask` (fast, cheap). Escalate to `perplexity_research` only when `ask` gives insufficient results. Never start with the 30-second tool.
- **Trust but verify:** Perplexity output informs decisions but is never treated as ground truth. The codebase is ground truth. Agents must verify Perplexity claims against actual code before implementing.
- **Citation discipline:** Any decision informed by Perplexity gets a citation in the session file or commit message — source URL or search query used.
- **Scoped queries:** Queries must relate to the active story or task. No open-ended browsing.
- **Graceful degradation:** If Perplexity is unavailable (MCP server down, rate limited, timeout), agents proceed with existing knowledge and note the gap. Never block on a web search.

### Tool Routing Table

| Perplexity Tool | Speed | Best For | Primary Agents |
|----------------|-------|----------|----------------|
| `perplexity_search` | Fast | Finding URLs, changelogs, release notes | Dev, TEA |
| `perplexity_ask` | Fast | Quick factual Q&A, "does X support Y?" | All agents (default) |
| `perplexity_research` | Slow (30s+) | Deep multi-source investigation | Architect, BA |
| `perplexity_reason` | Medium | Step-by-step analysis, trade-off comparison | TEA, Architect |

### What NOT to Touch

- Agent activation/prime flow — research tools are additive guidance, not new activation steps
- Workflow YAML definitions — no new phases or gates for research
- Hook system — no new hooks for research
- Subagent definitions — subagents (haiku) should NOT use Perplexity (cost/speed)
- Context7 integration — that's 136-19's scope

## Scope Boundaries

**In scope:**
- "Research Tools" section in agent-coordination guide with tool mapping, routing rules, and citation requirements
- Per-agent research guidance added to 5-6 agent definitions (dev, tea, reviewer, architect, tech-writer, optionally pm/ba)
- Speed-tier routing policy (ask → search → reason → research escalation)
- Graceful degradation guidance (Perplexity unavailable fallback)
- Citation discipline requirements
- Tests verifying agent definitions contain research guidance sections

**Out of scope:**
- Context7 integration (136-19)
- A `/research` wrapper skill — evaluate during implementation, but not required for MVP
- Research audit trail / sidecar logging — future enhancement
- Auto-research on error (wild card from brainstorm — future story)
- Rate limiting / usage budgets / caching layer — operational concern for later
- Per-session Perplexity call quotas
- Changes to MCP server configuration (already configured)

## AC Context

### AC1: Agent coordination guide has Research Tools section

**Given** the agent-coordination guide at `pennyfarthing-dist/guides/agent-coordination.md`
**When** a developer reads the guide
**Then** there is a "Research Tools" section that includes:
- Tool-to-activity mapping table (which tool for which task)
- Speed-tier routing guidance (default to `perplexity_ask`, escalate as needed)
- Citation requirements (how to record Perplexity-sourced decisions)
- Graceful degradation policy (what to do when Perplexity is unavailable)
- Scope restriction (queries must relate to active work)

**Verification:** Read the guide and confirm all five subsections are present with actionable guidance, not vague platitudes.

### AC2: Dev agent definition includes research guidance

**Given** the dev agent definition at `pennyfarthing-dist/agents/dev.md`
**When** the Dev agent is activated
**Then** it has guidance on using `perplexity_ask` for dependency lookups and `perplexity_search` for changelog/release note discovery
**And** the guidance explicitly states NOT to use `perplexity_research` (too slow for implementation work)

**Edge cases:**
- Dev working on a trivial 1-point story — research guidance should be proportional, not a 30-second web search for a typo fix
- Dev encountering an unfamiliar error — `perplexity_ask` with the error message is appropriate

### AC3: TEA agent definition includes research guidance

**Given** the TEA agent definition at `pennyfarthing-dist/agents/tea.md`
**When** the TEA agent is designing tests
**Then** it has guidance on using `perplexity_ask` for test pattern discovery and `perplexity_reason` for analyzing complex testing strategies
**And** the guidance includes the "trust but verify" principle — never assume a Perplexity-suggested test approach works without running it

### AC4: Reviewer agent definition includes research guidance

**Given** the reviewer agent definition at `pennyfarthing-dist/agents/reviewer.md`
**When** the Reviewer agent is reviewing code
**Then** it has guidance on using `perplexity_ask` to verify best practices and check for known vulnerabilities in patterns it encounters
**And** the guidance scopes this to "when something looks suspicious" not "for every line of code"

### AC5: Architect agent definition includes research guidance

**Given** the architect agent definition at `pennyfarthing-dist/agents/architect.md`
**When** the Architect agent is evaluating technology choices
**Then** it has guidance on using `perplexity_research` for deep investigation and `perplexity_reason` for structured trade-off analysis
**And** the Architect is the only agent with explicit permission to use the slow `perplexity_research` tool

### AC6: Graceful degradation when Perplexity unavailable

**Given** the Perplexity MCP server is unavailable or returns errors
**When** any agent attempts to use a Perplexity tool
**Then** the agent proceeds with existing knowledge and notes "Perplexity unavailable — proceeding with training data" in its assessment
**And** does NOT block, retry in a loop, or ask the user to fix MCP configuration

**Verification:** The graceful degradation policy is documented in the agent-coordination guide and referenced from each agent's research section.

### AC7: Subagents excluded from Perplexity usage

**Given** subagent definitions (sm-setup, sm-finish, testing-runner, reviewer-preflight, tandem-backseat)
**When** reviewing their definitions
**Then** none reference or encourage Perplexity tool usage
**And** the agent-coordination guide explicitly states subagents (haiku model) should not use Perplexity tools

**Rationale:** Subagents run on haiku for cost/speed. Adding web search calls to mechanical tasks defeats the purpose.
