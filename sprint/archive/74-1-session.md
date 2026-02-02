# Story 74-1: Tool intent summarizer

**Status:** completed
**Phase:** closed
**Workflow:** tdd
**Points:** 3
**Epic:** 74 - Tool Use Visualization
**Repos:** pennyfarthing

## Story Details

Create a utility that generates human-readable summaries of tool use intent.

**Examples:**
- Read: "Reading file src/foo.ts"
- Bash: "Running git status" or "Installing dependencies"
- Glob: "Finding TypeScript files in src/"
- Grep: "Searching for 'TODO' in codebase"
- Write: "Creating new file config.json"
- Edit: "Updating function in utils.ts"
- Task: "Launching explore agent to find error handlers"

## Acceptance Criteria

- [x] Generates readable summary for all common tools
- [x] Handles edge cases gracefully (unknown tools show name + truncated input)
- [x] Extracts meaningful context from input parameters

## Technical Approach

**Location:** `packages/cyclist/src/public/utils/toolIntentSummarizer.ts`

**Function signature:**
```typescript
function generateToolIntentSummary(toolName: string, input: Record<string, unknown>): string
```

**Implementation:**
1. Switch statement by toolName for known tools
2. Extract relevant fields from input (file_path, command, pattern, etc.)
3. Truncate long values to ~50 chars
4. Fallback for unknown tools: "{tool_name} ({truncated_json})"

**Integration:**
- Import into ToolCallBlock.tsx
- Display intent summary in header

## Key Files

- `packages/cyclist/src/public/utils/toolIntentSummarizer.ts` (NEW)
- `packages/cyclist/src/public/components/ToolCallBlock.tsx` (UPDATE)

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (59 tests failing - ready for Dev)

**Test Files:**
- `packages/cyclist/tests/74-1-tool-intent-summarizer.test.ts` (new)

**Tests Written:** 59 tests covering all 3 ACs:
- **AC1 (27 tests):** All common tools - Read, Bash, Glob, Grep, Write, Edit, Task, WebFetch, WebSearch
- **AC2 (13 tests):** Edge cases - unknown tools, missing fields, null/undefined, truncation
- **AC3 (15 tests):** Context extraction - command detection, file types, search patterns
- **Format (4 tests):** Return type, no empty strings, trimmed, single line

**Stub Implementation:**
- `packages/cyclist/src/public/utils/toolIntentSummarizer.ts` - throws "not implemented"

**Notes for Dev:**
- Tests expect specific phrasing (e.g., "Running git status", "Installing dependencies")
- Bash commands should detect npm/pnpm/yarn install → "Installing dependencies"
- Bash commands should detect npm test/vitest/jest → "Running tests"
- Truncation should keep summaries ≤70 chars
- Never include "undefined" or "null" in output

**Handoff:** To Dev (Malcolm Reynolds) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/utils/toolIntentSummarizer.ts` - Full implementation

**Tests:** 59/59 passing (GREEN)
**PR:** #627 - feat(74-1): Tool intent summarizer
**Branch:** feature/74-1-tool-intent-summarizer (pushed)

**Implementation Details:**
- Switch-based routing for 9 tool types (Read, Bash, Glob, Grep, Write, Edit, Task, WebFetch, WebSearch)
- Smart Bash command detection for install/test/build/lint/format operations
- Graceful fallback for unknown tools with truncated JSON
- Handles null/undefined/empty inputs safely
- Truncation to 70 chars max with ellipsis
- Newlines replaced with spaces for single-line output

**Handoff:** To Reviewer (River Tam) for code review

## Reviewer Assessment

**Verdict:** APPROVED ✓
**PR Status:** MERGED

**Data flow traced:** toolName + input → switch routing → getString() sanitization → truncate() → safe string output
**Pattern observed:** Defensive null handling with `??` and early returns at toolIntentSummarizer.ts:122-128
**Error handling:** JSON.stringify wrapped in try/catch at toolIntentSummarizer.ts:185-192, URL parsing has fallback at :37-39

**Findings:**
| Severity | Finding | Location |
|----------|---------|----------|
| [VERIFIED] | Input sanitization handles null/undefined/empty | getString() :23-28 |
| [VERIFIED] | Truncation consistent at 70 chars max | truncate() :13-18 |
| [VERIFIED] | Test coverage complete | 59/59 tests passing |
| [LOW] | Console.log in main.ts (accepted per user) | main.ts:1019,1030 |

**Tests:** 59/59 passing for story 74-1
**Lint:** 2 warnings (pre-existing, unrelated to summarizer)

**Recommendation:** MERGE TO MAIN - Ready for production

## Session Log

- SM setup: Story selected, session created
- TEA: 59 failing tests written, committed to feature branch
- Dev: Implementation complete, all 59 tests passing, PR #627 created
- Reviewer: Code approved, PR merged to main on 2026-02-02
- SM handoff: Story marked as completed, awaiting SM closure

## Completion Summary

**Story 74-1 is complete and merged to production.**

- All acceptance criteria met
- Full test coverage (59/59 passing)
- Code reviewed and approved
- PR merged to main branch
- Ready for release in Sprint 2606

