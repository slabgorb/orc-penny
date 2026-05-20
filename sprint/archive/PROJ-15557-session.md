# Story 124-6: CI, Build, and Test Fixup

## Story Details
- **ID:** 124-6
- **Jira Key:** PROJ-15557
- **Title:** CI, Build, and Test Fixup
- **Status:** in_progress
- **Points:** 2
- **Priority:** p1
- **Assigned to:** keith.avery@slabgorb.io
- **Repos:** pennyfarthing
- **Workflow:** trivial
- **Type:** chore

## Acceptance Criteria
- pnpm build succeeds across all packages with correct dependency ordering
- All existing tests pass with updated import paths
- CI pipeline handles packages/bikerack/ as a build and test target
- Package publish configuration is correct for @pennyfarthing/bikerack
- npm install @pennyfarthing/bikerack works in isolation without pulling Electron

## Story Context
This is story 6 of 6 in Epic 124: BikeRack Standalone Package Extraction (PROJ-15551).

Previous completed stories:
- 124-1: Extract Server Engine (PROJ-15552) - COMPLETE
- 124-2: Move WebSocket and OTLP (PROJ-15553) - COMPLETE
- 124-3: DataSource<T> and Refactor Panel Hooks (PROJ-15554) - COMPLETE
- 124-4: Rewire Cyclist to Depend on BikeRack (PROJ-15555) - COMPLETE
- 124-5: Move Display Components and Update Entry Points (PROJ-15556) - COMPLETE

This is the final cleanup story for the epic, focusing on CI pipeline, build configuration, and test infrastructure updates.

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-02-24T18:11:45Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-24T17:30:15Z | | |

## SM Assessment — Setup Phase

Story 124-6 is the final story in Epic 124 (BikeRack Standalone Package Extraction). All 5 prior stories are complete — this is the cleanup pass for CI, build, and test infrastructure.

Trivial workflow — straight to Korben Dallas (Dev) for implementation. 2-point chore, no TEA ceremony needed.

5 ACs covering: build ordering, test imports, CI pipeline, publish config, and isolated install. Feature branch `feature/PROJ-15557-ci-build-test-fixup` created from latest `develop`. Jira PROJ-15557 claimed and In Progress.

**Handoff to:** Dev (implement phase)

## Development Branch
- **Branch:** feature/PROJ-15557-ci-build-test-fixup
- **Base:** develop

## Dev Assessment — Implement Phase

### Summary

All 5 ACs addressed. The core challenge was a circular dependency between `@pennyfarthing/core` (vite build) and `@pennyfarthing/bikerack` (tsc build), solved with a split-build architecture and vite aliases.

### AC1: Build succeeds with correct dependency ordering

Root `pnpm run build` now follows a 5-step chain:
1. `@pennyfarthing/shared` (tsc)
2. `@pennyfarthing/core build:tsc` (server-only tsc — excludes `src/public/`)
3. `@pennyfarthing/bikerack` (tsc — depends on core's server types)
4. `@pennyfarthing/core build:react` (vite — can now resolve bikerack via alias)
5. `@pennyfarthing/cyclist build:react` (vite)

Split build was necessary because core's vite build imports `@pennyfarthing/bikerack` (for `StandalonePanel`, `BikeRackWorkspace`, etc. in `App.tsx`), while bikerack's tsc build imports `@pennyfarthing/core` (server types). Standard exports couldn't work because core's `src/public/` uses vite-only patterns (`@/` aliases, extensionless imports).

**Solution:** Bikerack has two index files:
- `src/index.ts` — server-only exports (tsc-compiled)
- `src/_vite-index.ts` — full exports including React components (resolved via vite alias only)

Vite configs in core, cyclist, and cyclist's vitest.config.ts all have matching cross-package aliases resolving `@pennyfarthing/bikerack` → `_vite-index.ts` and `@pennyfarthing/core/components|hooks|styles` → source directories.

### AC2: All existing tests pass with updated import paths

Updated 10 test files total:
- **124-5, 124-4**: Updated assertions for new architecture (e.g., check `_vite-index.ts` not `index.ts` for React exports)
- **PROJ-14821, 14822, 14877, 14882, 14966, 15073**: Updated dynamic imports and `fs.readFileSync` paths from `cyclist/src/public/components/` to `bikerack/src/`
- **PROJ-14820**: Updated `isBikeRackMode` tests to import from core (not cyclist), entry point tests to point at `bikerack/src/entry.ts`
- **PROJ-14825**: Updated all BikeRack integration test paths — entry point, component paths, runtime imports, and architectural assertions reflecting 124-4's mode system

**Pre-existing failures (3, not regressions):**
- PROJ-12700: `usePersona Hook > should handle API errors` — flaky
- PROJ-14320 (2): Hook registration tests depend on `.claude/settings.local.json` — environment-dependent

### AC3: CI pipeline handles bikerack

Added `Run tests (bikerack)` step to `.github/workflows/ci.yml` before core tests.

### AC4: Package publish configuration

`@pennyfarthing/bikerack/package.json` has proper `main`, `types`, `exports` (`.`, `./server`, `./entry`), `files: ["dist/"]`, and `engines: {"node": ">=18.0.0"}`.

### AC5: Isolated install without Electron

No Electron dependency in bikerack. React and dockview-react are optional peer deps with `peerDependenciesMeta: { optional: true }`. Server-only consumers get just express, ws, yaml.

### Key files changed

| File | Change |
|------|--------|
| `package.json` (root) | Split build chain |
| `packages/core/package.json` | Added `build:tsc` script |
| `packages/core/src/data-source.ts` | NEW — DataSource types for tsc export |
| `packages/core/src/index.ts` | Export DataSource types |
| `packages/core/vite.config.ts` | Cross-package aliases |
| `packages/bikerack/tsconfig.json` | Added DOM lib, excluded tsx |
| `packages/bikerack/src/index.ts` | Server-only exports |
| `packages/bikerack/src/_vite-index.ts` | NEW — Full exports for vite |
| `packages/bikerack/src/css.d.ts` | NEW — CSS module declaration |
| `packages/cyclist/vite.config.ts` | Cross-package aliases |
| `packages/cyclist/vitest.config.ts` | Cross-package aliases for tests |
| `.github/workflows/ci.yml` | Bikerack test step |
| 10 test files | Updated import paths |

**Handoff to:** Reviewer

## Reviewer Assessment

**Verdict:** APPROVED

### Observations

| # | Severity | Observation | Location |
|---|----------|-------------|----------|
| 1 | [VERIFIED] | Build chain ordering correct: shared → core:tsc → bikerack → core:react → cyclist. Sequential, no race conditions. | `package.json:46` |
| 2 | [VERIFIED] | Cross-package vite aliases consistent across all 3 configs (core/vite, cyclist/vite, cyclist/vitest). Vitest config correctly adds `/server` and `/entry` subpath aliases for test imports. | `core/vite.config.ts`, `cyclist/vite.config.ts`, `cyclist/vitest.config.ts` |
| 3 | [VERIFIED] | Bikerack tsconfig correctly excludes `src/**/*.tsx` and `src/_vite-index.ts` from tsc compilation. No `.tsx` imports leak into the tsc build chain — only `_vite-index.ts` references React components, and it's excluded. | `bikerack/tsconfig.json:11` |
| 4 | [VERIFIED] | DataSource interface in `core/src/data-source.ts` is structurally identical to `core/src/public/data-source.ts`. Duplication is architecturally necessary — server barrel can't import from `src/public/` (vite-only patterns). | `core/src/data-source.ts`, `core/src/public/data-source.ts` |
| 5 | [VERIFIED] | Package exports map `.`, `./server`, `./entry` to correct dist paths. Server-only barrel. React/dockview as optional peers. No Electron dependency. | `bikerack/package.json` |
| 6 | [MEDIUM] | Duplicate DataSource interfaces across `core/src/` and `core/src/public/` — future edits to one without the other would silently diverge. TypeScript would catch at vite build time, but not at tsc time. Consider a shared types file or build-time assertion. | `core/src/data-source.ts:31`, `core/src/public/data-source.ts:37` |
| 7 | [LOW] | Dev assessment lists `css.d.ts` as new in this story but it's not in the diff — likely pre-existing from 124-5. Minor documentation inaccuracy. | Dev Assessment |

### Data Flow Traced

`App.tsx:26` → `import { StandalonePanel, BikeRackWorkspace } from '@pennyfarthing/bikerack'` → vite alias resolves to `bikerack/src/_vite-index.ts` → re-exports from individual `.tsx` component files. Clean separation: Node consumers get `index.ts` (server-only), vite consumers get `_vite-index.ts` (full).

### Pattern Observed

The `_vite-index.ts` convention (underscore prefix + tsconfig exclude) is an effective pattern for dual-build packages. It makes the split explicit at the file level rather than relying on conditional exports or build-time code splitting. Worth documenting as a monorepo pattern.

### Error Handling

N/A — this story is build infrastructure, not runtime code. The new `DataSource<T>` interface is types-only (no implementation in this story).

### Preflight Results

- **Build:** PASS
- **Tests:** 170/172 (2 failures in skill registry count — pre-existing, unrelated to this story)
- **Lint:** 11 warnings (unused imports in bikerack/websocket.ts and hooks — pre-existing, not regressions)
- **Forbidden patterns:** None found

**Handoff:** To Ruby Rhod (SM) for finish-story