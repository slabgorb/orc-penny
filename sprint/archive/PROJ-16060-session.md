# Story 136-22: tmux-dev WheelHub launch crashes script — pipefail propagates non-zero exit

**Jira:** PROJ-16060
**Workflow:** tdd
**Phase:** finish
**Repos:** orchestrator
**Branch:** 136-22-tmux-dev-wheelhub-launch-crash
**Assigned To:** Leeloo

## Story Context

### Problem
The tmux-dev script uses `set -euo pipefail` and calls `pf launch wheelhub` in a pipeline:
```bash
WH_PORT=$(cd "$DIR" && pf launch wheelhub 2>/dev/null | tail -1)
```

When wheelhub returns non-zero, pipefail propagates the exit code through the pipeline. The `set -e` option then kills the script silently with exit 2. No session is created, and no error is shown to the user.

### Root Cause
`pf launch wheelhub` can return non-zero in consumer projects (pf-2, co-1, etc.) when the WheelHub process encounters startup issues. The script treats WheelHub as optional (has a 'Warning: WheelHub failed to start' fallback) but the `pipefail` setting makes it fatal.

### Key Files
- `pennyfarthing/pennyfarthing-dist/templates/tmux-dev.template` (source of truth)
- `tmux-dev` in each consumer project (copied by pf init)

### Suggested Fix
Wrap the WheelHub launch so pipefail cannot propagate:
```bash
WH_PORT=$(cd "$DIR" && pf launch wheelhub 2>/dev/null | tail -1) || true
```
or capture exit code separately.

## Acceptance Criteria
- [ ] WheelHub launch failure does not kill tmux-dev script
- [ ] Script continues to create tmux session even without WheelHub
- [ ] Warning message is shown when WheelHub fails to start
- [ ] tmux-dev works from fresh terminal, inside tmux, and via `just tmux`

## TEA Assessment

**Tests Required:** Yes
**Reason:** Script behavior change — WheelHub failure must become non-fatal

**Test Files:**
- `pennyfarthing/tests/unit/test_tmux_dev_wheelhub_resilience.sh` - 11 tests covering all 4 ACs

**Tests Written:** 11 tests covering 4 ACs
**Status:** RED (6 failing, 5 passing — ready for Dev)

**Failure Breakdown:**
- AC1 (2 tests): Script exits 1 / exits early on WheelHub failure
- AC2 (3 tests): No tmux session created when WheelHub fails
- AC3 (1 test): Shows "Error:" instead of "Warning:"
- AC4 + Edge (5 tests): PASS — successful WheelHub path works, cleanup works

**Handoff:** To Korben Dallas for implementation

**Implementation Hint:** Lines 88-101 of `tmux-dev.template` — replace `exit 1` with a warning and continue. The `if [[ ! -f "$PORT_FILE" ]]` block should emit `Warning:` to stderr and fall through to tmux session creation.

## Delivery Findings

### TEA (test design)
- No upstream findings during test design.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/templates/tmux-dev.template` - Removed `exit 1` on WheelHub failure, changed "Error" to "Warning"

**Tests:** 11/11 passing (GREEN)
**Branch:** fix/136-22-tmux-dev-wheelhub-launch-crash (pushed)

**Handoff:** To Zorg for review

### Dev (implementation)
- **Improvement** (non-blocking): Consumer projects have a stale copy of `tmux-dev` from `pf init`. Consumers need to re-run `pf init` or manually update their `tmux-dev` to pick up this fix.
  Affects `tmux-dev` in consumer repos ({needs re-copy from template}).
  *Found by Dev during implementation.*

## TEA Verify Assessment

**Tests:** 11/11 passing (GREEN confirmed)
**Coverage:** All 4 ACs verified
**Implementation Review:** Minimal, correct — removed `exit 1`, changed "Error" to "Warning". No scope creep.

**Handoff:** To Zorg for code review

### TEA (test verification)
- No upstream findings during test verification.

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `just wheelhub` (bg) → port file check → warning to stderr → fall through to tmux session creation (safe)
**Pattern observed:** `|| true` suppression consistent with line 77 at `tmux-dev.template:99`
**Error handling:** WheelHub failure → warning + kill cleanup, script continues. Correct at `tmux-dev.template:97-100`
**Tests:** 11/11 GREEN. All 4 ACs covered. Both success and failure paths exercised.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [LOW] | Process cleanup test trivially passes (mock exits immediately) | `test_tmux_dev_wheelhub_resilience.sh:329` | No — documents intent |

**Handoff:** To Ruby Rhod for finish-story

### Reviewer (code review)
- No upstream findings during code review.