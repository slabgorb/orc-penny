---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
inputDocuments:
  - pennyfarthing/docs/prd/batch-prd.md
  - pennyfarthing/pennyfarthing-dist/schemas/workflow-schema.md
  - pennyfarthing/pennyfarthing-dist/patterns/fan-out-fan-in-pattern.md
  - pennyfarthing/pennyfarthing-dist/workflows/prd/workflow.yaml
  - docs/ARCHITECTURE.md
  - docs/BIKELANE.md
documentCounts:
  briefs: 0
  research: 0
  projectDocs: 6
workflowType: 'prd'
workflowMode: 'create'
classification:
  projectType: Developer Tool / CLI Framework
  domain: AI-Assisted Development
  complexity: High
  projectContext: brownfield
---

# Product Requirements Document - Batch Workflow Integration

**Author:** President Lindberg
**Date:** 2026-03-03

## Success Criteria

### User Success

| Criterion | Measure | Threshold |
|-----------|---------|-----------|
| Developer keeps Pennyfarthing ceremony during batch | Batch runs produce session files, pass gates, track in sprint | 100% of batch runs have session + sprint tracking |
| Batch PRs are review-ready on arrival | Each PR has passed `/simplify` (built-in) + testing-runner | Zero PRs merged without gate passage |
| Sprint board stays coherent | One story = one session, regardless of unit count | No orphaned PRs or sub-tasks |
| Developer can see what happened | Session file shows all units with status, branches, PRs | Post-batch session is self-documenting |
| No file conflicts between units | File-overlap check warns before fan-out | Zero same-file collisions in production use |

### Business Success

| Criterion | Measure | Threshold |
|-----------|---------|-----------|
| Throughput multiplier for eligible stories | Points completed per sprint on batchable work | 2x vs single-agent on comparable stories within 3 months |
| Adoption by developers | % of eligible stories that use batch workflow | >30% of batchable stories use batch within 2 sprints of launch |
| Quality parity | Regression rate on batch-produced PRs vs single-agent | No increase in post-merge defects |

### Technical Success

| Criterion | Measure |
|-----------|---------|
| Workflow YAML passes existing validator | Zero schema changes required (confirmed by Architect) |
| Session `<units>` element parses correctly | XML format, grep-parseable, consistent with session schema |
| Worktree cleanup after batch | No stale `.claude/worktrees/batch-*` after 24h |
| Gate runtime coverage | Uses `manual` + `approval` gates — both already implemented in handoff.ts |

### Measurable Outcomes

- First batch workflow run completes end-to-end within 2 weeks of implementation
- 3+ stories use batch workflow within first sprint of availability
- Zero workflow engine regressions from batch addition

## Product Scope

### MVP — 6 points

1. **Batch workflow YAML** (2pt) — 4 phases: decompose → fan-out → review → finish. Uses existing schema, no engine changes.
2. **Session `<units>` XML tracking** (1pt) — New XML element in session files. Schema doc update.
3. **Orchestrator batch prompt** (1pt) — Fan-out execution instructions for orchestrator agent definition.
4. **Session update tooling** (1pt) — Extend fix-session-phase for unit status tracking.
5. **File-overlap independence check** (1pt) — Pre-fan-out warning if units share files.

### Growth Features (Post-MVP)

1. Integration test staging branch — merge all batch branches, run full suite
2. BikeRack batch visualization panel — real-time fan-out progress in GUI
3. Batch-aware CI — label-based grouping, merge-train support
4. Per-unit test gate — testing-runner per worktree before PR creation
5. Pennyfarthing reviewer persona in `/simplify` pass

### Vision (Future)

1. Auto-decomposition — Architect agent proposes decomposition without human prompting
2. AST-based false parallelism detection — static analysis of import/export graphs
3. Cross-repo batch — fan-out across orchestrator + framework repos
4. Batch templates — reusable decomposition patterns

## User Journeys

### Journey 1: Developer — Batch Happy Path

Developer has a story: "Add aria-labels to all 40 form components." SM flags it as batchable during setup. Developer runs the batch workflow. Architect decomposes into 8 units (5 components each), confirms no file overlaps. Developer approves the decomposition. Orchestrator fans out 8 agents in worktrees. 20 minutes later, 8 PRs land. Reviewer checks consistency across the batch. SM finishes the story — one session, one sprint artifact, 8 merged PRs.

**Reveals:** Workflow YAML, session units tracking, file-overlap check, orchestrator prompt.

### Journey 2: Developer — Partial Failure

Same story, but unit-3 fails its tests. Session shows 7 completed, 1 failed. Batch blocks at the review gate. Developer inspects the failed unit's worktree, fixes manually, pushes. Unit-3 status updates to completed. Review proceeds.

**Reveals:** Session unit status management, failure visibility, manual recovery path.

### Journey 3: Reviewer — Batch Consistency Check

Reviewer receives 8 PRs from a batch run. Instead of reviewing each independently, they review the batch as a whole — are naming conventions consistent across units? Did different agents make contradictory choices? Reviewer approves or rejects the batch, not individual PRs.

**Reveals:** Review phase needs batch-wide diff context, not per-PR review.

### Journey Requirements Summary

| Capability | Revealed By |
|-----------|-------------|
| Batch workflow YAML (4 phases) | Journey 1 |
| Session `<units>` XML tracking | Journeys 1, 2 |
| File-overlap independence check | Journey 1 |
| Orchestrator fan-out prompt | Journey 1 |
| Unit failure handling + manual recovery | Journey 2 |
| Batch-wide review context | Journey 3 |

## Project Scoping & Phased Development

### MVP Strategy

**Approach:** Problem-solving MVP — minimum that makes batch useful within Pennyfarthing ceremony.

**Must-have test:** Remove any MVP item and the batch workflow either doesn't run (#1, #3), can't be tracked (#2, #4), or is unsafe (#5).

| # | Feature | Points | Justification |
|---|---------|--------|---------------|
| 1 | Batch workflow YAML | 2 | Core — without this, nothing works |
| 2 | Session `<units>` XML | 1 | Core — without tracking, no visibility |
| 3 | Orchestrator batch prompt | 1 | Core — agent needs instructions to fan out |
| 4 | Session update tooling | 1 | Core — units need status updates |
| 5 | File-overlap check | 1 | Safety — prevents worst failure mode |

### Risk Mitigation

| Risk | Severity | Mitigation |
|------|----------|------------|
| `/batch` internals change | Medium | Thin wrapper — wrap, not fork |
| Decomposition produces bad units | High | File-overlap check (MVP) + manual approval gate |
| Worktree disk pressure | Low | Claude Code manages lifecycle; concurrency config in Growth |

## Functional Requirements

### FR-1: Batch Workflow YAML (MVP #1, 2pt)

**User Story:** As a developer, I can select the `batch` workflow for a story so that parallel execution follows BikeLane ceremony.

**Acceptance Criteria:**
- `workflows/batch-workflow.yaml` passes existing workflow validator without schema changes
- 4 phases: decompose (architect), fan-out (orchestrator), review (reviewer), finish (sm)
- Gates: manual on decompose, manual on fan-out, approval on review
- Triggers: `batch` tag on stories

### FR-2: Session Units Tracking (MVP #2, 1pt)

**User Story:** As a developer, I can see all batch units and their status in the session file.

**Acceptance Criteria:**
- `<units>` XML element in session file
- Each `<unit>` has: id, status (pending/in_progress/completed/failed), description, worktree path, branch, PR URL
- Grep-parseable, consistent with existing session schema
- Session schema documentation updated

### FR-3: Orchestrator Batch Prompt (MVP #3, 1pt)

**User Story:** As the orchestrator agent, I have instructions to invoke `/batch` with story context and track results back to session units.

**Acceptance Criteria:**
- Orchestrator agent definition includes batch fan-out execution flow
- Spawns parallel agents via Task tool with `isolation: "worktree"`
- Updates session unit status on completion/failure
- Passes story acceptance criteria to each worker agent

### FR-4: Session Update Tooling (MVP #4, 1pt)

**User Story:** As an agent, I can update individual unit status in the session file.

**Acceptance Criteria:**
- `fix-session-phase` extended to handle `--unit <id> --status <status>` arguments
- Updates single unit without clobbering other units
- Supports all unit status values: pending, in_progress, completed, failed

### FR-5: File-Overlap Independence Check (MVP #5, 1pt)

**User Story:** As a developer, I'm warned before fan-out if two units touch the same file.

**Acceptance Criteria:**
- Pre-fan-out gate checks unit file lists for intersection
- If overlap found, blocks with warning listing conflicting files and units
- Developer can override or request re-decomposition

## Non-Functional Requirements

- **NFR-1: No workflow engine changes** — Batch workflow must work within existing BikeLane infrastructure. Zero modifications to workflow-schema.ts or handoff.ts.
- **NFR-2: Additive only** — No migration needed for existing workflows, sessions, or sprint data. Batch is a new workflow alongside tdd/trivial/bdd.
- **NFR-3: Worktree cleanup** — No stale `.claude/worktrees/batch-*` directories after 24h. Claude Code manages lifecycle; Pennyfarthing monitors.
- **NFR-4: Graceful failure** — Failed units report status clearly in session. Batch blocks at review gate on any failure — doesn't silently pass.
- **NFR-5: Unit count range** — Respects `/batch` hard constraint of 5-30 units per run.

## Technical Architecture Reference

### Batch Workflow YAML (Architect-Validated)

```yaml
workflow:
  name: batch
  phases:
    - name: decompose
      agent: architect
      output: [unit_definitions, independence_check]
      gate:
        type: manual
        condition: Unit boundaries approved
    - name: fan-out
      agent: orchestrator
      input: [unit_definitions]
      output: [unit_results, unit_prs]
      gate:
        type: manual
        condition: All batch units resolved
    - name: review
      agent: reviewer
      input: [unit_results, unit_prs]
      output: [approval]
      gate:
        type: approval
        condition: Batch consistency review approved
    - name: finish
      agent: sm
      input: [approval]
      output: [archived_session]
```

### Key Design Decisions

1. **Fan-out is a single phase** — orchestrator agent uses internal fan-out/fan-in pattern, not a new workflow engine concept
2. **Session uses XML** — `<units>` element, not YAML, consistent with session schema
3. **Failed units block the batch** — strict by default, partial completion deferred to Growth
4. **No tandem observers** — unnecessary overhead for isolated worktree execution
5. **New workflow type** — standalone `batch`, not a modifier on existing workflows

## References

- Claude Code `/batch` command (3-phase: research → plan → execute, 5-30 units, worktree isolation)
- `pennyfarthing-dist/patterns/fan-out-fan-in-pattern.md`
- `pennyfarthing-dist/schemas/workflow-schema.md`
- Architect feasibility review (Vito Cornelius, 2026-03-03)
- Party Mode brainstorm session (2026-03-03)
