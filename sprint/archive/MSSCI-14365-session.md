# Story: MSSCI-14365 - Audit and map all files Pennyfarthing produces outside .pennyfarthing

**Epic:** epic-85 (Clean Install Consolidation) - MSSCI-14364
**Points:** 2
**Workflow:** trivial
**Phase:** approved
**Repos:** pennyfarthing
**Branch:** feature/MSSCI-14365-audit-install-files
**Jira:** MSSCI-14365

## Acceptance Criteria

**Given** a fresh `pennyfarthing init` or `pennyfarthing update` run
**When** I audit the project directory
**Then** every file created by Pennyfarthing outside `.pennyfarthing/` is documented
**And** each file has a migration plan (move, symlink, or deprecate)

## Technical Context

- Epic context: `sprint/context/context-epic-85.md`
- Key source: `packages/core/src/cli/commands/init.ts`, `update.ts`
- Constants: `packages/core/src/cli/utils/constants.ts`
- This is a research/documentation story - output is a document, not code

## Dev Assessment

Audit document written at `docs/audit-files-outside-pennyfarthing.md`. Covers:

- **22+ files/dirs** cataloged across 5 locations outside `.pennyfarthing/`
- Each file traced to exact source line in init.ts/update.ts
- Migration plan for every file: **7 moves**, **1 symlink**, **1 deprecation**, **8 keeps**
- Legacy paths already handled by init/update documented
- Impact mapping to subsequent stories (MSSCI-14366 through MSSCI-14374)

### AC Verification

- [x] Every file created by Pennyfarthing outside `.pennyfarthing/` is documented
- [x] Each file has a migration plan (move, symlink, or deprecate)

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**

1. `[VERIFIED]` Source line references — 18/20 init.ts and update.ts references are exact-line accurate. 2 doctor.ts references are at correct content but misattribute function boundaries (cosmetic, not factual).
2. `[VERIFIED]` Completeness — cross-referenced all `writeFileSync`, `ensureDirSync`, `symlinkSync`, `copyFileSync` calls in init.ts. No file creation paths missed. CLAUDE.md confirmed as setup-workflow output, not init output.
3. `[LOW]` Summary count mismatch — "Move to .pennyfarthing/ (6 items)" header with 7-row table. **Fixed** in follow-up commit.
4. `[VERIFIED]` Migration plans — each "Keep" decision correctly identified Claude Code hard requirements (commands/, skills/, settings.local.json, project/docs/). Each "Move" targets files only read by Pennyfarthing internals.
5. `[VERIFIED]` Story impact mapping — subsequent stories MSSCI-14366 through MSSCI-14374 correctly mapped to affected files.

**AC Verification:**
- Every file created outside `.pennyfarthing/` documented: YES (19 items + 3 update-only migrations + legacy paths)
- Each file has migration plan: YES (move/symlink/deprecate/keep with rationale)

**Handoff:** To SM for finish-story

## Notes

Trivial workflow: SM → Dev (skip TEA)
