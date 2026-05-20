# Story 126-15: Pull LFS portraits during pf init/setup so TUI portraits work out of the box

## Story Details
- **ID:** 126-15
- **Jira:** PROJ-15603
- **Workflow:** trivial
- **Points:** 2
- **Priority:** p2
- **Assigned:** keith.avery@slabgorb.io

## Story Description
Portrait files are stored in Git LFS. After pf init or pf-setup, the portrait files remain as LFS pointers (ASCII text) instead of actual PNGs. The BikeRack TUI persona bar shows no portrait because the images aren't real files.

PROJ-15501 added auto-pull on theme set, but that only covers pf theme set. New installs that run pf init followed by pf-setup need LFS portraits pulled as part of the setup flow so the TUI works immediately without manual git lfs pull.

## Acceptance Criteria
- [ ] pf init or pf-setup runs git lfs pull for the selected theme's portraits
- [ ] Only pulls portraits for the active theme (not all themes)
- [ ] Graceful degradation if git-lfs is not installed (warn, don't fail)
- [ ] Works for both fresh installs and upgrades

## SM Assessment

Setup complete. Story 126-15 is a 2-point trivial — add LFS portrait pull to pf init/setup flow. PROJ-15501 already added pull on theme set; this extends coverage to the init/setup path. Key constraint: only pull active theme portraits, graceful fallback if git-lfs missing. Branch `feat/126-15-lfs-portrait-pull` ready in pennyfarthing repo.

**Repos:** pennyfarthing
**Branch:** feat/126-15-lfs-portrait-pull

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/common/themes.py` - Added `ensure_portrait_lfs()` and `_is_lfs_pointer()` as shared functions
- `pennyfarthing-dist/src/pf/init/setup.py` - Call `ensure_portrait_lfs` after theme selection in both `run_auto_setup()` and `run_setup()`
- `pennyfarthing-dist/src/pf/theme/cli.py` - Replaced inline `_check_portrait_lfs` with delegation to `ensure_portrait_lfs`

**Tests:** 54/54 passing (5 pre-existing failures unrelated to this change)
**Branch:** feat/126-15-lfs-portrait-pull (pushed)

**AC Coverage:**
- [x] pf init/setup runs git lfs pull for the selected theme's portraits — both `run_setup()` and `run_auto_setup()` now call `ensure_portrait_lfs` after theme selection
- [x] Only pulls portraits for the active theme — scoped via `--include={theme_name}/**`
- [x] Graceful degradation if git-lfs is not installed — `FileNotFoundError` caught, warning printed
- [x] Works for both fresh installs and upgrades — `/pf-setup` uses `pf theme set` (already covered by PROJ-15501); programmatic paths now covered

**Handoff:** To review phase

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
| # | Severity | Finding | Location |
|---|----------|---------|----------|
| 1 | [MEDIUM] | `_is_lfs_pointer` duplicated — exists in both `common/themes.py` and `bikerack/portrait_resolver.py` | `common/themes.py:252`, `bikerack/portrait_resolver.py:44` |
| 2 | [VERIFIED] | Data flow safe — `theme_name` from YAML config, `subprocess.run` uses list args (no shell injection), path traversal fails gracefully | `common/themes.py:287,321` |
| 3 | [VERIFIED] | Return values ignored by callers — correct, fire-and-forget matches AC3 (graceful degradation) | `setup.py:138,521` |
| 4 | [LOW] | Three separate `import click` statements inside exception handlers | `common/themes.py:330,342,351` |
| 5 | [VERIFIED] | `run_setup()` re-checks LFS unconditionally — correct, `ensure_portrait_lfs` short-circuits if no stubs found | `setup.py:511-521` |
| 6 | [VERIFIED] | `run_auto_setup()` only pulls on fresh theme step — acceptable, re-entry covered by `pf theme set` path | `setup.py:128-138` |
| 7 | [LOW] | Only `.png`/`.jpg` checked, not `.webp`/`.jpeg` — matches original, not a regression | `common/themes.py:291` |

**Data flow traced:** theme_name (config YAML) → path construction → `git lfs pull --include=` (safe, list args)
**Error handling:** FileNotFoundError, TimeoutExpired, nonzero returncode all handled gracefully
**Handoff:** To SM for finish-story

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-02-24T17:52:23Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-24T12:35:00Z | 2026-02-24T17:39:48Z | 5h 4m |
| implement | 2026-02-24T17:39:48Z | 2026-02-24T17:44:00Z | 4m 12s |
| review | 2026-02-24T17:44:00Z | 2026-02-24T17:52:23Z | 8m 23s |
| finish | 2026-02-24T17:52:23Z | - | - |