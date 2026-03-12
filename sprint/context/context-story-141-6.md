---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-6: Add Tests for Core API Routes (evaluation through portrait)

## Business Context

Core API routes have zero test coverage. Twelve route handlers — evaluation, file-browser, git, health-score, hook-request, hotspots, identity, mode, otlp, permissions, persona, and portrait — serve the WheelHub server and BikeRack panels but are entirely untested. Any regression in route factory logic, response shape, or error handling goes undetected. This story closes that gap for the first batch of routes (alphabetically, evaluation through portrait), establishing the test pattern and style that stories 141-7 will extend for the remaining routes.

Test files live alongside source files in `packages/core/src/server/api/` and run via `node --test` as part of the standard `pnpm test` invocation in the core package.

## Technical Guardrails

### Existing Test Pattern

The single existing API route test is `packages/core/src/server/api/git-fetch-cooldown.test.ts`. It uses:

- `import { describe, it, beforeEach } from 'node:test'`
- `import assert from 'node:assert'`
- Dynamic `await import('./module.js')` inside test bodies
- No mocking framework — tests import and call exported functions directly
- File header comment citing the story number and a brief description of what is verified

Broader server tests (`packages/core/src/server/server.test.ts`) demonstrate testing Express routers by creating a real `http.createServer(app)`, binding to port `0`, and calling `fetch()` against it. The same test file confirms all route factories are functions and that calling them returns Express Router instances (objects with `.use`, `.get`, `.post` methods).

### Route Files Under Test

| Route | File | Factory | Takes getProjectDir? |
|-------|------|---------|----------------------|
| Evaluation | `packages/core/src/server/api/evaluation.ts` | `createEvaluationRouter()` | No |
| File Browser | `packages/core/src/server/api/file-browser.ts` | `createFileBrowserRouter(getProjectDir)` | Yes |
| Git | `packages/core/src/server/api/git.ts` | `createGitRouter(getProjectDir)` | Yes |
| Health Score | `packages/core/src/server/api/health-score.ts` | `createHealthScoreRouter(getProjectDir)` | Yes |
| Hook Request | `packages/core/src/server/api/hook-request.ts` | `createHookRequestRouter()` | No |
| Hotspots | `packages/core/src/server/api/hotspots.ts` | `createHotspotsRouter(getProjectDir)` | Yes |
| Identity | `packages/core/src/server/api/identity.ts` | `createIdentityRouter()` | No |
| Mode | `packages/core/src/server/api/mode.ts` | `createModeRouter()` | No |
| OTLP | `packages/core/src/server/api/otlp.ts` | `createOTLPRouter()` | No |
| Permissions | `packages/core/src/server/api/permissions.ts` | `createPermissionsRouter()` | No |
| Persona | `packages/core/src/server/api/persona.ts` | `createPersonaRouter(getProjectDir)` | Yes |
| Portrait | `packages/core/src/server/api/portrait.ts` | `createPortraitRouter()` | No |

### Exported Testable Functions (non-router)

Several modules export pure functions and state helpers that can be tested without HTTP:

- `evaluation.ts` — `getEvaluation()`, `getEvaluationResults()`, `getEvaluationSummary()`, `detectTrend()`, `generateRecommendations()`, `clearEvaluationResults()`
- `hook-request.ts` — `classifyHookSeverity()`, `resolveApproval()`, `getHookClients()`, `addHookClient()`
- `identity.ts` — `IdentityInfo` interface; route calls `execSync` for `jira` and `gh` CLI — tests must not shell out; test that the router factory returns a Router
- `mode.ts` — `getModeInfo()` returns `ModeInfo` struct with `mode`, `isBikeRack`, `nodeVersion`, `platform`, `arch`, `pid`, `uptime`, `startTime`
- `permissions.ts` — router wraps `getGrants()`, `addGrant()`, `removeGrant()` from `settings-store.ts`; test via HTTP calls
- `portrait.ts` — `getCurrentPortrait()` returns `{ src: string }`

### Key Constraints

- Tests must not start the full WebSocket server (`setupWebSocketServers`) — it holds the event loop open and hangs the test runner
- Avoid calling `execFile`/`execSync` subprocesses in tests — health-score, hotspots, and identity routes shell out to `python3` and system CLIs; test router factory shape and error-path logic, not subprocess output
- `.js` extensions are required in all relative TypeScript imports (project rule)
- Run command: `cd pennyfarthing/packages/core && pnpm build && node --test dist/server/api/*.test.js`

## Scope Boundaries

**In scope:**

- New test files for these twelve routes, each at `packages/core/src/server/api/<route>.test.ts`:
  - `evaluation.test.ts`
  - `file-browser.test.ts`
  - `git.test.ts` (route factory shape and non-cooldown logic — cooldown already covered by `git-fetch-cooldown.test.ts`)
  - `health-score.test.ts`
  - `hook-request.test.ts`
  - `hotspots.test.ts`
  - `identity.test.ts`
  - `mode.test.ts`
  - `otlp.test.ts`
  - `permissions.test.ts`
  - `persona.test.ts`
  - `portrait.test.ts`
- Each test file: happy path + at least one error case per significant route/function
- Tests run via `node --test` and pass after `pnpm build`

**Out of scope:**

- Routes not in this batch: `agent-load`, `audit-log`, `bell`, `code-markers`, `complexity`, `context`, `dead-code`, `dependencies`, `project-info`, `settings`, `spans`, `stats`, `story`, `telemetry`, `theme-agents`, `todos`, `token-stats`, `welcome` — covered by story 141-7
- Integration tests against a live WheelHub server with WebSocket connections
- Testing subprocess output from `python3 -m pf.healthscore` or `python3 -m pf.hotspots`
- Changes to any route implementation files
- Changes to `git-fetch-cooldown.test.ts` (already exists and passes)

## AC Context

**AC 1: Test files exist for all twelve routes**

- Twelve `.test.ts` files must exist in `packages/core/src/server/api/`:
  `evaluation.test.ts`, `file-browser.test.ts`, `git.test.ts`, `health-score.test.ts`, `hook-request.test.ts`, `hotspots.test.ts`, `identity.test.ts`, `mode.test.ts`, `otlp.test.ts`, `permissions.test.ts`, `persona.test.ts`, `portrait.test.ts`
- Testable via: `ls packages/core/src/server/api/*.test.ts | wc -l` returns 13 (12 new + existing `git-fetch-cooldown.test.ts`)

**AC 2: Each test covers happy path and at least one error case**

Route-by-route expected coverage:

- **evaluation**: Happy — `createEvaluationRouter()` returns Router with `.get`/`.post`; `getEvaluation()` returns an object; `detectTrend([])` does not throw. Error — `generateRecommendations` with empty results returns an array (not throws).
- **file-browser**: Happy — `createFileBrowserRouter(() => '/tmp')` returns Router; GET `/` with no path query lists project root. Error — POST `/open` with missing `path` body returns 400; POST `/edit` with path outside project dir returns 403.
- **git**: Happy — `createGitRouter(() => '/tmp')` returns Router with `.get`. Error — route factory with non-function arg does not crash at construction time (arg is only called on request).
- **health-score**: Happy — `createHealthScoreRouter(() => '/tmp')` returns Router. Error — GET `/` when `pf` Python package is absent returns 404 JSON with `{ success: false, error: ... }` (not Express HTML 404).
- **hook-request**: Happy — `classifyHookSeverity('Read', {})` returns `{ severity: 'safe' }`; `classifyHookSeverity('Bash', { command: 'ls' })` returns `{ severity: 'safe' }`; POST to router with `toolName`+`toolId` and no connected clients returns `{ decision: 'ask' }`. Error — POST without `toolName` returns 400; `classifyHookSeverity('Bash', { command: 'rm -rf /' })` returns `{ severity: 'destructive' }`.
- **hotspots**: Happy — `createHotspotsRouter(() => '/tmp')` returns Router. Error — confirms router construction does not shell out (no subprocess on router creation).
- **identity**: Happy — `createIdentityRouter()` returns Router with `.get`. Error — route construction does not throw when `jira` and `gh` CLIs are absent (errors are caught internally).
- **mode**: Happy — `getModeInfo()` returns object with all required fields: `mode` (`'electron'|'web'|'unknown'`), `isBikeRack` (boolean), `nodeVersion` (string starting with `v`), `platform` (string), `arch` (string), `pid` (positive integer), `uptime` (number >= 0), `startTime` (ISO 8601 string). Error — `getModeInfo()` called multiple times is stable (no throw on repeated calls).
- **otlp**: Happy — `createOTLPRouter()` returns Router; router has POST `/logs`, `/metrics`, `/traces` (check via router stack). Error — `processOTLPLogs`/`processOTLPMetrics`/`processOTLPTraces` called with malformed body (null/undefined) do not throw (caught internally, returns 500).
- **permissions**: Happy — `createPermissionsRouter()` returns Router; POST `/grant` with `{ tool: 'Bash', scope: 'ls', grant_type: 'session' }` returns 201 with grant object; GET `/` returns `{ grants: [...] }`; GET `/show/Bash` returns grants for Bash; DELETE `/revoke/Bash` returns `{ removed: N }`. Error — POST `/grant` missing `tool` returns 400; POST `/grant` with invalid `grant_type` returns 400.
- **persona**: Happy — `createPersonaRouter(() => '/tmp')` returns Router with `.get`. Error — GET `/` when project dir is not a Pennyfarthing project returns 404 JSON `{ error: 'Not a Pennyfarthing project' }`; GET `/full` similarly returns 404.
- **portrait**: Happy — `createPortraitRouter()` returns Router; `getCurrentPortrait()` returns `{ src: '' }` initially; POST `/` with `{ src: 'https://example.com/img.png' }` returns `{ success: true, src: '...' }`; subsequent GET `/` returns the updated portrait. Error — POST `/` with missing or non-string `src` returns 400 `{ error: 'Invalid portrait src' }`.

**AC 3: Tests run via `node --test` and pass**

- After `pnpm build` in `packages/core`, running `node --test dist/server/api/*.test.js` exits 0
- No test runner errors, no hanging processes
- All `describe`/`it` blocks report `pass`
- Existing `git-fetch-cooldown.test.ts` continues to pass unmodified
