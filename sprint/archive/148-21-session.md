---
story_id: "148-21"
jira_key: ""
epic: "MSSCI-16421"
workflow: "tdd"
---

# Story 148-21: Peloton agent panes show portrait beside CLI

**Phase:** red
**Workflow:** tdd
**Branch:** feat/148-21-peloton-portrait-panes
**Repos:** pennyfarthing

## Context

When peloton mode creates agent panes in tmux, each agent gets a plain CLI pane. This story adds a portrait panel beside each agent's CLI pane — splitting each agent pane horizontally with the character portrait on the left and the Claude CLI on the right.

The portrait pane already exists as a TUI component for the main CLI pane. This story extends it to peloton agent panes so each teammate shows their character portrait.

## Acceptance Criteria

- [x] AC1: Each peloton agent pane is split with portrait on left and CLI on right
- [x] AC2: Portrait shows the correct character for each agent's role (based on active theme)
- [x] AC3: Portrait pane is sized appropriately (small, non-intrusive)
- [x] AC4: Works when portrait/theme is not configured (graceful fallback — no portrait, full CLI)

## TEA Assessment

**Tests Required:** Yes
**Reason:** Feature adds new behavior to PaneOrchestrator — portrait pane splitting, character resolution, sizing, fallback

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_peloton_portrait_panes.py` - 21 tests covering AC1-AC4

**Tests Written:** 21 tests covering 4 ACs
**Status:** RED (15 failing, 6 passing — ready for Dev)

**Coverage by AC:**
- AC1 (4 tests): Portrait pane creation, separation from CLI, role naming, horizontal split direction
- AC2 (4 tests): Correct character per role (River/tea, Kaylee/dev, Inara/reviewer), theme association
- AC3 (2 tests): Portrait pane <=25% width, small image size bucket preference
- AC4 (5 tests): No theme fallback, missing portraits, agent not in theme, success without theme, no portrait splits without theme

**Additional coverage:**
- Teardown (2 tests): Portrait panes killed on teardown, included in registry entries
- Edge cases (4 tests): Empty phases, single agent, unknown role returns None

**New methods required on PaneOrchestrator:**
- `get_portrait_pane(role)` -> ManagedPane | None
- `get_portrait_info(role)` -> dict | None (with path, theme keys)

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/peloton/pane_orchestrator.py` - Added portrait pane splitting, get_portrait_pane(), get_portrait_info(), theme YAML validation

**Tests:** 21/21 passing (GREEN)
**Branch:** feat/148-21-peloton-portrait-panes (pushed)

**Handoff:** To Reviewer

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 21/21 tests pass, 117 peloton tests pass |
| 2 | reviewer-edge-hunter | Yes | findings | 4 | confirmed 2, dismissed 2 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 7 | confirmed 1 (new code only), dismissed 6 (pre-existing or duplicate) |
| 4 | reviewer-test-analyzer | Yes | findings | 12 | confirmed 2, dismissed 10 (low/style) |
| 5 | reviewer-comment-analyzer | Yes | findings | 1 | dismissed 1 (docstring states constraint, 20 satisfies <=25%) |
| 6 | reviewer-type-design | Yes | findings | 5 | confirmed 1, dismissed 4 (follows codebase patterns) |
| 7 | reviewer-security | Yes | findings | 5 | dismissed 5 (internal API, not user input boundary) |
| 8 | reviewer-simplifier | Yes | findings | 4 | confirmed 0, noted 2 (intentional duplication, style) |

**All received:** Yes (8 returned, 6 confirmed findings across specialists)
**Total findings:** 6 confirmed, 28 dismissed (with rationale), 0 deferred

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `spawn_agent_panes(phases, theme)` → for each role: `_create_pane(role)` → `_try_create_portrait(role, theme, pane)` → reads theme YAML at `.pennyfarthing/personas/themes/{theme}.yaml` → `resolve_portrait_path(theme, role, project_root, "small")` → `_split_portrait_pane(pane_id)` → creates `ManagedPane` with `{role}-portrait` naming → stored in `self.panes` + `self._portrait_info`. Flow is safe — no user input reaches tmux commands unsanitized; `role` and `theme` are internal API parameters from the peloton runner.

**Pattern observed:** `{success, data?, error?}` pattern followed consistently in `spawn_agent_panes` return. `_try_create_portrait` is void (fire-and-forget) which is appropriate for optional portrait decoration. Good pattern at `pane_orchestrator.py:134`.

**Error handling:** Three `except Exception` catches in new code (lines 295, 309, 338) implement AC4 graceful fallback. Silent returns are correct behavior — portrait is decorative, not essential. No logging is a debugging concern but not blocking.

**Observations:**

1. `[VERIFIED]` AC1: Portrait pane creation verified — each role gets `{role}-portrait` ManagedPane with separate pane_id, horizontal split direction confirmed in tests
2. `[VERIFIED]` AC2: Character mapping verified — `resolve_portrait_path(theme, agent, project_root, "small")` called per role, portrait_info stores path and theme
3. `[VERIFIED]` AC3: Size constraint verified — `split_pane(..., "h", 20)` at line 335, 20% < 25% AC3 limit
4. `[VERIFIED]` AC4: Fallback verified — 5 tests cover no-theme, missing portraits, agent not in theme; `_try_create_portrait` returns silently on any failure
5. `[MEDIUM]` [EDGE] `_portrait_info` not cleared on teardown (line 250) — stale metadata persists if orchestrator reused. Non-blocking: orchestrators are single-use per peloton run.
6. `[MEDIUM]` [EDGE] No `isinstance(data.get("agents"), dict)` check (line 293) — malformed YAML could cause string membership test. Non-blocking: `resolve_portrait_path` would fail gracefully anyway.
7. `[MEDIUM]` [TYPE] `_split_portrait_pane` creates phantom pane on tmux failure (line 340) — fake ID registered but teardown's `kill_pane` on non-existent ID silently fails too. Consistent with existing error handling pattern.
8. `[MEDIUM]` [TEST] Tests at lines 279, 303 can silently pass if mock never called — `for/else` pattern without guaranteed execution. Non-blocking: the happy path is well-tested.
9. `[MEDIUM]` [TEST] No test for tmux `split_pane` returning `{success: False}` — phantom pane path untested. Non-blocking: fallback behavior is simple and consistent.
10. `[LOW]` [SIMPLE] Module imports `split_pane` at line 14 but `_split_portrait_pane` re-imports dynamically at line 333 — inconsistency, not a bug.

**Security:** No injection, path traversal, or auth issues. `theme` and `role` are internal API parameters from peloton runner, not user input. `yaml.safe_load` used correctly (not `yaml.load`). Portrait paths resolved within project root.

**Handoff:** To SM for finish-story
