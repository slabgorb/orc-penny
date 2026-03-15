---
story_id: "148-7"
jira_key: "MSSCI-16428"
epic: "MSSCI-16421"
workflow: "tdd"
---

# Story 148-7: Settings page rework for new settings

**Phase:** red
**Workflow:** tdd
**Branch:** feat/148-7-settings-page-rework
**Repos:** pennyfarthing

## Context

The TUI settings panel auto-discovers settings from `DEFAULTS` in `settings.py` and renders them based on metadata in `settings_meta.py`. The panel groups settings by category and uses Switch (bool), Select (enum), and Input (text) widgets. New settings have been added to the system but the settings page needs reworking to properly organize and present them.

### Key Files
- `pennyfarthing-dist/src/pf/tui/settings_panel.py` — TUI widget rendering the settings form
- `pennyfarthing-dist/src/pf/tui/settings_meta.py` — Metadata registry (labels, groups, widget types, options)
- `pennyfarthing-dist/src/pf/settings/settings.py` — Get/set logic and DEFAULTS dict
- `.pennyfarthing/config.local.yaml` — User config file

## Acceptance Criteria

- [ ] AC1: All settings in DEFAULTS have explicit metadata entries in SETTINGS_META (no auto-inferred fallbacks)
- [ ] AC2: Settings are organized into logical groups with clear category labels
- [ ] AC3: Each setting has a human-readable label and description
- [ ] AC4: New settings added since the last rework are properly categorized and have correct widget types

## TEA Assessment

**Tests Required:** Yes
**Reason:** Settings metadata completeness is testable and critical for UI correctness

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_148_7_settings_meta.py` — 54 tests across 6 test classes

**Tests Written:** 54 tests covering 4 ACs
**Status:** RED (10 failing — ready for Dev)

**Failing Tests Summary:**
- AC1 (3 failures): `jira.project` and `jira.url` missing from SETTINGS_META — auto-inferred instead of explicit
- AC2 (0 failures): Group organization tests pass for existing explicit entries
- AC3 (4 failures): Auto-inferred jira settings have empty descriptions and auto-derived labels
- AC4 (3 failures): Cannot verify widget types for jira settings without SETTINGS_META entries

**What Dev Needs To Do:**
1. Add `SettingSpec` entries for `jira.project` and `jira.url` in SETTINGS_META with proper labels, descriptions, group="Jira", and widget_type="input"
2. All 54 tests should pass after adding the missing entries

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation:** Added 2 SettingSpec entries for `jira.project` and `jira.url`
**Tests:** 54/54 passing (GREEN)
**Handoff:** To Reviewer

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `DEFAULTS["jira"]["project"]` → `_flatten_defaults()` → `"jira.project"` → matched in `SETTINGS_META` → `SettingSpec(widget_type="input", group="Jira")` → rendered by `settings_panel.py` (safe — metadata-only, no user input)

**Pattern observed:** New entries follow identical `SettingSpec(key=, label=, widget_type=, group=, description=)` pattern as all 15 existing entries at `settings_meta.py:184-197`

**Error handling:** No new error paths introduced. Pre-existing `_theme_options()` catch-all is outside diff scope.

**Observations:**
| Severity | Observation | Location | Status |
|----------|-------------|----------|--------|
| — | All 17 visible DEFAULTS keys have explicit SETTINGS_META entries | `settings_meta.py` | Verified good |
| — | Widget types match data types (string → input) | `settings_meta.py:184-197` | Verified good |
| — | Group naming follows namespace convention (jira.* → "Jira") | `settings_meta.py:188,195` | Verified good |
| — | Clean TDD commit history (test RED → impl GREEN) | git log | Verified good |
| — | Tests are well-structured: parametrized, per-AC, plus coherence suite | `test_148_7_settings_meta.py` | Verified good |
| [LOW] | Tests use `_visible_default_keys()` at parametrize time (module import) — works correctly but couples test discovery to import-time DEFAULTS | `test_148_7_settings_meta.py:31-38` | Acceptable |

**AC Verification:**
- [x] AC1: All DEFAULTS keys now have explicit SETTINGS_META entries — confirmed by `test_all_defaults_have_explicit_meta` + parametrized `test_each_default_has_meta_entry`
- [x] AC2: Groups are {General, Workflow, TUI, Jira} — `test_expected_groups_exist` + namespace tests verify
- [x] AC3: Labels and descriptions are non-empty and human-readable — 4 tests cover
- [x] AC4: `jira.project` and `jira.url` use `input` widget type — explicitly tested

**Security:** No concerns — metadata-only change, no user input handling, no network calls.

**Test status:** 54 passed, 0 failed (0.17s)

**Handoff:** To SM for finish-story
