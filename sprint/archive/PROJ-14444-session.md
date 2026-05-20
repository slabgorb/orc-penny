# Story 79-4: Hotspot: skip orchestrator repos by type

**Jira:** PROJ-14444
**Epic:** Dialog Infrastructure + Hotspot Refactor (PROJ-14440)
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/79-4-hotspot-skip-orchestrator-repos
**PR:** #740 - feat(79-4): skip orchestrator repos by type in hotspot analysis
**Assignee:** keith.avery@slabgorb.io

## Description

Add --skip-type option to hotspots CLI (cli.py). Add skip_types parameter to analyze_all_repos() in analyze.py. Filter repos by type field from repos.yaml. Cyclist API passes --skip-type orchestrator by default. Dialog exposes "Include orchestrator" checkbox.

## Acceptance Criteria

- [ ] CLI accepts `--skip-type` option (repeatable) with values matching repo type field from repos.yaml
- [ ] analyze_all_repos() in analyze.py accepts skip_types parameter and filters repos before analysis
- [ ] Repos are correctly filtered by comparing repo type field (e.g., "orchestrator", "framework") against skip_types list
- [ ] Cyclist API (useHotspots hook) passes `--skip-type orchestrator` by default
- [ ] HotspotsDialog exposes "Include orchestrator" checkbox to toggle --skip-type orchestrator
- [ ] TDD: Red tests pass for all changes (separate test file for skip_types filtering logic)
- [ ] Existing tests continue to pass (backward compatibility)

## Technical Context

### Prior Stories

**79-1** (ToolDialog component): Created shared ToolDialog.tsx wrapper with max-w-5xl sizing, standard header/footer, close button. Located at `/pennyfarthing/packages/cyclist/src/public/components/dialogs/ToolDialog.tsx`.

**79-2** (HotspotsPanel→HotspotsDialog migration): Migrated HotspotsPanel to HotspotsDialog.tsx using ToolDialog wrapper. Removed HotspotsPanel from dockview sidebar. Component uses hook `useHotspots` with shape:
```typescript
const { data, isLoading, error, refresh } = useHotspots({ days });
```

**79-3** (DebugPanel tool launcher): Added tool launcher button row to DebugPanel below Token Stats section. "Hotspots" button opens HotspotsDialog.

### Key Files to Modify

**Backend (Python):**

1. `/pennyfarthing/pennyfarthing_scripts/hotspots/cli.py`
   - Add `--skip-type` option to `_common_options()` helper (repeatable, multiple values)
   - Pass skip_types to `_run_analysis()` and forward to analyze_all_repos()

2. `/pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py`
   - Add `skip_types: list[str] | None = None` parameter to `analyze_all_repos()` signature
   - After loading repos.yaml, filter repos: `if repo_config.get("type") not in skip_types` (if skip_types provided)
   - Keep analyze_repo() unchanged (single-repo analysis unaffected)

**Frontend (TypeScript/React):**

3. `/pennyfarthing/packages/cyclist/src/public/hooks/useHotspots.ts`
   - Modify hook to pass `--skip-type orchestrator` by default to API call
   - Add option parameter `includeOrchestrator?: boolean` to override default skip
   - When includeOrchestrator is false (default), append `--skip-type orchestrator` to API args

4. `/pennyfarthing/packages/cyclist/src/public/components/dialogs/HotspotsDialog.tsx`
   - Add checkbox state: `const [includeOrchestrator, setIncludeOrchestrator] = useState(false)`
   - Add checkbox UI in hotspots-controls section
   - Pass `includeOrchestrator` to useHotspots hook call
   - Checkbox toggles whether orchestrator repos are analyzed

### Repos.yaml Structure

Repos have a `type` field (e.g., "orchestrator", "framework"):
```yaml
repos:
  orchestrator:
    path: .
    type: orchestrator
  pennyfarthing:
    path: pennyfarthing
    type: framework
```

The filter should skip repos matching any value in skip_types list.

### Test Pattern

Story 79-3 had a "tool launcher row to DebugPanel" — similar scope. Tests should verify:
- `--skip-type orchestrator` excludes orchestrator repo from results
- Multiple `--skip-type` values work (e.g., `--skip-type orchestrator --skip-type backup`)
- Empty skip_types analyzes all repos
- Checkbox toggle correctly passes includeOrchestrator to hook
- Default behavior (without checkbox) skips orchestrator

## Notes

- Prior stories: 79-1 (ToolDialog component), 79-2 (HotspotsPanel→Dialog migration), 79-3 (DebugPanel tool launcher)
- Story 79-5 (Hotspot artifact exclusions) comes after this — expect further filtering work
- useHotspots hook is in `/pennyfarthing/packages/cyclist/src/public/hooks/useHotspots.ts`
- CLI tests use pytest; React hook tests use Vitest or similar (check existing test setup)
- Backward compatibility: analyze_repo() (single repo) should not be affected by skip_types

## Handoff: SM → TEA

- **Date:** 2026-02-08
- **From:** SM (The Mad Hatter)
- **To:** TEA (The Caterpillar)
- **Phase:** red (write failing tests)
- **Notes:** Story setup complete. Session file created, branch ready, Jira claimed. TEA should write failing tests for: --skip-type CLI option, skip_types filtering in analyze_all_repos(), React hook default parameter, dialog checkbox UI.

## TEA Assessment

**Tests Required:** Yes
**Reason:** 2-point TDD story with clear acceptance criteria across Python backend and React frontend.

**Test Files:**
- `tests/python/test_hotspots.py` — 10 new tests in `TestAnalyzeAllReposSkipTypes` (7) and `TestCLISkipType` (3)
- `packages/cyclist/tests/PROJ-14444-useHotspots-skipType.test.ts` — 6 new tests for hook skipTypes

**Tests Written:** 16 failing tests covering 5 of 7 ACs

**Coverage by AC:**
- AC1 (CLI --skip-type option): 3 tests — help text, repeatable, passthrough
- AC2 (analyze_all_repos skip_types param): 3 tests — exists, filters orchestrator, filters multiple
- AC3 (Repo filtering by type field): 2 tests — missing type field safe, skip-all-returns-error
- AC4 (Hook default skip orchestrator): 2 tests — default skip, includeOrchestrator override
- AC5 (Dialog checkbox): Implicitly tested via hook rerender test
- AC6 (TDD): This assessment
- AC7 (Backward compat): 2 tests — None/empty skip_types analyze all, existing 48 tests pass

**Existing tests:** All 48 existing Python tests pass. TypeScript backward-compat tests pass (3/6).

**Status:** RED — 16 tests failing, ready for Dev

**Handoff:** To Dev (The White Rabbit) for implementation

## Handoff: TEA → Dev

- **Date:** 2026-02-08
- **From:** TEA (The Caterpillar)
- **To:** Dev (The White Rabbit)
- **Phase:** implement (make tests GREEN)
- **Notes:** 16 failing tests across Python and TypeScript. Dev should implement: (1) `skip_types` param on `analyze_all_repos()`, (2) `--skip-type` CLI option in `_common_options()` + passthrough in `_run_analysis()`, (3) `skipTypes`/`includeOrchestrator` on `useHotspots` hook + query param forwarding, (4) `skip_type` query param in Express API, (5) checkbox in HotspotsDialog.

## Dev Assessment

**Implementation:** All 5 changes implemented across 6 files.
**Tests:** All 64 tests GREEN (58 Python + 6 TypeScript).
**PR:** #740 — https://github.com/slabgorb/pennyfarthing/pull/740

**Files Changed:**
- `pennyfarthing_scripts/hotspots/analyze.py` — added `skip_types` param, filtering logic in repo loop
- `pennyfarthing_scripts/hotspots/cli.py` — added `--skip-type` to `_common_options()`, passthrough in `_run_analysis()` and all 3 commands
- `packages/cyclist/src/public/hooks/useHotspots.ts` — added `skipTypes`/`includeOrchestrator` options, default orchestrator skip
- `packages/cyclist/src/api/hotspots.ts` — forward `skip_type` query params to Python CLI
- `packages/cyclist/src/public/components/dialogs/HotspotsDialog.tsx` — added `includeOrchestrator` state + checkbox
- `tests/python/test_hotspots.py` — 10 new tests with Path.exists mock fix

**Handoff:** To Reviewer (The Queen of Hearts) for code review

## Handoff: Dev → Reviewer

- **Date:** 2026-02-08
- **From:** Dev (The White Rabbit)
- **To:** Reviewer (The Queen of Hearts)
- **Phase:** review
- **PR:** #740
- **Notes:** All tests GREEN, PR created. Ready for review.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `HotspotsDialog checkbox` → `useHotspots(includeOrchestrator)` → `fetch(/api/hotspots?skip_type=orchestrator)` → `execFile(python3, ['--skip-type', 'orchestrator'])` → `analyze_all_repos(skip_types=['orchestrator'])` → filters repos_yaml by type field. Chain verified correct end-to-end.

**Observations:**

| # | Severity | Description | Location |
|---|----------|-------------|----------|
| 1 | [VERIFIED] | Python filtering logic correct — safe-by-default for repos missing type field | `analyze.py:452-455` |
| 2 | [VERIFIED] | CLI --skip-type repeatable, only passed to analyze_all_repos (not single-repo) | `cli.py:41,80` |
| 3 | [MEDIUM] | useCallback dep array includes `options.skipTypes` (array ref) — latent re-render trap for future callers passing inline arrays. Not triggered in current usage. | `useHotspots.ts:111` |
| 4 | [VERIFIED] | Express API uses execFile (no shell injection), String() coercion on params | `hotspots.ts:30-35` |
| 5 | [VERIFIED] | Empty state: skip all types returns error result | `analyze.py:467-471` |
| 6 | [VERIFIED] | Backward compatibility: None/empty skip_types analyze all repos | `analyze.py:452`, `cli.py:51` |
| 7 | [VERIFIED] | UI checkbox: controlled, default false (orchestrator skipped) | `HotspotsDialog.tsx:204,313-320` |
| 8 | [LOW] | Checkbox uses raw HTML instead of shadcn Checkbox component — minor style inconsistency | `HotspotsDialog.tsx:313` |
| 9 | [VERIFIED] | Test quality: proper async mocks, edge cases covered (7 Python + 3 CLI + 6 TS) | `test_hotspots.py`, `PROJ-14444-*.test.ts` |
| 10 | [VERIFIED] | Security: no injection risk, no auth bypass, AbortController prevents race conditions | All files |

**Error handling:** Empty skip → no filter (safe). All skipped → error result. Missing type field → not skipped (safe). AbortController cancels stale requests.

**Blocking issues:** None. No Critical or High.

**Handoff:** To SM (The Mad Hatter) for finish-story

## Handoff: Reviewer → SM

- **Date:** 2026-02-08
- **From:** Reviewer (The Queen of Hearts)
- **To:** SM (The Mad Hatter)
- **Phase:** finish
- **PR:** #740 — MERGED
- **Notes:** PR approved and merged. No blocking issues found. 8 verified-good observations, 1 medium (non-blocking latent re-render risk in useCallback deps), 1 low (raw HTML checkbox vs shadcn). All 64 tests pass. Ready for SM to run finish-story.
