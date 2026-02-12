# Story 102-1: Migrate BikeRack from index page to Dockview layout

**Epic:** 102 — BikeRack Follow-up — Dockview Migration and Panel Fixes
**Jira:** MSSCI-14877
**Status:** in_progress
**Phase:** finish
**Workflow:** tdd
**Repos:** pennyfarthing
**Branch:** feat/102-1-bikerack-dockview-migration

## Description
Migrate BikeRack from a custom index page + StandalonePanel wrapper approach to a proper Dockview layout. Currently, BikeRack uses `BikeRackIndex.tsx` and `StandalonePanel.tsx` for routing and panel display. This story focuses on replacing this with the same Dockview layout used by base Cyclist (`DockviewWorkspace.tsx`), enabling full multi-panel navigation and management in BikeRack mode.

## Context
- Follow-up to Epic 101 (BikeRack Mode — Decoupled WheelHub Dashboard)
- Currently BikeRack uses a custom BikeRackIndex page + StandalonePanel wrapper for individual panels
- Goal: Replace with proper Dockview layout similar to base Cyclist's DockviewWorkspace
- Key files to investigate: `src/public/components/DockviewWorkspace.tsx`, `src/public/components/BikeRackIndex.tsx`, `src/public/components/StandalonePanel.tsx`, `src/public/App.tsx`

## Acceptance Criteria
- [ ] BikeRack renders panels in Dockview layout instead of index page
- [ ] Panel tabs are navigable like base Cyclist
- [ ] StandalonePanel/?panel=X routing still works for direct panel access
- [ ] No regressions in base Cyclist Dockview behavior
- [ ] pnpm build succeeds
- [ ] Existing tests pass

## SM Assessment
- Epic 102 created and synced to Jira (MSSCI-14876)
- Story MSSCI-14877 claimed and in progress
- Branch created: feat/102-1-bikerack-dockview-migration in pennyfarthing/
- Epic context file created at sprint/context/context-epic-102.md
- TDD workflow: TEA designs tests first, then Dev implements
- This is a 5pt refactor: replacing BikeRackIndex + StandalonePanel with Dockview

## Technical Notes

### Architecture
- New component: `BikeRackWorkspace.tsx` — Dockview-based layout for BikeRack mode
- Replaces `BikeRackIndex.tsx` (index page) with proper tabbed Dockview workspace
- `App.tsx` routing: `/bikerack` → `BikeRackWorkspace` instead of `BikeRackIndex`
- `?panel=X` standalone routing unchanged (StandalonePanel still works)

### Key Design Decisions
- **No MessagePanel (sacred center) in BikeRack** — BikeRack is a monitoring dashboard, no conversation panel
- **Remove entire center panel region in BikeRack Dockview** — only left+right sidebars, no sacred center
- **BIKERACK_PANELS**: 13 panels (sprint, git, diffs, changed, workflow, background, audit, ac, tty, debug, bikelane, portrait, todo/todos)
- **Separate component** from DockviewWorkspace — BikeRackWorkspace is its own file, not a mode flag on DockviewWorkspace
- **Uses dockview-react** (unlike old BikeRackIndex which was forbidden from it per Rule 7)
- **No BikeRack-specific props on panels** (Rule 2 still applies)

### Files to Create/Modify
- `packages/cyclist/src/public/components/BikeRackWorkspace.tsx` — NEW (stub exists, needs implementation)
- `packages/cyclist/src/public/App.tsx` — MODIFY routing for `/bikerack`
- `packages/cyclist/tests/MSSCI-14877-bikerack-dockview.test.tsx` — NEW (32 tests written)

### Test Infrastructure Note
- DockviewWorkspace has heavy shadcn/ui dependency chain (`@/components/ui/badge`, `@/components/ui/button`)
- Runtime imports of DockviewWorkspace fail in vitest forks due to `@/` alias resolution
- AC4 regression tests use source code analysis (fs.readFileSync) instead of runtime imports
- This matches the MSSCI-14822 test pattern

## TEA Assessment

**Tests Required:** Yes
**Test File:** `packages/cyclist/tests/MSSCI-14877-bikerack-dockview.test.tsx`
**Tests Written:** 32 tests covering 4 ACs (AC5/AC6 verified separately)
**Status:** RED (13 failing, 19 passing — all failures are correct assertion failures)

**Failure Breakdown:**
- AC1: 3 failures (no cyclist-dockview class, App.tsx not routing to BikeRackWorkspace, no dockview-react import)
- AC2: 10 failures (BIKERACK_PANELS empty, createBikeRackLayout returns {})
- Structural: 1 failure (DockviewReact not in source)

**User Clarification:** Remove the entire center panel region (not just MessagePanel) when in BikeRack Dockview mode. BikeRack layout should be two-region (left + right sidebars only).

**Handoff:** To Korben Dallas (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/public/components/panel-registry.ts` - NEW: shared panel component Map for cross-workspace access
- `packages/cyclist/src/public/components/BikeRackWorkspace.tsx` - Full DockviewReact implementation, two-region layout, 13 panels
- `packages/cyclist/src/public/components/DockviewWorkspace.tsx` - Use shared panelRegistry instead of local Map
- `packages/cyclist/src/public/App.tsx` - Route /bikerack to BikeRackWorkspace instead of BikeRackIndex

**Tests:** 32/32 passing (GREEN)
**PR:** #829 — feat(102-1): migrate BikeRack from index page to Dockview layout
**Branch:** feat/102-1-bikerack-dockview-migration (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `/bikerack` URL → `App.tsx:205` detects pathname → hooks called unconditionally (lines 210-264) → conditional return at line 270 → noop `ClaudeContext.Provider` wraps `BikeRackWorkspace` → `onReady` callback builds two-region Dockview layout → `panelRegistry.get()` resolves components registered at module load. Safe — no user input passes unsanitized.

**Pattern observed:** Shared mutable registry (`panel-registry.ts:11`) extracted to break shadcn/ui dependency chain — good architectural decision. Both workspaces read from same `Map<string, ComponentType>` populated by `registerPanelComponent` at `App.tsx:56-73`.

**Error handling:** `PanelAdapter` at `BikeRackWorkspace.tsx:78-99` gracefully handles missing panel components with fallback title display. `ErrorBoundary` wraps each panel individually. `DockviewWorkspace.tsx:178-197` has equivalent pattern.

**Security:** No user input handling, no external data, no auth concerns. Pure UI restructuring.

**Observations:**
| Severity | Observation | Location |
|----------|------------|----------|
| [VERIFIED] | Hook ordering fixed — hooks called unconditionally, conditional returns after | `App.tsx:203-283` |
| [VERIFIED] | ClaudeContext noop matches all 12 fields of `ClaudeContextValue` interface | `App.tsx:271-279` |
| [VERIFIED] | BIKERACK_PANELS correctly excludes MessagePanel (sacred center) | `BikeRackWorkspace.tsx:34-48` |
| [VERIFIED] | DockviewWorkspace changes are minimal — 4 refs changed, behavior identical | `DockviewWorkspace.tsx` |
| [VERIFIED] | LEFT_PANELS (6) + RIGHT_PANELS (7) = BIKERACK_PANELS (13) — no mismatches | `BikeRackWorkspace.tsx:67-68` |
| [VERIFIED] | No `isBikeRack` props passed to panels (Rule 2 compliance) | `BikeRackWorkspace.tsx` |
| [LOW] | Dead code: `BikeRackIndex.tsx` still exists, no longer imported | `components/BikeRackIndex.tsx` |
| [LOW] | PanelAdapter duplicated with slight fallback differences | `BikeRackWorkspace.tsx:78` vs `DockviewWorkspace.tsx:178` |
| [LOW] | `createBikeRackLayout` exported/tested but unused at runtime | `BikeRackWorkspace.tsx:110` |
| [LOW] | Unstable `watermarkComponent={() => null}` reference | `BikeRackWorkspace.tsx:223` |
| [MEDIUM] | CI lint/ruff failures are pre-existing, not caused by this PR | CI jobs |

**Tests:** 32/32 passing. All ACs verified. TypeScript type check clean. Changed files lint clean.

**CI note:** `lint` and `Python Lint (Ruff)` CI jobs fail on pre-existing issues unrelated to this PR (ESLint warnings on untouched DockviewWorkspace lines, Ruff errors in `pennyfarthing_scripts/validate/`).

**Handoff:** To SM for finish-story
