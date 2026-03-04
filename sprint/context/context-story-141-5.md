---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-5: Add Tests for Core API Routes (agent-load through dependencies)

## Business Context

The March 2026 tech debt audit found that ~20 core API route handlers in `packages/core` have zero test coverage. These routes power BikeRack panels, the WheelHub server, and CLI tooling — bugs here break visible user-facing features (agent load inspector, audit log viewer, code quality panels). This story closes the coverage gap for the first alphabetical batch: agent-load, approval-gate (hook-request), audit-log, bell, code-markers, complexity, context, dead-code, and dependencies.

## Technical Guardrails

**Route source files** (all under `pennyfarthing/packages/core/src/server/api/`):

| AC Route Name | Source File | Router Factory | Mounted At |
|---|---|---|---|
| agent-load | `agent-load.ts` | `createAgentLoadRouter(getProjectDir)` | `/api/agent-load` |
| approval-gate | `hook-request.ts` | `createHookRequestRouter()` | `/api/hook-request` |
| audit-log | `audit-log.ts` | `createAuditLogRouter()` | `/api/audit-log` |
| bell | `bell.ts` | no router — exports `getBellClients`, `broadcastBellConsumed` | WebSocket only |
| code-markers | `code-markers.ts` | `createCodeMarkersRouter(getProjectDir)` | `/api/code-markers` |
| complexity | `complexity.ts` | `createComplexityRouter(getProjectDir)` | `/api/complexity` |
| context | `context.ts` | `createContextRouter(getProjectDir)` | `/api/context` |
| dead-code | `dead-code.ts` | `createDeadCodeRouter(getProjectDir)` | `/api/dead-code` |
| dependencies | `dependencies.ts` | `createDependenciesRouter(getProjectDir)` | `/api/dependencies` |

**Test infrastructure:**
- Test runner: `node --test dist/**/*.test.js` (Node native test runner, not vitest)
- Test files live alongside source: `src/server/api/<name>.test.ts`
- After writing tests, run `pnpm build` in `packages/core` so `dist/` is updated before running `pnpm test`
- Existing reference: `pennyfarthing/packages/core/src/server/api/git-fetch-cooldown.test.ts`
- Broader reference: `pennyfarthing/packages/core/src/server/server.test.ts` (shows HTTP server test pattern with `http.createServer(app)`)

**Import pattern** (`.js` extensions required in TypeScript):
```typescript
import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert';
import { createAgentLoadRouter } from './agent-load.js';
```

**Express Router test pattern** (from `server.test.ts`):
```typescript
const http = await import('node:http');
const app = express();
app.use('/api/agent-load', createAgentLoadRouter(() => '/tmp/test-project'));
const server = http.createServer(app);
const port = await new Promise<number>((resolve) => {
  server.listen(0, () => {
    const addr = server.address();
    resolve(typeof addr === 'object' && addr ? addr.port : 0);
  });
});
try {
  const res = await fetch(`http://localhost:${port}/api/agent-load`);
  // assert...
} finally {
  server.close();
}
```

**Python-backed routes** (code-markers, complexity, dead-code, dependencies) shell out via `execFile('python3', ...)`. For error-case tests, either mock `execFile` or test the factory/router structure without triggering the subprocess. The subprocess won't work in test environments without the Python CLI installed, so error path tests should simulate subprocess failure by passing an invalid projectDir or checking the route's JSON error response shape.

**bell.ts** has no Express Router — it is a pure WebSocket broadcast module. Tests should verify the exported function signatures and WebSocket broadcast behavior using a mock `WebSocket` set.

**Result object shape** — routes that delegate to Python return `{ success: false, error: string }` on failure (500 response). Routes that delegate to TypeScript helpers return the helper's output directly or `{ agent, context: null }` on not-found.

## Scope Boundaries

**In scope:**
- Test files for: agent-load, hook-request (approval-gate), audit-log, bell, code-markers, complexity, context, dead-code, dependencies
- Each test file covers: happy-path (router returns expected shape, 200 OK) and at least one error case (500 JSON response, not-found JSON, missing param behavior)
- Tests use Node native test runner (`node:test`, `node:assert`) — no vitest
- Tests are co-located at `src/server/api/<name>.test.ts`

**Out of scope:**
- Routes from evaluation onward (141-6 covers evaluation through portrait)
- Integration tests that require a live Python CLI install
- Modifying the route implementations themselves — test-only changes
- `packages/cyclist/src/approval-gate.ts` — that is a different module in a different package; the AC refers to the core hook-request router

## AC Context

### AC1: Test files exist for each named route

Each of the 9 routes needs a corresponding `.test.ts` file in `pennyfarthing/packages/core/src/server/api/`. The `bell.ts` module does not export a Router factory; its test file should test the exported functions (`getBellClients`, `broadcastBellConsumed`) directly.

Expected test files to create:
- `pennyfarthing/packages/core/src/server/api/agent-load.test.ts`
- `pennyfarthing/packages/core/src/server/api/hook-request.test.ts` (fulfills "approval-gate" AC)
- `pennyfarthing/packages/core/src/server/api/audit-log.test.ts`
- `pennyfarthing/packages/core/src/server/api/bell.test.ts`
- `pennyfarthing/packages/core/src/server/api/code-markers.test.ts`
- `pennyfarthing/packages/core/src/server/api/complexity.test.ts`
- `pennyfarthing/packages/core/src/server/api/context.test.ts`
- `pennyfarthing/packages/core/src/server/api/dead-code.test.ts`
- `pennyfarthing/packages/core/src/server/api/dependencies.test.ts`

### AC2: Each test covers happy path and at least one error case

**agent-load** (`createAgentLoadRouter(getProjectDir)`):
- Happy path: `GET /` returns `{ agents: [], summary: null, cachedAt: <string>, totalAcrossAllAgents: 0 }`
- Happy path: `GET /:agent` with a valid agent name returns `{ agent: string, context: object | null }`
- Error case: `GET /:agent` when `getPrimeContextJson` returns null → `{ agent, context: null }` (not a 500)

**hook-request / approval-gate** (`createHookRequestRouter()`):
- Happy path: `POST /api/hook-request` with a payload for an allowlisted tool returns `{ decision: 'allow', reason: string }`
- Error case: `POST /api/hook-request` with missing `toolName` field returns 400 or appropriate error JSON
- Export check: `resolveApproval`, `getHookClients`, `addHookClient`, `handleHookWebSocketMessage` are all exported as functions

**audit-log** (`createAuditLogRouter()`):
- Happy path: `GET /` returns `{ entries: [], total: 0 }` (empty store on startup)
- Happy path: `GET /events` returns `{ events: [], total: 0 }`
- Happy path: `GET /types` returns `{ types: [] }`
- Happy path: `GET /stats` returns an object (shape varies, not null)
- Happy path: `DELETE /` returns `{ success: true }`
- Error case: `GET /export/json` returns content-type `application/json`
- Error case: `GET /export/csv` returns content-type `text/csv`

**bell** (no Router — WebSocket broadcast module):
- Happy path: `getBellClients()` returns a `Set`
- Happy path: `broadcastBellConsumed('hello')` does not throw when no clients are connected
- Error case: `broadcastBellConsumed` skips closed WebSocket clients (readyState !== OPEN)

**code-markers** (`createCodeMarkersRouter(getProjectDir)`):
- Happy path: factory returns an Express Router (has `.get`, `.use` methods)
- Error case: when python3 subprocess fails, `GET /` responds with 500 and `{ success: false, error: string }`

**complexity** (`createComplexityRouter(getProjectDir)`):
- Happy path: factory returns an Express Router
- Error case: subprocess failure → 500 `{ success: false, error: string }`
- Error case: invalid JSON from stdout → 500 `{ success: false, error: 'Failed to parse complexity analysis output' }`

**context** (`createContextRouter(getProjectDir)`, `getContextUsage`, `resolveContextScript`):
- Happy path: `createContextRouter` returns an Express Router
- Happy path: `resolveContextScript('/tmp/nonexistent')` returns `{ path: null, isPython: false, paths: string[] }` (paths is an array of candidates checked)
- Happy path: `getContextUsage('/tmp/nonexistent')` returns a `ContextInfo` with `error` set and numeric fields as `null`
- Error case: `getContextUsage` with an invalid dir returns `{ percent: null, tokens: null, error: string, ... }` (does not throw)

**dead-code** (`createDeadCodeRouter(getProjectDir)`):
- Happy path: factory returns an Express Router
- Error case: when python3 subprocess fails, `GET /` responds with 500 and `{ success: false, error: string }`
- Edge case: `?layer=stale` runs only the stale command; `?layer=all` runs both commands in parallel

**dependencies** (`createDependenciesRouter(getProjectDir)`):
- Happy path: factory returns an Express Router
- Error case: subprocess failure → 500 `{ success: false, error: string }`
- Error case: invalid JSON from stdout → 500 `{ success: false, error: 'Failed to parse dependencies analysis output' }`

### AC3: Tests run via node --test and pass

Build then test command from `packages/core`:
```
pnpm build && pnpm test
```

The test runner glob is `dist/**/*.test.js`. New test files at `src/server/api/<name>.test.ts` will compile to `dist/server/api/<name>.test.js` and be picked up automatically. Tests must not import from paths that do not exist in `dist/` at test time — always build before testing.
