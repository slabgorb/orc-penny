# Story 117-12: Fix version reporting inconsistency (2.0.0 vs 11.4.0)

**Status:** in-progress
**Phase:** finish
**Workflow:** trivial
**Repos:** pennyfarthing
**Branch:** fix/117-12-fix-version-reporting
**Jira:** (none)
**Points:** 1
**Epic:** 117 — Consumer Install — Fix v11.x postinstall gaps

## Description

npx pennyfarthing --version reports 2.0.0 while doctor, update, and manifest all report 11.4.0. The CLI reads version from the wrong package.json.

## Acceptance Criteria

- [ ] `npx pennyfarthing --version` reports the correct version (matching 11.x)
- [ ] Version source is consistent across all CLI entry points

## Context

This is a 1-point trivial fix. The CLI likely reads from a nested or incorrect package.json instead of the root pennyfarthing package.json.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/cli/index.ts` — replaced inline version resolution (hardcoded `'2.0.0'` fallback + wrong path) with `getPackageVersion()` from `utils/version.ts`

**Root Cause:** `cli/index.ts` resolved `VERSION` file relative to `__dirname` (`../../VERSION`), which pointed to `packages/core/VERSION` (nonexistent). Both try/catch blocks failed silently, falling through to the hardcoded `'2.0.0'` default. Meanwhile `getPackageVersion()` in `utils/version.ts` correctly probes multiple paths and is already used by `doctor`, `update`, `manifest`, and `version` commands.

**Fix:** Import and call `getPackageVersion()` instead of inline logic. Net -20 lines, +2 lines. Removed unused imports (`readFileSync`, `fileURLToPath`, `dirname`, `join`).

**Tests:** Pre-existing failures (85/242) in workflow loader — unrelated to this change. Verified identical failure count with and without the fix.
**Branch:** fix/117-12-fix-version-reporting (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `getPackageVersion()` → VERSION file (3 path probes) → package.json fallback (3 paths) → `'0.0.0'` sentinel → `program.version()`. No user input, no injection.
**Pattern observed:** DRY — eliminated duplicate version resolution in favor of existing shared utility at `utils/version.ts:11`
**Error handling:** All failure modes handled internally by `getPackageVersion()` with `existsSync` + try/catch cascades. `'0.0.0'` fallback is safer than old `'2.0.0'`.
**Findings:** 1 low (pre-existing empty VERSION file edge case). No critical/high issues.
**Handoff:** To SM for finish-story