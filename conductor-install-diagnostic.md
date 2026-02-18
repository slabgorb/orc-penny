# Conductor Pennyfarthing Install Diagnostic Report

**Date:** 2026-02-18
**Project:** ~/Projects/conductor
**Installed Version:** @pennyfarthing/core@11.2.2
**Install Type:** npm package (symlinks to node_modules)
**Status:** All issues resolved — 12/12 hooks passing

---

## Issues Found & Fixed

### 1. Missing `pyproject.toml` — all Python hooks fail

**Severity:** CRITICAL
**Status:** FIXED

All hooks route through `run-pf.sh` which calls `uv run --project <dir> pf hooks <cmd>`. This requires a `pyproject.toml` that declares the `pennyfarthing-scripts` Python package. Conductor had none.

**Error:** `Error: No pyproject.toml found for pennyfarthing-scripts`

**Impact:** Every hook (session-start, stop, pre/post tool use, statusline) failed on every session. The agent ran completely unguarded — no bell mode, no context warnings, no reflector checks, no schema validation, no status line.

**Resolution:** Created `pyproject.toml` at conductor root that:
- Declares the same dependencies as `pennyfarthing-scripts` (pyyaml, ruamel.yaml, httpx, click, pydriller)
- Registers the `pf` CLI entry point (`pennyfarthing_scripts.cli:main`)
- Uses `tool.setuptools.packages.find` with `where = ["node_modules/@pennyfarthing/core"]` to discover the bundled Python source

**Framework note:** The npm package bundles `pennyfarthing_scripts/` source in `node_modules/@pennyfarthing/core/` but does not ship a `pyproject.toml`. Consumer projects must provide their own. This should be documented or automated in the postinstall.

### 2. All hooks referenced bare `pf` command — not in PATH

**Severity:** CRITICAL
**Status:** FIXED

`settings.local.json` contained **10 hook commands** using bare `pf`:
```
pf hooks session-start
pf hooks reflector-check
pf hooks pre-edit-check
pf hooks context-warning
pf hooks context-breaker
pf hooks schema-validation
pf hooks cyclist-pretooluse
pf hooks bell-mode
pf hooks sprint-yaml
pf hooks statusline
```

**Problem:** `pf` is not globally installed and not in PATH. The npm package installs as `pennyfarthing` (not `pf`) in `node_modules/.bin/`. The correct wrapper is `"$CLAUDE_PROJECT_DIR"/.pennyfarthing/scripts/core/pf.sh`.

**Resolution:** All 10 bare `pf` references replaced with `"$CLAUDE_PROJECT_DIR"/.pennyfarthing/scripts/core/pf.sh hooks <subcommand>`.

### 3. `setup-env.sh` missing execute permission

**Severity:** CRITICAL
**Status:** FIXED

`.pennyfarthing/project/hooks/setup-env.sh` had mode `644` (not executable), causing `Permission denied` on every session start.

**Resolution:** `chmod +x .pennyfarthing/project/hooks/setup-env.sh`

### 4. Stale `.claude/manifest.json` (v8.1.0) conflicted with `.pennyfarthing/manifest.json` (v11.2.2)

**Severity:** CRITICAL
**Status:** FIXED

| Field | `.claude/manifest.json` (stale) | `.pennyfarthing/manifest.json` (current) |
|-------|------------------------|-------------------------------|
| Version | 8.1.0 | 11.2.2 |
| managedPaths | `.claude/agents`, `.claude/commands`, `.claude/guides`, `.claude/skills`, `.claude/personas`, `.claude/scripts` | `.claude/commands`, `.claude/skills`, `.pennyfarthing/agents`, `.pennyfarthing/guides`, `.pennyfarthing/output-styles`, `.pennyfarthing/personas`, `.pennyfarthing/scripts`, `.pennyfarthing/workflows` |

**Resolution:** Deleted stale `.claude/manifest.json`. The canonical manifest at `.pennyfarthing/manifest.json` (v11.2.2) is now the sole source of truth.

### 5. 41 stale commands in `.claude/commands/`

**Severity:** HIGH
**Status:** FIXED

`.claude/commands/` had **101 files** vs **60** in `pennyfarthing-dist/commands/`. 41 extra commands were old non-prefixed names from before the `pf-` prefix migration:
```
architect.md, brainstorming.md, check.md, chore.md, close-epic.md,
continue-session.md, create-branches-from-story.md, create-theme.md,
dev.md, devops.md, git-cleanup.md, health-check.md, help.md,
list-themes.md, orchestrator.md, parallel-work.md, party-mode.md,
permissions.md, pm.md, prime.md, release.md, repo-status.md, retro.md,
reviewer.md, run-ci.md, set-theme.md, show-theme.md, sm.md,
sprint-planning.md, sprint.md, standalone.md, start-epic.md,
sync-epic-to-jira.md, sync-work-with-sprint.md, tea.md, tech-writer.md,
theme-maker.md, update-domain-docs.md, ux-designer.md, work.md, workflow.md
```

**Resolution:** Removed all 41 stale commands. Commands now 60/60, matching dist exactly.

### 6. 22 stale skills in `.claude/skills/`

**Severity:** HIGH
**Status:** FIXED

`.claude/skills/` had 44 entries. 20 were old non-prefixed duplicates, plus 1 orphaned (`dev-patterns`), plus `yq`:
```
agentic-patterns, changelog, code-review, context-engineering, cyclist,
dev-patterns, finalize-run, jira, judge, just, mermaid, otel,
permissions, persona-benchmark, sprint, story, systematic-debugging,
testing, theme, theme-creation, workflow, yq
```

**Resolution:** Removed all 22 stale skill directories. Skills now 22 entries, matching the 22 actual skills in dist (dist also contains 2 schema files that are correctly excluded).

### 7. Missing `.pennyfarthing/templates` symlink

**Severity:** HIGH
**Status:** FIXED

`pennyfarthing-dist/` includes a `templates/` directory but no symlink existed at `.pennyfarthing/templates`.

**Resolution:** Created symlink: `.pennyfarthing/templates -> ../node_modules/@pennyfarthing/core/pennyfarthing-dist/templates`

### 8. Stale `.claude/personas/` directory from v8.1.0 layout

**Severity:** MEDIUM
**Status:** FIXED

Contained `custom/` and `themes/` subdirectories from the old `.claude/*` layout. Personas now live at `.pennyfarthing/personas/` (symlinked correctly).

**Resolution:** Removed `.claude/personas/` directory.

### 9. Broken hook path in `.claude/settings.json`

**Severity:** MEDIUM
**Status:** FIXED

`settings.json` referenced `.claude/project/hooks/setup-env.sh` which doesn't exist. The actual file is at `.pennyfarthing/project/hooks/setup-env.sh`.

**Resolution:** Updated path from `.claude/project/hooks/setup-env.sh` to `.pennyfarthing/project/hooks/setup-env.sh`.

### 10. Duplicate permissions in `settings.local.json`

**Severity:** LOW
**Status:** FIXED

Permissions list included both old-style and new-style skill names (72 total entries). Only the `pf-` prefixed versions are needed.

**Resolution:** Trimmed to 22 `pf-` prefixed skill permissions.

---

## Post-Fix Verification

All 12 hooks tested end-to-end with clean environment (no inherited `PROJECT_ROOT`):

| Hook | Type | Result |
|------|------|--------|
| session-start | SessionStart | PASS |
| setup-env | SessionStart | PASS |
| auto-load-sm | SessionStart (startup) | PASS |
| reflector-check | Stop | PASS |
| pre-edit-check | PreToolUse | PASS |
| context-warning | PreToolUse | PASS |
| context-breaker | PreToolUse | PASS |
| schema-validation | PreToolUse | PASS |
| cyclist-pretooluse | PreToolUse | PASS |
| bell-mode | PostToolUse | PASS |
| sprint-yaml | PostToolUse | PASS |
| statusline | StatusLine | PASS |

| Check | Before | After |
|-------|--------|-------|
| Hook pass rate | 0/12 | 12/12 |
| `pyproject.toml` | Missing | Created |
| Bare `pf` hook references | 10 | 0 |
| Conflicting manifests | 2 | 1 |
| Commands (`.claude/commands/`) | 101 | 60 (matches dist) |
| Skills (`.claude/skills/`) | 44 | 22 (matches dist) |
| Templates symlink | Missing | Linked |
| Stale `.claude/personas/` | Present | Removed |
| Broken hook paths | 1 | 0 |
| Skill permissions | 72 | 22 |

## What Was Already Working

- All `.pennyfarthing/` symlinks resolve correctly (agents, guides, personas, scripts, workflows, output-styles, gates)
- npm package installed at correct version (11.2.2)
- `.claude/commands/` and `.claude/skills/` are file copies (correct for npm installs)
- `repos.yaml` properly configured for orchestrator + api + ui
- Sprint directory and session directory present
- `config.local.yaml` well-formed with theme, layout, cyclist path
- `auto-load-sm.sh` hook present and functional
- `pf.sh` wrapper script exists and reachable

## Root Cause

Two compounding issues:

1. **Missing Python project config:** The npm package bundles `pennyfarthing_scripts/` Python source but no `pyproject.toml`. All hooks delegate to `uv run --project`, which requires a `pyproject.toml` to resolve dependencies and the `pf` entry point. Without it, every hook fails silently.

2. **Upgrade debris from v8.x → v11.x:** The postinstall script created the new `.pennyfarthing/*` symlink layout but did not clean up old `.claude/*` layout artifacts (manifest, personas, non-prefixed commands/skills). The `settings.local.json` was generated with bare `pf` hook commands instead of the `pf.sh` wrapper path.

## Framework Improvement Recommendations

1. **Ship `pyproject.toml` in the npm package** or auto-generate one during postinstall for consumer projects
2. **Postinstall cleanup:** Remove stale `.claude/*` artifacts when upgrading from pre-11.x layouts
3. **Hook generation:** Use `"$CLAUDE_PROJECT_DIR"/.pennyfarthing/scripts/core/pf.sh` paths in generated `settings.local.json`, not bare `pf`
4. **Chmod:** Ensure project hook templates are generated with execute permission
