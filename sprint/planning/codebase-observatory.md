# Codebase Observatory — Debug Tools Expansion

**Author:** Bran Stark (Architect)
**Date:** 2026-02-06
**Status:** Design Complete — Handoff to PM for epic/story creation
**Repos:** pennyfarthing (Cyclist + pennyfarthing_scripts)

## Vision

Transform the Debug panel from a context/token display into a **Codebase Observatory** — an integrated suite of diagnostic tools that surface code health, detect quality issues, and help agents understand the codebase they're working in.

The panel itself becomes a lightweight launcher with a composite health gauge. Each tool opens a full-featured dialog for display and interactive tuning.

## Current State

| Component | Location | Lines |
|-----------|----------|-------|
| DebugPanel | `packages/cyclist/src/public/components/panels/DebugPanel.tsx` | 269 |
| HotspotsPanel | `packages/cyclist/src/public/components/panels/HotspotsPanel.tsx` | 365 |
| useHotspots hook | `packages/cyclist/src/public/hooks/useHotspots.ts` | 113 |
| Hotspots API | `packages/cyclist/src/api/hotspots.ts` | 59 |
| Hotspots Engine | `pennyfarthing_scripts/hotspots/analyze.py` | 473 |
| Hotspots CLI | `pennyfarthing_scripts/hotspots/cli.py` | 153 |
| Hotspots Models | `pennyfarthing_scripts/hotspots/models.py` | 61 |
| Dialog primitives | `packages/cyclist/src/public/components/ui/dialog.tsx` | 120 |
| ConfirmDialog | `packages/cyclist/src/public/components/ConfirmDialog.tsx` | 169 |
| Prime context | `packages/cyclist/src/prime.ts` | 370 |

## Changes

### 1. Debug Panel as Tool Launcher

**Remove** HotspotsPanel as a standalone dockview panel. **Merge** hotspot activation into the Debug panel alongside new tools.

The Debug panel keeps its existing context usage + token stats display at top, and gains a tool launcher row below:

```
+-- Debug Panel (sidebar) --------------------------------+
|  [Context Usage]  bar + tier + breakdown                |
|  [Token Stats]    input/output/cache/cost               |
|  --------------------------------------------------------|
|  Health: [=====-----] 62/100                            |
|  --------------------------------------------------------|
|  Tools:                                                  |
|  [Hotspots] [Dead Code] [Markers] [Agent Load]          |
|  [Complexity] [Dependencies]                             |
+---------------------------------------------------------+
```

Each button opens a dialog (see section 3).

**Files to change:**
- `DockviewWorkspace.tsx` — remove `HOTSPOTS` from `PANEL_INVENTORY`, `RIGHT_SIDEBAR_PANELS`, `PANEL_TITLES`
- `App.tsx` — remove HotspotsPanel registration
- `panels/index.ts` — remove HotspotsPanel export
- `DebugPanel.tsx` — add tool launcher buttons + health gauge

### 2. Hotspot Improvements

#### 2a. Skip orchestrator repos

In the orchestrator pattern, the orchestrator repo (sprint YAML, session files) is noise. `repos.yaml` already marks `type: orchestrator` vs `type: framework`.

**Backend:** `analyze_all_repos()` in `analyze.py` gains `skip_types: list[str] | None` parameter. When called from Cyclist API, default is `skip_types=["orchestrator"]`.

**CLI:** New `--skip-type` repeatable option in `cli.py`.

**API:** `api/hotspots.ts` passes `--skip-type orchestrator` by default. Dialog exposes "Include orchestrator" checkbox.

#### 2b. Filter non-code artifacts

Expand `DEFAULT_EXCLUDES` in `analyze.py`:

```python
DEFAULT_EXCLUDES = [
    # Existing
    "node_modules/*", "dist/*", "build/*",
    "*.lock", "*.min.js", "*.min.css", "*.map",
    "package-lock.json", "pnpm-lock.yaml",
    # Dotfiles and config
    ".gitignore", ".gitattributes", ".editorconfig",
    ".eslintrc*", ".prettierrc*", ".browserslistrc",
    "*.log", "*.tmp", "*.bak", "*.swp",
    # Generated
    "*.d.ts", "coverage/*", ".nyc_output/*", "*.snap",
    # Non-code assets
    "*.png", "*.jpg", "*.jpeg", "*.gif", "*.svg", "*.ico",
    "*.woff", "*.woff2", "*.ttf", "*.eot",
    # Config/CI
    "tsconfig*.json", ".github/*", "yarn.lock",
]
```

Additionally, the HotspotsDialog gains client-side filter toggles:
- "Code only" (default on) — positive filter for source extensions
- "Include config" toggle
- Custom exclude pattern text input

### 3. Dialog Architecture

All tools open as full-featured dialogs built on the existing Radix/shadcn `Dialog` primitives in `ui/dialog.tsx`.

**New shared component:** `ToolDialog.tsx`

```typescript
// components/dialogs/ToolDialog.tsx
interface ToolDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description?: string;
  children: React.ReactNode;
}
```

Uses `DialogContent` with `max-w-5xl` (wider than default `max-w-lg`) for table-heavy tools. Each tool gets its own dialog content component:

| Dialog | Content From | New? |
|--------|-------------|------|
| `HotspotsDialog.tsx` | Moved from HotspotsPanel + filter controls | Refactored |
| `DeadCodeDialog.tsx` | New dead code analysis | New |
| `CodeMarkersDialog.tsx` | New TODO/deprecation scanner | New |
| `AgentLoadDialog.tsx` | New agent context analyzer | New |
| `ComplexityDialog.tsx` | New complexity metrics | New |
| `DependenciesDialog.tsx` | New dependency staleness | New |

### 4. Tool: Code Markers (TODOs, FIXMEs, Deprecations)

Scans for TODO, FIXME, HACK, XXX comment markers and `@deprecated` annotations. Cross-references with git blame for age/author.

**Backend:** New Python module `pennyfarthing_scripts/codemarkers/`

```
codemarkers/
  __init__.py
  analyze.py    — grep + git blame + @deprecated detection
  models.py     — CodeMarker, DeprecationUsage dataclasses
  cli.py        — CLI interface
```

Core logic:
1. `grep -rn "TODO\|FIXME\|HACK\|XXX"` across source files
2. `git blame -L {line},{line}` each marker for age/author
3. For TypeScript: parse `@deprecated` JSDoc tags, find active callers via `ts-morph` or `tsc --noEmit` references
4. Score staleness: markers >90 days old flagged as stale

**API:** `GET /api/code-markers?repo=pennyfarthing`

**Dialog features:**
- Tabs: "TODOs" | "FIXMEs" | "Deprecated"
- Table: marker text, file:line, author, age (days), staleness badge
- Sort by age, file, author
- Filter by staleness threshold
- Summary stats: total markers, stale count, deprecated-but-used count

### 5. Tool: Dead Code Detection

Two layers of analysis finding unused/orphaned code.

**Layer 1: Git-based stale file detection**
- `git ls-files` → all tracked files
- `git log --name-only --since=N days` → recently changed files
- Difference = never-touched files in window
- Filter to source files only

**Layer 2: Unused export detection (TypeScript)**
- Run `ts-prune` (or equivalent tsc analysis) to find exported symbols with no importers
- Output: symbol name, file, export type

**Backend:** New Python module `pennyfarthing_scripts/deadcode/`

```
deadcode/
  __init__.py
  analyze.py    — git ls-files diff + ts-prune integration
  models.py     — StaleFile, UnusedExport dataclasses
  cli.py        — CLI interface
```

**API:** `GET /api/dead-code?days=180&repo=pennyfarthing`

**Dialog features:**
- Tabs: "Stale Files" | "Unused Exports"
- Stale files: path, last modified date, days since last change, confidence badge
- Unused exports: symbol, file:line, export type (function/class/const/type)
- Diagnostic only — does NOT auto-delete

### 6. Tool: Agent Load Analyzer

Runs `getPrimeContextJson()` for all agents at FULL tier, shows per-component token breakdown, enables sidecar pruning.

**Backend:** New API `GET /api/agent-load`

```typescript
// api/agent-load.ts
const AGENTS = ['sm', 'tea', 'dev', 'reviewer', 'architect', 'pm',
                'tech-writer', 'ux-designer', 'devops', 'orchestrator'];

router.get('/', (req, res) => {
  const results = AGENTS.map(agent => {
    const output = getPrimeContextJson(agent, projectDir, 'FULL');
    return {
      agent,
      totalTokens: output?.totalTokens ?? 0,
      components: output?.components ?? [],
      tokenCounts: output?.tokenCounts ?? {},
    };
  });
  res.json({ agents: results });
});
```

**Sidecar pruning:** `POST /api/agent-load/prune-sidecar`
- Body: `{ agent: "dev", sidecar: "gotchas.md" }`
- Resets sidecar to its header template (preserves the `# Title` and `> description` lines, clears content below the `---` separator)
- Requires confirmation dialog before execution

**Dialog features:**
- Bar chart or ranked table: agent name, total FULL-tier tokens
- Expand agent → component breakdown (agent_definition, persona, behavior_guide, sidecars, sprint_context)
- Sidecar section: list files with token counts
- "View" button → expandable content preview
- "Clear" button → confirmation → prune via POST API

### 7. Tool: Complexity Metrics

Static analysis of code complexity via ESLint rules and file/function length analysis.

**Backend:** New Python module or Node script in `pennyfarthing_scripts/complexity/`

Core metrics:
- File length (lines)
- Function length (lines per function)
- Cyclomatic complexity (via ESLint `complexity` rule or `escomplex`)
- Nesting depth

**API:** `GET /api/complexity?repo=pennyfarthing`

**Dialog features:**
- Table: file, longest function, avg complexity, max nesting
- Sort by any column
- Threshold highlighting: complexity >10 yellow, >20 red

### 8. Tool: Dependency Staleness

Track outdated npm packages and known vulnerabilities.

**Backend:** Wraps `npm outdated --json` and `npm audit --json`.

**API:** `GET /api/dependencies?repo=pennyfarthing`

**Dialog features:**
- Table: package, current, wanted, latest, type (dependencies/devDependencies)
- Security section: advisory count by severity
- Age indicator: how many major versions behind

### 9. Composite Health Score

A single 0-100 score displayed as a gauge in the Debug panel header. Computed from weighted dimensions:

| Dimension | Signal | Weight | Source |
|-----------|--------|--------|--------|
| Churn concentration | Avg hotspot score of top-10 files | 15% | Hotspots tool |
| Dead code ratio | Stale files / total tracked files | 10% | Dead code tool |
| TODO/FIXME density | Markers per KLOC | 15% | Code markers tool |
| Deprecation debt | Deprecated-but-used call count | 10% | Code markers tool |
| Complexity | Files exceeding complexity threshold | 15% | Complexity tool |
| Dependency freshness | % of deps at latest major | 10% | Dependencies tool |
| Agent context efficiency | Avg FULL-tier tokens (lower = better) | 10% | Agent load tool |
| Test coverage gaps | Changed files without test files | 15% | Hotspots + heuristic |

**API:** `GET /api/health-score` — runs lightweight versions of each analysis, caches result for 5 minutes.

The score itself is a derived metric. Each tool contributes its piece when run. The health score recalculates from cached tool results, NOT by re-running all tools.

### 10. Future Enhancement Ideas (Not in first cut)

These emerged from brainstorming and should be captured for later consideration:

- **Ambient contextual warnings** — when agents work on a file, proactively surface its health data in conversation
- **Quality gates in workflow** — health diff before/after a story, shown to Reviewer
- **Snapshot comparisons** — temporal health data stored per-sprint for trend analysis
- **Sparkline trends** — tiny inline charts next to each metric in the Debug panel
- **File health badges** — colored dots in Changed panel per-file health
- **Documentation drift scanner** — stale JSDoc params, dead README references
- **Skill staleness detection** — skills referencing paths that no longer exist
- **CLAUDE.md freshness score** — project docs vs. code change recency
- **Duplicate context detection** — find overlapping content across sidecars/guides/CLAUDE.md
- **Import graph visualization** — circular deps, orphaned clusters

## File Impact Summary

| Area | New Files | Modified Files |
|------|-----------|----------------|
| Dialogs | `ToolDialog.tsx`, `HotspotsDialog.tsx`, `DeadCodeDialog.tsx`, `CodeMarkersDialog.tsx`, `AgentLoadDialog.tsx`, `ComplexityDialog.tsx`, `DependenciesDialog.tsx` | — |
| Panel | — | `DebugPanel.tsx`, `DockviewWorkspace.tsx`, `App.tsx`, `panels/index.ts` |
| Hooks | `useDeadCode.ts`, `useCodeMarkers.ts`, `useAgentLoad.ts`, `useComplexity.ts`, `useDependencies.ts`, `useHealthScore.ts` | `useHotspots.ts` |
| API | `api/dead-code.ts`, `api/code-markers.ts`, `api/agent-load.ts`, `api/complexity.ts`, `api/dependencies.ts`, `api/health-score.ts` | `api/hotspots.ts`, `server.ts` |
| Python | `pennyfarthing_scripts/codemarkers/`, `pennyfarthing_scripts/deadcode/`, `pennyfarthing_scripts/complexity/` | `hotspots/analyze.py`, `hotspots/cli.py` |

## Suggested Epic Structure

**Initiative:** Codebase Observatory

**Epic 1: Dialog Infrastructure + Hotspot Refactor** (~8 pts)
- ToolDialog shared component
- Migrate HotspotsPanel into HotspotsDialog
- Remove Hotspots from panel inventory
- Add tool launcher row to DebugPanel
- Hotspot: skip orchestrator repos
- Hotspot: expand artifact exclusions + client-side filters

**Epic 2: Code Markers Tool** (~5 pts)
- Python `codemarkers` module (grep + git blame)
- `@deprecated` detection and caller cross-reference
- Express API endpoint
- React hook + dialog

**Epic 3: Dead Code Detection** (~5 pts)
- Python `deadcode` module (git stale files + ts-prune)
- Express API endpoint
- React hook + dialog

**Epic 4: Agent Load Analyzer** (~5 pts)
- Express API (prime JSON for all agents)
- Sidecar pruning API
- React hook + dialog with sidecar viewer/pruner

**Epic 5: Complexity + Dependencies** (~5 pts)
- Complexity metrics module (ESLint/escomplex wrapper)
- Dependency staleness (npm outdated/audit wrapper)
- Express APIs + React hooks + dialogs

**Epic 6: Composite Health Score** (~5 pts)
- Health score calculation from cached tool results
- Radial gauge component in Debug panel header
- Health score API with caching

**Total: ~33 points across 6 epics**

## Implementation Note: Python-First

All backend analysis tools should be implemented in Python under `pennyfarthing_scripts/`,
following the established pattern from `hotspots/`. This includes complexity metrics and
dependency staleness — use Python wrappers around `eslint --format json` and
`npm outdated --json` rather than Node.js API modules. Express API routes in Cyclist
remain TypeScript but are thin wrappers that shell out to Python.

## Handoff

This document is ready for PM to decompose into properly sized stories in `future.yaml`. The epic structure above is a suggestion — PM should adjust sizing and priority based on sprint capacity and strategic value.
