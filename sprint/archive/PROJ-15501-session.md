# Standalone: Auto-pull LFS portraits on theme set

**Jira:** PROJ-15501
**Points:** 2
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/PROJ-15501-auto-pull-lfs-portraits
**PR:** 1070
**Started:** 2026-02-22
**Completed:** 2026-02-22

---

## Description

Portrait images in the TUI disappear whenever a theme's portrait files are Git LFS pointers (131-byte stubs) instead of actual image data. The portrait resolver correctly detects and skips LFS pointers, but there was no mechanism to automatically pull the real files. Users had to manually run `git lfs pull` with the right include path.

## Changes

Added `_check_portrait_lfs()` helper to `pennyfarthing-dist/pf/theme/cli.py`:

- Scans all theme directories (via `discover_all_theme_dirs`) for portrait files that are LFS pointer stubs
- Reuses `_is_lfs_pointer` from `pf/bikerack/portrait_resolver.py` for detection
- Walks up from the portrait directory to find the git repo root
- Runs `git lfs pull --include=<portraits-path>/**` scoped to just that theme's portraits
- Reports count of pulled images on success
- Non-blocking: `git-lfs` not installed, timeout, or pull errors all emit warnings to stderr

Called from `set_theme()` after config write. `--dry-run` path returns before the check.

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/pf/theme/cli.py` | +67 lines — `_check_portrait_lfs()` helper, called from `set_theme()` |

## Verification

- `pf theme set discworld` with LFS stubs — auto-pulls and reports count
- `pf theme set discworld` again — skips silently (no stubs)
- `pf theme set discworld --dry-run` — does not trigger the check
