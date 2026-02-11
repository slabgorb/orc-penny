# Story 101-3: BikeRackIndex panel listing page

**Jira:** MSSCI-14822
**Epic:** 101 — BikeRack Mode
**Points:** 1
**Workflow:** tdd-tandem
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/101-3-bikerack-index-panel
**Tandem:** architect (file-watch)

## Description

Create an index page at `/bikerack` listing all available panels with links to open each in a standalone tab.

## Files

- NEW: `src/public/components/BikeRackIndex.tsx` — panel listing with `?panel=` links, styled with Tailwind
- MODIFY: `src/server.ts` — add `/bikerack` route serving the SPA

## Acceptance Criteria

- [ ] `/bikerack` URL renders the index page
- [ ] Lists all 13 panels (12 existing + portrait) with links
- [ ] Links use `?panel=X` format
- [ ] Styled with Tailwind dark mode, consistent with Cyclist
- [ ] `pnpm build` succeeds

## Context

### Prior Work: Story 101-1 (isBikeRackMode gate and entry point)

Story 101-1 established the core BikeRack mode foundation:
- **isBikeRackMode()** function exported from `src/server.ts` (checks `process.env.IS_BIKERACK === '1'`)
- **src/bikerack.ts** entry point created — sets `IS_BIKERACK=1` BEFORE imports, calls `createTerminalServer()`, listens on port 2898, writes `.bikerack-port` after server.listen() callback
- **src/websocket.ts** — `/ws/claude` WebSocket channel guarded by `!isBikeRackMode()` to skip Claude session management in BikeRack mode
- All 12 existing panels (sprint, git, diffs, todos, workflow, background, audit, changed, ac, tty, debug, bikelane) continue to work unchanged

### Prior Work: Story 101-2 (StandalonePanel wrapper and ?panel=X routing)

Story 101-2 added client-side panel routing:
- **PANEL_REGISTRY** mapping in `src/public/components/StandalonePanel.tsx` — registry includes all 12 existing panels by URL name (sprint, git, diffs, todos, workflow, background, audit, changed, ac, tty, debug, bikelane)
- **StandalonePanel.tsx** — renders a single panel full-screen based on `?panel=X` URL parameter
- **src/public/App.tsx** — checks for `?panel=` parameter before rendering DockviewWorkspace; if present, renders StandalonePanel instead
- "Panel not found" fallback with link to `/bikerack` (the index page this story will create)
- All panels work identically in both dockview (workspace) and standalone modes — no BikeRack-specific props or modifications

### ADR-0024 Requirements

ADR-0024 specifies:
- 13 panels total: 12 existing panels + new PortraitPanel (story 101-4)
- `/bikerack` serves an index page listing all panels
- Each panel is accessible via `?panel=X` query parameter
- Index page provides links in `?panel=X` format for all panels
- Panels styled with Tailwind dark mode, consistent with Cyclist
- No new WebSocket channels (CE-5) — reuses existing 16 channels

### Current Panel Inventory (12 existing, 1 new upcoming)

From `StandalonePanel.tsx` PANEL_REGISTRY and App.tsx panel registrations:

1. **sprint** — EnhancedSprintPanel (story tracking)
2. **git** — GitPanel (repository status)
3. **diffs** — DiffsPanel (code changes)
4. **todos** — TodoPanel (acceptance criteria tracking)
5. **workflow** — WorkflowPanel (current workflow state)
6. **background** — BackgroundPanel (background tasks)
7. **audit** — AuditLogPanel (OTEL spans and logs)
8. **changed** — ChangedPanel (changed files)
9. **ac** — ACPanel (acceptance criteria detail)
10. **tty** — TTYPanel (terminal output)
11. **debug** — DebugPanel (debug information)
12. **bikelane** — BikeLanePanel (workflow visualization)
13. **portrait** — PortraitPanel (NEW, story 101-4) — agent identity with tandem support

### BikeRack Mode Gate

All code uses centralized `isBikeRackMode()` function from `src/server.ts`:
```typescript
export function isBikeRackMode(): boolean {
  return process.env.IS_BIKERACK === '1';
}
```

No direct `process.env.IS_BIKERACK` checks anywhere in the codebase (Rule 1, ADR-0024).

## Technical Approach

### BikeRackIndex.tsx Component

Create a new React component that:
1. Renders as a full-screen page (similar layout to StandalonePanel fallback)
2. Displays a grid or list of all 13 panels with:
   - Panel name (display-friendly, e.g., "Sprint" instead of "sprint")
   - Brief description of what each panel shows
   - Clickable link to `/?panel=X` to open that panel in standalone mode
3. Uses Tailwind CSS for styling (dark mode, consistent with Cyclist)
4. Optionally includes back navigation or a "New Tab" icon to show it opens in a new browser tab

### Server Route

Add a new route in `src/server.ts`:
```typescript
app.get('/bikerack', (_req, res) => {
  res.sendFile(join(publicDir, 'index.html'));
});
```

This serves the same `index.html` that App.tsx renders, allowing React Router to handle the `/bikerack` path client-side. The App component will render BikeRackIndex when the path is `/bikerack`.

### App.tsx Integration

Modify `src/public/App.tsx` to detect `/bikerack` path and render BikeRackIndex instead of DockviewWorkspace:
- Check if current URL path is `/bikerack`
- If yes, render BikeRackIndex
- If `?panel=X` present, render StandalonePanel
- Otherwise render DockviewWorkspace (normal Cyclist mode)

### Styling

Use Tailwind CSS classes consistent with Cyclist's design system:
- Dark background (e.g., `bg-slate-900`, `dark:bg-slate-950`)
- Light text (e.g., `text-white`, `text-gray-200`)
- Hover effects on links (e.g., `hover:bg-slate-800`, `hover:text-cyan-400`)
- Card-like containers for each panel (e.g., `border`, `rounded-lg`, `p-4`)
- Responsive grid (e.g., `grid-cols-1 md:grid-cols-2 lg:grid-cols-3`)

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** React component + server route + client routing — needs functional verification

**Test Files:**
- `packages/cyclist/tests/MSSCI-14822-bikerack-index.test.tsx` — 22 tests across 5 AC groups + structural rules

**Tests Written:** 22 tests covering 5 ACs
**Status:** RED (35 failing on assertions, 5 structural passing — correct RED state)

**Test Breakdown:**
- AC1 (5 tests): BikeRackIndex export, rendering, heading, App.tsx routing, server.ts route
- AC2 (15 tests): 13 individual panel presence, 13 panel links, link count verification
- AC3 (14 tests): 13 ?panel=X href checks, query parameter format validation
- AC4 (3 tests): Tailwind className usage, dark-mode classes, minimal inline styles
- Structural (3 tests): No dockview imports (Rule 7), no BikeRack props (Rule 2), no process.env (Rule 10)

**Implementation Notes for Dev:**
1. Create `BikeRackIndex.tsx` with 13 panel links using `?panel=X` format
2. Add `/bikerack` route to `server.ts` serving index.html
3. Update `App.tsx` to detect `/bikerack` path and render BikeRackIndex
4. Use Tailwind CSS classes (dark mode) — not inline styles
5. Include portrait panel (story 101-4) in the listing — component doesn't need to exist yet, just the link

**Handoff:** To Dev (Korben Dallas) for GREEN phase implementation

---

## Handoff: SM → TEA
**Time:** 2026-02-11T14:00:00Z
**Phase:** setup → red
**Notes:** Story setup complete. Session created with full context from 101-1 and 101-2. Branch created in pennyfarthing repo. Jira claimed and moved to In Progress. tdd-tandem workflow — architect rides backseat during TEA phase.

---

## Handoff: TEA → Dev
**Time:** 2026-02-11T14:15:00Z
**Phase:** red → green
**Test Result:** RED — 35 failing tests on assertions, 5 structural passing
**Notes:** 22 tests written covering all 5 ACs. Stub component in place. Dev must implement BikeRackIndex.tsx, add /bikerack server route, and update App.tsx routing. tdd-tandem — architect rides backseat during Dev phase.

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/components/BikeRackIndex.tsx` - Full implementation with 13 panel cards, Tailwind dark mode, ?panel=X links
- `packages/cyclist/src/public/App.tsx` - /bikerack path detection, BikeRackIndex import and routing
- `packages/cyclist/src/server.ts` - /bikerack route serving SPA index.html

**Tests:** 40/40 passing (GREEN)
**PR:** #819 — feat(101-3): BikeRackIndex panel listing page
**Branch:** feat/101-3-bikerack-index-panel (pushed)

**Handoff:** To Reviewer for code review

---

## Handoff: Dev → Reviewer
**Time:** 2026-02-11T14:30:00Z
**Phase:** green → review
**Test Result:** GREEN — 40/40 passing
**Notes:** Implementation complete. BikeRackIndex with 13 panels, /bikerack route, App.tsx routing. PR #819 ready for review.

---

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `/bikerack` → server.ts serves index.html → App.tsx pathname check → BikeRackIndex renders → link click → `/?panel=X` → StandalonePanel renders (safe — static content, no user input)
**Pattern observed:** Early-return-before-hooks pattern at `App.tsx:204` — consistent with existing 101-2 standalone panel check at line 210
**Error handling:** Static listing page, no async ops. Portrait link gracefully degrades to "Panel not found" fallback until 101-4.
**Security:** No user input, no dangerouslySetInnerHTML, no dynamic hrefs from untrusted sources
**Observations:**
- `[VERIFIED]` All 13 panels, ADR-0024 rules, complete wiring, no forbidden patterns
- `[LOW]` PANELS array duplicates PANEL_REGISTRY knowledge — acceptable for 1-point story, portrait intentionally diverges

**Handoff:** To SM for finish-story

---

## Handoff: Reviewer → SM
**Time:** 2026-02-11T19:09:22Z
**Phase:** review → finish
**Verdict:** APPROVED
**Notes:** Code review passed. PR #819 merged to develop. No Critical or High issues. Clean implementation.

---

*Session created: 2026-02-11T14:00:00Z*
