# Epic 83: Complexity + Dependencies Tools

## Overview

Two lightweight diagnostic tools surfaced through the same Python-backend / Express-API / React-dialog stack used by Hotspots. **Complexity** performs static analysis (cyclomatic complexity, function length, nesting depth) by wrapping eslint or escomplex. **Dependencies** aggregates staleness and security data by wrapping `npm outdated --json` and `npm audit --json`. Both backends live in `pennyfarthing_scripts/`, with Express routes and React hooks/dialogs in Cyclist.

**Prior work:** Epic 82 built the Hotspots tool end-to-end (Python module, Express API, React panel). This epic replicates that pattern for two new tools.

## Background

### The Pattern

Pennyfarthing's diagnostic tools follow a consistent three-layer architecture established by the Hotspots feature:

1. **Python backend** (`pennyfarthing_scripts/<tool>/`) -- async subprocess wrappers around CLI tools, dataclass models following ADR-0008 `{success, data?, error?}`, Click CLI, JSON formatters. Invoked via `python3 -m pennyfarthing_scripts.<tool>`.
2. **Express API** (`packages/cyclist/src/api/<tool>.ts`) -- thin router that shells out to the Python module with `execFile('python3', ['-m', 'pennyfarthing_scripts.<tool>', ...])`, parses JSON stdout, returns result. Mounted in `server.ts` via `app.use('/api/<tool>', createRouter(getProjectDir))`.
3. **React frontend** (`packages/cyclist/src/public/hooks/use<Tool>.ts` + panel/dialog) -- `useState`/`useCallback` hook wrapping `fetch('/api/<tool>')` with abort controller, plus a sortable table component using shadcn `Button`, `Badge`, `Tooltip`, `Skeleton`.

### Why Two Separate Modules

Complexity and Dependencies are distinct concerns with different underlying tools, different data shapes, and different user workflows. Keeping them as separate `pennyfarthing_scripts/` modules follows the existing pattern (hotspots, brownfield, preflight are all separate). They share an API route prefix and a combined React dialog only at the UI layer (story 83-3).

### Tool Availability

- **ESLint** is already a devDependency of the monorepo (`eslint@^9.39.2` in `pennyfarthing/package.json`). The flat config at `pennyfarthing/eslint.config.mjs` uses `typescript-eslint`. The complexity module can leverage `eslint --format json` or use `escomplex` as a standalone alternative.
- **npm** is always available in the Node.js environment. `npm outdated --json` and `npm audit --json` require no additional dependencies.

## Technical Architecture

### Component Map

```
Complexity Tool
  pennyfarthing_scripts/complexity/
    ├── analyze.py         # async subprocess: eslint --format json or escomplex
    ├── models.py          # FileComplexity, ComplexityResult dataclasses
    ├── cli.py             # Click CLI: pf complexity analyze
    ├── formatters.py      # table/json/csv output
    ├── __init__.py        # public API exports
    └── __main__.py        # python -m pennyfarthing_scripts.complexity

Dependencies Tool
  pennyfarthing_scripts/dependencies/
    ├── analyze.py         # async subprocess: npm outdated --json, npm audit --json
    ├── models.py          # OutdatedPackage, SecurityAdvisory, DependencyResult
    ├── cli.py             # Click CLI: pf dependencies check
    ├── formatters.py      # table/json/csv output
    ├── __init__.py        # public API exports
    └── __main__.py        # python -m pennyfarthing_scripts.dependencies

Cyclist Express APIs
  packages/cyclist/src/api/
    ├── complexity.ts      # GET /api/complexity  → python3 -m pennyfarthing_scripts.complexity
    └── dependencies.ts    # GET /api/dependencies → python3 -m pennyfarthing_scripts.dependencies

Cyclist React Frontend
  packages/cyclist/src/public/
    ├── hooks/useComplexity.ts
    ├── hooks/useDependencies.ts
    └── components/panels/  (or dialogs — TBD by story 83-3)
        ├── ComplexityDialog.tsx   # sortable table with threshold highlighting
        └── DependenciesDialog.tsx # sortable table with severity badges
```

### Key Files (Existing — Reference Implementations)

| File | Lines | Purpose |
|------|-------|---------|
| `pennyfarthing_scripts/hotspots/analyze.py` | 472 | Async subprocess pattern, `_run_git_command()`, result aggregation |
| `pennyfarthing_scripts/hotspots/models.py` | 60 | ADR-0008 dataclass pattern: `success`, `error`, typed fields |
| `pennyfarthing_scripts/hotspots/cli.py` | 152 | Click CLI with shared options decorator, `asyncio.run()` bridge |
| `pennyfarthing_scripts/hotspots/formatters.py` | 109 | Table/JSON/CSV formatters, `export_json()` via `dataclasses.asdict()` |
| `pennyfarthing_scripts/hotspots/__init__.py` | 31 | Public API re-exports |
| `pennyfarthing_scripts/hotspots/__main__.py` | 6 | Module entry point |
| `pennyfarthing_scripts/common/config.py` | 92 | `get_project_root()`, `load_yaml_config()` |
| `packages/cyclist/src/api/hotspots.ts` | 59 | Express router: `execFile('python3', ...)` with JSON parse |
| `packages/cyclist/src/api/index.ts` | 39 | API module barrel exports |
| `packages/cyclist/src/server.ts` | 506 | Route mounting: `app.use('/api/hotspots', createHotspotsRouter(getProjectDir))` (line 138) |
| `packages/cyclist/src/public/hooks/useHotspots.ts` | 113 | React hook: fetch + abort controller + types |
| `packages/cyclist/src/public/components/panels/HotspotsPanel.tsx` | 365 | Sortable table, shadcn Badge/Button/Tooltip/Skeleton, time window controls |

### API Contracts

**GET /api/complexity?path=\<dir\>**
```json
// Response
{
  "success": true,
  "target_path": "/Users/dev/project/src",
  "file_count": 42,
  "files": [
    {
      "path": "src/server.ts",
      "total_lines": 506,
      "longest_function": 85,
      "avg_cyclomatic_complexity": 4.2,
      "max_nesting_depth": 5,
      "function_count": 18
    }
  ],
  "error": null
}
```

**GET /api/dependencies?path=\<dir\>**
```json
// Response
{
  "success": true,
  "target_path": "/Users/dev/project",
  "outdated": [
    {
      "package": "express",
      "current": "4.18.2",
      "wanted": "4.21.0",
      "latest": "5.0.1",
      "type": "dependencies",
      "severity": "minor"
    }
  ],
  "advisories": [
    {
      "package": "ws",
      "severity": "high",
      "title": "ReDoS vulnerability",
      "url": "https://github.com/advisories/GHSA-xxxx",
      "vulnerable_versions": "<8.17.1",
      "recommendation": "Upgrade to >=8.17.1"
    }
  ],
  "summary": {
    "total_outdated": 5,
    "major_updates": 1,
    "minor_updates": 3,
    "patch_updates": 1,
    "advisories_critical": 0,
    "advisories_high": 1,
    "advisories_moderate": 0,
    "advisories_low": 0
  },
  "error": null
}
```

### Express Router Pattern

Both new routers follow the `createHotspotsRouter` pattern in `packages/cyclist/src/api/hotspots.ts`:

```typescript
// Factory function receiving getProjectDir
export function createComplexityRouter(getProjectDir: () => string): Router {
  const router = Router();
  router.get('/', (req, res) => {
    const projectDir = getProjectDir();
    const args = ['-m', 'pennyfarthing_scripts.complexity', 'analyze', '--format', 'json'];
    // ... execFile('python3', args, { cwd, env: { PYTHONPATH }, timeout: 30000 })
  });
  return router;
}
```

### React Hook Pattern

Both hooks follow `useHotspots.ts` -- `useState` for data/loading/error, `useCallback` for fetch with `AbortController`, cleanup on unmount:

```typescript
export function useComplexity(options: UseComplexityOptions): UseComplexityReturn {
  // Same shape: { data, isLoading, error, refresh }
}
```

## Stories

| Story | Title | Points | Priority | Dependencies |
|-------|-------|--------|----------|--------------|
| 83-1 | Python complexity module | 2 | P0 | None |
| 83-2 | Python dependencies module | 2 | P0 | None |
| 83-3 | Complexity + Dependencies APIs + hooks + dialogs | 2 | P0 | 83-1, 83-2 |

### Story Notes

**83-1: Python complexity module**

New module at `pennyfarthing_scripts/complexity/` following the hotspots module structure (6 files: `__init__.py`, `__main__.py`, `analyze.py`, `models.py`, `cli.py`, `formatters.py`).

`analyze.py` wraps `eslint --format json` or `escomplex` via `asyncio.create_subprocess_exec` (same pattern as `hotspots/analyze.py` line 60). Parses JSON output to extract per-file metrics: longest function (line count), average cyclomatic complexity, max nesting depth, total lines. Since eslint is already installed (`eslint@^9.39.2` in root `package.json`, flat config at `eslint.config.mjs`), prefer eslint with a complexity rule configuration over adding escomplex as a new dependency.

Models follow ADR-0008 (same as `hotspots/models.py`):
- `FileComplexity`: path, total_lines, longest_function, avg_cyclomatic_complexity, max_nesting_depth, function_count
- `ComplexityResult`: success, target_path, file_count, files (list of FileComplexity), error

CLI uses Click with `_common_options` decorator (same pattern as `hotspots/cli.py` lines 31-41). Supports `--path`, `--format` (table/json/csv), `--top`, `--output`. Runnable as `python -m pennyfarthing_scripts.complexity analyze`.

**83-2: Python dependencies module**

New module at `pennyfarthing_scripts/dependencies/` with the same 6-file structure.

`analyze.py` runs two subprocess commands:
1. `npm outdated --json` -- parse into `OutdatedPackage` models (package, current, wanted, latest, type, staleness severity)
2. `npm audit --json` -- parse into `SecurityAdvisory` models (package, severity, title, url, vulnerable_versions, recommendation)

Both commands use `asyncio.create_subprocess_exec`. Note: `npm outdated` returns exit code 1 when outdated packages exist (not a failure), so the return code must be handled accordingly.

Models:
- `OutdatedPackage`: package, current, wanted, latest, type (dependencies/devDependencies), severity (major/minor/patch)
- `SecurityAdvisory`: package, severity (critical/high/moderate/low), title, url, vulnerable_versions, recommendation
- `DependencyResult`: success, target_path, outdated (list), advisories (list), summary (dict), error

**83-3: Complexity + Dependencies APIs + hooks + dialogs**

Three layers to wire up:

1. **Express APIs** -- Two new routers: `createComplexityRouter` and `createDependenciesRouter` in `packages/cyclist/src/api/`. Each follows the `hotspots.ts` pattern: factory function receiving `getProjectDir`, `execFile('python3', ...)` with 30s timeout, JSON parse of stdout. Register in `api/index.ts` (add exports) and mount in `server.ts` (add `app.use('/api/complexity', ...)` and `app.use('/api/dependencies', ...)` near the hotspots mount at line 138).

2. **React hooks** -- `useComplexity.ts` and `useDependencies.ts` in `packages/cyclist/src/public/hooks/`, following `useHotspots.ts` pattern: `useState` + `useCallback` + `AbortController`, returning `{ data, isLoading, error, refresh }`.

3. **React dialogs** -- Sortable tables following `HotspotsPanel.tsx` patterns (365 lines): `SortableHeader` component, `useMemo` for sorted data, shadcn `Badge` for threshold highlighting (e.g., red badge for cyclomatic complexity > 10, high/critical severity advisories), `Skeleton` for loading state, `Button` for actions. Complexity dialog highlights files exceeding configurable thresholds. Dependencies dialog shows outdated packages with version diff and security advisories with severity coloring.

## Constraints

- **ESLint availability**: The monorepo has `eslint@^9.39.2` with TypeScript support (`typescript-eslint`). The complexity module must locate the project's eslint binary (check `node_modules/.bin/eslint` relative to project root) and handle the case where eslint is not installed gracefully (return `{success: false, error: "eslint not found"}`).
- **ESLint configuration**: The existing `eslint.config.mjs` uses flat config format. The complexity module should use `--no-eslintrc` (or equivalent flat config flag) with an inline rule override to enable `complexity` reporting, avoiding interference with the project's own lint configuration.
- **npm command availability**: `npm` is assumed available in any Node.js environment. `npm outdated --json` returns exit code 1 when outdated packages exist -- this is not an error and must be handled. `npm audit --json` may return exit code > 0 for vulnerabilities found.
- **Performance**: Both `eslint` and `npm audit` can be slow on large projects. Use the same 30-second timeout as the hotspots API (`execFile` timeout option in the Express router). Consider `--max-warnings` or file glob limiting for eslint to avoid scanning the entire monorepo.
- **JSON output stability**: `npm outdated --json` and `npm audit --json` formats vary across npm versions. Target npm 9+ JSON schema. Include version detection or defensive parsing.
- **Python module pattern**: All new modules must be runnable as `python -m pennyfarthing_scripts.<module>` (requires `__main__.py`). Models must use `dataclasses` with `@dataclass` decorator and follow the `{success, ..., error}` result pattern from ADR-0008.
- **Cyclist integration**: New API routes must be exported from `packages/cyclist/src/api/index.ts` and mounted in `packages/cyclist/src/server.ts`. React hooks and dialogs live in `packages/cyclist/src/public/`.
