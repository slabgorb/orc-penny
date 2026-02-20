# Story 117-10: Doctor persona-config check false negative when config.local.yaml missing

## Story Details
- **ID:** 117-10
- **Workflow:** tdd
- **Repos:** pennyfarthing

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-20T21:19:22Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-20T00:00:00Z | 2026-02-20T20:11:22Z | 20h 11m |
| red | 2026-02-20T20:11:22Z | 2026-02-20T21:15:47Z | 1h 4m |
| green | 2026-02-20T21:15:47Z | 2026-02-20T21:17:58Z | 2m 11s |
| review | 2026-02-20T21:17:58Z | 2026-02-20T21:19:22Z | 1m 24s |
| finish | 2026-02-20T21:19:22Z | - | - |

## Context

### Problem Statement
Doctor's `persona-config` check reports "No theme configured" even when `persona-config.yaml` has `theme: firefly` set correctly. The check appears to depend on `config.local.yaml` existing rather than reading `persona-config.yaml` directly.

### Expected Behavior
Doctor should read `persona-config.yaml` as the source of truth for theme configuration, not `config.local.yaml`. The `config.local.yaml` is a runtime file that may not exist yet post-install.

### Repro Steps
1. Run `/pf-setup` (which sets theme in persona-config.yaml)
2. Run `npx pennyfarthing doctor`
3. Observe: persona-config check shows warning despite the file having a valid theme
4. Workaround: Creating config.local.yaml with `theme: firefly` clears both warnings

### Technical Approach
1. Locate Doctor's persona-config check implementation in the codebase
2. Write tests demonstrating the false negative when config.local.yaml is missing but persona-config.yaml has theme set
3. Fix Doctor to read persona-config.yaml as the primary source of truth
4. Ensure config.local.yaml overrides persona-config.yaml when both exist (for runtime flexibility)
5. Verify tests pass and doctor correctly detects the theme configuration

### Acceptance Criteria
- Doctor's persona-config check reads persona-config.yaml when present
- If theme is set in persona-config.yaml, the check passes
- config.local.yaml can still override persona-config.yaml if needed
- All doctor checks pass in clean E2E install scenario

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core bug — doctor disagrees with theme loader on whether theme is configured

**Test Files:**
- `packages/core/src/cli/commands/doctor-persona-config-false-negative.test.ts` - 12 tests covering 4 ACs + consistency check

**Tests Written:** 12 tests covering 4 ACs (+ 1 consistency suite)
**Status:** RED (4 failing, 8 passing — ready for Dev)

**Failing Tests:**
1. AC1: `checkUserFilesBasic` false negative with only `persona-config.yaml` (`warn` != `pass`)
2. AC1: `checkFileLayout` false negative with only `persona-config.yaml` (`warn` != `pass`)
3. AC4: `config.local.yaml` exists but has no theme field — should warn (`pass` != `warn`)
4. Consistency: Doctor and `getCurrentTheme()` disagree on `persona-config.yaml`-only scenario

**Fix Targets:**
- `doctor.ts:633-638` (`checkUserFilesBasic`): Use `getCurrentTheme()` instead of `pathExists(config.local.yaml)`
- `doctor.ts:2793-2799` (`checkFileLayout`): Same fix — use `getCurrentTheme()` for theme detection

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/cli/commands/doctor.ts` - Replaced naive `pathExists(config.local.yaml)` checks with `getCurrentTheme(projectRoot)` in three locations: `checkUserFilesBasic`, `checkUserFiles`, and `checkFileLayout`

**Tests:** 12/12 passing (GREEN) + 50/50 existing doctor tests (zero regressions)
**Branch:** feat/117-10-doctor-persona-config-false-negative (pushed)

**Handoff:** To Reviewer

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] Data flow: `getCurrentTheme(projectRoot)` reads config.local.yaml (priority 1) then persona-config.yaml (priority 2), returns theme string or null. Doctor now uses this return value for pass/warn — correct.
2. [VERIFIED] Error handling: `getCurrentTheme()` has try/catch around YAML parsing at `themes.ts:96-104` and `themes.ts:110-118` — parse failures fall through gracefully to null.
3. [VERIFIED] No circular dependency: `themes.ts` does not import from `doctor.ts`.
4. [VERIFIED] `configPath` at `doctor.ts:2798` is still used by the fix closure at line 2814 — not dead code.
5. [LOW] Detail message at `doctor.ts:2803` still says "No theme configured at .pennyfarthing/config.local.yaml" but check now also reads persona-config.yaml. Slightly imprecise but points user to correct fix action.
6. [VERIFIED] Performance: 3 calls to getCurrentTheme() across 3 separate functions — each does at most 2 sync file reads. Negligible for a doctor command.
7. [VERIFIED] All 62 tests pass (12 new + 50 existing). Zero regressions.

**Pattern observed:** Reuse of existing utility function (`getCurrentTheme`) rather than duplicating fallback logic — correct approach at `doctor.ts:635,729,2799`.
**Error handling:** Delegated to `getCurrentTheme()` which handles YAML parse errors gracefully at `themes.ts:102-104,116-118`.

**Handoff:** To SM for finish-story