---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
inputDocuments:
  - sprint/planning/bmad-comparison-prd.md
---

# BMAD vs Pennyfarthing Pipeline Comparison - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for the BMAD vs Pennyfarthing Pipeline Comparison, decomposing the requirements from the PRD into implementable stories.

## Requirements Inventory

### Functional Requirements

- FR-1: BMAD Simulator Agent Definitions — Create agent defs that reproduce BMAD's dev and reviewer behavior using verbatim `instructions.xml`, `checklist.md`, and "Amelia" persona from `dev.agent.yaml`. No PF persona/sidecars/tandem/workflow context.
- FR-2: Pipeline Replay BMAD Adapter — Extend Peloton replay harness with custom CLAUDE.md builder from BMAD source files, 2-phase mapping (dev, reviewer), story file + project-context.md context injection.
- FR-3: Scenario Configuration — Support `--pipeline bmad` flag on `pf benchmark replay run`, store results under `bmad/run-N/` directory.
- FR-4: BMAD Story File Translation — Translate PF scenario context into BMAD story file format using BMAD's `create-story/template.md`, OR verify axiathon context docs ARE the BMAD create-story output.
- FR-5: Comparison Execution and Reporting — 3+ runs per pipeline per scenario, multi-judge majority voting, detection heatmap, statistical comparison (mean, std dev, 95% CI, Cohen's d, p-value), cost comparison.

### Non-Functional Requirements

- NFR-1: Methodological Defensibility — Every bias-capable decision documented in ADR with rationale.
- NFR-2: Reproducibility — BMAD source pinned to commit hash, adapter code committed, run commands in runbook, results version-controlled.
- NFR-3: Extensibility — Adapter pattern supports future pipeline comparisons (Cursor rules, Windsurf, bare Claude).

### Additional Requirements

- Context parity must be verified and documented (side-by-side content comparison in ADR appendix)
- Phase mapping asymmetry (BMAD 2-phase vs PF 3-phase) documented as known asymmetry, not a flaw
- Same model (Opus) for all phases in both pipelines
- BMAD source at `/Users/keithavery/Projects/BMAD-METHOD/`
- Existing Peloton scenarios DPGD-116 and DPGD-117 in axiathon

### FR Coverage Map

- FR-1 → Epic 142, Story 142-2 (BMAD simulator CLAUDE.md template)
- FR-2 → Epic 142, Story 142-3 (Pipeline replay adapter)
- FR-3 → Epic 142, Story 142-3 (Pipeline replay adapter — includes --pipeline flag)
- FR-4 → Epic 142, Story 142-2 (BMAD simulator CLAUDE.md template — includes story file translation)
- FR-5 → Epic 142, Stories 142-5 and 142-6 (Baseline runs + comparison report)
- NFR-1 → Epic 142, Story 142-1 (ADR + methodology)
- NFR-2 → Epic 142, Story 142-1 (ADR — includes commit pinning and runbook)
- NFR-3 → Epic 142, Story 142-3 (Pipeline replay adapter — extensible --pipeline pattern)

## Epic List

### Epic 142: BMAD vs Pennyfarthing Pipeline Comparison

Engineers can run identical Peloton scenarios through both BMAD and Pennyfarthing dev pipelines, scored by the same judge, to produce statistically rigorous comparative analysis for management decision-making.

**FRs covered:** FR-1, FR-2, FR-3, FR-4, FR-5
**NFRs addressed:** NFR-1, NFR-2, NFR-3

---

## Epic 142: BMAD vs Pennyfarthing Pipeline Comparison

Engineers can run identical Peloton scenarios through both BMAD and Pennyfarthing dev pipelines, scored by the same judge, to produce defensible comparative data for framework adoption decisions.

### Story 142-1: ADR and Comparison Methodology

As an engineering lead,
I want a documented methodology for comparing BMAD and Pennyfarthing pipelines,
So that the comparison results are defensible under adversarial review.

**Points:** 2
**Priority:** P0
**Workflow:** trivial
**Repos:** orchestrator

**Acceptance Criteria:**

**Given** the BMAD-METHOD repo is checked out at `/Users/keithavery/Projects/BMAD-METHOD/`
**When** the ADR is written
**Then** it documents:
- Which BMAD source files are used and why (instructions.xml, checklist.md, dev.agent.yaml, code-review instructions.xml)
- The BMAD commit hash pinned for reproducibility
- Context parity analysis: what each agent receives, side-by-side
- Phase mapping rationale: BMAD 2-phase (Dev→Reviewer) vs PF 3-phase (TEA→Dev→Reviewer) as known asymmetry
- Controlled variables: same model, same scenario, same judge, same ground truth
- Story file translation decisions: how PF context docs map to BMAD story file format
**And** the ADR is saved at `docs/adr/` with sequential numbering

**Given** the axiathon story context documents exist
**When** context parity is analyzed
**Then** a side-by-side appendix shows what PF's dev agent sees vs what BMAD's dev agent will see
**And** each difference is annotated with rationale

---

### Story 142-2: BMAD Simulator CLAUDE.md Template and Story File

As a benchmark engineer,
I want a CLAUDE.md template that faithfully reproduces what a BMAD dev agent would see,
So that the BMAD pipeline run uses BMAD's actual instructions without PF contamination.

**Points:** 2
**Priority:** P1
**Workflow:** tdd
**Repos:** pennyfarthing

**Acceptance Criteria:**

**Given** the BMAD dev agent definition at `BMAD-METHOD/src/bmm/agents/dev.agent.yaml`
**And** the dev workflow at `BMAD-METHOD/src/bmm/workflows/4-implementation/dev-story/instructions.xml`
**And** the checklist at `BMAD-METHOD/src/bmm/workflows/4-implementation/dev-story/checklist.md`
**When** the BMAD dev CLAUDE.md template is built
**Then** it contains the "Amelia" persona description verbatim from `dev.agent.yaml`
**And** it contains the full `instructions.xml` content verbatim (10-step Red-Green-Refactor workflow)
**And** it contains the full `checklist.md` content verbatim (Definition of Done)
**And** it contains the story file content (translated from scenario context or verified BMAD-equivalent)
**And** it contains `project-context.md` content from the target project
**And** it contains NO Pennyfarthing persona, sidecars, workflow engine context, or session metadata

**Given** the BMAD reviewer definition at `BMAD-METHOD/src/bmm/workflows/4-implementation/code-review/instructions.xml`
**And** the code review checklist at `BMAD-METHOD/src/bmm/workflows/4-implementation/code-review/checklist.md`
**When** the BMAD reviewer CLAUDE.md template is built
**Then** it contains the adversarial review instructions verbatim (5-step workflow)
**And** it contains the review checklist verbatim
**And** it contains NO Pennyfarthing reviewer agent definition or sidecars

**Given** a Peloton scenario's epic and story context documents
**When** the story file is created for the BMAD dev agent
**Then** it follows BMAD's `create-story/template.md` structure (Story, AC, Tasks/Subtasks, Dev Notes, Dev Agent Record, File List)
**And** a `story_path` is provided in the prompt so BMAD's step 1 skips sprint-status lookup

---

### Story 142-3: Pipeline Replay BMAD Adapter

As a benchmark engineer,
I want a `--pipeline bmad` flag on `pf benchmark replay run`,
So that I can run scenarios through the BMAD simulator pipeline.

**Points:** 3
**Priority:** P1
**Workflow:** tdd
**Repos:** pennyfarthing

**Acceptance Criteria:**

**Given** the `pf benchmark replay run` command exists
**When** `--pipeline bmad` is passed
**Then** the harness uses the BMAD CLAUDE.md builder instead of `pf agent start` + persona
**And** phases are set to `[dev, reviewer]` (no TEA phase)
**And** the BMAD dev CLAUDE.md template is populated with scenario-specific story file content
**And** the BMAD reviewer CLAUDE.md template is populated with the dev phase output

**Given** a BMAD pipeline run completes
**When** results are saved
**Then** they are stored under `bmad/run-N/` directory (using "bmad" as the theme/directory name)
**And** `pipeline.yaml` includes a `pipeline: bmad` field to distinguish from PF runs

**Given** the BMAD story file needs to be placed in the worktree
**When** the worktree is set up for a BMAD run
**Then** the story file is written to `implementation_artifacts/{story_key}.md` in the worktree
**And** a `project-context.md` is created from the target project's coding standards
**And** the `story_path` in the dev prompt points to the worktree story file

**Given** `--pipeline` is omitted or set to `default`
**When** `pf benchmark replay run` executes
**Then** the standard PF pipeline behavior is unchanged (backward compatible)

---

### Story 142-4: Context Parity Verification

As an engineering lead,
I want verified proof that the BMAD and PF agents receive equivalent context,
So that no one can claim the comparison is unfair due to context differences.

**Points:** 1
**Priority:** P1
**Workflow:** trivial
**Repos:** orchestrator

**Acceptance Criteria:**

**Given** a completed BMAD pipeline run and a completed PF pipeline run on the same scenario
**When** the CLAUDE.md files from both runs are compared
**Then** a diff document shows exactly what each agent received
**And** context differences are categorized as: "BMAD-only content", "PF-only content", "equivalent content"
**And** each difference has an annotated rationale (e.g., "PF includes sidecars — this is a legitimate framework advantage, not an unfair addition")

**Given** the axiathon story context documents
**When** compared against BMAD's create-story template output
**Then** a verification note confirms whether the context docs were created from BMAD's create-story flow
**And** any gaps or extras are documented

---

### Story 142-5: Baseline Comparison Runs

As a benchmark engineer,
I want to run both pipelines on DPGD-116 and DPGD-117 scenarios,
So that we have statistically meaningful comparative data.

**Points:** 2
**Priority:** P1
**Workflow:** trivial
**Repos:** orchestrator

**Acceptance Criteria:**

**Given** the BMAD adapter is functional and the CLAUDE.md templates are verified
**When** baseline runs are executed
**Then** DPGD-116 is run 3+ times through the BMAD pipeline
**And** DPGD-116 is run 3+ times through the PF pipeline (or existing runs are reused)
**And** DPGD-117 is run 3+ times through the BMAD pipeline
**And** DPGD-117 is run 3+ times through the PF pipeline (or existing runs are reused)

**Given** completed runs exist
**When** multi-judge scoring is applied
**Then** each run has 3 judge passes with majority voting
**And** `majority_vote.yaml` is computed for every run

---

### Story 142-6: Comparative Analysis Report

As an engineering lead,
I want a statistical comparison report with detection heatmaps and cost analysis,
So that I can present data-driven framework adoption recommendations to management.

**Points:** 2
**Priority:** P1
**Workflow:** trivial
**Repos:** orchestrator

**Acceptance Criteria:**

**Given** scored runs for both BMAD and PF pipelines on both scenarios
**When** `pf benchmark replay compare` runs across both pipelines
**Then** the output shows a detection heatmap: finding × pipeline, with phase attribution
**And** per-pipeline statistics are shown: mean score, std dev, 95% CI
**And** Cohen's d effect size is computed between BMAD and PF scores
**And** Welch's t-test p-value is reported with significance stars

**Given** pipeline.yaml metadata from both pipelines
**When** cost analysis is computed
**Then** the report shows tokens-per-run for each pipeline
**And** estimated USD cost per run is compared
**And** a cost-normalized metric (findings-per-dollar) is reported

**Given** the comparison report is complete
**When** reviewed
**Then** the report includes: methodology summary, results table, detection heatmap, statistical significance, cost comparison, and a "limitations" section acknowledging the phase asymmetry and sample size
