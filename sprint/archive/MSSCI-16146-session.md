# Standalone: Wire pf validate into CI + add document type validators

**Jira:** MSSCI-16146
**Points:** 5
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16146-pf-validate-ci-doc-validators
**PR:** 1260
**Started:** 2026-03-04
**Completed:** 2026-03-04

---

## Description

Created 4 new `pf validate` adapters (adr, prd, architecture, theme), fixed 3 agent files failing validation, enhanced CLI to accept multiple validator names as positional args, added validate-framework CI job, and added dimensions block to 77 theme YAML files.

## Files Changed

| File | Change |
|------|--------|
| `.github/workflows/ci.yml` | Added validate-framework CI job |
| `pennyfarthing-dist/agents/tandem-backseat.md` | Added subagent frontmatter + output section |
| `pennyfarthing-dist/agents/tea.md` | Added missing `<critical>` section |
| `pennyfarthing-dist/agents/tech-writer.md` | Added missing `<helpers>` section |
| `pennyfarthing-dist/src/pf/validate/cli.py` | Registered 4 new validators, multi-name positional args |
| `pennyfarthing-dist/src/pf/validate/adapters/adr.py` | NEW — ADR validator |
| `pennyfarthing-dist/src/pf/validate/adapters/prd.py` | NEW — PRD validator |
| `pennyfarthing-dist/src/pf/validate/adapters/architecture.py` | NEW — Architecture doc validator |
| `pennyfarthing-dist/src/pf/validate/adapters/theme.py` | NEW — Theme validator |
| `pennyfarthing-dist/personas/themes/*.yaml` (77 files) | Added dimensions block |
| `pennyfarthing-dist/personas/themes/hogans-heroes.yaml` | Added tier, portrait_style, user_title |
| `pennyfarthing-dist/personas/themes/stephen-king.yaml` | Added tier, portrait_style, user_title |
