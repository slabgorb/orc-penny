---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-7: Add Tests for Core API Routes (settings through welcome)

## Business Context

Epic 141 identified that core API routes lack test coverage — approximately 20 route handlers in `packages/core/src/server/api/` have zero tests. Stories 141-5 and 141-6 cover the first two alphabetical batches; this story covers the final batch: settings, stats, story, telemetry, theme-agents, todos, token-stats, and welcome.

These routes are active in every BikeRack session (TUI, GUI, and IDE modes). Without tests, regressions in settings persistence, stats broadcasting, story context loading, or telemetry aggregation go undetected. The server.test.ts file already smoke-tests that route factories are exported and return Express Routers, but it does not test the logic inside each handler — input validation, error paths, or data contract shapes. This story closes that gap for the second half of the alphabet.

## Technical Guardrails

### Route File Locations

All target route files live at `pennyfarthing/packages/core/src/server/api/`:

| File | Factory / Exports |
|------|-------------------|
| `settings.ts` | `createSettingsRouter()`, `getSettingsForWebSocket(projectDir)` |
| `stats.ts` | `createStatsRouter()`, `getCurrentStats()`, `broadcastStats()`, `updatePwd()` |
| `story.ts` | `createStoryRouter(getProjectDir)` |
| `telemetry.ts` | `createTelemetryRouter()` |
| `theme-agents.ts` | `createThemeAgentsRouter(getProjectDir)`, `getThemeAgents(projectDir)` |
| `todos.ts` | `createTodosRouter()`, `setWebModeTodos()`, `getWebModeTodos()` |
| `token-stats.ts` | `createTokenStatsRouter()`, `broadcastTokenStats()`, `getTokenStatsClients()` |
| `welcome.ts` | `broadcastWelcome()`, `getWelcomeClients()` — no HTTP router, WebSocket-only |

### Test Runner

Tests run via Node.js native test runner. Command: `cd packages/core && pnpm build && node --test dist/server/api/*.test.js`

Test files are TypeScript source in `src/` compiled to `dist/`. The test runner targets `dist/`. Each test file must be co-located with its source file: `src/server/api/settings.test.ts`, etc.

### Import Conventions

- Use `.js` extensions in all relative imports (TypeScript ESM convention)
- Import test utilities from `node:test` and `node:assert`
- Use `import()` (dynamic) for modules that have side effects on load
- Use `mkdirSync` / `rmSync` from `node:fs` with `tmpdir()` from `node:os` for filesystem fixtures

### Existing Test Pattern

The single existing API route test (`git-fetch-cooldown.test.ts`) uses:

```typescript
import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert';
// Tests exported functions directly — no HTTP server spin-up
```

The `server.test.ts` pattern (spin up `http.createServer(app)` on port 0, use `fetch()`) is acceptable for HTTP handler tests but must `server.close()` in a `finally` block to avoid hanging the test runner. The server.test.ts also warns: do NOT call `createTerminalServer()` — it sets up WebSocket upgrade handlers that hold the event loop open.

### Stats Module State

`stats.ts` holds module-level mutable state (`currentStats`, `pendingStats`, `debounceTimer`, `statsClients`). Tests that mutate stats via `POST /` must account for state bleed between tests. Use `getCurrentStats()` to read state after mutations and reset between tests if needed.

### Todos Module State

`todos.ts` holds `webModeTodos` as module-level state. Tests can use `setWebModeTodos()` to pre-populate and `getWebModeTodos()` to assert. State resets are required between tests that mutate it.

### Token-Stats / Welcome: No HTTP Router

`token-stats.ts` and `welcome.ts` export utility functions and WebSocket client sets, but their HTTP GET handler (`createTokenStatsRouter`) and broadcast logic do not have complex business logic beyond pass-through. Test the exported utility functions directly; do not spin up WebSocket servers.

### Settings: Filesystem Dependency

`getSettingsForWebSocket(projectDir)` reads `.pennyfarthing/config.local.yaml` from `projectDir`. Tests that exercise theme/display/workflow merging must create a temp directory with a `.pennyfarthing/config.local.yaml` fixture and clean up in `afterEach`.

### Theme-Agents: Project Detection

`getThemeAgents(projectDir)` calls `detectPennyfarthingProject(projectDir)` first and returns `{}` if the project is not detected. Tests for error/no-project paths can safely pass a temp directory without a `.pennyfarthing/` structure.

## Scope Boundaries

**In scope:**

- Test files for each of the eight route modules:
  - `packages/core/src/server/api/settings.test.ts`
  - `packages/core/src/server/api/stats.test.ts`
  - `packages/core/src/server/api/story.test.ts`
  - `packages/core/src/server/api/telemetry.test.ts`
  - `packages/core/src/server/api/theme-agents.test.ts`
  - `packages/core/src/server/api/todos.test.ts`
  - `packages/core/src/server/api/token-stats.test.ts`
  - `packages/core/src/server/api/welcome.test.ts`
- Each test file covers: exported function existence, happy path behavior, at least one error/edge case
- Tests run via `node --test` on compiled `dist/` output and pass

**Out of scope:**

- Routes covered in 141-5 (agent-load through hotspots) and 141-6 (identity through portrait)
- WebSocket server setup or `setupWebSocketServers()` — covered by server.test.ts
- Integration tests that require a running Pennyfarthing project with real `.pennyfarthing/` config
- Modifying the route source files themselves — this is a test-only story
- `createTerminalServer()` invocation — explicitly excluded per server.test.ts warning
- Benchmarking or performance tests

## AC Context

**AC 1: Test files exist for settings, stats, story, telemetry, theme-agents, todos, token-stats, welcome API routes**

- Eight test files must exist at `packages/core/src/server/api/{route-name}.test.ts`
- Each file must contain at least one `describe` block with `it` assertions using `node:test` and `node:assert`
- Testable via: `ls packages/core/src/server/api/*.test.ts` lists all eight files
- Note: `git-fetch-cooldown.test.ts` already exists and is out of scope for this story

**AC 2: Each test covers happy path and at least one error case**

For each route, the minimum coverage contract is:

- **settings** — `getSettingsForWebSocket()` returns settings object (happy); returns current settings when config.local.yaml is missing or malformed (error path). `createSettingsRouter()` PATCH returns `{success: true}` on valid input; returns 500 when `saveUserSettings` fails.

- **stats** — `createStatsRouter()` GET returns `{model, status, pwd}` shape (happy); POST with valid partial `{model: "claude-3"}` updates state (happy); POST with non-string `model` returns 400 with error message (validation error). `updatePwd()` updates `currentStats.pwd` when pwd changes; skips update when pwd is the same.

- **story** — `createStoryRouter(getProjectDir)` GET returns story info object (happy path with a valid project dir); returns graceful response with `id: null` when no session file exists (error/missing path). The factory function accepts a `getProjectDir` callback — tests can pass `() => testDir`.

- **telemetry** — `createTelemetryRouter()` GET `/` returns `{metrics: ...}` shape (happy); GET `/tdd` returns same `{metrics}` shape; GET `/hierarchy` returns `{hierarchy: ...}`; GET `/by-agent` and `/by-story` return `{stats: ...}` shapes. Error case: `getTDDMetrics()` returning empty/null should yield `{metrics: null}` or `{metrics: {}}` without throwing.

- **theme-agents** — `getThemeAgents(projectDir)` returns `{}` when `detectPennyfarthingProject` returns false (non-project dir — error/no-project path); `createThemeAgentsRouter(getProjectDir)` GET `/full` returns 404 when theme data is not available (error path); GET `/` returns `{agents: ...}` shape (happy, even if agents is empty).

- **todos** — `getWebModeTodos()` returns empty array by default (happy baseline); `setWebModeTodos([...])` followed by `getWebModeTodos()` returns the set value (round-trip happy path); `createTodosRouter()` GET returns array (not 404 or 500) when `webModeTodos` is empty (error/empty case is valid behavior).

- **token-stats** — `createTokenStatsRouter()` returns a Router with `.get` method (shape test); `getTokenStatsClients()` returns a Set (happy); `broadcastTokenStats()` does not throw when the clients Set is empty (error/no-clients path).

- **welcome** — `getWelcomeClients()` returns a Set (happy); `broadcastWelcome({project, theme})` does not throw when no clients are connected (error/no-clients path); broadcast payload includes `type: 'welcome'`, `project`, `theme`, `showNudge`, `timestamp` fields (shape contract).

**AC 3: Tests run via node --test and pass**

- Command: `cd packages/core && pnpm build && node --test dist/server/api/settings.test.js dist/server/api/stats.test.js dist/server/api/story.test.js dist/server/api/telemetry.test.js dist/server/api/theme-agents.test.js dist/server/api/todos.test.js dist/server/api/token-stats.test.js dist/server/api/welcome.test.js`
- All tests exit 0 (no failures)
- No test hangs — no `createTerminalServer()` calls, no unclosed WebSocket servers, `server.close()` in `finally` blocks for any HTTP server created in tests
- Testable via: CI run shows green for all eight test files
