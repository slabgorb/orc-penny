# Standalone: Homebrew tap + shell installer

**Jira:** MSSCI-16164
**Points:** 3
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16164-homebrew-tap-shell-installer
**PR:** 1268
**Started:** 2026-03-04
**Completed:** 2026-03-04

---

## Description

Add Homebrew tap (1898andCo/homebrew-pf), shell installer, and sdist release pipeline so org members can install via `brew install 1898andco/pf/pennyfarthing`.

## Files Changed

| File | Change |
|------|--------|
| scripts/deploy.sh | Added sdist build, release asset upload, Homebrew tap dispatch |
| pennyfarthing-dist/templates/bootstrap.sh | Added brew as first-choice installer |
| pennyfarthing-dist/scripts/install.sh | New shell installer with auth check |
| scripts/homebrew/generate-formula.sh | New formula generator from pyproject.toml |
| README.md | Updated install section with brew/curl/uv options |
