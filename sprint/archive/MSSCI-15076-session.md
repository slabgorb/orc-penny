# Story 98-18: Move React UI build pipeline to core

## Story Details
- **ID:** 98-18
- **Jira Key:** MSSCI-15076
- **Workflow:** tdd
- **Epic:** 98 (MSSCI-14697) - Safe Install, Upgrade, and Namespace Isolation
- **Repository:** pennyfarthing
- **Assignee:** Keith Avery

## Story Description

Move the React UI build pipeline and static assets from Cyclist (packages/cyclist/) into core (packages/core/). This continues the work from 98-17 which already moved the web server and API layer into core. The build currently uses Vite in packages/cyclist/ to build React components. Static assets (HTML, CSS, JS bundles) need to serve from core's standalone server mode.

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-14T20:30:00Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-14 | 2026-02-14 | <1m |
| red | 2026-02-14 | 2026-02-14T18:41:05Z | <1h |
| green | 2026-02-14T18:41:05Z | 2026-02-14T19:05:32Z | 24m |

## Context

### Predecessor Work
- **98-17:** Move Cyclist server to core (COMPLETED) — moved WheelHub server and API layer into core's standalone mode

### Current State
- Cyclist uses Vite for building React components from `packages/cyclist/src/`
- Build output goes to `packages/cyclist/dist/`
- UI assets are served via Cyclist's bundled server
- Need to migrate this build pipeline to `packages/core/`

### Acceptance Criteria
- [ ] Vite build pipeline moved from Cyclist to Core
- [ ] Static assets (HTML, CSS, JS) build to Core distribution
- [ ] React components can be built independently from Electron
- [ ] Core's standalone server serves migrated UI assets
- [ ] All tests passing
- [ ] Build integration tested end-to-end

---

## TEA Assessment

**Tests Required:** Yes
**Test File:** `packages/core/src/server/ui-build.test.ts` (new)

**Tests Written:** 20 tests covering 5 of 6 ACs (AC5 "all tests passing" is meta)

| AC | Tests | RED Status |
|----|-------|------------|
| AC1: Vite pipeline | 4 | 4 FAIL — no vite.config.ts, no build:react script, no deps |
| AC2: Static assets | 4 | 4 FAIL — no src/public/, no dist/public/ |
| AC3: Electron independence | 3 | 1 FAIL, 2 PASS (correct: core has no electron) |
| AC4: Server serves UI | 4 | 4 FAIL — no index.html in core yet |
| AC6: E2E integration | 5 | 5 FAIL — no build output, no postcss config |

**Status:** RED (18 failing, 2 passing — all failures on assertions, not errors)

**Key Implementation Notes for Dev:**
1. Copy `vite.config.ts` from cyclist — adapt paths for core root
2. Copy `src/public/` from cyclist — index.html, index.tsx, components, styles
3. Add Vite + React + PostCSS deps to core package.json
4. Add `build:react` script to core package.json
5. Add `postcss.config.js` for Tailwind v4 processing
6. Core server.ts already serves `dist/public/` (from 98-17) — no server changes needed
7. `getPublicDir()` in paths.ts needs `src/public/` to exist for correct resolution
8. Cyclist should continue to have its own Vite build for Electron packaging

**Handoff:** To Dev for implementation

---

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `packages/core/vite.config.ts` — new Vite build config for React UI (adapted from cyclist)
- `packages/core/postcss.config.js` — PostCSS with @tailwindcss/postcss + autoprefixer
- `packages/core/tailwind.config.js` — Tailwind v4 config with Cyclist color/font mappings
- `packages/core/package.json` — added build:react script, React/UI deps (15 @radix-ui, dockview, etc.)
- `packages/core/tsconfig.json` — exclude src/public from TypeScript (Vite handles it)
- `packages/core/src/public/` — canonical React source (74 components, 34 hooks, 14 utils)
- `packages/cyclist/vite.config.ts` — now builds from `../core/src/public/` instead of local
- `packages/cyclist/tailwind.config.js` — content paths point to core
- `packages/cyclist/src/public/` — removed React source (kept index.html + images for Electron)

**Tests:** 96/96 passing (GREEN) — 20 ui-build + 76 server
**PR:** #887 — feat(98-18): move React UI build and static assets into core
**Branch:** feat/98-18-move-react-ui-build-to-core (pushed)

**Build Verification:**
- Core Vite: 2000 modules → 814KB JS, 166KB CSS
- Cyclist Vite: 2000 modules → 814KB JS, 166KB CSS (identical, builds from core source)
- Core tsc: clean
- Cyclist tsc: clean

**Handoff:** To Reviewer for code review

---

## Dev Assessment (Review Fix Round)

**All reviewer findings addressed:**

| Finding | Fix |
|---------|-----|
| [CRITICAL] Cyclist build:commands path | `generate-slash-commands.js:236` → output to `../../core/src/public/utils/` |
| [HIGH] Merge conflicts | Rebased on main, changed PR base from `develop` to `main` |
| [MEDIUM] workspace:^ protocol | Restored in core and cyclist package.json |
| [MEDIUM] React deps scope | Moved 15 UI packages from dependencies to devDependencies in core |

**Additional fix:** Created symlinks in `cyclist/src/public/` → `core/src/public/` for components, hooks, utils, styles, contexts, css, lib, types, App.tsx, index.tsx. Updated `vitest.config.ts` alias and root. Restores cyclist test baseline (12 pre-existing failures, same as main).

**Tests:** 20/20 ui-build GREEN, server tests GREEN, cyclist baseline matches main
**Build:** Full monorepo build passes (shared → core → cyclist)
**PR:** #887 — MERGEABLE, targets main

**Handoff:** To Reviewer for re-review

---

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [CRITICAL] | Cyclist `build:commands` writes to removed path — full cyclist build fails ENOENT | `cyclist/scripts/generate-slash-commands.js:236` | Update output path to core |
| [HIGH] | PR has merge conflicts (`mergeable: CONFLICTING`) | PR #887 | Rebase on main, resolve conflicts |
| [MEDIUM] | `workspace:^` protocol replaced with hardcoded `^10.4.0` | `core/package.json`, `cyclist/package.json` | Restore `workspace:^` |
| [MEDIUM] | React/UI deps in `dependencies` instead of `devDependencies` — Vite bundles all | `core/package.json` | Move to devDependencies |
| [LOW] | Tailwind config duplication between core and cyclist | Both `tailwind.config.js` | Consider shared base config |

**Verified Good:**
- XSS prevention: `parseMarkdown()` escapes HTML before processing (`markdown.ts:182`)
- Electron independence: core externalizes electron, no electron deps
- Core Vite pipeline: source→build→output wiring correct
- Cyclist Vite redirect: root/alias/input all point to `../core/src/public/`
- node-pty/xterm removal: clean, no remaining imports
- App.tsx changes: additive improvements (BikeRack mode, layout persistence)

**Data flow:** User input → WS → parseMarkdown (escapeHtml first) → dangerouslySetInnerHTML. Safe.

**Handoff:** Back to Dev for fixes

---

## Dev Assessment (Review Fix Round 2)

**Reviewer findings re-examined:**

| Finding | Status | Evidence |
|---------|--------|----------|
| [CRITICAL] build:commands path | Already fixed in `be04ed08a` | `generate-slash-commands.js:236` → `../../core/src/public/utils/` |
| [HIGH] Merge conflicts | Already resolved | PR is `MERGEABLE` per `gh pr view 887` |
| [MEDIUM] workspace:^ protocol | Already restored in `be04ed08a` | Both package.json files use `workspace:^` |
| [MEDIUM] React deps in devDependencies | Already moved in `be04ed08a` | All 15 @radix-ui + React in devDependencies (lines 76-112) |
| [LOW] Tailwind config duplication | Advisory (consider) | No action required |

**Additional fix this round:**
- `packages/core/src/server/paths.ts` — `getPublicDir()` path traversal: added compiled-dist check (`__dirname, '..', '..', 'src', 'public'`) for when running from `dist/server/`. Previous code only went up one level (for Electron asar), missing the two-level case.

**Tests:** 20/20 ui-build passing (GREEN)
**PR:** #887 — MERGEABLE, targets main
**Branch:** feat/98-18-move-react-ui-build-to-core (pushed `00c8831ae`)

**Handoff:** To Reviewer for re-review

---

## Reviewer Assessment (Round 3)

**Verdict:** APPROVED

**Previous findings verification (Round 2 re-review):**

| Finding | Verified | Evidence |
|---------|----------|----------|
| [CRITICAL] build:commands path | FIXED | `generate-slash-commands.js:236` → `../../core/src/public/utils/` confirmed |
| [HIGH] Merge conflicts | FIXED | `gh pr view 887` → `MERGEABLE` |
| [MEDIUM] workspace:^ | FIXED | Both package.json files use `workspace:^` |
| [MEDIUM] React deps scope | FIXED | All @radix-ui + React in `devDependencies` (core:75-112) |

**New fix this round:**
- [VERIFIED] `getPublicDir()` compiled-dist traversal at `paths.ts:187-191` — adds `__dirname/../../../src/public` check for `dist/server/paths.js` case. Priority order correct: asar → compiled → cwd → fallback. No conflicts between checks.

**Mandatory checklist:**
1. [VERIFIED] XSS: `escapeHtml()` at `markdown.ts:182` runs BEFORE markdown processing → `dangerouslySetInnerHTML` safe
2. [VERIFIED] Wiring: `server.ts:100` serves `publicDir` (HTML), `server.ts:105` serves `distPublicDir` (Vite JS/CSS)
3. [VERIFIED] Pattern: Dual static serving — `src/public/` for dev HTML template, `dist/public/` for build output
4. [VERIFIED] Electron independence: `external: ['electron']` in `vite.config.ts:28`, no electron deps in core
5. [VERIFIED] Cyclist redirect: `vite.config.ts:9` root → `../core/src/public`, all symlinks valid
6. [VERIFIED] Symlinks: 10 symlinks in `cyclist/src/public/` → `../../../core/src/public/*` confirmed

**Data flow traced:** User input → WebSocket → `parseMarkdown(escapeHtml(cleaned))` → `dangerouslySetInnerHTML`. HTML escaped at entry.

| Severity | Issue | Location | Status |
|----------|-------|----------|--------|
| [MEDIUM] | pnpm-lock.yaml stale after dep scope move | `pnpm-lock.yaml` | Needs `pnpm install` before merge |
| [LOW] | console.log in moved React files | 23+ files | Pre-existing, not introduced by PR |

**Tests:** 20/20 ui-build GREEN
**No Critical or High issues.**

**Handoff:** To SM for finish-story (after lock file update)

---

## Handoff History
| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| red (tea) | green (dev) | tests_fail | PASSED | 2026-02-14T18:41:05Z |
| green (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-14T19:05:32Z |
| review (reviewer) | green (dev) | review_reject | PASSED | 2026-02-14T19:10:15Z |
| green (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-14T19:17:43Z |
| green (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-14T19:30:00Z |
| review (reviewer) | finish (sm) | review_approve | PASSED | 2026-02-14T20:30:00Z |
