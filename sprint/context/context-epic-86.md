# Epic 86: Agent Collaboration — Tandem to Teams

## Overview

Build a graduated agent collaboration system for Pennyfarthing, starting with Tandem consultation (ADR-0012) as the foundation and layering Claude Code's native Agent Teams as an optional upgrade for interactive users.

**Three tiers of agent collaboration:**

```
Tier 1: Subagents        Tier 2: Tandem           Tier 3: Native Teams
(existing)               (this epic, Phase 1)     (this epic, Phase 2)
─────────────────────────────────────────────────────────────────────
Fire-and-forget           Structured Q&A           Parallel sessions
Haiku, <1K tokens         Sonnet, capped budget    Full context windows
No communication          Request/response         Free-form messaging
-p compatible             -p compatible             Interactive only
```

**Prior art:**
- ADR-0012: Tandem Agent Pairing (proposed 2026-01-23)
- PRD: `artifacts/prd-tandem.md` (completed 2026-01-23)
- Claude Code Agent Teams docs: `code.claude.com/docs/en/agent-teams`

## Background

### The Problem

Pennyfarthing workflows are strictly sequential (SM → TEA → Dev → Reviewer). Complex stories suffer because:
- Dev can't ask Architect a design question without a full handoff round-trip
- TEA can't check implementation constraints with Dev mid-test-writing
- Reviewer can't get Architect's take on a pattern without restarting the pipeline

### The Solution Spectrum

ADR-0012 proposed **Tandem** — mid-phase consultation via subagents. Claude Code now ships **native Agent Teams** — full parallel sessions with messaging. These aren't competing; they're complementary tiers on a collaboration spectrum.

| Need | Right Tool |
|------|------------|
| "Quick question for Architect" | Tandem consultation |
| "TEA and Architect explore in parallel" | Native team |
| "3 reviewers with different focus" | Native team |
| "Dev checks a constraint with TEA" | Tandem consultation |

### Constraints

| Constraint | Impact |
|-----------|--------|
| Pennyfarthing primarily runs in `-p` mode | Tandem works, native teams don't |
| Native teams are experimental | API may change, feature-flag gated |
| Native teams require interactive session | Not available through Cyclist's current `-p` invocations |
| One team per session, no nesting | Can't compose teams of teams |
| No session resumption for teammates | Teams are ephemeral |

## Technical Architecture

### Layered Model

```
┌──────────────────────────────────────────────┐
│ Pennyfarthing Layer                          │
│ (Personas, Workflows, Sprint, Gates, Sidecars│
├───────────────┬──────────────────────────────┤
│ Tandem Layer  │ Native Teams Layer           │
│ (Phase 1)     │ (Phase 2)                    │
│               │                              │
│ Consultation  │ TeamCreate, SendMessage,     │
│ protocol,     │ TaskList, delegate mode,     │
│ dialogue      │ plan approval                │
│ files,        │                              │
│ subagent      │ Feature flag:                │
│ spawning      │ AGENT_TEAMS=1                │
├───────────────┼──────────────────────────────┤
│ Claude Code Task tool  │ Claude Code Teams API│
│ (subagent_type)        │ (experimental)       │
└────────────────────────┴─────────────────────┘
```

### Workflow YAML Extensions

**Tandem (Phase 1):**
```yaml
phases:
  - name: green
    agent: dev
    tandem:                    # NEW: from ADR-0012
      partner: architect
      mode: consultation
      model: sonnet
      token_budget: 1000
      triggers:
        - request: true
        - complexity: high
```

**Native Teams (Phase 2):**
```yaml
workflow:
  name: tdd-parallel
  execution_mode: team         # NEW: enables native teams
  team:
    display: in-process
    model: sonnet
    delegate_lead: true

  phases:
    - name: explore
      execution: parallel      # NEW: parallel phase
      teammates:
        - agent: tea
          task: "Write failing tests"
        - agent: architect
          task: "Review approach"
      gate:
        type: all_complete
```

### Dialogue File (Tandem persistence)

From ADR-0012 — all consultations recorded:

```
.session/{story-id}-dialogue.md

# Tandem Dialogue: MSSCI-14400
**Leader:** Dev (Roy Batty) | **Partner:** Architect (Niander Wallace)

## Exchange 1
**[14:32] Dev → Architect**
> Should webhook handler be sync or async?

**[14:32] Architect:**
Async. Queue the work, ack immediately. Webhook sources timeout at 30s.
**Confidence:** high
**Outcome:** applied
```

## Phase 1: Tandem Consultation (Stories 86-1 through 86-6)

Implements ADR-0012. Works in `-p` mode. No new dependencies.

## Phase 2: Native Teams (Stories 86-7 through 86-10)

Layers native Agent Teams on top. Interactive mode only. Feature-flagged.

## Phase 3: Cyclist Integration (Stories 86-11 through 86-12)

Cyclist visualizes both Tandem dialogues and native team activity.

## Stories

| # | Story | Points | Priority | Phase | Dependencies |
|---|-------|--------|----------|-------|-------------|
| 86-1 | Workflow schema: `tandem:` block | 3 | P0 | 1 | None |
| 86-2 | Consultation protocol implementation | 3 | P0 | 1 | 86-1 |
| 86-3 | Dialogue file management | 2 | P0 | 1 | 86-2 |
| 86-4 | Agent tandem awareness | 3 | P0 | 1 | 86-2 |
| 86-5 | Tandem workflow templates | 2 | P1 | 1 | 86-1, 86-4 |
| 86-6 | Tandem metrics and token tracking | 2 | P1 | 1 | 86-3 |
| 86-7 | Feature detection: native teams capability | 2 | P1 | 2 | None |
| 86-8 | Persona injection via spawn prompts | 3 | P1 | 2 | 86-7 |
| 86-9 | Workflow schema: `execution_mode: team` | 3 | P1 | 2 | 86-1, 86-7 |
| 86-10 | Gate-to-task-dependency adapter | 5 | P2 | 2 | 86-9 |
| 86-11 | Cyclist: Tandem dialogue panel | 3 | P2 | 3 | 86-3 |
| 86-12 | Cyclist: Native team panel | 5 | P3 | 3 | 86-10 |

**Total: 36 points (12 stories)**
**Phase 1: 15 points (6 stories) — delivers value without native teams**
**Phase 2: 13 points (4 stories) — adds parallelism for interactive users**
**Phase 3: 8 points (2 stories) — Cyclist visualization**

## Story Details

### Phase 1: Tandem Consultation

---

### 86-1: Workflow schema — `tandem:` block (3 pts)

**What:** Extend BikeLane workflow YAML schema to support `tandem:` configuration blocks on phases, per ADR-0012.

**Acceptance Criteria:**
- [ ] `tandem:` block parsed from workflow YAML phases
- [ ] Properties: `partner`, `mode`, `model`, `token_budget`, `triggers`
- [ ] Schema validation: unknown modes rejected, `consultation` accepted
- [ ] Backward compatible: existing workflows without `tandem:` unchanged
- [ ] `workflow-status-check` subagent reports tandem configuration

**Key files:**
- `pennyfarthing-dist/workflows/*.yaml` (schema extension)
- `pennyfarthing-dist/agents/workflow-status-check.md` (update)

---

### 86-2: Consultation protocol implementation (3 pts)

**What:** Implement the structured request/response consultation protocol from ADR-0012. Leader agent spawns partner as Haiku subagent with formatted request, receives structured response.

**Acceptance Criteria:**
- [ ] Consultation request format: context, question, options considered, relevant code
- [ ] Consultation response format: recommendation, rationale, watch-out-for, confidence
- [ ] Leader spawns partner via Task tool with `model: sonnet`
- [ ] Partner prompt includes: agent definition, persona, consultation request
- [ ] Response parsed and available to leader for continued work
- [ ] Graceful degradation: partner failure → leader continues solo with warning
- [ ] Token budget enforced via prompt instruction

**Key files:**
- `pennyfarthing-dist/protocols/tandem-consultation.md` (new — protocol spec)
- `pennyfarthing-dist/agents/*.md` (add tandem consultation guidance section)

---

### 86-3: Dialogue file management (2 pts)

**What:** Create, append, and archive tandem dialogue files that record all consultation exchanges.

**Acceptance Criteria:**
- [ ] Dialogue file created at `.session/{story-id}-dialogue.md` on first consultation
- [ ] Each exchange appended with: timestamp, agents, question summary, response, outcome
- [ ] Outcome tracked: applied / deferred / rejected
- [ ] Summary section auto-generated: total exchanges, key decisions, time in tandem
- [ ] Dialogue file archived alongside session file on story completion
- [ ] Dialogue file readable by Reviewer for audit

**Key files:**
- `.session/{story-id}-dialogue.md` (new file type)
- `pennyfarthing-dist/scripts/core/dialogue-manager.sh` (new)

---

### 86-4: Agent tandem awareness (3 pts)

**What:** Update agent definitions so leader agents know how to initiate tandem consultations and partner agents know how to respond.

**Acceptance Criteria:**
- [ ] Leader agents (dev, tea, reviewer) have `<tandem>` section in their .md files
- [ ] Section explains: when to consult, how to format request, how to use response
- [ ] Partner agents (architect, devops, tea) have consultation response guidance
- [ ] Agents check workflow phase for tandem availability before consulting
- [ ] High-value pairings documented per ADR-0012 table

**Key files:**
- `pennyfarthing-dist/agents/dev.md` (add tandem section)
- `pennyfarthing-dist/agents/tea.md` (add tandem section)
- `pennyfarthing-dist/agents/reviewer.md` (add tandem section)
- `pennyfarthing-dist/agents/architect.md` (add partner response section)

---

### 86-5: Tandem workflow templates (2 pts)

**What:** Ship pre-built workflow templates with tandem pairing configured for common patterns.

**Acceptance Criteria:**
- [ ] `tdd-tandem.yaml` — Dev + Architect consultation on green phase (5+ pt stories)
- [ ] `review-tandem.yaml` — Reviewer + Architect consultation on review phase
- [ ] `bdd-tandem.yaml` — TEA + Dev consultation on red phase
- [ ] Each template documented with when-to-use guidance
- [ ] `/workflow list` shows tandem-enabled workflows with indicator
- [ ] Trigger routing: 5+ point stories auto-suggest tandem variants

**Key files:**
- `pennyfarthing-dist/workflows/tdd-tandem.yaml` (new)
- `pennyfarthing-dist/workflows/review-tandem.yaml` (new)
- `pennyfarthing-dist/workflows/bdd-tandem.yaml` (new)

---

### 86-6: Tandem metrics and token tracking (2 pts)

**What:** Track consultation token usage, frequency, and outcomes for overhead analysis.

**Acceptance Criteria:**
- [ ] Consultation tokens logged separately from leader session tokens
- [ ] Metrics captured: count, total tokens, avg response time, outcome distribution
- [ ] Metrics written to dialogue file summary section
- [ ] Session summary includes tandem overhead percentage
- [ ] Target: consultation overhead < 25% of baseline story token cost

**Key files:**
- `pennyfarthing-dist/scripts/core/dialogue-manager.sh` (metrics)
- `.session/{story-id}-dialogue.md` (summary section)

---

### Phase 2: Native Teams

---

### 86-7: Feature detection — native teams capability (2 pts)

**What:** Create a utility that detects whether Claude Code native Agent Teams are available and enabled.

**Acceptance Criteria:**
- [ ] Check `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var
- [ ] Probe for TeamCreate/SendMessage tool availability
- [ ] Expose detection function in `@pennyfarthing/core`
- [ ] `pennyfarthing doctor` reports teams capability status
- [ ] Graceful degradation: `execution_mode: team` workflows fall back to sequential + tandem

**Key files:**
- `packages/core/src/cli/utils/capabilities.ts` (new)
- `packages/core/src/cli/commands/doctor.ts` (update)
- `pennyfarthing-dist/scripts/core/detect-teams.sh` (new)

---

### 86-8: Persona injection via spawn prompts (3 pts)

**What:** When spawning a native teammate, inject the full Pennyfarthing persona (agent definition + theme character + sidecar context) into the spawn prompt.

**Acceptance Criteria:**
- [ ] Build spawn prompt that includes: agent .md content, persona, sidecar patterns/gotchas
- [ ] Teammates activate with full persona context
- [ ] Theme from `.pennyfarthing/config.local.yaml` respected
- [ ] Spawn prompt stays under 4K tokens (context budget)
- [ ] Works with all 10 core agents
- [ ] Tandem partner context (from Phase 1) also included when relevant

**Key files:**
- `pennyfarthing-dist/scripts/core/build-spawn-prompt.sh` (new)
- `.pennyfarthing/config.local.yaml` (read for theme)
- `.pennyfarthing/sidecars/` (read for context)

---

### 86-9: Workflow schema — `execution_mode: team` (3 pts)

**What:** Extend BikeLane workflow YAML to support native team execution with parallel phases.

**Acceptance Criteria:**
- [ ] New fields: `execution_mode`, `team` (display, model, delegate_lead), `execution` per phase
- [ ] `execution: parallel` phases spawn multiple teammates simultaneously
- [ ] `execution: teammate` phases run on a single spawned teammate
- [ ] `execution: lead` phases run on the lead session
- [ ] Falls back to sequential + tandem when teams unavailable
- [ ] Backward compatible with all existing workflows

**Key files:**
- `pennyfarthing-dist/workflows/*.yaml` (schema extension)
- `pennyfarthing-dist/agents/workflow-status-check.md` (update)

---

### 86-10: Gate-to-task-dependency adapter (5 pts)

**What:** Map Pennyfarthing's workflow gates to native team task dependencies. Also adapts handoff to use SendMessage when in team mode.

**Acceptance Criteria:**
- [ ] Each workflow phase creates a native Task with appropriate blockers
- [ ] `tests_fail` gate: TEA's task blocks Dev's task
- [ ] `tests_pass` gate: Dev's task blocks Reviewer's task
- [ ] `approval` gate: Reviewer's task blocks SM finish task
- [ ] Failed gates leave tasks in `in_progress`
- [ ] `handoff.md` detects team mode, uses SendMessage instead of CYCLIST markers
- [ ] Session file still updated for audit trail and Cyclist compatibility
- [ ] Sidecar file locking for concurrent teammate writes

**Key files:**
- `pennyfarthing-dist/scripts/core/gate-adapter.sh` (new)
- `pennyfarthing-dist/agents/handoff.md` (team mode support)
- `pennyfarthing-dist/scripts/core/sidecar-sync.sh` (new)

---

### Phase 3: Cyclist Integration

---

### 86-11: Cyclist — Tandem dialogue panel (3 pts)

**What:** New Cyclist panel showing tandem consultation history — the dialogue file visualized in real-time.

**Acceptance Criteria:**
- [ ] New `TandemPanel` dockview panel
- [ ] Shows consultation exchanges with agent portraits
- [ ] Real-time updates as new consultations happen
- [ ] Outcome badges: applied (green), deferred (yellow), rejected (red)
- [ ] Metrics summary: exchange count, token overhead, confidence distribution

**Key files:**
- `packages/cyclist/src/public/components/panels/TandemPanel.tsx` (new)
- `packages/cyclist/src/public/components/DockviewWorkspace.tsx` (register panel)

---

### 86-12: Cyclist — Native team panel (5 pts)

**What:** Cyclist panel showing active native team members, their status, task progress, and message history.

**Acceptance Criteria:**
- [ ] New `TeamPanel` dockview panel
- [ ] Shows team members with persona portraits
- [ ] Real-time status: idle, working, blocked
- [ ] Task list with completion progress and dependency visualization
- [ ] Message feed between agents
- [ ] Click agent to view their output
- [ ] Panel hidden when native teams not active

**Key files:**
- `packages/cyclist/src/public/components/panels/TeamPanel.tsx` (new)
- `packages/cyclist/src/public/components/DockviewWorkspace.tsx` (register panel)

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Native teams API changes | Phase 2 adapter breaks | Feature detection (86-7) isolates dependency; Phase 1 unaffected |
| Token cost explosion | 3-5x for parallel workflows | Tandem (Phase 1) keeps costs low; teams are opt-in |
| Tandem advice quality | Bad recommendations cause rework | Confidence signals, dialogue audit trail, outcome tracking |
| File conflicts in team mode | Two teammates edit same file | Workflow design assigns file ownership per agent |
| Sidecar corruption | Concurrent writes lose data | File locking in 86-10 |
| `-p` mode incompatibility | Native teams don't work for most users | Phase 1 (Tandem) delivers full value without teams |

## ADR Updates Required

| ADR | Update |
|-----|--------|
| ADR-0012 | Status: Proposed → Accepted |
| ADR-0013 (new) | Native Agent Teams integration strategy, feature detection, fallback behavior |

## References

- [ADR-0012: Tandem Agent Pairing](../docs/adr/0012-tandem-agent-pairing.md)
- [PRD: Tandem Agent Pairing](../artifacts/prd-tandem.md)
- [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [ADR-0007: Subagent Delegation Model](../docs/adr/0007-subagent-delegation-model.md)
