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
inputDocuments: []
workflowType: 'prd'
documentCounts:
  briefCount: 0
  researchCount: 1
  brainstormingCount: 0
  projectDocsCount: 5
classification:
  projectType: CLI Tool / Developer Tooling
  domain: Developer Experience (DX) / Build Infrastructure
  complexity: Medium
  projectContext: brownfield
---

# Product Requirements Document - Native Subagent Migration

**Author:** Keith Avery
**Date:** 2026-03-12
**Source:** [GitHub Issue #1332](https://github.com/slabgorb/pennyfarthing/issues/1332)
**Classification:** CLI Tool / Developer Tooling | DX / Build Infrastructure | Medium complexity | Brownfield

## Executive Summary

Migrate all Pennyfarthing agent personas from in-conversation persona switching to native Claude Code subagents (`.claude/agents/*.md`), giving each agent an isolated context window with role-specific tool restrictions. SM remains the main conversation orchestrator, spawning 10 agents as subagents. This eliminates context exhaustion on multi-phase story cycles and enables unlimited fix round-trips without degradation — addressing the #1 friction source (150 wrong-approach events across 622 sessions).

## Success Criteria

### User Success

- Agents never inherit stale context from prior phases — each starts from source of truth (sprint YAML, story spec, branch state)
- Return fix loops (Reviewer→Dev→Reviewer) work without degradation regardless of cycle count
- Fewer manual interventions needed to complete a full story cycle
- Zero persona confusion events — wrong agent behavior never bleeds into wrong phase

### Business Success

- Wrong-approach friction events drop by >50% (from 150/622 sessions baseline)
- Full story cycles complete without context exhaustion events
- Round-trip fix cycles don't require conversation restarts
- Developer experience improvement measurable through session completion rates

### Technical Success

- SM remains the main conversation agent — orchestrates spawning of all others
- 10 agents (TEA, Dev, Reviewer, Architect, PM, Tech Writer, UX Designer, DevOps, Orchestrator, BA) run as native Claude Code subagents in isolated context windows
- Each agent gets full context budget dedicated to its phase
- Handoff documents define the complete contract between phases (no implicit context dependency)
- Tool restrictions enforced per role (e.g., Reviewer = read-only)
- PreToolUse hooks block pushes to protected branches (main, develop)
- Existing PF orchestration (sprint, bmad, session) unchanged

### Measurable Outcomes

- Context utilization at phase start: <20% (vs. current 60-80% by Reviewer phase)
- Story cycles supporting 3+ Reviewer→Dev round-trips without degradation
- Zero persona confusion events (wrong agent behavior in wrong phase)
- No conversation restarts required due to context exhaustion during normal story flow

## Product Scope

### MVP (Phase 1) — The Migration

- All 10 non-SM agents defined as `.claude/agents/*.md` with appropriate tool restrictions
- PF activation skills (`/pf-dev`, `/pf-tea`, etc.) spawn native subagents with story context injected
- Handoff document contract between phases — defines what each agent receives and produces
- SM stays as main conversation, spawns subagents via handoff protocol
- Gate enforcement works with subagent isolation model
- PreToolUse hooks for branch protection
- Existing phased workflows, Tandem, and Team mode preserved
- Validated on at least one full story cycle (TEA→Dev→Reviewer with fix round-trip)

### Phase 2 — New Capabilities

- Intra-phase delegation (Reviewer spawns Dev for lint fix, Dev spawns TEA for test changes)
- `isolation: worktree` for clean git state per agent
- Context budget telemetry surfaced in BikeRack
- Handoff document quality scoring (did the contract contain everything the next agent needed?)
- Subagent-aware session archives — track per-agent context usage

### Phase 3 — Vision

- Automatic context budget monitoring and alerting
- Self-healing fix loops that retry without human intervention
- Adaptive handoff documents that learn what context each agent actually uses

### Risk Mitigation

- **Technical risk:** Claude Code's `.claude/agents/*.md` format is new and evolving. Mitigated by staying at cutting edge and adapting fast — not waiting for stability.
- **Migration risk:** Breaking existing workflows during conversion. Mitigated by validating on a full story cycle before declaring MVP complete.
- **Scope risk:** Intra-phase delegation deferred to Phase 2 to keep MVP focused on the core value (context isolation).

## User Journeys

### Journey 1: Full TDD Story Cycle (Happy Path)

User starts with `/pf-sm`, picks a story from the backlog. SM sets up the session and spawns TEA as a native subagent. TEA gets a fresh context with just the story spec, relevant code, and its agent definition. It designs failing tests, writes them, produces a handoff document summarizing what it built and why. TEA's context closes. SM spawns Dev with TEA's handoff. Dev gets a clean window — the tests, the spec, nothing else. Implements until green. Produces its own handoff. SM spawns Reviewer. Reviewer gets Dev's handoff plus the diff. Full context budget for deep analysis. Approves. SM finishes the story.

**Today:** By Reviewer phase, context is at 70%+. Reviewer rushes, misses things. User restarts conversations mid-story.

### Journey 2: Fix Round-Trip

Reviewer finds 3 issues, writes them into a findings document. SM spawns a fresh Dev with just the findings and relevant files. Dev fixes all three. SM spawns Reviewer again — fresh context, just the new diff and prior findings. Confirms fixes. This can repeat 3, 4, 5 times without degradation.

**Today:** Second round-trip often hits context ceiling. User manually restarts conversation, re-explains context, loses momentum.

### Journey 3: Workflow Switch Mid-Story

User is in a TDD cycle but realizes they need the Architect for a design decision. SM spawns Architect as a subagent with the story context. Architect produces a recommendation. SM feeds it into the next Dev spawn. No context pollution — the architectural detour doesn't eat into Dev's budget.

### Journey Requirements Summary

- Handoff documents must be self-contained contracts (no implicit context dependency)
- SM must be able to spawn any agent at any point in a workflow
- Each spawn starts from source of truth + handoff document, nothing else
- Multiple round-trips must work without degradation
- Single user, personal tool — no multi-tenant, admin, or support journeys needed

## Agent Architecture

### Agent Definition Conversion

Convert existing `pennyfarthing-dist/agents/*.md` definitions to `.claude/agents/*.md` format. Existing agent definitions are the source — no new agent behavior is being designed, only the execution model changes.

### Tool Restrictions Per Role

| Agent | Write Code | Write Tests | Read | Bash | Notes |
|-------|-----------|-------------|------|------|-------|
| TEA | No | Yes | Yes | Yes | Test files only |
| Dev | Yes | No | Yes | Yes | Code only, not tests |
| Reviewer | No | No | Yes | Limited | Read-only analysis |
| Architect | No | No | Yes | Limited | Design docs, ADRs |
| PM | No | No | Yes | Limited | Planning docs |
| Tech Writer | No | No | Yes | Yes | Documentation only |
| UX Designer | No | No | Yes | Limited | Design artifacts |
| DevOps | Yes | No | Yes | Yes | Infrastructure, CI/CD |
| Orchestrator | No | No | Yes | Yes | Meta-operations |
| BA | No | No | Yes | Limited | Requirements docs |

### Intra-Phase Delegation

Agents can spawn other agents ad-hoc within their phase when they need help outside their permissions:
- Reviewer finds lint issue → spawns Dev subagent for quick fix
- Dev needs test expectations changed → spawns TEA subagent
- Same rules as current Tandem and Team mode, different mechanism (isolated subagent vs. shared context)

### Spawning Model

Works with existing phased workflows. SM triggers handoffs per phase ownership. Gate enforcement, phase transitions, and handoff documents are preserved. The mechanism changes from in-conversation persona switching to native subagent spawning — same rules, different execution model.

### Relationship to Tandem and Team Mode

Tandem (backseat observer) and Team (multi-agent collaboration) patterns overlap with intra-phase delegation. The distinction: Tandem/Team are structured workflow pairings defined in workflow YAML. Intra-phase delegation is ad-hoc — an agent decides at runtime it needs help. Both patterns benefit from isolated context windows.

## Functional Requirements

### Agent Definition & Conversion

- FR1: SM can spawn any of the 10 non-SM agents as native Claude Code subagents
- FR2: Each agent definition includes role-specific tool restrictions (read/write/execute permissions)
- FR3: Each agent definition includes its persona from the active theme
- FR4: Agent definitions are converted from existing `pennyfarthing-dist/agents/*.md` to `.claude/agents/*.md` format

### Context Isolation

- FR5: Each spawned agent starts with a fresh context window containing only its agent definition, story context, and handoff document
- FR6: No conversational state from prior phases carries into a new agent spawn
- FR7: Multiple sequential spawns of the same agent role (e.g., Dev→Reviewer→Dev→Reviewer) each get independent context windows

### Handoff & Phase Transitions

- FR8: SM can pass a handoff document to a spawned agent containing the prior phase's output
- FR9: Each agent produces a structured handoff document at phase completion for the next agent
- FR10: Gate enforcement validates phase completion before allowing transition to next phase
- FR11: Existing phased workflow definitions (TDD, trivial, BDD, etc.) work without modification

### Tool Restrictions

- FR12: TEA can write/edit test files but cannot modify production code
- FR13: Dev can write/edit production code but cannot modify test files
- FR14: Reviewer can read all files but cannot write or edit any files
- FR15: Each agent's tool restrictions are enforced by Claude Code's native `tools` allowlist

### Branch Protection

- FR16: PreToolUse hooks block pushes to protected branches (main, develop)
- FR17: Branch protection rules are configured per-repo using existing `repos.yaml` topology

### Workflow Compatibility

- FR18: Tandem mode (backseat observer pairing) works with native subagents
- FR19: Team mode (multi-agent collaboration) works with native subagents
- FR20: PF activation skills (`/pf-dev`, `/pf-tea`, etc.) spawn native subagents instead of switching personas in-conversation
- FR21: SM orchestration (session setup, story finish, sprint commands) remains unchanged

## Non-Functional Requirements

### Performance

- Handoff documents must be compact enough to leave >80% of context budget for the agent's actual work
- Context isolation must not add meaningful latency to agent spawning beyond Claude Code's native subagent overhead

### Compatibility

- All existing phased workflows (TDD, trivial, BDD, agent-docs, etc.) must work without modification after migration
- Gate enforcement, Tandem mode, and Team mode must function with native subagents
- Existing PF CLI commands (`pf sprint`, `pf handoff`, `pf workflow`) require no changes

### Reliability

- A spawned agent must always receive its complete handoff document — partial or missing handoffs are a hard failure
- If a subagent spawn fails, SM must detect the failure and report it (not silently proceed)

### Observability

- BikeRack TUI portrait panel must track the current active agent across subagent transitions
- SM emits agent change events to WheelHub *before* spawning each subagent — the TUI updates from SM's event, not the subagent's
- Subagents do not need awareness of the TUI; observability is SM's responsibility
