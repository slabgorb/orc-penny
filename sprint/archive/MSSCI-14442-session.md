# Story: 79-2 — Migrate HotspotsPanel into HotspotsDialog

**Jira:** MSSCI-14442
**Epic:** epic-79 (MSSCI-14440) — Dialog Infrastructure + Hotspot Refactor
**Points:** 2
**Priority:** P0
**Workflow:** tdd
**Phase:** finish (review complete)
**PR:** #720 (merged)
**Repos:** pennyfarthing
**Branch:** feat/79-2-migrate-hotspots-dialog
**Assigned:** keith.avery@1898andco.io

## Description

Move HotspotsPanel content into components/dialogs/HotspotsDialog.tsx using ToolDialog wrapper. Remove HotspotsPanel from PANEL_INVENTORY, RIGHT_SIDEBAR_PANELS, PANEL_TITLES in DockviewWorkspace.tsx. Remove registration from App.tsx and export from panels/index.ts.

## Acceptance Criteria

- [ ] HotspotsDialog.tsx created using ToolDialog wrapper from 79-1
- [ ] HotspotsPanel content migrated into HotspotsDialog
- [ ] HotspotsPanel removed from PANEL_INVENTORY in DockviewWorkspace.tsx
- [ ] HotspotsPanel removed from RIGHT_SIDEBAR_PANELS in DockviewWorkspace.tsx
- [ ] HotspotsPanel removed from PANEL_TITLES in DockviewWorkspace.tsx
- [ ] HotspotsPanel registration removed from App.tsx
- [ ] HotspotsPanel export removed from panels/index.ts
- [ ] Tests pass for the new HotspotsDialog component
- [ ] Build succeeds with no type errors

## Technical Context

- ToolDialog shared component was created in 79-1 — use it as the wrapper
- Key files: DockviewWorkspace.tsx, App.tsx, panels/index.ts, HotspotsPanel.tsx
- Repo: pennyfarthing (packages/cyclist/)

## TEA Assessment

**Tests Required:** Yes
**Reason:** Migration with removal — must verify both new dialog and old panel cleanup

**Test Files:**
- `packages/cyclist/tests/79-2-hotspots-dialog.test.tsx` — 20 tests across 9 ACs

**Tests Written:** 20 tests covering 9 ACs (18 failing, 2 passing)
**Status:** RED (failing — ready for Dev)

**Key implementation notes for Dev:**
1. Create `HotspotsDialog` in `components/dialogs/HotspotsDialog.tsx` wrapping ToolDialog
2. Move all HotspotsPanel content (controls, tables, states) into the dialog body
3. Remove `HOTSPOTS` from `PANEL_INVENTORY`, `RIGHT_SIDEBAR_PANELS`, `PANEL_TITLES` in DockviewWorkspace.tsx
4. Remove `registerPanelComponent(PANEL_INVENTORY.HOTSPOTS, HotspotsPanel)` from App.tsx
5. Remove `HotspotsPanel` export from `panels/index.ts`
6. Stub file exists at `components/dialogs/HotspotsDialog.tsx` — replace with real implementation
7. `useHotspots` hook is mocked in tests — dialog should use it the same way HotspotsPanel does

**Handoff:** To Dev (Roy Batty) for implementation

## Dev Assessment

**Implementation:** Complete — all ACs addressed
**Tests:** 20/20 GREEN, existing hotspots-panel tests 8/8 GREEN
**TypeScript:** Compiles clean (tsc --noEmit)

**Files Changed:**
- `packages/cyclist/src/public/components/dialogs/HotspotsDialog.tsx` — full implementation using ToolDialog wrapper
- `packages/cyclist/src/public/components/DockviewWorkspace.tsx` — removed HOTSPOTS from PANEL_INVENTORY, RIGHT_SIDEBAR_PANELS, PANEL_TITLES
- `packages/cyclist/src/public/App.tsx` — removed HotspotsPanel import and registration
- `packages/cyclist/src/public/components/panels/index.ts` — removed HotspotsPanel export

**Note for Reviewer:** HotspotsPanel.tsx file still exists but is now orphaned (no imports). Reviewer may want to flag for deletion in a follow-up or as part of this PR.

**Handoff:** To Reviewer (J.F. Sebastian) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**PR:** #720 — merged to develop

**Observations:**
| Severity | Issue | Location | Action |
|----------|-------|----------|--------|
| `[VERIFIED]` | ToolDialog integration correct | HotspotsDialog.tsx:199 | Props passed through correctly |
| `[VERIFIED]` | All 3 DockviewWorkspace removal sites clean | DockviewWorkspace.tsx:52,94,112 | PANEL_INVENTORY, RIGHT_SIDEBAR, TITLES |
| `[VERIFIED]` | App.tsx clean — import + registration removed | App.tsx:45,71 | No dead references |
| `[VERIFIED]` | Data flow: useHotspots → fetch → renderContent | HotspotsDialog.tsx:205 | Same flow as original panel |
| `[VERIFIED]` | No security concerns | — | No user input changes |
| `[MEDIUM]` | menu-builder.ts:161 still has `hotspots` entry | menu-builder.ts:161 | Pre-existing, flag for follow-up |
| `[MEDIUM]` | Duplicate PANEL_TITLES at DockviewWorkspace.tsx:670 | DockviewWorkspace.tsx:670 | Pre-existing dead code |
| `[LOW]` | HotspotsPanel.tsx orphaned (no imports) | panels/HotspotsPanel.tsx | Delete in follow-up |

**Handoff:** To SM (Captain Bryant) for finish-story

## Session Log

- **Setup:** Session created by SM (Captain Bryant)
- **Handoff to TEA:** Story setup complete. TDD workflow — Deckard writes tests first.
- **TEA RED complete:** 20 tests written (18 failing). Stub created. Handing to Dev.
- **Dev GREEN complete:** 20/20 tests passing. All removals done. Handing to Reviewer.
- **Reviewer APPROVED:** PR #720 merged. 5 verified, 2 medium (pre-existing), 1 low. Handing to SM.
- **Reviewer Handoff:** PR approved and merged. All acceptance criteria met. Ready for SM finish-story.
