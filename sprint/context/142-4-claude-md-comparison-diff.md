# CLAUDE.md Comparison Diff — BMAD vs Pennyfarthing Dev Pipelines

**Story:** 142-4 (Context Parity Verification)
**Date:** 2026-03-10
**Purpose:** Annotated diff of what each pipeline's dev agent receives as CLAUDE.md context, categorized by source and with fairness rationale.

## Methodology

This comparison is based on:
- **BMAD side:** The `build_bmad_dev_claude_md()` function in `pennyfarthing-dist/src/pf/benchmark/bmad_adapter.py`, which assembles CLAUDE.md from verbatim BMAD source files at pinned commit `b7315c6e`
- **PF side:** The `pf agent start dev` activation output, which loads agent definition, persona, sidecars, session context, and repos topology
- **BMAD source:** `/Users/keithavery/Projects/BMAD-METHOD/` at commit `b7315c6e329eb72dc464f4e540bb67cdd22a9749`

No actual benchmark runs have been executed yet (runs begin in story 142-5). This comparison works from the **templates and builders** that will produce the CLAUDE.md files, which is deterministic — the builders inject source files verbatim with no randomization.

---

## Section-by-Section Comparison

### 1. Agent Identity / Persona

| Aspect | BMAD Dev Agent | PF Dev Agent | Category |
|--------|---------------|--------------|----------|
| **Character name** | "Amelia" | Theme-dependent (e.g., "Reverend Mother Gaius Helen Mohiam" in Dune theme) | **Intentional difference** |
| **Role** | Senior Software Engineer | Developer — Feature implementation, making tests pass, code changes | **Equivalent** |
| **Identity statement** | "Executes approved stories with strict adherence to story details and team standards" | "You are not here to write clever code. You are here to make tests pass." | **Equivalent** (different phrasing, same intent) |
| **Communication style** | "Ultra-succinct. Speaks in file paths and AC IDs — every statement citable. No fluff, all precision." | Not explicitly specified (output style controlled by separate output-styles system) | **BMAD-only** |
| **Principles** | "All tests must pass 100%", "Every task/subtask must be covered by comprehensive unit tests" | "Shipping beats perfection. Wire it up, make it work, move on." | **Equivalent** (both enforce test-passing, PF adds minimalism principle) |

**Rationale:** Persona differences are the variable under test. BMAD's "Amelia" is a static professional identity. PF's themed personas are a framework feature — whether themed personas affect code quality is part of what the comparison measures.

---

### 2. Critical Actions / Behavioral Rules

| BMAD Critical Action | PF Equivalent | Category |
|---------------------|---------------|----------|
| "READ the entire story file BEFORE any implementation" | Session file loaded at activation; context read during prime | **Equivalent** |
| "Execute tasks/subtasks IN ORDER as written" | No explicit ordering rule — PF agents follow ACs, not task lists | **BMAD-only** |
| "Mark task/subtask [x] ONLY when implementation AND tests pass" | Gate system enforces GREEN state before phase transition | **Equivalent mechanism** |
| "Run full test suite after each task" | `testing-runner` subagent verifies GREEN state | **Equivalent mechanism** |
| "Execute continuously without pausing" | No explicit rule (PF agents naturally run to completion within a phase) | **BMAD-only** |
| "Document in Dev Agent Record" | Session file updated with Dev Assessment before handoff | **Equivalent mechanism** |
| "Update File List with ALL changed files" | Not explicitly required (git tracks changes) | **BMAD-only** |
| "NEVER lie about tests being written or passing" | `testing-runner` subagent provides independent verification | **Equivalent mechanism** |

**Rationale:** BMAD's 8 critical actions are explicit behavioral guardrails embedded in the prompt. PF achieves similar outcomes through architectural mechanisms (gates, subagents, session protocol) rather than prompt-level rules. This is a legitimate architectural difference — embedded rules vs. structured workflow.

---

### 3. Workflow Instructions

| Aspect | BMAD | PF | Category |
|--------|------|-----|----------|
| **Format** | 10-step XML workflow in `dev-story/workflow.md` (~200 lines) | Agent definition with `<workflow>` section (~30 lines) | **Intentional difference** |
| **Step 1: Find story** | Load story from sprint-status or story_path | Session file pre-loaded at activation | **Equivalent** |
| **Steps 2-4: Load context** | Load project context, check for review continuation, mark in-progress | Prime loads context; SM marks in-progress before handoff | **Equivalent mechanism** |
| **Steps 5-7: Red-Green-Refactor** | Embedded TDD cycle within dev step | Separate TEA phase (RED) → Dev phase (GREEN) | **PF-only** (phase separation) |
| **Steps 8-9: Validate + Complete** | Run full test suite, validate against checklist | `testing-runner` subagent + gate system | **Equivalent mechanism** |
| **Step 10: Communication** | Prepare completion summary for user | Dev Assessment written to session file | **Equivalent** |
| **Total workflow size** | ~200 lines of detailed XML steps | ~30 lines of phase workflow + gate definitions | **Intentional difference** |

**Rationale:** BMAD's workflow is verbose and prescriptive — every step is explicitly defined with branching logic. PF's workflow is concise and relies on the gate system and agent handoffs to enforce quality. Both are legitimate approaches. The judge scores against ground truth regardless of workflow verbosity.

---

### 4. Quality Checklists / Gates

| Aspect | BMAD | PF | Category |
|--------|------|-----|----------|
| **Mechanism** | `checklist.md` — 25-item Definition of Done applied at step 9 | Gate system — `gates/dev-exit` enforces tests green, clean tree, no debug code, correct branch | **Intentional difference** |
| **Context validation** | 4 items (story completeness, architecture compliance, tech specs, previous learnings) | Gate checks session file fields populated | **Equivalent** |
| **Implementation checks** | 5 items (all tasks complete, AC satisfaction, no ambiguity, edge cases, dependencies) | Self-review checklist: code wired up, patterns followed, ACs met, error handling | **Equivalent** |
| **Testing checks** | 7 items (unit, integration, e2e, coverage, regression, code quality, framework compliance) | `testing-runner` subagent runs full suite; gate checks GREEN state | **Equivalent mechanism** |
| **Documentation checks** | 5 items (file list, dev record, change log, review follow-ups, structure compliance) | Dev Assessment template in session file | **BMAD-only** (more detailed documentation tracking) |
| **Final status** | 5 items (status update, sprint update, quality gates, no HALT, communication) | `pf handoff complete-phase` transitions phase; `pf handoff marker` routes to next agent | **Equivalent mechanism** |

**Rationale:** BMAD has a more detailed, explicit checklist (25 items). PF relies on automated gates plus a shorter judgment-based self-review. Whether explicit checklists outperform automated gates is part of what the comparison measures.

---

### 5. Project Context / Story Information

| Content | BMAD Source | PF Source | Category |
|---------|------------|-----------|----------|
| **Story requirements** | BMAD-format story file at `implementation_artifacts/{story_key}.md` | Session file + story context doc | **Equivalent** |
| **Acceptance criteria** | In story file `## Acceptance Criteria` (copied verbatim from scenario) | In session file and story context doc (same source) | **Equivalent** |
| **Technical notes** | In story file `## Dev Notes` (combined from epic + story context) | Separate epic context + story context docs | **Equivalent** |
| **Coding standards** | `project-context.md` (target project standards) | Loaded via CLAUDE.md of target project | **Equivalent** |
| **Tasks/Subtasks** | Empty (per ADR-0035 — avoids bias through our task decomposition) | Not applicable (PF agents derive tasks from ACs) | **Neutral** |

**Rationale:** Both agents receive the same substantive information — the same acceptance criteria, the same technical context, the same coding standards. The packaging differs (single story file vs. separate context docs) but the content is equivalent. This is confirmed by the axiathon context verification (see companion document).

---

### 6. Framework-Specific Context

#### PF-Only Content (not present in BMAD CLAUDE.md)

| Content | Source | Fairness Assessment |
|---------|--------|-------------------|
| **Themed persona** (e.g., Dune characters) | `pennyfarthing-dist/personas/{theme}/dev.md` | Framework feature under test — may or may not affect quality |
| **Sidecars** (patterns, gotchas, decisions) | `.pennyfarthing/sidecars/dev/` | Legitimate framework advantage — accumulated institutional knowledge |
| **Session file** with workflow state | `.session/{story}-session.md` | Framework feature — provides structured context |
| **Repos topology** | `.pennyfarthing/repos.yaml` | Project infrastructure — prevents cross-repo edits |
| **Gate system** | Phase transition quality checks | Quality mechanism under test |
| **Tandem protocol** | Background observer pairing (if configured) | Framework feature (not used in benchmark runs) |
| **Bell mode / relay mode** | Message injection and auto-handoff | Framework features (not used in benchmark runs) |
| **Crew/character references** | Agent-to-agent character names | Part of themed persona system |

#### BMAD-Only Content (not present in PF CLAUDE.md)

| Content | Source | Fairness Assessment |
|---------|--------|-------------------|
| **8 critical actions** | `dev.agent.yaml` → `critical_actions` | Behavioral guardrails — PF achieves similar via gates/subagents |
| **25-item Definition of Done checklist** | `dev-story/checklist.md` | Quality mechanism — PF uses gate system instead |
| **10-step XML workflow** | `dev-story/workflow.md` | Detailed prescriptive workflow — PF uses concise phase definitions |
| **Story file Tasks/Subtasks section** | Empty (per ADR-0035) | BMAD structural expectation — left empty to avoid bias |
| **Dev Agent Record / File List sections** | Empty (populated during execution) | BMAD documentation mechanism |
| **Communication style directive** | `dev.agent.yaml` → `persona.communication_style` | Agent personality detail |

---

## Summary

| Category | Count | Examples |
|----------|-------|---------|
| **Equivalent** | 8 | Role definition, AC content, technical notes, coding standards, test enforcement, story context, completion tracking, status transitions |
| **Equivalent mechanism** | 6 | Task ordering (BMAD: explicit rules → PF: gates), test verification (BMAD: critical action → PF: testing-runner), documentation (BMAD: Dev Agent Record → PF: Dev Assessment) |
| **BMAD-only** | 5 | Communication style directive, continuous execution rule, file list tracking, detailed 25-item checklist, 10-step XML workflow |
| **PF-only** | 8 | Themed persona, sidecars, session file, repos topology, gate system, TEA phase separation, tandem protocol, crew references |
| **Intentional difference** | 3 | Persona system, workflow verbosity, quality mechanism format |

### Conclusion

**Context is controlled.** Both agents receive equivalent project knowledge: the same acceptance criteria, technical context, and coding standards. The differences fall into two categories:

1. **Framework features under test** — persona themes, sidecars, gate system, phase separation (PF) vs. explicit critical actions, detailed checklists, prescriptive workflow (BMAD). These are the independent variables the comparison is designed to measure.

2. **Packaging differences** — single story file vs. separate context docs, embedded rules vs. architectural mechanisms. These are structural differences that don't advantage either pipeline.

No unfair advantages detected. The comparison is defensible.
