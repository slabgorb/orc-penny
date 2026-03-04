---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-8: Convert Throw to Result Objects in Scripts and Generators

## Business Context

Three modules in `packages/core/src/` still throw exceptions on validation failures instead of returning
`{success, data?, error?}` result objects. This violates the project's non-throwing contract
(`pennyfarthing/CLAUDE.md` rule 3: "Return result objects — don't throw"), which exists so callers
can handle errors as data without try/catch boundaries and so API routes and CLI entry points get
uniform, predictable failure shapes.

`generate-report.ts` is the OCEAN face report generator — its exported functions (`generateReport`,
`filterByRole`, `filterByTheme`, `compareCharacters`, `parseOceanFilter`) are all synchronous and
throw on bad input (invalid role, unknown theme, malformed OCEAN expression). `generate-skill-docs.ts`
generates docs from the skill registry and throws when the registry is missing or unreadable.
`skill-search.ts` throws when the registry is absent or when an unknown category is supplied.

Converting these to result objects makes callers explicit about error paths, enables the WheelHub API
layer to forward structured errors to the GUI, and eliminates the inconsistency between these modules
and the rest of `packages/core/src/shared/` (which already uses result patterns extensively).

## Technical Guardrails

### Files to modify (source of truth)

All three files live in the framework repo (`pennyfarthing/`), not the orchestrator. Edit source:

- `pennyfarthing/packages/core/src/scripts/generate-report.ts`
- `pennyfarthing/packages/core/src/shared/generate-skill-docs.ts`
- `pennyfarthing/packages/core/src/shared/skill-search.ts`

Corresponding dist files are compiled outputs — do not edit manually.

### Result object standard

```typescript
{ success: true, data: T }
{ success: false, error: string }
```

Where `T` is the existing return type of each function. The `error` field carries the same message
text previously passed to `throw new Error(...)`. Functions must never throw; all error paths must
return `{success: false, error: string}`.

### Throw sites by file

**`generate-report.ts`** (18 throw sites across private helpers and exported functions):
- `loadThemeData()` (private, lines 124, 139, 144, 149) — throws on missing/malformed theme data
- `parseOceanFilter()` (exported, lines 241, 249, 256, 259, 267) — throws on invalid OCEAN expression
- `filterByRole()` (exported, line 288) — throws on invalid agent role
- `filterByTheme()` (exported, line 301) — throws on unknown theme
- `compareCharacters()` (exported, lines 321, 325, 332, 339, 343) — throws on bad specs
- `generateReport()` (exported, lines 419, 426) — throws on unknown theme or invalid role

Note: `loadCharacter()` (private) already has a try/catch pattern at its call site inside
`loadAllCharacters()` (line 175-179) where individual character load failures are silently skipped
— this existing swallow is intentional and in scope to review, but the scope boundary below clarifies
what changes.

**`generate-skill-docs.ts`** (5 throw sites in `generateSkillDocs()`):
- Line 399: `throw new Error('Registry not found: Cannot resolve pennyfarthing-dist directory')`
- Line 407: `throw new Error(\`Registry not found: ${registryPath}\`)`
- Line 414: `throw new Error(\`Cannot read registry: ${registryPath}\`)`
- Line 422: `throw new Error(\`Invalid YAML in registry: ...\`)`
- Line 429: `throw new Error(\`Missing required field 'description' for skill: ${key}\`)` (strict mode)

`generateSkillDocs()` already has `GeneratorResult` with `success: boolean` — but it still throws
instead of returning `{success: false, error: ...}`. The signature change is small; the implementation
needs to replace throws with early returns.

**`skill-search.ts`** (3 throw sites in `searchSkills()`):
- Line 225: `throw new Error('Registry not found: Cannot resolve pennyfarthing-dist directory')`
- Line 232: `throw new Error(\`Registry not found: ${registryPath}\`)`
- Line 237: `throw new Error(\`Invalid category: ${options.category}. Valid categories: ...\`)`

`searchSkills()` currently returns `Promise<SkillResult[]>` — its return type must change to
`Promise<{success: boolean, data?: SkillResult[], error?: string}>`.

### Callers to update

- `pennyfarthing/packages/core/src/shared/skill-suggest.ts` — calls `searchSkills({})` in
  `getSkillDescription()` (line 338) and `searchSkills({ registryPath })` in `suggestSkills()`
  (line 273). Both already have try/catch guards that can be simplified to result-object checks.

- `pennyfarthing/packages/core/src/shared/index.ts` — re-exports `searchSkills`, `generateSkillDocs`
  from this directory; the exported types must be updated if signatures change.

- `pennyfarthing/packages/core/src/index.ts` — barrel re-exports `searchSkills`, `generateSkillDocs`
  from `./shared/index.js`; no logic change required but types propagate.

- Test files that currently assert thrown errors must be updated to assert `{success: false, error: ...}`
  instead of `assert.throws(...)`:
  - `pennyfarthing/packages/core/src/scripts/generate-report.test.ts`
  - `pennyfarthing/packages/core/src/shared/generate-skill-docs.test.ts`
  - `pennyfarthing/packages/core/src/shared/skill-search.test.ts`

- The CLI entry points at the bottom of each file (guarded by `import.meta.url`) call these functions
  and currently use `.catch(err => ...)` — they must be updated to check `result.success`.

### Import paths and `.js` extensions

All relative imports in TypeScript source must use `.js` extensions (per project rule 5). Do not
change import paths when updating callers — only change the call-site logic.

### Build order

Run `pnpm run build` from `pennyfarthing/packages/core/` after changes. Tests run via
`node --test dist/**/*.test.js`.

## Scope Boundaries

**In scope:**
- Convert all `throw new Error(...)` in the three named files to `return {success: false, error: '...'}` (or `return {success: false, error: '...'}` as a resolved Promise for async functions)
- Update return type signatures in all three files
- Update `skill-suggest.ts` call sites to use result-object checks instead of try/catch
- Update all three test files to assert result shapes rather than thrown errors
- Update CLI entry-point blocks inside each file to check `result.success`
- Export type changes propagate through `shared/index.ts` and `core/index.ts` (no logic change)

**Out of scope:**
- `benchmark-integration.ts` — has its own local `parseOceanFilter()` (line 294) that also throws; that file is not named in the AC and is a separate cleanup
- `generate-skill-docs.ts` internal `parseRegistryYaml()` which throws on malformed YAML (lines 91, 102) — these are already caught at the call site (lines 419-422) and converted; leave internal helper unchanged
- Any other files in `packages/core/src/` that throw — this story is scoped to the three named files
- `pennyfarthing-dist/` script changes — runtime scripts use the compiled dist, no direct edits
- Adding new error types or structured error codes beyond `error: string`
- Changing the behaviour of the `loadAllCharacters()` silent-swallow pattern in `generate-report.ts` (the `try/catch` at line 175 is intentional)

## AC Context

**AC 1: `scripts/generate-report.ts` returns result objects instead of throwing**

All exported functions (`generateReport`, `filterByRole`, `filterByTheme`, `filterByOcean`,
`compareCharacters`, `parseOceanFilter`) must return `{success: boolean, data?: T, error?: string}`
rather than throwing. Specifically:

- `parseOceanFilter(expr)` returns `{success: false, error: 'Invalid OCEAN dimension: X...'}` for
  invalid dimension; `{success: false, error: 'Invalid operator: ~...'}` for bad operator;
  `{success: false, error: 'Invalid OCEAN filter format: ...'}` for unparseable input; and
  `{success: true, data: OceanFilter}` on success.
- `filterByRole(role)` returns `{success: false, error: 'Invalid role: ...'}` for an unknown agent;
  `{success: true, data: CharacterInfo[]}` on success.
- `filterByTheme(theme)` returns `{success: false, error: 'Theme not found: ...'}` for unknown
  theme; `{success: true, data: CharacterInfo[]}` on success.
- `filterByOcean(expression)` propagates the result of `parseOceanFilter` on failure; returns
  `{success: true, data: CharacterInfo[]}` on success.
- `compareCharacters(specs)` returns `{success: false, error: '...'}` for all current throw
  conditions (too few, too many, bad format, unknown theme, unknown agent); `{success: true, data: ComparisonResult}` on success.
- `generateReport(options)` returns `{success: false, error: '...'}` for invalid theme or role;
  `{success: true, data: ReportResult}` on success.

Testable: `generate-report.test.ts` must have no `assert.throws` calls — all error assertions must
check `result.success === false` and `result.error` string content.

**AC 2: `shared/generate-skill-docs.ts` returns result objects instead of throwing**

`generateSkillDocs(options)` currently has `GeneratorResult.success: boolean` but still throws.
All five throw sites must become early returns:

- Missing dist path → `return {success: false, error: 'Registry not found: Cannot resolve pennyfarthing-dist directory', content: '', skillCount: 0}`
- Missing registry file → `return {success: false, error: \`Registry not found: ${registryPath}\`, content: '', skillCount: 0}`
- Unreadable registry → `return {success: false, error: \`Cannot read registry: ...\`, content: '', skillCount: 0}`
- Invalid YAML → `return {success: false, error: \`Invalid YAML in registry: ...\`, content: '', skillCount: 0}`
- Strict mode missing field → `return {success: false, error: \`Missing required field...\`, content: '', skillCount: 0}`

The CLI entry block (bottom of file, `import.meta.url` guard) must be updated to check
`result.success` instead of using `.catch(err => ...)`.

Testable: `generate-skill-docs.test.ts` must assert `result.success === false` and inspect
`result.error` for all error cases, rather than `assert.rejects(...)`.

**AC 3: `shared/skill-search.ts` returns result objects instead of throwing**

`searchSkills(options)` return type changes from `Promise<SkillResult[]>` to
`Promise<{success: boolean, data?: SkillResult[], error?: string}>`.

- Missing dist path → `{success: false, error: 'Registry not found: Cannot resolve pennyfarthing-dist directory'}`
- Missing registry file → `{success: false, error: \`Registry not found: ${registryPath}\`}`
- Invalid category → `{success: false, error: \`Invalid category: ...\`}`
- Happy path → `{success: true, data: SkillResult[]}`

The CLI entry block at the bottom of `skill-search.ts` must check `result.success` and use
`result.data` for output or `result.error` for the error message.

Testable: `skill-search.test.ts` must assert `result.success === false` with `result.error` matching
expected message text for all error cases; `result.data` for success cases.

**AC 4: All callers updated to handle result objects**

`skill-suggest.ts` has two call sites:

1. `suggestSkills()` (line 273): `await searchSkills({ registryPath })` currently inside try/catch.
   Must change to `const result = await searchSkills(...)` then `if (!result.success) return []`.
2. `getSkillDescription()` (line 338): `await searchSkills({})` inside try/catch. Must change to
   result-object check: if `!result.success`, return the fallback; otherwise use `result.data`.

No other non-test production callers of these three functions exist in `packages/core/src/` beyond
the barrel re-exports (which need no logic change) and the CLI entry blocks within each file.

Testable: `skill-suggest.ts` has no remaining try/catch blocks wrapping `searchSkills` calls; the
`skill-suggest.test.ts` suite passes without modification (it uses mocks, but if it calls real
`searchSkills` in any integration path, result-object shape must be valid).

**AC 5: Tests pass**

After all changes:

- `node --test dist/scripts/generate-report.test.js` — all tests pass
- `node --test dist/shared/generate-skill-docs.test.js` — all tests pass
- `node --test dist/shared/skill-search.test.js` — all tests pass
- `node --test dist/shared/skill-suggest.test.js` — all tests pass (no regressions from caller changes)
- `node --test dist/**/*.test.js` — full suite green (no type errors from signature changes)

TypeScript compilation (`pnpm run build` in `packages/core/`) must succeed with zero type errors
before test execution.
