# Story 93-2: Move benchmark commands, skills, and scripts to new package

**Jira:** PROJ-14631
**Epic:** epic-93 (Extract Benchmarking System into @pennyfarthing/benchmark)
**Points:** 3
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/PROJ-14631-benchmark-move-commands

## Description

Move into packages/benchmark/:
- Commands: solo.md, benchmark.md, benchmark-control.md, job-fair.md
- Skills: judge/, finalize-run/, persona-benchmark/
- Shell scripts: benchmark-runner.*, job-fair-*.sh, parallel-benchmark.sh, aggregate-benchmark-stats.*, consolidate-job-fair.sh, convert-jobfair-to-benchmarks.sh
- Python scripts: swebench-judge.py, ground-truth-judge.py, ensure-swebench-data.sh, test-cache.sh, test-setup.sh
- Tier scripts: compute_theme_tiers.py, compute-theme-tiers.sh, update-theme-tiers.sh
- Scenarios: entire scenarios/ directory

Update all internal path references within moved files.

Out of scope: plugin discovery (93-3), core cleanup (93-5).

## Acceptance Criteria

- [ ] All listed commands, skills, scripts, and scenarios moved to packages/benchmark/
- [ ] Internal path references updated in moved files
- [ ] Package builds successfully
- [ ] No broken imports within moved files

## Technical Approach

Bulk file move operation with path reference updates. Trivial workflow — no test design phase needed.

## SM Assessment

Story is a bulk move operation. Straightforward file relocation with path fixups. Trivial workflow is appropriate — direct handoff to Dev.

## Handoff: SM → Dev

**From:** SM (The Mad Hatter)
**To:** Dev (The White Rabbit)
**Workflow:** trivial (no TEA phase)

### Context for Dev

This is a bulk file move operation. Story 93-1 already created the package shell at `packages/benchmark/` with TS modules. Now move the remaining assets:

- **Commands** (4): solo.md, benchmark.md, benchmark-control.md, job-fair.md
- **Skills** (3 dirs): judge/, finalize-run/, persona-benchmark/
- **Shell scripts**: benchmark-runner.*, job-fair-*.sh, parallel-benchmark.sh, aggregate-benchmark-stats.*, consolidate-job-fair.sh, convert-jobfair-to-benchmarks.sh
- **Python scripts**: swebench-judge.py, ground-truth-judge.py, ensure-swebench-data.sh, test-cache.sh, test-setup.sh
- **Tier scripts**: compute_theme_tiers.py, compute-theme-tiers.sh, update-theme-tiers.sh
- **Scenarios**: entire scenarios/ directory

After moving, update internal path references in moved files.

### Key References
- ADR: docs/adr/0020-benchmark-package-extraction.md
- Epic context: sprint/context/context-epic-93.md
- Package location: pennyfarthing/packages/benchmark/

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- 88 files moved via `git mv` across commands/, skills/, scripts/, scenarios/
- `packages/benchmark/package.json` - added non-TS assets to files array
- `src/job-fair-aggregator.ts` - fixed DEFAULT_THEMES_DIR path depth
- `scripts/job-fair-runner.sh` - fixed PROJECT_DIR calculation
- `scripts/job-fair-status.sh` - fixed PROJECT_DIR calculation
- `scripts/job-fair-batch.sh` - fixed PROJECT_DIR calculation
- `scripts/consolidate-job-fair.sh` - fixed PROJECT_DIR calculation
- `scripts/benchmark-runner.js` - fixed PROJECT_DIR to walk up 3 levels
- `scripts/aggregate-benchmark-stats.js` - fixed PROJECT_DIR to walk up 3 levels
- `scripts/convert-jobfair-to-benchmarks.sh` - added PROJECT_DIR, fixed theme_file path
- `scripts/theme/update-theme-tiers.sh` - fixed zsh :h depth from 2 to 4
- `scripts/test/swebench-judge.py` - fixed parents[] depth from 3 to 4
- `scripts/test/ground-truth-judge.py` - fixed parents[] depth from 3 to 4
- `scripts/test/test-setup.sh` - fixed PROJECT_ROOT fallback depth

**Tests:** 41/41 passing (GREEN)
**PR:** #775 - feat(93-2): move benchmark commands, skills, and scripts to @pennyfarthing/benchmark
**Branch:** feature/PROJ-14631-benchmark-move-commands (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | `solo-runner.sh` not moved — 3 scripts reference `$SCRIPT_DIR/solo-runner.sh` which now resolves to `packages/benchmark/scripts/solo-runner.sh` (doesn't exist) | `scripts/solo-runner.sh` still in old location; referenced by `job-fair-runner.sh:10`, `job-fair-batch.sh:77`, `parallel-benchmark.sh:9`, `benchmark-runner.js` | Move `scripts/solo-runner.sh` to `packages/benchmark/scripts/solo-runner.sh` and update any internal path refs |
| [VERIFIED] | All 13 path depth calculations correct | All moved scripts | 3 `../..` levels for scripts/, 4 for test/ and theme/ |
| [VERIFIED] | Package builds and 41/41 tests pass | `packages/benchmark/` | GREEN |
| [VERIFIED] | Commands (4), skills (3), scenarios (57) properly relocated | `packages/benchmark/commands/`, `skills/`, `scenarios/` | No longer in old locations |
| [VERIFIED] | `package.json` files array includes non-TS assets | `packages/benchmark/package.json:14-20` | dist/, commands/, skills/, scripts/, scenarios/ |
| [LOW] | `compute_theme_tiers.py` has pre-existing bug: `JOB_FAIR_DIR = PROJECT_ROOT.parent / 'internal'` resolves incorrectly when `.pennyfarthing` is found in orchestrator root | `scripts/theme/compute_theme_tiers.py:54` | Not caused by this PR — pre-existing |

**Data flow traced:** Script path calculations → PROJECT_DIR → pennyfarthing-dist/personas/themes/ — all correct except solo-runner.sh dependency chain
**Pattern observed:** Consistent `$(cd "$SCRIPT_DIR/../../.." && pwd)` for 3-level depth at `scripts/*.sh`
**Error handling:** Scripts fail fast with `set -e` — solo-runner.sh absence will surface immediately

**Handoff:** Back to Dev for fix (move solo-runner.sh)

## Dev Assessment (Revision)

**Fix Applied:** Moved `solo-runner.sh` to `packages/benchmark/scripts/` per reviewer feedback
**Files Changed:**
- `scripts/solo-runner.sh` → `packages/benchmark/scripts/solo-runner.sh` (git mv + path fixes)
- `packages/benchmark/scripts/solo-runner.sh` - PROJECT_DIR: `dirname` → `../../..` (3 levels); SCENARIO_FILE: `$PROJECT_DIR/scenarios` → `$SCRIPT_DIR/../scenarios`
- `tests/integration/test_solo_runner_crossrole.sh` - updated RUNNER path to `packages/benchmark/scripts/`

**Callers verified:** `job-fair-runner.sh:10`, `job-fair-batch.sh:77`, `parallel-benchmark.sh:9`, `benchmark-runner.js:292,343` — all use `$SCRIPT_DIR/solo-runner.sh` (now resolves correctly)
**Tests:** 41/41 passing (GREEN)
**PR:** #775 — updated with fix commit
**Branch:** feature/PROJ-14631-benchmark-move-commands (pushed)

**Handoff:** To Reviewer for re-review

## Reviewer Assessment (Re-review)

**Verdict:** APPROVED

| Severity | Issue | Location | Status |
|----------|-------|----------|--------|
| [VERIFIED] | `solo-runner.sh` moved to benchmark package | `packages/benchmark/scripts/solo-runner.sh` | Fixed — old location confirmed empty |
| [VERIFIED] | PROJECT_DIR depth: 3 levels (`../../..`) | `solo-runner.sh:55` | Matches pattern at `job-fair-runner.sh:9` |
| [VERIFIED] | SCENARIO_FILE uses `$SCRIPT_DIR/../scenarios` (sibling) | `solo-runner.sh:57` | Correct — scenarios at `packages/benchmark/scenarios/` |
| [VERIFIED] | All 4 callers resolve via `$SCRIPT_DIR/solo-runner.sh` | `job-fair-runner.sh:10`, `job-fair-batch.sh:77`, `parallel-benchmark.sh:9`, `benchmark-runner.js:292,343` | Same-directory reference |
| [VERIFIED] | Integration test path updated | `test_solo_runner_crossrole.sh:9` | `$PROJECT_DIR/packages/benchmark/scripts/solo-runner.sh` |
| [VERIFIED] | 41/41 tests pass, build clean | `packages/benchmark/` | GREEN |
| [LOW] | `compute_theme_tiers.py` pre-existing bug remains | `scripts/theme/compute_theme_tiers.py:54` | Not in scope — pre-existing |

**Data flow traced:** `solo-runner.sh` SCRIPT_DIR → PROJECT_DIR (3 levels) → `pennyfarthing-dist/personas/themes/` (persona lookup); SCRIPT_DIR → `../scenarios/` (scenario lookup) — both resolve correctly
**Pattern observed:** Consistent `$(cd "$SCRIPT_DIR/../../.." && pwd)` across all `packages/benchmark/scripts/*.sh`

**Handoff:** To SM for finish-story
