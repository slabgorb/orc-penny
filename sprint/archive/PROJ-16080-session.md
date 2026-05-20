# Story 138-7: Define SIMPLIFY_RESULT structured finding format

**Jira:** PROJ-16080
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/138-7-simplify-result-format

## Story Details

Define the structured YAML format that every simplify teammate (reuse, quality, efficiency) returns when analyzing code during the TEA verify phase. This `SIMPLIFY_RESULT` format is the data contract that allows TEA to reliably aggregate, interpret, and apply findings from parallel teammates.

## Acceptance Criteria

1. **Schema Documentation Exists**
   - New file `pennyfarthing-dist/schemas/simplify-result-schema.md` documents the complete SIMPLIFY_RESULT YAML structure
   - Includes all required and optional fields with type definitions and constraints
   - Documents category value taxonomy for each teammate specialization
   - Explains confidence level definitions and how TEA interprets each level
   - Contains minimum 3 complete example outputs (clean report, single finding with high confidence, multiple findings with mixed confidence)

2. **Format Supports Non-Finding Cases**
   - Documentation clearly shows how to represent "no issues found" using `status: clean` and empty findings array
   - TEA can distinguish between "no findings" and "no response from teammate"

3. **Category Values Documented per Teammate**
   - Schema includes table/section listing valid `category` values for each teammate type:
     - simplify-reuse: duplicated-logic, extractable-helper, shared-constant, shared-type
     - simplify-quality: naming, dead-code, unclear-structure, unnecessary-comment, readability
     - simplify-efficiency: over-engineering, unnecessary-complexity, redundant-operation, premature-abstraction

4. **Confidence Level Semantics are Clear**
   - Documentation defines how TEA interprets confidence levels:
     - `high`: Auto-apply without manual review
     - `medium`: Review manually before applying
     - `low`: Document findings but do not apply without explicit review

5. **Schema References Agent Definitions**
   - Schema or related guide explicitly states format is used by:
     - `pennyfarthing-dist/agents/simplify-reuse.md`
     - `pennyfarthing-dist/agents/simplify-quality.md`
     - `pennyfarthing-dist/agents/simplify-efficiency.md`
     - `pennyfarthing-dist/agents/tea.md` (for aggregation)

## Technical Approach

This is a schema/documentation story. The deliverable is a new markdown file documenting the SIMPLIFY_RESULT YAML structure that the three simplify teammates will return. The file should:

1. Define the complete YAML schema with field descriptions, types, and constraints
2. Explain the confidence level semantics (high/medium/low) and how TEA uses them for applying/reviewing/rejecting findings
3. Document the category taxonomy for each teammate specialization
4. Provide complete example outputs showing both clean and findings cases
5. Reference the three simplify subagent definitions and TEA's aggregation logic

The context file (`sprint/context/context-story-138-7.md`) already exists with comprehensive technical details, schema definition, field descriptions, example outputs, and scope boundaries. Use this as the reference for the schema content.

## SM Assessment

**Routing:** Trivial workflow — straight to Dev (Toby). Schema/documentation story, no tests required beyond content validation.

**Context is strong:** Story context file already has the full schema spec, field definitions, category taxonomy, confidence levels, and example outputs. Dev should use `sprint/context/context-story-138-7.md` as the source of truth and produce `pennyfarthing-dist/schemas/simplify-result-schema.md`.

**Dependencies:** Stories 138-1 through 138-3 (the three simplify subagent definitions) are already complete. This schema documents their shared output contract. Story 138-4 (TEA integration) will consume this schema.

**Risk:** Low. Documentation-only deliverable with clear ACs.

## Delivery Findings

<!-- delivery-findings -->
### Dev (implementation)
- **Gap** (non-blocking): `simplify-quality.md` agent definition does not exist yet. Stories 138-1 (reuse) and 138-3 (efficiency) are complete, but 138-2 (quality) appears incomplete. Affects `pennyfarthing-dist/agents/simplify-quality.md` (needs to be created). *Found by Dev during implementation.*

### Reviewer (code review)
- **Conflict** (non-blocking): Schema documents `shared-constant`, `shared-type` for simplify-reuse but agent def uses `shared-validation`, `copy-paste-pattern`, `missing-abstraction`. Only 2 of 5 categories match. Affects `pennyfarthing-dist/agents/simplify-reuse.md` (categories need reconciliation with schema before 138-4). *Found by Reviewer during code review.*
- **Conflict** (non-blocking): Schema uses `redundant-operation` (singular) but simplify-efficiency agent def uses `redundant-operations` (plural). Agent also includes `excessive-options` not in schema. Affects `pennyfarthing-dist/agents/simplify-efficiency.md` (categories need reconciliation with schema before 138-4). *Found by Reviewer during code review.*
- **Gap** (non-blocking): Both existing agent defs include `files_analyzed` field in their SIMPLIFY_RESULT output examples, but schema omits it. Additive — won't break parsing, but schema is technically incomplete. Affects `pennyfarthing-dist/schemas/simplify-result-schema.md` (consider adding optional field). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Related section link `../../sprint/context/context-epic-138.md` is broken — resolves into pennyfarthing repo, not orchestrator where context files live. Affects `pennyfarthing-dist/schemas/simplify-result-schema.md:169` (remove or fix cross-repo link). *Found by Reviewer during code review.*

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/schemas/simplify-result-schema.md` — New schema documenting SIMPLIFY_RESULT YAML contract

**Tests:** N/A (documentation-only story)
**Branch:** feature/138-7-simplify-result-format (pushed)

**ACs Met:**
1. Schema file exists with all fields, types, constraints, categories, confidence semantics, and 3 examples
2. Non-finding cases documented (`status: clean` + empty array vs no response)
3. Category values per teammate in dedicated tables
4. Confidence level semantics with TEA action table (high/medium/low)
5. All four agent definitions referenced by path in Consuming Agents table

**Handoff:** To Reviewer (Josh Lyman) for review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Schema is consumed by TEA (story 138-4) to parse SIMPLIFY_RESULT from three simplify teammates. Format is prompt-driven (no runtime validation), so schema serves as documentation contract for agent prompts.
**Pattern observed:** Schema structure mirrors gate-schema.md pattern — `<info>` block, field tables, examples, consuming agents, related links. Consistent with existing schemas.
**Error handling:** Non-finding case (`status: clean`) and no-response case (no SIMPLIFY_RESULT returned) both documented at `simplify-result-schema.md:103-110`.
**Category mismatches:** MEDIUM — schema follows the canonical spec from story context; existing agent defs (138-1, 138-3) drifted during parallel development. Must be reconciled before 138-4 but not blocking for this schema story.
**Handoff:** To Leo McGarry (SM) for finish-story

## Key References

- **Epic Context:** `sprint/context/context-epic-138.md` — Overview of Simplify Integration and TEA's role
- **Story Context:** `sprint/context/context-story-138-7.md` — Complete schema specification and examples
- **Related Stories:**
  - 138-1: Create simplify-reuse subagent definition
  - 138-2: Create simplify-quality subagent definition
  - 138-3: Create simplify-efficiency subagent definition
  - 138-4: Extend TEA verify phase to spawn and aggregate simplify teammates