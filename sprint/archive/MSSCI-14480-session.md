# MSSCI-14298-14302: [BUG] GitPanel shows dirty state after clean git operations

**Status:** in_progress
**Workflow:** trivial
**Phase:** implement
**Repos:** pennyfarthing
**Branch:** fix/gitpanel-dirty-reads
**Points:** 2
**Priority:** P1
**Jira:** MSSCI-14480

## Description

GitPanel shows red dirty indicator and stale ahead/behind counts after git cleanup leaves repos clean. The red dot and change counts persist even though `git status --porcelain` returns empty.

## Root Cause Analysis

The regex in `shouldInvalidateGitCache()` at `websocket.ts:86` fails to match `git -C <repo>` commands and chained commands (`&& git merge ...`).

```javascript
// CURRENT (broken) — anchored to start, no flags before subcommand
/^git\s+(add|commit|checkout|...)/i

// FAILS on:
"git -C pennyfarthing add ..."        // -C flag before subcommand
"git -C pennyfarthing commit ..."     // same
"... && git merge --no-ff ..."        // git not at ^ (chained)
```

**Result:** Every `git -C <repo>` operation (used for multi-repo workflows) never invalidates the cache. The panel shows the state from before those operations forever.

Verified with node test — all `git -C pennyfarthing` commands return MISS, all plain `git` commands return MATCH.

## Fix Approach

Fix the regex in `shouldInvalidateGitCache()` (`websocket.ts:86`) to handle:
1. `git -C <path>` and other flags before the subcommand (`-c`, `--git-dir`, etc.)
2. Chained commands where `git` appears after `&&` or `;`

The same pattern exists in `shouldInvalidateDiffCache()` in `git-diff.ts:462` — fix both.

## Key Files

- `packages/cyclist/src/websocket.ts:70-110` — `shouldInvalidateGitCache()` — **THE BUG** (regex line 86)
- `packages/cyclist/src/git-diff.ts:460-510` — `shouldInvalidateDiffCache()` — same regex pattern, same bug
- `packages/cyclist/src/git-cache.ts` — Cache invalidation, debounce timing (working correctly)
- `packages/cyclist/src/public/panels/GitPanel.tsx` — Panel UI (no changes needed)

## Acceptance Criteria

- [ ] `git -C <repo> add/commit/merge/push/checkout` commands trigger cache invalidation
- [ ] Chained commands (`&& git merge ...`) trigger cache invalidation
- [ ] Plain `git add/commit/push` commands still trigger cache invalidation (no regression)
- [ ] Both `shouldInvalidateGitCache` and `shouldInvalidateDiffCache` are fixed
- [ ] After commit+merge+push across multiple repos, panel shows clean when repos are clean
