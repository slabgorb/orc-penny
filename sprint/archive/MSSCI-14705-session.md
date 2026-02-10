# Story 91-7: Enforce ESLint across all packages

**Jira:** MSSCI-14705
**Epic:** 91 (MSSCI-14510) — Cross-File Reference & Schema Validation Pipeline
**Points:** 3 | **Priority:** P1
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/enforce-eslint
**Assigned:** keith.avery@1898andco.io
**Started:** 2026-02-10

---

## Description

Remove continue-on-error from CI lint job. Add lint scripts to @pennyfarthing/shared and @pennyfarthing/cyclist. Fix existing lint errors.

## Acceptance Criteria

- [ ] `continue-on-error` removed from CI lint job (`.github/workflows/ci.yml`)
- [ ] Lint scripts added to `@pennyfarthing/shared` and `@pennyfarthing/cyclist` package.json
- [ ] Existing lint errors fixed across all packages
- [ ] `pnpm run lint` passes cleanly with `--max-warnings 0`

## Technical Context

### Current State
- ESLint 9.x flat config at `eslint.config.mjs` — shared across all packages
- Root lint command: `eslint 'packages/*/src/**/*.ts' --max-warnings 0`
- `packages/core` has lint script; `packages/shared` and `packages/cyclist` do not
- CI lint job at `.github/workflows/ci.yml:79` has `continue-on-error: true`
- Rules: `no-unused-vars` (warn), `no-explicit-any` (warn), `no-require-imports` (off)

### Key Files
| File | Role |
|------|------|
| `eslint.config.mjs` | ESLint flat config |
| `package.json` | Root lint script |
| `packages/core/package.json` | Has lint script |
| `packages/shared/package.json` | Needs lint script |
| `packages/cyclist/package.json` | Needs lint script |
| `.github/workflows/ci.yml` | CI lint job (remove continue-on-error) |

### Approach
1. TEA writes failing tests that verify lint passes across all packages
2. Dev adds lint scripts to shared + cyclist package.json
3. Dev fixes existing lint errors
4. Dev removes continue-on-error from CI
5. Verify pnpm run lint passes with --max-warnings 0

## TEA Assessment

**Tests Required:** Yes (verification script)
**Test File:** `tests/unit/test_eslint_enforcement.sh`

**Tests Written:** 4 checks covering all 4 ACs
**Status:** RED (4/6 failing — 2 pre-existing passes are correct)

| Check | Status | What's needed |
|-------|--------|---------------|
| AC1: CI continue-on-error | FAIL | Remove line 79 from `.github/workflows/ci.yml` |
| AC2: shared lint script | FAIL | Add `"lint": "eslint src/"` to `packages/shared/package.json` |
| AC2: cyclist lint script | FAIL | Add `"lint": "eslint src/"` to `packages/cyclist/package.json` |
| AC4: lint passes | FAIL | Fix 32 warnings (unused vars + explicit any) across core, cyclist, shared |

**Lint errors breakdown (32 warnings):**
- `packages/core/src/` — 12 warnings (all `no-unused-vars`)
- `packages/cyclist/src/` — 18 warnings (12 `no-unused-vars`, 4 `no-explicit-any`, 2 other)
- `packages/shared/src/` — 2 warnings (`no-unused-vars`)

**Note:** Also on this branch: `pennyfarthing_scripts/jira/claim.py` fix to set `assigned_to` in sprint YAML on claim.

**Handoff:** To Toby (Dev) for implementation

## Handoff Log

| Time | From | To | Notes |
|------|------|----|-------|
| 2026-02-10 | SM | TEA | Story setup complete, session created |
| 2026-02-10 | SM | TEA | Handoff to red phase — TEA to write failing tests |
| 2026-02-10 | TEA | Dev | Tests written (4 checks), RED status — Ready for implementation |
| 2026-02-10 | Dev | Reviewer | Implementation complete, 6/6 tests GREEN, PR #782 |
| 2026-02-10 | Reviewer | SM | APPROVED — PR #782 merged, no blocking issues |

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] All 32 lint warnings correctly resolved — imports removed, vars prefixed, dead code deleted
2. [VERIFIED] `broadcastContextUpdate` `as any` → proper ContextInfo literals at `websocket.ts:1259,1276,1397,1417`
3. [VERIFIED] Dead code removal safe — `triggerGitUpdate`, `todosUpdateCallback`, `runMigrations` have zero references
4. [VERIFIED] Import removals from main.ts don't break re-exports — IPC channels still re-exported at `main.ts:123-137`
5. [VERIFIED] ESLint config `caughtErrorsIgnorePattern` consistent with existing ignore patterns
6. [LOW] `_stepName` at `story-parser.ts:669` could be removed entirely (dead computation), not blocking
7. [LOW] `claim.py:174-182` inner break doesn't exit outer loop — negligible given Jira key uniqueness

**Data flow traced:** ESLint config → root lint script → CI workflow → package lint scripts — all wired correctly
**Pattern observed:** Consistent `_` prefix for intentionally unused destructured/catch vars across codebase
**Error handling:** `claim.py` uses best-effort try/except after Jira claim succeeds — acceptable pattern
**Tests:** 6/6 passing, preflight clean

**Handoff:** To SM for finish-story

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `.github/workflows/ci.yml` - Removed continue-on-error from lint job
- `eslint.config.mjs` - Added caughtErrorsIgnorePattern to no-unused-vars rule
- `packages/shared/package.json` - Added lint script
- `packages/cyclist/package.json` - Added lint script
- `packages/core/src/cli/commands/doctor-file-layout.test.ts` - Removed unused symlinkSync import
- `packages/core/src/cli/commands/e2e-fresh-install.test.ts` - Removed unused name destructuring
- `packages/core/src/cli/commands/e2e-upgrade.test.ts` - Removed unused name destructuring
- `packages/core/src/cli/commands/hooks-consolidation.test.ts` - Prefixed unused vars with _
- `packages/core/src/cli/commands/init-consolidation.test.ts` - Removed unused readFileSync import
- `packages/core/src/cli/commands/update-consolidation.test.ts` - Removed dead runMigrations function
- `packages/core/src/cli/commands/update.ts` - Removed unused readFileSync import
- `packages/core/src/cli/ocean-profiles.test.ts` - Removed unused existsSync, join imports
- `packages/core/src/plugins/plugin-discovery.test.ts` - Removed unused type imports
- `packages/core/src/scripts/generate-spider-report.ts` - Removed unused join import
- `packages/cyclist/src/main.ts` - Removed 7 unused imports
- `packages/cyclist/src/public/hooks/useSprint.ts` - Prefixed unused type destructuring
- `packages/cyclist/src/story-parser.ts` - Prefixed unused stepName var
- `packages/cyclist/src/websocket.ts` - Removed dead code, fixed as-any casts, removed unused imports
- `packages/shared/src/migrate-theme-schema.test.ts` - Removed unused basename import
- `pennyfarthing_scripts/jira/claim.py` - Set assigned_to in sprint YAML on claim

**Tests:** 6/6 passing (GREEN)
**PR:** #782 - feat(91-7): enforce ESLint across all packages
**Branch:** feat/enforce-eslint (pushed)

**Handoff:** To Reviewer for code review

---

## Handoff Completion: Reviewer → SM

**Timestamp:** 2026-02-10
**Status:** HANDOFF_RESULT: {"status": "success", "next_agent": "sm"}

**Verification Summary:**
- [x] Reviewer Assessment present with APPROVED verdict
- [x] Phase confirmed as "finish"
- [x] All 6/6 tests passing (GREEN)
- [x] PR #782 merged and ready for closure
- [x] No blocking issues identified

**Ready for:** SM finish-story workflow
