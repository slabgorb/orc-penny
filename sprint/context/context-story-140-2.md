---
parent: context-epic-140.md
workflow: trivial
---

# Story 140-2: Add Session Units XML Tracking

## Business Context

Batch workflow success depends on visibility. When the orchestrator fans out 5-30 parallel agents, developers and reviewers need to see at a glance:
- How many units are in this batch?
- What's the status of each unit (pending, in_progress, completed, failed)?
- Which branch and PR does each unit own?

Without session-level unit tracking, batch runs become black boxes — no way to distinguish between "everything passed" and "3 units passed, 2 failed, 1 hung." Batch gates (review, finish) cannot proceed without reading unit status from the session file. Session files are the authoritative record of work within Pennyfarthing ceremony; batch units must be tracked there alongside phases, agents, and acceptance criteria.

## Technical Guardrails

The session file is structured XML. Existing elements (`<meta>`, `<status>`, `<acceptance-criteria>`, `<work-log>`) follow consistent patterns:
- Machine-readable attributes for state (`phase="setup"`, `status="done"`)
- Grep-parseable — agents and scripts extract values using simple patterns like `grep -oP 'status="[^"]*"'`
- Descriptive text content for human readability

The new `<units>` element must integrate seamlessly with this design:
- XML structure (not YAML) — consistent with session schema
- Each `<unit>` uses attributes for programmatic fields (id, status, branch, PR URL, worktree path)
- Unit description as text content for human context
- Schema documentation must show exact attribute requirements and valid status values

## Scope Boundaries

**In scope:**

- Add `<units>` element to session XML schema documentation (`pennyfarthing-dist/schemas/session-schema.md`)
- Document `<unit>` child element with all required attributes: `id`, `status`, `description` (content), `worktree` (path), `branch`, `pr` (URL)
- Document valid status values: `pending`, `in_progress`, `completed`, `failed`
- Add parsing guidance showing how agents/scripts extract unit status with grep
- Include example XML snippet showing a multi-unit batch with mixed status values
- Add `<units>` to the complete schema example and "After Review" example in the documentation

**Out of scope:**

- Implementing tooling to write/update units in the session file — that's story 140-4 (fix-session-phase extension)
- Building batch workflow YAML — that's story 140-1
- Orchestrator fan-out logic — that's story 140-3
- File-overlap checking — that's epic 138 (story 138-5)

## AC Context

**AC 1: `<units>` element added to complete schema**
- Session schema documentation at `pennyfarthing-dist/schemas/session-schema.md` shows a `<units>` container with at least one `<unit>` child in the "Complete Schema" section
- The example must reflect a realistic multi-unit batch (minimum 2 units with different statuses)

**AC 2: Unit attributes documented**
- Schema reference section includes `<unit>` element documentation
- All 6 attributes listed with required/optional status: `id` (required, numeric), `status` (required, enum), `branch` (required, string), `pr` (optional, URL string), `worktree` (required, file path), plus text content (description, required)
- Status enum values explicitly documented: `pending`, `in_progress`, `completed`, `failed`

**AC 3: Units element integrated into examples**
- "New Session" example includes empty or starter `<units>` placeholder
- "After Review" example shows `<units>` with 3+ units in various states (at least one completed, one failed to match journey 2 "partial failure" scenario)
- Example demonstrates grep-parseable format — status attributes extractable with `grep -oP 'status="[^"]*"'`

**AC 4: Parsing guidance added**
- New subsection under "Parsing Guidance" (after AC status extraction) shows:
  - Extract all unit IDs: `grep -oP 'unit id="[^"]*"'`
  - Extract failed unit count: `grep -c 'status="failed"'`
  - Extract unit PR URLs: `grep -oP 'pr="[^"]*"'`

**AC 5: No schema changes**
- Documentation additions do NOT modify the workflow schema or introduce any XML namespaces
- Existing session XML examples remain valid (no breaking changes)
- Schema validation rules (if any) remain unchanged
