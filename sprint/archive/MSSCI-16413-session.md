---
story_id: "147-2"
jira_key: "MSSCI-16413"
epic: "MSSCI-16411"
workflow: "trivial"
---
# Story 147-2: Promote saddle_mode to explicit SettingSpec

## Story Details
- **ID:** 147-2
- **Jira Key:** MSSCI-16413
- **Epic:** MSSCI-16411 (Configuration Gap Closure)
- **Workflow:** trivial
- **Points:** 1
- **Priority:** p0
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-13T15:02:51Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-13T10:45:00Z | 2026-03-13T14:45:23Z | 4h |
| implement | 2026-03-13T14:45:23Z | 2026-03-13T14:50:37Z | 5m 14s |
| review | 2026-03-13T14:50:37Z | 2026-03-13T15:02:51Z | 12m 14s |
| finish | 2026-03-13T15:02:51Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): settings_meta.py `widget_type` field is `str` not `Literal["switch", "select", "input"]`. Affects `pennyfarthing-dist/src/pf/bikerack/settings_meta.py` (add type constraint). *Found by Reviewer subagent (type-design) during code review.*
- **Improvement** (non-blocking): `build_setting_specs()` and individual SettingSpec entries have zero test coverage. Affects `pennyfarthing-dist/src/pf/bikerack/settings_meta.py` (add test_settings_meta.py). *Found by Reviewer subagent (test-analyzer) during code review.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- No deviations found. Dev reported no deviations, and the implementation matches the story title exactly: a single SettingSpec added for `workflow.saddle_mode`.

## SM Assessment

**Story:** 147-2 — Promote saddle_mode to explicit SettingSpec
**Workflow:** trivial (1pt, p0)
**Repos:** pennyfarthing (branch: `feat/147-2-promote-saddle-mode-setting-spec`)

**Context:** saddle_mode needs to be promoted from ad-hoc config to a proper SettingSpec entry in the settings system, consistent with how other settings are defined.

**Routing:** Trivial workflow → Dev implements → Reviewer reviews → SM finishes.
**Handoff to:** Dev (White Rabbit)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/bikerack/settings_meta.py` - Added explicit SettingSpec for workflow.saddle_mode (switch widget, Workflow group)

**Tests:** 211/211 passing (GREEN)
**Branch:** feat/147-2-promote-saddle-mode-setting-spec (pushed)

**Handoff:** To Reviewer (Queen of Hearts) for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | Syntax OK. Saddle wiring tests 34/34 pass. Pre-existing failures in test_buffer_stream_events.py and test_bikerack.py — unrelated to this change. | N/A (pre-existing) |
| 2 | reviewer-edge-hunter | Yes | clean | none | N/A |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 1: settings_panel.py swallows KeyError silently when SettingSpec key missing from DEFAULTS | dismissed 1 — pre-existing architectural pattern, not introduced by this diff; saddle_mode key exists in DEFAULTS |
| 4 | reviewer-test-analyzer | Yes | findings | 3: no tests for settings_meta module (build_setting_specs, SettingSpec entries, get_options) | dismissed 3 — pre-existing gap affecting all SettingSpec entries equally, not introduced by this diff |
| 5 | reviewer-comment-analyzer | Yes | findings | 1: description "Use saddle commands for agent handoffs" could be more precise about the two handoff modes | dismissed 1 — medium confidence, description is adequate for a settings panel label; full explanation belongs in docs not a tooltip |
| 6 | reviewer-type-design | Yes | findings | 3: widget_type is stringly-typed (str not Literal), missing validation in settings_panel.py | dismissed 3 — pre-existing architectural issues affecting all SettingSpec entries, not introduced by this diff |
| 7 | reviewer-security | Yes | findings | 1: potential command injection in marker.py via next_agent interpolation into saddle command | dismissed 1 — pre-existing in marker.py (not changed in this diff); next_agent comes from workflow YAML phase definitions, not user input |
| 8 | reviewer-simplifier | Yes | clean | none | N/A |

**All received:** Yes
**Total findings:** 0 confirmed, 9 dismissed (all pre-existing architectural concerns not introduced by this 7-line diff), 0 deferred

## Reviewer Assessment

**Verdict:** APPROVED

**Review Checklist:**
- [x] **Subagent completion gate passed:** All 8 rows filled, all received.
- [x] **5+ observations:**
  1. [VERIFIED] Key `workflow.saddle_mode` matches DEFAULTS path at `settings.py:41`
  2. [VERIFIED] Widget type `switch` correct for boolean default (`False`)
  3. [VERIFIED] Group `"Workflow"` consistent with other `workflow.*` settings (relay_mode, pr_mode, statusbar, etc.)
  4. [VERIFIED] Placement in `_SPECS` list is logically ordered between `workflow.statusbar` and `workflow.startup_agent`
  5. [VERIFIED] Description "Use saddle commands for agent handoffs" accurately describes the feature per `handoff/marker.py:53-55`
  6. [VERIFIED] `build_setting_specs()` will pick up explicit spec via `SETTINGS_META` lookup — previously auto-inferred (same widget/group/label, but now gains explicit description)
  7. [VERIFIED] Saddle wiring tests (34 tests in `test_143_18_saddle_wiring.py`) all pass
- [x] **Data flow traced:** `DEFAULTS["workflow"]["saddle_mode"]` → `build_setting_specs()` → `SETTINGS_META["workflow.saddle_mode"]` → BikeRack TUI Settings panel renders as switch toggle
- [x] **Wiring:** Setting is accessible via `build_setting_specs()` which reads from `SETTINGS_META` dict populated at module load
- [x] **Pattern observed:** Follows exact same pattern as adjacent entries (workflow.statusbar, workflow.relay_mode) at `settings_meta.py:149-155`
- [x] **Error handling:** N/A — static data declaration, no runtime error paths
- [x] **Security:** N/A — no user input, no external data, no injection surface
- [x] **Hard questions:** N/A — no logic, no edge cases, no race conditions
- [x] **Subagent findings incorporated:** 9 findings from 5 specialists reviewed; all dismissed as pre-existing architectural concerns not introduced by this diff. [SILENT] settings_panel KeyError swallowing — pre-existing. [TEST] no settings_meta tests — pre-existing gap. [DOC] description could be more precise — adequate for settings panel. [TYPE] stringly-typed widget_type — pre-existing. [SEC] marker.py next_agent interpolation — pre-existing, not user-controlled input.
- [x] **Judgment:** APPROVED — no Critical/High issues, all checklist items complete

**Handoff:** To SM (The Mad Hatter) for finish-story