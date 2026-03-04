# Story 140-4: Add Batch Fan-Out to Orchestrator Agent Definition

**Jira:** MSSCI-16094
**Epic:** 140 — Batch Execution & Tracking
**Points:** 1
**Repos:** pennyfarthing
**Branch:** chore/140-4-add-batch-fan-out-orchestrator-agent
**Workflow:** trivial
**Phase:** finish
**Assigned:** Keith Avery

## Acceptance Criteria

**AC 1: Batch section added to orchestrator agent definition**
- File: `pennyfarthing-dist/agents/orchestrator.md`
- New section titled `<batch-workflow>` or similar, placed in workflow-participation or delegation section
- Section explicitly states: "orchestrator spawns parallel agents via Task tool with `isolation: "worktree"`"
- References `pennyfarthing-dist/patterns/fan-out-fan-in-pattern.md` for parallelism model
- Testable via: `grep -A 10 "batch\|fan-out" pennyfarthing-dist/agents/orchestrator.md` returns section with fan-out instructions

**AC 2: Task tool invocation pattern documented**
- Instructions include concrete Task tool usage:
  - How to unpack unit definitions from decompose phase
  - How to construct Task calls with `isolation: "worktree"`
  - How to pass story acceptance criteria to each worker agent
- Example shows multiple Task calls in single message (implicit parallelism)
- Testable via: Section contains example code block showing multiple Task invocations

**AC 3: Session unit status update documented**
- Instructions describe calling `fix-session-phase --unit <id> --status <status>` after each unit completes
- Describes aggregating unit results (branch, PR URL, status)
- Testable via: Section mentions `fix-session-phase` and unit status tracking

**AC 4: Error handling and result aggregation described**
- Instructions state that failed units block batch at review gate
- Orchestrator collects all unit results (success/failure) before handoff
- Testable via: Section includes paragraph on partial failure handling and review gate blocking

**AC 5: Agent definition is syntactically valid and parseable**
- File passes `pf hooks schema-validation` for orchestrator.md
- No unclosed XML tags
- Testable via: `git commit` hook validation passes, agent can be activated via `/orchestrator`

## Technical Approach

The story requires extending the orchestrator agent definition with batch workflow fan-out instructions. The technical work involves:

1. **Read the current orchestrator agent definition** at `pennyfarthing-dist/agents/orchestrator.md` to understand its structure (role, critical constraints, helpers, workflows, coordination sections)

2. **Review the fan-out/fan-in pattern** at `pennyfarthing-dist/patterns/fan-out-fan-in-pattern.md` to understand the parallelism model and how the Task tool's implicit parallelism works

3. **Add a new `<batch-workflow>` section** to the orchestrator definition that covers:
   - Receiving unit definitions and acceptance criteria from the decompose phase
   - Spawning N parallel Task calls (where 5 ≤ N ≤ 30) with `isolation: "worktree"`
   - Passing story acceptance criteria to each worker agent
   - Collecting results (branch, PR URL, status) from each unit
   - Calling `fix-session-phase --unit <id> --status <status>` to update session
   - Aggregating results before handoff to review phase

4. **Include concrete example code** showing multiple Task invocations in a single message

5. **Document error handling** — failed units block batch at review gate; orchestrator collects all results before handoff

6. **Validate the file** — ensure no XML syntax errors and that schema validation passes

## SM Assessment

Story setup complete. 1-point trivial workflow — ready for development. Routes to Keith Avery (Dev).

The story is focused and well-scoped:
- Clear acceptance criteria tied to specific file locations and testable patterns
- Technical approach is documented in the context document
- Feature branch created and pushed
- No blockers identified

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/agents/orchestrator.md` — Added `<batch-workflow>` section with fan-out instructions, Task tool examples with `isolation: "worktree"`, unit status tracking via `pf workflow fix-phase --unit --status`, and error handling/result aggregation documentation

**Tests:** Schema validation passed on commit (AC5)
**Branch:** `chore/140-4-add-batch-fan-out-orchestrator-agent` (pushed)

**Handoff:** To Reviewer (Chrisjen Avasarala) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Session `<units>` → orchestrator reads → fan-out Agent calls (`isolation: "worktree"`) → parallel workers → `fix-phase` status update → result aggregation table → handoff to review. Coherent end-to-end.
**Pattern observed:** Well-structured 4-step workflow (unpack → fan-out → track → aggregate) at `orchestrator.md:162-246`
**Error handling:** Partial failure policy documented — failed units block at review gate, all results collected before handoff

| Severity | Issue | Location | Notes |
|----------|-------|----------|-------|
| [MEDIUM] | `--unit`/`--status` flags don't exist on `fix-phase` CLI yet | `orchestrator.md:218-219` | Forward-looking by design (epic 140 in progress); `<units>` also absent from session schema |
| [LOW] | "Agent tool" vs "Task tool" terminology mismatch with referenced pattern file | `orchestrator.md:158` | Orchestrator is correct; pattern file is outdated |
| [VERIFIED] | XML tags properly opened/closed | `orchestrator.md:155,247` | `<batch-workflow>` / `</batch-workflow>` |
| [VERIFIED] | Pattern file reference valid | `orchestrator.md:158` | `fan-out-fan-in-pattern.md` exists |
| [VERIFIED] | Implicit parallelism documented | `orchestrator.md:178` | Multiple Agent calls in single message |
| [VERIFIED] | Section placement correct | `orchestrator.md:155` | Between workflow-participation and handoffs |
| [VERIFIED] | Result aggregation format documented | `orchestrator.md:237-246` | Table with unit/status/branch/PR |

**Handoff:** To SM (Camina Drummer) for finish-story

## Delivery Findings

<!-- delivery-findings-marker -->
### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): `fan-out-fan-in-pattern.md` still uses "Task tool" terminology while orchestrator correctly uses "Agent tool". Affects `pennyfarthing-dist/patterns/fan-out-fan-in-pattern.md` (update terminology to match current Claude Code tool name). *Found by Reviewer during code review.*
- **Gap** (non-blocking): `<units>` XML element referenced in batch-workflow section is not yet defined in `schemas/session-schema.md`. Affects `pennyfarthing-dist/schemas/session-schema.md` (add `<units>` element definition when batch CLI is implemented). *Found by Reviewer during code review.*

---

## Handoff History

| Phase | Assigned | Status | Notes |
|-------|----------|--------|-------|
| setup | Keith Avery | completed | SM-setup: Session file created, branch initialized, Jira claimed |
| review | Chrisjen Avasarala | completed | APPROVED — no blocking issues |