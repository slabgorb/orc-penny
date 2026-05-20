# Story 117-5: Ship index.html and add ws dependency in @pennyfarthing/core npm package

## Story Details
- **ID:** 117-5
- **Jira Key:** PROJ-15318
- **Workflow:** trivial
- **Repo:** pennyfarthing

## Overview

WheelHub fails to start or serve its UI when consumed as an npm dependency on Node v24 due to two issues:

1. **Missing `index.html` in npm package:** `packages/core/src/public/` is not in the `files` array in `package.json`, so the HTML template doesn't ship with the npm package.
2. **Missing `ws` ESM dependency:** `ws` is not listed as a dependency of `@pennyfarthing/core`. Transitive `ws@7` (via `simple-websocket`) is CJS-only and breaks Node v24 ESM imports.

### Acceptance Criteria

1. Add `packages/core/src/public/` to the `files` array in `@pennyfarthing/core`'s `package.json`
2. Add `ws@^8` to `@pennyfarthing/core`'s `dependencies`
3. Verify the built package includes `index.html`
4. Verify npm install resolves `ws@^8` as an ESM-compatible version

## Workflow Tracking

**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-02-19T12:26:54Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-19T12:19:50Z | 2026-02-19T12:20:23Z | 33s |
| implement | 2026-02-19T12:20:23Z | 2026-02-19T12:23:40Z | 3m 17s |
| review | 2026-02-19T12:23:40Z | 2026-02-19T12:26:54Z | 3m 14s |
| finish | 2026-02-19T12:26:54Z | - | - |

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/package.json` — added `"src/public/"` to `files` array

**Notes:**
- AC #1: Added `src/public/` to files array — `npm pack --dry-run` confirms `src/public/index.html` now ships
- AC #2: `ws@^8.19.0` was already present in dependencies (no change needed)
- AC #3: Verified via `npm pack --dry-run` — index.html included
- AC #4: `ws@^8.19.0` already resolves to ESM-compatible version

**Tests:** 2908/2908 passing (GREEN), 1 intentionally skipped
**Branch:** feat/117-5-ship-index-html-ws-dep (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `getPublicDir()` at `paths.ts:188` → `compiledPublic = join(__dirname, '..', '..', 'src', 'public')` → resolves to `src/public/` in npm-installed `node_modules/@pennyfarthing/core/` → `index.html` found by `server.ts:123` (safe — `__dirname`-relative joins, no user input)
**Pattern observed:** Minimal change — one line added to `files` array at `package.json:55`
**Error handling:** `server.ts:129-131` returns 404 if `index.html` not found — graceful degradation preserved
**Low finding:** Shipping entire `src/public/` (145 files) when only `index.html` is needed at runtime — future optimization to copy to `dist/` during build
**Tests:** 2908/2908 passing, 0 regressions

**Handoff:** To SM for finish-story

## Session State
- **Branch:** feat/117-5-ship-index-html-ws-dep
- **Session File:** .session/117-5-session.md
- **Jira Status:** In Progress (claimed)