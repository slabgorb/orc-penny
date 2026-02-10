# Session: Story 93-6 (MSSCI-14635)

**Story:** Update Cyclist to use benchmark plugin instead of inline API
**Epic:** epic-93 — Extract Benchmarking System into @pennyfarthing/benchmark
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/story-93-6-cyclist-benchmark-plugin
**Jira:** MSSCI-14635

## Story Context

Replace the existing dynamic import in packages/cyclist/src/server.ts (initPennyfarthingFeatures) with the plugin discovery mechanism from 93-3.

Benchmark API router should register via plugin entry point from @pennyfarthing/benchmark rather than being built into Cyclist.

Verify: Cyclist starts cleanly with and without benchmark package.

## Acceptance Criteria

- Replace dynamic import in packages/cyclist/src/server.ts (initPennyfarthingFeatures) with plugin discovery mechanism
- Benchmark API router registers via plugin entry point from @pennyfarthing/benchmark
- Cyclist starts cleanly with benchmark package installed
- Cyclist starts cleanly without benchmark package installed

## Technical Notes

### Epic Context (epic-93)

Extract the JobFair benchmarking system from @pennyfarthing/core into a standalone optional npm package (@pennyfarthing/benchmark). Benchmarking is a meta-operation that most users don't need — evaluates persona effectiveness but isn't required for core agent workflows.

Key architectural finding: zero reverse dependencies from core. Cyclist already uses dynamic imports that gracefully degrade.

### Story Sequence & Dependencies

This story depends on:
- **93-1** (DONE) — Package shell created with TS modules
- **93-3** (prerequisite) — Plugin discovery mechanism for commands and skills from installed packages

When 93-3 is complete, the plugin discovery system will allow:
- @pennyfarthing/core to discover and register commands and skills from optional installed packages
- Benchmark API router to register automatically when @pennyfarthing/benchmark is installed
- Generic design (not benchmark-specific) for future package extractions

### Key Files to Modify

- `packages/cyclist/src/server.ts` — Update initPennyfarthingFeatures to use plugin discovery instead of dynamic import
- May need to update @pennyfarthing/benchmark plugin entry point (93-3 deliverable)

### References

- ADR-0020: benchmark-package-extraction.md — Full architectural rationale and file inventory
- Epic context: /Users/keithavery/Projects/pf-2/sprint/context/context-epic-93.md

## SM Assessment

**Setup:** Complete
**Jira:** MSSCI-14635 claimed and In Progress
**Branch:** feat/story-93-6-cyclist-benchmark-plugin created from develop
**Dependencies:** Story 93-3 (plugin discovery) merged via PR #778. Story 93-5 (core cleanup) merged via PR #777. Both prerequisites satisfied.
**Handoff:** To TEA for test design (TDD red phase)

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core infrastructure — plugin router loading must be provably correct, especially graceful degradation

**Test Files:**
- `packages/cyclist/tests/93-6-plugin-loader.test.ts` — 15 tests across 4 suites
- `packages/cyclist/src/plugin-loader.ts` — Stub with types and "not implemented" throw

**Tests Written:** 15 tests covering 4 ACs
**Status:** RED (all 15 failing — stub throws "not implemented")

### Test Coverage by AC

| AC | Tests | Suite |
|----|-------|-------|
| Plugin discovery integration in server.ts | 5 | initPluginRouters() |
| Benchmark router registers via plugin | 3 | Plugin with API router |
| Graceful degradation (failed imports, missing exports) | 4 | Graceful degradation |
| Cyclist starts without plugins | 3 | Cyclist starts without plugins |

### Design Decisions

1. **New `plugin-loader.ts` module** — Separates plugin loading from server.ts for testability. Server.ts calls `initPluginRouters(app, projectRoot)` during startup.

2. **`PluginLoadResult` return type** — Returns `{discovered, loaded, failed, routers[]}` so server.ts can log what was loaded. Each router result has `{mountPath, plugin, success, error?}`.

3. **Mocks `@pennyfarthing/core` discovery functions** — Tests mock `discoverPlugins()` and `getPluginRouters()` to control plugin discovery without needing real packages installed.

4. **Never throws** — `initPluginRouters()` must catch all errors including from `discoverPlugins()` itself, returning empty result. One broken plugin must not prevent others from loading.

5. **Observability via console.log** — Plugin discovery results should be logged for debugging.

### Implementation Notes for Dev

The stub is at `packages/cyclist/src/plugin-loader.ts` with:
- All types defined (`PluginRouterResult`, `PluginLoadResult`)
- Function signature defined with JSDoc
- Function throws "not implemented"

Key implementation steps:
1. Import `discoverPlugins`, `getPluginRouters` from `@pennyfarthing/core`
2. Call `discoverPlugins(projectRoot)` to find plugins
3. Call `getPluginRouters(plugins)` to get router specs
4. For each router: `await import(modulePath)` → call `mod[exportName]()` → `app.use(mountPath, router)`
5. Wrap everything in try/catch, return result object
6. Add `api` field to `packages/benchmark/package.json` manifest
7. Call `initPluginRouters(app, getProjectDir())` from `server.ts`

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/plugin-loader.ts` — Full implementation of `initPluginRouters()` with dynamic import, graceful degradation, and observability logging
- `packages/cyclist/src/server.ts` — Import and call `initPluginRouters(app, projectDir)` during async startup
- `packages/benchmark/package.json` — Add `pennyfarthing.api` field for router auto-discovery

**Tests:** 15/15 passing (GREEN)
**PR:** #780 — feat(93-6): plugin router loader for Cyclist
**Branch:** feat/story-93-6-cyclist-benchmark-plugin (pushed)

**Implementation approach:**
- `initPluginRouters()` calls `discoverPlugins(projectRoot)` then `getPluginRouters(plugins)` from `@pennyfarthing/core`
- For each router spec: dynamically imports the module, finds the named export, calls it as a factory (passing `getProjectDir`), and mounts the result via `app.use(mountPath, router)`
- All errors caught per-router — one broken plugin doesn't prevent others from loading
- `dynamicImport()` helper allows test mocking via `globalThis.__pluginImportMock`
- Returns structured `PluginLoadResult` for logging: `{discovered, loaded, failed, routers[]}`

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | Plugin routers not loaded in Electron mode. `initPluginRouters()` only called in standalone server path (`if process.argv[1]`). Electron startup in `main.ts:startServer()` calls `createTerminalServer()` but never `initPluginRouters()`. The old `initPennyfarthingFeatures()` ran at module scope for both modes — this is a regression. | `server.ts:244-253` / `main.ts:2089-2114` | Call `initPluginRouters(app, projectDir)` from `main.ts:startServer()` after `createTerminalServer()`, or restructure to run at module scope |
| [MEDIUM] | Test "pass getProjectDir to router factory" asserts only `result` is defined, not that factory received correct argument | `93-6-plugin-loader.test.ts:229-262` | Verify factory was called with `() => projectRoot` getter |
| [LOW] | Unrelated changes (handoff.md, architecture workflow.yaml) included in story-scoped PR | `pennyfarthing-dist/agents/handoff.md`, `pennyfarthing-dist/workflows/architecture/` | Move to separate commit/PR |
| [VERIFIED] | Graceful degradation correct — all three error boundaries (discovery, router extraction, per-router import) catch and continue | `plugin-loader.ts:80-131` | — |
| [VERIFIED] | PluginLoadResult shape correct, never throws, structured logging | `plugin-loader.ts:32-41, 72-77` | — |
| [VERIFIED] | Dynamic import mock pattern (globalThis.__pluginImportMock) is sound | `plugin-loader.ts:46-55` | — |
| [VERIFIED] | Benchmark package.json api field matches PluginRouter interface | `benchmark/package.json:54-62` | — |

**Data flow traced:** `initPluginRouters(app, projectRoot)` → `discoverPlugins()` → `getPluginRouters()` → `dynamicImport(modulePath)` → `factory(() => projectRoot)` → `app.use(mountPath, router)`. Sound for standalone mode, missing in Electron mode.

**Handoff:** Back to Dev for fixes

## Dev Assessment (Review Fixes)

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/main.ts` — Add `initPluginRouters()` call to Electron startup path (`startServer()`) so plugin routers load in both Electron and standalone modes
- `packages/cyclist/tests/93-6-plugin-loader.test.ts` — Strengthen factory argument test to verify `getProjectDir` getter is passed and returns correct value; add mock cleanup in `beforeEach`
- `pennyfarthing-dist/agents/handoff.md` — Reverted unrelated changes
- `pennyfarthing-dist/workflows/architecture/workflow.yaml` — Removed (unrelated to story scope)

**Review Issues Addressed:**
- [HIGH] Fixed: `initPluginRouters()` now called from `main.ts:startServer()` before `server.listen()`, matching both Electron and standalone code paths
- [MEDIUM] Fixed: Test now uses `vi.fn()` factory mock, asserts it was called once with a function argument that returns the project root
- [LOW] Fixed: Reverted handoff.md changes and removed architecture workflow.yaml from PR

**Tests:** 15/15 passing (GREEN)
**PR:** #780 — feat(93-6): plugin router loader for Cyclist
**Branch:** feat/story-93-6-cyclist-benchmark-plugin (pushed)

**Handoff:** To Reviewer for re-review

## Reviewer Assessment (Re-Review)

**Verdict:** APPROVED

| # | Status | Observation | Location |
|---|--------|-------------|----------|
| 1 | [VERIFIED] | Electron mode fix correct — `initPluginRouters()` called with `await` before `server.listen()` in `startServer()` | `main.ts:2090-2100` |
| 2 | [VERIFIED] | Test strengthened — factory mock asserts call count, argument type (function), and return value | `93-6-plugin-loader.test.ts:259-272` |
| 3 | [VERIFIED] | Unrelated changes removed — PR contains only 5 story-scoped files | `git diff --stat` |
| 4 | [VERIFIED] | `expressApp` alias correctly references same Express instance `createTerminalServer()` wraps | `main.ts:1993`, `server.ts:62` |
| 5 | [VERIFIED] | No race condition — plugin loading `await`ed before `server.listen()`, all routes mounted before accepting connections | `main.ts:2096-2105` |

**Data flow traced:** `startServer()` → `createTerminalServer()` → `initPluginRouters(expressApp, pluginProjectDir)` → discovers, imports, mounts → `server.listen(0)`. Both Electron and standalone paths load plugins before accepting requests.
**Error handling:** `initPluginRouters` never throws (triple try/catch), `getProjectDirectory()` null-guarded in main.ts
**Pattern observed:** Await-before-listen is an improvement over old fire-and-forget `initPennyfarthingFeatures()`

**Handoff:** To SM for finish-story
