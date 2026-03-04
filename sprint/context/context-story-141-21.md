---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-21: Extract Hardcoded Values and Relocate Misplaced Business Logic

## Business Context

Four distinct cleanup items grouped into one story because each is a 2-point-or-less move with no shared dependencies.

**Agent evaluation in the wrong package.** `packages/cyclist/src/agent-evaluation.ts` (644 lines) is a full Job Fair benchmarking engine — it computes completion rates, error rates, tool efficiency, regression alerts, persona comparisons, trend detection, and baseline comparisons against stored Job Fair profiles. None of this is GUI rendering logic. It lives in cyclist because it was written there during Story 19-9, before `packages/benchmark` was planned. The correct home is either a new `packages/benchmark` package or the `pf benchmark` CLI in `pennyfarthing-dist/pf/`. As long as the cyclist UI and the core server stub can still call the evaluation API, the location does not matter to callers.

**Slug generation duplicated in two TypeScript files.** `toSlug()` and `oceanSuffix()` appear verbatim in both `packages/core/src/server/pennyfarthing.ts` (lines 47–56) and `packages/core/src/server/api/theme-agents.ts` (lines 41–50). Both are private functions. A third call site in `theme-agents.ts`'s `getFullThemeData` (line 103) computes the slug inline using the same expression. This is three-way duplication. A shared utility — either in `packages/core/src/server/` as a `slug-utils.ts` or promoted into `packages/shared/` — should be the single source.

**Token limits baked into source code.** `packages/cyclist/src/usage-stats.ts` lines 113–118 declare:
```
const MAX_TOKENS_PER_BLOCK = 217_000_000;   // empirically derived
const WEEKLY_MAX_TOKENS = 2_850_000_000;    // empirically derived
```
The comments acknowledge these are empirically derived — they will change when Anthropic changes plan limits. These belong in a config location that can be updated without a TypeScript rebuild (e.g., a key in `.pennyfarthing/config.local.yaml`, a `pf` CLI env var, or defaults in the `pf` CLI's Python layer with a TypeScript override path).

**Settings migration unreachable from Python.** `packages/core/src/server/settings.ts` contains `migrateSettings()` (lines 192–240), which handles four legacy config shapes: `permission_mode: 'turbo'`, `handoff_mode: 'auto'/'manual'`, and `auto_handoff: boolean`. This function is TypeScript-only. The `pf` Python CLI reads `.pennyfarthing/config.local.yaml` directly — if a project has a legacy config, Python will see stale keys and either fail silently or misread settings. Python needs a migration path that maps the same four legacy formats to the current schema.

## Technical Guardrails

**Agent evaluation — primary file:**
- `pennyfarthing/packages/cyclist/src/agent-evaluation.ts` — 644 lines of scoring/aggregation/regression/Job Fair integration; this is the file to move
- `pennyfarthing/packages/core/src/server/agent-evaluation.ts` — 27-line stub (already a stub; the real logic is in cyclist)
- `pennyfarthing/packages/core/src/benchmark/benchmark-integration.ts` — benchmark result reading already exists in core; the new home for evaluation logic should be adjacent or in a new package at `packages/benchmark/`

There is no `packages/benchmark/` directory yet. If creating one: follow the existing monorepo conventions — `package.json` with `"name": "@pennyfarthing/benchmark"`, pnpm workspace entry, TypeScript build, Node native test runner.

**Slug duplication — files to change:**
- `pennyfarthing/packages/core/src/server/pennyfarthing.ts` — lines 47–60 define `toSlug`, `oceanSuffix`, and `generateSlug` as private functions
- `pennyfarthing/packages/core/src/server/api/theme-agents.ts` — lines 41–50 redefine `toSlug` and `oceanSuffix`; line 103 uses them inline via `toSlug(shortName)-${oceanSuffix(ocean)}`

The slug functions are also used in `packages/cyclist/src/pennyfarthing.ts` (lines 100–116) but that file is the cyclist counterpart to the core server file — after Story 98-17 extracted the server module, these two files share logic. Check whether cyclist's pennyfarthing.ts is still a live code path or whether it delegates to core (as `packages/cyclist/src/api/theme-agents.ts` does with `export * from '@pennyfarthing/core/...'`).

**Token limits — file to change:**
- `pennyfarthing/packages/cyclist/src/usage-stats.ts` — lines 113–118; the constants `MAX_TOKENS_PER_BLOCK` and `WEEKLY_MAX_TOKENS` are the only targets; the polling logic, ccusage integration, and broadcast pattern are out of scope

**Settings migration — primary files:**
- `pennyfarthing/packages/core/src/server/settings.ts` — `migrateSettings()` at lines 192–240 is the TypeScript reference; the four migration paths documented in the JSDoc are the spec
- `pennyfarthing/pennyfarthing-dist/pf/` — Python CLI package where the migration equivalent must be added; the correct module is likely `hooks/` or a new `settings.py` alongside the existing pf CLI modules

**Build and test commands:**
```
cd pennyfarthing/packages/core && pnpm run build
cd pennyfarthing/packages/core && npm test
cd pennyfarthing/packages/cyclist && pnpm run build
cd pennyfarthing/packages/cyclist && npx vitest run
```

**TypeScript config:** `pennyfarthing/tsconfig.base.json` — `"strict": true`. Use `.js` extensions in all relative imports.

## Scope Boundaries

**In scope:**
- Move `packages/cyclist/src/agent-evaluation.ts` (the real 644-line implementation) into `packages/benchmark/` or `packages/core/src/benchmark/` alongside `benchmark-integration.ts`; update the core server stub to import from the new location if the move affects it
- Deduplicate `toSlug` + `oceanSuffix` into a single shared utility file within `packages/core/src/server/` (or `packages/shared/`); update all three call sites in `pennyfarthing.ts` and `theme-agents.ts`
- Move `MAX_TOKENS_PER_BLOCK` and `WEEKLY_MAX_TOKENS` from hardcoded constants to a config source (a config key with defaults acceptable; a `pf` CLI flag also acceptable); the default values (217M and 2.85B) stay the same
- Add Python-callable settings migration in the `pf` CLI that applies the same four legacy-format transforms as `migrateSettings()` in TypeScript

**Out of scope:**
- Changing any evaluation scoring logic inside `agent-evaluation.ts` — this is a relocation, not a rewrite
- Building a full `packages/benchmark` package beyond what is needed to house `agent-evaluation.ts` (no new CLI commands, no new test harnesses unless needed for AC verification)
- Removing the legacy config keys from existing `.pennyfarthing/config.local.yaml` files — migration should be forward-only (read old, write new on save), not destructive
- Story 141-17's Jira URL extraction from `story-parser.ts` — that is a separate story
- The `pf` CLI `--json` output work from story 141-16 — no dependency on that here
- Any changes to the `pf benchmark` command's user-facing behavior — this story is backend relocation only
- Changing the `usage-stats.ts` polling mechanism, ccusage integration, or feature flag (`CCUSAGE_DISABLED`)

## AC Context

**AC1: `agent-evaluation.ts` moved to `packages/benchmark` or `pf benchmark`**

The full 644-line implementation currently at `packages/cyclist/src/agent-evaluation.ts` must not remain in cyclist. Two destination options:

Option A — `packages/benchmark/` (new package): Create `packages/benchmark/src/agent-evaluation.ts`, add to pnpm workspace (`pnpm-workspace.yaml`), add `package.json` with `"name": "@pennyfarthing/benchmark"`. Cyclist imports change from `./agent-evaluation.js` to `@pennyfarthing/benchmark/dist/agent-evaluation.js` (or re-export via barrel).

Option B — `packages/core/src/benchmark/agent-evaluation.ts`: Simpler; adjacent to `benchmark-integration.ts` which already lives there. Cyclist imports change to `@pennyfarthing/core/dist/benchmark/agent-evaluation.js`.

Either option satisfies the AC. The core server stub (`packages/core/src/server/agent-evaluation.ts`) may be updated to re-export from the new location so the `/api/evaluation` route handler needs no changes.

Testable: after move, `pnpm run build` succeeds in both core and cyclist; the existing evaluation tests (if any accompany the cyclist file) pass in their new location; no file named `agent-evaluation.ts` remains under `packages/cyclist/src/`.

**AC2: Slug generation deduplicated (single source)**

After the change, `toSlug()` and `oceanSuffix()` exist in exactly one location. All existing call sites import from that location rather than defining their own copies. The slug generation behavior must not change — the test for slug correctness is that `toSlug('Hamlet Pierce')` still returns `'hamlet-pierce'` and `oceanSuffix({O:5,C:4,E:2,A:4,N:2})` still returns `'54242'`.

Verify by grepping: `grep -rn "function toSlug\|function oceanSuffix" packages/` should return exactly one file.

**AC3: Token limits moved to config or pf CLI**

After the change, `MAX_TOKENS_PER_BLOCK` and `WEEKLY_MAX_TOKENS` are not module-level `const` literals in `usage-stats.ts`. Instead, `usage-stats.ts` reads the values from a config source (acceptable: a `getTokenLimits()` function from settings, a `pf config get` subprocess call, or constants defined in a separate config file under `.pennyfarthing/`).

Default values remain 217,000,000 and 2,850,000,000 unless overridden. The polling behavior in `fetchUsageFromCcusage()` must continue to compute percentages correctly using whatever the resolved limit values are.

Testable: a unit test can override the config source and verify that `fetchUsageFromCcusage()` computes a different percentage when given a different limit — this was not previously testable because the values were hardcoded private constants.

**AC4: Settings migration callable from Python path**

The Python `pf` CLI must be able to load `.pennyfarthing/config.local.yaml` and apply the same four legacy-format migrations that `migrateSettings()` applies in TypeScript:

1. `permission_mode: turbo` → `permission_mode: accept` + `relay_mode: true`
2. `handoff_mode: auto` → `relay_mode: true`
3. `handoff_mode: manual` → `relay_mode: false`
4. `auto_handoff: true/false` → `relay_mode: true/false`

The Python implementation should be a function (e.g., `migrate_settings(raw: dict) -> dict`) in `pennyfarthing-dist/pf/` that takes the parsed YAML dict and returns the migrated dict. It should not write back to disk automatically — that is the caller's responsibility.

Testable: a Python test (or the pf CLI's existing test suite if one exists) exercises each of the four migration paths and asserts the output matches the expected migrated schema. The TypeScript `migrateSettings()` JSDoc comment at lines 186–191 of `settings.ts` is the normative spec.
