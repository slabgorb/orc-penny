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
| Native teams are experimental | API may change, feature-flag gated (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) |
| Native teams require interactive session | Not available in `-p` mode; Cyclist (Electron) could launch interactively |
| One team per session, no nesting | Can't compose teams of teams |
| No session resumption for teammates | Teams are ephemeral — no `/resume` for in-process teammates |
| Lead is fixed for team lifetime | Phase agent is lead for that phase's team; can't promote teammates |
| Teammates inherit lead permissions | Can't set per-teammate modes at spawn; change individually after |

### Agent Model Analysis (2026-02-15)

Our agent concept and native teams' agent concept are fundamentally different execution models. Phase 2 must bridge them cleanly.

**Our model — sequential prompt re-priming:**
```
Session 1: /sm  → Prime loads SM .md → work → marker → EXIT
Session 2: /tea → Prime loads TEA .md → work → marker → EXIT
Session 3: /dev → Prime loads Dev .md → work → marker → EXIT
```
Each "agent" is the same Claude Code instance re-primed with a different `.md` file.
Communication via session file writes. One agent alive at a time.

**Native teams model — concurrent independent sessions:**
```
Lead (SM): TeamCreate → spawns teammates → coordinates via SendMessage
  ├── TEA session: independent context, claims tasks, messages others
  ├── Dev session: independent context, claims tasks, messages others
  └── Reviewer session: independent context, claims tasks, messages others
```
Each teammate is a separate Claude Code process with its own context window.
Communication via SendMessage + shared TaskList.

**Compatibility matrix:**

| Concept | Our Model | Native Teams | Compatible? |
|---------|-----------|-------------|-------------|
| Agent identity | `.md` template loaded by Prime | Spawn prompt + auto-loaded CLAUDE.md | Yes — spawn prompt runs `pf agent start` |
| Communication | Session file + handoff markers | `SendMessage` DMs + broadcasts | **No** — markers are UI routing, not messaging |
| Coordination | Sequential `pf handoff` CLI | Shared `TaskList` with claim/complete | **No** — handoff assumes one agent at a time |
| State | `.session/` single-writer | Each teammate writes independently | **Conflict** — concurrent writes corrupt |
| Phase transitions | `pf handoff complete-phase` | Task deps with `addBlockedBy` | **Different paradigm** — ours assumes serial |
| Gates | Gate subagent spawned by exiting agent | `TaskCompleted` hook prevents completion | **Complementary** — hooks replace gate subagents |
| Lifecycle | Activate → work → exit → die | Spawn → work → idle → wake → shutdown | **Compatible** — teammates are phase-scoped, cleaned up before handoff |
| Lead role | Phase agent owns the work | Lead spawns + coordinates teammates | **Compatible** — phase agent IS the lead for that phase |
| Reflector markers | Every turn ends with `<!-- CYCLIST:... -->` | No markers — uses SendMessage | **Compatible** — markers for inter-phase handoff, SendMessage for intra-phase |

**Resolution — phase-scoped teams:**

The workflow stays sequential. Native teams enhance a **phase**, not replace the workflow. The current phase agent is the team lead and spawns teammates for parallel work within that phase.

```
execution_mode: sequential (default — today's model, unchanged)
  └── SM → TEA → Dev → Reviewer → SM
  └── Each agent activates, works solo, hands off via marker

execution_mode: team (native teams, per-phase)
  └── SM → TEA → Dev (team lead) → Reviewer → SM
                    │
                    ├── TeamCreate at phase start
                    ├── Spawn Architect as teammate
                    ├── Dev implements, Architect reviews in parallel
                    ├── SendMessage for real-time collaboration
                    ├── TeamDelete at phase end
                    └── Normal handoff to Reviewer
```

**Example: Dev + Architect in green phase:**
```
Dev activates (Prime, normal) → detects team config in workflow YAML
  → TeamCreate("green-phase")
  → Task(team_name="green-phase", name="architect",
         prompt="Run `pf agent start architect`. Story: MSSCI-14400.
                 Review Dev's implementation approach. Focus on patterns
                 and coupling. Send findings via SendMessage.")
  → Dev works on implementation
  → Architect reviews files, sends messages: "Consider extracting..."
  → Dev receives messages, adjusts approach
  → Dev finishes → shuts down Architect → TeamDelete
  → Normal exit protocol: pf handoff → marker → EXIT
```

Key insights:
- Teammates auto-load CLAUDE.md + MCP servers + skills from the working directory — they already get `.pennyfarthing/` context. Spawn prompts only need activation command + story assignment.
- The team is **phase-scoped** — created at phase start, destroyed at phase end. No lifecycle change to the workflow.
- Handoff between phases is unchanged — markers, session file, `pf handoff` CLI all work as-is.
- Within the phase, communication uses `SendMessage` (not markers, not session file).
- `TaskCompleted` hook can enforce gate checks before the lead marks phase done.
- Tandem consultation (subagent, sync) and native teams (teammate, async) coexist — tandem for quick questions, teams for sustained parallel work.

## Technical Architecture

### Layered Model

```
┌────────────────────────────────────────────────────────┐
│ Pennyfarthing Layer                                    │
│ (Personas, Workflows, Sprint, Gates, Sidecars, Prime)  │
├───────────────┬────────────────────────────────────────┤
│ Tandem Layer  │ Native Teams Layer                     │
│ (Phase 1)     │ (Phase 2)                              │
│               │                                        │
│ Consultation  │ TeamCreate      — create team           │
│ protocol,     │ SendMessage     — DMs, broadcast,      │
│ dialogue      │                   shutdown, plan approval│
│ files,        │ TaskCreate/List — shared work tracking  │
│ subagent      │ TeammateIdle    — hook: gate on idle    │
│ spawning      │ TaskCompleted   — hook: gate on done    │
│               │ Delegate mode   — SM lead, no code      │
│               │ Plan approval   — TEA plans, lead OKs   │
│               │                                        │
│               │ Feature flag:                          │
│               │ CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 │
├───────────────┼────────────────────────────────────────┤
│ Claude Code   │ Claude Code Teams API                  │
│ Task tool     │ (experimental, interactive only)       │
│ (subagents)   │                                        │
└───────────────┴────────────────────────────────────────┘
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
  name: tdd-team
  description: TDD with native team collaboration on complex phases

  phases:
    - name: setup
      agent: sm
      output: [session_file, branches]

    - name: red
      agent: tea
      input: [session_file]
      output: [failing_tests]
      # No team — TEA works solo (simple phase)

    - name: green
      agent: dev
      input: [failing_tests]
      output: [implementation, passing_tests]
      team:                        # NEW: phase-scoped team
        teammates:
          - agent: architect
            task: "Review implementation approach and patterns"
          - agent: tea
            task: "Verify tests stay green, flag regressions"
        model: sonnet
        display: in-process

    - name: review
      agent: reviewer
      input: [implementation, passing_tests]
      output: [approval]
      team:                        # Reviewer can have teammates too
        teammates:
          - agent: architect
            task: "Validate architectural patterns"

    - name: finish
      agent: sm
```
Phase agent is always the team lead. Teammates are spawned at phase start,
cleaned up at phase end. Handoff between phases is unchanged.

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

## Phase 2: Native Teams (Stories 86-7 through 86-10, 86-14, 86-15)

Phase-scoped native Agent Teams. The current phase agent is the team lead, spawning
teammates for parallel collaboration within that phase. Teams are created at phase
start and destroyed before handoff. Interactive mode only. Feature-flagged.

**Gate transparency:** Gates are defined in workflow YAML identically for both modes.
In sequential mode, gates execute via `pf handoff resolve-gate` (agent-driven).
In team mode, gates execute via `TaskCompleted` and `TeammateIdle` hooks (event-driven).
The hook reads the same gate definition from workflow YAML — gate authors don't need
to know which executor runs their gate.

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
| 86-8 | Teammate activation via spawn prompts | 2 | P1 | 2 | 86-7 |
| 86-9 | Workflow schema: `team:` block on phases | 3 | P1 | 2 | 86-1, 86-7 |
| 86-10 | Phase-scoped team lifecycle + gate hooks | 5 | P1 | 2 | 86-8, 86-9 |
| 86-11 | Cyclist: Tandem dialogue panel | 3 | P2 | 3 | 86-3 |
| 86-12 | Cyclist: Native team panel | 5 | P2 | 3 | 86-10 |
| 86-14 | Agent behavior: team-mode protocol | 2 | P1 | 2 | 86-8 |
| 86-15 | Team-enabled workflow templates | 2 | P1 | 2 | 86-9, 86-14 |

**Total: 39 points (14 stories)**
**Phase 1: 15 points (6 stories) — delivers value without native teams**
**Phase 2: 16 points (6 stories) — phase-scoped teams for interactive users**
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
- [ ] Detect interactive vs `-p` mode (teams require interactive)
- [ ] Detect `teammateMode` setting (`in-process` vs `tmux`)
- [ ] Expose detection function in `@pennyfarthing/core`
- [ ] `pennyfarthing doctor` reports teams capability status
- [ ] Graceful degradation: phases with `team:` block fall back to solo + tandem consultation

**Key files:**
- `packages/core/src/cli/utils/capabilities.ts` (new)
- `packages/core/src/cli/commands/doctor.ts` (update)
- `pennyfarthing-dist/scripts/core/detect-teams.sh` (new)

---

### 86-8: Teammate activation via spawn prompts (2 pts) ← reduced from 3

**What:** When spawning a native teammate, use a lightweight spawn prompt that triggers normal Prime activation. Teammates auto-load CLAUDE.md, MCP servers, and skills from the working directory — no need to rebuild context in the prompt.

**Acceptance Criteria:**
- [ ] Spawn prompt runs `pf agent start {agent}` for full Prime activation
- [ ] Spawn prompt includes: story ID, task assignment, phase context
- [ ] Teammates activate with persona, sidecars, and session context via Prime (not prompt injection)
- [ ] Spawn prompt stays under 500 tokens (activation command + task)
- [ ] Works with all 10 core agents
- [ ] Teammate correctly reads session file and workflow state

**Key files:**
- `pennyfarthing-dist/scripts/core/build-spawn-prompt.sh` (new — thin wrapper)
- `pennyfarthing-dist/agents/agent-behavior.md` (add `<team-mode>` section)

---

### 86-9: Workflow schema — `team:` block on phases (3 pts)

**What:** Extend BikeLane phase schema to support a `team:` block that declares teammates for that phase. The phase agent is always the lead; teammates are phase-scoped.

**Acceptance Criteria:**
- [ ] `team:` block parsed from workflow YAML phases (sibling to `tandem:`)
- [ ] Properties: `teammates` (list of agent + task), `model`, `display`
- [ ] Each teammate entry has: `agent` (required), `task` (description string)
- [ ] Schema validation: teammate agents must be valid agent names
- [ ] Falls back to solo execution when native teams unavailable (feature detection from 86-7)
- [ ] Backward compatible: phases without `team:` unchanged
- [ ] `workflow-status-check` subagent reports team configuration per phase

**Key files:**
- `pennyfarthing-dist/workflows/*.yaml` (schema extension)
- `pennyfarthing-dist/agents/workflow-status-check.md` (update)

---

### 86-10: Phase-scoped team lifecycle + gate hooks (5 pts)

**What:** Implement the phase-scoped team lifecycle: lead agent creates team at phase start, manages teammates during the phase, enforces gates via native hooks, and cleans up before handoff.

**Acceptance Criteria:**
- [ ] Lead agent creates team on phase entry when workflow has `execution: team`
- [ ] Lead spawns teammates per workflow YAML `teammates:` config
- [ ] `TaskCompleted` hook enforces gate checks before lead marks phase done
- [ ] `TeammateIdle` hook validates teammate work meets criteria (e.g., tests pass)
- [ ] Lead shuts down all teammates before starting exit protocol
- [ ] `TeamDelete` runs before `pf handoff` — team is fully cleaned up before marker
- [ ] Session file updated with teammate activity summary for audit
- [ ] Sidecar file locking for concurrent teammate writes
- [ ] Graceful degradation: if teammate crashes, lead continues solo with warning

**Key files:**
- `pennyfarthing-dist/scripts/core/team-lifecycle.sh` (new — create/cleanup)
- `pennyfarthing-dist/hooks/teammate-idle.sh` (new — gate enforcement)
- `pennyfarthing-dist/hooks/task-completed.sh` (new — gate enforcement)
- `pennyfarthing-dist/agents/agent-behavior.md` (add `<team-mode>` exit protocol)
- `pennyfarthing-dist/scripts/core/sidecar-sync.sh` (new — file locking)

---

### 86-14: Agent behavior — team-mode protocol (2 pts) — NEW

**What:** Add `<team-mode>` section to `agent-behavior.md` and individual agent `.md` files defining how agents behave when they are a team lead or a teammate.

**Acceptance Criteria:**
- [ ] `agent-behavior.md` has `<team-mode>` section covering: team creation, teammate spawning, SendMessage communication, cleanup before handoff
- [ ] Lead agents know: create team on phase entry, spawn teammates per YAML, shut down teammates before exit protocol
- [ ] Teammate agents know: they're a teammate (not lead), communicate via SendMessage, go idle when done, respond to shutdown requests
- [ ] Exit protocol has team-mode branch: cleanup team THEN run normal handoff
- [ ] Reflector markers still used for inter-phase handoff (unchanged)
- [ ] SendMessage used for intra-phase teammate communication (new)

**Key files:**
- `pennyfarthing-dist/agents/agent-behavior.md` (add `<team-mode>` section)
- `pennyfarthing-dist/agents/dev.md` (lead behavior for green phase)
- `pennyfarthing-dist/agents/reviewer.md` (lead behavior for review phase)

---

### 86-15: Team-enabled workflow templates (2 pts) — NEW

**What:** Ship workflow YAML templates with `team:` blocks configured for high-value pairings.

**Acceptance Criteria:**
- [ ] `tdd-team.yaml` — Dev + Architect on green, Reviewer + Architect on review
- [ ] `bdd-team.yaml` — UX + Architect on design, Dev + TEA on green
- [ ] Each template documented with when-to-use vs tandem variants
- [ ] `/workflow list` shows team-enabled workflows with indicator
- [ ] Templates include graceful fallback comment for when teams unavailable

**Key files:**
- `pennyfarthing-dist/workflows/tdd-team.yaml` (new)
- `pennyfarthing-dist/workflows/bdd-team.yaml` (new)

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
| Native teams API changes | Phase 2 lifecycle/hooks break | Feature detection (86-7) isolates dependency; phases fall back to solo + tandem |
| Token cost explosion | Each teammate is a full context window | Teams are opt-in per-phase; tandem (Phase 1) covers most cases cheaply |
| Tandem advice quality | Bad recommendations cause rework | Confidence signals, dialogue audit trail, outcome tracking |
| File conflicts in team mode | Two teammates edit same file | Workflow YAML declares file ownership; `TeammateIdle` hook can enforce |
| Sidecar corruption | Concurrent writes lose data | File locking in 86-10 |
| `-p` mode incompatibility | Native teams don't work in `-p` | Phase 1 (Tandem) delivers full value; Cyclist could launch interactively |
| Teammate crash mid-phase | Lead loses collaborator | Graceful degradation: lead continues solo with warning (86-10) |
| Team cleanup before handoff | Orphaned sessions if exit fails | 86-10 enforces TeamDelete before `pf handoff`; cleanup is pre-exit gate |

## ADR Updates Required

| ADR | Update |
|-----|--------|
| ADR-0012 | Status: Proposed → Accepted |
| ADR-0013 (new) | Phase-scoped native teams: agent model bridging, hook-based gates, dual-mode execution, fallback behavior |

## References

- [ADR-0012: Tandem Agent Pairing](../docs/adr/0012-tandem-agent-pairing.md)
- [PRD: Tandem Agent Pairing](../artifacts/prd-tandem.md)
- [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [ADR-0007: Subagent Delegation Model](../docs/adr/0007-subagent-delegation-model.md)
