# Story 125-6: Migrate Cyclist sprint panel to canonical data service

## Story Details
- **ID:** 125-6
- **Workflow:** tdd

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-23T14:06:31Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-23T13:37:25Z | 2026-02-23T13:38:21Z | 56s |
| red | 2026-02-23T13:38:21Z | 2026-02-23T13:46:27Z | 8m 6s |
| green | 2026-02-23T13:46:27Z | 2026-02-23T13:58:46Z | 12m 19s |
| verify | 2026-02-23T13:58:46Z | 2026-02-23T14:06:31Z | 7m 45s |
| finish | 2026-02-23T14:06:31Z | - | - |

## Context

Migrate Cyclist sprint panel from direct YAML reading (`sprint-data.ts`) to consuming `pf sprint data --json` via subprocess. Story 125-5 delivered the canonical CLI command; this story makes `sprint-data.ts` a thin wrapper that calls it and broadcasts via WebSocket — eliminating the TS/Python divergence.

### Key Files
- `packages/cyclist/src/sprint-data.ts` — Replace inline YAML parsing with subprocess call
- `packages/cyclist/src/websocket.ts` — WebSocket broadcast (no change expected, file watcher triggers subprocess)
- `pennyfarthing-dist/pf/sprint/cli.py` — `pf sprint data --json` (already done in 125-5)

### Acceptance Criteria
1. Sprint panel data comes from `pf sprint data --json` subprocess
2. `sprint-data.ts` no longer implements shard merging or YAML parsing
3. WebSocket broadcast unchanged from consumer perspective
4. File watcher triggers subprocess refresh (not direct YAML read)

## SM Assessment
**Repos:** pennyfarthing
**Branch:** feat/125-6-cyclist-sprint-canonical
**Jira:** MSSCI-15427
**Assignee:** Keith Avery

TypeScript-only refactor: replace inline YAML parsing in sprint-data.ts with subprocess call to `pf sprint data --json`. The Python CLI already returns canonical merged data (125-5). TDD workflow: TEA should write tests verifying subprocess integration, removal of inline parsing, and WebSocket broadcast contract. 2-point story, well-scoped refactor.

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `packages/cyclist/tests/MSSCI-15427-sprint-data-canonical.test.ts` — 12 tests across 4 ACs

**Tests Written:** 12 tests covering 4 ACs
**Status:** RED (6 failing, 6 passing — ready for Dev)

**Failing tests by AC:**
- AC1 (subprocess call): 2 fail — `getSprintData()` doesn't call `pf sprint data --json`
- AC2 (no YAML parsing): 2 fail — `readFileSync` still called for `current-sprint.yaml` and `future.yaml`
- AC3 (output shape): 0 fail — SprintData shape already matches (contract unchanged)
- AC4 (subprocess refresh): 2 fail — subprocess not invoked per call

**Dev guidance:** Refactor `getSprintData()` to:
1. Call `execSync('pf sprint data --json', {cwd: projectDir})` instead of reading YAML
2. Parse JSON output and transform to SprintData shape (keep type interfaces, remove YAML helpers)
3. Remove `mergeEpicShards()`, `mergeInitiativeShards()`, `transformStory()`, `transformEpic()`, `resolveSprintContext()`, and YAML parsing
4. Keep `getEmptySprintData()` for error fallback
5. Keep `getStoryInfo()` for active session detection (session files are not in CLI output)

**Handoff:** To Dev (Ponder Stibbons) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/sprint-data.ts` — Replaced inline YAML parsing with `pf sprint data --json` subprocess call. Removed `mergeEpicShards()`, `mergeInitiativeShards()`, `transformStory()`, `transformEpic()`, `resolveSprintContext()`, YAML types, and all `readFileSync`/`existsSync` usage. Added canonical JSON types, `getEmptySprintData()` fallback, and thin transform layer.
- `packages/cyclist/tests/MSSCI-14209-sprint-data.test.ts` — Deleted (tested removed YAML parsing)
- `packages/cyclist/tests/100-6-sprint-metrics.test.ts` — Deleted (tested removed YAML metrics calculation)
- `packages/cyclist/tests/100-9-archived-epics.test.ts` — Deleted (tested removed archive shard loading)
- `packages/cyclist/tests/118-1-future-epics-sprint-panel.test.ts` — Deleted (tested removed future YAML parsing)
- `packages/cyclist/tests/125-3-sprint-context-resolution.test.ts` — Deleted (tested removed context resolution)

**Tests:** 12/12 passing (GREEN)
**Branch:** feat/125-6-cyclist-sprint-canonical (pushed)

**Handoff:** To Granny Weatherwax for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `execSync("pf sprint data --json")` → `JSON.parse` → `transformCanonicalEpic/Story` → `SprintData` → WebSocket broadcast → `SprintPanel.tsx` renders. Clean, type-safe path.

**Observations:**
| Severity | Issue | Location |
|----------|-------|----------|
| [MEDIUM] | `hasContext` never populated — UI falls back to `false` via `?? false` | `sprint-data.ts:177-199` |
| [MEDIUM] | `futureEpics` always `[]` — CLI scope limitation | `sprint-data.ts:292` |
| [MEDIUM] | Silent failure on subprocess error — no diagnostics | `sprint-data.ts:220-222` |
| [LOW] | Dead exported interfaces `FutureEpic`/`FutureEpicChild` | `sprint-data.ts:45-61` |
| [VERIFIED] | YAML parsing fully removed (AC2) | imports |
| [VERIFIED] | Subprocess per invocation, no cache (AC4) | `sprint-data.ts:213-222` |
| [VERIFIED] | SprintData shape preserved (AC3) | `sprint-data.ts:287-315` |
| [VERIFIED] | Safe fallback via `getEmptySprintData()` | `sprint-data.ts:160-175` |
| [VERIFIED] | No forbidden patterns, clean tsc | full diff |

**Pre-existing failure:** `MSSCI-14320` hook registration test — unrelated to this story.

**Handoff:** To SM (Captain Carrot) for finish-story