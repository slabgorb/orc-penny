# Context: Story 120-6 — TUI Sprint panel does not resolve active sprint context

**GitHub Issue:** 1898andCo/pennyfarthing#1028
**Points:** 5 (resized from 3)
**Consolidation proposal:** `sprint/planning/sprint-state-consolidation-proposal.md`

## Problem

The TUI SprintPanel hardcodes `sprint/current-sprint.yaml` as the data source. When a user switches focus to a named sprint via `pf sprint use <name>`, CLI agents correctly load the selected sprint but the TUI continues showing the default.

This is a trust problem. The TUI is the team's shared view of reality — when it shows the wrong sprint, every decision made while looking at it is contaminated.

## The Planning Model

**The 90%:** The orchestrator centralizes all planning. `sprint/current-sprint.yaml` is the default source of truth. No registry, no indirection. Most of the time, one sprint, one view.

**The 10%:** A person or sub-team splits off to focus on a spike, feature sprint, or PoC. These have their own sprint files, context roots, and session directories. The sprint registry (`sprints.yaml`) exists for this case. It's the important 10% — when someone is focused on a spike, their tools must reflect that focus.

## Acceptance Criteria

### AC1: TUI loads selected sprint

- **Given** `config.local.yaml` has `sprint.active` set to a named sprint
- **When** the TUI Sprint panel loads or refreshes
- **Then** it displays epics, stories, and progress from the selected sprint file
- **Status:** Not done. Prior branch has resolution algorithm; needs revision for `SprintContext`.

### AC2: Provenance indicator shows active sprint identity

- **Given** a non-default sprint is active (focus switched via registry)
- **When** the Sprint panel renders
- **Then** the header shows the sprint **name** and **type** as a visual indicator
- **Given** the default sprint is active (the 90% case)
- **When** the Sprint panel renders
- **Then** no provenance indicator is shown — it would be noise
- **Status:** Not done. PR #1044 attempted this and was rejected (see post-mortem).

### AC3: Default fallback works

- **Given** no `sprint.active` preference OR `sprint.active` is `"default"`
- **When** the Sprint panel loads
- **Then** it loads `sprint/current-sprint.yaml` as before (the 90% case)
- **And** no provenance indicator is shown — default sprint needs no label
- **Status:** Not done. Prior branch has fallback logic; needs `SprintContext` with `is_default: true` instead of "registry absent means default."

### AC4: Switching focus updates the TUI

- **Given** user runs `pf sprint use <other-name>` while TUI is running
- **When** `config.local.yaml` changes
- **Then** the TUI Sprint panel updates to show the newly selected sprint
- **Responsiveness target:** Delay up to the file watcher polling interval is acceptable for now.
- **Status:** Not done. Prior branch re-reads config per call but no integration test exists.

## Design Decisions

| # | Decision | Choice | Rationale |
|---|----------|--------|-----------|
| 1 | Split into multiple stories? | **No — single story, 5 pts** | One issue, one story. Points reflect actual scope. |
| 2 | What does "source path" mean in UI? | **Drop from AC, show name + type only** | Name + type answer "which sprint am I on?" Source path deferred to settings toggle. |
| 3 | Live-switching in scope? | **Yes** | OP explicitly described switch-back behavior. Verify existing polling handles it; add test. |
| 4 | `contextRoot`/`sessionRoot` display? | **Keep in type, don't display** | Future designs will consume these fields. Not for panel display. |
| 5 | Optional vs always-present context? | **Always present with `isDefault` flag** | Consumers check `context.isDefault` instead of testing for presence of optional field. Cleaner contract. |
| 6 | `SprintRegistry` vs `SprintContext`? | **`SprintContext` — richer object** | Bundles file path, context root, session root, repos, name, type, `isDefault`. One resolution function for all consumers. |

## SprintContext Design (Move 1 from consolidation proposal)

```python
@dataclass
class SprintContext:
    name: str           # "main", "ocsf-rs1"
    type: str           # "project", "spike", "research"
    sprint_file: Path   # Resolved absolute path
    context_root: Path  # Story context .md files
    session_root: Path  # .session/ files
    repos: list[str]    # Repos this sprint covers
    description: str    # Human-readable
    is_default: bool    # True = main sprint (90%), False = focus-switched (10%)
```

**Default case (90%):** No preference set → resolves to orchestrator's `sprint/current-sprint.yaml`, `sprint/context/`, `.session/`, `is_default=True`. No registry lookup.

**Focus case (10%):** Preference set → resolves through `sprints.yaml` to scoped sprint files, `is_default=False`. Visible in UI as provenance indicator.

**Resolution:** One function `resolve_sprint_context(project_root) -> SprintContext`, called by all consumers. Replaces scattered "read config, look up registry, resolve path" logic.

## WebSocket Payload

```typescript
interface SprintContext {
  name: string;        // "main", "ocsf-rs1"
  type: string;        // "project", "spike", "research"
  description: string; // Human-readable
  file: string;        // Resolved path (debugging, not display)
  isDefault: boolean;  // true = main sprint, false = focus-switched
}

// Always present in SprintData:
{ sprint: { ... }, metrics: { ... }, context: SprintContext }
```

## Visual Specs

### React (`SprintPanel.tsx`)
```
┌─────────────────────────────────────────────────┐
│ Sprint Progress          [spike] ocsf-rs1       │
│ ════════════════════════════════════════════════ │
│  Epic 3: OCSF Log Sources    ████████░░  80%    │
└─────────────────────────────────────────────────┘
```
- Badge for type, text for name. Flex row, justify-between, align-center, gap.
- Only renders when `!context.isDefault`.

### Python Rich TUI (`sprint_panel.py`)
```
Sprint Progress [spike:ocsf-rs1]
════════════════════════════════
```
- `.get('type', '')` for dict access. `rich.markup.escape()` before markup rendering.

### Error state
- Resolution failure → silent fallback to `sprint/current-sprint.yaml`, log warning to debug panel, no provenance indicator shown.

## Root Cause

`packages/cyclist/src/sprint-data.ts` line ~303: `getSprintData()` hardcodes `const currentSprintPath = join(projectDir, 'sprint', 'current-sprint.yaml')`.

## Key Files

| File | Role | Status |
|------|------|--------|
| `packages/cyclist/src/sprint-data.ts` | Sprint data loading — needs `SprintContext` resolution | Needs revision |
| `packages/cyclist/tests/120-6-sprint-registry-resolution.test.ts` | 18 tests for resolution logic | Scenarios valid, assertions need shape updates |
| `packages/core/src/public/components/panels/SprintPanel.tsx` | React UI — add provenance indicator | Not started |
| `packages/core/src/public/hooks/useSprint.ts` | WS hook — add `SprintContext` type | Not started |
| `pennyfarthing-dist/pf/bikerack/sprint_panel.py` | Python TUI — add provenance to header | Not started |
| `packages/cyclist/src/websocket.ts` | WS server at `/ws/sprint` | No changes needed |
| `pennyfarthing-dist/pf/sprint/loader.py` | Python reference implementation | Reference only |

## Implementation Tasks

| Task | AC | Notes |
|------|----|-------|
| Revise `resolveSprintFile()` to return `SprintContext` | AC1, AC3 | Change return from `{path, registry?}` to full `SprintContext` with `isDefault`. Always return context. |
| Update `SprintData` interface | AC1 | Replace `registry?: SprintRegistry` with `context: SprintContext` |
| Update 18 existing tests for new shape | AC1, AC3 | Scenarios valid. Update assertions to expect `SprintContext` with `isDefault`. |
| Add `SprintContext` type to `useSprint.ts` | AC2 | Type definition for React side |
| Render provenance in `SprintPanel.tsx` | AC2 | See visual spec. Only when `!context.isDefault`. |
| Render provenance in `sprint_panel.py` | AC2 | See visual spec. `.get()` + `rich.markup.escape()`. |
| Render tests for React provenance | AC2 | Non-default context → provenance shows. Default context → no provenance. |
| Render tests for Python provenance | AC2 | Same coverage. Test escaped bracket chars in sprint names. |
| Add live-switching integration test | AC4 | Write config, call, change config, call again, assert different `SprintContext`. |

## Prior Work (branch: `feat/120-6-sprint-panel-active-sprint-preference`)

PR #1044 was closed without merge. **No code from this story has landed on `develop`.**

**Salvageable:**
- Resolution algorithm (config → registry → path → fallback) — correct approach, return shape needs updating
- 18 tests — scenarios valid, assertions need `SprintContext` shape updates
- Defensive fallback pattern — 6 exit points, every external read in try/catch

**Needs revision:**
- `SprintRegistry` → `SprintContext` (add `isDefault`, `contextRoot`, `sessionRoot`, `repos`)
- Optional `registry?` → always-present `context` with `isDefault` flag

**PR #1044 post-mortem:**

| # | Issue | How to avoid |
|---|-------|--------------|
| 1 | No render tests — display layer shipped untested | Write render tests for both React and Python before merging |
| 2 | Python bare dict access — `registry['type']` | Use `.get('type', '')` |
| 3 | Rich markup injection — unescaped f-string in `Text.from_markup()` | Use `rich.markup.escape()` |
| 4 | No CSS/layout — bare `<section>` | Follow visual spec |

## Sprint Registry System

1. `sprint/sprints.yaml` — maps sprint names to file paths and metadata
2. `.pennyfarthing/config.local.yaml` → `sprint.active` — per-user preference (gitignored)
3. Python `pf/sprint/loader.py` → `load_sprint()` — reference implementation

Resolution order: config preference → registry lookup → resolve path → load YAML. Falls back to `sprint/current-sprint.yaml`.
