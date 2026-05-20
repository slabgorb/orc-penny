# Standalone: Rebuild WheelHub bundle with in_review status mapping

**Jira:** PROJ-16233
**Points:** 1
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/PROJ-16233-wheelhub-in-review-bundle
**PR:** 1296
**Started:** 2026-03-06
**Completed:** 2026-03-06

---

## Description

The `wheelhub.mjs` esbuild bundle was missing the `in_review` → `in_review` mapping
in `mapStoryStatus()`. Consumer project TUIs (orc-ax-1, orc-ax-2) rendered `in_review`
stories identically to `backlog` stories — wrong badge symbol and no cyan styling.

Root cause: TypeScript source was fixed in #1281, but the esbuild bundle was rebuilt
in #1282 from stale compiled JS that predated the fix.

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/_dist/server/wheelhub.mjs` | Rebuilt esbuild bundle with current dist/ |
