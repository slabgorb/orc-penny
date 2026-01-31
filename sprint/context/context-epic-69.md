# Epic 69: Core Conversation Experience - Technical Context

**Epic:** Core Conversation Experience
**Status:** in_progress
**Points:** 10 (4 stories)
**Repos:** pennyfarthing (packages/cyclist)
**Created:** 2026-01-31

## Overview

Transform Cyclist's vanilla JS message view into a React + Tailwind component with streaming support, markdown rendering, and subagent span grouping.

## Current State Analysis

### Tech Stack (Before)

| Layer | Technology |
|-------|------------|
| Main Process | Electron 35.7.5, Express 4.18.2, TypeScript |
| Renderer | Vanilla JavaScript (ES modules) |
| Build | `tsc` only - NO bundler |
| Styling | Plain CSS with custom properties |
| Testing | Vitest + Playwright |

### Key Insight: No Bundler Exists

The frontend has no webpack/Vite/esbuild. Static files are served directly from `src/public/`. Story 69-1 must establish the React build pipeline before any components can be built.

### Existing Message View

**Location:** `pennyfarthing/packages/cyclist/src/public/js/components/message-view/`

| File | Purpose |
|------|---------|
| `MessageView.js` | Main coordinator |
| `message-renderers.js` | SDK message → HTML |
| `markdown-parser.js` | MD → HTML conversion |
| `syntax-highlighter.js` | Code highlighting |
| `quick-actions.js` | CYCLIST: marker detection |

These are **pure functions** - reusable in React without modification.

### IPC Bridge

Preload script exposes `electronAPI`:
- `electronAPI.claude.onMessage` - streaming messages
- `electronAPI.data.*` - story, git, tokens
- `electronAPI.settings.*` - theme, fonts

React components will use the same bridge pattern.

## Technical Approach

### Story 69-1: React + Tailwind Build Pipeline

**Goal:** Add React 18 + Tailwind CSS to Cyclist Electron app with hot reload.

**Approach:**
1. Add Vite as bundler (faster HMR than webpack)
2. Configure for React + TypeScript JSX
3. Add Tailwind + PostCSS
4. Create bridge between vanilla JS and React mount points
5. Update npm scripts for dev workflow

**Files to Create/Modify:**
```
pennyfarthing/packages/cyclist/
├── vite.config.ts          # NEW: Vite configuration
├── tailwind.config.js      # NEW: Tailwind theme
├── postcss.config.js       # NEW: PostCSS for Tailwind
├── package.json            # MODIFY: Add deps, update scripts
├── tsconfig.json           # MODIFY: Add JSX support
└── src/public/
    ├── index.html          # MODIFY: Add React root div
    ├── index.tsx           # NEW: React entry point
    └── App.tsx             # NEW: Root React component
```

**Key Dependencies:**
```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.0.0",
    "vite": "^5.0.0",
    "tailwindcss": "^3.4.0",
    "postcss": "^8.4.0",
    "autoprefixer": "^10.4.0"
  }
}
```

### Story 69-2: MessageView Component with Streaming

**Goal:** React MessageView with streaming, markdown, code highlighting, subagent spans.

**Approach:**
1. Create `<MessageView>` React component
2. Subscribe to `electronAPI.claude.onMessage` via useEffect
3. Reuse existing `markdown-parser.js` and `syntax-highlighter.js`
4. Add subagent span grouping (collapsible, type-identified)
5. Implement auto-scroll with scroll-up preservation

**Component Structure:**
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

**Key Files:**
```
src/public/components/
├── MessageView.tsx         # Main container
├── MessageList.tsx         # Scrolling list
├── Message.tsx             # Single message
├── StreamingContent.tsx    # Progressive text render
├── ToolCallBlock.tsx       # Tool use display
├── SubagentSpan.tsx        # Collapsible group
└── hooks/
    └── useMessageStream.ts # IPC subscription hook
```

### Story 69-3: StatsStrip Component

**Goal:** Context %, model badge, PWD, identities - real-time updates.

**Approach:**
1. Create `<StatsStrip>` as horizontal bar below editor
2. Subscribe to token/context updates
3. Implement warning colors at 70%/90% thresholds
4. Pull identity info from settings

**Layout:**
```
┌─────────────────────────────────────────────────────────┐
│ 📁 ~/project  │  🎫 keith@jira  │  🐙 keith  │  opus │ 45% ██░░░ │
└─────────────────────────────────────────────────────────┘
```

### Story 69-4: PersonaHeader Component

**Goal:** Agent portrait, character name/role, popup with details.

**Approach:**
1. Create `<PersonaHeader>` with portrait image
2. Show character name + role from theme
3. Clickable → persona popup with full details
4. Theme-aware styling for multi-project identification

**Integration Point:** Triggered by agent activation via `/agent` commands.

## File Inventory

### Must Create
| File | Story | Purpose |
|------|-------|---------|
| `vite.config.ts` | 69-1 | Vite bundler config |
| `tailwind.config.js` | 69-1 | Tailwind theme |
| `postcss.config.js` | 69-1 | PostCSS for Tailwind |
| `src/public/index.tsx` | 69-1 | React entry |
| `src/public/App.tsx` | 69-1 | Root component |
| `src/public/components/MessageView.tsx` | 69-2 | Message container |
| `src/public/components/Message.tsx` | 69-2 | Single message |
| `src/public/components/SubagentSpan.tsx` | 69-2 | Subagent grouping |
| `src/public/components/StatsStrip.tsx` | 69-3 | Stats bar |
| `src/public/components/PersonaHeader.tsx` | 69-4 | Agent header |

### Must Modify
| File | Story | Changes |
|------|-------|---------|
| `package.json` | 69-1 | Add React, Vite, Tailwind deps |
| `tsconfig.json` | 69-1 | Add JSX support |
| `src/public/index.html` | 69-1 | Add React root div |

### Reuse As-Is
| File | Purpose |
|------|---------|
| `src/public/js/components/message-view/markdown-parser.js` | MD parsing |
| `src/public/js/components/message-view/syntax-highlighter.js` | Code highlighting |
| `src/main.ts` | Electron main process |
| `src/preload.ts` | IPC bridge |
| `src/server.ts` | Express server |

## Testing Strategy

### Unit Tests (Vitest)
- MessageView renders with mock messages
- Streaming content updates progressively
- SubagentSpan groups messages correctly
- StatsStrip shows correct thresholds

### E2E Tests (Playwright)
- Full conversation flow with streaming
- Subagent span collapse/expand
- Stats update in real-time
- Persona header shows on agent activation

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Build pipeline conflicts with existing tsc | Run Vite for frontend only, keep tsc for main process |
| Breaking existing vanilla JS during migration | React mounts to new div, vanilla JS continues in parallel |
| Performance with large conversations | Virtual scrolling if needed (react-window) |
| Theme integration complexity | Extend Tailwind config with existing CSS variable values |

## Story Execution Order

1. **69-1** (2 pts, P0) - Build pipeline first - nothing works without it
2. **69-2** (5 pts, P0) - Core MessageView - highest user value
3. **69-3** (1 pt, P1) - StatsStrip - quick win after MessageView
4. **69-4** (2 pts, P1) - PersonaHeader - visual polish

## Related Documentation

- `docs/planning/cyclist-react-migration-epics.md` - Full epic breakdown with ACs
- `docs/planning/ux-design-specification.md` - UX requirements

---

*Generated by SM agent on 2026-01-31*
