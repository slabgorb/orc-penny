---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-22: Add pf serve — Persistent Python Server with WheelHub Reverse Proxy

## Business Context

Stories 141-17 and 141-18 replace TypeScript file-parsing with subprocess calls to `pf` CLI `--json` endpoints. This eliminates code duplication but introduces a performance tax: every GUI panel refresh spawns 1-4 Python processes, each paying ~100-200ms of interpreter startup, import chain, and YAML parsing. The caching strategy (FSWatcher + 30s TTL) mitigates this for repeated reads, but cache misses during active development (frequent file changes) will still feel sluggish.

`pf serve` eliminates the startup tax entirely. A persistent Python HTTP server keeps the interpreter warm, modules loaded, and can maintain its own in-memory cache of parsed YAML. WheelHub reverse-proxies `/api/pf/*` to the `pf serve` port, so the TypeScript layer switches from `execFileSync('pf', [...])` to `fetch('/api/pf/...')` — a single-digit-millisecond HTTP call to localhost instead of a 100ms+ subprocess spawn.

This also solves the `pf` binary resolution problem from 141-16. TypeScript no longer needs to find `pf` on PATH or check `PF_BIN` — it just hits WheelHub's own port, which proxies internally. The resolution complexity moves to WheelHub's startup (spawn `pf serve` once) rather than every subprocess call.

### Architecture After This Story

```
┌──────────────────────────────────────────────┐
│ Browser / BikeRack GUI                       │
│                                              │
│  fetch('/api/pf/story/show?id=141-16')       │
│  fetch('/api/pf/theme/show?name=west-wing')  │
│  fetch('/api/pf/workflow/phases?id=141-16')   │
└──────────────┬───────────────────────────────┘
               │ HTTP
┌──────────────▼───────────────────────────────┐
│ WheelHub (Express, TypeScript)               │
│                                              │
│  /api/stats, /api/git, /api/spans, ...       │  ← existing routes (unchanged)
│  /api/pf/*  ──► reverse proxy ──────────┐    │
│                                         │    │
└─────────────────────────────────────────┼────┘
                                          │ HTTP (localhost)
┌─────────────────────────────────────────▼────┐
│ pf serve (FastAPI, Python)                   │
│                                              │
│  GET /story/show?id=X     → sprint data      │
│  GET /workflow/phases?id=X → phase list       │
│  GET /theme/show?name=X   → theme data        │
│  GET /persona/current     → persona data      │
│  GET /handoff/status      → gate state        │
│  POST /handoff/complete-phase → phase advance  │
│  POST /handoff/resolve-gate   → gate check    │
│                                              │
│  In-memory cache + FSWatcher invalidation    │
│  Python interpreter stays warm               │
└──────────────────────────────────────────────┘
```

## Technical Guardrails

### pf serve Implementation

**Location:** `pennyfarthing/pennyfarthing-dist/src/pf/serve/` — new module alongside existing pf CLI modules.

**Framework:** FastAPI (already a transitive dependency via uvicorn in the Python ecosystem) or Flask (lighter, no async needed for this use case). Prefer FastAPI for automatic OpenAPI docs and Pydantic validation, which gives us schema documentation for free.

**CLI entry point:** `pf serve [--port PORT] [--host HOST]`
- Default port: 0 (auto-assign, write to `.bikerack-pf-port` alongside `.bikerack-port`)
- Default host: `127.0.0.1` (localhost only, never exposed externally)
- Writes port to `.bikerack-pf-port` so WheelHub can discover it

**Route mapping — each `pf` CLI `--json` command becomes an HTTP endpoint:**

| CLI Command | HTTP Route | Method |
|---|---|---|
| `pf sprint story show ID --json` | `GET /story/show?id=ID` | GET |
| `pf workflow phases ID --json` | `GET /workflow/phases?id=ID` | GET |
| `pf persona current AGENT --json` | `GET /persona/current?agent=AGENT` | GET |
| `pf theme show NAME --json` | `GET /theme/show?name=NAME` | GET |
| `pf theme list --json` | `GET /theme/list` | GET |
| `pf handoff status --json` | `GET /handoff/status` | GET |
| `pf workflow route ID --json` | `GET /workflow/route?id=ID` | GET |
| `pf handoff resolve-gate --json` | `POST /handoff/resolve-gate` | POST |
| `pf handoff complete-phase --json` | `POST /handoff/complete-phase` | POST |
| `pf handoff marker --json` | `POST /handoff/marker` | POST |

**Response contract:** Same JSON shapes as the CLI `--json` output (defined in 141-16). Errors return `{error, code, detail}` with appropriate HTTP status codes (404 for not found, 400 for bad request, 500 for internal errors).

**In-memory caching:** `pf serve` maintains its own cache, invalidated by FSWatcher on the same file patterns as 141-17's TypeScript cache. This means the TypeScript-side cache from 141-17 becomes redundant — the server-side cache handles it. TypeScript can remove its caching layer and trust the HTTP responses to be fast.

### WheelHub Reverse Proxy

**Location:** `pennyfarthing/packages/core/src/server/server.ts` — add proxy middleware.

**Implementation:** Use `http-proxy-middleware` (already common in Express apps) or a simple manual proxy using Node's `http.request`:

```typescript
import { createProxyMiddleware } from 'http-proxy-middleware';

// In server setup, after reading pf serve port:
const pfPort = readPfServePort(); // reads .bikerack-pf-port
app.use('/api/pf', createProxyMiddleware({
  target: `http://127.0.0.1:${pfPort}`,
  pathRewrite: { '^/api/pf': '' },
  changeOrigin: false,
}));
```

**Lifecycle management:**
- WheelHub spawns `pf serve` as a child process on startup (in `entry.ts` or `server.ts`)
- WheelHub reads `.bikerack-pf-port` to discover the assigned port
- On WheelHub shutdown, the child process is killed via `process.kill()`
- If `pf serve` crashes, WheelHub should restart it (simple retry with backoff)
- Health check: WheelHub pings `GET /health` on `pf serve` before proxying

### TypeScript Callsite Migration

After WheelHub proxies `/api/pf/*`, the TypeScript layer in 141-17/18 changes from:

```typescript
// Before (subprocess)
const result = execFileSync(pfBin, ['sprint', 'story', 'show', storyId, '--json'], { ... });
return JSON.parse(result);

// After (HTTP via WheelHub)
const response = await fetch(`/api/pf/story/show?id=${storyId}`);
const data = await response.json();
return data;
```

This is a mechanical replacement. The caching layer in TypeScript (from 141-17) can be removed since `pf serve` handles caching server-side.

### Dependency Note

This story depends on 141-16 (the `--json` endpoints must exist). It should be done after 141-17 and 141-18 (which establish the subprocess pattern), then replaces the subprocess calls with HTTP calls. However, if this story is prioritized, 141-17/18 could target HTTP calls directly instead of subprocess calls — skipping the subprocess intermediate step.

**Recommended sequence:** 141-16 → 141-22 → 141-17/18 (target HTTP from the start). This avoids writing subprocess code that gets immediately replaced. The trade-off is that 141-22 becomes a blocker for 141-17/18, but it's a clean 5-pointer that can be done in parallel with 141-15/20/21.

### Build and Test

```bash
# Python server
cd pennyfarthing && python -m pytest pennyfarthing-dist/src/pf/tests/ -x

# TypeScript proxy
cd pennyfarthing/packages/core && pnpm run build && npm test

# Integration: start pf serve, hit endpoints, verify responses
pf serve --port 9876 &
curl http://localhost:9876/health
curl http://localhost:9876/theme/list
kill %1
```

## Scope Boundaries

**In scope:**
- `pf serve` command in `pennyfarthing-dist/src/pf/serve/` — FastAPI/Flask HTTP server exposing all `--json` endpoints as HTTP routes
- Port file `.bikerack-pf-port` written on startup
- Health check endpoint (`GET /health`)
- In-memory caching with FSWatcher invalidation inside `pf serve`
- WheelHub reverse proxy at `/api/pf/*` in `packages/core/src/server/server.ts`
- WheelHub spawns `pf serve` as child process on startup, kills on shutdown
- Replace `execFileSync('pf', ...)` calls in story-parser, theme-loader, and workflow engine with `fetch('/api/pf/...')` calls
- Remove TypeScript-side caching layer (server-side cache is authoritative)
- Latency benchmark: measure panel render time with subprocess vs HTTP

**Out of scope:**
- WebSocket streaming from `pf serve` (future — could enable real-time push updates)
- Authentication on `pf serve` (localhost-only, single-user tool)
- Running `pf serve` standalone without WheelHub (it's an internal service)
- Adding new endpoints beyond what 141-16 defines
- Changing the `pf` CLI's `--json` output format
- Any changes to BikeRack GUI React components (they hit WheelHub API, which is unchanged from their perspective)

## AC Context

### AC1: pf serve starts a persistent HTTP server exposing all --json endpoints as HTTP routes

- `pf serve` starts without error, binds to a port, writes `.bikerack-pf-port`
- Each CLI `--json` endpoint has a corresponding HTTP route (see route mapping table)
- HTTP responses match the CLI JSON output byte-for-byte (same schemas)
- `GET /health` returns `{"status": "ok"}` with 200
- Testable: start `pf serve`, hit each route with `curl` or `httpx`, assert response matches `pf <command> --json` output

### AC2: WheelHub reverse-proxies /api/pf/* to pf serve

- WheelHub's Express app has a proxy middleware at `/api/pf`
- Requests to `http://localhost:WHEELHUB_PORT/api/pf/theme/list` are proxied to `http://localhost:PF_PORT/theme/list`
- Proxy handles connection errors gracefully (returns 502 with `{error: "pf serve unavailable"}`)
- Testable: start WheelHub (which spawns pf serve), hit `/api/pf/health` through WheelHub port, assert 200

### AC3: TypeScript subprocess calls replaced with fetch() to WheelHub /api/pf/* routes

- `grep -rn "execFileSync.*pf\|execSync.*pf" packages/core/src/server/ packages/core/src/shared/ packages/core/src/workflow/` returns no matches for pf CLI subprocess calls (only in test utilities)
- Story-parser, theme-loader, and workflow engine delegation modules use `fetch('/api/pf/...')` instead
- Error handling preserved: HTTP 4xx/5xx → `{success: false, error: ...}` result objects
- Testable: mock `fetch` in tests, assert correct URLs are called

### AC4: pf serve auto-starts when WheelHub starts, shuts down when WheelHub shuts down

- WheelHub's `entry.ts` spawns `pf serve` as a child process before starting the Express server
- WheelHub reads `.bikerack-pf-port` and configures the proxy
- On WheelHub shutdown (SIGTERM, SIGINT), `pf serve` child process is killed
- If `pf serve` crashes, WheelHub logs the error and attempts restart (max 3 retries)
- Testable: start WheelHub, verify `pf serve` process exists; stop WheelHub, verify `pf serve` process is gone

### AC5: Latency regression test shows improvement over subprocess pattern

- Benchmark measures: cold start (first request after cache clear) and warm (subsequent requests)
- Compare against the subprocess baseline measured in 141-17
- Target: cold < 50ms (vs ~150ms subprocess), warm < 10ms (vs ~50ms subprocess with TS cache)
- Results documented in PR description
- Testable: automated benchmark script that times N requests and reports p50/p95/p99

### AC6: Error contract preserved ({error, code, detail} JSON on failure)

- All error responses from `pf serve` use the same `{error, code, detail}` contract from 141-16
- HTTP status codes map to error codes: 404 → `STORY_NOT_FOUND` etc., 500 → `INTERNAL_ERROR`
- WheelHub proxy passes through error responses unchanged (no wrapping)
- Testable: request a nonexistent story, assert 404 with `{error: "Story not found", code: "STORY_NOT_FOUND", detail: "141-999"}`
