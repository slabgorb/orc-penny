# Story 136-23: TUI connects to wrong WheelHub — kill port-scanning fallback and enforce project-scoped discovery

## Story Details
- **ID:** 136-23
- **Jira Key:** PROJ-16061
- **Workflow:** tdd
- **Assigned to:** keithavery

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-03T11:49:37Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-03T11:38:57Z | 2026-03-03T11:39:26Z | 29s |
| red | 2026-03-03T11:39:26Z | 2026-03-03T11:43:21Z | 3m 55s |
| green | 2026-03-03T11:43:21Z | 2026-03-03T11:45:03Z | 1m 42s |
| review | 2026-03-03T11:45:03Z | 2026-03-03T11:49:37Z | 4m 34s |
| finish | 2026-03-03T11:49:37Z | - | - |

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

### Reviewer (code review)

- **Improvement** (non-blocking): `tui.py:main()` and `dev_main()` retain `DEFAULT_PORT = 2898` fallback at lines 1312-1323 and 1355-1366 — same anti-pattern fixed in `ws_client.py`. Normal launch via `launcher.py:start_tui()` always passes `--port` explicitly, so this only affects direct `python -m pf.bikerack.tui` invocation. Affects `pennyfarthing-dist/src/pf/bikerack/tui.py` (should raise or use project-scoped discovery instead of silent fallback). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `WheelHubClient(project_dir=X)` → `discover_port()` reads `X/.bikerack-port` → `connect()` uses `ws://localhost:{port}/ws/{channel}` — scoped per-project, no cross-contamination possible.
**Pattern observed:** Fail-fast error raising replaces silent DEFAULT_PORT fallback at ws_client.py:99-122 — correct pattern for project isolation.
**Error handling:** FileNotFoundError with actionable message ("Is WheelHub running? Start it with: pf bikerack start") at ws_client.py:116-118. RuntimeError for missing project_dir at ws_client.py:120-122.

| Severity | Issue | Location | Action |
|----------|-------|----------|--------|
| [LOW] | Dead constant `DEFAULT_PORT = 2898` no longer used by `discover_port()` | ws_client.py:30 | Non-blocking, cleanup |
| [MEDIUM] | `tui.py` retains same DEFAULT_PORT fallback pattern in `main()`/`dev_main()` | tui.py:1312-1323,1355-1366 | Follow-up story — normal launch always passes --port |
| [LOW] | Test docstring has stale file path | test_bikerack_project_isolation.py:10 | Cosmetic |

**Tests:** 17/17 GREEN. Pre-existing 29 failures in `tests/python/test_wheelhub_client.py` confirmed NOT regressions (same on develop baseline).

**Handoff:** To Leo McGarry (SM) for finish-story

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/bikerack/launcher.py` — Removed port-range scanning from `is_already_running()`
- `pennyfarthing-dist/src/pf/bikerack/ws_client.py` — Replaced `DEFAULT_PORT` fallback with error raising in `discover_port()`

**Tests:** 17/17 passing (GREEN)
**Branch:** feat/136-23-tui-wheelhub-discovery (pushed)

**Handoff:** To Josh Lyman (Reviewer) for code review

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_bikerack_project_isolation.py` — 17 tests covering all 5 ACs

**Tests Written:** 17 tests (7 failing, 10 passing)
**Status:** RED — failing tests target two port-scanning fallbacks:
1. `launcher.py:is_already_running()` scans `range(2898, 2909)` when files missing
2. `ws_client.py:discover_port()` falls back to `DEFAULT_PORT = 2898`

**Handoff:** To Toby Ziegler (Dev) for implementation

## SM Assessment

**Story:** 136-23 — TUI connects to wrong WheelHub
**Points:** 3 | **Priority:** p1 | **Workflow:** tdd

**Summary:** TUI's port-scanning fallback connects to the wrong project's WheelHub when multiple projects are running. Need to kill the fallback, enforce project-scoped `.bikerack-port` file discovery, and validate project identity on connection.

**Key Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/bikerack/launcher.py` — TUI launcher, WheelHub discovery
- `pennyfarthing/pennyfarthing-dist/src/pf/bikerack/tui_app.py` — TUI connection logic
- `pennyfarthing/packages/core/src/server/entry.ts` — WheelHub port file writing

**Acceptance Criteria:**
- TUI reads ONLY $PROJECT_DIR/.bikerack-port — no port scanning
- If port file missing, TUI starts its own WheelHub (or errors clearly)
- If port file exists but WheelHub is dead, TUI starts a new one
- TUI never connects to another project's WheelHub
- Two projects running simultaneously show correct project data

**Routing:** TDD workflow → Sam Seaborn (TEA) for test design, then Toby Ziegler (Dev).

**Risks:** Multi-project isolation — need integration testing with two simultaneous instances.