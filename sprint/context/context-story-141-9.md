---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-9: Convert Throw to Result Objects in CLI Utils

## Business Context

The project standard (CLAUDE.md Rule 6) requires `{success, data?, error?}` return shapes — never `throw`. Violations in CLI utils surface as unhandled exceptions that can crash the CLI mid-operation rather than returning a structured error the caller can act on. Story 141-9 targets the four utility files most used across the core CLI commands. Fixing these makes the CLI layer predictable, composable, and consistent with the pattern already applied in higher-level modules.

## Technical Guardrails

**Key files — the four files that own all throws:**

| File | Throws |
|------|--------|
| `pennyfarthing/packages/core/src/cli/utils/themes.ts` | `getThemesDir()` (line 62), `setTheme()` (line 236), `createTheme()` (lines 340, 346, 353) |
| `pennyfarthing/packages/core/src/cli/utils/files.ts` | `findMonorepoRoot()` (line 239) |
| `pennyfarthing/packages/core/src/cli/utils/version.ts` | `getAssetsPath()` (line 69) |
| `pennyfarthing/packages/core/src/cli/utils/manifest.ts` | `readManifest()` (line 59) |

**Callers that must be updated:**

| Caller file | Function called | Current handling |
|------------|-----------------|-----------------|
| `packages/core/src/cli/commands/theme.ts` | `setTheme()`, `createTheme()` | Wraps in `try/catch`, logs error message |
| `packages/core/src/cli/commands/update.ts` | `getAssetsPath()` (lines 90, 222, 534), `readManifest()` (lines 61, 364) | No try/catch — `getAssetsPath()` at line 90 and 222 are completely unguarded; `readManifest` at line 364 is used inline |
| `packages/core/src/cli/commands/doctor.ts` | `getAssetsPath()` (line 305), `readManifest()` (lines 103, 630, 694, 1933) | `getAssetsPath()` already has `try/catch`; `readManifest()` is unguarded |
| `packages/core/src/cli/commands/version.ts` | `readManifest()` (line 12) | Guarded by `manifestExists()` check but `readManifest()` itself can still throw on parse error |
| `packages/core/src/cli/commands/uninstall.ts` | `readManifest()` (line 59) | No try/catch |
| `packages/core/src/scripts/add-ocean-profiles.ts` | `findMonorepoRoot()` (line 18) | Top-level call — no guard |
| `packages/core/src/scripts/generate-report.ts` | `findMonorepoRoot()` (line 20) | Top-level call — no guard |
| `packages/core/src/index.ts` | Re-exports `getAssetsPath`, `readManifest` | Consumers outside core also affected |

**Return type pattern:**
```typescript
// Standard result type
interface Result<T> {
  success: boolean;
  data?: T;
  error?: string;
}

// Void operations use:
{ success: boolean; error?: string }
```

**Test file locations:**
- `packages/core/src/cli/utils/themes.test.ts` — existing tests call `setTheme()` and expect it to succeed; must stay working
- No existing test files for `files.ts`, `version.ts`, or `manifest.ts` utils

**Build/test:**
```bash
cd pennyfarthing && pnpm run build && pnpm test
```

**Constraints:**
- Use `.js` extensions in all relative imports (ESM)
- Do not change the `Manifest` type interface
- `getThemesDir()` is not exported in `index.ts` — used only internally within `themes.ts`; can update signature or keep as internal implementation detail
- `validateThemeName()` already returns `{valid, error?}` — do not change it; only the functions that `throw` need converting

## Scope Boundaries

**In scope:**
- Convert all `throw` statements in `themes.ts`, `files.ts`, `version.ts`, and `manifest.ts` to return `{success: false, error: '...'}` shapes
- Update return type signatures of each converted function
- Update all callers in `commands/theme.ts`, `commands/update.ts`, `commands/doctor.ts`, `commands/version.ts`, `commands/uninstall.ts` to check `result.success` instead of using try/catch
- Update `scripts/add-ocean-profiles.ts` and `scripts/generate-report.ts` callers of `findMonorepoRoot()`
- Write/update tests covering the error path for each converted function (TDD: failing tests first)

**Out of scope:**
- `getThemesDir()` consumers outside the file — it is not exported in the public API; its callers are all internal to `themes.ts` itself. Convert to return null or result internally, then let `getThemes()` handle it
- `benchmark/benchmark-integration.ts` has its own local `findMonorepoRoot()` implementation — do not touch it (it's a separate copy, not an import)
- Any other CLI command files not listed above
- Python-layer error handling (141-16 through 141-20 handle that)
- Changing how `validateThemeName()` works — it already returns a result shape

## AC Context

**AC1: `cli/utils/themes.ts` returns result objects instead of throwing**

- `getThemesDir()`: convert to return `string | null` (or fold into callers since it's internal). The single `throw` at line 62 fires when no themes directory can be found. Post-conversion, `getThemesDir()` returns `null`; `getThemes()` handles null gracefully (returns empty array).
- `setTheme(themeName, projectRoot, options)`: currently returns `ThemeInfo` and throws on not-found. Convert to return `{success: boolean; data?: ThemeInfo; error?: string}`. Three throw sites: validation failure (line 236 — theme not found), and the two in `createTheme`.
- `createTheme(themeName, projectRoot, options)`: currently returns `string` (path) and throws on validation failure, duplicate name, or missing base theme. Convert to `{success: boolean; data?: string; error?: string}`. Three throws (lines 340, 346, 353).
- Tests (TDD order — write RED first):
  - `setTheme('nonexistent', dir)` returns `{success: false, error: "Theme 'nonexistent' not found..."}` not throws
  - `createTheme('', dir)` returns `{success: false, error: 'Theme name is required'}`
  - `createTheme('duplicate', dir)` when theme exists returns `{success: false, error: "Theme 'duplicate' already exists"}`
  - `createTheme('new', dir, {baseTheme: 'ghost'})` returns `{success: false, error: "Base theme 'ghost' not found..."}`
  - Happy path: `setTheme('test-theme', dir)` returns `{success: true, data: <ThemeInfo>}`

**AC2: `cli/utils/files.ts` returns result objects instead of throwing**

- `findMonorepoRoot(startDir)`: currently returns `string` and throws when root not found after 10 directory levels. Convert to `{success: boolean; data?: string; error?: string}`.
- The throw at line 239 is the only throw in this file.
- Tests (TDD order — write RED first):
  - `findMonorepoRoot('/tmp')` (no pennyfarthing markers) returns `{success: false, error: 'Could not find project root...'}`
  - `findMonorepoRoot(validMonorepoDir)` returns `{success: true, data: '<path>'}`
- Update callers: `scripts/add-ocean-profiles.ts` and `scripts/generate-report.ts` both call `findMonorepoRoot()` at module top-level and assign result directly to `projectRoot`. After conversion, check `result.success` and exit with error if not found.

**AC3: `cli/utils/version.ts` and `manifest.ts` return result objects instead of throwing**

- `getAssetsPath()` in `version.ts`: single throw at line 69 when `pennyfarthing-dist/` cannot be found. Convert to `{success: boolean; data?: string; error?: string}`.
- `readManifest(projectRoot)` in `manifest.ts`: single throw at line 59, triggered on JSON parse failure. Convert to `{success: boolean; data?: Manifest | null; error?: string}`. Note: `null` is already a valid return (manifest not found); the throw only fires on parse error. Post-conversion: file-not-found path returns `{success: true, data: null}`; parse error path returns `{success: false, error: 'Failed to read manifest: ...'}`.
- Tests for `getAssetsPath()` (TDD order — write RED first):
  - With no `pennyfarthing-dist/` findable from a temp dir, returns `{success: false, error: 'Package directory not found...'}`
- Tests for `readManifest()` (TDD order — write RED first):
  - With a corrupt JSON file at `.pennyfarthing/manifest.json`, returns `{success: false, error: 'Failed to read manifest: ...'}`
  - With no manifest file, returns `{success: true, data: null}`
  - With valid manifest, returns `{success: true, data: <Manifest>}`
- `getInstalledVersion()` in `manifest.ts` calls `readManifest()` — update to use result shape

**AC4: All callers updated to handle result objects**

- `commands/theme.ts` — `setTheme()` and `createTheme()` callers already use try/catch; replace with result checks:
  - `setCommand`: `const result = setTheme(...); if (!result.success) { console.error(result.error); return; }`
  - `createCommand`: same pattern
- `commands/update.ts`:
  - Line 90: `const assetsResult = getAssetsPath(); if (!assetsResult.success) { logger.error(assetsResult.error); process.exit(1); }` — assign `assetsResult.data` to `assetsPath`
  - Lines 222, 534: same pattern at each call site
  - Lines 61, 364: `readManifest()` — check result before using
- `commands/doctor.ts`:
  - Line 305: already has try/catch — replace with result check
  - Lines 103, 630, 694, 1933: all `readManifest()` calls — update to destructure result
- `commands/version.ts` line 12: update `readManifest()` call
- `commands/uninstall.ts` line 59: update `readManifest()` call

**AC5: Tests pass**

- Existing `themes.test.ts` tests for `setTheme()` must continue to pass (happy path now checks `result.success === true` and uses `result.data`)
- All new RED tests written in AC1–4 must turn GREEN after implementation
- `pnpm test` in `pennyfarthing/packages/core` exits 0
