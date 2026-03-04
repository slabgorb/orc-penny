# Story 141-8: Convert Throw to Result Objects in Scripts and Generators

## Overview

Convert three modules from throwing errors to returning `{success, data?, error?}` result objects per project convention (CLAUDE.md rule 6).

## Target Files

### 1. `packages/core/src/scripts/generate-report.ts`
- **Throw sites:** 18 (across loadThemeData, loadCharacter, parseOceanFilter, filterByRole, filterByTheme, compareCharacters, generateReport)
- **Exported functions:** parseOceanFilter, filterByOcean, filterByRole, filterByTheme, compareCharacters, generateReport
- **Callers:** test file only (`generate-report.test.ts`)

### 2. `packages/core/src/shared/generate-skill-docs.ts`
- **Throw sites:** 7 (parseRegistryYaml: 2, generateSkillDocs: 5)
- **Exported functions:** generateSkillDocs
- **Callers:** test file, `shared/index.ts` (re-export), `core/index.ts` (re-export), `wheelhub.mjs` (compiled)

### 3. `packages/core/src/shared/skill-search.ts`
- **Throw sites:** 3 (all in searchSkills)
- **Exported functions:** searchSkills
- **Callers:** test file, `skill-suggest.ts` (direct import), `shared/index.ts`, `core/index.ts`, `wheelhub.mjs`

## Technical Approach

1. Define or reuse a `Result<T>` type: `{success: boolean, data?: T, error?: string}`
2. Replace each `throw new Error(msg)` with `return {success: false, error: msg}`
3. Update return types on all exported functions
4. Update callers (`skill-suggest.ts` imports `searchSkills` — must handle result object)
5. Update existing test files to assert on result objects instead of catch blocks
6. Internal helper functions (loadThemeData, loadCharacter) that throw should also return results since they're called by exported functions

## Guardrails

- Do NOT change the compiled `wheelhub.mjs` — it will be regenerated on build
- Existing test files (`generate-report.test.ts`, `generate-skill-docs.test.ts`, `skill-search.test.ts`) must be updated
- `skill-suggest.ts` is a direct caller of `searchSkills` — must be updated to handle result
- Re-exports in `shared/index.ts` and `core/index.ts` need type updates if signatures change

## Acceptance Criteria

1. `scripts/generate-report.ts` returns result objects instead of throwing
2. `shared/generate-skill-docs.ts` returns result objects instead of throwing
3. `shared/skill-search.ts` returns result objects instead of throwing
4. All callers updated to handle result objects
5. Tests pass
