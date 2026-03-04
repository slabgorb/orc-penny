# Story 137-6: Remove legacy text menus from migrated switch files

**Jira:** MSSCI-16068
**Repos:** pennyfarthing
**Branch:** feat/137-6-remove-legacy-text-menus
**Workflow:** trivial
**Phase:** finish
**Status:** in_progress
**Assigned:** keith.avery@1898andco.io

## Story Context

### Description
During the migration from static text-based collaboration menus to structured AskUserQuestion tool calls (story 137-2), step files were updated to use `<switch tool="AskUserQuestion">` tags for user choices. However, many step files still contain legacy text menu references like `[C] Continue`, `[A] Approve`, `[P] Proceed`, `[R] Review`, `[S] Skip` in instructions, descriptions, and output sections. These legacy menu markers should be removed or replaced with references to the structured choice mechanism.

### Acceptance Criteria
- [ ] Identify all workflow step files containing legacy text menu markers ([C], [A], [P], [R], [S])
- [ ] Remove or refactor legacy text menu references (approximately 103 files contain these patterns)
- [ ] Update instructions and descriptions to reference structured <switch> choices instead
- [ ] Verify removed legacy markers don't impact workflow functionality
- [ ] No duplicate choice options in either legacy or new format
- [ ] Documentation reflects switch-based UI interactions only

### Key Files
- `pennyfarthing/pennyfarthing-dist/workflows/*/steps/*.md` — Step files with legacy menus (103 files identified)
- Related to commit e59aee297 (feat 137-2) which migrated static menus to <switch> tags
- Schema documented in `pennyfarthing-dist/schemas/workflow-step-schema.md`

## Technical Approach

1. **Audit phase**: Search workflow step files for legacy text menu patterns (`[C]`, `[A]`, `[P]`, `[R]`, `[S]`)
2. **Categorize findings**: Group by workflow and file type to understand scope
3. **Remove/Refactor**: For each file:
   - Remove standalone legacy menu lines (e.g., `[C] Continue - ...`)
   - Update instructions that mention `[C]` to reference the switch option instead
   - Update descriptions that list menu choices to reflect structured approach
   - Keep references to actual switch case values where appropriate
4. **Validation**: Verify syntax remains correct in updated files
5. **Testing**: Ensure no workflows are broken by the removals

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:** 109 workflow step/YAML files across `pennyfarthing-dist/workflows/`
- Removed Collaboration Menu, Advanced Elicitation Mode, Party Mode sections
- Removed standalone menu items, Display: lines, Menu Handling Logic blocks
- Updated inline references to "switch prompt" mechanism
- Cleaned code block mock-ups and workflow YAML descriptions

**Net change:** -1605 lines (411 insertions, 2016 deletions)
**Tests:** N/A (markdown content cleanup)
**Branch:** feat/137-6-remove-legacy-text-menus (pushed)

**False positives kept:** 3 table/example placeholders using `[A]`/`[B]`

**Handoff:** To Reviewer for code review.

## Reviewer Assessment

**Verdict:** APPROVED
**Observations:**
1. `[VERIFIED]` All 82 `<switch>` tags intact — zero removed
2. `[VERIFIED]` 3 remaining `[CAPRS]` are false positives (table/example text)
3. `[HIGH]` Missing spaces in regex replacements — FIXED in commit b9761f2
4. `[VERIFIED]` Legacy sections (Collaboration Menu, Advanced Elicitation, Party Mode) removed
5. `[VERIFIED]` Inline references updated to "switch prompt" consistently
6. `[LOW]` Some replacement phrasing slightly awkward but functionally correct

**Handoff:** To SM (The Mad Hatter) for finish-story

## Delivery Findings

- No upstream findings during implementation.

### Reviewer (code review)
- No upstream findings during code review.

## SM Assessment

Setup complete. Trivial workflow (1 point, chore task) — straightforward codebase cleanup requiring systematic search and replace across workflow files. Routing to Dev (The White Rabbit) to implement the cleanup.

---

**Created:** 2026-03-03
**Agent:** sm-setup