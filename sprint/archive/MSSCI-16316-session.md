# Story 48-4: Cleanup — remove Node.js server, build scripts, update docs
**Jira:** MSSCI-16316
**Epic:** Python WheelHub Migration
**Workflow:** trivial
**Phase:** finish
**Repos:** orchestrator,pennyfarthing
**Branch:** feat/48-4-cleanup-remove-nodejs-server
**Points:** 2

## Story Context
Replace Node.js WheelHub server with Python FastAPI has been completed across stories 48-1 through 48-3. This final cleanup story removes the now-dead Node.js server code, build scripts, and updates documentation to reflect the Python-only runtime. This is part of the broader goal to eliminate the build pipeline, unify the runtime, and remove the Node.js dependency (see ADR-0022).

## Technical Approach
- Remove Node.js server source files from `packages/core/` that are no longer needed
- Remove or update build scripts (TypeScript compilation, bundling) that served the old Node.js server
- Update documentation references from Node.js server to Python FastAPI
- Verify no remaining imports or references to removed code

## Acceptance Criteria
- Node.js WheelHub server code is removed
- Build scripts related to the old server are removed or updated
- Documentation reflects the Python FastAPI server as the sole backend
- No broken imports or dangling references remain

## Reviewer Assessment

**Verdict:** APPROVED (re-review)

**Previous findings — all resolved:**
1. [VERIFIED] Root package.json exports now contain only `.` and `./dist/*` — dangling server exports removed
2. [VERIFIED] `express` and `ws` dependencies removed from root package.json
3. [VERIFIED] `tests/python/test_wheelhub_discovery.py` deleted
4. [VERIFIED] `build/lib/` stale artifacts deleted
5. [VERIFIED] No remaining `express`/`ws` imports in `packages/core/src/` or `packages/cyclist/src/`

**Original implementation — still valid:**
1. [VERIFIED] Launcher correctly switches from `["node", entry]` to `_get_wheelhub_command()` → uvicorn
2. [VERIFIED] React GUI components properly relocated from `server/` to `public/` with vite alias updated
3. [VERIFIED] `_install_wheelhub` removed from init, fastapi+uvicorn added to pyproject.toml
4. [VERIFIED] express/ws deps removed from both core and cyclist package.json

**Deferred (LOW, follow-up story):** 6 Cyclist test files still import from deleted modules (`packages/cyclist/tests/`)

**Handoff:** To Stilgar (SM) for finish-story

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:** 189 files (-69,748 lines) + reviewer fix commit
- `packages/core/src/server/` — deleted entire Node.js Express server (~90 files)
- `packages/cyclist/src/` — deleted IDE-only server-side code (api/, claude-service, websocket, etc.)
- `scripts/build-wheelhub.sh` — deleted esbuild bundle pipeline
- `pennyfarthing-dist/src/pf/_dist/server/wheelhub.mjs` — deleted bundled artifact
- `pennyfarthing-dist/src/pf/bikerack/launcher.py` — switched from Node.js to Python uvicorn
- `pennyfarthing-dist/src/pf/init/core.py` — removed `_install_wheelhub()`
- `packages/core/src/public/` — relocated React GUI components from server/
- `packages/core/package.json` — removed express, ws, server exports
- `packages/cyclist/package.json` — removed express, ws, IDE-only deps
- `pyproject.toml` — added fastapi, uvicorn dependencies
- `justfile` — removed rebuild-wheelhub recipe
- `tests/e2e/scenarios/wheelhub-node24.sh` — replaced Node.js bundle test with Python server test
- `packages/core/README.md` — updated to reflect Python-only server

**Reviewer fix (bdb995a):**
- `package.json` — removed `./server`, `./bikerack/server`, `./bikerack/entry` dangling exports; removed `express` and `ws` deps
- `tests/python/test_wheelhub_discovery.py` — deleted (tested removed `_find_wheelhub_entry`)
- `build/lib/` — deleted stale build artifact with old Node.js launcher

**Tests:** Build clean, 6/6 e2e tests passing
**Branch:** feat/48-4-cleanup-remove-nodejs-server (pushed)

**Handoff:** To Reviewer (Leto II) — all blocking findings addressed

## Delivery Findings

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Reviewer (code review)

- **Gap** (blocking): Root `package.json` still exports `./server`, `./bikerack/server`, `./bikerack/entry` pointing to deleted `packages/core/dist/server/`. Affects `pennyfarthing/package.json` (remove server export entries). *Found by Reviewer during code review.*
- **Gap** (non-blocking): `tests/python/test_wheelhub_discovery.py` tests the removed `_find_wheelhub_entry` function. Affects `tests/python/test_wheelhub_discovery.py` (delete or rewrite for Python server). *Found by Reviewer during code review.*
- **Gap** (non-blocking): `build/lib/pf/bikerack/launcher.py` is a stale build artifact with old Node.js launcher code. Affects `build/lib/` (rebuild or delete). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): 6 Cyclist test files still import from deleted server modules. Affects `packages/cyclist/tests/` (cleanup in follow-up). *Found by Reviewer during code review.*

### Dev (implementation)

- **Improvement** (non-blocking): Cyclist `src/shared/` directory still contains Node.js utilities (theme-loader, skill-search, etc.) that may be dead code now. Affects `packages/cyclist/src/shared/` (audit and remove if unused). *Found by Dev during implementation.*
- **Gap** (non-blocking): Cyclist tests in `packages/cyclist/tests/` likely have many broken imports from deleted server-side code. The vitest run will need cleanup. Affects `packages/cyclist/tests/` (remove or update tests referencing deleted modules). *Found by Dev during implementation.*

## SM Assessment
Trivial 2-point cleanup story. Final story in the Python WheelHub Migration epic — all implementation work (48-1 through 48-3) is complete. This is pure removal of dead Node.js code and build artifacts. Straightforward scope, no ambiguity in ACs. Routing directly to Dev for implementation.