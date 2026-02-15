# Epic 105: Script-First Handoff

**Jira:** (not yet created)
**ADR:** 0025
**Repo:** pennyfarthing
**PRD:** `sprint/planning/gate-prd.md`

## Overview

Replace the `handoff` and `sm-handoff` LLM subagents with bash scripts for phase routing and atomic session updates. Agents drive their own exit flow directly. Manual gates cost zero tokens. This is the foundation epic — all subsequent gate extraction work builds on the script infrastructure created here.

## Stories

| ID | Title | Pts | Priority | Workflow |
|----|-------|-----|----------|----------|
| 105-1 | Create handoff-cli.sh with resolve-gate and complete-phase | 3 | P1 | tdd |
| 105-2 | Update agent exit protocol across all agent files | 2 | P1 | agent-docs |
| 105-3 | End-to-end handoff smoke test | 1 | P1 | trivial |

## Current Handoff Architecture (What We're Replacing)

```
Agent (tea/dev/reviewer/sm)
  │
  │ 1. Write assessment
  │ 2. Spawn handoff subagent (Haiku Task)
  ▼
┌──────────────────────────────────┐
│     handoff.md subagent          │  LLM (Haiku)
│  - Query workflow YAML for gate  │
│  - Run gate-specific checks      │
│  - Update session via Edit tool  │  ← fragile, non-atomic
│  - Return HANDOFF_RESULT         │
└──────────┬───────────────────────┘
           │
           ▼
Agent (continued)
  │ 3. Run handoff-marker.sh {next_agent}
  │ 4. Emit marker → EXIT
```

**Problems:**
- Session updates via LLM Edit calls — fragile, non-atomic
- Subagent-of-subagent nesting (agent → handoff → future gate subagent = 3 hops)
- Manual gates still spawn an LLM
- Adding gate types requires editing `handoff.md` inline logic
- `quality_pass` gate type silently passes via default case

## Target Architecture (What We're Building)

```
Agent (tea/dev/reviewer/sm)
  │
  │ 1. Write assessment
  │ 2. handoff-cli.sh resolve-gate     ← pure bash
  │ 3. [If skip] jump to 6
  │ 4. Spawn gate file subagent         ← only LLM in exit path
  │ 5. [If fail] fix + retry
  │ 6. handoff-cli.sh complete-phase    ← atomic (temp+mv)
  │ 7. handoff-marker.sh → emit → EXIT
```

## Existing Infrastructure

### Files That Will Be Modified or Replaced

| File | Current Role | Change |
|------|-------------|--------|
| `pennyfarthing-dist/agents/handoff.md` | LLM subagent for gate checks + session updates | Eventually removed (epic 108) |
| `pennyfarthing-dist/agents/sm-handoff.md` | SM-specific handoff subagent | Eventually removed (epic 108) |
| `pennyfarthing-dist/scripts/core/handoff-marker.sh` | Environment-aware marker generation | Unchanged — still the final step |
| `pennyfarthing-dist/agents/tea.md` | TEA agent exit protocol | Updated exit sequence |
| `pennyfarthing-dist/agents/dev.md` | Dev agent exit protocol | Updated exit sequence |
| `pennyfarthing-dist/agents/reviewer.md` | Reviewer agent exit protocol | Updated exit sequence |
| `pennyfarthing-dist/agents/sm.md` | SM agent exit protocol | Updated exit sequence |
| All other agent `.md` files | Various agent exit protocols | Updated exit sequence |

### Scripts Infrastructure

| Script | Location | Purpose |
|--------|----------|---------|
| `handoff-marker.sh` | `pennyfarthing-dist/scripts/core/` | Generates CYCLIST markers — stays as-is |
| `phase-owner.sh` | `pennyfarthing-dist/scripts/workflow/` | Resolves phase → agent — used by resolve-gate |
| `find-root.sh` | `pennyfarthing-dist/scripts/core/` | Project root discovery — used by all scripts |
| `check-context.sh` | `pennyfarthing-dist/scripts/core/` | Context usage detection — used by marker |

### Session File Format

**Location:** `.session/{story-id}-session.md`

Key sections that `complete-phase` must update atomically:

```markdown
## Workflow Tracking
**Phase:** green                        ← update to next phase
**Phase Started:** 2026-02-13T14:30:00Z ← update timestamp

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| red | ... | ... | 30m |          ← fill in Ended/Duration for current
| green | ... | - | - |           ← add new row for next phase

### Handoff History
| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| red (tea) | green (dev) | tests_fail | PASSED | ... |  ← add new row
```

### Workflow YAML Phase Schema

**Location:** `pennyfarthing-dist/workflows/{name}/workflow.yaml`

Current phase definition:
```yaml
- name: green
  agent: dev
  gate:
    type: tests_pass                    # inline gate type
    condition: "All tests passing"
```

## Story 105-1: Create handoff-cli.sh

### File to Create

`pennyfarthing-dist/scripts/core/handoff-cli.sh`

### Subcommand: resolve-gate

**Input:** `handoff-cli.sh resolve-gate <story-id> <workflow> <current-phase>`

**Logic:**
1. Find project root via `find-root.sh`
2. Read workflow YAML at `.pennyfarthing/workflows/{workflow}/workflow.yaml`
3. Find current phase, extract `gate.type` (and later `gate.file`)
4. If `gate.type == manual` → return `status: skip`
5. Check session file for `## Assessment` heading (grep) → if missing, return `status: blocked`
6. Look up next phase and next agent from workflow phases array
7. Return structured `RESOLVE_RESULT`

**Output contract:**
```yaml
RESOLVE_RESULT:
  status: ready | blocked | skip
  gate_type: tests_pass | tests_fail | approval | manual
  gate_file: null                       # null for MVP, populated in epic 106
  next_agent: dev | tea | reviewer | sm
  next_phase: green | review | finish
  assessment_found: true | false
  error: null | "message"
```

**Exit codes:** 0 = ready/skip, 1 = blocked

### Subcommand: complete-phase

**Input:** `handoff-cli.sh complete-phase <story-id> <workflow> <from-phase> <to-phase> <gate-type>`

**Logic:**
1. Read session file
2. Create temp copy
3. Update `**Phase:**` line to new phase
4. Update `**Phase Started:**` to current ISO timestamp
5. Fill in `Ended` and `Duration` for current phase in Phase History table
6. Add new row for next phase in Phase History table
7. Add row to Handoff History table
8. `mv` temp file over original (atomic)

**Output contract:**
```yaml
COMPLETE_RESULT:
  status: success | error
  session_file: .session/{story-id}-session.md
  error: null | "message"
```

### YAML Parsing in Bash

Use `yq` (already a project dependency) for workflow YAML queries:
```bash
GATE_TYPE=$(yq ".workflow.phases[] | select(.name == \"$PHASE\") | .gate.type" "$WORKFLOW_FILE")
NEXT_PHASE=$(yq ".workflow.phases[$PHASE_INDEX + 1].name" "$WORKFLOW_FILE")
NEXT_AGENT=$(yq ".workflow.phases[$PHASE_INDEX + 1].agent" "$WORKFLOW_FILE")
```

### Session Parsing in Bash

Use `grep`/`sed` for session file updates (markdown, not YAML):
```bash
# Check assessment exists
grep -q "^## .*Assessment" "$SESSION_FILE"

# Update phase line
sed -i '' "s/^\*\*Phase:\*\* .*/\*\*Phase:\*\* $TO_PHASE/" "$TEMP_FILE"
```

### Key Constraints

- **Script stdout is the ONLY communication channel** — no side-channel files
- **Assessment section check uses heading grep** — exact pattern `## {Agent} Assessment` or `## Assessment`
- **Atomic writes** — always temp file + mv, never in-place edit
- **`#!/usr/bin/env zsh`** — all pennyfarthing scripts use zsh

---

## Story 105-2: Update Agent Exit Protocol

### Current `<agent-exit-protocol>` (in all ~10 agent files)

```
1. Write assessment to session
2. Terminate tandem backseat (if active)
3. Spawn handoff subagent → returns HANDOFF_RESULT
4. If blocked → report error, stop
5. Run handoff-marker.sh {next_agent}
6. Extract marker, emit it
7. EXIT
```

### New `<agent-exit-protocol>` (from ADR-0025)

```
1. Write assessment to session
2. Terminate tandem backseat (if active)
3. handoff-cli.sh resolve-gate {story-id} {workflow} {phase} → RESOLVE_RESULT
4. If blocked → report error, STOP
5. If skip → jump to step 7
6. If ready → spawn gate subagent with gate file → GATE_RESULT
   - If fail → fix issues, retry from step 3 (max 3 retries)
   - If pass → continue
7. handoff-cli.sh complete-phase {story-id} {workflow} {from} {to} {gate-type}
8. handoff-marker.sh {next_agent} → emit marker → EXIT
```

### Agent Files to Update

| File | Agent | Notes |
|------|-------|-------|
| `agents/tea.md` | TEA | Remove handoff subagent reference |
| `agents/dev.md` | Dev | Remove handoff subagent reference |
| `agents/reviewer.md` | Reviewer | Has merge-before-handoff logic — keep that |
| `agents/sm.md` | SM | Uses sm-handoff, switch to same handoff-cli.sh |
| `agents/orchestrator.md` | Orchestrator | If has exit protocol |
| `agents/architect.md` | Architect | If has exit protocol |
| `agents/pm.md` | PM | If has exit protocol |
| `agents/tech-writer.md` | Tech Writer | If has exit protocol |
| `agents/ux-designer.md` | UX Designer | If has exit protocol |
| `agents/devops.md` | DevOps | If has exit protocol |

### What Changes Per Agent File

1. Replace `<agent-exit-protocol>` section with new 8-step sequence
2. Remove handoff/sm-handoff from `<helpers>` table
3. Remove handoff subagent from `<parameters>` section
4. Update `<exit-sequence>` to match new protocol
5. Update `<handoff-gate>` checklist

### Key Constraint

All agent files must have the **identical** exit protocol text. Bulk update — do not customize per agent.

---

## Story 105-3: End-to-End Smoke Test

### Test Scenarios

**Scenario A: TDD green phase (gate = tests_pass)**
1. Create a mock session file with assessment written
2. Run `handoff-cli.sh resolve-gate {id} tdd green`
3. Verify: `status: ready`, `gate_type: tests_pass`, `next_agent: reviewer`, `next_phase: review`

**Scenario B: Trivial implement phase (gate = tests_pass)**
1. Create a mock session file
2. Run `handoff-cli.sh resolve-gate {id} trivial implement`
3. Verify: `status: ready`, `gate_type: tests_pass`, `next_agent: reviewer`

**Scenario C: Missing assessment**
1. Create a session file WITHOUT assessment section
2. Run `handoff-cli.sh resolve-gate {id} tdd green`
3. Verify: `status: blocked`, `assessment_found: false`, exit code 1

**Scenario D: Manual gate (skip)**
1. Run `handoff-cli.sh resolve-gate {id} patch fix`
2. Verify: `status: skip`

**Scenario E: complete-phase atomic update**
1. Run `handoff-cli.sh complete-phase {id} tdd green review tests_pass`
2. Verify session file updated with new phase, timestamps, history rows

### Test Location

`pennyfarthing-dist/scripts/tests/` — follow existing test pattern (see `epics-and-stories-workflow-import.test.sh`)

## Gate Types Across Workflows (Reference)

| Gate Type | Used In | Phase | Meaning |
|-----------|---------|-------|---------|
| `tests_fail` | tdd, bdd, 2party-tdd | red | Tests are RED |
| `tests_pass` | tdd, trivial, bdd | green/implement | Tests are GREEN |
| `approval` | tdd, trivial, bdd, 2party-tdd | review | Human approved |
| `manual` | patch | fix | No automated check |
| `design_review` | bdd | design | UX spec complete |
| `quality_pass` | 2party-tdd | verify | Full CI gates pass |
| `validation` | agent-docs | implement | Files parse correctly |

## Dependencies

- **No blockers** — this epic creates new infrastructure alongside existing
- **Blocked by nothing** — handoff.md stays functional during migration
- **Blocks:** Epic 106 (gate files reference resolve-gate's `gate_file` field)
- **Blocks:** Epic 108 (cleanup requires all agents using new protocol)

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Session file format varies | High | Grep exact patterns, test against real session files |
| yq version differences | Medium | Pin to `yq` v4 syntax, test in CI |
| Agent files have custom exit logic | Medium | Reviewer has merge step — preserve, wrap in new protocol |
| Bulk agent update breaks something | High | 105-3 smoke test validates before shipping |
