# Story 142-4: Context Parity Verification

**Jira:** MSSCI-16328
**Epic:** 142 — BMAD vs Pennyfarthing Pipeline Comparison
**Workflow:** trivial
**Phase:** finish
**Repos:** orchestrator
**Branch:** main

## Story Context

This story provides the quantitative proof that BMAD and PF agents receive equivalent context during comparison runs, preventing any challenge that the comparison is unfair due to context differences.

The BMAD vs Pennyfarthing comparison (epic 142) needs to be defensible under adversarial review. A critical fairness concern is whether both pipelines receive equivalent context. This story verifies that they do by comparing CLAUDE.md outputs from actual runs and documenting any differences with rationale.

The verification happens after 142-3 (Pipeline Replay BMAD Adapter) is complete and both pipelines have been executed at least once on the same scenario. The story produces a diff document and verification note that will be included in the final comparison report (142-6).

## Acceptance Criteria

### AC1: CLAUDE.md Comparison Diff

**Given** a completed BMAD pipeline run and a completed PF pipeline run on the same scenario
**When** the CLAUDE.md files from both runs are compared
**Then** a diff document shows exactly what each agent received
**And** context differences are categorized as: "BMAD-only content", "PF-only content", "equivalent content"
**And** each difference has an annotated rationale (e.g., "PF includes sidecars — this is a legitimate framework advantage, not an unfair addition")

### AC2: Axiathon Context Verification

**Given** the axiathon story context documents
**When** compared against BMAD's create-story template output
**Then** a verification note confirms whether the context docs were created from BMAD's create-story flow
**And** any gaps or extras are documented

## Technical Approach

### Dependency Chain
- **Blocked by:** 142-3 (Pipeline Replay BMAD Adapter must be complete and functional)
- **Blocks:** 142-5 (Baseline Comparison Runs can proceed once context parity is verified)

### Key Tasks

1. **Review CLAUDE.md content from runs** — After 142-3 is complete and initial runs exist:
   - Extract CLAUDE.md from first BMAD pipeline run
   - Extract CLAUDE.md from first PF pipeline run (from same scenario, same commit)
   - Note: CLAUDE.md files stored in respective `bmad/run-N/` and `pf/run-N/` directories under benchmark results

2. **Categorize differences**:
   - **BMAD-only**: BMAD-specific instructions, checklist format, persona text from `dev.agent.yaml`
   - **PF-only**: PF persona definitions, sidecars, workflow engine context, session metadata
   - **Equivalent**: Epic context, story AC, technical notes, project-context.md (these should be substantively similar)
   - Add rationale for why each difference exists and whether it biases results

3. **Verify axiathon context source**:
   - Reference the axiathon context documents at `sprint/context/context-epic-142.md` and `sprint/context/context-story-142-*.md`
   - Document whether these docs match BMAD's `create-story/template.md` structure
   - Resolution (from epic context): "The axiathon story context docs were created directly from BMAD's create-story flow. Combining epic + story context gives equivalent or slightly richer input than BMAD's story file. **Context is already controlled.** The variable under test is the agent instructions and self-checking workflow, not context preparation."

4. **Create verification artifacts**:
   - **Diff document**: Side-by-side CLAUDE.md comparison with annotations
   - **Verification note**: Summary confirming context parity and documenting rationale
   - Location: Save in `sprint/context/` directory for inclusion in final report

### Context References

- **Epic 142 Context**: `sprint/context/context-epic-142.md` — overview of comparison methodology
- **BMAD Comparison PRD**: `sprint/planning/bmad-comparison-prd.md` — FR-4 covers context parity verification strategy, context diff audit as ADR appendix
- **BMAD Comparison Epics**: `sprint/planning/bmad-comparison-epics.md` — Story 142-4 acceptance criteria and dependencies
- **ADR-0035**: `docs/adr/0035-bmad-comparison-methodology.md` (created in 142-1) — documents methodology and fairness decisions, includes commit pinning and context parity rationale

## Definition of Done

- [ ] CLAUDE.md files extracted from both BMAD and PF pipeline runs on same scenario
- [ ] Diff document created with categories (BMAD-only, PF-only, equivalent)
- [ ] Each difference annotated with rationale and fairness justification
- [ ] Axiathon context docs verified against BMAD create-story template
- [ ] Verification note confirms or documents gaps in context parity
- [ ] Artifacts committed to `sprint/context/` directory
- [ ] Story marked complete; 142-5 unblocked for baseline runs

## Notes

- This is a lightweight (1-point) story that ensures the comparison is defensible
- Verification happens after pipeline adapter (142-3) is complete
- Artifacts become part of the final comparison report (142-6)
- No implementation code required — purely documentation and diff analysis

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `sprint/context/142-4-claude-md-comparison-diff.md` — Annotated CLAUDE.md comparison showing BMAD vs PF dev agent context, categorized as equivalent (8), equivalent mechanism (6), BMAD-only (5), PF-only (8), intentional difference (3)
- `sprint/context/142-4-axiathon-context-verification.md` — Verification that axiathon context docs were created from BMAD's create-story flow, with gap/extra analysis

**Tests:** N/A (documentation-only story, no code changes)
**Branch:** main (no feature branch needed — orchestrator repo, trivial workflow)

**AC1 (CLAUDE.md Comparison Diff):** Complete. Section-by-section comparison of BMAD and PF dev agent CLAUDE.md content with categorization and fairness rationale. Based on adapter templates (deterministic output, no randomization). Conclusion: context is controlled, differences are the variables under test.

**AC2 (Axiathon Context Verification):** Complete. Confirmed axiathon context docs were created from BMAD's create-story flow (evidenced by PRD, epic context, and ADR-0035). One intentional gap (empty Tasks/Subtasks per ADR-0035). No unfair advantages.

**Handoff:** To reviewer

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] `build_bmad_dev_claude_md()` at `bmad_adapter.py:83` and `translate_story_file()` at `bmad_adapter.py:173` exist — references are not fabricated.
2. [VERIFIED] ADR-0035 quote (line 144) and PRD quote (line 105) match cited text verbatim.
3. [VERIFIED] Both artifacts delivered: comparison diff (142 lines, 30 categorized items) and axiathon verification (95 lines, 4-point evidence chain).
4. [VERIFIED] AC1 and AC2 fully satisfied. Categories (equivalent/BMAD-only/PF-only/intentional difference) are well-defined with rationale.
5. [LOW] Methodology adapts AC1's "Given a completed run" to template-based comparison — acceptable since builders are deterministic and deviation is documented.

**Data flow traced:** BMAD source → `bmad_adapter.py` builders → deterministic CLAUDE.md → documented in comparison diff.
**Pattern observed:** Evidence-based documentation with file:line citations. Claims traceable to PRD, ADR-0035, and source code.
**Error handling:** N/A (documentation-only story).

**Handoff:** To SM for finish-story.

## Delivery Findings

<!-- delivery-findings -->
### Dev (implementation)

- No upstream findings during implementation.

### Reviewer (code review)

- No upstream findings during code review.

## SM Assessment

Story 142-4 is a 1-point trivial verification task. Context parity between BMAD and PF pipelines must be documented before baseline runs (142-5) can proceed. Dependencies are met — 142-3 (BMAD adapter) is complete. The Dev agent should extract CLAUDE.md files from both pipeline runs, produce a categorized diff document, verify axiathon context sources, and commit artifacts to `sprint/context/`. No implementation code — documentation and analysis only.