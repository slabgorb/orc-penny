# ADR-0035: BMAD vs Pennyfarthing Pipeline Comparison Methodology

**Status:** Accepted
**Date:** 2026-03-10
**Author:** Dev (Reverend Mother Gaius Helen Mohiam)
**Epic:** 142 (PROJ-16324)

## Context

Management approved BMAD as the team's agent framework. Engineers are encountering limitations in BMAD's dev loop but have no quantitative evidence to support adopting Pennyfarthing. Anecdotal feedback is insufficient for a framework adoption decision.

Pennyfarthing has Peloton — a benchmark replay infrastructure that runs scenarios against real code at known commits, scored against ground truth. This ADR documents the methodology for extending Peloton to support a BMAD pipeline variant, enabling a controlled head-to-head comparison.

### Goal

Run identical scenarios through both pipelines, scored by the same judge, against the same ground truth. If BMAD wins, we learn. If Pennyfarthing wins, we have the data.

## Decision

### BMAD Source Files

All BMAD source files are taken verbatim from the BMAD-METHOD repository.

**Pinned commit:** `b7315c6e329eb72dc464f4e540bb67cdd22a9749`
**Repository:** `/Users/keithavery/Projects/BMAD-METHOD/`

| File | Purpose | Rationale |
|------|---------|-----------|
| `src/bmm/agents/dev.agent.yaml` | "Amelia" persona — Senior Software Engineer identity, communication style, critical actions, menu triggers | This is the complete dev agent definition. Contains persona, principles, and workflow routing. |
| `src/bmm/workflows/4-implementation/dev-story/workflow.md` | 10-step dev workflow (find story → load context → detect review continuation → mark in-progress → red-green-refactor → author tests → run validations → validate completion → mark for review → completion communication) | This is the authoritative dev execution workflow. Contains all XML step definitions with branching logic. |
| `src/bmm/workflows/4-implementation/dev-story/checklist.md` | Enhanced Definition of Done checklist (context validation, implementation completion, testing & QA, documentation, final status verification) | Quality gate applied at step 9 before marking story complete. |
| `src/bmm/workflows/4-implementation/code-review/workflow.md` | 5-step adversarial review workflow (load story → build attack plan → execute review → present findings and fix → update status) | This is the authoritative reviewer workflow. Explicitly adversarial — "find 3-10 specific issues minimum." |
| `src/bmm/workflows/4-implementation/code-review/checklist.md` | Senior Developer Review validation checklist (story loading, context verification, AC cross-check, code quality, security, outcome) | Quality gate for the review workflow. |

**Files NOT used (and why):**

| File | Reason Excluded |
|------|-----------------|
| `src/bmm/workflows/4-implementation/create-story/` | Planning phase — we test dev loop only, not planning |
| `src/bmm/workflows/4-implementation/sprint-planning/` | Planning phase |
| `src/bmm/workflows/4-implementation/sprint-status/` | Sprint tracking — not relevant to code quality comparison |
| `src/bmm/workflows/4-implementation/correct-course/` | Sprint management |
| `src/bmm/workflows/4-implementation/retrospective/` | Sprint ceremony |
| `_bmad/bmm/config.yaml` | Project-specific config — we provide equivalent context directly |

**Note:** The PRD referenced `instructions.xml` files, but BMAD v6 uses `workflow.md` with embedded `<workflow>` XML tags. The actual source files are markdown, not standalone XML.

### Phase Mapping

BMAD and Pennyfarthing structure their dev loops differently. This is a legitimate architectural difference, not a bias.

| Phase | BMAD | Pennyfarthing |
|-------|------|---------------|
| Test design | Embedded in dev workflow (steps 5-7: red-green-refactor cycle) | Separate TEA agent (RED phase) |
| Implementation | Dev agent (steps 5-8: implement + validate) | Dev agent (GREEN phase) |
| Review | Code review workflow (5 steps, adversarial) | Reviewer agent (adversarial review phase) |
| **Total phases** | **2** (dev, reviewer) | **3** (TEA, dev, reviewer) |

**Why this is fair:** BMAD chose to embed test-writing inside the dev step. Pennyfarthing chose to separate it into a dedicated TEA agent. The judge scores against ground truth findings regardless of which phase caught them. The detection heatmap will reveal whether Pennyfarthing's phase separation provides additional value.

**What we report:**
- **Detection rate** — findings caught / total (primary metric)
- **Per-phase attribution** — which phase caught each finding (heatmap)
- **Cost efficiency** — findings-per-dollar (since BMAD's 2-phase may use fewer tokens)

### Controlled Variables

| Variable | Value | Rationale |
|----------|-------|-----------|
| Model | Claude Opus (same version) for all phases, both pipelines | Eliminates model capability as a confound |
| Scenarios | DPGD-116, DPGD-117 (existing axiathon scenarios) | Pre-existing ground truth, tested infrastructure |
| Judge | Same Peloton judge prompt and scoring rubric | Eliminates judge variation |
| Ground truth | Same findings list per scenario | Single source of truth for what the pipeline should catch |
| Runs per pipeline | 3+ per scenario (6+ per scenario total) | Statistical significance with majority voting |
| Scoring | Multi-judge (3 judges per run, majority vote) | Reduces single-judge noise |
| Worktree | Fresh git worktree per run at same base commit | Identical starting state |

**Variables that intentionally differ:**

| Variable | BMAD | Pennyfarthing | Rationale |
|----------|------|---------------|-----------|
| Agent instructions | BMAD workflow.md + checklist.md | PF agent definitions + sidecars | This IS the variable under test |
| Phase count | 2 (dev, reviewer) | 3 (TEA, dev, reviewer) | Architectural difference — measured, not controlled |
| Persona | "Amelia" (Senior Software Engineer) | Themed persona (e.g., Dune characters) | Framework feature — PF personas are part of its value proposition |
| Workflow engine | None (instructions embedded in CLAUDE.md) | BikeLane phased workflow with session tracking | Framework feature under test |
| Self-checking | checklist.md at step 9 | Gate system at phase transitions | Quality mechanism under test |

### BMAD CLAUDE.md Construction

The BMAD simulator builds a CLAUDE.md by injecting source files verbatim. No Pennyfarthing wrappers, personas, sidecars, or workflow engine context are included.

**BMAD Dev CLAUDE.md structure:**

```
1. Agent persona (from dev.agent.yaml → persona section)
   - Role: Senior Software Engineer
   - Identity: "Executes approved stories with strict adherence..."
   - Communication style: "Ultra-succinct. Speaks in file paths and AC IDs..."
   - Principles: All tests must pass, comprehensive unit tests required

2. Critical actions (from dev.agent.yaml → critical_actions)
   - Read entire story file before implementation
   - Execute tasks in order
   - Mark [x] only when implementation AND tests pass
   - Run full test suite after each task
   - Execute continuously without pausing
   - Document in Dev Agent Record
   - Update File List
   - Never lie about test status

3. Dev workflow (from dev-story/workflow.md — verbatim)
   - Steps 1-10 with full XML workflow tags
   - Initialization, configuration, execution logic

4. Definition of Done checklist (from dev-story/checklist.md — verbatim)
   - Context & requirements validation
   - Implementation completion
   - Testing & QA
   - Documentation & tracking
   - Final status verification

5. Story file content (from scenario context — translated to BMAD format)

6. project-context.md (from target project coding standards)
```

**BMAD Reviewer CLAUDE.md structure:**

```
1. Adversarial reviewer role description (from code-review/workflow.md preamble)
   - "YOU ARE AN ADVERSARIAL CODE REVIEWER"
   - "Find 3-10 specific issues minimum"

2. Code review workflow (from code-review/workflow.md — verbatim)
   - Steps 1-5 with full XML workflow tags

3. Review checklist (from code-review/checklist.md — verbatim)
   - Story loading, context verification, AC cross-check
   - Code quality, security, outcome decision
```

### Story File Translation

BMAD's dev workflow expects a story file in a specific format (from `create-story/template.md`). The axiathon scenario context documents were created from BMAD's planning workflow, so translation is minimal.

**BMAD story file sections → PF context mapping:**

| BMAD Section | Source | Translation Notes |
|--------------|--------|-------------------|
| `## Story` (user story) | Story context → Business Context | Reformat as "As a... I want... so that..." |
| `## Acceptance Criteria` | Epic breakdown → story ACs | Already in Given/When/Then — copy verbatim |
| `## Tasks / Subtasks` | Not pre-populated | Left empty — BMAD's dev workflow step 1 skips to step 6 (test authoring) when no incomplete tasks exist. The LLM will interpret ACs and Dev Notes as implicit work scope. This matches a minimal story file scenario where create-story hasn't run. |
| `## Dev Notes` | Epic context → Technical Architecture + Story context → Technical Guardrails | Combine architectural patterns, key files, coding standards |
| `## Dev Agent Record` | Empty | Populated by BMAD dev agent during execution |
| `## File List` | Empty | Populated by BMAD dev agent during execution |

**Key translation decision:** Tasks/Subtasks are left empty. In BMAD's normal workflow, the create-story agent populates these from the PRD and architecture docs. With an empty task list, BMAD's dev workflow step 1 finds no incomplete tasks and jumps to step 6 (test authoring), then steps 7-9 (validation, completion). In practice, the LLM will interpret the ACs and Dev Notes as implicit work scope and implement accordingly — but the workflow XML does not explicitly derive tasks from ACs. This is a known risk: if the BMAD agent takes the empty-task path too literally, it may skip to completion prematurely. Story 142-4 (Context Parity Verification) will validate actual behavior. Leaving tasks empty still avoids introducing bias through our task decomposition.

**Alternative considered:** Pre-populating tasks from PF's story context. Rejected because (a) our task decomposition would reflect PF's thinking, not BMAD's, and (b) BMAD's dev agent is designed to work with the story file as-is.

### Worktree Setup for BMAD Runs

1. Create a fresh git worktree at the scenario's base commit
2. Write the BMAD-format story file to `implementation_artifacts/{story_key}.md`
3. Create `project-context.md` from the target project's coding standards
4. Pass `story_path` directly in the prompt so BMAD's step 1 skips sprint-status lookup (BMAD's workflow has explicit handling: "if story_path is provided, use story_path directly")
5. No `_bmad/` directory, no `sprint-status.yaml`, no `config.yaml` — these are BMAD project infrastructure, not part of the agent's instructions

### Execution Runbook

```bash
# 1. Run PF pipeline (or reuse existing runs)
pf benchmark replay run scenarios/dpgd-116.yaml
pf benchmark replay run scenarios/dpgd-117.yaml

# 2. Run BMAD pipeline
pf benchmark replay run scenarios/dpgd-116.yaml --pipeline bmad
pf benchmark replay run scenarios/dpgd-117.yaml --pipeline bmad

# 3. Repeat for 3+ runs each (6+ total per scenario)

# 4. Score all runs with multi-judge
pf benchmark replay score --judges 3

# 5. Compare
pf benchmark replay compare --pipeline-a default --pipeline-b bmad
```

Results stored under `bmad/run-N/` directory structure with `pipeline.yaml` metadata including `pipeline: bmad` field.

## Consequences

### Positive

- **Defensible methodology** — every decision documented with rationale
- **Reproducible** — pinned commit, documented source files, runbook
- **Fair** — BMAD gets its own instructions verbatim; PF gets its normal pipeline
- **Extensible** — `--pipeline` flag pattern supports future comparisons (Cursor rules, bare Claude)

### Negative

- **Phase asymmetry** — 2-vs-3 phase comparison may complicate per-phase attribution (mitigated by detection heatmap)
- **No BMAD planning phases** — we only test the dev loop, not the full BMAD lifecycle (explicitly out of scope)

### Neutral

- **Context parity is approximate** — PF's epic + story context is equivalent to BMAD's story file, but not byte-identical. The variable under test is instructions and workflow, not context.

## Appendix A: Context Parity — Side-by-Side Comparison

### What BMAD's Dev Agent Receives

| Content | Source |
|---------|--------|
| Persona ("Amelia", Senior Software Engineer) | `dev.agent.yaml` → persona section |
| Critical actions (8 rules) | `dev.agent.yaml` → critical_actions |
| 10-step dev workflow with XML tags | `dev-story/workflow.md` |
| Definition of Done checklist | `dev-story/checklist.md` |
| Story file (user story, ACs, dev notes) | Translated from scenario context |
| Project coding standards | `project-context.md` |

**NOT included:** PF persona themes, sidecars (patterns/gotchas/decisions), session file, workflow engine state, tandem partner, bell mode, relay mode.

### What PF's Dev Agent Receives

| Content | Source |
|---------|--------|
| Agent definition (role, workflow, exit protocol) | `pennyfarthing-dist/agents/dev.md` |
| Themed persona (e.g., Reverend Mother) | `pennyfarthing-dist/personas/dune/dev.md` |
| Sidecars (patterns, gotchas, decisions) | `.pennyfarthing/sidecars/dev/` |
| Session file (story, ACs, phase, repos) | `.session/{story}-session.md` |
| Epic context (background, architecture) | `sprint/context/context-epic-{N}.md` |
| Story context (guardrails, scope, AC detail) | `sprint/context/context-story-{id}.md` |
| Repos topology | `.pennyfarthing/repos.yaml` |
| Workflow engine state | BikeLane phased workflow |
| Gate system | Phase transition quality checks |

**NOT included:** BMAD workflow XML, BMAD checklist, BMAD persona.

### Annotated Differences

| Difference | Category | Rationale |
|------------|----------|-----------|
| PF includes sidecars (learned patterns/gotchas) | PF-only | Legitimate framework advantage — sidecars accumulate institutional knowledge across sessions |
| PF includes themed persona | PF-only | Framework feature under test — may or may not affect code quality |
| PF separates TEA phase | PF-only | Architectural decision — measured via detection heatmap |
| BMAD embeds TDD in dev workflow | BMAD-only | Architectural decision — steps 5-7 cover red-green-refactor |
| BMAD has explicit Definition of Done checklist | BMAD-only | Quality mechanism — PF uses gate system instead |
| PF has gate system at phase transitions | PF-only | Quality mechanism — BMAD uses checklist at step 9 instead |
| BMAD uses `project-context.md` | Equivalent | PF uses epic/story context docs — same information, different packaging |
| BMAD story file has Tasks/Subtasks | BMAD-only | BMAD agents derive implementation tasks from story file; PF agents derive from ACs + context |

**Conclusion:** Context is controlled. Both agents receive equivalent project knowledge (coding standards, requirements, ACs). The differences are in agent instructions, workflow structure, and quality mechanisms — which are the variables under test.

## Appendix B: BMAD Source File Verification

To verify the BMAD source files haven't changed:

```bash
cd /Users/keithavery/Projects/BMAD-METHOD
git checkout b7315c6e329eb72dc464f4e540bb67cdd22a9749

# Verify files exist
ls src/bmm/agents/dev.agent.yaml
ls src/bmm/workflows/4-implementation/dev-story/workflow.md
ls src/bmm/workflows/4-implementation/dev-story/checklist.md
ls src/bmm/workflows/4-implementation/code-review/workflow.md
ls src/bmm/workflows/4-implementation/code-review/checklist.md
ls src/bmm/workflows/4-implementation/create-story/template.md
```

## References

- PRD: `sprint/planning/bmad-comparison-prd.md`
- Epic breakdown: `sprint/planning/bmad-comparison-epics.md`
- BMAD integration guide: `sprint/planning/bmad-integration.md`
- ADR-0013: Stepped Workflow Support (BMAD-Inspired): `docs/adr/0013-bmad-workflow-import.md`
- BMAD-METHOD: https://github.com/bmad-code-org/BMAD-METHOD (commit `b7315c6e`)
