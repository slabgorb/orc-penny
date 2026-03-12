# Standalone: Configurable PR title format via repos.yaml

**Jira:** MSSCI-16205
**Points:** 2
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16205-pr-title-format
**PR:** 1284
**Started:** 2026-03-05
**Completed:** 2026-03-05

---

## Description

Add configurable `pr_title_format` setting to repos.yaml with default template
`{jira_key} - {type}({scope}): {title}`. New `format_pr_title()` function in
pf.git.repos. Updated sm-finish, standalone, and git-cleanup to use centralized
format instead of hardcoded title strings.

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/git/repos.py` | Added `get_pr_title_format()` and `format_pr_title()` |
| `pennyfarthing-dist/agents/sm-finish.md` | Use `format_pr_title()` for PR creation |
| `pennyfarthing-dist/commands/pf-standalone.md` | Use `format_pr_title()` for PR creation |
| `pennyfarthing-dist/workflows/git-cleanup/steps/step-03-execute.md` | Use `format_pr_title()` for PR creation |
| `pennyfarthing-dist/src/pf/tests/test_pr_title_format.py` | 8 new tests |
| `.pennyfarthing/repos.yaml` | Added `pr_title_format` setting (orchestrator) |
