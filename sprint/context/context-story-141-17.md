---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-17: Replace TypeScript File Parsers with pf CLI Subprocess Calls

## Business Context

This story merges the scope of the original 141-17 (story-parser replacement) and 141-19 (theme-loader replacement). Both follow the identical anti-pattern: TypeScript reimplements Python business logic by parsing files directly. Consolidating them into one story reduces PR count, review burden, and ensures a single consistent subprocess delegation pattern is established once and reused.

Three TypeScript files are the targets:

- `story-parser.ts` (886 lines, duplicated in both `packages/core` and `packages/cyclist`) — reimplements session file parsing (13 regex formats), sprint YAML aggregation, workflow phase resolution, story status normalization, and Jira URL generation.
- `theme-loader.ts` (577 lines in `packages/core/src/shared/`) — mirrors the Python theme discovery algorithm with a hardcoded `CATEGORY_MAP` of 130+ entries.
- `pennyfarthing.ts` (420 lines in `packages/core/src/server/`) — duplicates project detection, theme config loading, and persona assembly.

After this story, all three delegate to `pf` CLI `--json` endpoints. Format changes to session files, sprint YAML, or theme YAML require only Python changes.

## Technical Guardrails

### Files Being Replaced

**Story parser:**
- `pennyfarthing/packages/core/src/server/story-parser.ts` — primary file (~886 lines), exports `parseSessionFile`, `parseSprintYaml`, `parseWorkflowPhases`, `generateEpicContext`, `parseAvailableWorkflows`
- `pennyfarthing/packages/cyclist/src/story-parser.ts` — byte-for-byte duplicate; same exports, same interfaces

**Theme loader:**
- `pennyfarthing/packages/core/src/shared/theme-loader.ts` — 577 lines; exports `discoverAllThemeDirs()`, `listThemes()`, `loadTheme()`, `deriveCategory()`, and `CATEGORY_MAP`
- `pennyfarthing/packages/core/src/server/pennyfarthing.ts` — 420 lines; contains `findPennyfarthingRoot`, theme config loading, persona assembly

**Hardcoded Jira URL to remove:**
```typescript
// packages/core/src/server/story-parser.ts, line 42
const JIRA_BASE_URL = 'https://1898andco.atlassian.net/browse';
```

### Interfaces to Preserve

These TypeScript interfaces must remain export-compatible so downstream consumers require no changes:

From story-parser:
- `StoryInfo` — full story data shape returned by the API
- `WorkflowPhase` / `WorkflowStep` — workflow phase list with `done/current/pending` status
- `SprintStory`, `EpicContext` — expandable sprint/epic section data
- `CriteriaItem`, `AvailableWorkflow` — AC checklist and workflow discovery panel

From theme-loader:
- `ThemeMetadata` — theme discovery result
- `AgentPersona` — persona data for a themed agent

### Subprocess Pattern

Use the `pf` binary resolution strategy from 141-16 (check `PF_BIN` env var → `~/.local/bin/pf` → bare `pf` on PATH):

```typescript
import { execFileSync } from 'child_process';

function callPf(args: string[], projectDir: string): { success: boolean; data?: unknown; error?: string } {
  try {
    const pfBin = resolvePfBinary(); // shared utility from 141-16
    const output = execFileSync(pfBin, args, {
      cwd: projectDir,
      encoding: 'utf8',
      timeout: 10000,
    });
    return { success: true, data: JSON.parse(output) };
  } catch (err) {
    return { success: false, error: String(err) };
  }
}
```

Return `{success, data?, error?}` — never throw. Wrap `execFileSync` in try/catch.

### Caching Strategy

CLI results are cached in-memory with FSWatcher-based invalidation:

- **Sprint/session data** — cache invalidated when any file in `.session/` or `sprint/` changes
- **Theme data** — cache invalidated when theme YAML files or `.pennyfarthing/config.local.yaml` change
- **Cache TTL fallback** — 30 seconds as safety net for cases where FSWatcher misses events
- **FSWatcher** — the only non-delegatable TypeScript concern; retained for real-time GUI responsiveness

This ensures subprocess calls are not spawned on every panel render. The cache is warm for the common case (panel refresh, focus change) and only cold after a file mutation.

### Shared Subprocess Mock Helper

Create a test utility for mocking `child_process.execFileSync` calls to `pf`:

```typescript
// packages/core/src/test-utils/pf-mock.ts
export function mockPfCall(command: string, response: object): void { /* ... */ }
export function mockPfError(command: string, code: number, error: object): void { /* ... */ }
```

This utility is reused by 141-18 (workflow engine delegation). It should handle:
- Matching specific `pf` subcommands and returning JSON
- Simulating error responses (non-zero exit, error JSON)
- Asserting which commands were called and with what args

### Category Migration (from 141-19)

Each theme YAML file in `pennyfarthing-dist/personas/themes/` gains a `category:` top-level field. Values sourced from the existing `CATEGORY_MAP` in `theme-loader.ts`. After migration, `CATEGORY_MAP` and `deriveCategory()` are deleted from TypeScript.

### Trivial Items Absorbed from 141-21

During this refactor, also handle:
- **toSlug/oceanSuffix dedup** — `pennyfarthing.ts` and `theme-agents.ts` both define these; extract to a shared utility during the `pennyfarthing.ts` refactor
- **Jira URL dedup** — removed from `story-parser.ts` as part of the main replacement

### Build Order Dependency

141-16 must be merged and `pf` CLI must expose `--json` on all target commands before this story begins implementation (GREEN phase). TEA can write failing tests against the subprocess interface immediately.

### Recommended Sequence with 141-22 (pf serve)

If 141-22 (pf serve) lands before this story, the subprocess pattern described here should be replaced with `fetch('/api/pf/...')` calls through WheelHub's reverse proxy. This is simpler (no `pf` binary resolution, no subprocess error parsing, no TypeScript-side caching — `pf serve` handles caching server-side). The interfaces and ACs remain the same; only the transport changes from subprocess to HTTP.

Recommended sequence: **141-16 → 141-22 → 141-17 → 141-18**. If 141-22 is not ready, fall back to the subprocess pattern described here.

### Never-Edit Zones

- `node_modules/` — trace any symlink issues to `pennyfarthing-dist/`
- `.pennyfarthing/` symlinked dirs — source lives at `pennyfarthing/pennyfarthing-dist/`

### Import Rule

Use `.js` extensions in all relative TypeScript imports.

## Scope Boundaries

**In scope:**
- Delete `packages/cyclist/src/story-parser.ts` entirely
- Replace `packages/core/src/server/story-parser.ts` body with subprocess calls to `pf sprint story show --json` and `pf workflow phases --json`
- Remove `const JIRA_BASE_URL` hardcode; source Jira URL from the JSON payload
- Replace `packages/core/src/shared/theme-loader.ts` discovery/loading/category logic with `pf theme list --json` / `pf theme show --json` subprocess calls; delete `CATEGORY_MAP` and `deriveCategory()`
- Replace `packages/core/src/server/pennyfarthing.ts` project detection and persona assembly with `pf CLI` subprocess calls
- Add `category:` field to every core theme YAML in `pennyfarthing-dist/personas/themes/`
- Retain FSWatcher logic for cache invalidation
- Implement in-memory cache with FSWatcher invalidation and 30s TTL fallback
- Create shared subprocess mock helper (`pf-mock.ts`) for tests
- Deduplicate `toSlug()` / `oceanSuffix()` into a single shared utility
- Preserve all exported TypeScript interfaces unchanged
- Update `packages/cyclist/src/` imports that pointed to local `story-parser.ts`
- Contract tests validating CLI JSON schemas match TypeScript interfaces
- Measure panel render latency before and after
- GUI panels (TUI, GUI, IDE modes) render correctly

**Out of scope:**
- `packages/core/src/bmad/story-parser.ts` — separate BMAD parser with different purpose; do not touch
- Changes to the `pf` CLI itself — that is 141-16's work
- Changes to API route handlers beyond what is forced by removing imports
- Workflow engine consolidation — that is 141-18
- Any new `--json` flags not already delivered by 141-16
- `packages/cyclist/src/pennyfarthing.ts` — cyclist variant is a separate file; may be addressed in follow-on
- `portrait-resolver.ts` — not a discovery-logic file; keep unchanged
- Theme packages (`@pennyfarthing/themes-*`) category fields — those packages add their own `category:` independently

## AC Context

**AC1: Both core and cyclist story-parser.ts replaced with pf CLI subprocess calls**

- `packages/core/src/server/story-parser.ts` no longer contains any `readFileSync`, `readdirSync`, `statSync`, or `parseYaml` calls related to session files or sprint YAML
- `packages/cyclist/src/story-parser.ts` is deleted; `git status` shows it as removed
- All calls to `parseSessionFile`, `parseSprintYaml`, `parseWorkflowPhases` delegate to `execFileSync('pf', ['sprint', 'story', 'show', ...])` or `execFileSync('pf', ['workflow', 'phases', ...])`
- Subprocess calls use `{success, data?, error?}` result object; no `throw` on CLI error
- Tests mock `child_process.execFileSync` using the shared `pf-mock.ts` helper

**AC2: No direct sprint YAML or session file parsing in TypeScript**

- `grep -r 'parseYaml\|readFileSync.*\.yaml\|readFileSync.*session' packages/core/src/server/story-parser.ts packages/cyclist/src/` returns no matches
- The 13 regex patterns previously used for session file format variations are removed from TypeScript
- Integration test: given a real project directory with a session file, `pf sprint story show --json` returns correctly structured JSON, and the TypeScript wrapper maps it to `StoryInfo` without error

**AC3: Jira URL comes from config not hardcode**

- `const JIRA_BASE_URL = 'https://1898andco.atlassian.net/browse'` is removed
- `jiraUrl` fields populated from the JSON payload returned by `pf sprint story show --json`
- If the CLI payload omits `jiraUrl`, the TypeScript layer returns `null` — no fallback hardcode
- Test: assert that when CLI returns `{"jiraUrl": null}`, mapped `StoryInfo.jiraUrl` is `null`

**AC4: TypeScript theme discovery replaced with pf CLI calls**

- `theme-loader.ts` no longer reads theme YAML files directly via `readdirSync` / `readFileSync` / `parseYaml`
- `listThemes()` calls `pf theme list --json` as a subprocess
- `loadTheme(id)` calls `pf theme show <id> --json` as a subprocess
- Both functions return `{success, data?, error?}` objects
- Testable: `grep -n "readdirSync\|readFileSync\|parseYaml" packages/core/src/shared/theme-loader.ts` returns no matches related to theme discovery

**AC5: CATEGORY_MAP eliminated; categories declared in theme YAML**

- `CATEGORY_MAP` export is deleted from `theme-loader.ts`
- `deriveCategory()` function is deleted
- Every theme YAML under `pennyfarthing-dist/personas/themes/` has a `category:` field
- `grep -rn "CATEGORY_MAP" packages/` returns no matches
- `grep -L "^category:" pennyfarthing-dist/personas/themes/*.yaml` returns empty

**AC6: pennyfarthing.ts project detection and persona assembly use pf CLI**

- `pennyfarthing.ts` removes `findPennyfarthingRoot` directory walk
- Theme config loading and persona assembly delegate to `pf persona current --json`
- FSWatcher instantiation and file-watch callback remain in TypeScript
- `grep -n "parseYaml\|readdirSync\|findPennyfarthingRoot" packages/core/src/server/pennyfarthing.ts` returns no matches

**AC7: FSWatcher retained for cache invalidation only**

- FSWatcher watches `.session/`, `sprint/`, theme YAML dirs, and `.pennyfarthing/config.local.yaml`
- On file change, the in-memory cache for the relevant data category is cleared
- Cache TTL of 30s as safety fallback
- No subprocess is spawned by the watcher itself — it only invalidates cache

**AC8: Panel render latency measured before/after with no perceptible regression**

- Before implementing: measure wall-clock time for story panel, sprint panel, theme panel renders using browser DevTools or `performance.now()` instrumentation
- After implementing: measure the same panels
- Target: no panel render exceeds 200ms cold, 50ms warm (from cache)
- Results documented in the PR description

**AC9: Contract tests validate CLI JSON schemas match TypeScript interfaces**

- Golden file or snapshot tests that call each `pf` `--json` endpoint and validate the response contains all fields expected by the TypeScript interfaces
- Both Python and TypeScript test suites validate against the same contract
- If Python changes the schema, TypeScript tests break before shipping

**AC10: GUI panels still render correctly**

- BikeRack story panel shows: story ID, title, current phase, sprint progress, workflow phase list, AC checklist, Jira link
- Theme panel shows all characters with correct portraits and categories
- `AvailableWorkflow` discovery panel lists detected workflows
- Manual smoke test: `pf bikerack start` with an active session — all panels populate without browser console errors
- `pnpm run build` passes in both `packages/core` and `packages/cyclist`

**AC11: Depends on 141-16**

- TEA phase writes failing tests using `pf-mock.ts` — tests fail because implementation still uses direct file parsing
- Dev phase implements subprocess replacement, making tests pass
- Story is blocked if 141-16 is not merged
