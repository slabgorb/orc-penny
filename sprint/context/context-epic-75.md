# Epic 75: Vanilla JS to React Hooks Migration

**Status:** backlog
**Points:** 12 (5 stories)
**Repos:** pennyfarthing (packages/cyclist)

## Overview

Convert remaining vanilla JS utility modules (~3100 lines) to proper React hooks and components for better integration with the React-based Cyclist architecture. This epic completes the React migration by modernizing utilities that currently run as browser-side JavaScript without React semantics.

## Stories

| ID | Title | Points | Priority | Status |
|----|-------|--------|----------|--------|
| 75-1 | useMarkdownParser hook | 3 | P1 | Backlog |
| 75-2 | useSyntaxHighlighter hook | 2 | P1 | Backlog |
| 75-3 | useSlashCommands hook | 2 | P1 | Backlog |
| 75-4 | useQuickActions hook | 2 | P1 | Backlog |
| 75-5 | Remove vanilla JS dependencies | 3 | P2 | Backlog |

## Current State Analysis

### Total Lines to Migrate

**~3,141 total lines** across 8 files:

| File | Type | Lines | Purpose | Dependencies |
|------|------|-------|---------|--------------|
| `markdown-parser.js` | JS | 248 | MD to HTML, code blocks, tables, XSS prevention | (standalone) |
| `syntax-highlighter.js` | JS | 163 | Code syntax highlighting, keyword/string/comment detection | (standalone) |
| `quick-actions.js` | JS | 572 | CYCLIST marker detection, action button rendering | markdown-parser, editor-textarea, sidebar, controls |
| `slash-commands.js` | JS | 318 | Command definitions (auto-generated), command filtering | (standalone) |
| `avatar-service.ts` | TS | 82 | GitHub avatar fetching with cache and fallback | electronAPI.avatar |
| `color-presets.ts` | TS | 558 | 8 color presets, WCAG contrast validation, persistence | electronAPI.config, electronAPI.theme |
| `font-presets.ts` | TS | 352 | Font presets (UI, code), font size scale, CSS var application | electronAPI.font, electronAPI.invoke |
| `subagent-display.ts` | TS | 131 | Subagent type parsing, helper lookup, friendly message generation | electronAPI.theme |

### Current Imports (Consumers)

Files that currently import from these vanilla JS modules:

| Component | Imports | Type |
|-----------|---------|------|
| `App.tsx` | `font-presets.ts` | App-level font loading |
| `StreamingContent.tsx` | `markdown-parser.js` | Message rendering |
| `Message.tsx` | `markdown-parser.js` | Message rendering |
| `SubagentSpan.tsx` | `subagent-display.ts` | Helper display |
| `SettingsPanel.tsx` | `color-presets.ts`, `font-presets.ts` | Settings UI |
| `ThemePalette/index.tsx` | `color-presets.ts` | Theme preview |
| `FontPicker/index.tsx` | `font-presets.ts` | Font selection |
| `QuickActions.tsx` | Uses useMarkerActions hook | Quick action rendering |
| `useUserAvatar.ts` (hook) | `avatar-service.ts` | Avatar fetching |
| `useSubagentHelper.ts` (hook) | `subagent-display.ts` | Helper caching |

### Existing Hook Patterns

The codebase already has React hooks that we can learn from:

**Hook Architecture** (`src/public/hooks/`):
- `useUserAvatar.ts` - Fetches data, manages loading/error state, uses electronAPI
- `useTabCompletion.ts` - State management, filtering, navigation callbacks
- `useMarkerActions.ts` - Message processing, marker detection (partially implemented)
- `useSubagentHelper.ts` - Helper lookup with caching, async electronAPI calls
- `useMessageStream.ts` - IPC subscription pattern via useEffect
- `useCommandHistory.ts` - Local state management with persistence

**Key Patterns to Follow:**
1. Memoization with `useMemo`/`useCallback` for performance
2. `useState` for local state, `useEffect` for side effects
3. Async operations in useEffect with cleanup
4. Explicit type definitions (`.ts` not `.tsx` for hooks)
5. Return structured result objects `{ data, loading, error }`

### Architecture of Files to Migrate

#### Pure Utility Functions (No Side Effects)
- **markdown-parser.js**: All pure functions - can convert to hook or keep as utils
- **syntax-highlighter.js**: All pure functions - great candidate for memoization
- **slash-commands.js**: Mostly pure, can export utilities as-is

#### Stateful Modules (Browser APIs, Persistence)
- **avatar-service.ts**: Uses electronAPI, cache state - needs useEffect + memoization
- **color-presets.ts**: DOM manipulation, IPC listeners, persistence - needs hooks + context
- **font-presets.ts**: In-memory state + IPC persistence - needs custom hook
- **subagent-display.ts**: Helper cache, async API calls - needs memoization

#### DOM/Event Manipulation
- **quick-actions.js**: Button rendering, DOM element updates, event handlers - needs React component wrapping

## Technical Approach by Story

### Story 75-1: useMarkdownParser Hook (3 pts, P1)

**Acceptance Criteria:**
- `useMarkdownParser` hook converts markdown to HTML
- Handles code blocks with language detection
- Sanitizes against XSS via HTML escaping
- Memoizes results based on input
- Strips CYCLIST markers before rendering

**Implementation Approach:**

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

**Dependencies to Extract:**
- Move `parseMarkdown()`, `stripMarkers()`, `escapeHtml()` to `utils/markdown.ts`
- Import `highlightCode` from syntax-highlighter

**Testing Strategy:**
- Unit: XSS prevention (script tags escaped), marker stripping, table parsing
- Integration: Message.tsx uses hook and renders correctly

**Risk Areas:**
- Performance with very large markdown (mitigate: memoization + code splitting)
- Accidental rendering of CYCLIST markers (mitigate: stripMarkers runs first)

### Story 75-2: useSyntaxHighlighter Hook (2 pts, P1)

**Acceptance Criteria:**
- `useSyntaxHighlighter` hook highlights code for given language
- Detects keywords, strings, comments, numbers
- Supports: JavaScript, TypeScript, Python, Go, Rust, Bash
- Memoizes highlighting results
- Theme-aware (uses CSS variables)

**Implementation Approach:**

```typescript
// src/public/hooks/useSyntaxHighlighter.ts
export interface UseSyntaxHighlighterResult {
  highlighted: string;
}

export function useSyntaxHighlighter(code: string | null, lang: string): UseSyntaxHighlighterResult {
  const highlighted = useMemo(() => {
    if (!code || !lang) return code || '';
    return highlightCode(code, lang);
  }, [code, lang]);

  return { highlighted };
}
```

**Dependencies to Extract:**
- Move `highlightCode()`, `highlightLine()`, keyword sets to `utils/syntax.ts`
- Ensure language detection is robust (typos like "js" vs "JavaScript")

**Testing Strategy:**
- Unit: Each language keywords highlighted correctly
- Visual: Playwright checks color classes applied
- Performance: Large code blocks (<1ms highlighting)

### Story 75-3: useSlashCommands Hook (2 pts, P1)

**Acceptance Criteria:**
- `useSlashCommands` hook provides command definitions and filtering
- Supports prefix matching (e.g., "/dev" matches all "/dev*" commands)
- Returns filtered command list
- Handles trigger detection (position after "/" or whitespace)
- Auto-generated from build-time sources

**Implementation Approach:**

```typescript
// src/public/hooks/useSlashCommands.ts
export interface SlashCommand {
  name: string;
  description: string;
}

export function useSlashCommands(prefix?: string): SlashCommand[] {
  return useMemo(() => {
    if (!prefix) return SLASH_COMMANDS;
    return filterCommands(prefix);
  }, [prefix]);
}

export function useCompletionTrigger(text: string, position: number): boolean {
  return useMemo(() => {
    return isCompletionTrigger(text, position);
  }, [text, position]);
}
```

**Dependencies:**
- Reuse existing `SLASH_COMMANDS` array (auto-generated at build)
- Extract `filterCommands()` and `isCompletionTrigger()` to `utils/commands.ts`
- Hook integrates with existing `useTabCompletion` hook

### Story 75-4: useQuickActions Hook (2 pts, P1)

**Current State:** QuickActions.tsx component exists but imports detection logic from `quick-actions.js`

**Acceptance Criteria:**
- `useQuickActions` hook detects CYCLIST markers in message text
- Supports marker types: handoff, invoke, question, choices, context_clear, continue
- Extracts choice labels from numbered lists
- Returns structured result for rendering
- Handles CONTEXT_CLEAR marker async operation

**Implementation Approach:**

```typescript
// src/public/hooks/useQuickActions.ts
export interface QuickActionResult {
  type: 'handoff' | 'invoke' | 'question' | 'yesno' | 'list' | 'continue' | 'context_clear';
  agent?: string;
  responses?: string[];
  choices?: Array<{ number: number; text: string }>;
  autoExecute?: boolean;
  confidence: number;
}

export function useQuickActions(message: Message | null): QuickActionResult | null {
  return useMemo(() => {
    if (!message) return null;

    const markers = detectStructuredMarkers(text);
    if (!markers) return null;

    return processStructuredMarkers(markers, text);
  }, [message?.id, message?.message?.content?.join('')]);
}
```

**Dependencies to Extract:**
- Move `detectStructuredMarkers()`, `processStructuredMarkers()`, `extractChoiceTexts()` to `utils/markers.ts`
- Keep in sync with shared marker module at `@pennyfarthing/shared/marker`

### Story 75-5: Remove Vanilla JS Dependencies (3 pts, P2)

**Acceptance Criteria:**
- All vanilla JS files removed from codebase
- All imports updated to hooks/utils
- No `parseMarkdown()`, `highlightCode()`, `quick-actions.js` imports remain
- Message rendering tests still pass
- No console errors for missing imports

**Implementation Approach:**

1. **Create Utils Extraction Refactor**
   ```
   src/public/utils/
   ├── markdown.ts        # parseMarkdown(), stripMarkers(), escapeHtml()
   ├── syntax.ts          # highlightCode(), keyword sets
   ├── markers.ts         # detectStructuredMarkers(), processStructuredMarkers()
   ├── text.ts            # stripMarkdown(), truncateText()
   └── commands.ts        # filterCommands(), isCompletionTrigger()
   ```

2. **Update Imports in Components**
   - `Message.tsx`: `parseMarkdown` -> `useMarkdownParser` hook
   - `StreamingContent.tsx`: `parseMarkdown` -> `useMarkdownParser` hook
   - `QuickActions.tsx`: `quick-actions.js` -> `useQuickActions` hook
   - `App.tsx`: `font-presets.ts` -> `useFontSettings` hook
   - `SettingsPanel.tsx`: `color-presets.ts` -> `useColorPresets` hook

3. **Delete Vanilla JS Files**
   ```bash
   rm src/public/js/components/message-view/markdown-parser.js
   rm src/public/js/components/message-view/syntax-highlighter.js
   rm src/public/js/components/message-view/quick-actions.js
   rm src/public/js/slash-commands.js
   rm src/public/js/avatar-service.ts
   rm src/public/js/color-presets.ts
   rm src/public/js/font-presets.ts
   rm src/public/js/subagent-display.ts
   ```

4. **Verification Checklist**
   - [ ] No import statements for removed files
   - [ ] TypeScript compilation succeeds (tsc)
   - [ ] Vite build succeeds (npm run build)
   - [ ] All tests pass (npm test)
   - [ ] No console errors in dev mode

## Recommended Migration Order

### Phase 1: Foundations (Stories 75-1, 75-2)
1. **75-1** (3 pts) - `useMarkdownParser` - no dependencies on other utilities
2. **75-2** (2 pts) - `useSyntaxHighlighter` - standalone, feeds into 75-1

**Rationale:** These are pure function conversions with highest reuse.

### Phase 2: Integration (Stories 75-3, 75-4)
3. **75-3** (2 pts) - `useSlashCommands` - independent, used by CommandPalette
4. **75-4** (2 pts) - `useQuickActions` - depends on utilities from 75-1

**Rationale:** Dependencies are established, can now integrate complex logic.

### Phase 3: Cleanup (Story 75-5)
5. **75-5** (3 pts) - Remove vanilla JS files - only after all 4 hooks are complete

**Rationale:** Ensures no dangling imports.

## File Inventory Summary

### Create (New Hook Files)
| File | Story | Lines | Purpose |
|------|-------|-------|---------|
| `src/public/hooks/useMarkdownParser.ts` | 75-1 | ~50 | Markdown to HTML conversion |
| `src/public/hooks/useSyntaxHighlighter.ts` | 75-2 | ~40 | Code syntax highlighting |
| `src/public/hooks/useSlashCommands.ts` | 75-3 | ~50 | Command definitions + filtering |
| `src/public/hooks/useQuickActions.ts` | 75-4 | ~80 | CYCLIST marker detection |
| `src/public/utils/markdown.ts` | 75-1 | ~250 | Extracted markdown functions |
| `src/public/utils/syntax.ts` | 75-2 | ~160 | Extracted syntax functions |
| `src/public/utils/markers.ts` | 75-4 | ~250 | Marker detection logic |
| `src/public/utils/text.ts` | 75-1/4 | ~50 | Text processing utils |
| `src/public/utils/commands.ts` | 75-3 | ~100 | Command filtering logic |

### Modify (Existing Components)
| File | Story | Changes |
|------|-------|---------|
| `src/public/components/Message.tsx` | 75-1 | Use `useMarkdownParser` hook |
| `src/public/components/StreamingContent.tsx` | 75-1 | Use `useMarkdownParser` hook |
| `src/public/components/QuickActions.tsx` | 75-4 | Use `useQuickActions` hook |
| `src/public/components/SettingsPanel.tsx` | 75-2/3 | Use font/color preset hooks |
| `src/public/App.tsx` | 75-2 | Use font settings hook |

### Delete (Story 75-5)
```
src/public/js/components/message-view/markdown-parser.js
src/public/js/components/message-view/syntax-highlighter.js
src/public/js/components/message-view/quick-actions.js
src/public/js/slash-commands.js
src/public/js/avatar-service.ts
src/public/js/color-presets.ts
src/public/js/font-presets.ts
src/public/js/subagent-display.ts
```

## Dependency Graph

```
useMarkdownParser
  |
  ├── utils/markdown.ts (parseMarkdown, escapeHtml, stripMarkers)
  └── useSyntaxHighlighter (for code block highlighting)

useSyntaxHighlighter
  |
  └── utils/syntax.ts (highlightCode, keyword sets)

useSlashCommands
  |
  └── utils/commands.ts (SLASH_COMMANDS, filterCommands, isCompletionTrigger)

useQuickActions
  |
  ├── utils/markers.ts (detectStructuredMarkers, processStructuredMarkers)
  ├── utils/text.ts (stripMarkdown, truncateText)
  └── useMarkdownParser (for choice text extraction)

Components (post-migration)
  ├── Message.tsx -> useMarkdownParser
  ├── StreamingContent.tsx -> useMarkdownParser
  ├── QuickActions.tsx -> useQuickActions
  ├── App.tsx -> useFontSettings
  └── SettingsPanel.tsx -> useColorPresets, useFontSettings
```

## Technical Considerations

### Performance Optimizations
1. **Memoization**: All hooks use `useMemo` for derived values to prevent unnecessary re-rendering
2. **Lazy Loading**: Syntax highlighting only runs when code blocks are actually rendered
3. **Chunk Caching**: Avatar URLs cached in-memory, color presets pre-loaded

### XSS & Security
- `parseMarkdown()` uses HTML escaping BEFORE markdown parsing to prevent `<script>` injection
- `sanitizeFontFamily()` prevents CSS injection via font-family input
- CYCLIST markers removed before rendering (markers are metadata, not display)

### Browser Compatibility
- All hooks use standard React 18 APIs (useState, useEffect, useMemo, useCallback)
- electronAPI calls gracefully degrade to defaults if unavailable
- No exotic ES features - targets ES2020+

## Gotchas & Edge Cases

| Edge Case | Root Cause | Mitigation |
|-----------|-----------|-----------|
| Large code blocks hanging browser | O(n^2) regex on each highlight | Tokenizer approach + line-by-line processing |
| Markers inside code blocks detected | Regex before code block removal | Remove code blocks first |
| Font family CSS injection | User custom font input | `sanitizeFontFamily()` removes special chars |
| Avatar fetch races | Multiple requests for same user | Browser cache + electronAPI caching layer |
| CYCLIST marker typos | User includes markers with wrong syntax | Strict regex pattern matching + validation |

## Risk Areas & Mitigations

| Risk | Impact | Severity | Mitigation |
|------|--------|----------|-----------|
| Breaking message rendering during refactor | Users see blank messages | Critical | Use feature flags, run new hooks in parallel with old |
| Performance regression from hook overhead | Slow conversation | High | Profile with React DevTools, use Profiler API |
| Circular dependency in utils | Build failure | Medium | Plan dependency graph before coding |
| electronAPI not available in test | Tests fail | Medium | Mock window.electronAPI in test setup |
| Large code blocks timeout | UI freeze | Medium | Add timeout + graceful degradation |

## Quick Reference: Hook Signatures

```typescript
// Story 75-1
export function useMarkdownParser(markdown: string | null): { html: string; error: null }

// Story 75-2
export function useSyntaxHighlighter(code: string | null, lang: string): { highlighted: string }

// Story 75-3
export function useSlashCommands(prefix?: string): SlashCommand[]
export function useCompletionTrigger(text: string, position: number): boolean

// Story 75-4
export function useQuickActions(message: Message | null): QuickActionResult | null

// Bonus (utilities for components)
export function stripMarkdown(text: string): string
export function truncateText(text: string, maxLen: number): string
export function detectStructuredMarkers(text: string): Marker[] | null
```
