# Story 140-1: Create Batch Workflow YAML

**Story ID:** 140-1
**Jira:** MSSCI-16091
**Epic:** 140 — Batch Execution & Tracking
**Repos:** pennyfarthing
**Branch:** feat/140-1-batch-workflow-yaml
**Workflow:** trivial
**Phase:** finish
**Status:** in_progress

## Acceptance Criteria

**AC-1: Workflow YAML exists and is well-formed**
- File created at `pennyfarthing/pennyfarthing-dist/workflows/batch-workflow.yaml`
- YAML syntax is valid (can be parsed by `yaml` library without errors)
- Includes all required fields: `workflow.name`, `workflow.phases` with phase names and agents

**AC-2: Conforms to workflow schema without requiring schema changes**
- Run the existing workflow validator against the file
- Validator output: zero errors, zero warnings
- No modifications to the schema itself are needed — the workflow uses only existing gate types (manual, approval) and existing phase structure

**AC-3: Implements the 4-phase batch workflow architecture**
- Phase 1: `decompose` — assigned to `architect` agent, output includes unit_definitions and independence_check
- Phase 2: `fan-out` — assigned to `orchestrator` agent, input from decompose, output includes unit_results and unit_prs
- Phase 3: `review` — assigned to `reviewer` agent, input from fan-out, output is approval
- Phase 4: `finish` — assigned to `sm` agent, input from review, output is archived_session

**AC-4: Gates are correctly configured**
- `decompose` phase has a manual gate with condition "Unit boundaries approved"
- `fan-out` phase has a manual gate with condition "All batch units resolved"
- `review` phase has an approval gate with condition "Batch consistency review approved"
- `finish` phase has no gate (final phase)

**AC-5: Includes triggers for batch story routing**
- `triggers.tags` includes `batch` so stories tagged with `batch` are routed to this workflow
- If appropriate, include `triggers.types` or `triggers.points` based on expected batch story patterns (optional per schema, but recommended for clarity)

**AC-6: Follows existing workflow patterns and style**
- Structure and formatting match `tdd.yaml`
- Phase names are descriptive and align with batch workflow terminology
- Input/output arrays document data flow between phases
- Gate definitions use consistent condition messaging
- Includes `workflow.version` and `workflow.description` for maintainability

**AC-7: Is ready for downstream stories**
- Orchestrator agent can read this workflow to understand the fan-out phase responsibilities
- Session tracking code can identify the `<units>` output that will be tracked
- Reviewer agent can understand that the review phase receives batch-wide results
- SM agent knows finish responsibilities are to archive and clean up

## Story Context

The batch workflow YAML is the foundational definition that enables all parallel batch execution within Pennyfarthing. Without this, the batch feature cannot be invoked, phases cannot be sequenced, gates cannot be evaluated, and agents cannot coordinate. This is the single source of truth that the workflow engine loads to orchestrate decompose → fan-out → review → finish.

This story creates a 4-phase workflow YAML that follows the existing workflow schema without requiring schema changes. It uses only existing gate types (manual and approval) and existing phase structures. The workflow defines how the architect decomposes work into units, the orchestrator fans out parallel execution, the reviewer approves the batch, and the SM finishes cleanup.

Key dependencies:
- Must follow the existing schema at `pennyfarthing/pennyfarthing-dist/schemas/workflow-schema.md`
- Must follow the pattern established by `pennyfarthing/pennyfarthing-dist/workflows/tdd.yaml`
- Must pass the existing workflow validator without modifications to the validator or schema
- Sets up the foundation for downstream stories (140-2, 140-3, and Epic 138)

## SM Assessment

**Setup Complete:** Yes
**Session:** `.session/140-1-session.md`
**Branch:** `feat/140-1-batch-workflow-yaml` (pennyfarthing repo)
**Jira:** MSSCI-16091 — claimed, In Progress
**Workflow:** trivial → Dev (Toby Ziegler)

**Handoff:** To Dev for implementation.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/workflows/batch-workflow.yaml` - 4-phase batch workflow definition

**Tests:** Validator passes (valid: true, zero errors)
**Branch:** feat/140-1-batch-workflow-yaml (pushed)

**Handoff:** To Reviewer (Josh Lyman) for code review.

## Reviewer Assessment

**Verdict:** APPROVED

**Review observations:**

1. `[VERIFIED]` Schema validation passes — `validateWorkflow()` returns `valid: true`, zero errors. All gate types (`manual`, `approval`) are in the valid set at `workflow-schema.ts:401`.
2. `[VERIFIED]` Data flow traced: `decompose` outputs `[unit_definitions, independence_check]` → `fan-out` receives as input, outputs `[unit_results, unit_prs]` → `review` receives as input, outputs `[approval]` → `finish` receives `[approval]`. Chain is complete with no orphaned inputs.
3. `[VERIFIED]` Phase-agent assignments match ACs exactly: decompose=architect, fan-out=orchestrator, review=reviewer, finish=sm. All valid agent names per `VALID_AGENT_NAMES` in `workflow-schema.ts:81`.
4. `[VERIFIED]` Trigger routing works — `triggers.tags: [batch]` will be matched by `findTriggerTagMatch()` in `workflow-router.ts:178-211`. Workflow name `batch-workflow` aligns with filename for `prime/workflow.py:355` loader lookup.
5. `[MEDIUM]` `state.py:47` hardcoded `WORKFLOW_PHASES` dict does not include `batch-workflow` — `pf workflow phase-check batch-workflow decompose` will silently fall back to TDD phases and return `sm` instead of `architect`. Not blocking for this YAML-only story but will break agent phase-check on startup. Affects `pennyfarthing-dist/src/pf/workflow/state.py`.
6. `[VERIFIED]` Gate configuration: decompose and fan-out use `manual`, review uses `approval`, finish has no gate. All match ACs and are valid gate types.
7. `[VERIFIED]` No security concerns — static YAML definition file with no user input processing.

**Pattern observed:** Follows `tdd.yaml` structure (comments, description, version, phases with input/output/gate, triggers) at `pennyfarthing-dist/workflows/batch-workflow.yaml:1-42`.
**Error handling:** N/A for YAML definition — validator handles malformed input.

**Handoff:** To SM (Leo McGarry) for finish-story.

## Delivery Findings

<!-- Append-only. Each agent adds findings under their own subheading. -->

### Dev (implementation)

- **Gap** (non-blocking): Batch workflow has no `setup` phase — every other phased workflow starts with SM setup. Downstream stories may need to add setup if session creation isn't handled externally. Affects `pennyfarthing-dist/workflows/batch-workflow.yaml` (may need setup phase prepended). *Found by Dev during implementation.*
- **Question** (non-blocking): AC-1 specifies filename `batch-workflow.yaml` but project convention uses short names (`tdd.yaml`, `bdd.yaml`). Used AC filename but `workflow.name` had to be `batch-workflow` to match CLI loader expectations (filename=name). Affects `pennyfarthing-dist/workflows/batch-workflow.yaml` (naming convention). *Found by Dev during implementation.*

### Reviewer (code review)

- **Gap** (non-blocking): `pf workflow phase-check` uses hardcoded `WORKFLOW_PHASES` dict in `state.py` which lacks `batch-workflow`. Phase-check will silently return wrong agent for batch phases. Affects `pennyfarthing-dist/src/pf/workflow/state.py` (needs `batch-workflow` entry or migration to YAML-based lookup). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Dev's finding about missing `setup` phase is valid — every other phased workflow starts with SM setup. The batch workflow's first phase (`decompose`) goes straight to architect, meaning SM session creation must happen externally. Consider adding setup phase in a follow-up. Affects `pennyfarthing-dist/workflows/batch-workflow.yaml`. *Found by Reviewer during code review.*