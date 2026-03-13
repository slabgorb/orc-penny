---
story_id: "148-1"
jira_key: "MSSCI-16422"
epic: "MSSCI-16421"
workflow: "tdd"
---
# Story 148-1: Extend tmux for pane discoverability

## Story Details
- **ID:** 148-1
- **Jira Key:** MSSCI-16422
- **Epic:** MSSCI-16421 — TUI-tmux Fixer
- **Workflow:** tdd
- **Points:** 3
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-13T16:25:54Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-13T15:34:48.849746Z | 2026-03-13T15:36:21Z | 1m 32s |
| red | 2026-03-13T15:36:21Z | 2026-03-13T15:41:50Z | 5m 29s |
| green | 2026-03-13T15:41:50Z | 2026-03-13T16:01:47Z | 19m 57s |
| spec-check | 2026-03-13T16:01:47Z | 2026-03-13T16:09:30Z | 7m 43s |
| verify | 2026-03-13T16:09:30Z | 2026-03-13T16:14:47Z | 5m 17s |
| review | 2026-03-13T16:14:47Z | 2026-03-13T16:23:16Z | 8m 29s |
| spec-reconcile | 2026-03-13T16:23:16Z | 2026-03-13T16:25:54Z | 2m 38s |
| finish | 2026-03-13T16:25:54Z | - | - |

## Story Context

The goal is to make the pf tmux CLI pane and the Claude Code pane instantly identifiable. This is about **pane discoverability** — users should be able to tell at a glance which tmux pane is the BikeRack TUI and which is the Claude Code CLI.

This is a foundational change to the TUI-tmux integration that will improve the user experience when working with multiple panes.

## SM Assessment

**Setup complete.** Story 148-1 claimed in Jira (MSSCI-16422), session file created, feature branch `feat/148-1-tmux-pane-discoverability` cut from `develop` in pennyfarthing repo.

**Context:** User wants pf tmux CLI pane and Claude Code pane to be instantly identifiable at a glance. This is a discoverability/UX improvement to the tmux pane management layer.

**Routing:** TDD workflow → TEA (Thufir Hawat) for RED phase to design failing tests for pane identification.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- No upstream findings during implementation.

### TEA (test verification)
- **Improvement** (non-blocking): Error handling pattern in `tmux/cli.py` is repeated 15+ times — extractable into a helper like `_result_or_exit(result)`. Pre-existing pattern, not introduced by this story.
  Affects `pennyfarthing-dist/src/pf/tmux/cli.py` (extract helper to reduce boilerplate).
  *Found by TEA during test verification.*

### Reviewer (code review)
- **Improvement** (non-blocking): `configure_pane_borders()` docstring says "role labels and icons" but format string `" #{pane_title} "` only shows title, not icons. Docstring is misleading.
  Affects `pennyfarthing-dist/src/pf/tmux/panes.py` (update docstring to match actual behavior).
  *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Nerd Font icon column uses `f"{icon:3}"` Python char-width formatting, which may misalign in terminals with variable-width glyph rendering. Cosmetic only.
  Affects `pennyfarthing-dist/src/pf/tmux/cli.py` (consider `wcwidth` or accept as known limitation).
  *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No deviations from spec.

### TEA (test verification)
- **Parameterized 4 individual role icon tests into single @pytest.mark.parametrize**
  - Spec source: test_tmux_pane_discoverability.py, AC1
  - Spec text: Tests validate each role returns a non-empty icon string
  - Implementation: Replaced 4 separate test methods with one parameterized test covering same roles
  - Rationale: Eliminates copy-paste pattern; coverage unchanged (15 tests still collected)
  - Severity: minor
  - Forward impact: none — same assertions, same coverage

### Dev (implementation)
- **Changed CLI import pattern for load_registry** → ✓ ACCEPTED by Reviewer: Standard Python mock-patching pattern. Module-level access is the canonical solution for name-binding interception issues.
  - Spec source: test_tmux_pane_discoverability.py, AC5
  - Spec text: Tests mock `pf.tmux.registry.load_registry` expecting module-level interception
  - Implementation: Changed `from pf.tmux.registry import load_registry` to `from pf.tmux import registry as _registry` and use `_registry.load_registry()` for mockability
  - Rationale: Direct name binding at import time prevents mock interception; module-level access allows tests to patch correctly
  - Severity: minor
  - Forward impact: none — all existing CLI behavior unchanged

### Reviewer (audit)
- No undocumented deviations found. TEA parameterization and Dev import changes are both accurately documented.

### Architect (reconcile)
- No additional deviations found.

**Verification notes:**
- TEA parameterization deviation: verified at `test_tmux_pane_discoverability.py:38`. Spec source, spec text, implementation, rationale, severity, and forward impact all accurate.
- Dev import pattern deviation: verified at `cli.py:17,70`. Spec source, spec text, implementation, rationale, severity, and forward impact all accurate. Reviewer explicitly accepted this change.
- No ACs deferred — all 5 ACs confirmed DONE in spec-check. AC deferral verification is a no-op.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Feature story adding new tmux pane identification capabilities

**Test File:**
- `pennyfarthing-dist/src/pf/tests/test_tmux_pane_discoverability.py` — 15 tests across 5 ACs

**Tests Written:** 15 tests covering 5 ACs
**Status:** RED (failing — ready for Dev)

**AC Coverage:**
| AC | Tests | Description |
|----|-------|-------------|
| AC1 | 6 | `get_pane_icon(role)` — distinct icons per role, fallback for unknown |
| AC2 | 3 | `configure_pane_borders(session)` — enables pane-border-status, sets format |
| AC3 | 1 | Border format references `#{pane_title}` for dynamic labels |
| AC4 | 3 | `set_pane_env(pane_id, role)` — injects `PF_PANE_ROLE` env var |
| AC5 | 2 | `pf tmux list` output includes role icons (text + JSON) |

**Stubs Added:** `get_pane_icon()`, `configure_pane_borders()`, `set_pane_env()` in `pf/tmux/panes.py` — all raise `NotImplementedError`

**Implementation Notes for Dev:**
- `get_pane_icon()`: Map roles to Nerd Font icons (project already uses these in BikeRack panels)
- `configure_pane_borders()`: Use `tmux set-option pane-border-status top` + `pane-border-format` with `#{pane_title}`
- `set_pane_env()`: Use `tmux set-environment -t <pane_id>` or `send-keys "export PF_PANE_ROLE=<role>"`
- `pf tmux list`: Add icon column using `get_pane_icon(entry["role"])`

**Handoff:** To Reverend Mother (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/tmux/panes.py` — Added `get_pane_icon()`, `configure_pane_borders()`, `set_pane_env()` with Nerd Font icons and tmux option management
- `pennyfarthing-dist/src/pf/tmux/cli.py` — Added icon column to `pf tmux list` (text + JSON), changed `load_registry` import to module-level for mockability

**Tests:** 15/15 passing (GREEN)
**Branch:** feat/148-1-tmux-pane-discoverability (pushed)

**Implementation Details:**
- `get_pane_icon()`: Maps roles to distinct Nerd Font icons — 󰚩 (claude), 󰓩 (tui), 󰙨 (worker), 󱄅 (saddle), ◆ (fallback)
- `configure_pane_borders()`: Sets `pane-border-status top` + `pane-border-format " #{pane_title} "` on the session
- `set_pane_env()`: Uses `tmux set-environment -t <pane_id> PF_PANE_ROLE <role>`
- CLI `list`: Icon column prepended to each row; JSON output includes `icon` field

**Handoff:** To Thufir Hawat (TEA) for verify phase

## Architect Assessment (spec-check)

**Spec Alignment:** Confirmed — all 5 ACs fully covered.

| AC | Status | Notes |
|----|--------|-------|
| AC1 | Pass | `get_pane_icon()` maps 4 roles to distinct Nerd Font icons + fallback `◆` |
| AC2 | Pass | `configure_pane_borders()` sets `pane-border-status top` + `pane-border-format` |
| AC3 | Pass | Border format uses `#{pane_title}` for dynamic labels |
| AC4 | Pass | `set_pane_env()` uses `tmux set-environment -t <pane_id> PF_PANE_ROLE <role>` |
| AC5 | Pass | `pf tmux list` prepends icon column (text) and includes `icon` field (JSON) |

**Deviation Review:** One minor deviation documented by Dev — changed `load_registry` import from name-binding to module-level access for mockability. This is a standard Python testing pattern and architecturally sound. No spec drift.

**Architecture Notes:**
- Implementation follows existing `{success, data?, error?}` result pattern consistently
- Icon mapping uses a simple dict lookup — appropriate for a small, fixed set of roles
- No new dependencies introduced
- Clean separation: `panes.py` owns the icon/border/env logic, `cli.py` consumes it

**Handoff:** To Thufir Hawat (TEA) for verify phase

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed — 15/15 tests passing

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 5 findings | 2 high (test parameterization, error helper), 1 medium (mock setup), 2 low |
| simplify-quality | clean | No findings |
| simplify-efficiency | 3 findings | 2 high (registry/live-panes error patterns), 1 medium (split logic duplication) |

**Applied:** 1 high-confidence fix — parameterized 4 identical role icon tests into `@pytest.mark.parametrize` (-21 lines, +4 lines)
**Flagged for Review:** 3 findings — error handling helper extraction in cli.py (pre-existing pattern, out of story scope)
**Noted:** 3 low-confidence observations (mock setup boilerplate, _get_context already good, trivial icon lookup)
**Reverted:** 0

**Overall:** simplify: applied 1 fix

**Quality Checks:** 15/15 tests passing, no regressions
**Handoff:** To Leto II (Reviewer) for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none — 15/15 GREEN, no smells | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 3 | confirmed 1 (Unicode width), dismissed 2 |
| 3 | reviewer-silent-failure-hunter | Yes | clean | none | N/A |
| 4 | reviewer-test-analyzer | Yes | findings | 9 | confirmed 0, dismissed 7, deferred 2 |
| 5 | reviewer-comment-analyzer | Yes | findings | 1 | confirmed 1 (lying docstring) |
| 6 | reviewer-type-design | Yes | findings | 4 | confirmed 0, dismissed 3, deferred 1 |
| 7 | reviewer-security | Yes | clean | none | N/A |
| 8 | reviewer-simplifier | Yes | findings | 4 | dismissed 4 |

All received: Yes
Total findings: 2 confirmed (Medium), 16 dismissed (with rationale), 3 deferred

### Finding Decisions

**Confirmed:**
- [DOC] `configure_pane_borders()` docstring claims "role labels and icons" but format only shows title — misleading. `panes.py:159`. **Medium** — cosmetic docstring fix, not blocking.
- [EDGE] Unicode icon width in `f"{icon:3}"` may misalign columns in some terminals. `cli.py:105`. **Medium** — cosmetic, Nerd Font width is a known cross-terminal challenge.

**Dismissed:**
- [EDGE] Header misalignment (same root cause as Unicode width — single finding, not two)
- [EDGE] Missing guard on `role` input — `dict.get()` handles None/empty safely, and registry always provides a string. Adding a guard is over-engineering for internal code.
- [TEST] "Vacuous assertion" on `test_role_has_icon` — it's parameterized and paired with `test_all_icons_are_distinct`. Together they cover AC1 fully.
- [TEST] "Implementation coupling" on border format test — test correctly verifies `pane-border-format` is set and `#{pane_title}` is referenced. That's the AC requirement.
- [TEST] "Zero-assertion" on `test_border_format_contains_pane_title` — uses `pytest.fail()` which is standard pattern for loop-based assertions.
- [TEST] "Incomplete mock" on `test_env_value_matches_role` — test verifies role value appears in tmux call args, which is sufficient for a 3-point story.
- [TEST] "Tautological" on `test_json_output_includes_icon_field` — calling `get_pane_icon()` in test is standard practice for DRY test constants. Not tautological — it verifies CLI integration wires through to the function.
- [TEST] Missing edge cases for worker/saddle in list test — existing tests cover the icon lookup function exhaustively; CLI test covers integration path.
- [TEST] Fallback distinctness from known icons — covered implicitly by `test_all_icons_are_distinct` + `test_unknown_role_returns_fallback`.
- [TYPE] Stringly-typed role — pre-existing pattern across all panes.py/registry.py. Out of scope for this story.
- [TYPE] Dict return types — `{success, data?, error?}` is the project-wide convention (SOUL.md Principle 10). Adding TypedDict is a cross-cutting concern.
- [TYPE] Inconsistent CLI choices — `click.Choice(["worker", "agent", "script"])` is pre-existing code, not in this diff.
- [SIMPLE] `get_pane_icon()` as "wrapper-no-value" — it's a named public API function providing self-documenting interface and single point of change. Correct abstraction.
- [SIMPLE] `configure_pane_borders()`/`set_pane_env()` as "wrapper-no-value" — these are AC-required building blocks for future tmux integration. Not orphaned, intentionally scoped.
- [SIMPLE] Import alias "less direct" — the alias pattern was deliberately chosen for mock compatibility. Reverting would break tests.

**Deferred:**
- [TEST] Missing edge case for malformed/missing role in list output — valid improvement but out of scope for 3-point story. Future story could add defensive tests.
- [TEST] Error message propagation assertions — low-value for internal functions following `{success, error}` pattern.
- [TYPE] Role enum/Literal type — cross-cutting improvement across tmux subsystem, worth a future story.

## Reviewer Assessment

**Verdict:** APPROVED

**Review Checklist:**
- [x] Subagent completion gate passed — all 8 rows filled
- [x] 7 observations documented (2 confirmed, 5 verified-good notes below)
- [x] Data flow traced: `role` from registry → `get_pane_icon()` → CLI output (safe — no user input reaches subprocess)
- [x] Wiring: `panes.py` functions correctly consumed by `cli.py` list command
- [x] Pattern: `{success, data?, error?}` followed consistently at `panes.py:159-185`
- [x] Error handling: `configure_pane_borders` short-circuits on first failure at `panes.py:168`. `set_pane_env` delegates to caller. Both correct.
- [x] Security: `subprocess.run` with list args (no shell=True) at `panes.py:19-25`. No injection vectors.
- [x] Hard questions: `get_pane_icon(None)` returns fallback (safe). Empty role returns fallback (safe). No race conditions — icon lookup is pure function.
- [x] Subagent findings incorporated — 2 confirmed [DOC][EDGE], 16 dismissed with rationale, 3 deferred
- [x] [TEST] Test quality reviewed — assertions are functional, parameterization is appropriate, mock patterns standard
- [x] [TYPE] Type design reviewed — stringly-typed roles are pre-existing pattern, dict returns follow project convention
- [x] [SIMPLE] Complexity reviewed — functions are minimal, wrapper pattern provides named API surface, no over-engineering
- [x] Judgment: No Critical or High issues. APPROVE.

**Verified Good:**
- [VERIFIED] All 3 new functions follow `{success, data?, error?}` return pattern
- [SEC] `subprocess.run` uses list args, no `shell=True` — no injection vectors. All inputs from trusted sources (registry, tmux output).
- [SILENT] No swallowed errors — `configure_pane_borders` propagates first failure, `set_pane_env` returns result directly. No empty catches or silent fallbacks.
- [VERIFIED] Import change from name-binding to module-level access is correct for mock compatibility
- [VERIFIED] Icon dict is immutable module-level constant — thread-safe
- [VERIFIED] 15/15 tests GREEN, no code smells

**Handoff:** To Stilgar (SM) for finish-story