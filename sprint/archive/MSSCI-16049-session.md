# Story 136-20: Integrate Perplexity MCP for agent research tasks

**Jira:** MSSCI-16049
**Points:** 3
**Priority:** p2
**Workflow:** tdd
**Phase:** finish
**Status:** in_progress
**Repos:** orchestrator,pennyfarthing
**Branch:** feat/MSSCI-16049-perplexity-mcp-agent-research

## Acceptance Criteria

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

## Context

Pennyfarthing agents operate in a knowledge bubble — they know what's in their context window and nothing else. When an agent encounters an unfamiliar library API, a breaking change in a dependency, or needs to verify a best practice, it has two options: guess, or stop and ask the user. Both are bad. Guessing produces wrong code. Stopping breaks flow and burns user goodwill.

Perplexity MCP tools (`perplexity_ask`, `perplexity_search`, `perplexity_research`, `perplexity_reason`) are already available in the Claude Code environment via MCP server configuration. But zero agent definitions reference them, no guide mentions them, and no skill wraps them. They're loaded but unused.

This story teaches agents when and how to use Perplexity for scoped, cited research — without turning every implementation task into a research project. The sibling story 136-19 (Context7) handles library documentation lookups; this story covers broader knowledge needs: best practices, vulnerability checks, ecosystem changes, error diagnosis.

## Key Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing-dist/guides/agent-coordination.md` | Add a "Research Tools" section defining when agents should use Perplexity vs Context7 vs existing knowledge. Include the tool-to-activity mapping and speed-tier routing. |
| `pennyfarthing-dist/agents/dev.md` | Add research tool guidance in the agent definition — scoped lookups for dependency changes, error diagnosis. Default to `perplexity_ask`. |
| `pennyfarthing-dist/agents/tea.md` | Add research tool guidance — test pattern discovery, framework capability checks via `perplexity_ask` and `perplexity_reason`. |
| `pennyfarthing-dist/agents/reviewer.md` | Add research tool guidance — best practice verification, CVE/vulnerability checks during code review via `perplexity_ask`. |
| `pennyfarthing-dist/agents/architect.md` | Add research tool guidance — technology evaluation, trade-off analysis via `perplexity_research` and `perplexity_reason`. |
| `pennyfarthing-dist/agents/tech-writer.md` | Add research tool guidance — fact verification, external API reference checks via `perplexity_ask`. |

## Tool Routing Table

| Perplexity Tool | Speed | Best For | Primary Agents |
|----------------|-------|----------|----------------|
| `perplexity_search` | Fast | Finding URLs, changelogs, release notes | Dev, TEA |
| `perplexity_ask` | Fast | Quick factual Q&A, "does X support Y?" | All agents (default) |
| `perplexity_research` | Slow (30s+) | Deep multi-source investigation | Architect, BA |
| `perplexity_reason` | Medium | Step-by-step analysis, trade-off comparison | TEA, Architect |

## SM Assessment

**Routing:** TDD workflow → TEA (Leeloo) for red phase.

**Story shape:** Documentation-only changes across 6 agent definition files and 1 guide. No runtime code, no schema changes, no migrations. The tests will verify content presence in markdown files.

**Risk:** Low. Additive content to existing files. Sibling story 136-19 (Context7) may or may not have landed — TEA needs to check if a Research Tools section already exists in agent-coordination.md before creating one.

**Key constraint:** Subagents (haiku) must be excluded from Perplexity guidance. Speed-tier routing must default to `perplexity_ask` with explicit escalation paths.

**Branch:** `feat/MSSCI-16049-perplexity-mcp-agent-research` on pennyfarthing `develop`.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Documentation changes need content-presence validation to prevent regression

**Test Files:**
- `tests/python/test_perplexity_agent_guidance.py` — 28 tests covering all 7 ACs

**Tests Written:** 28 tests covering 7 ACs
**Status:** RED (10 failing — ready for Dev)

**Failing tests (10):**
1. Guide placeholder note for 136-20 still present
2. dev.md — no Perplexity reference
3. dev.md — no perplexity_ask as default
4. tea.md — no Perplexity reference
5. tea.md — no perplexity_ask reference
6. reviewer.md — no Perplexity reference
7. architect.md — no Perplexity reference
8. architect.md — no perplexity_research reference
9. architect.md — no perplexity_reason reference
10. tech-writer.md — no Perplexity reference

**Passing tests (18):** Guide already has speed-tier table, routing, degradation policy, subagent exclusion (from 136-19 work). Subagent exclusion tests all pass — no Perplexity leakage.

**Handoff:** To Korben Dallas (Dev) for implementation.

## Delivery Findings

### TEA (test design)

- No upstream findings during test design.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/guides/agent-coordination.md` — replaced placeholder with speed-tier routing, scope restriction, graceful degradation
- `pennyfarthing-dist/agents/dev.md` — added Perplexity guidance (perplexity_ask default, perplexity_search for changelogs, avoid perplexity_research)
- `pennyfarthing-dist/agents/tea.md` — added Perplexity guidance (perplexity_ask, perplexity_reason, trust-but-verify)
- `pennyfarthing-dist/agents/reviewer.md` — added Perplexity guidance (perplexity_ask for suspicious patterns and vulnerabilities)
- `pennyfarthing-dist/agents/architect.md` — added Perplexity guidance (perplexity_reason, perplexity_research — only agent with deep research permission)
- `pennyfarthing-dist/agents/tech-writer.md` — added Perplexity guidance (perplexity_ask for fact verification)

**Tests:** 28/28 passing (GREEN)
**Branch:** feat/MSSCI-16049-perplexity-mcp-agent-research (pushed)

**Handoff:** To Jean-Baptiste Emanuel Zorg (Reviewer) for code review

### Dev (implementation)

- No upstream findings during implementation.

## TEA Verify Assessment

**Tests:** 28/28 passing (GREEN confirmed)
**Regression:** 30/30 Context7 tests still pass — no regressions from Perplexity additions
**Coverage:** All 7 ACs verified through tests

**Implementation Quality:**
- Guide: Placeholder removed, speed-tier routing with clear escalation path, scope restriction, graceful degradation
- Agent guidance: Role-appropriate tool recommendations integrated into existing `<research-tools>` tags
- Architect correctly scoped as sole `perplexity_research` user
- Dev explicitly steered away from slow tools
- No subagent contamination (6/6 exclusion tests pass)

**Verdict:** PASS — ready for review

**Handoff:** To Jean-Baptiste Emanuel Zorg (Reviewer) for code review

### TEA (test verification)

- No upstream findings during test verification.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** Agent activation → `<research-tools>` tag → guide reference → Perplexity tool usage → assessment citation. Coherent end-to-end.
**Pattern observed:** Consistent with 136-19 (Context7) pattern — extend existing tags, reference canonical guide. All 5 agents at `pennyfarthing-dist/agents/*.md:research-tools`.
**Error handling:** Graceful degradation at `agent-coordination.md:424` — explicit "Do NOT block, retry in a loop" instruction. Matches Context7 degradation pattern.

**Observations:**
- `[VERIFIED]` All 5 target agents have Perplexity guidance with role-appropriate tool scoping
- `[VERIFIED]` Architect correctly scoped as sole `perplexity_research` user; Dev explicitly warned off
- `[VERIFIED]` Subagent exclusion: 6/6 tests pass, no Perplexity leakage
- `[VERIFIED]` 28/28 Perplexity + 30/30 Context7 regression tests GREEN
- `[VERIFIED]` Working tree clean, branch pushed
- `[LOW]` TEA test `test_trust_but_verify` has loose fallback (`"verify" in content_lower`), but primary condition is correct
- `[LOW]` `<research-tools>` tags growing — may want structured subsections if more tools are added (future concern)

**Handoff:** To Ruby Rhod (SM) for finish-story

### Reviewer (code review)

- **Improvement** (non-blocking): Consider structured subsections in `<research-tools>` tags if a third research tool is added — single-paragraph format will get unwieldy. Affects `pennyfarthing-dist/agents/*.md` (future consideration). *Found by Reviewer during code review.*

## Session Log

- 2026-03-04 — Jira claimed, story status updated to in_progress, setup complete
- SM assessment written, handing off to TEA
- TEA: 28 tests written, 10 failing (RED confirmed), committing and handing off to Dev
- Dev: 6 files changed, 28/28 tests GREEN, branch pushed
- TEA verify: 28/28 + 30/30 regression tests pass, implementation approved
- Reviewer: APPROVED — clean implementation, no blocking issues