# Story 101-4: PortraitPanel with tandem support

**Session ID:** 101-4
**JIRA:** MSSCI-14823
**Title:** PortraitPanel with tandem support
**Points:** 2
**Priority:** P1
**Status:** in_progress
**Workflow:** tdd-tandem
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/101-4-portrait-panel-tandem
**Tandem:** architect (file-watch)
**Epic:** 101 — BikeRack Mode
**Assignee:** kavery

## Story Description

New standalone panel displaying agent identity (character, role, portrait image) with tandem backseat support.

PortraitPanel subscribes to `/ws/persona` via the existing `usePersona()` hook and displays:
- Agent character name
- Agent role
- Portrait image from `/portraits/{theme}/medium/{slug}.png`
- Tandem agent when active

## Context from Prior Work

### Story 101-1: isBikeRackMode() gate and entry point
- **isBikeRackMode()** function exported from `src/server.ts` — checks `process.env.IS_BIKERACK === '1'`
- **src/bikerack.ts** entry point — sets `IS_BIKERACK=1`, calls `createTerminalServer()`, listens on port 2898
- **src/websocket.ts** — `/ws/claude` guarded by `!isBikeRackMode()`

### Story 101-2: StandalonePanel wrapper and ?panel=X routing
- **PANEL_REGISTRY** mapping in `StandalonePanel.tsx` — all 12 existing panels
- **StandalonePanel.tsx** — renders single panel full-screen based on `?panel=X`
- **App.tsx** — checks for `?panel=` before rendering `DockviewWorkspace`

### Story 101-3: BikeRackIndex panel listing page
- **BikeRackIndex.tsx** with 13 panel cards including portrait link
- **/bikerack** route serving SPA index.html
- **App.tsx** `/bikerack` path detection

## Files to Modify

### NEW: src/public/components/panels/PortraitPanel.tsx
- Subscribes to `/ws/persona` via `usePersona()` hook
- Displays portrait image from `/portraits/{theme}/medium/{slug}.png`
- Shows tandem agent when active
- Shows "No agent active" state when no persona data
- Renderable in StandalonePanel wrapper via `?panel=portrait`

### MODIFY: src/public/components/panels/index.ts
- Export PortraitPanel

## Acceptance Criteria

- [x] PortraitPanel uses existing usePersona() hook (CE-1)
- [x] No new WebSocket connections or endpoints (CE-5, Rule 3)
- [x] Displays character name, role, portrait image
- [x] Shows tandem agent when active (tandemAgent data)
- [x] Shows "No agent active" state when no persona data
- [x] Portrait URL resolved via /portraits/{theme}/medium/{slug}.png
- [x] Renders correctly in StandalonePanel wrapper via ?panel=portrait
- [x] pnpm build succeeds

## References

- ADR-0024 (BikeRack Mode Architecture)
- Rules 2/3 (No BikeRack-specific props, no new endpoints)
- CE-1 (Use existing hooks)
- CE-5 (No new WebSocket connections)
- Contract 4 (Panel responsibilities)

## Workflow: tdd-tandem

**Tandem Agent (backseat):** architect (file-watch)

Flow:
1. TEA → Set up tests
2. TEA + Architect → Implement
3. Reviewer + PM → Review
4. SM → Complete

## Session Notes

- Reusing `/ws/persona` endpoint from prior work (no new endpoints)
- Reusing `usePersona()` hook from existing panels
- Portrait images in `/portraits/{theme}/medium/` follow existing theme structure
- Tandem backseat: architect provides real-time file review and architectural feedback

---

## Handoff: SM → TEA
**Time:** 2026-02-11T00:00:00Z
**Phase:** setup → red
**Notes:** Story setup complete. Session created with full context from 101-1, 101-2, and 101-3. Branch created in pennyfarthing repo. Jira claimed and moved to In Progress. tdd-tandem workflow — architect rides backseat during TEA phase.

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** React component + StandalonePanel integration + WebSocket hook subscription — needs functional verification

**Test Files:**
- `packages/cyclist/tests/MSSCI-14823-portrait-panel.test.tsx` — 22 tests across 8 AC groups + structural rules

**Tests Written:** 22 tests covering 8 ACs
**Status:** RED (16 failing on assertions, 6 structural passing — correct RED state)

**Test Breakdown:**
- AC1 (2 tests): usePersona import verification, hook call in component body
- AC2 (2 tests): No new WebSocket constructors in source, only /ws/persona connections
- AC3 (3 tests): Character name display, role display, portrait image element
- AC4 (4 tests): Tandem character name, tandem role, tandem portrait image, no tandem when absent
- AC5 (2 tests): Empty state when no persona data, empty state when persona fields null
- AC6 (2 tests): Primary portrait URL pattern, tandem portrait URL pattern
- AC7 (3 tests): PANEL_REGISTRY has 'portrait' key, maps to PortraitPanel, renders via ?panel=portrait
- Structural (4 tests): No dockview imports (Rule 7), no BikeRack props (Rule 2), no process.env (Rule 10), panels/index.ts export

**Implementation Notes for Dev:**
1. Implement PortraitPanel.tsx using `usePersona()` hook — character, role, slug, theme, tandemAgent
2. Add `export { PortraitPanel } from './PortraitPanel'` to `panels/index.ts`
3. Add `portrait: PortraitPanel` to `PANEL_REGISTRY` in `StandalonePanel.tsx`
4. Portrait img src: `/portraits/${theme}/medium/${slug}.png` with alt={character}
5. Show tandem agent info (character, role, portrait) when `tandemAgent` is present
6. Show "No agent active" text when persona is null or has null character
7. Reference `PersonaHeader.tsx` for usePersona patterns, portrait URL resolution, and tandem display

**Handoff:** To Dev (Korben Dallas) for GREEN phase implementation

---

## Handoff: TEA → Dev
**Time:** 2026-02-11T14:30:00Z
**Phase:** red → green
**Test Result:** RED — 16 failing tests on assertions, 6 structural passing
**Notes:** 22 tests written covering all 8 ACs. Stub component in place. Dev must implement PortraitPanel.tsx with usePersona() hook, add to panels/index.ts export, and register in StandalonePanel PANEL_REGISTRY. tdd-tandem — architect rides backseat during Dev phase.

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/components/panels/PortraitPanel.tsx` — Full implementation with usePersona() hook, portrait display, tandem support, empty state
- `packages/cyclist/src/public/components/panels/index.ts` — Added PortraitPanel export
- `packages/cyclist/src/public/components/StandalonePanel.tsx` — Added portrait to PANEL_REGISTRY and import
- `packages/cyclist/tests/MSSCI-14823-portrait-panel.test.tsx` — Fixed WebSocket mock setup (self-contained, resilient to vi.restoreAllMocks)

**Tests:** 22/22 passing (GREEN)
**PR:** #822 — feat(cyclist): PortraitPanel with tandem support (MSSCI-14823)
**Branch:** feat/101-4-portrait-panel-tandem (pushed)

**Handoff:** To Reviewer for code review

---

## Handoff: Dev → Reviewer
**Time:** 2026-02-11T00:00:00Z
**Phase:** green → review
**Test Result:** GREEN — 22/22 passing
**Notes:** PortraitPanel implemented with usePersona() hook. All 22 tests GREEN. PR #822 created targeting develop. Ready for adversarial review. tdd-tandem — architect+PM ride backseat during Reviewer phase.

---

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `/ws/persona` WebSocket → usePersona() hook → persona state → PortraitPanel render (safe — pure consumer, no new endpoints)
**Pattern observed:** Minimal component following existing panel pattern — no dockview imports, no BikeRack props, usePersona() hook reuse at `PortraitPanel.tsx:20`
**Error handling:** Null persona guard at `PortraitPanel.tsx:22`, empty state "No agent active" at line 25, hook error handling at `usePersona.ts:92-96`
**Security:** No user input, no dangerouslySetInnerHTML, no secrets, no process.env. Clean.
**Non-blocking observations:** [MEDIUM] No img onError fallback (line 35), [LOW] null safety gap on theme/slug (line 30), [LOW] inline styles vs Tailwind (cosmetic)
**Tests:** 22/22 GREEN | **TypeScript:** Clean | **Forbidden patterns:** None
**Handoff:** To SM for finish-story

---

## Handoff: Reviewer → SM
**Time:** 2026-02-11T19:42:00Z
**Phase:** review → finish
**Verdict:** APPROVED
**Notes:** PR #822 merged to develop. All 22 tests GREEN, TypeScript clean. No blocking issues. Ready for SM to run finish-story flow.
