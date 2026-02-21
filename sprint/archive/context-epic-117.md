# Epic 117: Consumer Install — Fix v11.x postinstall gaps

**Priority:** P0
**Status:** in_progress
**Repos:** pennyfarthing

## Overview

This epic addresses critical postinstall and hook generation issues that break consumer installations of pennyfarthing v11.x. The framework bundles Python hooks and scripts, but the install/setup process is incomplete:

1. No `pyproject.toml` shipped in npm package — consumers must manually create one to run hooks
2. Hook commands generated with bare `pf` instead of wrapper path — not in PATH during installation
3. Stale artifacts from v8-10.x upgrades left in place — conflicts and clutter
4. Generated hook scripts created with wrong permissions — causes immediate failures on session start

## Stories

### 117-1: Ship pyproject.toml in npm package for consumer Python hooks (3 pts, P0)
- Bundle a template `pyproject.toml` in `pennyfarthing-dist/`
- Auto-generate it in consumer's `.pennyfarthing/` during postinstall
- Verify `uv run --project` works for all hook commands after install
- Don't overwrite existing user-created `pyproject.toml` files
- Add tests for generation and hook execution

**Key files:**
- npm package source: `pennyfarthing/pennyfarthing-dist/`
- Python scripts: `pennyfarthing/pennyfarthing_scripts/`
- Hooks system: `pennyfarthing-dist/scripts/hooks/`
- Postinstall: check `pennyfarthing-dist/scripts/core/` for install scripts

### 117-2: Generate hook commands with pf.sh wrapper path, not bare pf (2 pts, P0)
- Update hook generation to use full wrapper path: `$CLAUDE_PROJECT_DIR/.pennyfarthing/scripts/core/pf.sh`
- Ensure hooks are executable after generation without requiring manual PATH setup
- Verify hook commands execute correctly from consumer projects

**Key files:**
- Hook generation: likely in `pennyfarthing-dist/scripts/hooks/` or settings-related modules

### 117-3: Postinstall cleanup of stale pre-11.x artifacts (3 pts, P1)
- Detect and remove: `.claude/manifest.json`, `.claude/personas/`, non-prefixed commands (41 extras), non-prefixed skills (22 extras)
- Add option to cleanup during postinstall or explicit update command
- Preserve user-created artifacts, only remove framework-created ones

**Key files:**
- Postinstall/update command: `pennyfarthing-dist/scripts/core/`

### 117-4: Ensure project hook templates have execute permission (1 pt, P1)
- Generated hook scripts (setup-env.sh etc) created with 644, should be 755
- Fix permission on generation and test that hooks are executable
- Workflow: trivial

**Key files:**
- Hook script generation: likely in `pennyfarthing-dist/scripts/`

## Related Issues

- MSSCI-15304: Original conductor install diagnostic (predecessor context)
- Consumer feedback: npm install → session start fails due to missing pyproject.toml and permission errors

## Technical Debt

- Postinstall process needs consolidation (multiple scripts, unclear flow)
- Hook generation logic split across multiple modules
- No integration tests for full install → session start flow
