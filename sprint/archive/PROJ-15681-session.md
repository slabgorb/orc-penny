# Story 129-1: Fix Context Check Bugs in sprint-data.ts

**Jira:** PROJ-15681
**Epic:** PROJ-15680 — Context Validation & Visibility
**Points:** 1
**Type:** fix
**Repos:** pennyfarthing
**Workflow:** trivial
**Phase:** implement
**Assigned:** keith.avery@slabgorb.io
**Started:** 2026-02-25

## Context

Per ADR-0029 "Formalized Epic & Story Context Creation", two critical bugs exist in context-checking code that cause the Cyclist sprint panel to inaccurately report context status:

1. **`checkStoryContext` filename pattern bug:** Currently searches for `{storyId}-context.md` but actual context files follow the pattern `context-story-{N-N}.md`. Result: every story context check returns false even when context exists.

2. **`checkEpicContext` PROJ regex failure:** The regex `\d+` for matching epic IDs only handles numeric epics (e.g., `129`), but fails for PROJ-keyed epics (e.g., `PROJ-15680`). Result: PROJ epic context checks always return false.

Three separate context-checking implementations currently exist:
- `sprint-data.ts:checkStoryContext()` — wrong filename pattern
- `sprint-data.ts:checkEpicContext()` — PROJ regex failure
- `generic-sm-setup.ts:checkEpicContext()` — works for numeric, untested for PROJ

**Correct reference implementation:** Python `pf/context_docs/story_detail_data.py:177-208` handles both patterns correctly.

**Impact:** Gates and Cyclist panel cannot accurately determine if context exists before story work begins, violating the gate-enforced context validation requirement in ADR-0029.

## Acceptance Criteria

- [ ] Fix `checkStoryContext()` in `packages/core/src/workflow/generic-sm-setup.ts` to match `context-story-{id}.md` pattern
- [ ] Fix `checkEpicContext()` in `packages/core/src/workflow/generic-sm-setup.ts` to handle both numeric (e.g., `129`) and PROJ-keyed (e.g., `PROJ-15680`) epic IDs
- [ ] Both functions return `{exists: true, path}` on success and `{exists: false, message, expectedPath}` on failure
- [ ] No additional refactoring — fixes are additive and minimal (2-3 lines per function)
- [ ] Verify both patterns work: numeric epic `129`, PROJ epic `PROJ-15680`, story `129-1`

## Technical Approach

1. **Fix checkEpicContext regex:** Replace `^\d+$` with pattern that matches both `\d+` (numeric) and `PROJ-\d+` formats
2. **Verify checkStoryContext:** Ensure it searches for `context-story-{id}.md`, not `{id}-context.md`
3. **Test manually:** Create test context files matching both patterns and verify detection
4. **Update logic in generic-sm-setup.ts:** The fixes maintain backward compatibility with existing ~50 context files

## Implementation Notes

- Location: `/Users/keithavery/Projects/pf-3/pennyfarthing/packages/core/src/workflow/generic-sm-setup.ts` lines 429-447
- Regex should match: `^\d+$` (epic 129) and `^PROJ-\d+$` (epic PROJ-15680)
- File pattern: `context-epic-{id}.md` (e.g., `context-epic-129.md`, `context-epic-PROJ-15680.md`)
- Story context pattern: `context-story-{id}.md` (e.g., `context-story-129-1.md`)