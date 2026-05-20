# Story Context: 79-5 - Hotspot: expand artifact exclusions + client filters

## Summary

Expand the `DEFAULT_EXCLUDES` list in `analyze.py` to cover non-code artifacts (YAML, Markdown, JSON config, test snapshots, images, fonts, coverage output, orchestrator-specific paths) that inflate hotspot scores without indicating code quality issues. Add client-side filter toggles in `HotspotsDialog` ("Show tests", "Show styles", "Show config") that filter the already-fetched hotspot data without requiring additional API calls.

## Current State

### DEFAULT_EXCLUDES (`analyze.py`)

Located at `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` line 32-42:

```python
DEFAULT_EXCLUDES = [
    "node_modules/*",
    "dist/*",
    "build/*",
    "*.lock",
    "*.min.js",
    "*.min.css",
    "*.map",
    "package-lock.json",
    "pnpm-lock.yaml",
]
```

Missing patterns that frequently churn without indicating code quality issues:
- Config files: `*.yaml`, `*.yml`, `*.json` (sprint YAML, `package.json`, tsconfig, etc.)
- Documentation: `*.md`
- Test snapshots: `*.snap`
- Images: `*.svg`, `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*.ico`, `*.webp`
- Fonts: `*.woff`, `*.woff2`, `*.ttf`, `*.eot`
- Coverage output: `coverage/*`, `.nyc_output/*`
- Orchestrator-specific: `.session/*`, `sprint/*`

### Exclusion Mechanism (`_should_exclude`)

Located at `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` lines 201-209:

```python
def _should_exclude(path: str, patterns: list[str]) -> bool:
    """Check if a file path matches any exclusion pattern."""
    for pattern in patterns:
        if fnmatch.fnmatch(path, pattern):
            return True
        # Also check the basename for patterns like "*.lock"
        if fnmatch.fnmatch(path.split("/")[-1], pattern):
            return True
    return False
```

This function uses `fnmatch` for glob-style matching. It checks both the full path and the basename, so patterns like `*.yaml` match files at any depth. Directory patterns like `coverage/*` match files one level deep; for recursive matching, `coverage/**` or checking path prefix would be needed.

### Exclusion usage

`_should_exclude` is called in `analyze_repo()` at line 331:

```python
if _should_exclude(fpath, all_excludes):
    continue
```

Where `all_excludes = DEFAULT_EXCLUDES + (excludes or [])` (line 279). The user can append additional patterns via the `--exclude` CLI option.

### Client-side Data in HotspotsDialog

After story 79-2, `HotspotsDialog` has `allFiles` and `allDirs` arrays (migrated from `HotspotsPanel.tsx` lines 229-243) that contain the merged hotspot data from all repos. These are currently sliced to top 50 before rendering (line 338: `allFiles.slice(0, 50)`).

There are no client-side filter controls beyond the time window selector and file/dir view toggle.

### HotspotsPanel Sub-components

From `HotspotsPanel.tsx`:
- `FileTable` receives `hotspots: FileHotspot[]` (line 58)
- `DirTable` receives `hotspots: DirectoryHotspot[]` (line 118)
- `FileHotspot` has a `path: string` field (from `useHotspots.ts` line 5)
- `DirectoryHotspot` has a `path: string` field (from `useHotspots.ts` line 17)

Client-side filtering would operate on the `path` field before passing arrays to the table components.

## Target State

After implementation:

1. **Server-side** (`analyze.py`): `DEFAULT_EXCLUDES` expanded from 9 patterns to ~30+ patterns covering all common non-code artifacts
2. **Client-side** (`HotspotsDialog.tsx`): Three filter toggles above the table:
   - "Show tests" (default: on) -- toggles visibility of `*.test.*`, `*.spec.*`, `__tests__/*`, `test/*`, `tests/*`
   - "Show styles" (default: on) -- toggles visibility of `*.css`, `*.scss`, `*.less`
   - "Show config" (default: off) -- toggles visibility of remaining config patterns that survived server-side exclusion (e.g., `tsconfig.json`, `vite.config.ts` -- note these are `.ts`/`.json` files that may not be excluded server-side)

## Key Files

### Files to Modify

| File | Location | What Changes |
|------|----------|--------------|
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` | Expand `DEFAULT_EXCLUDES` (lines 32-42); potentially update `_should_exclude` for recursive directory patterns |
| `HotspotsDialog.tsx` | `pennyfarthing/packages/cyclist/src/public/components/dialogs/HotspotsDialog.tsx` | Add filter toggle checkboxes; add client-side filtering logic before passing data to tables |

### Files to Read (Context / Reference)

| File | Location | Why |
|------|----------|-----|
| `analyze.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/analyze.py` | Current `DEFAULT_EXCLUDES` (line 32), `_should_exclude()` (line 201), `analyze_repo()` usage (line 279, 331) |
| `HotspotsPanel.tsx` | Before 79-2: `pennyfarthing/packages/cyclist/src/public/components/panels/HotspotsPanel.tsx` | Source for `allFiles`/`allDirs` memo logic (lines 229-243) that HotspotsDialog inherits |
| `useHotspots.ts` | `pennyfarthing/packages/cyclist/src/public/hooks/useHotspots.ts` | `FileHotspot` and `DirectoryHotspot` type definitions (lines 4-23) |
| `models.py` | `pennyfarthing/pennyfarthing_scripts/hotspots/models.py` | Python dataclass definitions to verify `path` field availability |

## Technical Approach

### 1. Expand `DEFAULT_EXCLUDES` in `analyze.py`

Replace lines 32-42 with the expanded list:

```python
DEFAULT_EXCLUDES = [
    # Package managers and build output
    "node_modules/*",
    "dist/*",
    "build/*",
    ".next/*",
    ".nuxt/*",
    "*.lock",
    "*.min.js",
    "*.min.css",
    "*.map",
    "package-lock.json",
    "pnpm-lock.yaml",
    "yarn.lock",
    # Configuration and data files
    "*.yaml",
    "*.yml",
    "*.md",
    "*.json",
    "*.toml",
    # Test snapshots
    "*.snap",
    # Images
    "*.svg",
    "*.png",
    "*.jpg",
    "*.jpeg",
    "*.gif",
    "*.ico",
    "*.webp",
    # Fonts
    "*.woff",
    "*.woff2",
    "*.ttf",
    "*.eot",
    # Coverage output
    "coverage/*",
    ".nyc_output/*",
    # Orchestrator-specific
    ".session/*",
    "sprint/*",
    # IDE and tool files
    ".vscode/*",
    ".idea/*",
]
```

**Important considerations:**
- `*.json` excludes `package.json`, `tsconfig.json`, etc. This is intentional -- config file churn is not a code quality signal. However, it also excludes `.json` data files that may be meaningful in some repos. The `--exclude` CLI option allows users to customize.
- `*.yaml` and `*.yml` exclude sprint files, CI configs, and other YAML. This is the primary win for orchestrator repos.
- `*.md` excludes documentation churn.
- The list does NOT exclude `*.ts`, `*.tsx`, `*.js`, `*.jsx`, `*.py`, `*.css`, `*.scss` -- these are code/style files that remain in the analysis.

### 2. Update `_should_exclude` for recursive directory patterns

The current implementation uses `fnmatch` which does not support `**` glob patterns. Directory patterns like `coverage/*` only match one level deep. To match recursively (e.g., `coverage/lcov-report/index.html`), add a path-prefix check:

```python
def _should_exclude(path: str, patterns: list[str]) -> bool:
    """Check if a file path matches any exclusion pattern."""
    for pattern in patterns:
        if fnmatch.fnmatch(path, pattern):
            return True
        # Check the basename for patterns like "*.lock"
        if fnmatch.fnmatch(path.split("/")[-1], pattern):
            return True
        # Check path prefix for directory patterns like "coverage/*"
        if pattern.endswith("/*"):
            dir_prefix = pattern[:-2]
            if path.startswith(dir_prefix + "/"):
                return True
    return False
```

This adds recursive directory exclusion: `coverage/*` will match `coverage/lcov-report/index.html` in addition to `coverage/summary.json`.

### 3. Add client-side filter toggles to HotspotsDialog

Add filter state:

```tsx
const [showTests, setShowTests] = useState(true);
const [showStyles, setShowStyles] = useState(true);
const [showConfig, setShowConfig] = useState(false);
```

Add filtering logic using `useMemo` (after `allFiles` and `allDirs` are computed):

```tsx
const TEST_PATTERNS = [/\.test\./, /\.spec\./, /\/__tests__\//, /\/test\//, /\/tests\//];
const STYLE_PATTERNS = [/\.css$/, /\.scss$/, /\.less$/];
const CONFIG_PATTERNS = [/\.config\./, /tsconfig/, /\.eslintrc/, /\.prettierrc/, /vite\.config/, /vitest\.config/];

function matchesAny(path: string, patterns: RegExp[]): boolean {
  return patterns.some(p => p.test(path));
}

const filteredFiles = useMemo(() => {
  return allFiles.filter(f => {
    if (!showTests && matchesAny(f.path, TEST_PATTERNS)) return false;
    if (!showStyles && matchesAny(f.path, STYLE_PATTERNS)) return false;
    if (!showConfig && matchesAny(f.path, CONFIG_PATTERNS)) return false;
    return true;
  });
}, [allFiles, showTests, showStyles, showConfig]);

const filteredDirs = useMemo(() => {
  return allDirs.filter(d => {
    if (!showTests && matchesAny(d.path, TEST_PATTERNS)) return false;
    if (!showStyles && matchesAny(d.path, STYLE_PATTERNS)) return false;
    return true;
  });
}, [allDirs, showTests, showStyles, showConfig]);
```

Pass `filteredFiles` and `filteredDirs` to the table components instead of `allFiles`/`allDirs`.

Add filter toggle UI in the controls section:

```tsx
<div className="hotspots-filters" data-testid="hotspots-filters">
  <label className="hotspots-filter-toggle">
    <input
      type="checkbox"
      checked={showTests}
      onChange={(e) => setShowTests(e.target.checked)}
      data-testid="filter-show-tests"
    />
    Show tests
  </label>
  <label className="hotspots-filter-toggle">
    <input
      type="checkbox"
      checked={showStyles}
      onChange={(e) => setShowStyles(e.target.checked)}
      data-testid="filter-show-styles"
    />
    Show styles
  </label>
  <label className="hotspots-filter-toggle">
    <input
      type="checkbox"
      checked={showConfig}
      onChange={(e) => setShowConfig(e.target.checked)}
      data-testid="filter-show-config"
    />
    Show config
  </label>
</div>
```

Note: "Show config" defaults to off because config files are mostly excluded server-side by `*.json`/`*.yaml`, but `.config.ts` / `.config.js` files survive server-side exclusion and are often not interesting for hotspot analysis.

### 4. Update summary stats

The summary line (showing commit count, file count, dir count) should reflect filtered counts:

```tsx
<span>{filteredFiles.length} files</span>
<span>{filteredDirs.length} dirs</span>
```

### 5. Testing

**Python tests:**
- Test expanded `DEFAULT_EXCLUDES`: verify `*.yaml`, `*.md`, `*.json`, `*.snap`, images, fonts are excluded
- Test `_should_exclude` recursive directory matching: `coverage/lcov/index.html` matches `coverage/*`
- Test `_should_exclude` does NOT exclude code files: `src/App.tsx`, `utils.py`, `main.ts`
- Test backward compatibility: original patterns (node_modules, dist, etc.) still excluded

**Frontend tests:**
- Test filter toggle rendering: all three checkboxes visible
- Test "Show tests" toggle: `*.test.tsx` files hidden when unchecked
- Test "Show styles" toggle: `*.css` files hidden when unchecked
- Test "Show config" toggle: `*.config.ts` files shown when checked
- Test filters apply independently (can combine multiple)
- Test summary stats update when filters change
- Test filters work with directory view (not just files)

## Acceptance Criteria

- `DEFAULT_EXCLUDES` expanded to cover: YAML, Markdown, JSON, TOML, test snapshots, images, fonts, coverage output, orchestrator paths, IDE files
- `_should_exclude` correctly handles recursive directory patterns (e.g., `coverage/*` matches `coverage/deep/file.txt`)
- Expanded exclusions do NOT exclude code files (`.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.css`, `.scss`)
- `HotspotsDialog` has "Show tests", "Show styles", "Show config" filter toggles
- Filters operate on already-fetched data (no additional API calls)
- "Show tests" and "Show styles" default to on; "Show config" defaults to off
- Toggling filters immediately updates the displayed table
- Summary stats reflect filtered counts
- Python unit tests pass
- Frontend unit tests pass

## Dependencies

### Depends On

- **79-2** (Migrate HotspotsPanel into HotspotsDialog) -- filter toggles are added inside HotspotsDialog
- **79-4** (Skip orchestrator repos by type) -- server-side filtering of orchestrator repos is complementary; expanded excludes further clean results for remaining repos

### Depended On By

- No direct dependents; this is the last story in Epic 79

## Risks / Open Questions

1. **Over-exclusion of `*.json` files:** Excluding all JSON files server-side means `package.json` churn is hidden, which is usually desirable, but also hides `.json` data files that might be meaningful hotspots in some projects. The `--exclude` CLI option and the existing `--exclude` support allow users to override, but there is no way to un-exclude a default pattern without modifying the code. Consider whether `DEFAULT_EXCLUDES` should use more specific patterns (e.g., `package.json`, `tsconfig*.json`, `.eslintrc.json`) instead of blanket `*.json`. The trade-off is more patterns vs. more comprehensive exclusion.

2. **`fnmatch` performance:** Adding ~30 patterns to `DEFAULT_EXCLUDES` means `_should_exclude` runs 30 `fnmatch.fnmatch()` calls per file per commit. For a repo with 500 files across 200 commits, that is 3 million fnmatch calls. `fnmatch` is implemented in C on CPython and is fast, but profile if the 30-second API timeout becomes tight. Consider compiling patterns into a single regex or using `pathlib.PurePath.match()` for optimization if needed.

3. **Client-side filter patterns:** The regex patterns for test/style/config matching are heuristics. For example, `CONFIG_PATTERNS` includes `vite.config` and `tsconfig` but may miss other config files. Users cannot customize these patterns. Consider whether the filter categories should be configurable or if the hardcoded heuristics are sufficient.

4. **Filter state persistence:** Filter toggle state is local to the `HotspotsDialog` component and is lost when the dialog is closed (Radix unmounts content). If users frequently toggle filters, this could be annoying. Consider storing filter preferences in `localStorage` or a Cyclist settings store.

5. **CSS checkbox styling:** The filter toggles use native `<input type="checkbox">` elements. These may not match the Cyclist theme. Consider using shadcn `Checkbox` component for consistent styling, though this adds an import dependency and slightly more complexity.

6. **Directory-level config filter:** The "Show config" filter makes less sense for directory-level hotspots since directories contain a mix of file types. The config filter is primarily useful for file-level view. Consider disabling the config toggle in directory view or applying it differently (e.g., only hide directories that contain exclusively config files).
