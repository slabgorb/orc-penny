# Story 120-6 Session

**Story ID:** 120-6
**Jira Key:** PROJ-15411
**Title:** Sprint panel ignores active sprint preference from sprint registry
**Type:** bug
**Points:** 5
**Priority:** p1
**Status:** in_progress
**Workflow:** tdd
**Phase:** finish
**Assignee:** slabgorb@gmail.com
**Repos:** pennyfarthing

## Description

The TUI Sprint panel always loads sprint/current-sprint.yaml instead of respecting the user's active sprint set via `pf sprint use <name>`. The sprint registry (sprint/sprints.yaml) and config.local.yaml sprint.active preference work correctly for CLI agents but the TUI does not read them. Fix the SprintPanel to resolve the active sprint through the registry, display the correct sprint data, and show provenance (sprint name, type, source path) in the panel header.

## Refs
- GitHub: slabgorb/pennyfarthing#1028

## Acceptance Criteria

### AC1: TUI loads selected sprint
- **Given** `config.local.yaml` has `sprint.active` set to a named sprint
- **When** the TUI Sprint panel loads or refreshes
- **Then** it displays epics, stories, and progress from the selected sprint file

### AC2: Provenance indicator shows active sprint identity
- **Given** a non-default sprint is active (focus switched via registry)
- **When** the Sprint panel renders
- **Then** the header shows the sprint **name** and **type** as a visual indicator
- **Given** the default sprint is active (the 90% case)
- **When** the Sprint panel renders
- **Then** no provenance indicator is shown — it would be noise

**Visual spec — React (`SprintPanel.tsx`):**
```
┌─────────────────────────────────────────────────┐
│ Sprint Progress          [spike] ocsf-rs1       │
│ ════════════════════════════════════════════════ │
│                                                 │
│  Epic 3: OCSF Log Sources    ████████░░  80%    │
│  ...                                            │
└─────────────────────────────────────────────────┘
```
- Badge for type (`[spike]`, `[research]`, `[project]`), text for name
- Layout: flex row, justify-between, align-center, gap
- Only renders when `data.registry` is present and `is_default` is false

**Visual spec — Python Rich TUI (`sprint_panel.py`):**
```
Sprint Progress [spike:ocsf-rs1]
════════════════════════════════
```
- Appended to header as `[type:name]`
- Use `.get('type', '')` for dict access (never bare `registry['type']`)
- Escape values with `rich.markup.escape()` before `Text.from_markup()` — brackets in sprint names would break Rich rendering

### AC3: Default fallback works
- **Given** no `sprint.active` preference OR `sprint.active` is `"default"`
- **When** the Sprint panel loads
- **Then** it loads `sprint/current-sprint.yaml` as before (the 90% case)
- **And** no provenance indicator is shown — default sprint needs no label

### AC4: Switching focus updates the TUI
- **Given** user runs `pf sprint use <other-name>` while TUI is running
- **When** `config.local.yaml` changes
- **Then** the TUI Sprint panel updates to show the newly selected sprint
- **Responsiveness target:** The WS server file watcher triggers on YAML changes. `getSprintData()` must re-read config on each call (no caching of resolved path). Delay up to the file watcher polling interval is acceptable for now.

## Technical Approach

The work is split into two phases:

### Phase 1: Data Layer (ALREADY DONE in PR #1044)
- `packages/cyclist/src/sprint-data.ts`: `resolveSprintFile()` function that mirrors Python `pf/sprint/loader.py` resolution order
  - Reads `config.local.yaml` for sprint.active preference
  - Looks up sprint in `sprints.yaml` registry
  - Resolves the target sprint file path
  - Falls back to `sprint/current-sprint.yaml` if no preference
  - Returns `{path, registry}` tuple with metadata
- `SprintData` interface extended with optional `registry?: SprintRegistry` field
- 18 new tests covering all resolution paths

### Phase 2: Display Layer (THIS STORY - REMAINING WORK)

#### Files to modify:
1. **`packages/core/src/public/hooks/useSprint.ts`** — Add `SprintRegistry` type definition to match backend shape
   - Type: `{name, type, description, file, isDefault}`
   - Injected into `SprintData` over WebSocket

2. **`packages/core/src/public/components/panels/SprintPanel.tsx`** — React UI provenance rendering
   - Add section below title when `data.registry` present and `!registry.isDefault`
   - Render badge (`[spike]`, `[research]`, etc.) + sprint name
   - Use flex row layout with justify-between alignment

3. **`pennyfarthing-dist/pf/bikerack/sprint_panel.py`** — Python TUI provenance rendering
   - Modify header at line ~276 to append provenance indicator when registry present
   - Use `.get('type', '')` and `.get('name', '')` for safe dict access
   - Escape values with `rich.markup.escape()` before `Text.from_markup()`

4. **Tests** — Add render tests
   - React: mount `SprintPanel` with mock `data.registry`, assert provenance renders
   - React: mount without registry, assert no provenance section
   - Python: test header output with/without registry metadata
   - Python: test escaped bracket characters in sprint names
   - Integration: file watcher test — write config, call, change config, call again, assert different results

#### WebSocket Payload Shape
The `registry` metadata is injected into `SprintData` by `resolveSprintFile()`. Over `/ws/sprint` WebSocket:
```typescript
interface SprintRegistry {
  name: string;       // "ocsf-rs1"
  type: string;       // "spike"
  description: string; // "OCSF log source research spike"
  file: string;       // Resolved path (for debugging, not display)
  isDefault: boolean; // false when focus-switched
}

// In SprintData:
{
  sprint: { ... },
  metrics: { ... },
  registry?: SprintRegistry  // Present when resolved through registry; absent = default
}
```

## Key Files to Review/Modify

| File | Purpose | Phase |
|------|---------|-------|
| `pennyfarthing-dist/pf/sprint/loader.py` | Python reference implementation (working) | Reference |
| `packages/cyclist/src/sprint-data.ts` | Sprint data loading — `resolveSprintFile()` added | Phase 1 (done) |
| `packages/cyclist/tests/120-6-sprint-registry-resolution.test.ts` | 18 tests for resolution logic | Phase 1 (done) |
| `packages/core/src/public/components/panels/SprintPanel.tsx` | React UI — add provenance indicator | Phase 2 |
| `packages/core/src/public/hooks/useSprint.ts` | WS hook — add `SprintRegistry` type | Phase 2 |
| `pennyfarthing-dist/pf/bikerack/sprint_panel.py` | Python TUI — add provenance to header | Phase 2 |

## Branch

Created: `fix/120-6-fix-sprint-panel-active-sprint-preference`

## TEA Assessment

**Tests Required:** Yes
**Reason:** Bug fix with display layer changes across React and Python TUI

**Test Files:**
- `packages/cyclist/tests/120-6-sprint-panel-provenance.test.tsx` - React provenance rendering (11 tests)
- `pennyfarthing-dist/pf/tests/test_sprint_panel_provenance.py` - Python TUI provenance rendering (9 tests)

**Tests Written:** 20 tests covering all 4 ACs
**Status:** RED (failing — ready for Dev)

**React results:** 8 failed, 3 passed (assertion failures on missing `sprint-provenance` testid)
**Python results:** 6 failed, 3 passed (assertion failures on missing `[type:name]` in header)

**Note on React test runner:** Tests MUST be run from `packages/cyclist/` directory (not monorepo root) due to Vite 7 hardlink inode canonicalization. The `atAliasPlugin` in `vitest.config.ts` handles `@/` alias resolution but only loads when vitest config is in scope. Command: `cd packages/cyclist && npx vitest run tests/120-6-sprint-panel-provenance.test.tsx`

**Handoff:** To Dev (Major Winchester) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/public/hooks/useSprint.ts` - Added `SprintRegistry` type, optional `registry` field on `SprintData`, fixed merge logic to clear registry on absence
- `packages/core/src/public/components/panels/SprintPanel.tsx` - Added provenance indicator (badge + name) when non-default sprint active
- `pennyfarthing-dist/pf/bikerack/sprint_panel.py` - Appended `[type:name]` provenance to header for non-default sprints with safe `.get()` access

**Tests:** 20/20 passing (GREEN) — 11 React, 9 Python
**Branch:** fix/120-6-fix-sprint-panel-active-sprint-preference (pushed)

**Handoff:** To Reviewer (Colonel Potter) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** WS payload → useSprint hook → SprintData.registry → SprintPanel conditional render (safe — React escapes, Python uses Text.append)
**Pattern observed:** Explicit registry override in merge at useSprint.ts:126 prevents stale state — good defensive coding
**Error handling:** Safe optional chaining (React) and .get() defaults (Python) throughout — no crash paths on missing/empty data

| Severity | Issue | Location | Note |
|----------|-------|----------|------|
| [LOW] | Unused `type SprintRegistry` import | SprintPanel.tsx:17 | Stripped at compile time, lint noise only |

**Handoff:** To SM for finish-story