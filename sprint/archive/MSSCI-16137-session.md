---
story_id: "141-10"
jira: "MSSCI-16137"
epic: "141"
workflow: "tdd"
phase: "setup"
repos: "pennyfarthing"
branch: "feature/MSSCI-16137-convert-throw-result-cyclist-file-browser"
assigned_to: "keith.avery@1898andco.io"
started: "2026-03-05"
---

# Story 141-10: Convert Throw to Result Objects in Cyclist File-Browser

**Status:** In Progress
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-16137-convert-throw-result-cyclist-file-browser
**Jira:** MSSCI-16137
**Points:** 2

## Acceptance Criteria
- [ ] cyclist/src/file-browser.ts returns result objects instead of throwing (6 sites)
- [ ] All callers updated to handle result objects
- [ ] Tests pass

## Context
This is a 2-point chore to convert throw-based error handling in cyclist/src/file-browser.ts to return result objects (`{success, data?, error?}`) instead. There are 6 throw sites to convert, and all callers need updating.

## Technical Approach
- Identify all 6 throw sites in cyclist/src/file-browser.ts
- Define result object types if not already available
- Convert each throw to return {success: false, error: "..."}
- Update all callers to check result.success instead of try/catch
- Ensure tests pass

## SM Assessment
Story setup complete. Branch cut from develop, Jira claimed and moved to In Progress. 2-point chore — routing directly to Dev (skip TEA per DEC-SM-001). Straightforward conversion: 6 throw sites in file-browser.ts → result objects, update callers.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/cyclist/src/file-browser.ts` - Converted 7 throw sites to result objects using `FileBrowserResult<T>` type. Functions `validatePathSecurity`, `listDirectory`, and `readFile` now return `{success, data?, error?}` instead of throwing.
- `packages/cyclist/tests/MSSCI-16137-file-browser-result-objects.test.ts` - 13 tests covering all result object paths (success and error cases for listDirectory, readFile, isValidPath, and symlink security).

**Tests:** 13/13 passing (GREEN). Full cyclist suite: 2433/2433 passing.
**Branch:** feature/MSSCI-16137-convert-throw-result-cyclist-file-browser (pushed)

**Handoff:** To Reviewer for code review

## Delivery Findings

### Dev (implementation)
- **Improvement** (non-blocking): cyclist/src/file-browser.ts has zero internal callers — nobody imports from it. The core API route (`packages/core/src/server/api/file-browser.ts`) imports from core's own stub at `packages/core/src/server/file-browser.ts`, which has completely different signatures. The cyclist re-export at `packages/cyclist/src/api/file-browser.ts` re-exports from core, not from cyclist's own file-browser. This file may be dead code or a candidate for consolidation with core's stub. *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): `FileBrowserResult<T>` uses `success: boolean` with optional fields rather than a discriminated union. Consistent with project convention but a union type (`{success: true, data: T} | {success: false, error: string}`) would enable TypeScript narrowing without non-null assertions. Affects `packages/cyclist/src/file-browser.ts` (type definition at line 37-41). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `validatePathSecurity` → `listDirectory`/`readFile` — error results propagate correctly through the call chain; security checks (path normalization, symlink resolution) preserved with identical error messages
**Pattern observed:** `FileBrowserResult<T>` follows project `{success, data?, error?}` convention at `file-browser.ts:37-41`
**Error handling:** All 7 throw sites converted — 3 in `validatePathSecurity` (path escape, symlink escape, non-ENOENT realpath), 2 in `listDirectory` (not found, not directory), 2 in `readFile` (not found, not file). `isValidPath` correctly unchanged.
**Tests:** 13/13 passing, full suite 2433/2433 green
**Handoff:** To Leo McGarry (SM) for finish-story