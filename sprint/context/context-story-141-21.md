---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-21: Extract Hardcoded Values and Relocate Misplaced Business Logic

## Business Context

Two cleanup items that remain after trivial items were absorbed into adjacent stories (141-17 and 141-18).

**Absorbed into other stories (no longer in scope here):**
- Jira URL dedup — handled by 141-17 (story-parser replacement removes the hardcode)
- `toSlug()` / `oceanSuffix()` dedup — handled by 141-17 (during `pennyfarthing.ts` / `theme-agents.ts` refactor)
- Token limits (`MAX_TOKENS_PER_BLOCK`) — moved to config during 141-18 workflow delegation

**Remaining items:**

**Agent evaluation in the wrong package.** `packages/cyclist/src/agent-evaluation.ts` (644 lines) is a full Job Fair benchmarking engine — it computes completion rates, error rates, tool efficiency, regression alerts, persona comparisons, trend detection, and baseline comparisons against stored Job Fair profiles. None of this is GUI rendering logic. It lives in cyclist because it was written there during Story 19-9, before `packages/benchmark` was planned. The correct home is either a new `packages/benchmark` package or the `pf benchmark` CLI in `pennyfarthing-dist/pf/`. As long as the cyclist UI and the core server stub can still call the evaluation API, the location does not matter to callers.

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
- Add Python-callable settings migration in the `pf` CLI that applies the same four legacy-format transforms as `migrateSettings()` in TypeScript

**Out of scope:**
- Changing any evaluation scoring logic inside `agent-evaluation.ts` — this is a relocation, not a rewrite
- Building a full `packages/benchmark` package beyond what is needed to house `agent-evaluation.ts` (no new CLI commands, no new test harnesses unless needed for AC verification)
- Removing the legacy config keys from existing `.pennyfarthing/config.local.yaml` files — migration should be forward-only (read old, write new on save), not destructive
- `toSlug()` / `oceanSuffix()` dedup — absorbed into 141-17
- Token limits (`MAX_TOKENS_PER_BLOCK`) — absorbed into 141-18
- Jira URL extraction — handled by 141-17
- The `pf` CLI `--json` output work from story 141-16 — no dependency on that here
- Any changes to the `pf benchmark` command's user-facing behavior — this story is backend relocation only

## AC Context

**AC1: `agent-evaluation.ts` moved to `packages/benchmark` or `pf benchmark`**

The full 644-line implementation currently at `packages/cyclist/src/agent-evaluation.ts` must not remain in cyclist. Two destination options:

Option A — `packages/benchmark/` (new package): Create `packages/benchmark/src/agent-evaluation.ts`, add to pnpm workspace (`pnpm-workspace.yaml`), add `package.json` with `"name": "@pennyfarthing/benchmark"`. Cyclist imports change from `./agent-evaluation.js` to `@pennyfarthing/benchmark/dist/agent-evaluation.js` (or re-export via barrel).

Option B — `packages/core/src/benchmark/agent-evaluation.ts`: Simpler; adjacent to `benchmark-integration.ts` which already lives there. Cyclist imports change to `@pennyfarthing/core/dist/benchmark/agent-evaluation.js`.

Either option satisfies the AC. The core server stub (`packages/core/src/server/agent-evaluation.ts`) may be updated to re-export from the new location so the `/api/evaluation` route handler needs no changes.

Testable: after move, `pnpm run build` succeeds in both core and cyclist; the existing evaluation tests (if any accompany the cyclist file) pass in their new location; no file named `agent-evaluation.ts` remains under `packages/cyclist/src/`.

**AC2: Settings migration callable from Python path**

The Python `pf` CLI must be able to load `.pennyfarthing/config.local.yaml` and apply the same four legacy-format migrations that `migrateSettings()` applies in TypeScript:

1. `permission_mode: turbo` → `permission_mode: accept` + `relay_mode: true`
2. `handoff_mode: auto` → `relay_mode: true`
3. `handoff_mode: manual` → `relay_mode: false`
4. `auto_handoff: true/false` → `relay_mode: true/false`

The Python implementation should be a function (e.g., `migrate_settings(raw: dict) -> dict`) in `pennyfarthing-dist/pf/` that takes the parsed YAML dict and returns the migrated dict. It should not write back to disk automatically — that is the caller's responsibility.

Testable: a Python test (or the pf CLI's existing test suite if one exists) exercises each of the four migration paths and asserts the output matches the expected migrated schema. The TypeScript `migrateSettings()` JSDoc comment at lines 186–191 of `settings.ts` is the normative spec.
