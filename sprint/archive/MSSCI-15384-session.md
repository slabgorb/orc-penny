# Story 117-9: Fix pennyfarthing cyclist CLI command — points to wrong entry file

**Jira:** MSSCI-15384
**Epic:** 117 — Consumer Install — Fix v11.x postinstall gaps
**Points:** 2
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** fix-cyclist-cli-entry
**Assigned:** keith.avery@1898andco.io

---

## Acceptance Criteria

- `npx pennyfarthing cyclist` successfully launches BikeRack (web mode) without silent exit
- Command respects process.versions.electron detection for Electron mode vs web mode
- No code regressions in existing cyclist functionality

## Context

During clean E2E installation of orc-ax (2026-02-19), the `npx pennyfarthing cyclist` command was found to silently exit with code 0 and no output.

**Root Cause:** `packages/core/src/cli/commands/cyclist.ts` line 174 spawns `node dist/server.js`, but server.js is a library module that only exports `createTerminalServer()` without actually calling it. The spawned process exits immediately.

**Correct Entry Points:**
- Web/BikeRack mode: `dist/bikerack.js` (calls createTerminalServer() + .listen())
- Electron mode: `electron dist/main.js` (checks process.versions.electron)

## Technical Approach

1. Fix `packages/core/src/cli/commands/cyclist.ts` line 174 to point at the correct entry file
2. Consider two approaches:
   - Option A: Point cyclist.ts at bikerack.js for web mode
   - Option B: Have server.js detect non-Electron and auto-start
3. Verify spawned process launches without errors
4. Test both web and Electron modes

---

## Session Log

### Setup — SM
- Story claimed in Jira (MSSCI-15384 → In Progress)
- Session created
- Workflow: trivial (SM → Dev → Reviewer → SM)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/cli/commands/cyclist.ts` — changed entry file from `server.js` to `bikerack.js` (line 174)
- `packages/core/src/cli/commands/cyclist.test.ts` — updated mock files and assertions to match `bikerack.js`

**Root Cause:** `cyclistCommand()` spawned `node dist/server.js`, but `server.ts` is a library module that only exports `createTerminalServer()` without invoking it. The process exited immediately with code 0.

**Fix:** Point at `dist/bikerack.js` which is the actual entry point — it calls `createTerminalServer()` and `.listen()`.

**Tests:** 18/18 passing (GREEN)
**Branch:** fix-cyclist-cli-entry (pushed)

**Handoff:** To review phase

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** CLI `--port` option → `PORT` env var → spawned `bikerack.js` (note: bikerack reads `BIKERACK_PORT`, not `PORT` — pre-existing mismatch, not introduced by this fix)
**Pattern observed:** Minimal surgical fix — single line change at `cyclist.ts:174`, tests updated to match. Option A (point at bikerack.js) chosen correctly over Option B (modify server.js).
**Error handling:** `child.on('error')` at `cyclist.ts:205` correctly catches spawn failures. No new error paths introduced.
**Security:** No new inputs, no auth changes, no user-facing data paths affected.
**Tests:** 18/18 passing. Assertions correctly updated from `server.js` to `bikerack.js`. Mock file setup matches.

| Severity | Issue | Location | Action |
|----------|-------|----------|--------|
| [MEDIUM] | PORT env mismatch (pre-existing) | cyclist.ts:186 vs bikerack.ts:10 | Future story — not introduced here |
| [LOW] | Variable `serverPath` naming | cyclist.ts:174 | Non-blocking cosmetic |

**Handoff:** To SM (Drummer) for finish-story