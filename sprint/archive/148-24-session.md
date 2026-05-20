---
story_id: "148-24"
jira_key: "PROJ-16421"
epic: "PROJ-16421"
workflow: "tdd"
---
# Story 148-24: Peloton layout selection — horizontal, vertical, or 2x2 grid for team panes

## Story Details
- **ID:** 148-24
- **Jira Key:** PROJ-16421 (Epic)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-16T12:46:23Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-16T00:00:00Z | 2026-03-16T11:20:30Z | 11h 20m |
| red | 2026-03-16T11:20:30Z | 2026-03-16T11:25:24Z | 4m 54s |
| green | 2026-03-16T11:25:24Z | 2026-03-16T11:29:02Z | 3m 38s |
| spec-check | 2026-03-16T11:29:02Z | 2026-03-16T11:31:37Z | 2m 35s |
| verify | 2026-03-16T11:31:37Z | 2026-03-16T11:35:00Z | 3m 23s |
| review | 2026-03-16T11:35:00Z | 2026-03-16T12:41:31Z | 1h 6m |
| spec-reconcile | 2026-03-16T12:41:31Z | 2026-03-16T12:46:23Z | 4m 52s |
| finish | 2026-03-16T12:46:23Z | - | - |

## Story Summary
Allow users to select the layout of team panes in peloton mode. Three options: horizontal (side-by-side), vertical (stacked), or 2x2 grid. The layout should be selectable via CLI flag or config setting.

## Acceptance Criteria
- AC1: `pf peloton` accepts `--layout horizontal|vertical|grid` flag (default: grid for 4+ agents, vertical for 2-3)
- AC2: Horizontal layout splits the window into equal-width vertical panes side by side
- AC3: Vertical layout splits the window into equal-height horizontal panes stacked top to bottom
- AC4: Grid layout arranges panes in a 2x2 (or 2xN) grid pattern
- AC5: Layout preference can be persisted in config.local.yaml under `peloton.layout`
- AC6: CLI flag overrides config setting
- AC7: Existing peloton tests continue to pass with default layout
- AC8: TUI pane is consistently placed below the SM team lead CLI pane, regardless of layout choice

## Sm Assessment

Story 148-24 setup complete. Session created, branch `feat/148-24-peloton-layout-selection` ready on pennyfarthing repo. TDD workflow — routing to TEA for RED phase.

**Repos:** pennyfarthing
**Branch:** feat/148-24-peloton-layout-selection

## Tea Assessment

**Phase:** finish
**Tests:** 22 failing, 0 passing (0.17s)
**Test file:** `pennyfarthing-dist/src/pf/tests/test_148_24_peloton_layout_selection.py`

### Test Coverage

| AC | Tests | Category |
|----|-------|----------|
| AC1 | 5 | `--layout` flag: horizontal/vertical/grid, invalid rejection, state persistence |
| AC1 | 3 | Smart defaults: vertical for 2-3 agents, grid for 4+ |
| AC2 | 1 | Horizontal prompt mentions side-by-side |
| AC3 | 1 | Vertical prompt mentions stacked |
| AC4 | 1 | Grid prompt mentions grid/2x2 |
| AC5 | 3 | Config read, `get_configured_layout()`, unset returns None |
| AC6 | 2 | CLI flag overrides config |
| AC7 | 1 | Backward compat: existing call signature works |
| AC8 | 3 | TUI below CLI: in prompt, independent of layout, layout only affects agents |

### Implementation Guidance

Changes needed in `pennyfarthing-dist/src/pf/peloton/live.py`:
1. Add `layout: str | None = None` param to `start_session()`
2. Add `get_configured_layout(project_root)` to read `peloton.layout` from `config.local.yaml`
3. Validate layout against `{"horizontal", "vertical", "grid"}`
4. Default: `"grid"` if 4+ agents, `"vertical"` for 2-3
5. Include layout description in TeamCreate prompt
6. Store layout in state dict
7. Prompt must always specify TUI below SM CLI pane

CLI (`cli.py`): Add `--layout` option to `pf peloton start`.

**Handoff:** To Dev for GREEN phase.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/peloton/live.py` — layout param on start_session, get_configured_layout(), _resolve_layout(), VALID_LAYOUTS, layout descriptions in prompt, TUI-below-CLI instruction
- `pennyfarthing-dist/src/pf/peloton/cli.py` — --layout CLI option (horizontal|vertical|grid)
- `pennyfarthing-dist/src/pf/tests/test_148_24_peloton_layout_selection.py` — 22 new tests
- `pennyfarthing-dist/src/pf/tests/test_peloton_pane_layout.py` — updated: layout now in result
- `pennyfarthing-dist/src/pf/tests/test_148_19_peloton_pane_reuse.py` — updated: layout now in result

**Tests:** 139/139 passing (GREEN) — 22 new + 117 existing peloton tests
**Branch:** feat/148-24-peloton-layout-selection (committed)

**Handoff:** To Reviewer for code review

### Dev (implementation)
- No deviations from spec.

## Tea Assessment (verify)

**Phase:** finish
**Tests:** 22/22 passing (GREEN confirmed)
**Verification:** All ACs covered, no regressions in existing peloton suite

**Handoff:** To Reviewer for code review

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None

All 8 ACs verified against implementation:
- AC1-4: Layout selection and descriptions implemented via `_resolve_layout()` + `_LAYOUT_DESCRIPTIONS`
- AC5-6: Config read from `config.local.yaml`, explicit flag takes precedence
- AC7: 139/139 tests passing (22 new + 117 existing)
- AC8: TUI-below-CLI instruction present in all prompt variants

**Decision:** Proceed to verify phase.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 57/57 tests pass |
| 2 | reviewer-edge-hunter | Yes | clean | none | N/A — 62 lines, no boundary conditions beyond existing validation |
| 3 | reviewer-silent-failure-hunter | Yes | clean | none | N/A — `get_configured_layout` returns None on all errors, consistent with pattern |
| 4 | reviewer-test-analyzer | Yes | clean | none | N/A — 22 tests cover all ACs, no vacuous assertions |
| 5 | reviewer-comment-analyzer | Yes | clean | none | N/A — docstrings accurate and minimal |
| 6 | reviewer-type-design | Yes | clean | none | N/A — layout is a str validated against set, appropriate for enum-like config |
| 7 | reviewer-security | Yes | clean | none | N/A — no user input reaches dangerous operations, layout is validated |
| 8 | reviewer-simplifier | Yes | clean | none | N/A — minimal implementation, no over-engineering |

**All received:** Yes (8 returned, 0 with findings)
**Total findings:** 0 confirmed, 0 dismissed, 0 deferred

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `--layout` CLI flag → `click.Choice` validates → `start_session(layout=)` → `_resolve_layout()` (explicit > config > default) → `effective_layout` in prompt and state — evidence: `live.py:89-97` priority chain is explicit, `live.py:259-264` validation against `VALID_LAYOUTS` set
**Pattern observed:** Clean precedence chain at `live.py:83-97` — explicit > config > agent-count default. Follows existing config read pattern.
**Error handling:** Invalid layout returns `{success: False, error: ...}` at `live.py:260-264` — consistent with project principle #10 (return results, don't throw)
**Tests:** 57/57 passing (22 new + 35 related existing)

| Severity | Issue | Location | Note |
|----------|-------|----------|------|
| [VERIFIED] | Layout validation rejects invalid values — evidence: `live.py:260` checks `effective_layout not in VALID_LAYOUTS`, test `test_start_session_rejects_invalid_layout` confirms | `live.py:259-264` | |
| [VERIFIED] | Config read is safe — evidence: `live.py:72-73` checks file exists, `live.py:79` catches all exceptions returning None | `live.py:69-80` | |
| [VERIFIED] | CLI flag overrides config — evidence: `live.py:89-90` returns early on explicit, config checked only if explicit is None | `live.py:83-97` | |
| [VERIFIED] | TUI-below-CLI in all prompts — evidence: `live.py:300` hardcoded in prompt string, test `test_tui_placement_independent_of_layout` verifies all 3 layouts | `live.py:300` | |
| [VERIFIED] | Backward compat — `layout` param defaults to None, existing callers unaffected — evidence: `live.py:238` `layout: str | None = None` | `live.py:238` | |
| [VERIFIED] | `yaml` import inside function — evidence: `live.py:75` lazy import avoids import-time dependency, consistent with existing pattern at `live.py:290` and `pane_orchestrator.py:290` | `live.py:75` | [EDGE] |
| [VERIFIED] | No silent failures — `get_configured_layout` returns None on all errors, caller handles None correctly | `live.py:69-80` | [SILENT] |
| [VERIFIED] | Test coverage complete — 22 tests cover all 8 ACs with edge cases (case insensitivity, state persistence) | tests | [TEST] |
| [VERIFIED] | Docstrings accurate — Args section documents layout param, return type updated | `live.py:243-253` | [DOC] |
| [VERIFIED] | Type design appropriate — layout as validated str against VALID_LAYOUTS set, not over-engineered with enum | `live.py:34` | [TYPE] |
| [VERIFIED] | No security concerns — layout value is validated against fixed set before use, no injection path | `live.py:259-264` | [SEC] |
| [VERIFIED] | Minimal implementation — no unnecessary abstractions, `_resolve_layout` is clean 3-tier precedence | `live.py:83-97` | [SIMPLE] |

**Blocking issues:** None.
**Handoff:** To SM for finish-story.

VERDICT: APPROVE

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No upstream findings during implementation.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No deviations from spec.

### Architect (reconcile)
- No additional deviations found.