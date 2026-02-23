# Standalone: Add configurable portrait size to BikeRack TUI

**Jira:** MSSCI-15519
**Points:** 2
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-15519-portrait-size-setting
**PR:** 1080
**Started:** 2026-02-23
**Completed:** 2026-02-23

---

## Description

Add `portrait_size` setting (`auto` | `large` | `medium` | `small` | `off`) to `config.local.yaml`. The BikeRack TUI reads it at startup and adjusts portrait image search order, CSS dimensions, and header max-height accordingly. Auto mode adapts based on terminal row count (>=40 large, >=25 medium, >=15 small, <15 off).

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/pf/bikerack/portrait_resolver.py` | Add `preferred_size` parameter to `_find_portrait()` and `resolve_portrait_path()` |
| `pennyfarthing-dist/pf/bikerack/tui.py` | Add `PORTRAIT_SIZE_CONFIG`, `_resolve_effective_size()`, dynamic CSS sizing, bump max-height |
| `pennyfarthing-dist/pf/settings/settings.py` | Add `portrait_size` to `SHOW_KEYS` and `DEFAULTS` |
