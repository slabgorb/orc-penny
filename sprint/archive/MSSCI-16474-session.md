---
story_id: "148-18"
jira_key: "MSSCI-16474"
epic: "MSSCI-16421"
workflow: "tdd"
---
# Story 148-18: Peloton tmux session leak — agent panes not cleaned up on shutdown

## Story Details
- **ID:** 148-18
- **Jira Key:** MSSCI-16474
- **Epic:** MSSCI-16421 (TUI-tmux Fixer)
- **Workflow:** tdd
- **Points:** 2
- **Priority:** p0
- **Type:** bug
- **Stack Parent:** none

## Story Description

Two issues:
1. Peloton agent panes (tea, dev, reviewer, architect) accumulate across runs — visible as windows 4-15 in tmux after 3 peloton runs. TeamDelete and shutdown don't kill the tmux panes.
2. Tests that exercise tmux pane creation should NOT open real tmux panes — they must mock tmux interactions to avoid leaking sessions. User preference: no tests that open real tmux panels.

## Workflow Tracking
**Workflow:** tdd
**Phase:** review
**Phase Started:** 2026-03-15T13:24:08Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-15T13:08:53Z | 2026-03-15T13:11:17Z | 2m 24s |
| red | 2026-03-15T13:11:17Z | 2026-03-15T13:17:30Z | 6m 13s |
| green | 2026-03-15T13:17:30Z | 2026-03-15T13:24:08Z | 6m 38s |
| review | 2026-03-15T13:24:08Z | - | - |

## SM Assessment

Setup complete. Story 148-18 is a p0 bug fix for peloton tmux pane leaks. Session created, Jira claimed (MSSCI-16474), branch `feat/148-18-peloton-tmux-session-leak` checked out in pennyfarthing repo. Peloton team assembled — routing to TEA for RED phase.

**Acceptance Criteria:**
- [ ] AC1: `pf peloton stop` kills all peloton-owned agent panes
- [ ] AC2: `TeamDelete` triggers pane cleanup before team teardown
- [ ] AC3: No orphaned panes remain after shutdown (verified by `tmux list-panes`)
- [ ] AC4: All peloton/tmux tests use mocks — no real tmux panes opened during test runs
- [ ] AC5: Existing peloton tests continue to pass

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

- **[TEA] Gap (non-blocking):** `PaneOrchestrator.teardown()` already works correctly (kills non-protected panes, preserves protected, handles errors) but had ZERO test coverage. Added 7 tests — all pass. The method itself is sound; the bug is that `stop()` never calls it or any equivalent cleanup.

- **[TEA] Gap (non-blocking):** `stop()` in `live.py` has no concept of the registry at all — it doesn't import `kill_pane`, `load_registry`, or `save_registry`. The fix must add registry-aware cleanup to `stop()`, not just wire up `PaneOrchestrator.teardown()`.

## TEA Assessment

**Tests:** 5 failing, 13 passing (RED state confirmed)
**Coverage:** All ACs covered
**File:** `pennyfarthing-dist/src/pf/tests/test_peloton_pane_cleanup.py` (new)

### Failing tests (define the fix):
| Test | What it asserts |
|------|----------------|
| `test_stop_calls_kill_pane_for_each_peloton_pane` | stop() must call kill_pane for %10, %11, %12 |
| `test_stop_removes_peloton_panes_from_registry` | Registry on disk must not contain peloton panes after stop |
| `test_stop_reports_killed_pane_count` | Result must include `{killed: [...]}` |
| `test_stop_graceful_when_kill_pane_fails` | Must attempt all 3 kills even if some fail |
| `test_second_start_after_stop_has_clean_registry` | No accumulation across runs |

### Passing tests (existing behavior + new teardown coverage):
- 7 PaneOrchestrator.teardown() tests (previously untested)
- 4 stop() tests for existing behavior (state clearing, protected pane safety)
- 2 no-real-tmux verification tests

### Implementation guidance for Dev:
The core fix is in `pf/peloton/live.py:stop()`. It needs to:
1. Read the registry file directly (JSON, no tmux calls needed)
2. Filter for panes with `owner="peloton"`
3. Call `kill_pane()` for each (from `pf.tmux.panes`)
4. Remove peloton panes from registry and save back to disk
5. Report killed panes in the result dict

Do NOT refactor teardown() or pane_orchestrator — they work fine. The fix is entirely in `stop()`.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->