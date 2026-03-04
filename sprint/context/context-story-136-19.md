---
parent: context-epic-136.md
workflow: tdd
---

# Story 136-19: Integrate Context7 API for automated skill documentation updates

## Business Context

Pennyfarthing agents write code against external libraries (vitest, dockview, React, Tailwind, jira-cli, shadcn, etc.) using knowledge from their training data. When a library ships a breaking change, new API, or deprecation, agents don't know — they write code against the old version, tests fail, and a simple story balloons in scope.

Context7 MCP provides two tools already available in the environment: `resolve-library-id` (maps a package name to a Context7 library ID with version info) and `query-docs` (retrieves current documentation and code examples for any library). Like Perplexity (136-20), these tools are loaded but unused — no agent definition, guide, or skill references them.

This story teaches agents when and how to use Context7 for precise, library-specific documentation lookups. Context7 is the *scalpel* — you know which library, you need its current docs. This complements Perplexity (136-20), which is the *search engine* for broader knowledge. Together they form the agent research capability, but each story delivers independently.

**Scope note:** The title mentions "automated skill documentation updates" — that aspiration (batch verification of skill docs against external reality) is a future capability. This story delivers the foundation: agent guidance for on-demand Context7 lookups during implementation.

## Technical Guardrails

### Key Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing-dist/guides/agent-coordination.md` | Add Context7 to the "Research Tools" section (created by 136-20, or create it here if 136-19 lands first). Define the two-step lookup pattern: `resolve-library-id` → `query-docs`. Include Context7 vs Perplexity routing guidance. |
| `pennyfarthing-dist/agents/dev.md` | Add Context7 guidance — use `query-docs` when implementing against external libraries. Default lookup path: resolve library ID first, then query with specific question. |
| `pennyfarthing-dist/agents/tea.md` | Add Context7 guidance — verify API surfaces and test helper availability before writing test assertions. |
| `pennyfarthing-dist/agents/reviewer.md` | Add Context7 guidance — verify imports, API usage, and deprecation status during code review. |
| `pennyfarthing-dist/agents/architect.md` | Add Context7 guidance — evaluate library capabilities and version compatibility during design. |
| `pennyfarthing-dist/agents/tech-writer.md` | Add Context7 guidance — verify external API references and CLI flags when writing documentation. |

### Key Files to Consume (Read-Only)

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/agents/*.md` | All agent definitions — understand current structure before adding Context7 sections |
| `pennyfarthing-dist/guides/agent-coordination.md` | Shared behavior guide — may already have Research Tools section from 136-20 |
| `pennyfarthing-dist/skills/*/skill.md` | Understand skill frontmatter format for future `depends_on` field (not this story, but inform the design) |

### Patterns to Follow

- **Two-step lookup:** Always `resolve-library-id` first, then `query-docs`. Never call `query-docs` without a valid library ID.
- **Specific queries:** "How to configure vitest reporters" not "vitest documentation". Context7 rewards precision.
- **Context7 for libraries, Perplexity for everything else:** If you know the package name and need its API docs → Context7. If you have a general question or need best practices → Perplexity (136-20).
- **Three-call limit:** Context7 docs state "do not call this tool more than 3 times per question." Agent guidance must respect this — resolve once, query up to twice.
- **Trust but verify:** Context7 provides official docs, but always run the code. Docs can lag behind actual library behavior.
- **Graceful degradation:** If Context7 MCP is unavailable, proceed with training data knowledge. Note the gap but don't block.
- **Internal tool carve-out:** Context7 indexes external/public libraries. Internal tools (`pf` CLI, custom packages) are NOT in Context7. Don't try to look them up.

### Context7 vs Perplexity Routing

| Need | Tool | Why |
|------|------|-----|
| Current API signature for a specific library | Context7 `query-docs` | Precise, structured library docs |
| "Does library X support feature Y?" | Context7 `query-docs` | Library-specific capability check |
| Best practice for a general pattern | Perplexity `perplexity_ask` | Broad knowledge, not library-specific |
| Comparing two libraries | Perplexity `perplexity_reason` | Cross-library analysis |
| Finding a library for a task | Perplexity `perplexity_search` | Discovery, not docs |
| Checking for known vulnerabilities | Perplexity `perplexity_ask` | Security advisories are web content |

### What NOT to Touch

- Agent activation/prime flow — Context7 guidance is additive, not a new activation step
- Workflow YAML definitions — no new phases or gates
- Hook system — no new hooks
- Subagent definitions — haiku subagents should NOT use Context7 (same rationale as 136-20)
- Skill frontmatter schema — `depends_on` field is future work, not this story
- Automated verification/batch jobs — future capability, not this story
- Perplexity integration — that's 136-20's scope (though the routing table covers both)

## Scope Boundaries

**In scope:**
- Context7 section in agent-coordination guide's Research Tools area (or create the Research Tools section if 136-20 hasn't landed)
- Two-step lookup pattern documentation (`resolve-library-id` → `query-docs`)
- Context7 vs Perplexity routing guidance
- Per-agent Context7 guidance in 5-6 agent definitions (dev, tea, reviewer, architect, tech-writer)
- Three-call-per-question limit enforcement in guidance
- Graceful degradation when Context7 unavailable
- Tests verifying agent definitions contain Context7 guidance sections

**Out of scope:**
- Perplexity integration (136-20)
- Automated skill documentation verification / batch freshness checks
- Skill frontmatter `depends_on` declarations
- Library ID mapping registry
- Documentation freshness timestamps or metadata
- Auto-PR for stale docs
- Changes to MCP server configuration (already configured)

## AC Context

### AC1: Agent coordination guide has Context7 documentation in Research Tools section

**Given** the agent-coordination guide at `pennyfarthing-dist/guides/agent-coordination.md`
**When** a developer reads the Research Tools section
**Then** there is Context7 guidance that includes:
- The two-step lookup pattern (`resolve-library-id` → `query-docs`)
- Context7 vs Perplexity routing table (which tool for which need)
- Three-call-per-question limit
- Internal tool carve-out (Context7 is for external libraries only)
- Graceful degradation policy

**Verification:** Read the guide and confirm all subsections present. If 136-20 landed first, Context7 guidance is added to the existing Research Tools section. If 136-19 lands first, the Research Tools section is created with Context7 content and a placeholder note for Perplexity.

### AC2: Dev agent definition includes Context7 guidance

**Given** the dev agent definition at `pennyfarthing-dist/agents/dev.md`
**When** the Dev agent is implementing against an external library
**Then** it has guidance to use `resolve-library-id` + `query-docs` for current API documentation
**And** the guidance specifies when to look up vs when to trust training data (new library, version uncertainty, unfamiliar API)

**Edge cases:**
- Dev working with an internal package (`@pennyfarthing/core`) — guidance explicitly says don't try Context7 for internal packages
- Dev working with a very common pattern (e.g., `fs.readFile`) — no need to look up stdlib

### AC3: TEA agent definition includes Context7 guidance

**Given** the TEA agent definition at `pennyfarthing-dist/agents/tea.md`
**When** the TEA agent is writing tests that interact with external libraries
**Then** it has guidance to verify test helper APIs and assertion patterns via `query-docs`
**And** includes the "trust but verify" principle — run the test even if Context7 confirms the API

### AC4: Reviewer agent definition includes Context7 guidance

**Given** the reviewer agent definition at `pennyfarthing-dist/agents/reviewer.md`
**When** the Reviewer encounters imports or API usage from external libraries
**Then** it has guidance to spot-check suspicious patterns with `query-docs` (deprecated APIs, changed signatures)
**And** scopes this to "when something looks off" not "verify every import"

### AC5: Architect and Tech-Writer agent definitions include Context7 guidance

**Given** the architect and tech-writer agent definitions
**When** these agents need current library documentation
**Then** each has role-appropriate Context7 guidance:
- Architect: evaluate library capabilities, version compatibility, API design quality
- Tech-Writer: verify external references, CLI flags, API examples in documentation

### AC6: Graceful degradation when Context7 unavailable

**Given** the Context7 MCP server is unavailable or `resolve-library-id` returns no matches
**When** any agent attempts a Context7 lookup
**Then** the agent proceeds with training data knowledge and notes "Context7 unavailable — using training data" in its work
**And** does NOT block, retry in a loop, or ask the user to fix MCP configuration

**Edge case:** `resolve-library-id` returns results but `query-docs` fails — agent uses the library ID information (name, description, snippet count) as a signal even without full docs.

### AC7: Subagents excluded from Context7 usage

**Given** subagent definitions (sm-setup, sm-finish, testing-runner, reviewer-preflight, tandem-backseat)
**When** reviewing their definitions
**Then** none reference or encourage Context7 tool usage
**And** the agent-coordination guide explicitly states subagents (haiku model) should not use Context7 tools

**Rationale:** Same as 136-20 — subagents run on haiku for cost/speed. MCP round-trips on mechanical tasks are waste.

### AC8: Context7 and Perplexity routing is coherent

**Given** both 136-19 and 136-20 may land in either order
**When** the Research Tools section in agent-coordination guide is complete
**Then** there is a single, unified routing table showing when to use Context7 vs Perplexity
**And** the table is consistent regardless of which story landed first

**Verification:** If only one story has landed, the section includes a placeholder for the other tool. When both land, the routing table is complete.
