# Story td-3: BikeRack panel state persistence

## Story Details
- **ID:** td-3
- **Workflow:** trivial
- **Type:** chore
- **Priority:** P2
- **Points:** 2
- **Status:** backlog
- **Description:** BikeRack panels (the standalone panel viewer mode in Cyclist) are not saving state properly. We need to add a mechanism for panel state persistence. BikeRack is the standalone panel viewer — key files: `packages/cyclist/src/bikerack.ts` (entry), `BikeRackWorkspace.tsx` (layout), `StandalonePanel.tsx` (routing).
- **Repos:** pennyfarthing
- **Branch:** chore/td-3-bikerack-panel-state
- **Assigned:** slabgorb@gmail.com

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-02-12T22:04:32Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-12T00:00:00Z | 2026-02-12T00:00:00Z | 0m |
| implement | 2026-02-12T00:00:00Z | 2026-02-12T22:00:15Z | 22h |
| review | 2026-02-12T22:00:15Z | 2026-02-12T22:04:32Z | 4m |

### Handoff History
| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| implement (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-12T22:00:15Z |
| review (reviewer) | finish (sm) | approval | PASSED | 2026-02-12T22:04:32Z |

## Context
This is a technical debt story addressing panel state persistence in BikeRack. The standalone panel viewer needs to properly save and restore panel state between sessions.

## Key Files
- `packages/cyclist/src/bikerack.ts` - Entry point
- `packages/cyclist/src/BikeRackWorkspace.tsx` - Layout
- `packages/cyclist/src/StandalonePanel.tsx` - Routing

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/api/settings.ts` - Added GET/PATCH `/bikerack-layout` endpoints storing `bikerack_layout` in config.local.yaml
- `packages/cyclist/src/public/hooks/useLayoutPersistence.ts` - Parameterized endpoint URL (default unchanged)
- `packages/cyclist/src/public/components/BikeRackWorkspace.tsx` - Added `initialLayout`/`onLayoutChange` props, Dockview `fromJSON`/`toJSON` persistence, layout change subscriptions
- `packages/cyclist/src/public/App.tsx` - Wired BikeRack route to use `bikerack-layout` endpoint, pass layout props, added loading state

**Tests:** Type-check passes (tsc --noEmit clean)
**PR:** #840 - feat(td-3): BikeRack panel state persistence
**Branch:** chore/td-3-bikerack-panel-state (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Panel rearrange → `onDidLayoutChange` → `handleLayoutChange` (300ms) → `saveLayout` (300ms) → `PATCH /api/settings/bikerack-layout` → `bikerack_layout` in config.local.yaml (safe — separate key from main layout, read-modify-write preserves other config)
**Pattern observed:** Server endpoints follow exact pattern of existing `/layout` routes at `settings.ts:498-564` — consistent read-modify-write YAML, `createErrorResponse` for errors
**Error handling:** `fromJSON` in try-catch with graceful fallback to default panels at `BikeRackWorkspace.tsx:116-121`; hook catches fetch errors at `useLayoutPersistence.ts:79-83`; server returns `{ layout: null }` on any failure
**Pre-existing:** 10 test failures (BIKERACK_PANELS count, agent-load-api, sidecar-pruning) and 1 lint warning (sprint-data.ts:287) — all confirmed on `develop`, none introduced by this PR
**Observations:** 1 LOW (double debounce 300ms+300ms — pre-existing pattern from DockviewWorkspace), 1 LOW (no `isReady` guard on subscription effect — Dockview fires `onReady` synchronously so timing is safe)

**Handoff:** To SM for finish-story
