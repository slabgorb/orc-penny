# Story 101-2: StandalonePanel wrapper and ?panel=X client routing

## Story Details
- **ID:** 101-2
- **Jira Key:** PROJ-14821
- **Epic:** 101 — BikeRack Mode (PROJ-14819)
- **Points:** 3
- **Priority:** P0
- **Workflow:** tdd-tandem
- **Assigned To:** kavery

## Description
Add client-side routing that detects ?panel=X in the URL and renders a single panel full-screen instead of the dockview workspace.

## Implementation Files

### New Files
- `src/public/components/StandalonePanel.tsx` — PANEL_REGISTRY mapping panel names to components, full-viewport wrapper, "Panel not found" fallback with link to /bikerack

### Modified Files
- `src/public/App.tsx` — check ?panel= before rendering DockviewWorkspace (~15 lines)

## Acceptance Criteria

- [ ] ?panel=sprint renders SprintPanel full-screen
- [ ] All 12 existing panels in PANEL_REGISTRY (sprint, git, diffs, todos, workflow, background, audit, changed, ac, tty, debug, bikelane)
- [ ] PANEL_REGISTRY is single source of truth for routing (CE-2)
- [ ] Invalid ?panel= value shows "Panel not found" with link to /bikerack
- [ ] No dockview-react imports in StandalonePanel (Rule 7)
- [ ] No BikeRack-specific props passed to panels (Rule 2)
- [ ] BikeRack detection is URL-based only — ?panel= presence (Rule 10)
- [ ] Normal / URL still loads dockview workspace
- [ ] pnpm build succeeds

## References
- ADR-0024 (BikeRack Design Architecture)
- Rules 2/7/10 (Framework implementation rules)
- CE-2 (Single source of truth for routing)

## Workflow Tracking

**Workflow:** tdd-tandem
**Phase:** finish
**Phase Started:** 2026-02-11T18:22:19Z
**Tandem:** none

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-11T18:00:51Z | 2026-02-11T18:01:51Z | 1m |
| red | 2026-02-11T18:01:51Z | 2026-02-11T18:07:16Z | 5m 25s |
| green | 2026-02-11T18:07:16Z | 2026-02-11T18:16:10Z | 8m 54s |
| review | 2026-02-11T18:16:10Z | 2026-02-11T18:22:19Z | 6m 9s |

## Technical Context

### Epic Context
Story 101-2 is part of the BikeRack Mode epic (101), which adds a decoupled WheelHub dashboard for CLI-first developers. Key constraints:
- Rule 2: No BikeRack-specific props passed to panels
- Rule 7: No dockview-react imports in StandalonePanel
- Rule 10: BikeRack detection is URL-based only
- CE-2: PANEL_REGISTRY is single source of truth for routing

### Panel Registry
The StandalonePanel must include all 12 existing Cyclist panels:
1. sprint
2. git
3. diffs
4. todos
5. workflow
6. background
7. audit
8. changed
9. ac
10. tty
11. debug
12. bikelane

### Next Agent
After setup completes, this story routes to **TEA (Test Engineer)** for the RED phase of tdd-tandem workflow.

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** 3-point P0 story with 9 ACs — full test coverage needed

**Test Files:**
- `packages/cyclist/tests/PROJ-14821-standalone-panel.test.tsx` — 27 tests across 8 AC groups

**Tests Written:** 27 tests covering 8 ACs (AC9 "pnpm build succeeds" is build-verification, not unit-testable)
**Status:** RED (21 failing, 6 passing — all failures are assertion-based, not import errors)

**Test Strategy:**
- AC1: Renders panel full-screen from `?panel=sprint` URL param
- AC2: PANEL_REGISTRY contains all 12 required panels (parametric test)
- AC3: PANEL_REGISTRY exported as named export, used for resolution (CE-2)
- AC4: Invalid panel name → "Panel not found" with `/bikerack` link
- AC5: Static analysis — no `dockview-react` imports in source (Rule 7)
- AC6: Static analysis — no BikeRack-specific props; panels render bare (Rule 2)
- AC7: `getStandalonePanelName()` reads URL only, no env vars (Rule 10)
- AC8: App.tsx imports StandalonePanel, routes conditionally

**Stub created:** `src/public/components/StandalonePanel.tsx` — exports `PANEL_REGISTRY` (empty), `getStandalonePanelName()` (returns null), `StandalonePanel` (renders stub div). Compiles cleanly; tests fail on assertions.

**Handoff:** To Korben Dallas (Dev) for GREEN phase implementation

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `src/public/components/StandalonePanel.tsx` — populated PANEL_REGISTRY with 12 panels, implemented getStandalonePanelName() URL reader, StandalonePanel full-screen wrapper with "Panel not found" fallback
- `src/public/App.tsx` — added conditional routing: getStandalonePanelName() check before DockviewWorkspace render (~5 lines)

**Tests:** 27/27 passing (GREEN)
**PR:** #817 — feat(101-2): StandalonePanel wrapper and ?panel=X routing
**Branch:** feat/101-2-standalone-panel-routing (pushed)

**ADR-0024 Compliance:**
- Rule 2: No BikeRack-specific props — panels render bare via `<PanelComponent />`
- Rule 7: Zero dockview-react imports — only imports from `./panels`
- Rule 10: URL-based detection only — `new URLSearchParams(window.location.search)`
- CE-2: PANEL_REGISTRY is single exported object, used by StandalonePanel for resolution

**Handoff:** To Zorg (Reviewer) for code review

### Handoff History
| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| red (tea) | green (dev) | tests_fail | PASSED | 2026-02-11T18:07:16Z |
| green (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-11T18:16:10Z |
| review (reviewer) | finish (sm) | approval | PASSED | 2026-02-11T18:22:19Z |

---

## Reviewer Assessment

**Verdict:** APPROVED
**Tests:** 2,493/2,493 passing, TypeScript clean
**Data flow traced:** `?panel=sprint` → `getStandalonePanelName()` → App early return → `StandalonePanel` → `PANEL_REGISTRY["sprint"]` → `<EnhancedSprintPanel />` (safe — URL param used as dictionary key only)
**Pattern observed:** Clean registry pattern at `StandalonePanel.tsx:36-49` — single `Record<string, ComponentType>` as source of truth (CE-2 compliant)
**Error handling:** Invalid panel → "Panel not found" fallback with `/bikerack` link at `StandalonePanel.tsx:66-74`

**Observations:**
| Severity | Issue | Location |
|----------|-------|----------|
| [MEDIUM] | Early return before hooks — safe (URL stable per page load) but violates eslint `react-hooks/rules-of-hooks`. Fix: extract to parent wrapper. | `App.tsx:204-207` |
| [MEDIUM] | `bikelane` maps to bare `BikeLanePanel` (needs props) instead of `ConnectedBikeLanePanel` (self-contained). Shows empty state in standalone mode. | `StandalonePanel.tsx:48` |
| [MEDIUM] | No ErrorBoundary wrapping standalone panel path | `App.tsx:205-207` |
| [LOW] | `getStandalonePanelName()` invoked twice (App.tsx + StandalonePanel.tsx) | Both files |

**Recommendation:** MEDIUM items are valid follow-up improvements, not blockers for this routing story. All 9 ACs met.

**Handoff:** To Ruby Rhod (SM) for finish-story
