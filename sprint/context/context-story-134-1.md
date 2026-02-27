---
parent: context-epic-134.md
workflow: tdd
---

# Story 134-1: Add Impact Summary compilation to SM finish flow

## Business Context

The boss reviews completed stories to understand what implementation revealed about the broader system. Epic 133 gave agents the ability to capture structured Delivery Findings in R1 format. But raw findings aren't optimized for quick scanning — the boss still has to read each finding line by line and mentally tally types and blocking status.

Story 134-1 adds the compilation step: during SM's finish flow, the `sm-finish` subagent reads all Delivery Findings from the session file, counts them by type, identifies blocking items, and writes a `## Impact Summary` section. The boss reads this section and understands the story's upstream effects in 30 seconds.

This is the foundation for 134-2 (PR body generation) which will embed the Impact Summary into the PR description.

## Technical Guardrails

### Key Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing-dist/agents/sm-finish.md` | Add Impact Summary compilation step to finish flow |
| `pennyfarthing-dist/agents/sm.md` | Update finish flow documentation to reference Impact Summary |

### Key Files to Consume (Read-Only)

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/src/pf/findings/capture.py` | `parse_delivery_findings()` — extracts structured findings from session markdown |
| `.session/{story-id}-session.md` | Source of Delivery Findings section |

### Patterns to Follow

- Use `pf.findings.capture.parse_delivery_findings()` to extract findings — do NOT parse findings manually
- Impact Summary format must match FR1-FR7 from the PRD exactly (see AC Context below)
- R6 guardrail: Summary is compiled verbatim from findings. SM reads and summarizes, does not editorialize or reinterpret
- Backward compatibility: sessions without `## Delivery Findings` must not cause errors — generate "No upstream effects noted"
- Result-object pattern: any new Python functions must return `{success, data?, error?}`

### What NOT to Touch

- `pf.findings.capture` module (Epic 133, complete — read-only dependency)
- Agent exit behaviors in tea.md, dev.md, reviewer.md (Epic 133)
- PR body generation (that's 134-2)
- Sprint aggregation (that's Epic 135)

## Scope Boundaries

**In scope:**
- SM finish flow compiles Impact Summary from Delivery Findings
- Impact Summary section written to session file during finish
- Handles: findings present, no findings, blocking findings, missing Delivery Findings section
- Impact Summary section placement: after Delivery Findings, before agent assessments

**Out of scope:**
- PR body generation (134-2)
- Session-artifacts guide documentation (134-3)
- Sprint-level aggregation (Epic 135)
- Late PR creation workflow changes (134-2)

## AC Context

### AC1: Standard Compilation (FR1, FR2, FR4, FR5, FR15)

**Given** a session file with Delivery Findings (e.g., 1 Gap blocking, 1 Conflict non-blocking, 1 Improvement non-blocking)
**When** SM runs the finish phase
**Then** `sm-finish` writes `## Impact Summary` containing:
- `**Upstream Effects:** 3 findings (1 Gap, 1 Conflict, 0 Question, 1 Improvement)`
- One line per finding: `- **{Type}:** {description}. Affects \`{path}\`.`

**Edge cases:**
- Multiple findings of the same type — count correctly
- Findings from different agents — all included regardless of source
- Findings with long descriptions — one line each, no truncation

### AC2: Blocking Items (FR3)

**Given** a session file with a blocking finding
**When** SM runs the finish phase
**Then** Impact Summary contains `**BLOCKING:**` on a dedicated line before the finding list
**And** blocking findings are listed first

**Edge cases:**
- Multiple blocking items — all listed under BLOCKING prefix
- Mix of blocking and non-blocking — blocking first, then non-blocking

### AC3: No Findings (FR6)

**Given** a session file where all agents wrote "No upstream findings"
**When** SM runs the finish phase
**Then** Impact Summary contains:
- `**Upstream Effects:** No upstream effects noted`
- `**Blocking:** None`

### AC4: Missing Section Backward Compat

**Given** a session file without a `## Delivery Findings` section (legacy)
**When** SM runs the finish phase
**Then** Impact Summary still generates with "No upstream effects noted"
**And** no error is raised

### AC5: Section Placement (R5)

**Given** SM compiles the Impact Summary
**When** writing the section to the session file
**Then** it is placed after `## Delivery Findings` and before agent assessment sections

### AC6: Archive Preservation (FR7)

**Given** a completed session file with Impact Summary
**When** the session is archived
**Then** the archived file preserves the Impact Summary section intact

### AC7: Verbatim Compilation (R6)

**Given** findings with specific descriptions
**When** SM compiles the Impact Summary
**Then** finding descriptions are taken verbatim from R1 entries — not reworded, summarized, or editorially enhanced
