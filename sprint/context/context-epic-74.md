# Epic 74: Tool Use Visualization

**Status:** Backlog
**Total Points:** 13 (P1 Priority)

## Overview

Improve tool use display in the Cyclist message view with human-readable intent summaries and proper visual hierarchy. Currently, ToolCallBlock displays only tool name and raw input. Target is a stacked tool history with collapsible groups, status indicators, and visual distinction between active and historical tool uses.

## Stories

| ID | Title | Points | Priority | Status |
|----|-------|--------|----------|--------|
| 74-1 | Tool intent summarizer | 3 | P0 | Backlog |
| 74-2 | Collapsible tool result display | 2 | P0 | Backlog |
| 74-3 | Tool use stack between messages | 5 | P0 | Backlog |
| 74-4 | Tool use visual design polish | 3 | P1 | Backlog |

## Architecture Overview

### Current State

**ToolCallBlock Component** (`packages/cyclist/src/public/components/ToolCallBlock.tsx`)
- Simple component displaying tool name + formatted input
- Basic collapse toggle for results (already implemented)
- Status indicator showing 'pending' or 'complete'
- Limited input formatting (tool-specific field extraction)

**Message Flow:**
1. Claude API streams `ToolUseMessage` blocks with `tool_name`, `tool_id`, `input`
2. `ToolResultMessage` arrives separately with `tool_id`, `content`
3. MessageView component renders via ToolCallBlock (lines 130-149)
4. Tool results matched by `tool_id` for pairing

**Current Input Display** (`formatToolInput` function):
- Read: `input.file_path`
- Bash: `input.command`
- Glob: `input.pattern`
- Grep: `input.pattern`
- Write: `input.file_path`
- Default: Full JSON stringified

### Data Flow

```
Claude API
    |
electronAPI.claude.onMessage() [useMessageStream hook]
    |
Message[] state with type: 'tool_use' | 'tool_result'
    |
MessageView component (line 48)
    |
Tool use/result matching by tool_id (line 78-79)
    |
ToolCallBlock renderer (line 130-149)
    |
Display in message stream
```

### Available Data on Tool Uses

**From ToolUseMessage:**
- `tool_name`: string (Read, Bash, Glob, Grep, Write, Edit, Task)
- `tool_id`: unique identifier
- `input`: Record<string, unknown> with tool-specific parameters
- `timestamp`: number (ms since epoch)

**From ToolResultMessage (matched by tool_id):**
- `content`: string (output/result)
- `timestamp`: number
- `is_error`: boolean (inferred from content or explicit field)

**From Enriched Spans (OTEL telemetry, optional enhancement):**
- `durationMs`: execution time
- `status`: 'running' | 'completed' | 'error'
- `enrichment`: tool-specific data (file paths, commands, counts, etc.)

### Design System

**Theme Variables** (`src/public/css/theme-system.css`):
- Primary colors: `--bg-primary`, `--text-primary`, `--accent`
- Status colors: `--status-success: #22c55e`, `--status-warning: #eab308`, `--status-error: #ef4444`, `--status-info: #3b82f6`
- Tool bg: `--tool-bg: #0f0f1a`

**Existing Collapse Pattern** (SubagentSpan component):
- Uses `useState(defaultCollapsed)` for toggle state
- Arrow icon: collapsed / expanded
- `className` includes `collapsed` modifier for CSS
- Count badge shown when collapsed: "5 messages"

## Key Files and Responsibilities

| File | Responsibility | Related to Epic |
|------|----------------|-----------------|
| `packages/cyclist/src/public/components/ToolCallBlock.tsx` | Current tool display, will be enhanced | Core component |
| `packages/cyclist/src/public/components/MessageView.tsx` | Message rendering, tool grouping logic | Add tool stack grouping (74-3) |
| `packages/cyclist/src/public/components/SubagentSpan.tsx` | Collapsible pattern reference | Copy collapse UX for stacks (74-3) |
| `packages/cyclist/src/public/hooks/useMessageStream.ts` | Message data flow | Data source for tool uses |
| `packages/cyclist/src/enriched-span-exporter.ts` | Tool span enrichment | Enhancement data for timing/status |
| `packages/cyclist/src/tool-stats.ts` | Tool statistics | Statistics aggregation |
| `packages/cyclist/src/public/css/theme-system.css` | Design tokens | Colors for tool types (74-4) |

## Technical Approach by Story

### Story 74-1: Tool Intent Summarizer (3 pts)

**Goal:** Generate human-readable summaries like "Reading file src/foo.ts" from tool name + input.

**Implementation:**
1. Create new utility module: `packages/cyclist/src/public/utils/toolIntentSummarizer.ts`
2. Export function: `function generateToolIntentSummary(toolName: string, input: Record<string, unknown>): string`
3. Switch statement by `toolName`:
   - **Read**: "Reading {file_path}" (extract from `input.file_path`)
   - **Bash**: "Running {command}" or "Installing dependencies" (extract from `input.command`)
   - **Glob**: "Finding {pattern} files" (extract from `input.pattern`)
   - **Grep**: "Searching for '{pattern}'" (extract from `input.pattern`)
   - **Write**: "Creating {file_path}" (extract from `input.file_path`)
   - **Edit**: "Updating {file_path}" (extract from `input.file_path`)
   - **Task**: "Launching {subagent_type} subagent" (extract from `input.subagent_type`)
   - **Default**: "{tool_name} ({truncated_json})" for unknown tools

4. Truncate long paths/commands to ~50 chars
5. Handle edge cases: missing input fields, null values, empty strings

**Update ToolCallBlock:**
- Import the new utility
- Call before render: `const intent = generateToolIntentSummary(toolUse.tool_name, toolUse.input)`
- Display intent in a new `.tool-intent` div above current input display

**Acceptance Criteria:**
- Generates readable summaries for all 7 common tool types
- Graceful fallback for unknown tools
- Edge cases handled (missing fields, empty input)

### Story 74-2: Collapsible Tool Result Display (2 pts)

**Goal:** Show results collapsed by default with line count; expand to show full output.

**Current State:** Already has basic collapse toggle for results. Needs enhancement:
- Show line count in collapsed header
- Truncate very long results (>50 lines) with "Show more"
- Add copy-to-clipboard button

**Implementation:**

1. Enhance ToolCallBlock component:
   - Extend state tracking to count lines in result
   - Update collapsed header: "Result (42 lines)" instead of just "Result"
   - For results >50 lines, show truncated preview (first 50 lines) + "Show all (N lines)" button
   - Add copy button alongside toggle

2. Add utility function `countLines(content: string): number`

3. CSS: Add `.tool-result-truncated` class for preview state

**Acceptance Criteria:**
- Results collapsed by default, show line count
- Large results (>50 lines) show truncated preview
- Copy button works and provides feedback
- Line count visible in collapsed header

### Story 74-3: Tool Use Stack Between Messages (5 pts)

**Goal:** Group consecutive tool uses into collapsible stack with visual hierarchy.

**Implementation:**

1. **In MessageView component**, modify grouping logic (lines 71-112):
   - After existing tool result matching, add tool stack grouping
   - Identify consecutive tool_use messages between assistant messages
   - Group into `ToolStack` objects with:
     - `stackId`: unique identifier
     - `tools`: array of tool_use messages
     - `count`: number of tools
     - `timestamp`: start time of stack

2. **Create new ToolStack component** (`packages/cyclist/src/public/components/ToolStack.tsx`):
   - Similar to SubagentSpan collapse pattern
   - Header shows: "5 tool calls" with timeline start
   - Collapsed: show just counts
   - Expanded: render each tool as ToolCallBlock with summary collapsed by default
   - Current/pending tool always expanded (class: `tool-current`)
   - Historical tools dimmed with opacity (class: `tool-historical`)

3. **MessageView rendering logic:**
   - Before rendering tool_use individually, check if it's part of a stack
   - If so, render ToolStack wrapper instead of individual ToolCallBlock
   - Single tool_use renders normally (no stack)

4. **Styling:**
   - `.tool-stack` - container
   - `.tool-stack-header` - clickable header
   - `.tool-stack-current` - current tool (bright)
   - `.tool-stack-historical` - historical (opacity: 0.6)
   - `.tool-count` - badge showing count

**Data Structure:**
```typescript
interface ToolUseMessage {
  type: 'tool_use';
  tool_name: string;
  tool_id: string;
  input: Record<string, unknown>;
  timestamp: number;
}

interface ToolStack {
  stackId: string;
  tools: ToolUseMessage[];
  count: number;
  isActive: boolean; // pending == true
  timestamp: number;
}
```

**Acceptance Criteria:**
- Consecutive tool uses grouped into stacks
- Stack count visible in collapsed header
- Individual summaries visible when expanded
- Current/pending tool always visible and prominent
- Clear visual distinction: current bright, historical dimmed

### Story 74-4: Tool Use Visual Design Polish (3 pts)

**Goal:** Add status indicators, color coding by tool type, elapsed time, error styling.

**Implementation:**

1. **Status Indicators:**
   - Create component: `packages/cyclist/src/public/components/ToolStatus.tsx`
   - Pending: spinning circle/loader icon
   - Success: green checkmark
   - Error: red X with error styling
   - Render in tool header next to tool name

2. **Color Coding by Tool Type:**
   - In theme-system.css, add tool-specific colors:
     - `--tool-read-color: #3b82f6` (blue)
     - `--tool-write-color: #f97316` (orange)
     - `--tool-bash-color: #22c55e` (green)
     - `--tool-glob-color: #a855f7` (purple)
     - `--tool-grep-color: #06b6d4` (cyan)
     - `--tool-edit-color: #eab308` (yellow)
     - `--tool-task-color: #ec4899` (pink)
   - Apply as left border on `.tool-call-block` or dot indicator

3. **Elapsed Time Display:**
   - Get `durationMs` from enriched span data (OTEL telemetry)
   - Format via utility: `formatDuration(ms)` - "245ms", "1.5s"
   - Display in collapsed header: "Read file (245ms)"
   - Use DebugPanel's formatDuration as reference (line 108-112)

4. **Error Styling:**
   - If tool result is error (`is_error: true` or contains error markers):
     - Red border on `.tool-call-block`
     - Red status indicator icon
     - Error content highlighted with red background
   - Class: `.tool-error`

**Acceptance Criteria:**
- Status icons visible and correct (pending/success/error)
- Tool type colors distinguishable
- Elapsed time displayed for completed tools
- Error results highlighted with red
- Visual consistency with Cyclist design system

## Dependencies and Constraints

### Inter-Story Dependencies

**Build Order:**
1. **74-1 (Intent Summarizer)** - Foundation for summaries used in 74-3
2. **74-2 (Collapsible Results)** - Enhancement to result display, independent
3. **74-3 (Tool Stacks)** - Uses intent summaries from 74-1, implements grouping logic
4. **74-4 (Design Polish)** - Final visual pass, uses all previous work

**Blockers:**
- Need to ensure tool execution data includes timing/status info
- May need coordination with OTEL span enrichment (already exists, just need to consume)

### Technical Constraints

1. **TypeScript strict mode** - All new code must be type-safe
2. **No external UI libraries** - Use existing patterns (SubagentSpan as reference)
3. **Accessibility** - ARIA labels, keyboard navigation, screen reader support
4. **Performance** - Don't re-render large tool lists on every message (use useMemo)
5. **Styling** - CSS modules or inline, use CSS vars from theme-system.css

### Known Gotchas

1. **Tool result matching:** Tool results arrive as separate messages and must be matched by `tool_id` (MessageView handles this)
2. **Streaming state:** Need to handle tools that are still pending (isStreaming=true)
3. **Tool input types:** Different tools have completely different input structures - need good fallback
4. **Large outputs:** Some tool results can be 10K+ lines - don't render full content by default
5. **Stack grouping timing:** Need to identify "consecutive" tools accurately (between which messages?)

## Related Stories and Epics

- **Epic 75:** Vanilla JS to React Hooks Migration - Affects markdown/syntax highlighting used in results
- **Epic 70:** Flexible Workspace - Provides base component patterns
- **PROJ-12782:** OTEL spans display - Source of timing/status data

## References

### Component Examples in Codebase
- `SubagentSpan.tsx` - Collapse/expand pattern with count badge
- `DebugPanel.tsx` - Tool grouping, duration formatting, status aggregation
- `ToolCallBlock.tsx` - Current tool display implementation
- `FileTree.tsx` - Tree expand/collapse pattern

### Utilities to Reference
- `formatDuration()` in DebugPanel (line 108-112)
- `groupSpansByTool()` in DebugPanel (line 117-147)
- `parseMarkdown()` from message-view/markdown-parser.js

### Design Token Files
- `theme-system.css` - CSS custom properties for colors, spacing, fonts

## Implementation Timeline Estimate

- **74-1:** 1-2 hours (straightforward string formatting)
- **74-2:** 1 hour (enhance existing component)
- **74-3:** 3-4 hours (new grouping logic + component)
- **74-4:** 2 hours (styling and minor enhancements)
- **Testing:** 2-3 hours (unit tests for summarizer, component tests for all)

## Success Metrics

1. Tool uses display human-readable intent summaries
2. Results collapsed by default, line count visible
3. Multiple consecutive tools grouped and collapsible
4. Current tool visually prominent, historical tools dimmed
5. Status, color coding, timing all visible
6. No performance regression on message list with 20+ tool uses
7. Full accessibility support (keyboard navigation, screen readers)
