# Story 117-6: Fix getDistDir() wrong path resolution in npm-installed mode

**Jira:** MSSCI-15319
**Epic:** 117 — Consumer Install — Fix v11.x postinstall gaps
**Points:** 2
**Type:** bug
**Priority:** P0
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** fix/117-6-getdistdir-path-resolution

---

## Description

The `getDistDir()` function resolves the wrong path when running in npm-installed mode (consumer projects). This is a bug affecting consumer installs.

## Acceptance Criteria

- [ ] `getDistDir()` returns correct path in npm-installed mode
- [ ] `getDistDir()` still works correctly in development/monorepo mode
- [ ] Bug is verified fixed in both modes

## Technical Context

- Epic context: `sprint/context/context-epic-117.md`
- This is part of the v11.x postinstall gap fixes
- Related stories: 117-1 (pyproject.toml), 117-2 (hook generation), 117-5 (index.html + ws dep)

---

## SM Assessment

Story is a P0 bug fix, 2 points, trivial workflow. Straight to Dev.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/server/paths.ts` - Added npm-installed path check before generic `/dist` fallback

**Root Cause:** When `__dirname` is `dist/server/`, the `__dirname.includes('/dist')` check returned `dist/server/` directly. `join(getDistDir(), 'public')` then resolved to `dist/server/public/` (only has index.html) instead of `dist/public/` (has Vite CSS/JS output). This caused 404s for all React assets.

**Fix:** Added explicit check: when `__dirname` ends with `/server` and `../public` exists, return the parent (`dist/`) so static assets resolve correctly. Preserves monorepo behavior (cyclist check fires first) and dev mode (tsx fallback).

**Tests:** 2908/2908 passing (1 skipped, pre-existing)
**Branch:** fix/117-6-getdistdir-path-resolution (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `getDistDir()` → `join(getDistDir(), 'public')` → `express.static(distPublicDir)` — path now resolves correctly in npm-installed mode
**Pattern observed:** Priority-ordered path checks (monorepo → npm → generic) at `paths.ts:245-262`, new check correctly inserted between monorepo and generic
**Error handling:** `existsSync` returns false on error, `join(__dirname, '..')` always valid, function always returns string — no null/undefined possible
**Security:** No user input in path construction, all paths derived from compile-time `__dirname`
**Observations:**
- [VERIFIED] npm mode: returns `dist/` instead of `dist/server/` — CSS/JS assets served correctly
- [VERIFIED] monorepo mode: cyclist check fires first, unaffected by new code
- [VERIFIED] cyclist's own `getDistDir()` unaffected (Electron preload only)
- [LOW] `endsWith('/server')` could be `path.basename()` but consistent with existing patterns
- [VERIFIED] 2908/2908 core tests passing, lint clean, working tree clean

**Handoff:** To SM for finish-story