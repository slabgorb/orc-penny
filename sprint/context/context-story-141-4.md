---
parent: context-epic-141.md
workflow: trivial
---

# Story 141-4: Remove Deprecated Bikerack Shim and Stale References

## Business Context

During the monorepo consolidation (Stories 124-1 through 124-6), the `packages/bikerack/` package was absorbed into `packages/core/` and its surface re-exported under `@pennyfarthing/core/bikerack/*` paths. The shim file `cyclist/src/bikerack.ts` was left in place for backward compatibility but was immediately marked deprecated. `packages/bikerack/` itself was never committed to the repo as a real package — it only exists as stale references in comments and provenance headers. Similarly, `packages/shared/` was absorbed into core (Story 98-16) and the canonical test for that migration (`core/src/consolidation.test.ts`) already enforces that no source files import from `@pennyfarthing/shared`. This story removes the shim file and verifies no live references remain, reducing confusion about the package topology for anyone reading the source.

## Technical Guardrails

**The shim file:**
- `pennyfarthing/packages/cyclist/src/bikerack.ts` — 9-line file that logs a deprecation warning and delegates via dynamic import to `@pennyfarthing/core/bikerack/entry`. It is not imported by any other `cyclist/src/` file.

**Test that currently references the shim (must be updated or removed together):**
- `pennyfarthing/packages/cyclist/tests/124-4-rewire-cyclist-bikerack.test.ts` — AC2 of that test asserts that `bikerack.ts` exists and imports from `@pennyfarthing/core/bikerack/entry` (line 62-65). After the shim is deleted this assertion will fail. The test must be updated to remove or invert the assertion for the now-deleted file.

**Stale `packages/bikerack/` comment references (not real imports — comments only):**
- `pennyfarthing/packages/cyclist/src/bikerack.ts` line 6: `// node packages/bikerack/dist/entry.js` — deleted with the file.
- `pennyfarthing/packages/core/src/public/data-source.ts` line 6: `* - WebSocketDataSource: packages/bikerack/` — a JSDoc provenance comment. Per AC2, provenance headers are acceptable; do not need to be changed.
- `pennyfarthing/CHANGELOG.md` line 168 — changelog entry, acceptable provenance; do not change.

**`packages/shared/` references (comment/doc only — no live imports exist):**
- `pennyfarthing/packages/cyclist/src/paths.ts` line 9: `// Inlined from @pennyfarthing/shared (for standalone npm distribution)` — a comment explaining why path-resolver logic was copied rather than imported. This is a provenance header; AC4 ("provenance headers acceptable") applies here too. No action required.
- `pennyfarthing/packages/cyclist/scripts/cyclist-doctor.sh` lines 73, 358-372 — diagnostic script that checks for the `@pennyfarthing/shared` workspace symlink. This is runtime tooling, not a source import; leave it unless the symlink check is confirmed stale.
- `pennyfarthing/packages/cyclist/docs/VALIDATION-CHECKLIST.md` — documentation; out of scope.
- `pennyfarthing/packages/core/src/consolidation.test.ts` lines 242-248 — the AC8 test that enforces no source imports from `@pennyfarthing/shared`. This is the enforcement mechanism; do not touch it.

**Build surface:**
- `pennyfarthing/packages/cyclist/vite.config.ts` line 15: `'@pennyfarthing/bikerack': resolve(...)` — vite alias for the browser build. This is not a reference to `packages/bikerack/`; it is an alias mapping the old npm package name to `core/src/server/_vite-index.ts`. Do not remove — it supports React component imports.
- `pennyfarthing/packages/cyclist/vitest.config.ts` lines 35-37: similar aliases for the test environment. Do not remove.
- `pennyfarthing/packages/cyclist/src/server.ts` line 133: comment `// bikerack.ts needs: createTerminalServer...` — stale comment referencing the shim. Should be cleaned up when the shim is removed.

**The `cyclist/package.json` already has no `@pennyfarthing/shared` or `@pennyfarthing/bikerack` dependency** — only `@pennyfarthing/core` and runtime deps.

## Scope Boundaries

**In scope:**
- Delete `pennyfarthing/packages/cyclist/src/bikerack.ts`
- Update `pennyfarthing/packages/cyclist/tests/124-4-rewire-cyclist-bikerack.test.ts` to remove the assertion that reads `bikerack.ts` (the file will no longer exist); the remaining ACs in that test (AC1, AC3, AC4, AC5) continue to pass and must not be broken
- Clean up the stale comment on line 133 of `pennyfarthing/packages/cyclist/src/server.ts` referencing `bikerack.ts`
- Verify `pnpm run build` in `pennyfarthing/` and `vitest run` in `packages/cyclist/` pass after removal

**Out of scope:**
- Provenance headers and changelog entries (`data-source.ts` JSDoc, `CHANGELOG.md`) — explicitly allowed by AC2
- The `paths.ts` inline comment (`// Inlined from @pennyfarthing/shared`) — provenance comment, not an import
- Vite/vitest aliases for `@pennyfarthing/bikerack` in `vite.config.ts` and `vitest.config.ts` — these are namespace aliases routing to `core`, not references to a deleted package
- `cyclist-doctor.sh` workspace symlink checks — runtime diagnostic tooling
- `packages/core/src/consolidation.test.ts` — enforcement test, must remain untouched
- Removing or renaming `@pennyfarthing/core/bikerack/*` export paths — those are active, used by `server.ts` and `env.ts`

## AC Context

**AC1: `cyclist/src/bikerack.ts` shim file is removed**

The file at `pennyfarthing/packages/cyclist/src/bikerack.ts` must not exist after this story. Verify by checking that `existsSync('packages/cyclist/src/bikerack.ts')` returns false. The file contains only a deprecation log and a dynamic import to `@pennyfarthing/core/bikerack/entry`; no other source file in `cyclist/src/` imports it directly, so deletion has no transitive impact on the server or websocket modules.

After deletion, update `packages/cyclist/tests/124-4-rewire-cyclist-bikerack.test.ts`: the specific `it` block at lines 62-65 (`'should import from @pennyfarthing/core/bikerack/entry in bikerack.ts'`) reads a now-deleted file and will throw. Either remove the `it` block or replace the assertion with `expect(existsSync(join(CYCLIST_SRC, 'bikerack.ts'))).toBe(false)` to document the intended state.

**AC2: No source code references `packages/bikerack/` (provenance headers acceptable)**

After removing `bikerack.ts`, the only remaining textual references to `packages/bikerack/` are:
- `packages/core/src/public/data-source.ts` JSDoc (provenance) — acceptable, no action.
- `CHANGELOG.md` (history) — acceptable, no action.
- `packages/cyclist/src/server.ts` line 133 stale comment — this is source code (not provenance); clean it up.

Testable: `grep -r "packages/bikerack" packages/cyclist/src/ packages/core/src/` must produce zero source-code matches (JSDoc `data-source.ts` is the only exception and it is in `packages/core`, not cyclist, and is a doc comment).

**AC3: No source code imports from `packages/shared/`**

There are currently zero `import ... from '@pennyfarthing/shared'` statements in any source file — the consolidation test at `core/src/consolidation.test.ts` (AC8) already enforces this and passes. This AC is a verification gate: run `pnpm test` in `packages/core/` and confirm `consolidation.test.ts` passes. The `paths.ts` comment is a provenance note, not an import; it satisfies the "provenance headers acceptable" allowance.

**AC4: Build and tests pass after removal**

From `pennyfarthing/`:
1. `pnpm run build` — TypeScript compilation must succeed; deleting `bikerack.ts` removes a file that had no importers, so no compilation errors are expected.
2. `cd packages/cyclist && pnpm test` — `vitest run` must exit 0. The `124-4-rewire-cyclist-bikerack.test.ts` file must be updated first (AC1) or the test suite will throw on the deleted file read.
3. The remaining ACs of `124-4-rewire-cyclist-bikerack.test.ts` (AC1: no `@pennyfarthing/bikerack` in deps, AC3: ClaudeService wires `/ws/claude`, AC4: `IS_BIKERACK` removed, AC5: `claude-service.ts` stays in cyclist) must continue to pass unchanged.
