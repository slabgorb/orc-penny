# Story 86-14: Agent behavior: team-mode protocol

**Status:** in_progress
**Phase:** review
**Workflow:** tdd
**Jira:** PROJ-15109
**Branch:** feature/86-14-team-mode-protocol
**Repos:** pennyfarthing
**Assignee:** M. Pursifull
**Points:** 2
**Epic:** 86 — Agent Collaboration — Tandem to Teams
**Started:** 2026-02-18

---

## Context

Story 86-14 adds team-mode protocol documentation to agent behavior guides. This is part of Phase 2 (Native Teams) of the larger Epic 86 initiative to build graduated agent collaboration. Teams allow a phase agent to spawn teammates for parallel work within that phase, using SendMessage for intra-phase communication. This story documents how agents behave when they are either a team lead (spawning teammates) or a teammate (receiving work and communicating via SendMessage). Team-mode protocol builds on the earlier tandem backseat observer pattern and adds real-time parallel collaboration capability.

## Acceptance Criteria

- [ ] `agent-behavior.md` has `<team-mode>` section covering: team creation, teammate spawning, SendMessage communication, cleanup before handoff
- [ ] Lead agents know: create team on phase entry, spawn teammates per YAML, shut down teammates before exit protocol
- [ ] Teammate agents know: they're a teammate (not lead), communicate via SendMessage, go idle when done, respond to shutdown requests
- [ ] Exit protocol has team-mode branch: cleanup team THEN run normal handoff
- [ ] Reflector markers still used for inter-phase handoff (unchanged)
- [ ] SendMessage used for intra-phase teammate communication (new)

## Key Files

- `pennyfarthing-dist/guides/agent-behavior.md` — add `<team-mode>` section with team lead and teammate responsibilities
- `pennyfarthing-dist/guides/tandem-protocol.md` — reference for understanding backseat vs teammate models
- `pennyfarthing-dist/agents/dev.md` — example of lead behavior for green phase
- `pennyfarthing-dist/agents/reviewer.md` — example of lead behavior for review phase
- Epic context: `sprint/context/context-epic-86.md`

## Technical Approach

This story is documentation-focused. The task is to write comprehensive guidance for agents on team-mode behavior:

1. **Team-mode section in agent-behavior.md:** Explain the conceptual model (phase-scoped teams, lead/teammate roles, SendMessage vs markers)
2. **Team lead responsibilities:** When to create teams, how to spawn teammates from YAML config, managing teammates during the phase, graceful shutdown before exit protocol
3. **Teammate responsibilities:** Detecting team-mode activation, understanding they're not the phase lead, using SendMessage for collaboration, responding to idle checks and shutdown signals
4. **Exit protocol branching:** Document the modified exit sequence for team-mode: shutdown teammates first, then normal handoff
5. **Communication channels clarification:** Markers for inter-phase, SendMessage for intra-phase communication

The implementation of actual team lifecycle (86-10), spawn prompts (86-8), and workflow schema (86-9) is handled in parallel stories.

## TEA Assessment

**Tests Required:** No
**Reason:** Documentation-only story. All 6 ACs define content for `agent-behavior.md` (markdown guide). No code, no functions, no testable behavior. Chore bypass criteria: "Documentation updates (README, docs/)".

**Test Files:** None
**Tests Written:** 0
**Status:** BYPASS (documentation chore)

**Handoff:** To Dev for documentation implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/guides/agent-behavior.md` — Added `<team-mode>` section (team lead responsibilities, teammate responsibilities, communication channels, critical rules) and team-mode branch in exit protocol (step 2)

**Tests:** N/A (documentation-only story, TEA bypass)
**PR:** #973 — docs(agents): add team-mode protocol to agent-behavior guide
**Branch:** feature/86-14-team-mode-protocol (pushed)

**AC Coverage:**
- [x] `<team-mode>` section with team creation, spawning, SendMessage, cleanup
- [x] Lead agent guidance: TeamCreate, spawn per YAML, TeamDelete before exit
- [x] Teammate guidance: recognize role, SendMessage, go idle, respond to shutdown
- [x] Exit protocol step 2: team cleanup before tandem/gate/handoff
- [x] Reflector markers unchanged for inter-phase handoff
- [x] SendMessage documented for intra-phase communication

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] AC coverage complete — all 6 ACs map to specific sections
2. [VERIFIED] Placement correct — `<team-mode>` between tandem and reflector, XML tags clean
3. [VERIFIED] Exit protocol step 2 insertion with correct numbering through step 10
4. [MEDIUM] Session file write contradiction at line 181 — teammate point 5 says "session file or sidecar" but table says "written by lead only." Epic context warns concurrent writes corrupt. Fix: change to "sidecar" only. Non-blocking — feature not implemented yet.
5. [LOW] Forward reference to `pf detect teams` (line 107) — command doesn't exist yet (story 86-7)
6. [LOW] SendMessage `to="lead"` addressing — native teams API uses spawn names, not role strings
7. [VERIFIED] Critical safety rails on channel separation correctly scoped

**Data flow traced:** Workflow YAML `team:` block → agent detection on activation → TeamCreate → spawn teammates → SendMessage coordination → TeamDelete → normal exit protocol. Channel separation enforced by critical block.
**Pattern observed:** Documentation mirrors the tandem-protocol.md structure (detection → spawn → communication → cleanup) — consistent agent guidance pattern.
**Error handling:** Graceful fallback documented — missing prerequisites → solo execution, no error.

**Handoff:** To SM for finish-story