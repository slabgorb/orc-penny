---
story_id: "148-27"
jira_key: "MSSCI-16592"
epic: "MSSCI-14876"
workflow: "trivial"
---
# Story 148-27: Add peloton layout setting to TUI settings page

## Story Details
- **ID:** 148-27
- **Jira Key:** (none yet)
- **Workflow:** trivial
- **Branch:** feat/148-27-peloton-layout-tui-setting
- **Repos:** pennyfarthing
- **Points:** 1
- **Priority:** p2

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-18T09:48:02Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-18T16:00:00Z | 2026-03-18T09:29:26Z | -23434s |
| implement | 2026-03-18T09:29:26Z | 2026-03-18T09:39:56Z | 10m 30s |
| review | 2026-03-18T09:39:56Z | 2026-03-18T09:48:02Z | 8m 6s |
| finish | 2026-03-18T09:48:02Z | - | - |

## Context

The Peloton feature (team-based TDD workflow) already supports layout preferences via the `peloton.layout` config setting in `.pennyfarthing/config.local.yaml`. Users can set layout to `horizontal`, `vertical`, or `grid` (2x2).

However, this setting is **not exposed in the TUI settings page**. The TUI settings panel (built via `settings_meta.py` and `settings_panel.py`) uses a metadata registry of `SettingSpec` objects to render configurable options.

**Acceptance Criteria:**
1. Add `peloton.layout` setting to the TUI settings metadata
2. TUI settings page shows "Peloton Layout" dropdown with options: Horizontal, Vertical, Grid
3. Setting is persisted to `.pennyfarthing/config.local.yaml` under `peloton.layout`
4. Changes take effect immediately (no restart required)
5. Tests verify the setting is exposed and functional

## Key Files

| File | Purpose | Status |
|------|---------|--------|
| `pennyfarthing-dist/src/pf/settings/settings.py` | Settings storage + defaults | Needs update: add peloton defaults |
| `pennyfarthing-dist/src/pf/tui/settings_meta.py` | Settings metadata registry | **Primary**: Add SettingSpec for peloton.layout |
| `pennyfarthing-dist/src/pf/tui/settings_panel.py` | TUI settings panel renderer | Should work automatically via meta |
| `pennyfarthing-dist/src/pf/peloton/live.py` | Peloton layout logic | Reference: VALID_LAYOUTS = {"horizontal", "vertical", "grid"} |

## Implementation Notes

1. **DEFAULTS update:** Add `peloton: { layout: "grid" }` (default matches live.py behavior)
2. **SettingSpec:** Add to `_SPECS` list with:
   - `key="peloton.layout"`
   - `label="Peloton Layout"`
   - `widget_type="select"`
   - `group="Peloton"` (new group)
   - `options=[("Horizontal", "horizontal"), ("Vertical", "vertical"), ("Grid", "grid")]`
   - `description="Pane layout for team workflows"`
3. **Compatibility:** Ensure setting is not hidden or excluded (check HIDDEN_KEYS)

## Related Stories

- 148-8: Peloton mode — spawn team panes and run TDD workflow (5 pts, in_progress)
- 148-24: Peloton layout selection via CLI (done) — established `--layout` flag and config storage
- 148-28: Peloton teammates pre-priming (done) — ensures agents are fully primed before work

## Sm Assessment

**Story:** 148-27 — Add peloton layout setting to TUI settings page
**Workflow:** trivial → implement phase next, owner: dev

**Scope confirmed:** Minimal — the layout logic (`VALID_LAYOUTS`, `--layout` CLI flag, config persistence) is already implemented in `peloton/live.py`. This story only exposes the existing setting in the TUI settings panel by:
1. Removing `"layout"` from `HIDDEN_KEYS` in `settings_meta.py`
2. Adding a `SettingSpec` with `widget_type="select"` for `peloton.layout`
3. Optionally adding `peloton: { layout: "grid" }` to DEFAULTS in `settings.py`

**Key finding from research:** The layout feature is description-driven (informs SM's prompt), not geometry-enforced. Dev should be aware — the TUI setting just writes to config.local.yaml; actual tmux enforcement is unchanged.

**Ready for Dev handoff.**

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/settings/settings.py` — added `peloton: { layout: "grid" }` to DEFAULTS
- `pennyfarthing-dist/src/pf/tui/settings_meta.py` — added `SettingSpec` for `peloton.layout` in new "Peloton" group

**Tests:** 116/116 passing (GREEN)
**Branch:** feat/148-27-peloton-layout-tui-setting (pushed)

**Note:** The `"layout"` entry in `HIDDEN_KEYS` guards a flat top-level key, not `peloton.layout` — no change to `HIDDEN_KEYS` was needed. The spec was derived from `VALID_LAYOUTS` in `peloton/live.py` (grid/vertical/horizontal), with grid first as it's the smart default for 4+ agents.

**Handoff:** To Queen of Hearts (Reviewer) for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 3 | confirmed 1, dismissed 2 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 5 | dismissed 5 (all pre-existing, not in diff) |
| 4 | reviewer-test-analyzer | Yes | findings | 3 | confirmed 2, dismissed 1 |
| 5 | reviewer-comment-analyzer | Yes | findings | 3 | confirmed 1, deferred 1, dismissed 1 |
| 6 | reviewer-type-design | Yes | findings | 3 | confirmed 1 (SHOW_KEYS), deferred 1, dismissed 1 |
| 7 | reviewer-security | Yes | clean | none | N/A |
| 8 | reviewer-simplifier | Yes | findings | 1 | deferred 1 |
| 9 | reviewer-rule-checker | Yes | clean | none | N/A |

**All received:** Yes (9/9)
**Total findings:** 4 confirmed (all MEDIUM or LOW), 0 dismissed rule-violations, 7 dismissed (pre-existing/out-of-scope)

## Design Deviations

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- **Dev note: `SHOW_KEYS` not updated** — Spec said nothing about `pf settings show`, but by convention all settings groups in DEFAULTS should appear in `SHOW_KEYS`. Dev's change adds `"peloton"` to DEFAULTS but not `SHOW_KEYS`. Not a spec deviation (ACs don't mention CLI display), but a consistency gap. → ✓ ACCEPTED by Reviewer: Dev logged no deviations because ACs don't mention `pf settings show`; gap noted as delivery finding.
- **Dev deviations entry** → ✓ ACCEPTED by Reviewer: "No deviations from spec" — agrees with author reasoning for all AC items.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** TUI select widget → `set_setting_typed("peloton.layout", value)` → writes to `.pennyfarthing/config.local.yaml` → `pf peloton start` calls `get_configured_layout()` → reads from yaml → `_resolve_layout()` returns value → validated against `VALID_LAYOUTS` → injected into TeamCreate prompt. Safe — TUI constrains to 3 valid options; runtime validates against `VALID_LAYOUTS` before use.

**Pattern observed:** Follows established settings registration pattern — default in `DEFAULTS`, UI spec in `_SPECS`, auto-wired to panel via `build_setting_specs()`. Consistent with `jira.project`, `portrait_size`, etc.

**Error handling:** `set_setting_typed()` at `settings.py:118` propagates write errors up; TUI `_save_and_notify()` catches and shows status. ✓

**Wiring verified:** `build_setting_specs()` iterates `DEFAULTS`, finds `peloton.layout`, looks up `SETTINGS_META["peloton.layout"]`, returns the `SettingSpec` with `widget_type="select"` and 3 options. Confirmed by runtime check during review.

**Rule Compliance:**
- Rule 2 (mutable defaults): `DEFAULTS` is a module constant, not a function default — compliant ✓
- Rule 3 (type annotations): No new public functions added — N/A ✓
- SOUL Principle 2 (One Truth): `VALID_LAYOUTS`, options list, and default string are three separate definitions of the same values. By the existing pattern in this codebase, this is how settings work — tolerated but flagged as MEDIUM.
- All 13 Python checklist rules: Clean (verified by rule-checker, no new logic in diff) ✓

**[EDGE] SHOW_KEYS gap confirmed:** `settings.py:14-26` — `"peloton"` not in `SHOW_KEYS`. `pf settings show` will not display peloton.layout after TUI change. Non-blocking (feature writes to config correctly; show is diagnostic only). Dismissed from edge-hunter's type-coercion finding (`get_configured_layout` called `.lower()` on raw YAML value) — pre-existing code, not in diff.

**[SILENT] All pre-existing:** `get_configured_layout():84` bare `except Exception: return None`, `load_state()` bare pass, `stop()` kill_pane swallow — all pre-existing, not introduced by this diff. Dismissed.

**[TEST] Two gaps confirmed:**
1. `test_148_7_settings_meta.py:83` — `EXPECTED_GROUPS` is `{"General", "Workflow", "TUI", "Jira"}` — missing `"Peloton"`. New group not explicitly guarded against future regression.
2. No test directly asserts `peloton.layout` appears in `build_setting_specs()` with `widget_type="select"`, 3 options, `group="Peloton"`. AC5 partially unmet.

**[DOC] SHOW_KEYS gap** (corroborates [EDGE]): `pf settings show` silently omits peloton — non-blocking.

**[TYPE] VALID_LAYOUTS duplication** (medium, deferred): Three independent definitions of valid layout values. Architectural concern for future maintenance; does not affect correctness today.

**[SIMPLE] Same as [TYPE]** — deferred to a future improvement story.

**[SEC] Clean** — no security issues. TUI constrains to 3 values; runtime validates; local-only tool.

**[RULE] Clean** — no rule violations in the diff itself.

### Devil's Advocate

What would break this? A few scenarios examined:

1. **Existing `peloton:` config key**: If a user already has `peloton: {other_key: value}` in `config.local.yaml`, `_set_by_path("peloton.layout", "grid")` correctly merges — only sets the subkey. Verified via `_set_by_path()` implementation at `settings.py:85-93`. ✓

2. **`pf settings set peloton.layout invalid`**: The value `"invalid"` passes through `_coerce_value()` as a string, gets written to yaml, then fails at `_resolve_layout()` validation (line 267: `if effective_layout not in VALID_LAYOUTS → return error`). The peloton session fails to start with a clear error message. Acceptable.

3. **`DEFAULTS` "grid" vs smart default**: `get_configured_layout()` reads directly from `config.local.yaml`, not from `DEFAULTS`. If config.local.yaml has no peloton.layout entry, smart default applies. The DEFAULTS entry only matters for display purposes. No conflict. ✓

4. **The "Peloton" group name**: If `build_setting_specs()` auto-derives the group for unregistered settings, it would produce `"Peloton"` (title-case of prefix). The explicit `group="Peloton"` in SettingSpec is consistent — no conflict. ✓

5. **HIDDEN_KEYS**: Contains `"layout"` which matches top-level flat key `layout`, not `peloton.layout` (top segment is `"peloton"`, not `"layout"`). Correctly does NOT hide the new setting. ✓

The devil's advocate did not uncover any additional blocking issues. The SHOW_KEYS gap and test coverage gaps remain the genuine weaknesses.

**Handoff:** To Mad Hatter (SM) for finish-story

## Delivery Findings

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Gap** (non-blocking): `"peloton"` not in `SHOW_KEYS` in `settings.py:14`. `pf settings show` command will silently omit peloton.layout even when user-configured. Affects `pennyfarthing-dist/src/pf/settings/settings.py` (add `"peloton"` to SHOW_KEYS tuple). *Found by Reviewer during code review.*
- **Gap** (non-blocking): `EXPECTED_GROUPS` in `test_148_7_settings_meta.py:83` does not include `"Peloton"`. The new group is not explicitly regression-guarded. Affects `pennyfarthing-dist/src/pf/tests/test_148_7_settings_meta.py` (add `"Peloton"` to EXPECTED_GROUPS). *Found by Reviewer during code review.*
- **Gap** (non-blocking): No test verifies `peloton.layout` appears in `build_setting_specs()` with correct `widget_type`, `options`, and `group`. AC5 partially unmet. Affects `pennyfarthing-dist/src/pf/tests/` (add dedicated test for peloton.layout registration). *Found by Reviewer during code review.*## Impact Summary

**Upstream Effects:** 3 findings (3 Gap, 0 Conflict, 0 Question, 0 Improvement)
**Blocking:** None

- **Gap:** `"peloton"` not in `SHOW_KEYS` in `settings.py:14`. `pf settings show` command will silently omit peloton.layout even when user-configured. Affects `pennyfarthing-dist/src/pf/settings/settings.py`.
- **Gap:** `EXPECTED_GROUPS` in `test_148_7_settings_meta.py:83` does not include `"Peloton"`. The new group is not explicitly regression-guarded. Affects `pennyfarthing-dist/src/pf/tests/test_148_7_settings_meta.py`.
- **Gap:** No test verifies `peloton.layout` appears in `build_setting_specs()` with correct `widget_type`, `options`, and `group`. AC5 partially unmet. Affects `pennyfarthing-dist/src/pf/tests/`.

