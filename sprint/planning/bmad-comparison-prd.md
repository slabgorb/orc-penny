---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-03-success
  - step-04-journeys
  - step-05-domain (skipped)
  - step-06-innovation (skipped)
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
inputDocuments:
  - docs/comparisons/bmad-vs-pennyfarthing.md
  - docs/comparisons/bmad-pennyfarthing-gap-analysis.md
  - docs/adr/0013-bmad-workflow-import.md
workflowType: 'prd'
documentCounts:
  briefCount: 0
  researchCount: 0
  brainstormingCount: 0
  projectDocsCount: 3
classification:
  projectType: CLI Tool / Developer Tooling (Benchmark Extension)
  domain: Developer Experience (DX) / Quality Engineering
  complexity: Medium
  projectContext: brownfield
---

# Product Requirements Document - BMAD vs Pennyfarthing Pipeline Comparison

**Author:** Keith Avery
**Date:** 2026-03-10

## Problem Statement

Management approved BMAD as the agent framework. The team is discovering limitations in BMAD's dev loop but has no quantitative evidence to justify adopting Pennyfarthing. We need a fair, defensible, head-to-head comparison using Pennyfarthing's existing Peloton benchmark infrastructure — running identical scenarios through both pipelines, scored by the same judge, against the same ground truth.

If BMAD wins on some dimension, we learn. If Pennyfarthing wins, we have the data to make the case.

## Success Criteria

### User Success (The Engineering Team)

- **Defensible data** — comparison results can be presented to management with clear methodology, no cherry-picking
- **Fair to both frameworks** — BMAD gets its own instructions verbatim, PF gets its normal pipeline; neither is advantaged
- **Reproducible** — any engineer can re-run the comparison and get statistically consistent results

### Business Success (Framework Adoption)

- **Decision support** — clear signal on which pipeline catches more real bugs in real code
- **Per-phase attribution** — understand WHERE each pipeline is stronger (TEA vs Dev vs Reviewer)
- **Cost comparison** — token usage / cost per run for each pipeline

### Technical Success

- **Reuses existing infrastructure** — extends Peloton replay, no new scoring system
- **BMAD simulator is faithful** — uses BMAD's actual `instructions.xml`, `checklist.md`, agent persona; documented and defensible
- **Statistically rigorous** — multiple runs per pipeline, multi-judge majority voting, Cohen's d effect sizes

## Scope

### In Scope

| Item | Description |
|------|-------------|
| BMAD simulator agent definitions | PF-compatible agent defs that faithfully reproduce BMAD's dev + reviewer instructions (no PF persona/sidecars) |
| Pipeline replay adapter | Extension to build BMAD-style CLAUDE.md (BMAD instructions + checklist, no PF framework) |
| BMAD story file translation | Convert PF scenario context → BMAD story file format (using BMAD's `template.md`) — OR document that axiathon context IS the BMAD create-story output |
| Baseline runs | Execute both pipelines on DPGD-116 and DPGD-117 scenarios, 3+ runs each, multi-judge |
| Comparison report | Statistical comparison with detection heatmap, per-phase attribution, cost analysis |
| ADR | Document methodology, fairness decisions, every translation choice |

### Out of Scope

- Running BMAD's full PM/Architect/SM planning pipeline (we test dev loop only)
- Modifying BMAD's instructions in any way
- Optimizing PF's pipeline based on results (separate follow-up)
- Testing BMAD's planning phases against PF's planning phases
- Multi-IDE comparison (both run via `claude -p`)

## Context Parity Analysis

A critical fairness question: what context does each agent receive?

### BMAD Dev Agent Receives

1. **Story file** — created by SM's `create-story` workflow, which front-loads ALL planning artifacts (epics, PRD, architecture, UX, previous story learnings, git history) into a rich Dev Notes section
2. **`project-context.md`** — coding standards and project-wide patterns
3. **`instructions.xml`** — the 10-step dev workflow
4. **`checklist.md`** — Definition of Done validation

### PF Dev Agent Receives

1. **Epic context** — vision, scope, dependencies
2. **Story context** — acceptance criteria, technical notes, file hints
3. **Agent definition** — dev agent instructions with persona
4. **Sidecars** — patterns, gotchas, decisions learned from prior work
5. **Session file** — workflow state, phase, repos topology

### Resolution

The axiathon story context docs were created directly from BMAD's create-story flow. Combining epic + story context gives equivalent or slightly richer input than BMAD's story file. **Context is already controlled.** The variable under test is the agent instructions and self-checking workflow, not context preparation.

This must be documented in the ADR with specific evidence (file comparison showing the axiathon context docs match BMAD story file content).

## Functional Requirements

### FR-1: BMAD Simulator Agent Definitions

Create agent definition files that reproduce BMAD's dev and reviewer behavior within the Peloton harness:

- **BMAD Dev agent**: Loads BMAD's `instructions.xml` (10-step Red-Green-Refactor), `checklist.md` (Definition of Done), and the "Amelia" persona description from `dev.agent.yaml`
- **BMAD Reviewer agent**: Loads BMAD's `code-review/instructions.xml` (5-step adversarial review) and checklist
- **No PF additions**: No persona themes, no sidecars, no tandem, no workflow engine context — only what BMAD would provide
- **Acceptance Criteria**:
  - Given a BMAD simulator agent, when its CLAUDE.md is built, then it contains ONLY BMAD-sourced instructions
  - Given a BMAD simulator run, when the dev agent executes, then its behavior follows BMAD's 10-step workflow

### FR-2: Pipeline Replay BMAD Adapter

Extend the Peloton replay harness to support a BMAD pipeline variant:

- **Custom CLAUDE.md builder**: Instead of `pf agent start <role>` + persona, builds from BMAD source files at `/Users/keithavery/Projects/BMAD-METHOD/`
- **Phase mapping**: BMAD uses `[dev, reviewer]` (no separate TEA phase — TDD is embedded in dev's 10-step workflow)
- **Context injection**: Story file + project-context.md instead of PF epic/story context + agent def
- **Acceptance Criteria**:
  - Given a scenario with `pipeline: bmad`, when replay runs, then CLAUDE.md contains BMAD instructions verbatim
  - Given a BMAD pipeline run, when phases execute, then only `dev` and `reviewer` phases run (no TEA)

### FR-3: Scenario Configuration

Support pipeline variant selection in scenario YAML:

```yaml
# Option A: separate scenario file
id: dpgd-116-bmad
pipeline: bmad
# inherits repo, base_commit, ground_truth from dpgd-116

# Option B: run-time flag
# pf benchmark replay run scenarios/dpgd-116.yaml --pipeline bmad
```

- **Acceptance Criteria**:
  - Given a scenario, when `--pipeline bmad` is specified, then the BMAD adapter is used
  - Given a BMAD pipeline run, results are stored under a distinct theme/directory (e.g., `bmad/run-N/`)

### FR-4: BMAD Story File Translation

Translate PF scenario context into BMAD's story file format:

- Use BMAD's `create-story/template.md` structure (Story, AC, Tasks/Subtasks, Dev Notes, Dev Agent Record, File List)
- Populate from our epic context + story context documents
- OR: document that the axiathon context docs ARE already the BMAD create-story output and no translation is needed
- **Acceptance Criteria**:
  - Given scenario context docs, when translated to BMAD format, then the story file contains all sections from BMAD's template
  - Given translation decisions, when reviewed, then each is documented with rationale in the ADR

### FR-5: Comparison Execution and Reporting

Run both pipelines and produce comparative analysis:

- Minimum 3 runs per pipeline per scenario (6+ total per scenario)
- Multi-judge scoring (3 judges per run, majority vote)
- Detection heatmap: finding × pipeline, showing which phase caught it
- Statistical comparison: mean score, std dev, 95% CI, Cohen's d, p-value
- Cost comparison: tokens and estimated USD per pipeline run
- **Acceptance Criteria**:
  - Given completed runs, when `pf benchmark replay compare` runs, then it shows PF vs BMAD side by side
  - Given comparison results, when Cohen's d is computed, then effect sizes are reported with significance levels

## Non-Functional Requirements

### NFR-1: Methodological Defensibility

Every design decision that could bias results must be documented in an ADR:
- Why these specific BMAD files were used
- How context parity was verified
- What was stripped from PF to avoid unfair advantage
- What was given to BMAD to ensure fair treatment
- Phase mapping rationale (BMAD 2-phase vs PF 3-phase)

### NFR-2: Reproducibility

Any engineer must be able to reproduce results:
- BMAD source pinned to a specific commit hash
- All adapter code committed and documented
- Run commands documented in a runbook
- Results stored in version-controlled directory structure

### NFR-3: Extensibility

The adapter pattern should support future pipeline comparisons:
- Other frameworks (Cursor rules, Windsurf, bare Claude)
- Different phase configurations
- Custom prompt injection points

## Phase Mapping Decision

BMAD runs a 2-phase dev loop: **Dev** (includes TDD) → **Reviewer**.
PF runs a 3-phase dev loop: **TEA** (RED) → **Dev** (GREEN) → **Reviewer**.

This is a legitimate architectural difference, not a bias. BMAD chose to embed test-writing in the dev step. PF chose to separate it. The judge scores against ground truth findings regardless of which phase caught them — so the comparison remains fair. The detection heatmap will reveal whether PF's phase separation provides value.

Document this in the ADR as a known asymmetry, not a flaw.

## Technical Architecture (from Brainstorm)

### CLAUDE.md Construction Strategy

**Verbatim injection with static template.** The BMAD simulator builds a CLAUDE.md by injecting BMAD's `instructions.xml` and `checklist.md` content verbatim — no paraphrasing, no PF wrappers. A static template slots in:

1. BMAD dev agent persona (from `dev.agent.yaml` — "Amelia", Senior Software Engineer)
2. BMAD `instructions.xml` (10-step dev workflow, unmodified)
3. BMAD `checklist.md` (Definition of Done, unmodified)
4. Story file content (translated from scenario context or verified as BMAD-equivalent)
5. `project-context.md` (from the target project's actual coding standards)

No `pf agent start` is called. No PF persona, sidecars, workflow engine, or session context is included.

### Worktree Setup Strategy

**Story file pre-staging with story_path provision.** Before the agent runs:

1. Create a BMAD-format story file in the worktree at `implementation_artifacts/{story_key}.md`
2. Create a minimal `project-context.md` from the axiathon project's coding standards
3. Pass `story_path` directly in the prompt so BMAD's step 1 skips sprint-status lookup

No `sprint-status.yaml` needed — BMAD's instructions have a fallback: "if story_path provided, use it directly."

### Harness Integration Strategy

**`--pipeline` flag with BMAD as theme name.** Extend `pf benchmark replay run`:

- `--pipeline bmad` swaps the CLAUDE.md builder to use the BMAD adapter
- Results stored under `bmad/run-N/` directory structure (BMAD registered as a "theme" for directory organization)
- Phase list set to `[dev, reviewer]` (no TEA) when pipeline is BMAD

### Phase Mapping Strategy

**Keep 2-vs-3 phase asymmetry honest.** Do not artificially split BMAD's dev into TEA+Dev. This is a real architectural difference between the frameworks. The detection heatmap will show whether PF's phase separation adds value. Report both:

- **Detection rate** — findings caught / total (the primary metric)
- **Cost efficiency** — findings-per-dollar and tokens-per-run (since BMAD's 2-phase may use fewer tokens)

Same model (Opus) for all phases in both pipelines for controlled comparison.

### Fairness Verification Strategy

**Context diff audit as ADR appendix.** After first successful run, publish a side-by-side comparison:

- Left column: what PF's dev agent sees (CLAUDE.md content)
- Right column: what BMAD's dev agent sees (CLAUDE.md content)
- Annotated differences with rationale for each

**Parked for follow-up if challenged:** Run BMAD's actual create-story workflow on the axiathon scenario and diff output against our context docs.

## Key Risks

| Risk | Mitigation |
|------|------------|
| BMAD instructions reference files/paths that don't exist in worktree | Story file pre-staging + story_path provision bypasses path resolution; document any remaining substitutions |
| Context parity is disputed | Context diff audit published as ADR appendix; BMAD create-story verification parked as escalation |
| Sample size too small for statistical significance | Start with 3 runs, increase if effect sizes are ambiguous |
| BMAD performs better and we look bad | This is a feature, not a bug — honest data is the goal |
| Judge prompt biased toward PF-style output | Judge scores against ground truth findings, not output format |
| BMAD's "different model for reviewer" recommendation not followed | Document as controlled variable — same model ensures fair comparison; multi-model variant parked for follow-up |

## Dependencies

- BMAD-METHOD checked out at `/Users/keithavery/Projects/BMAD-METHOD/`
- Existing Peloton scenarios (DPGD-116, DPGD-117) in axiathon
- Existing pipeline replay infrastructure (`pf benchmark replay`)
- Claude API access for benchmark runs

## Estimated Effort

| Story | Points | Description |
|-------|--------|-------------|
| ADR + methodology | 2 | Document comparison design, fairness principles, translation decisions, context diff audit |
| BMAD simulator CLAUDE.md template | 2 | Static template with verbatim BMAD instructions, persona, checklist injection |
| Pipeline replay adapter + --pipeline flag | 3 | BMAD CLAUDE.md builder, story file pre-staging, phase mapping, harness integration |
| Story file translation / verification | 1 | Verify axiathon context = BMAD create-story output, or translate to BMAD template format |
| Run baselines (2 scenarios) | 2 | Execute both pipelines 3+ runs each, multi-judge scoring |
| Comparison report | 2 | Statistical analysis, detection heatmap, cost normalization, write-up |
| **Total** | **12** | |
