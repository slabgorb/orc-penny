# Session: MSSCI-13969 - useMarkdownParser hook

**Story ID:** MSSCI-13969
**Jira Key:** MSSCI-13969
**Title:** useMarkdownParser hook
**Points:** 3
**Epic:** MSSCI-13968 (Vanilla JS to React Hooks Migration)
**Assignee:** keith.avery@1898andco.io

---

## Workflow

**Workflow:** tdd
**Phase:** approved
**Repos:** pennyfarthing

---

## Story Description

Convert markdown-parser.js to a React hook that handles:
- Markdown to HTML conversion
- Code block extraction and syntax highlighting
- Link handling and sanitization
- Memoization for performance

---

## Acceptance Criteria

From epic context (Story 75-1):
- `useMarkdownParser` hook converts markdown to HTML
- Handles code blocks with language detection
- Sanitizes against XSS via HTML escaping
- Memoizes results based on input
- Strips CYCLIST markers before rendering

---

## Epic Context Reference

**Context File:** sprint/context/context-epic-75.md

The epic context file exists and contains detailed implementation guidance for this story including:
- Hook signature: `useMarkdownParser(markdown: string | null): { html: string; error: null }`
- Dependencies to extract: `parseMarkdown()`, `stripMarkers()`, `escapeHtml()` to `utils/markdown.ts`
- Testing strategy: XSS prevention, marker stripping, table parsing
- Risk areas: Performance with large markdown, accidental marker rendering

---

## Technical Approach

### Implementation

```typescript
// src/public/hooks/useMarkdownParser.ts
export interface UseMarkdownParserResult {
  html: string;
  isLoading: boolean;
  error: Error | null;
}

export function useMarkdownParser(markdown: string | null): UseMarkdownParserResult {
  const html = useMemo(() => {
    if (!markdown) return '';
    return parseMarkdown(markdown);
  }, [markdown]);

  return { html, isLoading: false, error: null };
}
```

### Dependencies to Extract

- Move `parseMarkdown()`, `stripMarkers()`, `escapeHtml()` to `utils/markdown.ts`
- Import `highlightCode` from syntax-highlighter

### Files to Create

| File | Lines | Purpose |
|------|-------|---------|
| `src/public/hooks/useMarkdownParser.ts` | ~50 | Markdown to HTML conversion hook |
| `src/public/utils/markdown.ts` | ~250 | Extracted markdown functions |

### Files to Modify

| File | Changes |
|------|---------|
| `src/public/components/Message.tsx` | Use `useMarkdownParser` hook |
| `src/public/components/StreamingContent.tsx` | Use `useMarkdownParser` hook |

### Source File to Migrate

- `src/public/js/components/message-view/markdown-parser.js` (248 lines)

---

## Testing Strategy

- **Unit Tests:** XSS prevention (script tags escaped), marker stripping, table parsing
- **Integration Tests:** Message.tsx uses hook and renders correctly
- **Performance Tests:** Memoization prevents unnecessary re-renders

---

## Risk Areas

| Risk | Mitigation |
|------|-----------|
| Performance with very large markdown | Memoization + code splitting |
| Accidental rendering of CYCLIST markers | stripMarkers runs first |

---

## TDD Workflow Phases

1. **setup** (current) - Session file created, context established
2. **tea** - Test Engineer/Architect writes test specifications
3. **dev** - Developer implements hook following TDD
4. **review** - Code review and merge

---

## Session Log

| Timestamp | Phase | Agent | Action |
|-----------|-------|-------|--------|
| 2026-02-03 | setup | SM | Session file created |
| 2026-02-03 | red | TEA | 40 failing tests written (RED state confirmed) |
| 2026-02-03 | implement | Dev | 40/40 tests passing (GREEN), PR #632 created |
| 2026-02-03 | review | Reviewer | APPROVED - merged PR #632 |

---

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** markdown input → stripMarkers → escapeHtml → parseMarkdown → useMemo → html output (safe - XSS neutralized before markdown processing)

**Observations:**
1. `[VERIFIED]` XSS protection at `markdown.ts:182` - HTML escaping before processing
2. `[VERIFIED]` Memoization at `useMarkdownParser.ts:30-33` - useMemo with correct dependency
3. `[VERIFIED]` CYCLIST marker stripping at `markdown.ts:177` - before escaping
4. `[LOW]` Type assertion `as string` at `markdown.ts:20` - safe due to guard in parseMarkdown
5. `[LOW]` Duplicate stripMarkers (also in @pennyfarthing/shared) - acceptable for now
6. `[VERIFIED]` 40/40 tests passing including XSS attack vectors
7. `[VERIFIED]` Clean TypeScript port from vanilla JS

**Error handling:** Null/undefined inputs return empty string at `parseMarkdown:173`

**Pattern observed:** Escape-first security pattern at `markdown.ts:177-182` - correct order

**No Critical or High issues.** All ACs verified.

**Handoff:** To SM (Zoe) for finish-story

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `src/public/hooks/useMarkdownParser.ts` - React hook with useMemo memoization
- `src/public/utils/markdown.ts` - Extracted markdown utilities (248→244 lines TypeScript)
- `tests/MSSCI-13969-useMarkdownParser.test.ts` - Fixed XSS test assertion

**Tests:** 40/40 passing (GREEN)
**PR:** #632 - feat(MSSCI-13969): useMarkdownParser hook
**Branch:** `feat/MSSCI-13969-use-markdown-parser` (pushed)

**Implementation Notes:**
- Extracted from `js/components/message-view/markdown-parser.js`
- Uses existing `highlightCode` from `syntax-highlighter.js` for code blocks
- XSS prevention: HTML escaped BEFORE markdown processing
- CYCLIST markers stripped before rendering
- Hook uses `useMemo` for memoization as specified

**Handoff:** To Reviewer (River) for code review

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core functionality migration requires comprehensive test coverage

**Test Files:**
- `tests/MSSCI-13969-useMarkdownParser.test.ts` - Hook and utility tests

**Tests Written:** 40 tests covering 5 ACs + additional markdown features
- AC1: Hook converts markdown to HTML (5 tests)
- AC2: Code blocks with language detection (4 tests)
- AC3: XSS prevention via HTML escaping (4 tests)
- AC4: Memoization (2 tests)
- AC5: CYCLIST marker stripping (5 tests)
- Additional markdown features (7 tests)
- Utility functions - parseMarkdown, escapeHtml, stripMarkers (13 tests)

**Stub Files Created:**
- `src/public/hooks/useMarkdownParser.ts` - Hook stub (throws "not implemented")
- `src/public/utils/markdown.ts` - Utility stubs (throw "not implemented")

**Status:** RED (40 tests failing - ready for Dev)

**Branch:** `feat/MSSCI-13969-use-markdown-parser` (in pennyfarthing repo)

**Implementation Notes for Dev:**
1. Extract `parseMarkdown`, `escapeHtml`, `stripMarkers` from `js/components/message-view/markdown-parser.js`
2. Move to `src/public/utils/markdown.ts` with TypeScript types
3. Implement `useMarkdownParser` hook using `useMemo` for memoization
4. Import `highlightCode` from existing `syntax-highlighter.js`
5. Tests expect XSS prevention BEFORE markdown parsing (escape HTML first)

**Handoff:** To Dev (Malcolm) for implementation

---

## Notes

- This is Story 75-1 in the epic, recommended as first story to implement
- No dependencies on other utilities - standalone implementation
- Feeds into Story 75-2 (useSyntaxHighlighter) for code block highlighting
