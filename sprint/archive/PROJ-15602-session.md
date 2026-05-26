# Story 126-14: pf upgrade cleanup — remove npm artifacts and stale symlinks

## Story Details
- **ID:** 126-14
- **Jira:** PROJ-15602
- **Workflow:** trivial
- **Points:** 2
- **Repos:** pennyfarthing
- **Phase:** finish
- **Assigned:** slabgorb@gmail.com

## Description
pf upgrade detects node_modules/@pennyfarthing but doesn't clean up npm-era artifacts. After migration, users are left with: (1) node_modules/@pennyfarthing still present, (2) old Node commands/symlinks in .claude/commands that reference npx pennyfarthing, (3) stale .pennyfarthing/manifest.json (Node-era) alongside new init-manifest.json. Upgrade should offer to remove these artifacts (with user confirmation) and produce a clean post-migration state.

## Acceptance Criteria
- [ ] pf upgrade --clean offers to remove node_modules/@pennyfarthing directory
- [ ] Stale symlinks in .claude/commands/ pointing to node_modules are detected and removed
- [ ] Old manifest.json (Node-era) removed after migration to init-manifest.json
- [ ] All cleanup requires user confirmation (or --yes flag for CI)
- [ ] Dry-run shows what would be cleaned without acting

## Context
<!-- Dev agent will fill in implementation context -->

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/upgrade/core.py` — added `detect_cleanup_targets()` and `cleanup_artifacts()`, updated `run_upgrade()` with `clean` param, extended `generate_report()` with cleanup section
- `pennyfarthing-dist/src/pf/upgrade/cli.py` — added `--clean` and `--yes/-y` flags, user confirmation flow
- `pennyfarthing-dist/src/pf/tests/test_upgrade_cleanup.py` — 18 tests covering detection, removal, dry-run, CLI confirmation, and report

**Tests:** 18/18 passing (GREEN)
**Branch:** feature/PROJ-15602-pf-upgrade-cleanup (pushed)

**AC Coverage:**
- [x] pf upgrade --clean offers to remove node_modules/@pennyfarthing directory
- [x] Stale symlinks in .claude/commands/ pointing to node_modules are detected and removed
- [x] Old manifest.json (Node-era) removed after migration to init-manifest.json
- [x] All cleanup requires user confirmation (or --yes flag for CI)
- [x] Dry-run shows what would be cleaned without acting

**Handoff:** To review phase

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `--clean` CLI flag → `run_upgrade(clean=True)` → `cleanup_artifacts()` → `shutil.rmtree`/`unlink` (safe, confirmed)
**Pattern observed:** Result object pattern `{success, data}` consistently applied across all new functions at `core.py:270,323`
**Error handling:** `shutil.rmtree(ignore_errors=True)` + post-removal `exists()` check provides graceful degradation at `core.py:352-356`
**Security:** Path traversal safe — `relative_to()` guarantees no escape; symlink resolution via `resolve()` is read-only

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [MEDIUM] | Double `detect_cleanup_targets()` call in confirm path | `cli.py:43` + `core.py:335` | Not blocking — UX correctness > micro-optimization |
| [LOW] | Unused `import os` | `test_upgrade_cleanup.py:17` | Cosmetic, remove at convenience |

**Handoff:** To SM for finish-story