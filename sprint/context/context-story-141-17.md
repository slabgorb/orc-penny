---
parent: context-epic-141.md
workflow: tdd
---

# Story 141-17: Replace TypeScript story-parser with pf CLI Subprocess Calls

## Business Context

`story-parser.ts` is 886 lines of TypeScript that directly parses session markdown files and sprint YAML to produce `StoryInfo` objects for the BikeRack GUI panels. The same file exists verbatim in both `packages/core/src/server/` and `packages/cyclist/src/`, meaning every bug fix and format change must be applied twice. It contains 13 regex patterns to handle historical session file format variations, hardcodes a Jira instance URL, and reimplements logic (sprint aggregation, workflow phase resolution, story status normalization) that the `pf` Python CLI already owns.

141-16 adds `--json` output to the relevant `pf` CLI commands. This story consumes that work: TypeScript stops parsing files directly and instead shells out to `pf story info --json` and `pf workflow phases --json`, trusting the CLI as the single source of truth. The duplicate file in cyclist is deleted entirely. The Jira URL moves to config so it is no longer baked into the binary.

The net result is that format changes to session files or sprint YAML require only Python changes, not coordinated edits to two TypeScript files.

## Technical Guardrails

**Files being replaced:**
- `pennyfarthing/packages/core/src/server/story-parser.ts` — primary file (~886 lines), exports `parseSessionFile`, `parseSprintYaml`, `parseWorkflowPhases`, `generateEpicContext`, `parseAvailableWorkflows`
- `pennyfarthing/packages/cyclist/src/story-parser.ts` — byte-for-byte duplicate; same exports, same interfaces

**Hardcoded Jira URL to remove:**
```typescript
// packages/core/src/server/story-parser.ts, line 42
const JIRA_BASE_URL = 'https://1898andco.atlassian.net/browse';
```
Config key and resolution path TBD based on how 141-16 exposes it (likely `.pennyfarthing/config.local.yaml` via `pf config get jira.base_url`).

**Interfaces to preserve** (consumed by route handlers and React panels):
- `StoryInfo` — full story data shape returned by the API
- `WorkflowPhase` / `WorkflowStep` — workflow phase list with `done/current/pending` status
- `SprintStory`, `EpicContext` — expandable sprint/epic section data
- `CriteriaItem`, `AvailableWorkflow` — AC checklist and workflow discovery panel

These TypeScript interfaces must remain export-compatible so downstream consumers (`packages/core/src/routes/`, `packages/cyclist/src/` panel components) require no changes.

**Subprocess pattern to use:**
```typescript
import { execSync } from 'child_process';

function callPf(args: string[], projectDir: string): unknown {
  const output = execSync(`pf ${args.join(' ')}`, {
    cwd: projectDir,
    encoding: 'utf8',
  });
  return JSON.parse(output);
}
```
Return `{success, data?, error?}` — never throw. Wrap `execSync` in try/catch.

**Build order dependency:** 141-16 must be merged and `pf` CLI must expose `--json` on `story info` and `workflow phases` before this story begins implementation (GREEN phase). TEA can write failing tests against the subprocess interface immediately.

**Never-edit zones:**
- `node_modules/` — trace any symlink issues to `pennyfarthing-dist/`
- `.pennyfarthing/` symlinked dirs — source lives at `pennyfarthing/pennyfarthing-dist/`

**Import rule:** Use `.js` extensions in all relative TypeScript imports.

## Scope Boundaries

**In scope:**
- Delete `packages/cyclist/src/story-parser.ts` entirely
- Replace `packages/core/src/server/story-parser.ts` body with subprocess calls to `pf story info --json` and `pf workflow phases --json`
- Remove `import { parse as parseYaml } from 'yaml'` and direct `fs` reads for session/sprint files from story-parser
- Remove `const JIRA_BASE_URL` hardcode; source Jira URL from `pf config get` or from the JSON payload returned by `pf story info --json`
- Preserve all exported TypeScript interfaces unchanged (no breaking changes to consumers)
- Update `packages/cyclist/src/` imports that previously pointed to its local `story-parser.ts` to instead use the core re-export or call the API
- GUI panels (TUI, GUI, IDE modes) must continue to render story info, sprint progress, workflow phases, AC checklist, and Jira links correctly after the change
- Unit tests: mock subprocess calls; test JSON-to-interface mapping; test error path when `pf` returns non-zero exit

**Out of scope:**
- `packages/core/src/bmad/story-parser.ts` — this is a separate BMAD story file parser with a different purpose; do not touch
- Changes to the `pf` CLI itself — that is 141-16's work
- Changes to API route handlers in `packages/core/src/routes/` beyond what is forced by removing the import
- Theme loader consolidation — that is 141-19
- Workflow engine consolidation — that is 141-18
- Any new `--json` flags not already delivered by 141-16

## AC Context

**AC: Both core and cyclist story-parser.ts replaced with pf CLI subprocess calls**

- `packages/core/src/server/story-parser.ts` no longer contains any `readFileSync`, `readdirSync`, `statSync`, or `parseYaml` calls related to session files or sprint YAML
- `packages/cyclist/src/story-parser.ts` is deleted; `git status` shows it as removed
- All calls to `parseSessionFile`, `parseSprintYaml`, `parseWorkflowPhases` delegate to `execSync('pf story info --json', ...)` or `execSync('pf workflow phases --json', ...)`
- Subprocess calls use `{success, data?, error?}` result object; no `throw` on CLI error — instead return `{success: false, error: stderr}`
- Tests mock `child_process.execSync` and assert that the correct `pf` subcommand and flags are passed for each parsing scenario

**AC: No direct sprint YAML or session file parsing in TypeScript**

- `grep -r 'parseYaml\|readFileSync.*\.yaml\|readFileSync.*session' packages/core/src/server/story-parser.ts packages/cyclist/src/` returns no matches after the change
- The 13 regex patterns previously used to handle session file format variations (`listStoryMatch`, `headerMatch`, `storyFieldMatch`, `tableStoryMatch`, etc.) are removed from TypeScript — format handling lives exclusively in the Python CLI
- Integration test: given a real project directory with a session file in any supported format, `pf story info --json` returns a correctly structured JSON payload, and the TypeScript wrapper maps it to `StoryInfo` without error

**AC: Jira URL comes from config not hardcode**

- `const JIRA_BASE_URL = 'https://1898andco.atlassian.net/browse'` is removed from `story-parser.ts`
- `jiraUrl` fields in `StoryInfo`, `SprintStory`, and `EpicContext` are populated from the JSON payload returned by `pf story info --json` (which reads from config)
- If the CLI payload omits `jiraUrl` (config not set), the TypeScript layer returns `null` for those fields — no fallback hardcode
- Test: assert that when `pf story info --json` returns `{"jiraUrl": null}`, the mapped `StoryInfo.jiraUrl` is `null`, not the old hardcoded string

**AC: GUI panels still render correctly**

- BikeRack story panel (TUI, GUI, IDE) shows: story ID, title, current phase, sprint progress bar, workflow phase list with done/current/pending status, AC checklist, and Jira link (when config is set)
- `AvailableWorkflow` discovery panel continues to list all detected workflows
- `EpicContext` expandable section shows sibling stories with correct status badges
- Manual smoke test: `pf bikerack start` with an active session — all panel sections populate without errors in the browser console
- No TypeScript compilation errors (`pnpm run build` passes in both `packages/core` and `packages/cyclist`)
- Existing route handler tests in `packages/core/src/routes/` continue to pass without modification

**AC: Depends on 141-16**

- TEA phase writes failing tests that import the new subprocess-based `story-parser.ts` interface and mock `execSync` — tests fail because the implementation still uses direct file parsing
- Dev phase implements the subprocess replacement, making tests pass
- If 141-16 is not yet merged when this story enters Dev phase, the story is blocked; Dev must not proceed with a stub implementation that will be replaced again
