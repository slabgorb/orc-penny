# Story 124-5: Move Display Components and Update Entry Points

## Story Details
- **ID:** 124-5
- **Jira Key:** PROJ-15556
- **Title:** Move Display Components and Update Entry Points
- **Status:** in_progress
- **Points:** 2
- **Priority:** p1
- **Assigned to:** keith.avery@slabgorb.io
- **Repos:** pennyfarthing
- **Workflow:** tdd
- **Type:** feature

## Acceptance Criteria
- BikeRackWorkspace, BikeRackIndex, StandalonePanel are in packages/bikerack/
- Entry point expanded in packages/bikerack/src/ with full launcher (start server + Claude CLI) and cleanup (port file, process management)
- pf bikerack start works and launches the standalone BikeRack product
- Panel components remain in core (shared by BikeRack, Cyclist, and future BikeShop)
- Port 2898 convention preserved for BikeRack (vs 1898 for Cyclist)

## Story Context
This is story 5 of 6 in Epic 124: BikeRack Standalone Package Extraction (PROJ-15551).

Previous completed stories:
- 124-1: Extract Server Engine into packages/bikerack/ (PROJ-15552) - APPROVED
- 124-2: Move WebSocket and OTLP from Cyclist to BikeRack (PROJ-15553) - APPROVED
- 124-3: Introduce DataSource<T> and Refactor Panel Hooks (PROJ-15554) - APPROVED
- 124-4: Rewire Cyclist to Depend on BikeRack (PROJ-15555) - APPROVED

This story focuses on moving display components (BikeRackWorkspace, BikeRackIndex, StandalonePanel) into the bikerack package and expanding the entry point with a full launcher and cleanup logic.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-24T17:21:39Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|

## SM Assessment — Setup Phase

Story 124-5 is ready for TDD red phase. Session file created with all 5 ACs from the sprint YAML. Feature branch `feature/PROJ-15556-move-display-components-entry-points` created from develop in the pennyfarthing repo. Jira PROJ-15556 claimed and moved to In Progress.

This is the fifth story in the BikeRack extraction epic. Stories 124-1 through 124-4 are all approved/complete. This story moves display components into BikeRack and wires up the standalone launcher.

Key areas for TEA to focus test design:
- BikeRackWorkspace, BikeRackIndex, StandalonePanel location verification
- Entry point launcher with server start + CLI integration
- `pf bikerack start` command functionality
- Panel components staying in core (shared)
- Port 2898 convention for BikeRack

**Handoff to:** TEA (red phase)

## Development Branch
- **Branch:** feature/PROJ-15556-move-display-components-entry-points
- **Base:** develop

## TEA Assessment

**Tests Required:** Yes
**Reason:** Feature story with 5 ACs requiring structural verification

**Test Files:**
- `packages/cyclist/tests/124-5-move-display-components.test.ts` - Cross-package structural tests (vitest, node environment)

**Tests Written:** 35 tests covering 5 ACs
**Status:** RED (17 failing, 18 passing — ready for Dev)

**Breakdown:**
- AC1 (7 tests, 7 failing): BikeRackWorkspace, BikeRackIndex, StandalonePanel must exist in bikerack/src/ and be removed from core/
- AC2 (5 tests, 5 failing): Self-contained entry point with server start, port file, SIGINT/SIGTERM cleanup in bikerack/src/
- AC3 (5 tests, 3 failing): Python launcher must reference bikerack entry (not cyclist), remove IS_BIKERACK env var, export launcher from package.json
- AC4 (13 tests, 0 failing): Panel components correctly remain in core — already green
- AC5 (4 tests, 2 failing): Port 2898 default in bikerack entry point, BIKERACK_PORT env override

**Key implementation notes for Dev:**
1. Move 3 display components from `packages/core/src/public/components/` → `packages/bikerack/src/`
2. Create launcher entry point in `packages/bikerack/src/` (entry.ts, launcher.ts, start.ts, or cli.ts)
3. Move port file + signal handler logic from `packages/cyclist/src/bikerack.ts` into bikerack's own entry
4. Update `pennyfarthing-dist/src/pf/bikerack/launcher.py` to reference bikerack entry (not cyclist) and remove IS_BIKERACK
5. Add launcher export to bikerack `package.json` exports
6. BikeRack will need React dependencies (react, dockview-react) for display components

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/bikerack/src/BikeRackWorkspace.tsx` - moved from core, imports updated to @pennyfarthing/core
- `packages/bikerack/src/BikeRackIndex.tsx` - moved from core (React-only, clean move)
- `packages/bikerack/src/StandalonePanel.tsx` - moved from core, panel imports from @pennyfarthing/core
- `packages/bikerack/src/entry.ts` - new self-contained launcher (server start, port file, signal handlers)
- `packages/bikerack/src/index.ts` - added display component exports
- `packages/bikerack/package.json` - added ./entry export path
- `packages/core/src/public/components/BikeRackWorkspace.tsx` - deleted (moved)
- `packages/core/src/public/components/BikeRackIndex.tsx` - deleted (moved)
- `packages/core/src/public/components/StandalonePanel.tsx` - deleted (moved)
- `packages/cyclist/src/bikerack.ts` - thinned to delegator
- `pennyfarthing-dist/src/pf/bikerack/launcher.py` - updated to reference bikerack entry, removed IS_BIKERACK

**Tests:** 35/35 passing (GREEN)
**Branch:** feature/PROJ-15556-move-display-components-entry-points (pushed)

**Handoff:** To review phase

## TEA Verify Assessment

**Tests:** 35/35 passing (GREEN confirmed)
**Verification:** All 5 ACs verified via structural tests
**Status:** GREEN — ready for review

**Handoff:** To Reviewer

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | Broken imports — App.tsx imports StandalonePanel and BikeRackWorkspace from deleted paths | `packages/core/src/public/App.tsx:26-27` | Update imports to `@pennyfarthing/bikerack` or re-export from core |
| [MEDIUM] | bikerack tsconfig.json has no JSX support — .tsx files won't compile | `packages/bikerack/tsconfig.json` | Add `"jsx": "react-jsx"` to compilerOptions |
| [MEDIUM] | Missing React/dockview-react deps in bikerack package.json | `packages/bikerack/package.json` | Add react, dockview-react to dependencies |
| [LOW] | dockview-theme.css import removed, not redirected | `packages/bikerack/src/BikeRackWorkspace.tsx` | Add CSS import from core or bikerack |
| [VERIFIED] | Entry point entry.ts has correct server start, port file, cleanup logic | `packages/bikerack/src/entry.ts` | - |
| [VERIFIED] | Python launcher correctly references bikerack/dist/entry.js | `pennyfarthing-dist/src/pf/bikerack/launcher.py:89` | - |
| [VERIFIED] | IS_BIKERACK env var removed from launcher | `pennyfarthing-dist/src/pf/bikerack/launcher.py` | - |
| [VERIFIED] | Cyclist bikerack.ts properly thinned to delegator | `packages/cyclist/src/bikerack.ts` | - |
| [VERIFIED] | Port 2898 convention preserved | `packages/bikerack/src/entry.ts:10` | - |
| [VERIFIED] | Panel components untouched in core | `packages/core/src/public/components/panels/` | - |

**Blocking:** [HIGH] App.tsx broken imports must be fixed before merge.

**Handoff:** Back to Dev for fixes

## Dev Assessment (Fix Round)

**Fixes Applied:**
- `packages/core/src/public/App.tsx` - Updated imports from deleted paths to `@pennyfarthing/bikerack`
- `packages/core/package.json` - Added @pennyfarthing/bikerack as optional peer dep
- `packages/bikerack/tsconfig.json` - Added `jsx: react-jsx` for .tsx compilation
- `packages/bikerack/package.json` - Added react/dockview-react as peer + dev deps
- `packages/bikerack/src/BikeRackWorkspace.tsx` - Restored dockview-theme.css import

**Tests:** 35/35 passing (GREEN)
**Branch:** feature/PROJ-15556-move-display-components-entry-points (pushed)

**Handoff:** To review (re-review)

## Reviewer Assessment (Re-review)

**Verdict:** APPROVED

All four previous findings resolved:
- [VERIFIED] App.tsx imports updated to `@pennyfarthing/bikerack` — `core/src/public/App.tsx:25`
- [VERIFIED] JSX support added — `bikerack/tsconfig.json:6`
- [VERIFIED] React/dockview-react peer deps — `bikerack/package.json`
- [VERIFIED] CSS import restored — `bikerack/src/BikeRackWorkspace.tsx:28`
- [VERIFIED] Circular dep handled via optional peer dep pattern — `core/package.json`

**Data flow traced:** `pf bikerack start` → launcher.py → `bikerack/dist/entry.js` → createTerminalServer → listen 2898 → write .bikerack-port (safe, no injection)
**Pattern observed:** Optional peer deps for cross-package UI component sharing — correct monorepo pattern
**Error handling:** Entry IIFE at parity with original (no regression)

**Handoff:** To SM for finish-story