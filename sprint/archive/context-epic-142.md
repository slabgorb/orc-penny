# Epic 142: BMAD vs Pennyfarthing Pipeline Comparison

## Overview

Run identical Peloton benchmark scenarios through both BMAD and Pennyfarthing dev pipelines, scored by the same judge against the same ground truth, to produce statistically rigorous comparative data for framework adoption decisions. Management approved BMAD as the agent framework, but the team is discovering limitations in BMAD's dev loop. This epic provides the quantitative evidence needed to evaluate both frameworks fairly.

**Priority:** P1
**Repo:** pennyfarthing (adapter code), orchestrator (ADR, runs, report)
**Stories:** 6 (12 points)

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **BMAD Comparison PRD** (`sprint/planning/bmad-comparison-prd.md`) | Problem statement, success criteria, functional requirements FR-1 through FR-5, technical architecture, phase mapping, context parity analysis |
| **BMAD Comparison Epics** (`sprint/planning/bmad-comparison-epics.md`) | Story breakdown, acceptance criteria, FR coverage map |
| **BMAD Integration Guide** (`sprint/planning/bmad-integration.md`) | BMAD-PF handoff model, artifact compatibility, workflow overlap |
| **ADR-0013: Stepped Workflow Support** (`docs/adr/0013-bmad-workflow-import.md`) | BMAD architecture overview, BMAD workflow migration patterns, stepped vs phased workflow design |

## Background

### The Problem

Management selected BMAD as the team's agent framework. Engineers are encountering limitations in BMAD's dev loop but lack quantitative evidence to justify adopting Pennyfarthing instead. Anecdotal feedback isn't sufficient for a framework adoption decision — the team needs defensible, reproducible, head-to-head data.

### The Approach

Pennyfarthing already has Peloton — a benchmark replay infrastructure that runs scenarios against real code at known commits and scores results against ground truth. This epic extends Peloton to support a BMAD pipeline variant, enabling apples-to-apples comparison. Both pipelines run the same scenarios, scored by the same judge, against the same ground truth findings.

### Key Fairness Decisions

- **Context parity:** The axiathon story context docs were created from BMAD's create-story flow. Combining PF's epic + story context gives equivalent input to BMAD's story file. The variable under test is agent instructions and workflow, not context preparation.
- **Phase asymmetry:** BMAD uses a 2-phase loop (Dev with embedded TDD -> Reviewer). PF uses a 3-phase loop (TEA -> Dev -> Reviewer). This is a legitimate architectural difference documented as a known asymmetry, not a flaw.
- **Same model:** Both pipelines use Opus for all phases to control for model capability differences.

### BMAD Source Files

The BMAD simulator uses verbatim content from `/Users/keithavery/Projects/BMAD-METHOD/`:
- `src/bmm/agents/dev.agent.yaml` — "Amelia" persona (Senior Software Engineer)
- `src/bmm/workflows/4-implementation/dev-story/instructions.xml` — 10-step Red-Green-Refactor workflow
- `src/bmm/workflows/4-implementation/dev-story/checklist.md` — Definition of Done
- `src/bmm/workflows/4-implementation/code-review/instructions.xml` — 5-step adversarial review
- `src/bmm/workflows/4-implementation/code-review/checklist.md` — Review checklist

## Technical Architecture

### CLAUDE.md Construction

The BMAD simulator builds a CLAUDE.md by injecting BMAD source files verbatim — no PF wrappers, personas, sidecars, or workflow engine context:

```
BMAD Dev CLAUDE.md:
  1. "Amelia" persona from dev.agent.yaml
  2. instructions.xml (10-step workflow, unmodified)
  3. checklist.md (Definition of Done, unmodified)
  4. Story file content (from scenario context)
  5. project-context.md (target project coding standards)

BMAD Reviewer CLAUDE.md:
  1. code-review/instructions.xml (5-step adversarial review)
  2. code-review/checklist.md (review checklist)
```

### Harness Integration

```
pf benchmark replay run scenarios/dpgd-116.yaml --pipeline bmad
                                                 ^^^^^^^^^^^
                                                 Swaps CLAUDE.md builder
                                                 Sets phases to [dev, reviewer]
                                                 Stores results under bmad/run-N/
```

### Worktree Setup (BMAD Runs)

1. Create BMAD-format story file at `implementation_artifacts/{story_key}.md`
2. Create `project-context.md` from target project coding standards
3. Pass `story_path` in prompt so BMAD's step 1 skips sprint-status lookup

### Key Files (New)

| File | Purpose |
|------|---------|
| `docs/adr/0035-bmad-comparison-methodology.md` | Methodology ADR with context diff audit |
| BMAD CLAUDE.md template (location TBD in pennyfarthing) | Static template for BMAD dev/reviewer agents |
| Pipeline adapter module (location TBD in pennyfarthing) | `--pipeline bmad` handler in replay harness |
| Comparison report (location TBD in orchestrator) | Statistical analysis with detection heatmap |

### Story Dependency Chain

```
142-1 (ADR + methodology)
  |
  v
142-2 (BMAD simulator templates) ---> 142-3 (Pipeline replay adapter)
                                          |
                                          v
                                       142-4 (Context parity verification)
                                          |
                                          v
                                       142-5 (Baseline runs) ---> 142-6 (Comparison report)
```

## Cross-Epic Dependencies

**Depends on:**
- Existing Peloton replay infrastructure (`pf benchmark replay`) — provides the harness being extended
- Existing axiathon scenarios (DPGD-116, DPGD-117) — provide ground truth and scenario definitions
- BMAD-METHOD repo at `/Users/keithavery/Projects/BMAD-METHOD/` — source of BMAD instructions

**Depended on by:**
- None currently — this is a standalone comparison effort that produces a report for management decision-making
