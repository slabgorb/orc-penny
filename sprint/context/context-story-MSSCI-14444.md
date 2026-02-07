# Story Context: 79-4 - Hotspot: skip orchestrator repos by type

## Summary

Add a `--skip-type` CLI option to the hotspots Python CLI so that repos can be filtered by their `type` field from `repos.yaml`. Pass `--skip-type orchestrator` by default from the Cyclist API router so that orchestrator repo churn (sprint YAML edits, session files) is excluded from hotspot results. Optionally expose an "Include orchestrator" checkbox in `HotspotsDialog` that overrides this default.

## Current State

### repos.yaml Structure

Located at `/Users/keithavery/Projects/pf-1/repos.yaml` (31 lines). Repos are nested under a `repos:` key:

```yaml
repos:
  orchestrator:
    path: .
    type: orchestrator          # line 7
    description: Sprint management...
  pennyfarthing:
    path: pennyfarthing
    type: framework             # line 14
    description: Inlined pennyfarthing framework source...
```

The `type` field is the filtering dimension. `orchestrator` repos should be skippable.

### Python CLI (`cli.py`)

Located at `pennyfarthing/pennyfarthing_scripts/hotspots/cli.py` (153 lines).

- **`_common_options`** decorator (lines 31-41): Adds shared Click options (`--repo`, `--path`, `--days`, `--top`, `--format`, `--output`, `--exclude`, `--branch`). No `--skip-type` option exists.
- **`_run_analysis()`** (lines 44-79): Dispatches to `analyze_repo()` or `analyze_all_repos()` based on `repo`/`repo_path` args. Currently passes `excludes` and `branch` but has no `skip_types` parameter.
- **`analyze` command** (lines 131-136): `@hotspots.command()` decorated, calls `_run_analysis()` and `_output_result()`.

### Python Analysis Engine (`analyze.py`)

Located at `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` (472 lines).

- **`analyze_all_repos()`** (lines 420-472): Signature is `async def analyze_all_repos(project_root, days, excludes, branch) -> MultiRepoHotspotResult`. No `skip_types` parameter.
  - Line 441: `repos_yaml = load_yaml_config(project_root / "repos.yaml")` -- returns the full YAML dict including the top-level `repos:` key.
  - Lines 445-454: Iterates `repos_yaml.items()` directly. **Important:** Since `load_yaml_config()` (defined at `pennyfarthing/pennyfarthing_scripts/common/config.py` line 68) uses `yaml.safe_load()` which returns the raw parsed YAML, the returned dict has `repos` as a top-level key. So `repos_yaml.items()` yields `('repos', {...})` and possibly other top-level keys, NOT the individual repo entries. The current code at line 447 iterates these incorrectly but happens to work because `isinstance(repo_config, dict)` is True for the nested `repos` dict, and the iteration drills in one level. **However**, adding type-based filtering requires accessing the inner `repos` dict's per-repo config to check the `type` field.
  - Lines 447-454: For each `repo_name, repo_config` pair, extracts `path` and checks for `.git` directory.

### Cyclist API Router (`hotspots.ts`)

Located at `pennyfarthing/packages/cyclist/src/api/hotspots.ts` (59 lines).

- **`createHotspotsRouter()`** (lines 6-59): Express router handling `GET /`.
  - Lines 15-20: Builds `args` array for `python3 -m pennyfarthing_scripts.hotspots analyze --format json --days N`. No `--skip-type` in the args.
  - Lines 22-26: Optionally adds `--repo` or `--path` to args.
  - Lines 31-34: `execFile('python3', args, { cwd: pythonPath, env, timeout: 30000 })`.

### Python Models (`models.py`)

Located at `pennyfarthing/pennyfarthing_scripts/hotspots/models.py` (61 lines). Dataclasses: `FileHotspot`, `DirectoryHotspot`, `HotspotResult`, `MultiRepoHotspotResult`. No changes needed to models.

## Target State

After implementation:

1. **CLI** (`cli.py`): New `--skip-type` option in `_common_options`, passed through `_run_analysis()` to `analyze_all_repos()`
2. **Engine** (`analyze.py`): `analyze_all_repos()` accepts `skip_types: list[str] | None` parameter, filters repos by `type` field from `repos.yaml`
3. **API** (`hotspots.ts`): Passes `--skip-type orchestrator` by default; accepts optional `skip_type` query param to override
4. **Dialog** (`HotspotsDialog.tsx`): Optional "Include orchestrator" checkbox that, when checked, omits the `skip_type` query param (or passes an empty value)

### Updated API Contract

```
GET /api/hotspots
  Query params:
    days       - Time window (default 90)
    repo       - Single repo name (optional)
    skip_type  - Repo type to exclude (default: "orchestrator"; empty string = skip nothing)
```

## Key Files

### Files to Modify

| File | Location | What Changes |
|------|----------|--------------|
| `cli.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/cli.py` | Add `--skip-type` option to `_common_options` (line 31); pass through `_run_analysis()` (line 44) |
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` | Add `skip_types` param to `analyze_all_repos()` (line 420); filter repos after loading `repos.yaml` (lines 445-454); fix `repos.yaml` parsing to handle nested `repos:` key |
| `hotspots.ts` | `pennyfarthing/packages/cyclist/src/api/hotspots.ts` | Add `--skip-type orchestrator` to default args (line 15); accept `skip_type` query param |
| `HotspotsDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/dialogs/HotspotsDialog.tsx` | Add "Include orchestrator" checkbox; conditionally pass `skip_type` query param via `useHotspots` |
| `useHotspots.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useHotspots.ts` | Add optional `skipType` to `UseHotspotsOptions` (line 50); include in query params (line 80) |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `repos.yaml` | `/Users/keithavery/Projects/pf-1/repos.yaml` | Understand YAML structure: `repos:` top-level key, per-repo `type` field |
| `config.py` | `pennyfarthing/pennyfarthing_scripts/common/config.py` | `load_yaml_config()` returns raw `yaml.safe_load()` result (line 81) |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/models.py` | Verify no model changes needed |
| `server.ts` | `pennyfarthing/packages/cyclist/src/server.ts` | Hotspots router mount at line 138 |

## Technical Approach

### 1. Add `--skip-type` to CLI (`cli.py`)

Add the option in `_common_options` (after line 40, before `return fn`):

```python
fn = click.option("--skip-type", "skip_type", multiple=True, help="Skip repos with this type (repeatable)")(fn)
```

Update `_run_analysis()` signature (line 44) to accept `skip_type`:

```python
def _run_analysis(repo, repo_path, days, exclude, branch, skip_type):
    # ...
    # In the "all repos" branch (line 74-78):
    skip_types = list(skip_type) if skip_type else None
    return asyncio.run(
        analyze_all_repos(project_root, days, excludes, branch, skip_types=skip_types)
    )
```

Update all three commands (`analyze`, `files`, `dirs`) to pass `skip_type` through.

### 2. Add `skip_types` filtering to `analyze_all_repos()` (`analyze.py`)

Update the function signature (line 420):

```python
async def analyze_all_repos(
    project_root: Path,
    days: int = 90,
    excludes: list[str] | None = None,
    branch: str = "--all",
    skip_types: list[str] | None = None,
) -> MultiRepoHotspotResult:
```

Fix the `repos.yaml` parsing to handle the nested `repos:` key (replace lines 445-454):

```python
if repos_yaml and isinstance(repos_yaml, dict):
    # Handle nested 'repos:' key structure
    repo_entries = repos_yaml.get("repos", repos_yaml)
    if not isinstance(repo_entries, dict):
        repo_entries = repos_yaml

    for repo_name, repo_config in repo_entries.items():
        if isinstance(repo_config, dict):
            # Filter by type if skip_types is specified
            repo_type = repo_config.get("type", "")
            if skip_types and repo_type in skip_types:
                continue
            repo_path = repo_config.get("path", repo_name)
        else:
            repo_path = str(repo_config)

        full_path = project_root / repo_path
        if full_path.exists() and (full_path / ".git").exists():
            repos.append((repo_name, full_path))
```

This fixes the pre-existing parsing issue where `repos_yaml.items()` would iterate over top-level YAML keys (`repos`, potentially others) rather than the individual repo entries. The fix extracts the `repos` sub-dict first.

### 3. Update Cyclist API router (`hotspots.ts`)

Add `--skip-type` to the default args and accept a query param override (modify lines 13-26):

```typescript
const skipType = req.query.skip_type as string | undefined;

const args = [
  '-m', 'pennyfarthing_scripts.hotspots',
  'analyze',
  '--format', 'json',
  '--days', days,
];

// Default: skip orchestrator repos unless explicitly included
if (skipType !== '') {
  args.push('--skip-type', skipType || 'orchestrator');
}

if (repo) {
  args.push('--repo', repo);
} else {
  args.push('--path', projectDir);
}
```

Logic:
- No `skip_type` param: defaults to `--skip-type orchestrator`
- `skip_type=orchestrator`: explicit, same as default
- `skip_type=` (empty string): skip nothing, include all repos
- `skip_type=framework`: skip framework repos (unusual but supported)

### 4. Update `useHotspots` hook

Add `skipType` to `UseHotspotsOptions` (line 50 of `useHotspots.ts`):

```typescript
export interface UseHotspotsOptions {
  days: number;
  repo?: string;
  skipType?: string;
}
```

Include in query params (after line 83):

```typescript
if (options.skipType !== undefined) {
  params.set('skip_type', options.skipType);
}
```

Update the `useCallback` dependencies (line 101) to include `options.skipType`.

### 5. Add "Include orchestrator" checkbox to HotspotsDialog

Add a `useState<boolean>(false)` for `includeOrchestrator` in `HotspotsDialog`. Pass `skipType` to `useHotspots`:

```tsx
const [includeOrchestrator, setIncludeOrchestrator] = useState(false);
const { data, isLoading, error, refresh } = useHotspots({
  days,
  skipType: includeOrchestrator ? '' : undefined,
});
```

Add a checkbox in the controls bar:

```tsx
<label className="hotspots-filter-toggle">
  <input
    type="checkbox"
    checked={includeOrchestrator}
    onChange={(e) => setIncludeOrchestrator(e.target.checked)}
  />
  Include orchestrator
</label>
```

### 6. Testing

**Python tests:**
- Test `analyze_all_repos()` with `skip_types=["orchestrator"]` -- verify orchestrator repos are excluded
- Test `analyze_all_repos()` with `skip_types=None` -- verify all repos are included
- Test `repos.yaml` parsing correctly extracts the inner `repos:` dict
- Test `_run_analysis()` passes `skip_type` through correctly

**API tests:**
- Test `GET /api/hotspots` (no skip_type param) -- verify `--skip-type orchestrator` is in the args
- Test `GET /api/hotspots?skip_type=` (empty) -- verify no `--skip-type` in args
- Test `GET /api/hotspots?skip_type=framework` -- verify `--skip-type framework` in args

**Frontend tests:**
- Test `useHotspots` hook includes `skip_type` query param when `skipType` option is provided
- Test "Include orchestrator" checkbox toggles the `skipType` value

## Acceptance Criteria

- `--skip-type` CLI option exists and filters repos by `type` field from `repos.yaml`
- `analyze_all_repos()` correctly parses the nested `repos:` key in `repos.yaml`
- Cyclist API defaults to `--skip-type orchestrator` when no `skip_type` query param is provided
- Passing `skip_type=` (empty) includes all repos
- `useHotspots` hook supports optional `skipType` parameter
- `HotspotsDialog` has an "Include orchestrator" checkbox
- When unchecked (default), orchestrator repo results are excluded
- When checked, orchestrator repo results are included
- Python unit tests pass
- Frontend unit tests pass

## Dependencies

### Depends On

- None directly (this story can be implemented independently of 79-1/79-2/79-3), but the HotspotsDialog UI changes depend on 79-2 having been completed

### Depended On By

- **79-5** (Expand artifact exclusions + client filters) -- builds on the filtering infrastructure established here

## Risks / Open Questions

1. **`repos.yaml` parsing bug:** The current `analyze_all_repos()` code at line 447 iterates `repos_yaml.items()` which yields the top-level YAML keys, not the individual repo entries under `repos:`. This pre-existing issue needs to be fixed as part of this story. The fix (extracting `repos_yaml.get("repos", repos_yaml)`) is backward-compatible because it falls back to the raw dict if there is no `repos:` key.

2. **Single-repo mode bypass:** When `--repo` or `--path` is used (lines 51-73 of `cli.py`), `_run_analysis()` calls `analyze_repo()` directly, bypassing `analyze_all_repos()`. The `--skip-type` option is irrelevant in single-repo mode. The CLI should either ignore it silently or warn. Silent ignore is simpler.

3. **Multiple skip types:** The CLI uses `multiple=True` for `--skip-type`, allowing `--skip-type orchestrator --skip-type another`. The API router currently passes a single value. If multi-type filtering is needed from the API, the query param would need to support comma-separated values or repeated params. For now, single-value support is sufficient.

4. **Performance impact:** Skipping orchestrator repos reduces the number of `git log` subprocess calls (from 2 repos to 1 in this project). This should noticeably improve analysis speed, well within the 30-second timeout in `hotspots.ts` line 34.

5. **Hook re-fetch on checkbox change:** When the user toggles "Include orchestrator", `useHotspots` creates a new `fetchHotspots` callback (because `options.skipType` changes). However, `useHotspots` does NOT auto-fetch -- the user must click "Analyze" again. This is the expected behavior since hotspot analysis is an on-demand operation. Consider whether toggling the checkbox should auto-trigger a re-fetch for better UX.
