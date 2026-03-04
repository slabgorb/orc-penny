# Story 138-6: Update TEA assessment template with simplify report section

**Jira:** MSSCI-16079
**Points:** 1
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-16079-update-tea-assessment-template
**Assigned:** keith.avery@1898andco.io

## Story Context

No additional context file found. Story is straightforward: update the TEA (Test Engineer Agent) assessment template by adding a simplify report section.

## Acceptance Criteria

- TEA assessment template updated with simplify report section
- Changes follow existing template conventions
- Code ready for review

## SM Assessment

1-point trivial story. TEA assessment template needs a simplify report section added. Routing to Dev (Naomi Nagata) via trivial workflow.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/agents/tea.md` - Added verify-phase assessment template with Simplify Report section

**Tests:** N/A (agent definition file, no tests applicable)
**Branch:** feature/MSSCI-16079-update-tea-assessment-template (pushed)

**Handoff:** To Reviewer for code review

## Delivery Findings

<!-- Delivery findings per ADR-0031 -->

### Dev (implementation)

- No upstream findings during implementation.

### Reviewer (code review)

- **Improvement** (non-blocking): Step 9 timeout guidance not duplicated in assessment template. Affects `pennyfarthing-dist/agents/tea.md` (could add timeout note to template for self-contained reference). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Template text → TEA agent reads `<assessment-template>` → writes assessment to session file. Template fields match verify-workflow Step 9 exactly.
**Pattern observed:** Phase-aware template organization (### Red Phase / ### Verify Phase) at `pennyfarthing-dist/agents/tea.md:335-380` — clean, follows existing conventions.
**Error handling:** N/A (documentation template, no runtime behavior)

**Handoff:** To SM (Camina Drummer) for finish-story