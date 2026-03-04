# Story 141-22: Add pf serve — Persistent Python Server with WheelHub Reverse Proxy

## Summary
5pt TDD story to replace Python subprocess-per-request pattern with a persistent HTTP server (`pf serve`) reverse-proxied through WheelHub.

## Technical Approach
- Add `pf serve` command that starts a FastAPI/Flask HTTP server
- Expose existing `--json` CLI endpoints as HTTP routes
- WheelHub reverse-proxies `/api/pf/*` to the `pf serve` port
- Replace `execFileSync('pf', [...])` calls with `fetch()` to local HTTP routes
- Auto-start/stop `pf serve` as WheelHub child process
- Preserve existing error contract (`{error, code, detail}`)

## Key Files (likely affected)
- `pennyfarthing-dist/src/pf/` — new `serve` command
- `packages/core/src/` — WheelHub reverse proxy setup, subprocess replacement
- `packages/core/src/server/` — WheelHub server entry points

## Acceptance Criteria
1. `pf serve` starts persistent HTTP server with all `--json` endpoints
2. WheelHub reverse-proxies `/api/pf/*` to `pf serve`
3. TypeScript subprocess calls replaced with `fetch()`
4. Auto-start/stop lifecycle tied to WheelHub
5. Latency improvement over subprocess pattern
6. Error contract preserved
