# Axiathon Context Verification Note

**Story:** 142-4 (Context Parity Verification)
**Date:** 2026-03-10
**Purpose:** Verify that axiathon story context documents match BMAD's create-story template output, confirming context parity between pipelines.

## BMAD Create-Story Template Structure

Source: `BMAD-METHOD/src/bmm/workflows/4-implementation/create-story/template.md`
Commit: `b7315c6e329eb72dc464f4e540bb67cdd22a9749`

The BMAD create-story template defines this structure:

| Section | Purpose | Populated By |
|---------|---------|-------------|
| `## Story` | User story ("As a... I want... so that...") | create-story workflow |
| `## Acceptance Criteria` | Testable criteria | create-story workflow |
| `## Tasks / Subtasks` | Implementation task breakdown | create-story workflow |
| `## Dev Notes` | Architecture patterns, constraints, testing standards | create-story workflow |
| `### Project Structure Notes` | Path alignment, conflict detection | create-story workflow |
| `### References` | Source citations | create-story workflow |
| `## Dev Agent Record` | Agent model, debug logs, completion notes | dev agent (during execution) |
| `## File List` | Changed files list | dev agent (during execution) |

## PF Epic/Story Context Document Structure

Source: `sprint/context/context-epic-142.md` and `sprint/context/context-story-142-*.md`

PF context documents use this structure:

| Section | Purpose | Populated By |
|---------|---------|-------------|
| `## Overview` / `## Business Context` | Background and motivation | PM/SM during story setup |
| `## Technical Guardrails` | Architecture constraints, key files | Architect/SM during context creation |
| `## Scope Boundaries` | In/out of scope | PM during context creation |
| `## AC Context` | Detailed AC with testability notes | PM/TEA during context creation |
| YAML frontmatter (`parent`, `workflow`) | Metadata | SM during setup |

## Section-by-Section Mapping

| BMAD Section | PF Equivalent | Match Quality | Notes |
|--------------|---------------|---------------|-------|
| `## Story` (user story) | `## Business Context` | **Equivalent** | PF uses prose context instead of "As a... I want..." format. The `translate_story_file()` function reformats to BMAD's user story format. |
| `## Acceptance Criteria` | `## AC Context` | **Equivalent** | PF context docs contain Given/When/Then criteria. Story context ACs are copied verbatim into BMAD story file by the translator. |
| `## Tasks / Subtasks` | *Not present* | **Intentional gap** | PF agents derive tasks from ACs, not from a pre-populated task list. Left empty in BMAD story file per ADR-0035 to avoid introducing PF's task decomposition bias. |
| `## Dev Notes` | `## Technical Guardrails` + epic `## Technical Architecture` | **Equivalent** | The `translate_story_file()` function combines epic Technical Architecture and story Technical Guardrails into the Dev Notes section. |
| `### Project Structure Notes` | Embedded in Technical Guardrails | **Equivalent** | PF context docs include file paths and module structure within guardrails. |
| `### References` | Reference links in context docs | **Equivalent** | Both reference source documents; PF uses relative paths to sprint/planning/ and docs/adr/. |
| `## Dev Agent Record` | *Not applicable* | **Neutral** | BMAD-specific bookkeeping section populated during execution. PF uses session file + Dev Assessment instead. |
| `## File List` | *Not applicable* | **Neutral** | BMAD-specific tracking. PF relies on git for file tracking. |

## Verification: Were Axiathon Context Docs Created from BMAD's Create-Story Flow?

### Finding: **Yes — confirmed**

The axiathon scenario context documents (used in DPGD-116, DPGD-117) were created using BMAD's create-story planning workflow. Evidence:

1. **PRD states explicitly** (from `sprint/planning/bmad-comparison-prd.md`, Context Parity Analysis section):
   > "The axiathon story context docs were created directly from BMAD's create-story flow."

2. **Epic context confirms** (from `sprint/context/context-epic-142.md`, Key Fairness Decisions):
   > "Context parity: The axiathon story context docs were created from BMAD's create-story flow. Combining PF's epic + story context gives equivalent input to BMAD's story file."

3. **ADR-0035 documents** (Appendix A, Story File Translation section):
   > "BMAD's dev workflow expects a story file in a specific format (from create-story/template.md). The axiathon scenario context documents were created from BMAD's planning workflow, so translation is minimal."

4. **Structural alignment**: The `translate_story_file()` function in `bmad_adapter.py` performs only lightweight reformatting (prose → user story format, section name mapping) rather than substantive content transformation, confirming the source content is already equivalent.

## Gaps and Extras

### Gaps (present in BMAD template, absent in PF context)

| Gap | Impact | Resolution |
|-----|--------|------------|
| `## Tasks / Subtasks` left empty | BMAD dev agent may skip to step 6 (test authoring) when no incomplete tasks exist | **Accepted risk** per ADR-0035. The LLM interprets ACs and Dev Notes as implicit work scope. Populating tasks would inject PF's decomposition, biasing the comparison. |
| `## Dev Agent Record` starts empty | No prior agent learnings in BMAD story file | **Neutral** — this section is populated by the BMAD dev agent during execution, not pre-populated. |
| `## File List` starts empty | No prior file tracking | **Neutral** — same as Dev Agent Record. |

### Extras (present in PF context, absent in BMAD template)

| Extra | Impact | Resolution |
|-------|--------|------------|
| YAML frontmatter (`parent`, `workflow`) | PF metadata for workflow engine | **Not injected** into BMAD story file. Only affects PF's internal routing. |
| `## Scope Boundaries` (in/out of scope) | Explicit scope definition | **Equivalent to Dev Notes** — scope information is folded into the Dev Notes section during translation. |
| Dependency chain documentation | Cross-story dependency tracking | **Not injected** into BMAD story file. Relevant for PF's multi-story workflow, not single-story execution. |

## Conclusion

**Context is already controlled.** The axiathon story context documents were created from BMAD's create-story flow. The `translate_story_file()` function performs minimal reformatting to map PF's context structure back to BMAD's template format. Combining epic + story context gives equivalent or slightly richer input than BMAD's story file.

The single intentional gap (empty Tasks/Subtasks) is documented in ADR-0035 with rationale. All other differences are structural (section naming, metadata) rather than substantive.

**The variable under test is the agent instructions and self-checking workflow, not context preparation.**

Story 142-5 (Baseline Comparison Runs) is unblocked.
