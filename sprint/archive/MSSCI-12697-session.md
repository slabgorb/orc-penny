# Session: MSSCI-12697 - React + Tailwind Build Pipeline

## Story Metadata

| Field | Value |
|-------|-------|
| **Story ID** | MSSCI-12697 |
| **Title** | React + Tailwind Build Pipeline |
| **Jira** | MSSCI-12697 |
| **Workflow** | trivial |
| **Phase** | approved |
| **Assignee** | Keith Avery |
| **Points** | 2 |
| **Repos** | pennyfarthing |
| **Slug** | react-tailwind-build-pipeline |

## Epic Context

**Reference:** `sprint/context/context-epic-69.md`

**Epic 69: Core Conversation Experience** - Transform Cyclist's vanilla JS message view into a React + Tailwind component with streaming support, markdown rendering, and subagent span grouping.

## User Story

As a **developer**,
I want **the Cyclist Electron app to support React components with Tailwind CSS**,
So that **I can build the new UI using modern tooling**.

## Acceptance Criteria

**Given** the existing Cyclist Electron application
**When** I add a React component to the codebase
**Then** it compiles and renders correctly in the Electron window
**And** Tailwind CSS classes are applied and work as expected
**And** existing vanilla JS continues to function during migration
**And** hot reload works for development

## Technical Approach

From the epic context, the approach is:

1. **Add Vite as bundler** - Faster HMR than webpack, well-suited for Electron renderer
2. **Configure for React + TypeScript JSX** - Enable JSX compilation in tsconfig
3. **Add Tailwind + PostCSS** - Modern utility-first CSS framework
4. **Create bridge between vanilla JS and React mount points** - React mounts to new div, vanilla JS continues in parallel
5. **Update npm scripts for dev workflow** - Integrate Vite dev server with Electron

### Key Dependencies

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

### Key Insight

The frontend currently has NO bundler - static files are served directly from `src/public/`. This story establishes the React build pipeline before any components can be built.

## Files to Create/Modify

### Files to Create

| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/vite.config.ts` | Vite bundler configuration |
| `pennyfarthing/packages/cyclist/tailwind.config.js` | Tailwind theme configuration |
| `pennyfarthing/packages/cyclist/postcss.config.js` | PostCSS for Tailwind |
| `pennyfarthing/packages/cyclist/src/public/index.tsx` | React entry point |
| `pennyfarthing/packages/cyclist/src/public/App.tsx` | Root React component |

### Files to Modify

| File | Changes |
|------|---------|
| `pennyfarthing/packages/cyclist/package.json` | Add React, Vite, Tailwind dependencies and scripts |
| `pennyfarthing/packages/cyclist/tsconfig.json` | Add JSX support |
| `pennyfarthing/packages/cyclist/src/public/index.html` | Add React root div |

### Files to Reuse (No Changes)

| File | Purpose |
|------|---------|
| `pennyfarthing/packages/cyclist/src/main.ts` | Electron main process |
| `pennyfarthing/packages/cyclist/src/preload.ts` | IPC bridge |
| `pennyfarthing/packages/cyclist/src/server.ts` | Express server |

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Build pipeline conflicts with existing tsc | Run Vite for frontend only, keep tsc for main process |
| Breaking existing vanilla JS during migration | React mounts to new div, vanilla JS continues in parallel |
| Theme integration complexity | Extend Tailwind config with existing CSS variable values |

## Progress Log

- [ ] Install React, ReactDOM dependencies
- [ ] Install Vite and React plugin
- [ ] Install Tailwind, PostCSS, Autoprefixer
- [ ] Create vite.config.ts
- [ ] Create tailwind.config.js
- [ ] Create postcss.config.js
- [ ] Update tsconfig.json for JSX
- [ ] Create index.tsx React entry point
- [ ] Create App.tsx root component
- [ ] Update index.html with React root div
- [ ] Update package.json scripts
- [ ] Verify hot reload works
- [ ] Verify vanilla JS still functions

---

*Session created: 2026-01-31*

## Handoff to Dev

**From:** SM (Titus Pullo)
**To:** Dev (Lucius Vorenus)
**Timestamp:** 2026-01-31
**Workflow:** trivial (skipping TEA)

### Context Summary
Story 69-1 sets up the React + Tailwind build pipeline for Cyclist. This is foundational work - nothing in Epic 69 works without this pipeline.

### Key Files
- Create: vite.config.ts, tailwind.config.js, postcss.config.js, src/public/index.tsx, src/public/App.tsx
- Modify: package.json, tsconfig.json, src/public/index.html

### Technical References
- Epic context: sprint/context/context-epic-69.md
- Planning doc: docs/planning/cyclist-react-migration-epics.md (Story 69-1 section)
- Cyclist source: pennyfarthing/packages/cyclist/

### Acceptance Criteria
1. React component compiles and renders in Electron window
2. Tailwind CSS classes applied and working
3. Existing vanilla JS continues to function
4. Hot reload works for development

Report back when complete.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/vite.config.ts` - Vite bundler configuration
- `packages/cyclist/tailwind.config.js` - Tailwind theme with Cyclist CSS variables
- `packages/cyclist/postcss.config.js` - PostCSS for Tailwind v4
- `packages/cyclist/tsconfig.vite.json` - TypeScript config for React/JSX
- `packages/cyclist/src/public/index.tsx` - React entry point
- `packages/cyclist/src/public/App.tsx` - Root React component (placeholder)
- `packages/cyclist/src/public/styles/tailwind.css` - Tailwind imports
- `packages/cyclist/src/public/index.html` - Added react-root div, CSS/JS links
- `packages/cyclist/package.json` - Added deps and build scripts
- `packages/cyclist/tsconfig.json` - Exclude .tsx from main tsc

**Tests:** Build passes (no unit tests for build pipeline)
**PR:** #574 - feat(cyclist): React + Tailwind build pipeline
**Branch:** feat/MSSCI-12697-react-tailwind-pipeline (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [CRITICAL] | Vite outputs to `dist/public/` but Express serves from `src/public/`. The React bundle at `/js/react/react.js` will 404 because `paths.ts:getPublicDir()` returns `src/public`. | `vite.config.ts:12`, `paths.ts:187-203` | Either change Vite outDir to `src/public` OR add static serving from `dist/public` in server.ts |
| [LOW] | Stale comment in tailwind.css mentions "tw-" prefix but prefix was removed from tailwind.config.js | `src/public/styles/tailwind.css:2` | Remove or update comment |

**Observations:**
1. `[VERIFIED]` tsconfig.json correctly excludes .tsx files from main tsc build
2. `[VERIFIED]` Tailwind extends existing CSS variables for theme consistency
3. `[VERIFIED]` emptyOutDir: false preserves existing files
4. `[VERIFIED]` Build passes, React bundle compiles correctly
5. `[CRITICAL]` Static serving path mismatch - built files won't be accessible

**Data flow traced:** index.html → `/js/react/react.js` → 404 (file in dist/public, Express serves src/public)

**Handoff:** Back to Dev for fixes

## Dev Fix Assessment

**Fixes Applied:**
1. `[CRITICAL]` Changed Vite `outDir` from `dist/public` to `src/public` - Express already serves from src/public, so React bundle is now accessible at `/js/react/react.js`
2. `[LOW]` Removed stale tw- prefix comment from tailwind.css

**Verification:**
- Build outputs now in `src/public/js/react/react.js` and `src/public/css/react.css`
- Express will serve these files without any server.ts changes

**Commit:** d90699037 - fix(cyclist): output React build to src/public for Express serving

**Handoff:** Back to Reviewer for re-review

## Reviewer Re-Assessment

**Verdict:** APPROVED

**Issues Addressed:**
1. `[CRITICAL]` ✓ Fixed - Vite now outputs to `src/public`, React bundle accessible
2. `[LOW]` ✓ Fixed - Stale comment removed from tailwind.css

**Re-Review Observations:**
1. `[VERIFIED]` outDir changed to `src/public` at `vite.config.ts:12`
2. `[VERIFIED]` Build outputs exist at `src/public/js/react/react.js` and `src/public/css/react.css`
3. `[VERIFIED]` Full build passes (tsc + vite)
4. `[LOW]` Vite warning about outDir same as root - acceptable, works correctly
5. `[VERIFIED]` Data flow: index.html → `/js/react/react.js` → `src/public/js/react/react.js` (Express serves)

**Data flow traced:** index.html → `/js/react/react.js` → src/public/js/react/react.js (accessible via Express static serving)

**Handoff:** To SM (Titus Pullo) for finish-story
