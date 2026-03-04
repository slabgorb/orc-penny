# Session: MSSCI-16050 — Unified Research Tools section in agent-coordination guide

## Story
- **ID:** 136-21 / MSSCI-16050
- **Epic:** 136 — Post-install reliability — fix consumer-facing bugs from Python-first migration
- **Title:** Unified Research Tools section in agent-coordination guide
- **Points:** 2
- **Priority:** p2
- **Workflow:** tdd (SM → TEA → Dev → Reviewer → SM)
- **Assigned to:** keith.avery@1898andco.io

## Context
This story unifies guidance from Stories 136-19 (Context7 API) and 136-20 (Perplexity MCP) into a single Research Tools section in the agent-coordination guide. After those stories land independently, this story consolidates their contributions into a coherent decision framework with:
- A unified decision tree ("which tool do I use?")
- A single routing table covering all six research tools (Context7, Perplexity ask/reason/research/search)
- Shared principles (citation, degradation, scope, subagent exclusion)
- Per-agent research profiles replacing any duplicate sections

## Acceptance Criteria
- [ ] Single unified "Research Tools" section exists in agent-coordination guide (exactly one, not two separate sections)
- [ ] Unified routing table with clear first-choice tool and escalation path for all common information needs
- [ ] Shared principles (citation, degradation, scope, trust-but-verify, subagent exclusion) documented once and referenced
- [ ] Per-agent research profiles consolidated in dev, tea, reviewer, architect, tech-writer agent files
- [ ] No gaps or contradictions in routing table
- [ ] Implementation handles all landing order scenarios (both landed, one landed, neither landed)

## Key Files to Modify
- `pennyfarthing-dist/guides/agent-coordination.md` — unified Research Tools section with decision tree and routing table
- `pennyfarthing-dist/agents/dev.md` — consolidated research guidance XML section
- `pennyfarthing-dist/agents/tea.md` — consolidated research guidance XML section
- `pennyfarthing-dist/agents/reviewer.md` — consolidated research guidance XML section
- `pennyfarthing-dist/agents/architect.md` — consolidated research guidance XML section
- `pennyfarthing-dist/agents/tech-writer.md` — consolidated research guidance XML section

## Phase: review

## Notes
- Context7 API: `query-docs` method for library-specific documentation
- Perplexity MCP tools: `ask` (fast factual), `reason` (chain-of-thought), `research` (deep multi-source), `search` (web discovery)
- Order-independent: story must work whether 136-19, 136-20, or both have already landed
- Subagents must remain excluded from research tools

---

## SM Assessment

**Story:** 136-21 — Unified Research Tools section in agent-coordination guide
**Routing:** TDD workflow → TEA (Leeloo) for test design
**Scope:** 2-point documentation consolidation — merges Context7 and Perplexity guidance from stories 136-19 and 136-20 into a single Research Tools section in the agent-coordination guide, plus per-agent research profiles in 5 agent definition files.
**Risk:** Low — documentation-only changes to markdown files. Must handle landing-order independence (both/one/neither prerequisite story may have landed).
**Key constraint:** Subagents remain excluded from research tools. No code changes — markdown only.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Story context explicitly requires structural verification of unification invariants

**Test Files:**
- `pennyfarthing/tests/python/test_unified_research_tools.py` — 38 tests across 7 test classes

**Tests Written:** 38 tests covering 5 ACs
**Status:** RED (2 failing, 36 passing — ready for Dev)

**Failing tests:**
1. `test_graceful_degradation_not_duplicated` — "Graceful degradation" appears as bold heading 3x (Context7 subsection, Perplexity subsection, shared principles). Should appear 1x in shared principles only.
2. `test_scope_restriction_not_duplicated` — Scope restriction appears 2x with inconsistent naming ("Scope restriction" vs "Scoped queries"). Should appear 1x in shared principles.

**Dev guidance:** Consolidate the Research Tools section in `agent-coordination.md` so that shared principles (graceful degradation, scope, citation, subagent exclusion) are stated ONCE in the "Shared Principles" subsection. Per-tool subsections (Context7, Perplexity) should document tool-specific behavior only, referencing shared principles by name rather than restating them.

**Branch:** `feat/MSSCI-16050-unified-research-tools` (pennyfarthing repo, from develop)

**Handoff:** To Korben Dallas (Dev) for implementation

## Delivery Findings

### TEA (test design)
- **Improvement** (non-blocking): Per-tool subsections in Research Tools restate shared principles verbatim rather than referencing them. Affects `pennyfarthing-dist/guides/agent-coordination.md` (remove duplicated graceful degradation and scope restriction bold headings from Context7 and Perplexity subsections). *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): Context7 subsection lost explicit anti-pattern list ("Do NOT block, retry in a loop, or ask the user to fix MCP configuration") when graceful degradation was deduplicated. Shared principle covers essential behavior but is less prescriptive. Affects `pennyfarthing-dist/guides/agent-coordination.md` (consider adding anti-patterns to shared graceful degradation principle in a future story). *Found by Reviewer during code review.*

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/guides/agent-coordination.md` — removed duplicated graceful degradation from Context7 subsection, expanded Perplexity section with speed-tier routing, removed placeholder note
- `pennyfarthing-dist/agents/dev.md` — added Perplexity guidance to unified research-tools section
- `pennyfarthing-dist/agents/tea.md` — added Perplexity guidance to unified research-tools section
- `pennyfarthing-dist/agents/reviewer.md` — added Perplexity guidance to unified research-tools section
- `pennyfarthing-dist/agents/architect.md` — added Perplexity guidance to unified research-tools section
- `pennyfarthing-dist/agents/tech-writer.md` — added Perplexity guidance to unified research-tools section

**Tests:** 68/68 passing (GREEN) — 38 unified + 30 Context7 predecessor
**Branch:** `feat/MSSCI-16050-unified-research-tools` (pushed)

**Handoff:** To Jean-Baptiste Emanuel Zorg for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Agent `<research-tools>` → `guides/agent-coordination.md` → unified Research Tools section (routing table, shared principles, per-tool specifics). Chain intact.
**Pattern observed:** Shared principles deduplicated correctly — graceful degradation, scope, citation, subagent exclusion each stated once at `agent-coordination.md:437-443`
**Error handling:** Graceful degradation covers both tools with single shared principle. Per-tool subsections reference shared principle rather than restating.
**Tests:** 68/68 GREEN (38 unified + 30 Context7 predecessor)
**Observations:** 10 total — 8 VERIFIED, 1 LOW (lost anti-pattern specificity), 1 VERIFIED (test utility adequacy)
**Handoff:** To Ruby Rhod (SM) for finish

---

**Session Started:** 2026-03-04
**Setup By:** sm-setup subagent (Loc Rhod)