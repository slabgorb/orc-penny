# Standalone: Rewrite onboarding docs with three user journeys and brew-first install

**Jira:** PROJ-16187
**Points:** 3
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/PROJ-16187-rewrite-onboarding-docs
**PR:** 1276
**Started:** 2026-03-04
**Completed:** 2026-03-04

---

## Description

Rewrote GETTING-STARTED.md from scratch and fixed README.md. Three clear user journeys:
- Path A: Join an existing project (clone → bootstrap auto-installs)
- Path B: Set up a new project (brew install → pf init → /pf-setup)
- Path C: Framework development / dogfooding (orchestrator repo)

Removed all Cyclist, npm, and @pennyfarthing package references. Fixed wrong package names (pip install pf → pennyfarthing-scripts via brew/uv/pipx), stale command counts, incorrect symlink annotations.

## Files Changed

| File | Change |
|------|--------|
| README.md | Rewrote Quick Start (3 journeys), CLI Commands, Visual Dashboards, Directory Structure; removed Cyclist/npm refs |
| docs/GETTING-STARTED.md | Full rewrite — 3 user paths, accurate install commands, accurate pf doctor output, alternative installs section |
