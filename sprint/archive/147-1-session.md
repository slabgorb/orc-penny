---
story_id: "147-1"
jira_key: ""
epic: "MSSCI-16394"
workflow: "trivial"
---
# Story 147-1: Add Jira config to DEFAULTS and TUI settings panel

## Story Details
- **ID:** 147-1
- **Jira Key:** (pending creation)
- **Epic:** MSSCI-16394 - Configuration Gap Closure
- **Workflow:** trivial
- **Stack Parent:** none
- **Branch:** feat/147-1-jira-config-defaults-tui (pennyfarthing/)

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-13T13:20:57Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-13T13:05:31Z | 2026-03-13T13:07:11Z | 1m 40s |
| implement | 2026-03-13T13:07:11Z | 2026-03-13T13:15:43Z | 8m 32s |
| review | 2026-03-13T13:15:43Z | 2026-03-13T13:20:57Z | 5m 14s |
| finish | 2026-03-13T13:20:57Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): Jira client `_resolve_jira_config()` at `jira/client.py:19` has duplicated default values ("MSSCI", "https://1898andco.atlassian.net") that now also exist in DEFAULTS. Future story should consolidate to read from DEFAULTS, eliminating the dual source of truth. Affects `pennyfarthing-dist/src/pf/jira/client.py` (should import from DEFAULTS instead of hardcoding). *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- No undocumented deviations found. Dev correctly logged "no deviations" — the implementation follows the established settings pattern exactly.

## SM Assessment

**Story:** 147-1 — Add Jira config to DEFAULTS and TUI settings panel
**Workflow:** trivial (setup → implement → review → finish)
**Routing:** Dev (Reverend Mother) for implementation

### Context
This 1-point p0 story closes a configuration gap: Jira settings (project key, sprint board, etc.) are not currently in the DEFAULTS system or exposed in the TUI settings panel. Dev should add the missing Jira fields to the defaults registry and wire them into the settings TUI.

### Acceptance Criteria
- Jira configuration fields added to DEFAULTS
- Fields visible and editable in TUI settings panel
- Existing Jira config continues to work

### Recommendation
Straight to Dev — trivial workflow, no TEA phase needed.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/settings/settings.py` - Added `jira.project` and `jira.url` to DEFAULTS dict
- `pennyfarthing-dist/src/pf/bikerack/settings_meta.py` - Added SettingSpec entries for Jira fields in "Jira" group

**Tests:** 162/162 passing (GREEN) — all settings and jira tests pass
**Branch:** feat/147-1-jira-config-defaults-tui (pennyfarthing/)

**Notes:**
- Jira client (`jira/client.py`) already reads from `config.local.yaml` via `_resolve_jira_config()` — no client changes needed
- SHOW_KEYS in settings.py already included `"jira"` — settings show command works
- TUI auto-discovers new specs via `build_setting_specs()` which reads DEFAULTS
- Default values match existing hardcoded fallbacks in the Jira client

**Handoff:** To Leto II (The God Emperor) for review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 3 | dismissed 3 — URL trailing slash and empty string are pre-existing behaviors; special chars in project key is theoretical with no new attack surface |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 3 | dismissed 3 — broad `except Exception` in `_resolve_jira_config()` and `_get_current_value()` are pre-existing, not introduced by this diff |
| 4 | reviewer-test-analyzer | Yes | findings | 2 | dismissed 2 — no new logic was added (declarative data only); 162 existing settings tests cover the infrastructure |
| 5 | reviewer-comment-analyzer | Yes | findings | 2 | dismissed 2 — description fields are adequate for TUI tooltips; verbose docs would be out of pattern with other SettingSpecs |
| 6 | reviewer-type-design | Yes | findings | 4 | dismissed 4 — stringly-typed URL/project and missing validation are all pre-existing in JiraClient; diff adds no new code paths |
| 7 | reviewer-security | Yes | findings | 3 | dismissed 3 — regex injection in extract_jira_key() and JQL injection are pre-existing in client.py; config was already user-editable via config.local.yaml before this change |
| 8 | reviewer-simplifier | Yes | findings | 2 | dismissed 2 — explicit SettingSpecs provide better labels ("Jira Project Key" vs auto-derived "Project") and descriptions; consistent with workflow settings pattern |

All received: Yes
Total findings: 0 confirmed, 19 dismissed (all pre-existing or non-applicable), 0 deferred

## Reviewer Assessment

**Verdict:** APPROVED

**Review Checklist:**
- [x] Subagent completion gate passed: All 8 rows filled, all received
- [x] 5+ observations: See below
- [x] Data flow traced: TUI `set_setting("jira.project", val)` → `config.local.yaml` → `_resolve_jira_config()` reads config → `JIRA_PROJECT` module constant — safe, correct
- [x] Wiring: DEFAULTS feeds `build_setting_specs()` → TUI renders Input widgets → `set_setting()` persists → Jira client reads config — fully connected
- [x] Pattern: Follows existing settings pattern exactly (DEFAULTS entry + SettingSpec + SHOW_KEYS) at `settings.py:43` and `settings_meta.py:170`
- [x] Error handling: Empty string in TUI → `_coerce_value("")` returns `""` → client's `or` chain falls to hardcoded default — safe
- [x] Security: No new attack surface — config was already user-editable; all injection concerns are pre-existing in `jira/client.py`
- [x] Hard questions: Null input handled by `_coerce_value`; `_set_by_path` creates intermediate dicts; module-level `JIRA_PROJECT` is set once at import (won't hot-reload, but that's pre-existing)
- [x] Subagent findings incorporated: All 19 findings reviewed, all dismissed as pre-existing
- [x] Judgment: APPROVE — no Critical/High issues, all steps complete

**Observations:**
1. [VERIFIED] DEFAULTS values `"MSSCI"` and `"https://1898andco.atlassian.net"` match hardcoded fallbacks in `jira/client.py:28-29` — no divergence
2. [VERIFIED] `SHOW_KEYS` at `settings.py:22` already contained `"jira"` — `pf settings show` correctly displays the new section with `# (default)` annotations
3. [VERIFIED] `build_setting_specs()` discovers new keys and returns 17 total specs including 2 Jira specs in group "Jira"
4. [LOW] Dual source of truth: DEFAULTS dict and `_resolve_jira_config()` both define the same fallback values — logged as Delivery Finding for future consolidation
5. [VERIFIED] Pattern consistency: explicit SettingSpec entries follow the same structure as workflow settings (lines 98-169), not over-engineered
6. [EDGE] URL trailing slash normalization and empty string edge cases — dismissed: empty string falls through `or` chain to hardcoded default safely; trailing slash is pre-existing behavior in `JiraClient`
7. [SILENT] Broad `except Exception` in `_resolve_jira_config()` at `jira/client.py:26` — dismissed: pre-existing, not introduced by this diff
8. [TEST] No new tests for declarative DEFAULTS entries — dismissed: 162 existing settings tests cover the infrastructure; entries are data, not logic
9. [DOC] SettingSpec descriptions are concise — dismissed: consistent with other SettingSpec description patterns in the file
10. [TYPE] `jira.url` stored as raw string without URL validation — dismissed: pre-existing in `JiraClient.__init__` which accepts unvalidated `base_url: str | None`
11. [SEC] Regex injection risk in `extract_jira_key()` and JQL injection via project key — dismissed: pre-existing in `jira/client.py`; config was already user-editable before this change
12. [SIMPLE] Explicit SettingSpecs could be auto-discovered — dismissed: explicit specs provide better labels ("Jira Project Key" vs auto-derived "Project") and descriptions, consistent with workflow settings pattern

**Handoff:** To Stilgar (SM) for finish-story