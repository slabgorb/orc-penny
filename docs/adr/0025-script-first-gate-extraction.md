# ADR-0025: Script-First Gate Extraction

**Status:** Proposed
**Date:** 2026-02-13
**Author:** architect (Major Margaret Houlihan)
**PRD:** sprint/planning/gate-prd.md

## Context

Phase transition gates are currently embedded as inline logic within the handoff subagent (`handoff.md`). Each gate type (`tests_pass`, `tests_fail`, `approval`, `manual`) is a hardcoded branch in a single agent definition. This creates several problems:

- **Two separate gate systems**: Phased workflows use `handoff.ts` → `checkGate()`, while stepped workflows use `gate-handler.ts` → `detectGate()`. These share no code or concepts.
- **Subagent-of-subagent nesting**: Agent → handoff subagent → (future) gate runner creates fragile 3-hop chains.
- **System under strain**: `2party-tdd.yaml` already uses `quality_pass` gate type that isn't in `handoff.md` — it silently passes via the default case.
- **Session updates via LLM Edit calls**: The handoff subagent uses Edit tool to update session files, which is fragile and non-atomic.
- **No extensibility**: Adding a new gate type means modifying `handoff.md` inline logic.

### Decision Drivers

1. Gate logic should be declarative files, not embedded agent code
2. Session updates must be atomic (not LLM Edit calls)
3. Subagent nesting depth must not increase
4. The system must support incremental migration (old and new coexist)
5. Manual gates should not require an LLM spawn

## Considered Options

### Option A: PRD's "Thin Handoff to Router" (Rejected)

Keep the handoff subagent as a thin router: agent → handoff → gate file subagent → handoff → agent.

**Rejected because:** Adds a 4th hop (agent → handoff → gate → handoff) when 2 hops suffice (agent → gate). The handoff subagent becomes pure overhead — everything it does (read workflow YAML, update session) can be a bash script.

### Option B: Script-First Gate Extraction (Selected)

Eliminate the handoff subagent entirely. Replace with bash scripts for routing and session updates, LLM only for gate evaluation.

## Decision Outcome

**Selected: Script-First Gate Extraction (Kill Handoff)**

Replace the handoff subagent with:

1. `handoff-cli.sh resolve-gate` — bash script finds gate file + next phase, pre-checks assessment
2. Gate file subagent — the only LLM in the flow, evaluates pass/fail criteria
3. `handoff-cli.sh complete-phase` — bash script atomically updates session (temp file + mv)
4. Updated `<agent-exit-protocol>` — agents drive exit directly, no intermediate subagent

**Rationale:** Follows the prime pattern (scripts inform agents, agents make decisions). Eliminates subagent-of-subagent nesting. Session updates become atomic bash operations. One fewer haiku spawn per handoff. Manual gates short-circuit without any LLM cost.

### Component Structure

```
Agent (tea/dev/reviewer/sm)
  │
  │ 1. Write assessment to session
  │ 2. Call handoff-cli.sh resolve-gate
  ▼
┌──────────────────────────────────┐
│     handoff-cli.sh               │  Pure bash
│     (Phase Router)               │
│  resolve-gate → find gate file   │
│  complete-phase → atomic update  │
└──────────┬───────────────────────┘
           │ gate file path
           ▼
┌──────────────────────────────────┐
│     Gate File Subagent           │  Haiku Task
│  Input: gate file + session ctx  │
│  Output: GATE_RESULT             │
└──────────┬───────────────────────┘
           │ pass/fail
           ▼
┌──────────────────────────────────┐
│     Agent (continued)            │
│  pass → complete-phase → marker  │
│  fail → fix issues, retry       │
└──────────────────────────────────┘
```

**Components:**

| Component | Responsibility | Dependencies |
|-----------|---------------|--------------|
| `handoff-cli.sh` | Phase routing, assessment pre-check, session updates, gate file resolution | Workflow YAML, session file |
| Gate files (`gates/*.md`) | Declarative pass/fail criteria | None (pure content) |
| Gate subagent (haiku) | Evaluate criteria against current state | Gate file, session |
| `handoff-marker.sh` | Environment-aware marker generation | Cyclist detection |

**Gate file resolution order:**
1. `.pennyfarthing/gates/{name}.md` (project-local)
2. `pennyfarthing-dist/gates/{name}.md` (built-in)
3. Inline type fallback (migration compatibility)

### Interfaces

**`handoff-cli.sh resolve-gate <story-id> <workflow> <current-phase>`**

```yaml
RESOLVE_RESULT:
  status: ready | blocked | skip
  gate_type: tests_pass | tests_fail | approval | manual
  gate_file: .pennyfarthing/gates/tests-pass.md
  next_agent: dev | tea | reviewer | sm
  next_phase: green | review | approved | finish
  assessment_found: true | false
  error: null | "message"
# Exit: 0 = ready/skip, 1 = blocked
```

**`handoff-cli.sh complete-phase <story-id> <workflow> <from> <to> <gate-type>`**

```yaml
COMPLETE_RESULT:
  status: success | error
  session_file: .session/{story-id}-session.md
  error: null | "message"
# Exit: 0 = success, 1 = error
# Atomicity: temp file + mv
```

**Gate subagent contract:**

```yaml
GATE_RESULT:
  status: pass | fail
  message: "human-readable summary"
  checks:
    - name: "check name"
      status: pass | fail
      detail: "specifics"
```

**Gate file schema:**

```xml
<gate name="{name}" model="haiku">
  <purpose>What this gate checks</purpose>
  <pass>Pass criteria (instructions for evaluator)</pass>
  <fail>Failure report + recovery instructions</fail>
  <gate name="{child}"><!-- max depth 3 --></gate>
</gate>
```

**Workflow YAML extension:**

```yaml
gate:
  file: gates/tests-pass    # new (takes precedence)
  type: tests_pass           # legacy fallback
  condition: "All tests passing"
```

**Agent exit protocol (new):**

1. Write assessment to session
2. Terminate tandem backseat (if active)
3. `handoff-cli.sh resolve-gate` → if blocked, STOP
4. If skip → step 6. If ready → spawn gate subagent
5. If fail → fix + retry. If pass → continue
6. `handoff-cli.sh complete-phase`
7. `handoff-marker.sh {next_agent}` → emit marker → EXIT

## Consequences

### Positive

- Eliminates subagent-of-subagent nesting (3 hops → 2)
- Session updates are atomic bash (temp+mv), not fragile LLM Edit calls
- Manual gates cost zero LLM tokens
- Gate definitions are declarative, reviewable, testable files
- Incremental migration via `gate.file` / `gate.type` coexistence
- Follows established prime pattern (scripts inform, agents decide)

### Negative

- All agent files (~10) need `<agent-exit-protocol>` updated simultaneously
- `handoff.md` and `sm-handoff.md` subagents become dead code (removal needed)
- `handoff-cli.sh` is a new bash script with non-trivial logic (YAML parsing, file resolution)
- Two gate systems remain (phased vs stepped) — this ADR only addresses phased

### Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Gate subagent returns unparseable output | Med | Med | Default-deny: no GATE_RESULT = fail |
| Assessment section format drift | Med | Med | Exact heading marker (`## Assessment`), script greps heading |
| `<gate>` tag collision with step files | Med | Med | Gate files in `gates/` only, parser checks directory |
| Agent implements exit protocol differently | High | Med | Single canonical `<agent-exit-protocol>`, bulk-updated |
| Gate criteria model-dependent | Med | Low | `model` attribute locks evaluator |

## Implementation Consistency Rules

> These rules prevent AI agents from making conflicting implementation choices.

1. **Agent drives exit, not a subagent** — calling agent directly calls scripts + spawns gate subagent
2. **Gate subagent is the ONLY LLM in exit path** — scripts are pure bash
3. **Session updates are atomic scripts** — agents MUST NOT manually edit phase/history fields
4. **`GATE_RESULT` is the only contract** — agent branches on `status` only
5. **`gate.file` precedence over `gate.type`** — enables incremental migration
6. **`manual` gate short-circuits** — no LLM spawn, resolve-gate returns pass directly
7. **Assessment pre-check in resolve-gate** — fail-fast on missing prerequisite
8. **Script stdout is the ONLY communication channel** — no side-channel files or env vars

## Implementation Plan

### Phase 1: MVP
1. Create `pennyfarthing-dist/scripts/core/handoff-cli.sh` with `resolve-gate` and `complete-phase`
2. Create `pennyfarthing-dist/gates/tests-pass.md` (first gate file)
3. Add `gate.file` support to workflow YAML schema
4. Update `<agent-exit-protocol>` in all agent files
5. Add `gate.file: gates/tests-pass` to `tdd.yaml` green phase

### Phase 2: Migration
6. Create remaining gate files: `tests-fail.md`, `approval.md`
7. Update all workflow YAMLs to use `gate.file`
8. Deprecate inline gate logic in `handoff-cli.sh`
9. Remove `handoff.md` subagent (replaced by scripts)

### Phase 3: Cleanup
10. Remove `sm-handoff.md` (SM uses same script path)
11. Remove inline `gate.type` fallback from `handoff-cli.sh`
12. Update Cyclist `checkGate()` if needed

## Related Decisions

- [ADR-0007: Subagent Delegation Model](0007-subagent-delegation-model.md) — this ADR removes one delegation layer
- [ADR-0009: Session File Coordination](0009-session-file-coordination.md) — session writes become atomic scripts
- [ADR-0013: BMAD Workflow Import](0013-bmad-workflow-import.md) — BikeLane stepped workflows are unaffected
- [ADR-0015: Prime Activation System](0015-prime-activation-system.md) — follows the same scripts-inform-agents pattern
