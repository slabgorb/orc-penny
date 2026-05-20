# Story 141-3 Context: Audit Unexported Hooks

**Story ID:** 141-3
**Jira Key:** PROJ-16130
**Slug:** audit-unexported-hooks

## Summary
Audit the hooks directory — 33 hook files but only 13 exported from index.ts. Delete dead code (useMessageStream, usePlanModeExit), export all remaining active hooks, and add an audit test to prevent regression.

## Acceptance Criteria
- [ ] useMessageStream.ts deleted (replaced by ClaudeContext)
- [ ] usePlanModeExit.ts deleted (never wired into UI)
- [ ] All remaining hooks exported from index.ts with their public types
- [ ] Audit test verifies every use*.ts has a corresponding export
- [ ] Build compiles clean
- [ ] No stale imports remain

## Technical Approach
1. Delete useMessageStream.ts and usePlanModeExit.ts (and its test)
2. Add exports for all 17 previously-unexported hooks to index.ts, grouped by category
3. Clean up stale references in doc comments
4. Write shell-based audit test consistent with existing test patterns
