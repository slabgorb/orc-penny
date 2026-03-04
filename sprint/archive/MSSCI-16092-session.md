# 140-2: Add Session Units XML Tracking

**Story:** 140-2
**Jira:** MSSCI-16092
**Epic:** 140 — Batch Execution & Tracking
**Workflow:** trivial
**Phase:** finish
**Repos:** orchestrator
**Branch:** 140-2/session-units-xml-tracking
**Assigned:** keithavery

## Story Context

Batch workflow success depends on visibility. When the orchestrator fans out 5-30 parallel agents, developers and reviewers need to see at a glance:
- How many units are in this batch?
- What's the status of each unit (pending, in_progress, completed, failed)?
- Which branch and PR does each unit own?

Session files are the authoritative record of work within Pennyfarthing ceremony. This story adds the `<units>` XML element to the session schema for tracking parallel batch execution units.

## Acceptance Criteria

**AC 1: `<units>` element added to complete schema**
- Session schema documentation at `pennyfarthing-dist/schemas/session-schema.md` shows a `<units>` container with at least one `<unit>` child in the "Complete Schema" section
- Example reflects realistic multi-unit batch (minimum 2 units with different statuses)

**AC 2: Unit attributes documented**
- Schema reference section includes `<unit>` element documentation
- All 6 attributes listed with required/optional status: `id` (required, numeric), `status` (required, enum), `branch` (required, string), `pr` (optional, URL string), `worktree` (required, file path), plus text content (description, required)
- Status enum values explicitly documented: `pending`, `in_progress`, `completed`, `failed`

**AC 3: Units element integrated into examples**
- "New Session" example includes empty or starter `<units>` placeholder
- "After Review" example shows `<units>` with 3+ units in various states (at least one completed, one failed)
- Example demonstrates grep-parseable format

**AC 4: Parsing guidance added**
- New subsection under "Parsing Guidance" shows:
  - Extract all unit IDs: `grep -oP 'unit id="[^"]*"'`
  - Extract failed unit count: `grep -c 'status="failed"'`
  - Extract unit PR URLs: `grep -oP 'pr="[^"]*"'`

**AC 5: No schema changes**
- Documentation additions only (no workflow schema or XML namespace changes)
- Existing session XML examples remain valid (no breaking changes)

## Technical Approach

1. Read existing session schema documentation (`pennyfarthing-dist/schemas/session-schema.md`)
2. Add comprehensive documentation for the `<units>` XML element and its `<unit>` children:
   - Explain the purpose: tracking parallel batch execution units
   - Define required attributes: `id`, `status`, `branch`, `worktree`, `description` (text content)
   - Define optional attributes: `pr` (URL)
   - Enumerate valid status values: `pending`, `in_progress`, `completed`, `failed`
3. Update schema examples:
   - Add `<units>` placeholder to "New Session" example
   - Show realistic multi-unit `<units>` in "After Review" example with mixed statuses
4. Add parsing guidance section showing grep patterns for extracting unit data
5. Verify no breaking changes to existing schema validation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/schemas/session-schema.md` — Added `<units>` element to complete schema, element reference, usage examples, and parsing guidance

**Tests:** N/A (documentation-only change)
**Branch:** `140-2/session-units-xml-tracking` (orchestrator), `feature/138-2-simplify-quality-subagent` (pennyfarthing — piggyback commit)

**ACs Met:**
- AC 1: `<units>` in Complete Schema with 3 units in different statuses
- AC 2: `<unit>` element reference with all 6 attributes documented, status enum defined
- AC 3: Empty `<units/>` in New Session example, 4 units with mixed statuses in After Review
- AC 4: Parsing guidance with 5 grep patterns for unit data extraction
- AC 5: No schema changes — documentation additions only

**Handoff:** To Reviewer (Josh Lyman) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** N/A — documentation-only change, no runtime paths
**Pattern observed:** Element reference follows established format (attribute table, content description, status enum) consistent with `<ac>`, `<entry>`, `<assessment>` at `session-schema.md:149-166`
**Error handling:** N/A — schema documentation
**Observations:**
- `[VERIFIED]` All 5 ACs met — schema, reference, examples, parsing, no breakage
- `[LOW]` `grep -c 'status="failed"'` not unit-scoped (pre-existing pattern)
- `[LOW]` `grep -oP` requires GNU grep on macOS (pre-existing pattern)

**Handoff:** To SM (Leo McGarry) for finish-story

## Delivery Findings

- No upstream findings during implementation.

### Reviewer (code review)
- No upstream findings during code review.

## SM Assessment

- **Workflow:** trivial (1pt → straight to Dev)
- **Risk:** Low — documentation-only change, no code modifications
- **Dependencies:** None apparent
- **Repos:** orchestrator (sprint tracking)
- **Key Files:**
  - `pennyfarthing-dist/schemas/session-schema.md` — primary deliverable