# Session: MSSCI-12698 - MessageView Component with Streaming

## Story Metadata

| Field | Value |
|-------|-------|
| **Story ID** | MSSCI-12698 |
| **Title** | MessageView Component with Streaming |
| **Jira** | MSSCI-12698 |
| **Workflow** | tdd |
| **Phase** | finish |
| **Assignee** | Keith Avery |
| **Points** | 5 |
| **Repos** | pennyfarthing |
| **Slug** | message-view-streaming |
| **Branch** | feat/MSSCI-12698-message-view-streaming |

## Epic Context

**Reference:** `sprint/context/context-epic-69.md`

**Epic 69: Core Conversation Experience** - Transform Cyclist's vanilla JS message view into a React + Tailwind component with streaming support, markdown rendering, and subagent span grouping.

## User Story

As a **Cyclist user**,
I want **a React-based message view with streaming text display**,
So that **I can see Claude's responses as they stream in with proper markdown rendering and subagent grouping**.

## Acceptance Criteria

**Given** the React + Tailwind build pipeline from Story 69-1
**When** Claude streams a response
**Then** the MessageView displays text progressively as it arrives
**And** markdown is rendered correctly (headers, lists, code blocks)
**And** code blocks have syntax highlighting
**And** tool calls are displayed in a distinct block
**And** subagent messages are grouped in collapsible spans
**And** each subagent span shows its type and name
**And** auto-scroll follows new content unless user scrolls up

## Technical Approach

From the epic context (Story 69-2):

1. **Create `<MessageView>` React component** - Main container
2. **Subscribe to `electronAPI.claude.onMessage`** via useEffect hook
3. **Reuse existing parsers** - `markdown-parser.js` and `syntax-highlighter.js` are pure functions
4. **Add subagent span grouping** - Collapsible, type-identified (explore, test-runner, etc.)
5. **Implement auto-scroll** - Follow new content, preserve position on scroll-up

### Component Structure

```tsx
<MessageView>
  <MessageList>
    <Message role="user">...</Message>
    <Message role="assistant">
      <StreamingContent />
      <ToolCallBlock />
    </Message>
    <SubagentSpan type="explore" name="codebase-search">
      <Message>...</Message>
      <Message>...</Message>
    </SubagentSpan>
  </MessageList>
</MessageView>
```

### Key Files to Create

| File | Purpose |
|------|---------|
| `src/public/components/MessageView.tsx` | Main container component |
| `src/public/components/MessageList.tsx` | Scrolling message list |
| `src/public/components/Message.tsx` | Single message rendering |
| `src/public/components/StreamingContent.tsx` | Progressive text render |
| `src/public/components/ToolCallBlock.tsx` | Tool use display |
| `src/public/components/SubagentSpan.tsx` | Collapsible subagent group |
| `src/public/hooks/useMessageStream.ts` | IPC subscription hook |

### Files to Reuse (No Changes)

| File | Purpose |
|------|---------|
| `src/public/js/components/message-view/markdown-parser.js` | MD → HTML |
| `src/public/js/components/message-view/syntax-highlighter.js` | Code highlighting |

## Testing Strategy

### Unit Tests (Vitest)
- MessageView renders with mock messages
- Streaming content updates progressively
- SubagentSpan groups messages correctly by parent ID
- Markdown renders headers, lists, code blocks
- Syntax highlighting applies to code blocks

### Integration Tests
- Full conversation flow with streaming
- Subagent span collapse/expand interaction
- Auto-scroll behavior (follows new, preserves on scroll-up)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Performance with large conversations | Virtual scrolling (react-window) if needed |
| Streaming race conditions | Use refs for latest state, avoid stale closures |
| Breaking existing vanilla JS | React mounts to new div, vanilla JS continues |

## Progress Log

- [x] Write failing tests for MessageView
- [x] Write failing tests for streaming content
- [x] Write failing tests for subagent span grouping
- [x] Implement MessageView component
- [x] Implement streaming subscription hook
- [x] Implement SubagentSpan grouping
- [x] Pass all tests
- [ ] Verify in Electron app

---

*Session created: 2026-01-31*

## Handoff to TEA

**From:** SM (Titus Pullo)
**To:** TEA (Atia of the Julii)
**Timestamp:** 2026-01-31
**Workflow:** tdd (RED phase)

### Context Summary

Story 69-2 builds the React MessageView component with streaming support. This is the core user-facing component for Epic 69. Story 69-1 (React + Tailwind pipeline) is already merged, so the build infrastructure is ready.

### Key Files

**Create:**
- `src/public/components/MessageView.tsx` - Main container
- `src/public/components/Message.tsx` - Single message
- `src/public/components/StreamingContent.tsx` - Progressive text
- `src/public/components/SubagentSpan.tsx` - Collapsible groups
- `src/public/hooks/useMessageStream.ts` - IPC subscription

**Reuse (pure functions):**
- `src/public/js/components/message-view/markdown-parser.js`
- `src/public/js/components/message-view/syntax-highlighter.js`

### Technical References

- Epic context: `sprint/context/context-epic-69.md` (Story 69-2 section)
- Planning doc: `docs/planning/cyclist-react-migration-epics.md`
- Cyclist source: `pennyfarthing/packages/cyclist/`

### Acceptance Criteria for Tests

1. MessageView renders with mock messages
2. Streaming content updates progressively
3. Markdown renders correctly (headers, lists, code blocks)
4. Code blocks have syntax highlighting
5. Tool calls display in distinct blocks
6. Subagent messages grouped in collapsible spans
7. Auto-scroll follows new content, preserves on scroll-up

Write failing tests that cover these ACs.

## TEA Assessment

**Tests Required:** Yes
**Reason:** 5-point story with complex UI components requiring thorough test coverage

**Test Files:**
- `packages/cyclist/tests/69-2-message-view-react.test.tsx` - 71 tests covering all 7 ACs
- `packages/cyclist/tests/setup.ts` - Vitest setup for @testing-library/jest-dom

**Tests Written:** 71 tests covering 7 ACs
- AC1: MessageView renders with mock messages (7 tests)
- AC2: Streaming content updates progressively (6 tests)
- AC3: Markdown renders correctly (10 tests)
- AC4: Code blocks have syntax highlighting (6 tests)
- AC5: Tool calls display in distinct blocks (8 tests)
- AC6: Subagent messages grouped in collapsible spans (9 tests)
- AC7: Auto-scroll behavior (8 tests)
- useMessageStream hook tests (5 tests)
- Component isolation tests (12 tests)

**Status:** RED (all 71 tests failing with "not implemented" errors - ready for Dev)

**Infrastructure Changes:**
- Added @testing-library/react and @testing-library/jest-dom to devDependencies
- Updated vitest.config.ts to include .tsx files and React plugin
- Created stub components that throw "not implemented"

**Commit:** `5e9333e66` - `test(cyclist): add failing tests for MessageView React components`

**Handoff:** To Dev (Lucius Vorenus) for implementation

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `packages/cyclist/src/public/components/MessageView.tsx` - Main container with message grouping
- `packages/cyclist/src/public/components/MessageList.tsx` - Scrolling container with auto-scroll
- `packages/cyclist/src/public/components/Message.tsx` - Single message with markdown rendering
- `packages/cyclist/src/public/components/StreamingContent.tsx` - Progressive text with cursor
- `packages/cyclist/src/public/components/ToolCallBlock.tsx` - Tool use/result display
- `packages/cyclist/src/public/components/SubagentSpan.tsx` - Collapsible subagent grouping
- `packages/cyclist/src/public/hooks/useMessageStream.ts` - IPC subscription hook
- `packages/cyclist/tests/69-2-message-view-react.test.tsx` - Minor test selector fixes

**Tests:** 71/71 passing (GREEN)
**PR:** #575 - feat(cyclist): MessageView React component with streaming
**Branch:** feat/MSSCI-12698-message-view-streaming (pushed)

**Commit:** `575ae6edc` - `feat(cyclist): implement MessageView React components`

**Handoff:** To Reviewer (Marcus Tullius Cicero) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Review Timestamp:** 2026-01-31

### Observations

| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | `[VERIFIED]` | `dangerouslySetInnerHTML` is safe - `parseMarkdown()` calls `escapeHtml()` FIRST before any processing, preventing XSS | `markdown-parser.js:180` |
| 2 | `[VERIFIED]` | Type definitions are complete - `MessageData`, `ToolUseMessage`, etc. have proper TypeScript interfaces | `MessageView.tsx:22-33` |
| 3 | `[LOW]` | Type assertion `as any` used for subagent messages - could be more strictly typed | `MessageView.tsx:105` |
| 4 | `[VERIFIED]` | Error handling in `useMessageStream` is proper - catches both sync and async errors, provides error state | `useMessageStream.ts:57-61` |
| 5 | `[VERIFIED]` | Cleanup function properly removes listener on unmount, wrapped in try-catch | `useMessageStream.ts:63-68` |
| 6 | `[LOW]` | Empty catch block in cleanup swallows errors silently - acceptable for cleanup | `useMessageStream.ts:66` |

### Data Flow Trace

- **Input:** `message.content` (user-supplied markdown string)
- **Path:** `Message.tsx:42` → `parseMarkdown()` → `escapeHtml()` (line 180) → regex transformations → `dangerouslySetInnerHTML`
- **Safety:** HTML is escaped BEFORE markdown processing, neutralizing XSS vectors

### Pattern Observed

**GOOD PATTERN:** Composition pattern at `MessageView.tsx:97-141` - `renderItem()` delegates to appropriate component based on message type

**GOOD PATTERN:** `forwardRef` with `useImperativeHandle` at `MessageList.tsx:64-67` for exposing scroll control

### Error Handling

- `useMessageStream`: Catches missing `electronAPI` and sets error state ✓
- `MessageList`: Defensive `if (!container)` checks ✓
- `parseMarkdown`: Handles null/undefined input ✓

### Security Analysis

- `dangerouslySetInnerHTML` mitigated by `escapeHtml()` ✓
- No `eval()` or `Function()` constructs ✓
- No hardcoded credentials ✓
- No direct user input to DOM without sanitization ✓

### Tests

71/71 tests passing for story-specific test file (`69-2-message-view-react.test.tsx`)

### Blocking Issues

None.

**Handoff:** To SM (Titus Pullo) for finish-story
