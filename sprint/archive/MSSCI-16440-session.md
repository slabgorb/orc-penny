# Standalone: Update Jira label from pennyfarthing to product-pennyfarthing

**Jira:** MSSCI-16440
**Points:** 2
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16440-jira-label-update
**PR:** 1395
**Started:** 2026-03-13
**Completed:** 2026-03-13

---

## Description

Update the Jira label used on all tickets from `pennyfarthing` to `product-pennyfarthing`. The label is used when creating stories, creating standalone issues, and querying Jira for sprint reconciliation.

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/jira/create.py` | Updated `PROJECT_LABEL` constant from `"pennyfarthing"` to `"product-pennyfarthing"` |
| `pennyfarthing-dist/src/pf/jira/cli.py` | Updated hardcoded label in standalone story creation payload |
| `pennyfarthing-dist/src/pf/jira/reconcile.py` | Updated 2 JQL query strings with new label |
