# Epic 131: Gate-Enforced Context Pipeline

## Overview

Wire the validator and creation skill into the gate system so context is enforced, not optional. SM's setup gate checks for epic and story context before handoff. TEA's gate checks for validated story context before RED phase. When context is missing, SM auto-triggers creation. This is the integration epic — it makes the pipeline mandatory.

**Priority:** P1
**Repo:** pennyfarthing
**Stories:** 3 (6 points)

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **PRD** (`sprint/planning/context-gate-prd.md`) | FR1-FR5 (gate validation), FR6 (SM triggers creation), FR4 (TEA gate), Journey 1 (SM happy path), Journey 4 (TEA consumption), Journey 5 (epic context cascade), Gate Strategy section |
| **ADR-0029** (`docs/adr/0029-context-gate-architecture.md`) | Component structure diagram (lines 81-108), consistency rules 3-4 and 6, implementation plan items 7-8 |

## Background

### Current Gate State

The `sm-setup-exit` gate (`pennyfarthing-dist/gates/sm-setup-exit.md`) already has a `story-context-exists` check (lines 21-24) that verifies:
- `sprint/context/context-epic-{N}.md` exists
- Session file contains technical approach section
- Session file contains acceptance criteria

But this check is basic file existence — no section validation, no content quality check. And TEA has no gate at all for context validation.

### The Cascade Pattern

SM's gate runs a sequential cascade:
1. Check epic context → if missing, trigger `/pf-context create epic {N}`
2. Check story context → if missing, trigger `/pf-context create story {N-N}`
3. Re-run validation → if still invalid, fail with manual-creation message

One attempt per level (Rule #6). No retry loops.

### TEA's Role

TEA currently reads story context opportunistically — "Read story from session file" (`agents/tea.md` line 83). There's no enforcement. After this epic, TEA gets a gate that validates story context exists and passes schema validation before RED phase proceeds. TEA then reads both story and epic context as primary input for test strategy.

## Technical Architecture

### Gate Flow

```
SM Agent activates for story setup
  |
  v
pf handoff resolve-gate {story-id} {workflow} setup
  |
  v
sm-setup-exit gate runs checks:
  1. session-exists          (existing)
  2. session-fields-set      (existing)
  3. epic-context-validated   <-- UPDATED (was: story-context-exists)
     |  calls: pf context-docs validate epic {N}
     |  exit 0 → pass
     |  exit 2 → trigger: /pf-context create epic {N}
     |  exit 1 → fail with validation errors
     |  re-validate after creation
     |
  4. story-context-validated  <-- NEW
     |  calls: pf context-docs validate story {N-N}
     |  exit 0 → pass
     |  exit 2 → trigger: /pf-context create story {N-N}
     |  exit 1 → fail with validation errors
     |  re-validate after creation
     |
  5. branch-created          (existing)
  |
  v
All pass → handoff to TEA
  |
  v
TEA activates for RED phase
  |
  v
tea-context gate runs:                               <-- NEW GATE
  1. story-context-validated
     |  calls: pf context-docs validate story {N-N}
     |  exit 0 → pass, TEA reads context
     |  exit 1/2 → fail (SM should have handled this)
  |
  v
TEA reads context-epic-{N}.md + context-story-{N-N}.md
  → Writes test strategy informed by full technical context
```

### Key Files (Existing, to be Modified)

| File | Path | Lines | Change |
|------|------|-------|--------|
| SM setup exit gate | `pennyfarthing-dist/gates/sm-setup-exit.md` | 82 | Replace `story-context-exists` check with two validated checks (epic + story). Add cascade logic: validate → create on failure → re-validate |
| TEA agent definition | `pennyfarthing-dist/agents/tea.md` | 154 | Add context loading instructions: read `context-story-{N-N}.md` and `context-epic-{N}.md` during RED phase |
| SM agent definition | `pennyfarthing-dist/agents/sm.md` | 278 | Update pre-handoff checklist to reference new cascade behavior |

### Key Files (New)

| File | Path | Purpose |
|------|------|---------|
| TEA context gate | `pennyfarthing-dist/gates/tea-context.md` | Gate definition — validates story context before RED phase |

### Key Files (Reference/Consumed)

| File | Path | Purpose |
|------|------|---------|
| Validator CLI | `pf/context_docs/cli.py` | `pf context-docs validate {type} {id}` — called by gates (from Epic 129-3) |
| Context skill | `pennyfarthing-dist/skills/pf-context/skill.md` | `/pf-context create {type} {id}` — invoked by SM on failure (from Epic 130) |
| Gate guide | `pennyfarthing-dist/guides/gates.md` | Gate definition format and conventions |
| Handoff CLI guide | `pennyfarthing-dist/guides/handoff-cli.md` | `pf handoff resolve-gate` integration |

### Gate-Calls-Script Pattern

Per ADR-0029 Rule #4: Gates call CLI, not Python directly. The gate definition instructs the agent to run `pf context-docs validate epic {N}` and interpret exit codes. Gate logic stays simple — validator handles the details.

**Gate check format:**
```markdown
### Check: epic-context-validated
Run: `pf context-docs validate epic {epic_id}`
- Exit 0: PASS
- Exit 2 (not found): Run `/pf-context create epic {epic_id}`, then re-validate
- Exit 1 (invalid): FAIL — report validation errors to operator
- Creation attempted and re-validation fails: FAIL — "Manual fix required"
```

### SM Auto-Trigger Flow (131-2)

When SM's gate detects missing context:

1. SM runs `pf context-docs validate epic {N}` → exit 2 (not found)
2. SM invokes `/pf-context create epic {N}` (skill from Epic 130-1)
3. SM re-runs `pf context-docs validate epic {N}` → exit 0 (pass) or exit 1 (fail)
4. If pass → proceed to story context check
5. If fail → report errors, stop. "Context creation produced invalid output. Manual fix required at sprint/context/context-epic-{N}.md"

Same pattern for story context, after epic passes.

**Key constraint:** ONE attempt per level (Rule #6). No retry loops. If creation produces invalid output, the operator fixes it manually.

### TEA Context Consumption (131-3)

TEA agent definition update adds explicit context loading to the RED phase workflow:

```
1. Read session file for story context
2. Read context-story-{N-N}.md — primary input for test strategy
3. Read context-epic-{N}.md — understand cross-story constraints
4. Extract: technical guardrails, scope boundaries, AC context
5. Write test strategy informed by full context
```

TEA's gate is simpler than SM's — no creation trigger. If story context is missing at TEA activation, something went wrong in SM setup. Gate fails with clear message: "Story context not found. SM setup gate should have created this."

## Stories

| Story | Title | Points | Workflow | Dependencies |
|-------|-------|--------|----------|-------------|
| 131-1 | Update sm-setup-exit Gate with Context Validation Cascade | 2 | trivial | 129-1 (bug fixes), 129-3 (validator CLI) |
| 131-2 | SM Auto-Triggers Context Creation on Gate Failure | 2 | tdd | 131-1, 130-2 (creation skill) |
| 131-3 | TEA Context Gate and Agent Integration | 2 | tdd | 129-3 (validator CLI) |

## Story Notes

### 131-1: Update sm-setup-exit Gate with Context Validation Cascade

**What to do:** Replace the existing `story-context-exists` check in `sm-setup-exit.md` with two new checks: `epic-context-validated` and `story-context-validated`. Each calls `pf context-docs validate` and interprets exit codes. This story adds the gate checks only — auto-trigger is 131-2.

**Gate recovery actions update:**
- Old: "Write context" (vague)
- New: "Run `/pf-context create epic {N}` or `/pf-context create story {N-N}`" (actionable)

**Key constraint:** Gate stays pure pass/fail. The gate checks and reports — it doesn't create. SM (the calling agent) acts on failure.

### 131-2: SM Auto-Triggers Context Creation on Gate Failure

**What to do:** Update SM agent behavior so that when `sm-setup-exit` gate reports `epic-context-validated` or `story-context-validated` as failed (exit 2 = not found), SM automatically invokes `/pf-context create` for the missing level, then re-runs the gate.

**Failure messaging:**
- Creation succeeded, re-validation passed: continue silently
- Creation succeeded, re-validation failed: "Context created but has validation errors. Manual fix needed at {path}"
- Creation failed: "Context creation failed. Run `/pf-context create {type} {id}` manually"

**Key constraint:** One attempt per level, then fail (Rule #6). No retry loops.

### 131-3: TEA Context Gate and Agent Integration

**What to do:** Two changes:
1. Create `tea-context.md` gate definition that validates story context via `pf context-docs validate story {id}`
2. Update `tea.md` agent definition to explicitly read epic and story context during RED phase

**Gate behavior:** Fail-only — no creation trigger. If context is missing, SM setup didn't complete properly. Message: "Story context not found. Ensure SM setup completed successfully."

**Agent update:** Add context loading as step 1 of TEA's RED phase workflow (before "Read story from session file"). TEA reads both `context-story-{N-N}.md` and `context-epic-{N}.md` as primary inputs for test strategy.

## Constraints

- **Gates call CLI, not Python** (Rule #4): `pf context-docs validate` is the interface
- **One attempt per level** (Rule #6): SM tries creation once, then fails with actionable message
- **Gate stays pure pass/fail:** Gate checks — calling agent acts
- **TEA gate is fail-only:** No creation trigger at TEA level
- **Backward compatible:** Existing gate checks (session-exists, session-fields-set, branch-created) unchanged

## Cross-Epic Dependencies

**Depends on:**
- Epic 129-1 (Bug Fixes) — accurate `hasContext` display after gate passes
- Epic 129-3 (Validator CLI) — `pf context-docs validate` command
- Epic 130-2 (Story Creation Skill) — `/pf-context create` invoked by SM on failure

**Depended on by:**
- Nothing. This is the enforcement layer — the end of the pipeline.
