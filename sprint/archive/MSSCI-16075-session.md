# Session: MSSCI-16075 — Create simplify-quality subagent definition

## Story
- **ID:** 138-2 / MSSCI-16075
- **Epic:** 138 — Simplify Integration — automated code quality via TEA verify teammates
- **Points:** 1
- **Workflow:** trivial
- **Status:** backlog

## Acceptance Criteria
- [ ] Create `simplify-quality` subagent definition at `pennyfarthing/pennyfarthing-dist/agents/simplify-quality.md`
- [ ] Definition follows subagent pattern (role, context, tools, constraints, output format)
- [ ] Reuse pattern matches `simplify-reuse` from story 138-1
- [ ] Quality focus: code duplication, consistency, architecture violations
- [ ] Efficiency focus complements reuse and quality
- [ ] Ready for integration into TEA verify phase

## Repos: orchestrator
## Workflow: trivial
## Phase: setup
## Branch: feat/MSSCI-16075-simplify-quality-subagent

## SM Assessment
1-point trivial story. Create the `simplify-quality` subagent definition following the same pattern as `simplify-reuse` (138-1). Quality-focused mechanical analysis subagent targeting Haiku. Straightforward agent definition work — route directly to Korben Dallas (Dev).

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/agents/simplify-quality.md` - New subagent definition for code quality analysis

**Tests:** N/A (agent definition, no executable code)
**Branch:** feat/MSSCI-16075-simplify-quality-subagent (pushed)

**Handoff:** To Zorg (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** TEA spawns agent → agent reads FILE_LIST → analyzes files → returns SIMPLIFY_RESULT YAML (report-only, no writes)
**Pattern observed:** Structural match with simplify-reuse template verified across frontmatter, arguments, critical, role, responsibilities, workflow steps, output format, and example invocation
**Error handling:** Agent is report-only with no side effects; FILE_LIST filtering in Step 1 handles missing files
**Observations:**
- `[MEDIUM]` Stray `</output>` at simplify-quality.md:160 — orphan closing tag, copy-paste artifact
- `[LOW]` AC4 "code duplication" scope delegated to simplify-reuse — reasonable domain separation
- `[VERIFIED]` 6 quality categories fully non-overlapping with 5 reuse categories
- `[VERIFIED]` SIMPLIFY_RESULT format structurally identical to simplify-reuse
- `[VERIFIED]` Confidence heuristics quality-specific with same TEA action mapping

**Handoff:** To Ruby Rhod (SM) for finish-story

## Delivery Findings

<!-- Delivery findings from agents -->
### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): Stray `</output>` closing tag at end of `pennyfarthing-dist/agents/simplify-quality.md` line 160. Cosmetic structural error — orphan XML tag with no matching open. *Found by Reviewer during code review.*

## Notes
- Part of 3-agent simplify fan-out pattern (reuse, quality, efficiency)
- Use 138-1 (simplify-reuse) as template for format and structure
- Haiku-targeted subagent for mechanical quality analysis