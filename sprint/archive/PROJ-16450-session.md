---
story_id: "148-10"
jira_key: "PROJ-16421"
epic: "PROJ-16421"
workflow: "tdd"
---
# Story 148-10: Unify peloton pane management with tmux registry

## Story Details
- **ID:** 148-10
- **Jira Key:** PROJ-16421
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** spec-check
**Phase Started:** 2026-03-14T09:44:28Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-14T09:38:35Z | 2026-03-14T09:39:36Z | 1m 1s |
| red | 2026-03-14T09:39:36Z | 2026-03-14T09:42:01Z | 2m 25s |
| green | 2026-03-14T09:42:01Z | 2026-03-14T09:44:28Z | 2m 27s |
| spec-check | 2026-03-14T09:44:28Z | - | - |

## SM Assessment

**Story:** 148-10 — Unify peloton pane management with tmux registry
**Points:** 2 | **Priority:** p1 | **Workflow:** tdd

### Setup Summary

- Session file created with story context
- Branch `feat/148-10-unify-peloton-tmux-registry` created from `develop` in pennyfarthing repo
- Story moved to in_progress status

### Scope

Peloton's `live.py` maintains its own `peloton-state.json` instead of registering panes in the tmux registry. `pane_orchestrator.py` calls `_run_tmux` directly instead of using `panes.capture_pane()`. Unify both to use the canonical `pf.tmux` API so `pf tmux read/send/list` works natively with peloton panes.

### Key Files

- `pennyfarthing/pennyfarthing-dist/src/pf/peloton/live.py` — peloton live mode (own state file)
- `pennyfarthing/pennyfarthing-dist/src/pf/peloton/pane_orchestrator.py` — replay mode (calls _run_tmux directly)
- `pennyfarthing/pennyfarthing-dist/src/pf/tmux/panes.py` — canonical pane API
- `pennyfarthing/pennyfarthing-dist/src/pf/tmux/registry.py` — tmux pane registry
- `pennyfarthing/pennyfarthing-dist/src/pf/tmux/cli.py` — CLI commands (has new `read` command)

### Routing Decision

2-point TDD story → routes to **TEA (Thufir Hawat)** for the red phase.

---

## TEA Assessment

**RED phase complete.** 8 tests written, 5 failing, 3 passing (baselines).

### Test File
`pennyfarthing/pennyfarthing-dist/src/pf/tests/test_148_10_unify_peloton_tmux.py`

### Acceptance Criteria Coverage

**AC-1: live.py spawn_panes registers panes in tmux registry** (3 failing tests)
- `test_spawn_panes_writes_to_tmux_registry` — after spawn, tmux-panes.json must contain peloton entries
- `test_spawn_panes_registry_entries_have_owner` — peloton entries must have `owner='peloton'`
- `test_spawn_panes_registry_pane_ids_match_state` — pane IDs must match between peloton state and tmux registry
- `test_spawn_panes_registry_entries_not_protected` — PASSES (baseline, peloton panes should not be protected)

**AC-2: pane_orchestrator.py uses panes.capture_pane** (2 failing tests)
- `test_capture_output_calls_capture_pane` — mock verifies capture_pane is called, not _run_tmux
- `test_capture_output_does_not_import_run_tmux` — source inspection confirms no _run_tmux in method body

**AC-3: pf tmux read/list resolves peloton panes by title** (2 passing tests)
- `test_resolve_by_peloton_title` — PASSES (resolve_pane_ref already handles title matching)
- `test_resolve_by_peloton_title_case_insensitive` — PASSES (case-insensitive matching works)

### Implementation Guidance for Dev

1. **`live.py` spawn_panes**: After creating panes, write entries to the tmux registry (`registry_path()` / `save_registry()`). Each entry needs `pane_id`, `role: "worker"`, `title: "peloton-{role}"`, `protected: False`, `owner: "peloton"`.

2. **`pane_orchestrator.py` capture_output**: Replace the `from pf.tmux.panes import _run_tmux` + direct `_run_tmux("capture-pane", ...)` call with `from pf.tmux.panes import capture_pane` + `capture_pane(pane_id)`.

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/peloton/live.py` — added `_register_panes_in_tmux_registry()` helper, called from `spawn_panes()`
- `pennyfarthing-dist/src/pf/peloton/pane_orchestrator.py` — replaced `_run_tmux` call with `capture_pane()` in `capture_output()`
- `pennyfarthing-dist/src/pf/tmux/panes.py` — added `capture_pane()` public API
- `pennyfarthing-dist/src/pf/tmux/cli.py` — added `pf tmux read` command
- `pennyfarthing-dist/commands/pf-peloton.md` — command file for `/pf-peloton` autocomplete
- `pennyfarthing-dist/src/pf/tests/test_148_10_unify_peloton_tmux.py` — 8 tests (all passing)

**Tests:** 8/8 passing (GREEN). 46 existing peloton tests also pass.
**Branch:** `feat/148-10-unify-peloton-tmux-registry` (pushed)

**Handoff:** To Reviewer (Leto II) for code review.

---

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

No upstream findings.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Improvement** (non-blocking): `live.py` still maintains its own `peloton-state.json` in addition to the tmux registry. The peloton state file tracks workflow-specific fields (`active_role`, `agent_started`, `workflow`) that don't belong in the tmux registry. A future story could consider whether some of this state could be consolidated, but both files serve different purposes today.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

No design deviations.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No deviations from spec.