# Epic 144: Specification Fidelity Gates

## Overview

Enforce spec fidelity end-to-end across the TDD pipeline: structured deviation documentation with gate-enforced format validation, AC accountability with real-time operator approval, two new Architect phases (spec-check before RED, spec-reconcile after Reviewer), and a modernized TDD workflow. Every departure from any spec — story context, epic context, PRD, sibling story assumptions — is logged or the gate blocks. The boss can audit any story from the session file alone.

**Priority:** P0
**Repo:** pennyfarthing
**Stories:** 9 (19 points)

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **Spec Fidelity Gates PRD** (`sprint/planning/spec-fidelity-gates.md`) | Full PRD — success criteria, user journeys, functional requirements FR-1 through FR-9, technical architecture, implementation strategy |
| **Spec Fidelity Gates Epics** (`sprint/planning/spec-fidelity-gates-epics.md`) | Story breakdown, FR coverage map, acceptance criteria for all 9 stories |
| **Gate PRD** (`sprint/planning/gate-prd.md`) | Original gate architecture — context for existing `deviations-logged` and `deviations-audited` gates |
| **Simplify Integration PRD** (`sprint/planning/prd-simplify-integration.md`) | Simplify teammate design — context for simplify toggle (FR-7) |
| **Context Gate PRD** (`sprint/planning/context-gate-prd.md`) | Context validation gates — context for Assumptions section requirement (FR-6) |

## Background

### The Problem: Silent Spec Drift

The current TDD pipeline has no systematic mechanism for tracking deviations from specifications. When TEA writes tests or Dev implements features, departures from story context, epic context, or PRD requirements go undocumented unless agents happen to mention them. This creates two downstream problems:

1. **Retroactive deviation hunts** — after external reviewers find issues, someone has to go back through session archives and add "retroactive design deviations" to every affected story. This has happened repeatedly (PR #50 had 13+6 findings, PR #52 had 8 findings that the pipeline missed).

2. **Boss can't trust the pipeline** — the session file should be the single audit artifact, but without structured deviation documentation, the boss has to re-read specs and diff code to understand what actually changed. That defeats the purpose of the pipeline.

### The Solution: Gates Over Goodwill

Rather than relying on agents to remember to document deviations (they won't — Principle 6: Gates Over Goodwill), the pipeline will enforce it:

- **`deviations-logged` gate** — upgraded from existence check to format validation. TEA and Dev cannot hand off without structured deviation entries (or an explicit "No deviations from spec.").
- **`ac-completion` gate** — new standalone composable gate. Every AC must be DONE, DEFERRED (with operator approval), or DESCOPED. No silent drops.
- **Architect spec-check** — new phase before RED validates assumptions against sibling stories, catching broken assumptions before TEA writes tests against the wrong spec.
- **Architect spec-reconcile** — new phase after Reviewer produces the definitive deviation manifest. This is what the boss reads.

### Current State

The infrastructure is partially in place:
- `deviations-logged.md` and `deviations-audited.md` gate definitions exist but are **unwired** in `tdd.yaml` — the workflow doesn't reference them
- Tandem workflows (`tdd-tandem.yaml`, `review-tandem.yaml`, `bdd-tandem.yaml`) exist but are obsolete now that Architect gets explicit phases
- The `## Design Deviations` session section exists by convention but has no enforced format
- Epic 143 (Native Subagent Migration) provides the subagent infrastructure these Architect phases will run on

### Design Principles

- **Excellence over optimization** — two additional Architect phases per story is the right trade. Don't optimize for token cost at the expense of spec fidelity (Principle 13).
- **Human-in-loop is expected** — the operator is present and watching. Blocking for AC deferral approval is by design, not a latency problem.
- **Graceful degradation** — when sibling stories lack context documents, fall back to story titles and ACs from sprint YAML. Partial information beats no forward-looking comparison.
- **Session file size is a future concern** — deviation manifests will grow session files. When this becomes a problem, scripts will slice and dice. Don't prematurely constrain the format.

## Technical Architecture

### Updated TDD Workflow

```
SM (setup) → Architect (spec-check) → TEA (red) → Dev (green) → TEA (verify) → Reviewer → Architect (spec-reconcile) → SM (finish)
```

8 phases (up from 6), with two new Architect phases providing bookend spec alignment.

### Gate Architecture

| Gate | Type | Phase | Purpose |
|------|------|-------|---------|
| `spec-check-pass` | **New** | After setup | Architect validates assumptions vs sibling stories |
| `deviations-logged` (tea) | Existing, **unwired** | After RED | TEA logged deviation section with 6-field format |
| `ac-completion` | **New**, standalone | After GREEN | All ACs accounted for with operator approval |
| `deviations-logged` (dev) | Existing, **unwired** | After GREEN | Dev logged deviation section with 6-field format |
| `quality-pass` | Existing | After VERIFY | Lint, typecheck, tests |
| `deviations-audited` | Existing, **unwired** | After REVIEW | Reviewer stamped all deviations |
| `spec-reconcile-pass` | **New** | After REVIEW | Architect final spec comparison, definitive manifest |

### Deviation Entry Format (6-field structured)

```markdown
- **{Short description}**
  - Spec source: {document path, section/AC reference}
  - Spec text: "{quoted original specification}"
  - Implementation: {what was actually built/tested}
  - Rationale: {why the deviation was made}
  - Severity: {minor | major}
  - Forward impact: {none | minor | breaking} — {affected story IDs and assumptions}
```

Agent-specific subsections: `### TEA (test design)`, `### Dev (implementation)`, `### Architect (reconcile)`.

### Key Files (Existing)

| File | Purpose | Action |
|------|---------|--------|
| `pennyfarthing-dist/workflows/tdd.yaml` | TDD workflow definition | **Modify** — add spec-check, reconcile phases; wire all gates |
| `pennyfarthing-dist/gates/deviations-logged.md` | Deviation existence gate | **Modify** — upgrade to format validation |
| `pennyfarthing-dist/gates/deviations-audited.md` | Reviewer deviation audit gate | **Wire** into tdd.yaml review phase |
| `pennyfarthing-dist/agents/tea.md` | TEA agent definition | **Modify** — add `<deviation-logging>` section |
| `pennyfarthing-dist/agents/dev.md` | Dev agent definition | **Modify** — add `<deviation-logging>` section |
| `pennyfarthing-dist/templates/context-schema.yaml` | Context document schema | **Modify** — add Assumptions to required story sections |
| `.pennyfarthing/repos.yaml` | Repo configuration | **Modify** — add `simplify_enabled` field |

### Key Files (New)

| File | Purpose |
|------|---------|
| `pennyfarthing-dist/guides/deviation-format.md` | Deviation entry format specification guide |
| `pennyfarthing-dist/gates/ac-completion.md` | AC accountability gate with operator approval |
| `pennyfarthing-dist/gates/spec-check-pass.md` | Architect spec-check gate |
| `pennyfarthing-dist/gates/spec-reconcile-pass.md` | Architect spec-reconcile gate |

### Key Files (Deleted)

| File | Reason |
|------|--------|
| `pennyfarthing-dist/workflows/tdd-tandem.yaml` | Tandem needs rethink — Architect now has explicit phases |
| `pennyfarthing-dist/workflows/review-tandem.yaml` | Same — tandem removal is clean cut |
| `pennyfarthing-dist/workflows/bdd-tandem.yaml` | Same — BDD tandem out of scope |

### Configuration: Simplify Toggle

```yaml
# In .pennyfarthing/repos.yaml, per-repo:
simplify_enabled: false  # default — simplify teammates don't spawn in verify
```

Read at runtime when TEA enters verify phase. Not cached at workflow start.

### Implementation Dependency Graph

```
Phase A (independent, start immediately):
  144-4  Simplify toggle in repos.yaml
  144-5  Assumptions section in context schema
  144-8  Remove tandem workflows

Phase B (depends on 144-1 format spec):
  144-1  Deviation format spec + gate validation upgrade
  144-2  Update TEA and Dev agent definitions (needs format from 144-1)
  144-3  AC-completion gate (standalone, but consistent with deviation format)

Phase C (depends on 144-2, 144-1, 144-5):
  144-6  Architect spec-check phase (needs assumptions section + agent definitions)
  144-7  Architect spec-reconcile phase (needs deviation format + agent definitions)

Phase D (depends on everything):
  144-9  Update TDD workflow — wires all phases and gates together
```

**Critical path:** 144-1 → 144-2 → 144-7 → 144-9

## Cross-Epic Dependencies

**Depends on:**
- **Epic 143 (Native Subagent Migration)** — Architect phases run as native subagents. Core subagent infrastructure (stories 143-1 through 143-8, all done) provides the spawning mechanism. Stories 143-9 (E2E validation) and 143-10 (Reviewer-Dev round-trip) validate the pipeline these gates enforce.

**Depended on by:**
- **Epic 47 (Strategic Role Benchmarking)** — PM and Architect persona benchmarks (47-3, 47-4) will need the Architect spec-check/reconcile phases to exist before meaningful pipeline evaluation
- **Future tandem rethink epic** — tandem workflow removal (144-8) explicitly defers redesign; future epic will need the updated TDD workflow as its baseline
