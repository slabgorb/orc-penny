# Story 137-2: Replace static collaboration menus with AskUserQuestion

**Jira:** MSSCI-15922
**Epic:** 137 — Stepped workflow modernization — gates, AskUserQuestion, and collaboration
**Points:** 2
**Type:** feature
**Priority:** p1
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-15922-askuserquestion-menus

## Description

Update workflow-step-schema to define <collaboration-menu> → AskUserQuestion mapping. Add tool="AskUserQuestion" attribute to signal structured choices. Migrate all stepped workflow step files (~90 files across architecture, release, prd, quick-dev, ux-design, epics-and-stories, sprint-planning, guided-tour, installation-check, project-setup, etc.). Update xml-tags.md taxonomy.

## Acceptance Criteria

- [ ] workflow-step-schema.md updated with <switch> element and AskUserQuestion mapping
- [ ] All stepped workflow step files migrated from text menus to <switch> tags where branching occurs
- [ ] <collaboration-menu> retained only for simple loop menus (no step transitions)
- [ ] xml-tags.md updated with <switch>, <case>, <default> tag documentation
- [ ] Existing workflow behavior preserved (no functional changes)

## Technical Approach

Mechanical migration guided by ADR-0032. For each step file:
1. If collaboration menu has options that navigate to different steps → replace with <switch tool="AskUserQuestion">
2. If all options loop back (A/P/C where only C proceeds) → keep <collaboration-menu> or convert to <switch>
3. Update schema docs and xml-tags taxonomy

Reference: docs/adr/0032-stepped-workflow-switch-gate-output-tags.md

## Delivery Findings

<!-- Delivery Findings: agents append below this line -->

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): 28/73 step files (38%) have dual navigation — old `**[X]** Label` text menus and `<!-- CYCLIST:CHOICES -->` markers remain alongside new `<switch>` blocks. Cleanup as follow-up chore. Affects `pennyfarthing-dist/workflows/{architecture,git-cleanup,interactive-debug,prd/steps-e,quick-spec,release}/steps/` (remove old text menus where `<switch>` now provides authoritative navigation). *Found by Reviewer during code review.*

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `schemas/workflow-step-schema.md` — added `<switch>`, `<case>`, `<default>` element definitions
- `guides/taxonomy/xml-tags.md` — documented `<switch>`, updated `<collaboration-menu>` scope
- 73 step files across 14 workflows — migrated text menus to `<switch tool="AskUserQuestion">`
  - architecture (8), epics-and-stories (2), git-cleanup (4), guided-tour (5), installation-check (8), interactive-debug (4), party-mode (1), prd (12), product-brief (4), project-context (1), project-setup (9), quick-spec (2), release (10), ux-design (11)
- `<collaboration-menu>` retained only in `party-mode-roleplay/step-02-discussion.md` (loop-only menu)

**Tests:** N/A — markdown-only migration, no code changes
**Branch:** feat/MSSCI-15922-askuserquestion-menus (pushed)

**Handoff:** To Reviewer (Jean-Baptiste Emanuel Zorg)

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** User selects "continue" → `<case value="continue" next="step-04-components">` → `step-04-components.md` exists (verified all 73 next targets resolve)
**Pattern observed:** Consistent `<switch tool="AskUserQuestion">` with `<case value="" next="">` across all files, following ADR-0032 schema
**Error handling:** No `<default>` elements used (optional per schema for user-choice switches). Zero broken navigation references.
**Security:** N/A (markdown-only, no code execution paths)

| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | [VERIFIED] | Schema additions correct (`<switch>`, `<case>`, `<default>`) | `schemas/workflow-step-schema.md` |
| 2 | [VERIFIED] | Taxonomy updates correct | `guides/taxonomy/xml-tags.md` |
| 3 | [VERIFIED] | All navigation targets valid (zero dangling refs) | All 73 step files |
| 4 | [VERIFIED] | Party-mode `<collaboration-menu>` correctly retained | `party-mode-roleplay/step-02-discussion.md` |
| 5 | [VERIFIED] | ADR-0032 compliance | All `<switch>` elements |
| 6 | [MEDIUM] | Dual navigation in 28/73 files (38%) — old text menus not removed | architecture(8), git-cleanup(4), interactive-debug(4), prd/steps-e(1), quick-spec(1), release(10) |
| 7 | [LOW] | Case value naming inconsistency (terse vs verbose slugs) | Scattered |

**Handoff:** To SM (Ruby Rhod) for finish-story