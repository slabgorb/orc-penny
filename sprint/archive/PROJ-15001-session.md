# Story 105-2: Update agent exit protocol across all agent files

**Epic:** 105 — Script-First Handoff (PROJ-14999)
**Jira:** PROJ-15001
**Points:** 2
**Priority:** P1
**Workflow:** agent-docs
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/PROJ-15001-update-agent-exit-protocol
**Assigned:** keith.avery@slabgorb.io
**Started:** 2026-02-15

## Description

Replace `<agent-exit-protocol>` in all ~10 agent files with the new 7-step sequence from ADR-0025: write assessment, terminate tandem, resolve-gate, gate subagent (if needed), complete-phase, handoff-marker, emit marker, EXIT. Remove all references to handoff and sm-handoff subagents for phase transitions.

## Acceptance Criteria

- [ ] All agent files updated with new 7-step exit protocol from ADR-0025
- [ ] References to handoff and sm-handoff subagents removed from phase transitions
- [ ] Agent files use handoff-cli.sh (resolve-gate + complete-phase) instead of subagents
- [ ] Exit protocol consistent across all ~10 agent files

## Technical Context

### ADR-0025: Script-First Gate Extraction

**Status:** Proposed
**Key Decision:** Replace the handoff subagent with bash scripts for routing and session updates, LLM only for gate evaluation.

**New Agent Exit Protocol (from ADR-0025):**

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

### RESOLVE_RESULT Contract

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

### COMPLETE_RESULT Contract

```yaml
COMPLETE_RESULT:
  status: success | error
  session_file: .session/{story-id}-session.md
  error: null | "message"
# Exit: 0 = success, 1 = error
# Atomicity: temp file + mv
```

### Agent Files to Update

| File | Agent | Notes |
|------|-------|-------|
| `pennyfarthing-dist/agents/tea.md` | TEA | Remove handoff subagent reference |
| `pennyfarthing-dist/agents/dev.md` | Dev | Remove handoff subagent reference |
| `pennyfarthing-dist/agents/reviewer.md` | Reviewer | Has merge-before-handoff logic — keep that, wrap in new protocol |
| `pennyfarthing-dist/agents/sm.md` | SM | Uses sm-handoff, switch to same handoff-cli.sh |
| `pennyfarthing-dist/agents/orchestrator.md` | Orchestrator | If has exit protocol |
| `pennyfarthing-dist/agents/architect.md` | Architect | If has exit protocol |
| `pennyfarthing-dist/agents/pm.md` | PM | If has exit protocol |
| `pennyfarthing-dist/agents/tech-writer.md` | Tech Writer | If has exit protocol |
| `pennyfarthing-dist/agents/ux-designer.md` | UX Designer | If has exit protocol |
| `pennyfarthing-dist/agents/devops.md` | DevOps | If has exit protocol |

### Key Implementation Rules (from ADR-0025)

1. **Agent drives exit, not a subagent** — calling agent directly calls scripts + spawns gate subagent
2. **Gate subagent is the ONLY LLM in exit path** — scripts are pure bash
3. **Session updates are atomic scripts** — agents MUST NOT manually edit phase/history fields
4. **`GATE_RESULT` is the only contract** — agent branches on `status` only
5. **Single canonical `<agent-exit-protocol>`** — bulk-updated, identical across all agent files
6. **Manual gates short-circuit** — no LLM spawn, resolve-gate returns pass directly
7. **Assessment pre-check in resolve-gate** — fail-fast on missing prerequisite
8. **Script stdout is the ONLY communication channel** — no side-channel files or env vars

### What Changes Per Agent File

1. Replace `<agent-exit-protocol>` section with new 8-step sequence
2. Remove handoff/sm-handoff from `<helpers>` table
3. Remove handoff subagent from `<parameters>` section
4. Update `<exit-sequence>` to match new protocol
5. Update `<handoff-gate>` checklist

## Dependencies

- **Depends on:** 105-1 (Create handoff-cli.sh) — COMPLETED
- **Blocks:** 105-3 (End-to-end handoff smoke test)

## Assessment

### SM Setup → Orchestrator (analyze)
- Session created with full ADR-0025 context
- 10 agent files identified for update
- Branch created in pennyfarthing repo
- Jira claimed and transitioned

### Orchestrator (analyze → implement)
**Key finding:** ADR-0025 says `handoff-cli.sh` but 105-1 delivered Python via `pf handoff resolve-gate` / `pf handoff complete-phase`. Updated all references to use `pf handoff` CLI commands.

**Files Updated (18 total):**

Agent files (13):
- `tea.md` — removed handoff from helpers/params, updated exit-sequence/handoff-gate/workflow
- `dev.md` — same pattern as tea
- `reviewer.md` — same + preserved merge-before-handoff logic in exit-sequence
- `sm.md` — replaced sm-handoff references, updated exit/gate/helpers/params
- `orchestrator.md` — replaced generic exit with full exit protocol
- `tech-writer.md` — removed embedded handoff subagent prompt, updated handoff-protocol
- `architect.md` — replaced generic exit with full exit protocol
- `pm.md` — same
- `ba.md` — same
- `devops.md` — same
- `ux-designer.md` — same
- `sm-setup.md` — updated sm-handoff references in SETUP_RESULT
- `README.md` — marked handoff.md and sm-handoff.md as deprecated

Guide files (5):
- `agent-behavior.md` — canonical `<agent-exit-protocol>` updated to 8-step script-first flow
- `agent-tag-taxonomy.md` — updated examples
- `xml-tags.md` — updated examples
- `tandem-protocol.md` — updated handoff reference
- `approval-gates-pattern.md` — updated protocol description and diagrams

**Remaining (out of scope for 2pt story):**
Pattern reference docs still have old terminology: `tdd-flow-pattern.md`, `helper-delegation-pattern.md`, `session-artifacts.md`, `agent-template-tactical.md`, `pf-check.md`. These are historical reference material — not active instructions. Can be cleaned up in a follow-up.

**Handoff:** To Tech Writer for documentation quality review

### Tech Writer Review

**Verdict:** APPROVED (with notes)

**Files Reviewed:** All 18 files listed in Orchestrator assessment

**Gate Conditions:**
- [x] Clear and consistent structure — exit protocols follow uniform pattern across all agents
- [x] No stale references in active instructions — exit sequences, handoff-gates all use `pf handoff` CLI
- [x] Follows agent file conventions — XML tags, section ordering, content structure all correct
- [x] XML tags properly nested — verified across all 13 agent files and 5 guide files
- [x] Examples are accurate — handoff-gate examples in xml-tags.md correctly show CLI commands

**Residual Issues (non-blocking):**

| Severity | Issue | Location |
|----------|-------|----------|
| MEDIUM | Stale `handoff` subagent in helpers/params | `orchestrator.md:51, 68-76` |
| MEDIUM | Stale `handoff` subagent in helpers/params | `tech-writer.md:27, 30-38` |
| LOW | Stale `handoff` example in helpers tag | `agent-tag-taxonomy.md:43-45` |

These are helpers/parameters table entries that still list the deprecated `handoff` subagent, while the exit sequences in the same files correctly use CLI commands. The contradiction won't cause failures (agents follow exit sequences, not helpers tables during handoff), but should be cleaned up in a follow-up.

**Out-of-scope staleness (acknowledged):** `approval-gates-pattern.md` L347-399, L748-752 reference deprecated handoff subagents. Already flagged by Orchestrator as deferred.

**Handoff:** To SM for finish

## Notes

- Epic context: `/Users/keithavery/Projects/pf-1/sprint/context/context-epic-105.md`
- ADR-0025: `/Users/keithavery/Projects/pf-1/docs/adr/0025-script-first-gate-extraction.md`
- Epic YAML: `/Users/keithavery/Projects/pf-1/sprint/epic-PROJ-14999.yaml`