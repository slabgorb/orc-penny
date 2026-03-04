---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-19: Replace TypeScript Theme Loader with pf CLI Calls

## Business Context

`theme-loader.ts` (577 lines) in `packages/core/src/shared/` maintains the full theme discovery algorithm in TypeScript — four source priority order, deduplication by theme ID, and a `CATEGORY_MAP` with 130+ hardcoded entries. This is a verbatim mirror of the same algorithm in `pennyfarthing-dist/src/pf/common/themes.py`. When `common/themes.py` is updated (new theme source, new dedup logic, new category), `theme-loader.ts` must be updated in parallel or drift occurs.

`pennyfarthing.ts` in `packages/core/src/server/` (420 lines) similarly reimplements project root detection, theme config loading, and persona assembly — all logic that already exists in `pf prime` and `pf theme`.

This story eliminates the duplication by replacing the TypeScript implementations with subprocess calls to `pf theme list --json` and `pf theme show --json` (added in 141-16). The TypeScript layer becomes a thin CLI wrapper. The only TypeScript that remains is `FSWatcher` for real-time file change detection, which is a legitimate GUI concern (watching for `.pennyfarthing/config.local.yaml` changes and notifying connected clients).

`CATEGORY_MAP` is moved into individual theme YAML files so each theme declares its own category. This is a prerequisite for external/user-contributed themes to be categorized correctly without patching TypeScript source.

## Technical Guardrails

### Key Files

- `pennyfarthing/packages/core/src/shared/theme-loader.ts` — primary target; 577 lines; exports `discoverAllThemeDirs()`, `listThemes()`, `loadTheme()`, `deriveCategory()`, and `CATEGORY_MAP`. All discovery and loading logic must be replaced with `pf theme list --json` / `pf theme show --json` subprocess calls.
- `pennyfarthing/packages/core/src/server/pennyfarthing.ts` — secondary target; 420 lines; contains project root detection (`findPennyfarthingRoot`), theme config loading, and persona assembly. Replace with `pf CLI` subprocess calls.
- `pennyfarthing/pennyfarthing-dist/personas/themes/` — core theme YAML files; each needs a `category:` field added so `CATEGORY_MAP` data lives with the theme definition.
- `pennyfarthing/packages/core/src/shared/portrait-resolver.ts` — imported by `theme-loader.ts`; provides `resolvePennyfarthingDist()` and `getPortraitPaths()`; NOT a target — keep as-is.

### subprocess / CLI Patterns

- All `pf` subprocess calls use `pf theme list --json` (returns array of theme metadata) and `pf theme show <id> --json` (returns full theme object including agents).
- Subprocess calls must use Node's `child_process.execFile` or `spawnSync` with the `pf` binary on PATH. Do not shell-construct the command string.
- JSON parse errors must be caught and surfaced via `{success: false, error: ...}` result objects — never thrown.
- FSWatcher setup and teardown remain in TypeScript as the only non-delegatable GUI concern.

### Result Object Convention

All functions must return `{success: boolean, data?: T, error?: string}`. No throwing. Callers in the server layer (WheelHub API routes) already expect this contract.

### Category Migration

Each theme YAML file in `pennyfarthing-dist/personas/themes/` gains a `category:` top-level field. The values are sourced from the existing `CATEGORY_MAP` in `theme-loader.ts`. After migration, `CATEGORY_MAP` and `deriveCategory()` are deleted.

### 141-16 Dependency

This story depends on 141-16 (`Add --json Output to pf CLI for GUI Consumption`). `pf theme show --json` and `pf theme list --json` must be implemented and returning correct structured output before this story's TypeScript changes can be written or tested.

## Scope Boundaries

**In scope:**

- `packages/core/src/shared/theme-loader.ts`: replace discovery, loading, and category logic with `pf theme list --json` and `pf theme show --json` subprocess calls; delete `CATEGORY_MAP`, `deriveCategory()`, and all direct YAML file reading for theme data
- `packages/core/src/server/pennyfarthing.ts`: replace project root detection, theme config loading, and persona assembly with `pf CLI` subprocess calls
- `pennyfarthing-dist/personas/themes/*.yaml`: add `category:` field to every core theme YAML using values from `CATEGORY_MAP`
- Keeping `FSWatcher` logic in TypeScript (watches for config changes, notifies GUI clients)
- Updating all TypeScript callers of the removed/changed exports to use the new CLI-delegating API

**Out of scope:**

- `pf theme list --json` and `pf theme show --json` CLI implementation — that is 141-16
- `packages/cyclist/src/pennyfarthing.ts` — the cyclist variant is a separate file and may be addressed in a follow-on story
- `portrait-resolver.ts` — not a discovery-logic file; keep unchanged
- Theme YAML schema changes beyond adding `category:` — no other YAML structural changes
- Theme packages (`@pennyfarthing/themes-*`) — category fields in those packages are out of scope for this story; those packages add their own `category:` in their YAML independently
- Any changes to WheelHub API response shape — the external contract must remain stable

## AC Context

**AC 1: TypeScript theme discovery replaced with pf CLI calls**

- `theme-loader.ts` no longer reads theme YAML files directly via `readdirSync` / `readFileSync` / `parseYaml`
- `listThemes()` calls `pf theme list --json` as a subprocess and parses the JSON response
- `loadTheme(id)` calls `pf theme show <id> --json` as a subprocess and parses the JSON response
- Both functions return `{success, data?, error?}` objects
- Testable via: `grep -n "readdirSync\|readFileSync\|parseYaml" packages/core/src/shared/theme-loader.ts` returns no matches related to theme discovery; subprocess calls present with JSON parse and error handling

**AC 2: CATEGORY_MAP eliminated; categories declared in theme YAML**

- `CATEGORY_MAP` export is deleted from `theme-loader.ts`
- `deriveCategory()` function is deleted from `theme-loader.ts`
- Every theme YAML file under `pennyfarthing-dist/personas/themes/` has a `category:` field with a non-empty string value
- No TypeScript file imports or references `CATEGORY_MAP`
- Testable via: `grep -rn "CATEGORY_MAP" packages/` returns no matches; `grep -L "^category:" pennyfarthing-dist/personas/themes/*.yaml` returns empty (all files have category field)

**AC 3: pennyfarthing.ts project detection and persona assembly use pf CLI**

- `pennyfarthing.ts` (`packages/core/src/server/`) removes manual `findPennyfarthingRoot` directory walk
- Project root detection delegates to `pf` (e.g., `pf story info --json` or equivalent from 141-16 that surfaces project root)
- Theme config loading (reading `.pennyfarthing/config.local.yaml`) delegates to a `pf` subcommand where one exists, or is replaced by reading config via `pf persona current --json`
- Persona assembly removes direct YAML parsing of persona/agent files in favour of `pf persona current --json` output
- FSWatcher instantiation and file-watch callback wiring remains in TypeScript
- Testable via: `grep -n "parseYaml\|readdirSync\|findPennyfarthingRoot" packages/core/src/server/pennyfarthing.ts` returns no matches for discovery/assembly logic; FSWatcher import and usage still present

**AC 4: Depends on 141-16 (blocking)**

- No part of this story's implementation is mergeable before `pf theme list --json` and `pf theme show --json` are implemented and return correct structured JSON
- Tests for this story mock or call the real `pf theme list --json` / `pf theme show --json` subprocess; tests are not written against direct YAML file access
- Testable via: test suite runs `pf theme list --json` in a subprocess and asserts parsed JSON has expected shape; if `pf` binary is absent or returns non-JSON, tests fail with a clear error
