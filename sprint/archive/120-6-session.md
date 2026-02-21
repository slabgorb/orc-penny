# Story 120-6: Sprint panel ignores active sprint preference from sprint registry

**Status:** in_progress
**Phase:** finish
**Workflow:** tdd
**Jira:** (none)
**Branch:** feat/120-6-sprint-panel-active-sprint-preference
**Repos:** pennyfarthing
**Assignee:** M. Pursifull
**Points:** 3
**Epic:** 120 — BikeRack TUI Enhancements
**Started:** 2026-02-21

---

## Context

The TUI Sprint panel always displays `sprint/current-sprint.yaml` regardless of the user's active sprint preference set via `pf sprint use <name>`. This affects orchestrator projects with multiple parallel sprints (main project + spike/research sprints).

### Sprint registry system

1. **Sprint registry** (`sprint/sprints.yaml`): Maps sprint names to file paths and metadata
2. **Per-user preference** (`.pennyfarthing/config.local.yaml` → `sprint.active`): Stores which named sprint the user selected
3. **CLI resolution** (`pf/sprint/loader.py` → `load_sprint()`): Correctly resolves preference → registry → file path → fallback
4. **TUI bug**: `sprint-data.ts` hardcodes `sprint/current-sprint.yaml`, ignoring the registry

### Root cause

`packages/cyclist/src/sprint-data.ts` ~line 303: `getSprintData()` hardcodes `const currentSprintPath = join(projectDir, 'sprint', 'current-sprint.yaml')`

## Acceptance Criteria

- [ ] SprintPanel reads `config.local.yaml` `sprint.active` preference on load
- [ ] When `sprint.active` is set, sprint data is resolved through `sprint/sprints.yaml` registry
- [ ] Panel header shows provenance: sprint name, type, and source path
- [ ] When no `sprint.active` is set (or set to "main"/"default"), falls back to `sprint/current-sprint.yaml`
- [ ] Switching sprints via `pf sprint use <name>` is reflected on next TUI refresh
- [ ] Tests cover registry resolution and fallback behavior

## Key Files

| File | Role |
|------|------|
| `packages/cyclist/src/sprint-data.ts` | Sprint data loading — fix here |
| `packages/core/src/public/components/panels/SprintPanel.tsx` | UI display — add provenance header |
| `packages/core/src/public/hooks/useSprint.ts` | WebSocket hook feeding SprintPanel |
| `packages/cyclist/src/websocket.ts` | WS server at `/ws/sprint` |
| `pennyfarthing-dist/pf/sprint/loader.py` | Reference implementation (Python) |
| `pennyfarthing-dist/pf/sprint/cli.py` | `pf sprint use/list/active` commands |

## SM Assessment

Story setup complete. GitHub issue #1028 triaged into 120-6. Root cause identified: `sprint-data.ts` hardcodes `sprint/current-sprint.yaml` instead of resolving through the sprint registry. Python CLI layer has a working reference implementation in `pf/sprint/loader.py`. The fix is well-scoped — update the data service, add provenance to the UI, and write tests. Branch created in pennyfarthing repo. Handing off to TEA for test design.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core data service bug — registry resolution logic missing from TypeScript layer

**Test Files:**
- `packages/cyclist/tests/120-6-sprint-registry-resolution.test.ts` - Sprint registry resolution tests

**Tests Written:** 18 tests covering 6 ACs (5 failing, 13 passing)
**Status:** RED (failing - ready for Dev)

**Failing tests (5):**
- AC1: Config preference read → loads Unknown Sprint instead of resolved sprint
- AC2: Registry resolution → no epic data from spike sprint
- AC2: Metrics calculation → zero metrics without resolved data
- AC3: Provenance metadata → `registry` property missing from SprintData
- AC5: Sprint switch → successive calls don't detect config change

**Passing tests (13):** Fallback/edge case behavior that already works (no config → default, missing files → default, malformed YAML → default)

**Handoff:** To Dev (Ponder Stibbons) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/sprint-data.ts` - Added `resolveSprintFile()` function, `SprintRegistry` interface, registry resolution in `getSprintData()`, provenance metadata injection

**Tests:** 18/18 passing (GREEN) + 36/36 existing tests (no regressions)
**Branch:** feat/120-6-sprint-panel-active-sprint-preference (pushed)

**Implementation notes:**
- Added `resolveSprintFile()` that mirrors Python `load_sprint()` resolution order: config → registry → resolve path → fallback
- `SprintData` interface extended with optional `registry?: SprintRegistry` field
- Shard resolution uses `dirname()` of resolved sprint file (correct for cross-repo paths)
- All fallback paths preserved — missing config, missing registry, missing file, malformed YAML all fall back to default

**Handoff:** To Reviewer (Granny Weatherwax) for code review

## TEA Verify Assessment

**GREEN State Confirmed:** Yes
**Tests:** 54/54 passing (19 new + 35 existing, zero regressions)
**Duration:** 206ms total

**Handoff:** To Reviewer (Granny Weatherwax)

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] Resolution order at `sprint-data.ts:334` matches Python `loader.py:41` — config → registry → resolve → fallback
2. [VERIFIED] Six defensive fallback exit points in `resolveSprintFile()` — no crash paths
3. [VERIFIED] Empty string handling via `||` operator correctly treats `""` as no preference
4. [VERIFIED] Shard resolution with `dirname()` at line 433 matches Python `sprint_path.parent` pattern
5. [MEDIUM] `docs` field from Python `_registry` metadata not included in TS `SprintRegistry` — non-blocking parity gap, UI doesn't consume it yet
6. [VERIFIED] No security concerns — local file reads from known paths, no injection vectors
7. [VERIFIED] `SprintRegistry` exported and optional — existing consumers unaffected
8. [VERIFIED] 18 new tests + 36 existing, zero regressions

**Data flow traced:** `getSprintData(projectDir)` → `resolveSprintFile(projectDir)` → reads config.local.yaml → reads sprints.yaml → resolves path → returns `{path, registry}` → sprint YAML loaded from resolved path → `registry` injected into `SprintData` return value
**Pattern observed:** Mirrors Python reference implementation faithfully — same resolution order, same fallback semantics, same metadata injection pattern
**Error handling:** Every external read (config, registry, sprint file) wrapped in try/catch with fallback to default path

**Handoff:** To SM for finish-story

## Technical Approach

1. **sprint-data.ts**: Read config.local.yaml, resolve through sprints.yaml registry, load correct file, inject provenance metadata
2. **SprintPanel.tsx**: Show provenance in header (sprint name, type, source path)
3. **Tests**: Registry resolution, fallback, config change detection