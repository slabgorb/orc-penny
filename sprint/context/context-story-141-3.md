---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-3: Audit Unexported Hooks — Export or Delete

## Business Context

The public hooks directory (`packages/core/src/public/hooks/`) contains 34 hook files but `index.ts` only exports 13 of them. The remaining 20 hooks are silently importable by consumers (via direct path imports) but absent from the public API surface. This creates two risks: (1) consumers may inadvertently depend on internal hooks that have no stability guarantee, and (2) dead or deprecated hooks continue to exist and confuse contributors.

`useMessageStream` is a concrete example of this debt — it was the original WebSocket hook for subscribing to Claude messages, but it has been superseded by `ClaudeContext` (`packages/core/src/public/contexts/ClaudeContext.tsx`), which provides a single shared WebSocket connection for all components. The index.ts comment on line 20 already reads `// useMessageStream is deprecated - use ClaudeContext instead`, but the file itself was never deleted.

This story brings the hooks directory to a well-defined state: every file is either a first-class export in `index.ts`, or it is gone. It is part of the March 2026 tech debt audit (Epic 141) that also addresses dead shims, test coverage gaps, and error handling violations across the framework.

## Technical Guardrails

**Primary file locations:**

- `packages/core/src/public/hooks/index.ts` — the public export surface; currently exports 13 hooks
- `packages/core/src/public/hooks/*.ts` — 34 hook files total (13 exported, 20 unexported, 1 deprecated)
- `packages/core/src/public/contexts/ClaudeContext.tsx` — replacement for `useMessageStream`; exports `ClaudeProvider` and `useClaudeContext`

**The 13 currently exported hooks (do not touch these exports):**

`useAgentLoad`, `useClaude`, `useCommandHistory`, useDiffs`, `useGitStatus`, `useMarkdownParser`, `useMessageQueue`, `usePersona`, `useStatsStrip`, `useStory`, `useSyntaxHighlighter`, `useTabCompletion`, `useTodos`

**The 20 unexported hooks (each needs a decision — export or delete):**

| Hook | Internal consumers | Notes |
|---|---|---|
| `useCodeMarkers` | 6 files | Wraps `/api/code-markers`; used by components |
| `useColorScheme` | 2 files | Reads `data-variant` attribute on document root |
| `useComplexity` | 3 files | REST variant wrapping `/api/complexity` |
| `useDataSource` | 8 files | Generic WebSocket DataSource abstraction |
| `useDeadCode` | 4 files | REST variant wrapping `/api/dead-code` |
| `useDependencies` | 3 files | REST variant wrapping `/api/dependencies` |
| `useFileBrowser` | 1 file | Fetches directory listings from `/api/files` |
| `useFocusPanel` | 3 files | WebSocket `/ws/focus` panel focus events |
| `useHealthScore` | 3 files | REST variant wrapping `/api/health-score` |
| `useHotspots` | 11 files | REST variant wrapping `/api/hotspots` |
| `useLayoutPersistence` | 2 files | GET/PATCH `/api/settings/layout` |
| `useMarkerActions` | 1 file | Parses CYCLIST markers for QuickActions |
| `usePlanModeExit` | 1 file | Plan mode → accept mode transition |
| `useResponsiveLayout` | 3 files | Breakpoint detection and sidebar width |
| `useSprint` | 4 files | WebSocket `/ws/sprint` via `useDataSource` |
| `useSubagentHelper` | 2 files | Themed helper data for subagent display |
| `useTandemObservations` | 2 files | WebSocket `/ws/tandem` tandem observations |
| `useTeamMembers` | 5 files | WebSocket `/ws/team`, `/ws/tasks`, `/ws/messages` |
| `useUserAvatar` | 2 files | GitHub/Gravatar avatar fetch |
| `useMessageStream` | 0 source files (deprecated) | Replaced by `ClaudeContext` |

**`useMessageStream` removal details:**

- File: `packages/core/src/public/hooks/useMessageStream.ts`
- Establishes its own WebSocket connection to `/ws/claude` and owns its own reconnect loop — duplicating what `ClaudeContext` already provides
- Referenced only in: a JSDoc comment in `packages/core/src/public/types/message.ts` (not an import) and a deprecated comment in `index.ts`
- No component or hook file imports `useMessageStream` — confirmed by grep
- Safe to delete outright

**Import resolution constraint:**

All unexported hooks are imported internally via relative paths (e.g., `import { useHotspots } from './useHotspots.js'`). Adding them to `index.ts` does not affect these internal imports. Removing a hook file requires verifying no file imports it by relative path before deletion.

**TypeScript build:** `packages/core` compiles via `pnpm run build` in the `pennyfarthing/` monorepo. All changes must compile cleanly.

## Scope Boundaries

**In scope:**

- Audit all 34 files in `packages/core/src/public/hooks/` against `index.ts` exports
- Add exports to `index.ts` for any hook that has internal consumers and should be part of the public API
- Delete `packages/core/src/public/hooks/useMessageStream.ts`
- Remove the deprecated comment block from `index.ts` (line 20: `// useMessageStream is deprecated - use ClaudeContext instead`)
- Verify no remaining file imports `useMessageStream` (only the JSDoc comment reference in `types/message.ts` is acceptable)
- Write tests (TDD workflow): RED tests assert the expected export surface before changes, GREEN after

**Out of scope:**

- Changing the behavior of any hook — this is audit/export plumbing only
- Removing other deprecated hooks (only `useMessageStream` is explicitly targeted)
- Migrating any component from `useMessageStream` to `ClaudeContext` (no component uses `useMessageStream`)
- Modifying `ClaudeContext.tsx` — it is already the replacement and is not affected
- Changes to any other package (`packages/cyclist`, `packages/shared`)

## AC Context

**AC 1: Every hook file in `public/hooks/` is either exported from `index.ts` or deleted**

- Start by listing all `.ts` files in `packages/core/src/public/hooks/` (excluding `index.ts`)
- Cross-reference against `export` statements in `index.ts`
- For each unexported hook with internal consumers: add an `export { HookName } from './HookName.js'` line to `index.ts` under the appropriate section comment
- For `useMessageStream`: delete the file (no consumers)
- Testable: after changes, `ls packages/core/src/public/hooks/*.ts | grep -v index.ts` produces a list where every name appears in `index.ts`; `wc -l` on the hooks directory minus index.ts equals the number of named exports in `index.ts`

**AC 2: `useMessageStream` is removed (deprecated in favor of `ClaudeContext`)**

- Delete `packages/core/src/public/hooks/useMessageStream.ts`
- Remove the comment `// useMessageStream is deprecated - use ClaudeContext instead` from `index.ts` (line 20)
- Testable: `ls packages/core/src/public/hooks/useMessageStream.ts` returns "No such file"; `grep -r "import.*useMessageStream" packages/core/src` returns no results; `grep -r "useMessageStream" packages/core/src/public/hooks/index.ts` returns no results

**AC 3: No hook file exists without a corresponding export or explicit deprecation plan**

- After AC 1 and AC 2 are satisfied, this AC is automatically satisfied — every remaining file is exported
- If the team decides any hook should be internal-only (not exported), a `// @internal` JSDoc tag and a comment in `index.ts` must document the decision explicitly
- Testable: run a script that compares filenames in `hooks/` to export names in `index.ts`; all match

**AC 4: All existing imports still resolve after changes**

- All 20 unexported hooks are imported internally via relative paths (not from the index barrel), so adding exports does not change resolution for internal consumers
- Deleting `useMessageStream.ts` is safe because zero source files import it (verified above)
- Testable: `pnpm run build` in `pennyfarthing/packages/core` exits 0; `pnpm run build` in `pennyfarthing/packages/cyclist` exits 0; `pnpm test` passes across the monorepo
- For TDD RED phase: write a test that asserts `useMessageStream` is NOT exported from the index (import attempt fails or named export is absent) — this will fail until the deletion is done
