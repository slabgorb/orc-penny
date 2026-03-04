---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-10: Convert Throw to Result Objects in Cyclist File-Browser

## Business Context

The project standard (CLAUDE.md Rule 6) is that all functions return `{success, data?, error?}` instead of throwing. The cyclist `file-browser.ts` module is one of the three error-handling violations identified in the March 2026 tech debt audit (alongside 141-8 and 141-9). It contains 6 throw sites across two public functions (`listDirectory` and `readFile`) and one private helper (`validatePathSecurity`). Throwing from these functions crashes the callers rather than allowing them to handle errors gracefully. Because the API route in `packages/core/src/server/api/file-browser.ts` already wraps calls in try/catch (meaning it anticipated throws), converting to result objects eliminates the need for that error-catching wrapper and makes the control flow explicit.

## Technical Guardrails

### File Under Change

`pennyfarthing/packages/cyclist/src/file-browser.ts` — the only file containing actual throw sites. This module is not re-exported via the `packages/core` stub; it is used directly in the cyclist package.

Do not edit `pennyfarthing/packages/cyclist/src/api/file-browser.ts` — that file is a one-liner re-export from `@pennyfarthing/core/dist/server/api/file-browser.js` and is unrelated to the cyclist-specific throw sites.

Do not edit `pennyfarthing/packages/core/src/server/file-browser.ts` — that is a separate stub with its own interface definitions and is not a caller of cyclist's file-browser.

### The 6 Throw Sites

All throws are in `pennyfarthing/packages/cyclist/src/file-browser.ts`:

| Line | Function | Condition | Message |
|------|----------|-----------|---------|
| 50 | `validatePathSecurity` | Literal path outside project dir | `'Access denied: path outside project directory'` |
| 59 | `validatePathSecurity` | Resolved realpath outside project dir | `'Access denied: path outside project directory'` |
| 64 | `validatePathSecurity` | `realpathSync` throws (non-ENOENT) | rethrows `e` |
| 85 | `listDirectory` | `existsSync(targetPath)` is false | `\`Directory not found: ${targetPath}\`` |
| 90 | `listDirectory` | Not a directory | `\`Not a directory: ${targetPath}\`` |
| 178 | `readFile` | `existsSync(filePath)` is false | `\`File not found: ${filePath}\`` |
| 183 | `readFile` | Not a file | `\`Not a file: ${filePath}\`` |

Note: lines 50, 59, 64 are inside `validatePathSecurity`, which is a private helper (not exported). Its throws propagate through both `listDirectory` and `readFile`.

### Result Object Standard

```typescript
// Project-standard result shape
type Result<T> = { success: true; data: T } | { success: false; error: string };

// Before (violation)
export function listDirectory(dirPath: string, projectDir: string): DirectoryListing {
  throw new Error('Access denied: path outside project directory');
}

// After (conforming)
export function listDirectory(
  dirPath: string,
  projectDir: string
): { success: boolean; data?: DirectoryListing; error?: string } {
  // ...
  return { success: false, error: 'Access denied: path outside project directory' };
  // ...
  return { success: true, data: { path: targetPath, entries } };
}
```

### Caller: Core API Route

`pennyfarthing/packages/core/src/server/api/file-browser.ts` (lines 35, 55) calls `listDirectory` and `readFile` from `'../file-browser.js'` — which resolves to the core stub, not the cyclist module directly. The try/catch wrappers in that route (lines 32-43 and 46-63) were written anticipating throws. After this story those wrappers should be updated to check `result.success` instead.

Note: the cyclist-src `file-browser.ts` is also consumed in an Electron/IPC context (the module comment references "IPC communication"). There are no surviving Electron IPC handlers that import from it directly in the current source tree — the `bikerack.ts` shim and related IPC wiring are being removed in story 141-4. Confirm no remaining IPC callers before declaring scope complete.

### No Existing Tests

There are no test files for `cyclist/src/file-browser.ts`. The TDD workflow applies: TEA writes failing tests first (RED), Dev converts throws to result objects (GREEN), then refactors.

### TypeScript Build

Changes must compile without errors. Run `pnpm run build` from `pennyfarthing/packages/cyclist/` to verify. Return types must be updated in all exported function signatures.

## Scope Boundaries

**In scope:**
- `pennyfarthing/packages/cyclist/src/file-browser.ts` — convert all 6 throw sites to result object returns
- Update exported function signatures: `listDirectory` and `readFile` return `{success, data?, error?}` instead of throwing
- Refactor `validatePathSecurity` from a void-throwing function into a returning validation helper (returns error string or null), consumed by `listDirectory` and `readFile` internally
- Update `pennyfarthing/packages/core/src/server/api/file-browser.ts` — remove try/catch wrappers around `listDirectory` and `readFile` calls; check `result.success` instead
- New test file (created by TEA in RED phase): `pennyfarthing/packages/cyclist/tests/141-10-file-browser-result-objects.test.ts`
- Tests cover all 6 error conditions plus happy path for both `listDirectory` and `readFile`

**Out of scope:**
- `pennyfarthing/packages/core/src/server/file-browser.ts` — separate stub, different types, different story
- `pennyfarthing/packages/cyclist/src/api/file-browser.ts` — one-line re-export, no throw sites
- Other cyclist modules that use `fs.readFileSync` directly (story 141-8, 141-9 scope)
- Any Electron IPC handler changes — those are addressed in story 141-4 (bikerack shim removal)
- Converting `isValidPath` — it already returns `boolean` and does not throw (uses try/catch internally)

## AC Context

### AC 1: `cyclist/src/file-browser.ts` returns result objects instead of throwing (6 sites)

Testable: `grep -n 'throw' pennyfarthing/packages/cyclist/src/file-browser.ts` returns no matches.

The 6 throw sites map to these result returns:

- `validatePathSecurity` literal path check (line 50): caller receives `{ success: false, error: 'Access denied: path outside project directory' }`
- `validatePathSecurity` realpath check (line 59): caller receives `{ success: false, error: 'Access denied: path outside project directory' }`
- `validatePathSecurity` rethrow of non-ENOENT error (line 64): caller receives `{ success: false, error: err.message }` (or a standardized string)
- `listDirectory` ENOENT check (line 85): `{ success: false, error: 'Directory not found: <path>' }`
- `listDirectory` not-a-directory check (line 90): `{ success: false, error: 'Not a directory: <path>' }`
- `readFile` ENOENT check (line 178): `{ success: false, error: 'File not found: <path>' }`
- `readFile` not-a-file check (line 183): `{ success: false, error: 'Not a file: <path>' }`

Exported function return types must change:
```typescript
export function listDirectory(
  dirPath: string,
  projectDir: string
): { success: boolean; data?: DirectoryListing; error?: string }

export function readFile(
  filePath: string,
  projectDir: string
): { success: boolean; data?: string; error?: string }
```

`isValidPath` signature is unchanged (returns `boolean`, no throws internally).

### AC 2: All callers updated to handle result objects

Testable: `pennyfarthing/packages/core/src/server/api/file-browser.ts` no longer wraps `listDirectory` / `readFile` calls in try/catch; instead checks `result.success`.

Expected pattern after update:

```typescript
// GET /
router.get('/', (req, res) => {
  const projectDir = getProjectDir();
  const requestedPath = (req.query.path as string) || '';
  const result = listDirectory(requestedPath, projectDir);
  if (!result.success) {
    return res.status(400).json({ error: result.error });
  }
  res.json(result.data);
});

// POST /open
router.post('/open', (req, res) => {
  const projectDir = getProjectDir();
  const { path: filePath } = req.body;
  if (!filePath) return res.status(400).json({ error: 'Missing path parameter' });
  const result = readFile(filePath, projectDir);
  if (!result.success) {
    return res.status(400).json({ error: result.error });
  }
  res.json({ path: filePath, content: result.data });
});
```

The `/edit` route in `packages/core/src/server/api/file-browser.ts` does not call `listDirectory` or `readFile` and requires no change.

### AC 3: Tests pass

Testable: `pnpm vitest run` from `pennyfarthing/packages/cyclist/` exits 0.

Test file `tests/141-10-file-browser-result-objects.test.ts` must cover:

**`listDirectory` tests:**
- Returns `{ success: true, data: { path, entries } }` for a valid directory
- Returns `{ success: false, error: 'Directory not found: ...' }` when path does not exist
- Returns `{ success: false, error: 'Not a directory: ...' }` when path is a file
- Returns `{ success: false, error: 'Access denied: path outside project directory' }` when path is outside projectDir (literal check)
- Returns `{ success: false, error: 'Access denied: path outside project directory' }` when symlink resolves outside projectDir

**`readFile` tests:**
- Returns `{ success: true, data: '<file contents>' }` for a valid file
- Returns `{ success: false, error: 'File not found: ...' }` when file does not exist
- Returns `{ success: false, error: 'Not a file: ...' }` when path is a directory
- Returns `{ success: false, error: 'Access denied: path outside project directory' }` when path is outside projectDir

**`isValidPath` tests (regression — must not change behavior):**
- Returns `true` for a valid path inside projectDir
- Returns `false` for a path outside projectDir
- Returns `false` for a non-existent path

Total: at least 11 test cases. Use `node:os` `tmpdir` or a fixture directory for isolated filesystem tests.
