# Story 120-7: Refactor remaining call sites to use get_dist_root()

**Jira:** MSSCI-15409
**Epic:** 120 — BikeRack TUI Enhancements
**Points:** 2
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** refactor-remaining-dist-root-callsites
**Assigned:** keith.avery@1898andco.io

---

## Acceptance Criteria

- [ ] All 5 remaining modules refactored to use `get_dist_root()` instead of hardcoded `root / "pennyfarthing-dist" / ...`
- [ ] Tests added for each refactored call site
- [ ] No regressions in existing test suite

## Context

Follow-up from story 120-5 (MSSCI-15401). The reviewer identified 5 modules that still hardcode `pennyfarthing-dist` paths:

1. `pf/git/hooks_installer.py` (lines 51, 131) — `pf git install-hooks` fails with "pennyfarthing-dist required"
2. `pf/cli.py` (line 300) — `pf help` command registry not found
3. `pf/bikerack/portrait_resolver.py` (lines 104-122) — portraits not found, TUI shows placeholder
4. `pf/hooks/statusline.py` (lines 258-261) — theme YAML not found, statusline shows raw theme name
5. `pf/prime/tandem_awareness.py` (line 181) — tandem config resolution

### Technical Approach

Pattern established in 120-5:
- Import `get_dist_root` from `pf.common.config`
- Replace `root / "pennyfarthing-dist" / ...` with `get_dist_root(root) / ...`
- Handle `None` return (dist root not found) gracefully

---

## Session Log

### Setup — SM

## SM Assessment

- Jira MSSCI-15409 created under epic MSSCI-15396, claimed, In Progress
- Session created, branch `refactor-remaining-dist-root-callsites` from `develop`
- Follow-up from 120-5 reviewer finding [MEDIUM]: 5 remaining hardcoded paths
- Workflow: trivial (SM → Dev → Reviewer → SM)
- Pattern established in 120-5 — mechanical refactor, no design decisions needed

**Handoff:** To Major Winchester for implementation

### Implement Phase — Dev

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pf/git/hooks_installer.py` — Use `get_dist_root()` for dist discovery + dynamic relative symlink paths via `os.path.relpath`
- `pf/cli.py` — Help command registry resolution via `get_dist_root()`
- `pf/validate/adapters/tandem_awareness.py` — Agent directory resolution via `get_dist_root()`
- `pf/hooks/statusline.py` — Theme YAML fallback via `get_dist_root()` when `.pennyfarthing/` path doesn't have the theme
- `pf/tests/test_dist_root.py` — 4 new tests for remaining call sites + removed unused `os` import (120-5 LOW finding)

**Note:** `portrait_resolver.py` was listed in the story but has NO `pennyfarthing-dist` reference — it already uses `discover_all_theme_dirs()` (refactored in 120-5). The Cyclist portrait fallback paths reference `packages/cyclist/portraits/`, a separate concern. Skipped as not applicable.

**Tests:** 35/35 passing (GREEN)
**Regression:** 0 new failures (1324 passing, 53+27 pre-existing)
**Branch:** refactor-remaining-dist-root-callsites (pushed)

**Handoff:** To Colonel Potter for review

### Review Phase — Reviewer

## Reviewer Assessment

**Verdict:** APPROVED

| Severity | Observation | Location |
|----------|-------------|----------|
| [VERIFIED] | All 4 call sites refactored to `get_dist_root()` with None checks | hooks_installer:52, cli:297, tandem_awareness:181, statusline:259 |
| [VERIFIED] | Data flow traced: `install_git_hooks` → `get_dist_root` → `os.path.relpath` for dynamic symlinks | hooks_installer:131 |
| [VERIFIED] | Error handling: each site degrades gracefully when dist root is None | All 4 files |
| [MEDIUM] | `pf_dist` resolved vs `d_dir` unresolved — `os.path.relpath` could miscompute with symlinked project roots | hooks_installer:131 |
| [LOW] | Print msg still says "pennyfarthing-dist/scripts/hooks/" in npm context | hooks_installer:72 |
| [VERIFIED] | 4 new tests cover all refactored call sites against npm_layout fixture | test_dist_root.py |
| [VERIFIED] | `portrait_resolver.py` confirmed — no `pennyfarthing-dist` refs, correctly skipped | N/A |
| [VERIFIED] | Removed unused `import os` (120-5 LOW finding) | test_dist_root.py:10 |
| [VERIFIED] | No remaining hardcoded path construction in target files; other files already use `get_dist_root()` with fallbacks | Codebase scan |

**No Critical or High issues.** Clean, focused refactoring following the 120-5 pattern.

**Handoff:** To Hawkeye for finish-story