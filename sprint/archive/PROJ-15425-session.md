# Story 125-4: Add sprint provenance indicator to BikeRack TUI
**Jira:** PROJ-15425
**Status:** in_progress
**Points:** 1
**Workflow:** trivial
**Phase:** finish
**Repos:** orchestrator
**Branch:** feat/125-4-add-sprint-provenance-indicator-to-bikerack
**Assigned:** keith.avery@slabgorb.io

## Story Context

This story is part of **Epic 125: Sprint State Engine Consolidation** (PROJ-15421), which consolidates fragmented sprint state across 6 storage locations into a unified SprintContext model.

**GitHub Issue:** [#1028](https://github.com/slabgorb/pennyfarthing-orchestrator/issues/1028)

### Problem
Users cannot see which sprint context is active when working with multiple sprint contexts (focus/spike sprints vs. main orchestrator sprint). When a non-default context is active, the BikeRack TUI sprint panel should display a provenance indicator (e.g., "[spike: ocsf-rs1]") in the header to give users clear feedback about their current sprint scope.

### Architecture Overview

**Current Flow:**
The sprint panel receives sprint data via WebSocket (`/ws/sprint`) with payload containing:
- `sprint`: Sprint metadata (number, name, done/remaining/in-progress counts)
- `epics`: List of epics with stories
- `registry`: Sprint context metadata with `name`, `type`, and `isDefault` flag

**Key Files:**
- `pennyfarthing-dist/pf/bikerack/sprint_panel.py` — TUI sprint panel (renders tree of epics/stories)
- `pennyfarthing-dist/pf/core/models.py` — SprintContext dataclass with `is_default` field
- `packages/core/src/public/hooks/useSprint.ts` — React hook typing with SprintRegistry interface
- `packages/core/src/server/api/*.ts` — WheelHub server routes constructing sprint payload

**Implementation Status:**
The Python TUI code (sprint_panel.py lines 320-329) **already implements** the provenance indicator display. The feature is functionally complete and ready for testing.

### Provenance Indicator Format

When `is_default` is False, append a bracket section to the header showing context type and name:
- Format: `[type:name]` (e.g., `[spike:ocsf-rs1]`)
- If only name: `[ocsf-rs1]`
- If only type: `[spike]`

Example header with provenance: `Sprint 2608  ✓10 pts  ⊙8 pts  ⟳2 pts  [dim]100%[/dim] [spike:ocsf-rs1]`

## Acceptance Criteria

### AC1: Header shows context when not default
- **Given** a user is viewing the BikeRack TUI sprint panel on a non-default context (e.g., `ocsf-rs1` spike)
- **When** the sprint panel receives payload with `registry.isDefault = False, registry.type = "spike", registry.name = "ocsf-rs1"`
- **Then** the panel header displays `[spike:ocsf-rs1]` appended to the sprint number and progress bar

### AC2: Header shows nothing when default
- **Given** a user is viewing the BikeRack TUI sprint panel on the default main sprint
- **When** the sprint panel receives payload with `registry.isDefault = True` or `registry` is missing
- **Then** the panel header displays sprint metadata with no additional provenance indicator

### AC3: Graceful handling of partial context data
- Handle `registry` with only `name` (no type) — display `[name]`
- Handle `registry` with only `type` (no name) — display `[type]`
- No errors when partial data is present

### AC4: No visual regression on default sprint
- Feature enabled on default sprint shows standard format with no extra brackets
- No whitespace or formatting changes to existing header

## Test Plan

1. **Default sprint flow:**
   - Launch BikeRack on orchestrator root with no sprint preference set
   - Verify sprint header shows standard format with no brackets
   - Check git panel, progress panel for any side effects

2. **Focus sprint flow:**
   - Set `sprint.active: "ocsf-rs1"` in `.pennyfarthing/config.local.yaml`
   - Launch BikeRack and verify sprint panel displays `[spike:ocsf-rs1]` in header
   - Verify epics/stories render normally below the header

3. **Edge cases:**
   - Create a context with only `name`, no `type` — verify header shows `[name]`
   - Create a context with only `type`, no `name` — verify header shows `[type]`
   - Switch between default and non-default contexts via config change — verify header updates

4. **Unblock GitHub issue:**
   - Verify issue #1028 is satisfied (users can see active sprint context)
   - Verify no regressions in git panel, progress panel, or other BikeRack panels

## SM Assessment

**Routing:** Trivial workflow (1pt) — SM → Dev → Reviewer → SM. No TEA phase needed.

**Context:** Implementation is already in place in `sprint_panel.py`. Dev should verify the existing code, add any missing tests, and confirm ACs are met. Lightweight story — mostly validation.

**Risks:** None identified. Feature is self-contained in the TUI sprint panel.

**Handoff to:** Gandalf (Dev) for implement phase.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/pf/tests/test_sprint_panel_provenance.py` — Fixed mock setup: added `mock_tree.size.width = 80` to all 9 test methods that were failing due to MagicMock vs int comparison

**Implementation Notes:**
- The provenance indicator code in `sprint_panel.py` (lines 320-329) was already correct and complete
- All 4 ACs are satisfied by the existing implementation:
  - AC1: `[type:name]` displayed for non-default registries
  - AC2: No indicator for default or missing registry
  - AC3: Handles partial data (name-only → `[name]`, type-only → `[type]`)
  - AC4: No visual regression on default sprint
- The only work needed was fixing the test mocks so the existing tests could pass

**Tests:** 67/67 passing (GREEN) — 9 provenance + 58 sprint panel
**Branch:** `fix/125-4-sprint-panel-provenance-tests` (pushed, pennyfarthing repo)

**Handoff:** To Saruman (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `registry` dict from WebSocket → `_rebuild_tree` → `.get()` accessors → `Text.append()` (plain text, safe) → `Static.update()`. No Rich markup injection possible.
**Wiring verified:** TypeScript `SprintRegistry` interface (`useSprint.ts:57-63`) matches Python expectations. `useSprint.ts:126` explicitly propagates/clears registry on updates.
**Pattern observed:** Consistent with existing header construction — base via `from_markup()`, provenance via plain `Text.append()` at `sprint_panel.py:320-329`.
**Error handling:** All `.get()` with defaults (lines 320-323), registry None check (line 321), header update in try/except (lines 330-333).
**Low findings:**
- Stale docstring at `test_sprint_panel_provenance.py:4` ("Phase: RED") — pre-existing
- No dedicated test for type-only provenance (code handles it at line 328) — non-blocking

**Handoff:** To Elrond (SM) for finish-story

## Session Log
- 2026-02-23T19:15:00Z SM: Session created, story claimed in Jira
- 2026-02-23T19:15:30Z SM: Assessment written, handing off to Dev
- 2026-02-23T19:16:00Z Dev: Verified existing implementation satisfies all ACs
- 2026-02-23T19:16:30Z Dev: Fixed 9 test mock setups (missing mock_tree.size.width)
- 2026-02-23T19:17:00Z Dev: 67/67 tests GREEN, branch pushed, handing off to Reviewer
- 2026-02-23T19:18:00Z Reviewer: APPROVED — traced data flow, verified wiring, 2 low findings (non-blocking)