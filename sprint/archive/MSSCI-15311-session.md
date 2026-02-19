# Story 117-1: Ship pyproject.toml in npm package for consumer Python hooks

**Jira:** MSSCI-15311
**Epic:** 117 — Consumer Install — Fix v11.x postinstall gaps
**Points:** 3
**Priority:** P0
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/117-1-pyproject-toml-npm
**Started:** 2026-02-19T11:12:28Z

## Description

The npm package bundles pennyfarthing_scripts/ Python source but no pyproject.toml. All hooks delegate to uv run --project which requires pyproject.toml. Consumer projects must manually create one. Ship a template pyproject.toml in the npm package and auto-generate it during postinstall.

## Acceptance Criteria

- [ ] pyproject.toml template included in npm package (pennyfarthing-dist/)
- [ ] Postinstall generates pyproject.toml in consumer's .pennyfarthing/ directory
- [ ] uv run --project works for all hook commands after install
- [ ] Existing manual pyproject.toml files are not overwritten
- [ ] Tests verify pyproject.toml generation and hook execution

## Technical Context

- npm package source: `pennyfarthing/pennyfarthing-dist/`
- Python scripts: `pennyfarthing/pennyfarthing_scripts/`
- Hooks system: `pennyfarthing-dist/scripts/hooks/`
- Postinstall: check `pennyfarthing-dist/scripts/core/` for install scripts
- Consumer install flow: `npm install` → postinstall → setup hooks → session start

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core install flow gap — consumer hooks cannot execute without pyproject.toml

**Test Files:**
- `packages/core/src/cli/commands/pyproject-install.test.ts` — 16 tests covering all 5 ACs

**Tests Written:** 16 tests covering 5 ACs
**Status:** RED (12 failing, 4 passing — ready for Dev)

**Failure Summary:**
- AC1 (4 fails): Template `pennyfarthing-dist/templates/pyproject.toml` does not exist
- AC2 (4 fails): `init`/`update` commands don't generate `.pennyfarthing/pyproject.toml`
- AC3 (3 fails): `run-pf.sh` lacks `.pennyfarthing/pyproject.toml` resolution path
- AC4 (3 pass): No-overwrite tests pass vacuously (will be meaningful post-impl)
- AC5 (1 fail): `findLocalPyproject()` in `python.ts` doesn't check `.pennyfarthing/`

**Implementation Guidance for Dev:**
1. Create `pennyfarthing-dist/templates/pyproject.toml` — copy from repo root `pyproject.toml` but strip dev/optional deps
2. In `init.ts` and `update.ts`: copy template to `.pennyfarthing/pyproject.toml` (skip if exists or project root has one)
3. In `run-pf.sh`: add third elif for `$PROJECT_ROOT/.pennyfarthing/pyproject.toml`
4. In `python.ts findLocalPyproject()`: add check for `.pennyfarthing/pyproject.toml` relative to project root
5. Verify `package.json` `files` array already includes `pennyfarthing-dist/templates/` (confirmed — it does)

**Key Files to Modify:**
- `pennyfarthing-dist/templates/pyproject.toml` (NEW)
- `pennyfarthing-dist/scripts/lib/run-pf.sh` (add resolution path)
- `packages/core/src/cli/commands/init.ts` (generate pyproject.toml)
- `packages/core/src/cli/commands/update.ts` (generate if missing)
- `packages/core/src/cli/utils/python.ts` (findLocalPyproject)

**Handoff:** To Dev (Sergeant Carter) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/templates/pyproject.toml` — NEW consumer template with core deps only
- `pennyfarthing-dist/scripts/lib/run-pf.sh` — added `.pennyfarthing/pyproject.toml` as third resolution path
- `packages/core/src/cli/utils/python.ts` — `findLocalPyproject()` checks `.pennyfarthing/pyproject.toml` during walk-up
- `packages/core/src/cli/commands/init.ts` — `generatePyprojectToml()` copies template to `.pennyfarthing/` (skip if exists/dogfooding/project root has one)
- `packages/core/src/cli/commands/update.ts` — calls `generatePyprojectToml()` before early return + in updateInstalledContent

**Tests:** 16/16 passing (GREEN)
**Existing Tests:** 25/25 E2E install tests still passing (zero regressions)
**Branch:** feat/117-1-pyproject-toml-npm (pushed)

**Handoff:** To Reviewer for review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Template (`pennyfarthing-dist/templates/pyproject.toml`) → `readFileSync` → `writeFileSync` → `.pennyfarthing/pyproject.toml` → `run-pf.sh` bash check → `uv run --project`. No user input. Safe.
**Pattern observed:** Follows existing skip-if-exists template copy pattern at `init.ts:444-470`. Consistent.
**Error handling:** Missing template → warn and return (`init.ts:522-525`). Read errors on project pyproject.toml → caught and ignored. Dry run respected.

| # | Severity | Issue | Location |
|---|----------|-------|----------|
| 1 | [VERIFIED] | Template well-formed with correct deps and entry point | `templates/pyproject.toml:1-27` |
| 2 | [VERIFIED] | Skip logic handles exists/dogfooding/project-level correctly | `init.ts:498-518` |
| 3 | [VERIFIED] | Resolution order correct in run-pf.sh | `run-pf.sh:18-27` |
| 4 | [VERIFIED] | findLocalPyproject walk-up integration correct | `python.ts:40-49` |
| 5 | [VERIFIED] | No security concerns — no user input in data flow | `init.ts:527-530` |
| 6 | [VERIFIED] | Graceful degradation on missing template | `init.ts:522-525` |
| 7 | [MEDIUM] | Duplicate generatePyprojectToml call in update path (idempotent) | `update.ts:123,203` |
| 8 | [LOW] | run-pf.sh header comment lists 2 paths, now 3 | `run-pf.sh:4-6` |

**Handoff:** To SM for finish-story