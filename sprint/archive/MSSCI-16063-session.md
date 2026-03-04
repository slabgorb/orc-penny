# Story 136-25: justfile.pf claude recipe uses stale WheelHub launch — sync pf init templates to consumer projects

**Jira:** MSSCI-16063
**Status:** In Progress
**Workflow:** tdd
**Phase:** finish
**Repos:** orchestrator, pennyfarthing
**Branch:** story/136-25-justfile-pf-claude-stale-wheelhub

## Story

### Problem
Consumer projects (pf-2, co-1, co-2, co-3) have a stale claude recipe in .pennyfarthing/justfile.pf. The old recipe calls `just pf launch wheelhub` in a pipeline with `set -euo pipefail`, which crashes with exit 2 when WheelHub returns non-zero. The template was updated to read .bikerack-port directly, but consumer copies weren't synced.

### Root Cause
`pf init` copies justfile.pf from the template, but consumers don't re-run `pf init` regularly. The template diverged from deployed copies.

### Acceptance Criteria
- [ ] `pf init` updates justfile.pf in consumer projects
- [ ] Claude recipe reads .bikerack-port directly (no subprocess pipeline)
- [ ] `just claude` works in pf-2, co-1, co-2, co-3
- [ ] Consider: pf init should warn when justfile.pf is stale

### Key Files
- `pennyfarthing/pennyfarthing-dist/templates/justfile.pf.template` (source of truth)
- `.pennyfarthing/justfile.pf` in each consumer project

### Fix
Run `pf init` in each consumer project, or manually sync the claude recipe. Long term: add staleness detection to `pf init` or `pf doctor`.

## Context
No context document found. See sprint/context/ for story context if available.

## SM Assessment
- 1-point TDD story
- Workflow: tdd (phased) — TEA (Leeloo) owns the next phase (red)
- Repos: orchestrator and pennyfarthing both involved
- Branches created from main (orchestrator) and develop (pennyfarthing per gitflow)

## TEA Assessment

**Tests Required:** Yes
**Reason:** AC4 requires new staleness detection feature

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_init_justfile.py` — 8 new tests in 2 classes

**Tests Written:** 8 tests covering ACs 1, 2, 4
- `TestStalenessDetection` (5 tests): `check_justfile_pf_staleness()` — detects stale/missing/matching justfile.pf
- `TestUpdateReportsStaleness` (3 tests): `update_framework_justfile()` returns `was_stale` flag

**Status:** RED (7 failing, 1 passes due to stub coincidence — ready for Dev)

**Implementation needed:**
1. `check_justfile_pf_staleness(target_dir, dist_root)` — compare deployed content vs template, return `{success, stale, deployed}`
2. Add `was_stale` key to `update_framework_justfile()` result `data` dict
3. AC3 (`just claude` works in consumers) requires manual `pf init` in each consumer project

**Stub location:** `pennyfarthing-dist/src/pf/init/justfile.py` line ~222

**Handoff:** To Korben Dallas (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/init/justfile.py` — implemented `check_justfile_pf_staleness()` and added `was_stale` to `update_framework_justfile()` result

**Tests:** 38/38 passing (GREEN)
**Branch:** story/136-25-justfile-pf-claude-stale-wheelhub (pushed)

**Handoff:** To Jean-Baptiste Emanuel Zorg (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `target_dir` Path → `read_text()` → string comparison → result dict (safe — pure read, no mutation)
**Pattern observed:** Return dict `{success, data?, error?}` consistently followed at `justfile.py:145-154` and `justfile.py:237-252`
**Error handling:** Missing template returns `{success: False, error: ...}` at `justfile.py:238-239`; missing deployed file returns `{stale: True, deployed: False}` at `justfile.py:242-243`

| Severity | Observation | Location |
|----------|-------------|----------|
| [VERIFIED] | Data flow safe — read-only comparison | `justfile.py:245-250` |
| [VERIFIED] | Error paths covered (missing template, missing file) | `justfile.py:237-243` |
| [VERIFIED] | `was_stale` correct in both dry_run and normal paths | `justfile.py:114,152` |
| [VERIFIED] | No forbidden patterns, no secrets, clean tree | preflight |
| [VERIFIED] | 38/38 tests pass, no regressions | preflight |
| [LOW] | Public `check_justfile_pf_staleness` placed between private helpers | `justfile.py:228` |

**Handoff:** To Ruby Rhod (SM) for finish-story

## Delivery Findings

### TEA (test design)
- **Improvement** (non-blocking): The mock_dist fixture in test_init_justfile.py uses a simplified template that doesn't match the real template content. Future tests that need realistic template content should create their own fixtures.
  Affects `pennyfarthing-dist/src/pf/tests/test_init_justfile.py` (mock_dist fixture).
  *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation.

### TEA (test verification)
- No upstream findings during test verification.

### Reviewer (code review)
- No upstream findings during code review.

## TEA Verify Assessment

**Tests:** 38/38 passing (GREEN confirmed)
**Verification:** Implementation matches test expectations across all paths
**Edge cases reviewed:** missing template, missing file, matching content, differing content, fresh init
**No regressions:** All 31 original tests unaffected

**Handoff:** To Jean-Baptiste Emanuel Zorg (Reviewer) for code review