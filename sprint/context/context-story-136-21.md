---
parent: context-epic-136.md
workflow: tdd
---

# Story 136-21: Unified Research Tools section in agent-coordination guide

## Business Context

Stories 136-19 (Context7) and 136-20 (Perplexity) each add tool-specific guidance to agents independently. They can land in either order, and each creates or extends a "Research Tools" section in the agent-coordination guide. But the real value emerges when both tools are documented together in a single, coherent decision framework: "I need information — which tool do I reach for?"

This story is the integration layer. After 136-19 and 136-20 land, this story unifies their guidance into a single Research Tools section with a definitive routing table, shared principles, and per-agent research profiles that cover both tools. It resolves any inconsistencies between the two independently-authored sections and ensures agents have one place to look, not two.

Without this story, agents get two separate "when to use X" guides that may overlap, contradict, or leave gaps. With it, they get a single decision tree: Context7 for library docs, Perplexity for broader knowledge, training data for everything else.

## Technical Guardrails

### Key Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing-dist/guides/agent-coordination.md` | Unify the Research Tools section into a single coherent block: decision tree, unified routing table, shared principles (citation, degradation, scope), per-tool specifics. Remove any duplication between 136-19 and 136-20 contributions. |
| `pennyfarthing-dist/agents/dev.md` | Consolidate research guidance into a single `<research-tools>` XML section covering both Context7 and Perplexity with role-specific routing. |
| `pennyfarthing-dist/agents/tea.md` | Same consolidation — unified research section. |
| `pennyfarthing-dist/agents/reviewer.md` | Same consolidation — unified research section. |
| `pennyfarthing-dist/agents/architect.md` | Same consolidation — unified research section. |
| `pennyfarthing-dist/agents/tech-writer.md` | Same consolidation — unified research section. |

### Patterns to Follow

- **Single decision tree:** Agent encounters an information need → Is it about a specific library? → Yes: Context7. No: Is it a factual question? → Yes: Perplexity `ask`. Need deep analysis? → Perplexity `reason` or `research`.
- **Shared principles across both tools:** Citation discipline, graceful degradation, scoped queries, trust-but-verify, subagent exclusion. These apply identically to both tools — document once, reference everywhere.
- **Per-agent research profiles:** Each agent gets a compact section listing which tools they use, for what, and with what limits. Not two separate sections (one for Context7, one for Perplexity) but one unified section.
- **Order independence:** This story must work regardless of whether 136-19, 136-20, or both have landed. If only one has landed, this story adds the other and unifies. If both have landed, this story consolidates.

### Unified Routing Table (target state)

| Information Need | First Try | Escalate To | Never Use |
|-----------------|-----------|-------------|-----------|
| Current API signature for known library | Context7 `query-docs` | Perplexity `ask` | `perplexity_research` |
| Does library X support feature Y? | Context7 `query-docs` | Perplexity `ask` | — |
| Best practice for a general pattern | Perplexity `ask` | `perplexity_reason` | Context7 (not library-specific) |
| Comparing two technologies | Perplexity `reason` | `perplexity_research` (Architect only) | Context7 (single-library tool) |
| Finding a library for a task | Perplexity `search` | `perplexity_ask` | Context7 (need name first) |
| Known vulnerabilities / CVEs | Perplexity `ask` | `perplexity_search` | Context7 (not security-focused) |
| Error diagnosis (unfamiliar error) | Perplexity `ask` | Context7 if library-specific | `perplexity_research` |
| Internal tool documentation (`pf` CLI) | Training data / skill docs | — | Context7 or Perplexity (not indexed) |

### What NOT to Touch

- MCP server configuration — both tools are already configured
- Workflow YAML — no new phases or gates
- Hook system — no new hooks
- Subagent definitions — remain excluded from research tools
- Skill frontmatter schema — `depends_on` is future work
- Automated verification / batch jobs — future capability

## Scope Boundaries

**In scope:**
- Unified Research Tools section in agent-coordination guide with single decision tree and routing table
- Consolidated per-agent research profiles replacing any separate Context7/Perplexity sections
- Shared principles block (citation, degradation, scope, trust-but-verify, subagent exclusion)
- Resolution of any duplication or inconsistency between 136-19 and 136-20 contributions
- Tests verifying unified structure exists and is internally consistent

**Out of scope:**
- Adding new tool capabilities beyond what 136-19 and 136-20 deliver
- `/research` wrapper skill
- Automated documentation verification
- Research audit trail / sidecar logging
- Rate limiting / usage budgets
- Any new agent definitions or subagent changes

## AC Context

### AC1: Single unified Research Tools section exists

**Given** the agent-coordination guide has received contributions from 136-19 and/or 136-20
**When** this story completes
**Then** there is exactly ONE "Research Tools" section (not two separate ones) containing:
- A decision tree for "which tool do I use?"
- A unified routing table covering all six Perplexity + Context7 tools
- Shared principles that apply to both tools
- Per-tool specifics (Context7 two-step pattern, Perplexity speed tiers)

**Verification:** Grep for "Research Tools" in agent-coordination.md — exactly one heading match. No separate "Context7" and "Perplexity" top-level sections.

### AC2: Per-agent research profiles are consolidated

**Given** agent definitions may have separate research guidance from 136-19 and 136-20
**When** this story completes
**Then** each agent (dev, tea, reviewer, architect, tech-writer) has ONE research section covering both tools
**And** the section uses a compact format: "For X, use Context7. For Y, use Perplexity. Never use Z."

**Verification:** Each agent file has at most one research-related XML section or markdown heading.

### AC3: Routing table has no gaps or contradictions

**Given** the unified routing table in the agent-coordination guide
**When** an agent encounters any common information need
**Then** the table provides a clear first-choice tool and escalation path
**And** no two rows recommend the same tool for contradictory reasons

**Edge cases:**
- Library-specific question that Context7 can't answer (library not indexed) — table should route to Perplexity as fallback
- Question that could be either library-specific or general — table should default to Context7 first (more precise)

### AC4: Shared principles documented once

**Given** both Context7 and Perplexity share common principles (citation, degradation, scope, subagent exclusion)
**When** reading the Research Tools section
**Then** these principles are stated ONCE in a shared subsection, not duplicated per tool

**Verification:** Search for "graceful degradation" — appears once in the shared principles, not twice.

### AC5: Works regardless of landing order

**Given** this story may land before, after, or between 136-19 and 136-20
**When** the implementation runs
**Then** it handles all three scenarios:
- Both already landed → consolidate and deduplicate
- Only one landed → add the missing tool and unify
- Neither landed → create the complete unified section from scratch

**Verification:** The implementation checks what exists before modifying, not assuming a specific prior state.
