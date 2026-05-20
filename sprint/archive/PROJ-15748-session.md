# Standalone: Add theme-based spinner verbs and feature discovery tips

**Jira:** PROJ-15748
**Points:** 3
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/PROJ-15748-spinner-verbs
**PR:** 1154
**Started:** 2026-02-26
**Completed:** 2026-02-26

---

## Description

Add spinnerVerbs and spinnerTipsOverride support to Claude Code settings.local.json, synced via pf theme set and session start reconciliation.

- Add spinner_verbs (10-12 thematic verbs) to all 100 theme YAMLs
- Create data/spinner-tips.yaml with 15 feature discovery tips
- Create pf/common/spinner.py with load/sync functions
- Wire into pf theme set (instant sync) and session start (reconciliation safety net)
- Add data/ to pf init content dirs for consumer projects
- spinnerVerbs mode=replace (full thematic immersion), tips excludeDefault=false (mixed with CC defaults)

## Files Changed

| File | Change |
|------|--------|
| pennyfarthing-dist/data/spinner-tips.yaml | Created — 15 feature discovery tips |
| pennyfarthing-dist/src/pf/common/spinner.py | Created — load/sync module |
| pennyfarthing-dist/personas/themes/*.yaml (100 files) | Added spinner_verbs to theme block |
| pennyfarthing-dist/src/pf/theme/cli.py | Wire sync into pf theme set |
| pennyfarthing-dist/src/pf/hooks/session_start.py | Wire reconciliation into session start |
| pennyfarthing-dist/src/pf/init/core.py | Add data/ to _CONTENT_DIRS |
