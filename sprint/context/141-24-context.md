# Story 141-24: Wire pf serve into WheelHub lifecycle

## Summary
3pt TDD story to integrate the pf serve components (built in 141-22) into WheelHub's Express server. Mount the proxy router, wire lifecycle spawn/stop, and replace subprocess calls with PfClient.

## Technical Approach
- Mount `createPfProxyRouter()` on `/api/pf/*` in WheelHub's Express app
- Call `spawnPfServe()` during WheelHub server startup, `stopPfServe()` on shutdown
- Replace `execSync('pf', [...])` calls with `PfClient.call()` (primary target: `sprint-data.ts`)
- Clean up unused TS imports in `pf-proxy.ts` (fs, path)
- Add timeout to proxy `http.request`

## Key Files (likely affected)
- `packages/core/src/server/` — WheelHub server entry point, route mounting
- `packages/core/src/server/pf-proxy.ts` — cleanup unused imports, add proxy timeout
- `packages/core/src/server/sprint-data.ts` — replace execSync with PfClient

## Acceptance Criteria
1. WheelHub mounts `createPfProxyRouter` on `/api/pf/*`
2. `spawnPfServe()` called on WheelHub startup, `stopPfServe()` on shutdown
3. At least one `execSync('pf ...')` call replaced with `PfClient.call()`
4. Unused imports removed from `pf-proxy.ts`
5. Proxy `http.request` has timeout
6. All existing tests still pass
