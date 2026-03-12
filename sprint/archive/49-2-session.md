# Story 49-2: Remove legacy TypeScript — dead CLI, BMAD, Jira modules

**Status:** in_progress
**Phase:** finish
**Workflow:** trivial
**Repos:** pennyfarthing
**Branch:** feature/49-2-remove-legacy-typescript
**Jira:**
**Points:** 3

## Acceptance Criteria
- All dead TypeScript CLI modules removed from the codebase
- All dead BMAD TypeScript modules removed
- All dead Jira TypeScript modules removed (replaced by Python `pf/jira/`)
- No remaining imports or references to removed modules
- Build passes cleanly after removal
- No runtime regressions

## Technical Approach
Post ADR-0034 migration, several TypeScript modules are now dead code — their functionality has moved to Python (`pennyfarthing-dist/src/pf/`). This story removes:
1. **Dead CLI modules** — TypeScript CLI entry points replaced by the `pf` Python CLI
2. **BMAD modules** — Legacy TypeScript BMAD integration no longer referenced
3. **Jira modules** — TypeScript Jira client replaced by `pf/jira/` Python package

Approach: Identify all dead TS modules via import tracing, remove them, update any barrel exports or references, verify build and tests pass.

## SM Assessment
Story setup complete. Trivial workflow — routing directly to Dev for implementation. Branch `feature/49-2-remove-legacy-typescript` created from `develop` in pennyfarthing repo. This is a cleanup story removing dead TypeScript after the Python migration (ADR-0034). No Jira key assigned.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/jira/` — removed 4 files (jira-epic-creation, jira-sprint-sync + tests)
- `packages/core/src/bmad/` — removed 11 files (context-reader, epics-parser, story-parser, story-exporter, status-sync, index + tests)
- `packages/core/src/cli/index.ts` — removed dead CLI entry point (Commander-based, 6k lines)
- `packages/core/src/cli/commands/` — removed 21 files (command, cyclist, doctor, skill, theme, uninstall, update, version + tests)
- `packages/core/src/cli/workspace.test.ts` — updated stale assertion (cli/index.ts → cli/utils/)

**Retained:** `packages/core/src/cli/utils/` — exported utilities still used by live code (files.ts, manifest.ts, version.ts, python.ts, settings.ts, themes.ts, stale-artifacts.ts)

**Tests:** 2417 TS (2407 passed, 8 pre-existing failures) + 1934 Python (1931 passed, 1 pre-existing failure) — GREEN
**Branch:** feature/49-2-remove-legacy-typescript (pushed)
**Impact:** -20,153 lines, 38 files removed/modified

**Handoff:** To Leto II (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] No dangling imports — grep across all `.ts` in `packages/core/src/` confirms zero references to deleted `bmad/`, `jira/jira-`, `cli/commands/`, `cli/index`
2. [VERIFIED] Barrel exports clean — `src/index.ts` only exports from `cli/utils/` (retained), nothing from deleted modules
3. [VERIFIED] Retained `cli/utils/` is actively used — exported by `index.ts` (version, manifest, files) and imported by 3 scripts
4. [VERIFIED] Stale dist artifacts cleaned — no orphaned `.js` in `dist/` for deleted modules
5. [VERIFIED] workspace.test.ts update is correct — assertion changed from `cli/index.ts` to `cli/utils/`, ADR-0034 referenced
6. [LOW] Deleted command test files tested dead *command* code, not the retained utilities — no coverage regression
7. [VERIFIED] Build passes, tests GREEN (pre-existing failures only)

**Data flow traced:** No new data flows — pure deletion story. Verified no live imports depend on deleted modules.
**Pattern observed:** Correct retention of `cli/utils/` which is the barrel-exported utility layer. Dead code identified via import tracing — sound methodology.
**Error handling:** N/A — deletion story, no new code.
**Security analysis:** N/A — removing code, no new attack surface.

**Handoff:** To Stilgar (SM) for finish-story

## Delivery Findings

<!-- delivery-findings-start -->
### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- No upstream findings during code review.
<!-- delivery-findings-end -->

## Progress
- [x] Setup complete
- [x] Identified dead modules via import tracing and barrel export analysis
- [x] Removed jira/, bmad/, cli/commands/, cli/index.ts
- [x] Updated workspace.test.ts stale assertion
- [x] Build passes, tests GREEN
- [x] Committed and pushed