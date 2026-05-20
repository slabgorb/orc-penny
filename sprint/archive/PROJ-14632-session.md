# Session: Story 93-3 (PROJ-14632)

**Story:** Plugin discovery for commands and skills from installed packages
**Epic:** epic-93 — Extract Benchmarking System into @pennyfarthing/benchmark
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/story-93-3-plugin-discovery

## Story Context

Implement a generic plugin discovery mechanism for `@pennyfarthing/core` to find
and register commands, skills, and API routers from installed `@pennyfarthing/*`
packages. When `@pennyfarthing/benchmark` is installed, its 4 commands, 3 skills,
and Cyclist API router should be available automatically.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core infrastructure — plugin discovery must be provably correct

**Test Files:**
- `packages/core/src/plugins/plugin-discovery.test.ts` — 33 tests across 7 suites

**Tests Written:** 33 tests covering 6 ACs
**Status:** RED (all 33 failing — stub implementations throw "not implemented")

### Test Coverage by AC

| AC | Tests | Suite |
|----|-------|-------|
| Generic plugin discovery | 7 | discoverPlugins() |
| Benchmark commands available | 4 | getPluginCommands() |
| Benchmark skills load | 5 | getPluginSkills() |
| Cyclist API router registers | 3 | getPluginRouters() |
| Graceful degradation | 4 | Graceful degradation |
| Tests cover all scenarios | 2 | DiscoveredPlugin type contract |
| Manifest parsing | 6 | parsePluginManifest() |

### Design Decisions

1. **Plugin manifest via `package.json` "pennyfarthing" field** — convention over configuration,
   no separate config files needed. Packages declare what they provide.

2. **Skip core and shared** — these are framework packages, not plugins.

3. **Type exports**: `PluginManifest`, `DiscoveredPlugin`, `PluginCommand`, `PluginSkill`, `PluginRouter`

4. **API router spec**: `{ path, module, export }` — Cyclist can dynamically import and mount.

5. **Graceful degradation everywhere** — malformed JSON, missing directories, absent packages all
   return empty results, never throw.

### Implementation Notes for Dev

The stub is at `packages/core/src/plugins/plugin-discovery.ts` with:
- All types defined (PluginManifest, DiscoveredPlugin, PluginCommand, PluginSkill, PluginRouter)
- All function signatures defined with JSDoc
- All functions throw "not implemented"

Key integration points after implementation:
1. `init.ts` should call `discoverPlugins()` and iterate plugin commands/skills during init
2. `symlinks.ts` — `copyCommandsDirectory` and `copySkillsDirectory` need plugin-aware variants
3. `generate-slash-commands.js` — needs to scan plugin command dirs too
4. `server.ts` — needs to call `getPluginRouters()` for dynamic mounting
5. Export from `packages/core/src/index.ts`

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/plugins/plugin-discovery.ts` — Full implementation of plugin discovery (5 functions, 6 types)
- `packages/core/src/plugins/plugin-discovery.test.ts` — 33 tests (from TEA, unchanged)
- `packages/core/src/index.ts` — Export all plugin discovery types and functions
- `packages/benchmark/package.json` — Add "pennyfarthing" manifest field

**Tests:** 33/33 passing (GREEN)
**PR:** #778 — feat(93-3): plugin discovery for commands and skills
**Branch:** feat/story-93-3-plugin-discovery (pushed)

**Implementation approach:**
- `discoverPlugins()` scans `node_modules/@pennyfarthing/*/package.json` for "pennyfarthing" field
- Excludes core and shared packages via constant array
- `parsePluginManifest()` gracefully handles missing/malformed JSON
- `getPluginCommands()` scans plugin's declared commands dir for .md files
- `getPluginSkills()` scans plugin's declared skills dir for subdirectories (skips hidden)
- `getPluginRouters()` extracts API router specs from manifests
- All functions return empty arrays on error — never throw

**Note:** Integration with init.ts, symlinks.ts, generate-slash-commands.js, and server.ts
is deferred to story 93-6 (Cyclist plugin integration). This story establishes the
discovery API that those integration points will consume.

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] Graceful degradation — all error paths return empty, never throw (`plugin-discovery.ts:90-109`, `:120-154`)
2. [VERIFIED] No benchmark-specific hardcoding — `EXCLUDED_PACKAGES` at `:13` only excludes `core` and `shared`
3. [VERIFIED] Data flow traced: `package.json` → `parsePluginManifest` → `DiscoveredPlugin` → `getPluginCommands/Skills/Routers` — path traversal prevented by `join()`
4. [VERIFIED] Type cast at `:105` is safe — downstream functions guard all optional fields before use
5. [VERIFIED] Hidden directory filtering at `:215` — `.hidden`, `.git` correctly skipped
6. [LOW] `node:fs` vs `fs` import style inconsistency with existing codebase — not blocking
7. [VERIFIED] Benchmark `package.json` `pennyfarthing` field matches `files` array — assets will be published
8. [VERIFIED] Core index exports — 5 functions, 5 types, clean barrel export
9. [VERIFIED] 33/33 tests passing — no skips, no console.log, comprehensive coverage
10. [VERIFIED] No security concerns — reads only from `node_modules/`, no user input in paths

**Data flow traced:** `node_modules/@pennyfarthing/*/package.json` → `parsePluginManifest()` → `DiscoveredPlugin[]` → `getPluginCommands/Skills/Routers()` (safe: `join()` prevents traversal, all paths resolve within package directory)
**Pattern observed:** Follows workflow-loader.ts directory scan pattern at `plugin-discovery.ts:128-131`
**Error handling:** Every function guards with `existsSync` + `try/catch`, returns empty on error

**Handoff:** To SM for finish-story
