# Story 132-11: Build pf status dashboard command

## Story Details
- **ID:** 132-11
- **Jira Key:** MSSCI-15647
- **Title:** Build pf status dashboard command
- **Points:** 3
- **Epic:** 132 (Developer Discovery & Onboarding)
- **Repos:** pennyfarthing
- **Workflow:** tdd

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-25T16:18:29Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-25T15:57:21Z | 2026-02-25T15:58:22Z | 1m 1s |
| red | 2026-02-25T15:58:22Z | 2026-02-25T16:05:45Z | 7m 23s |
| green | 2026-02-25T16:05:45Z | 2026-02-25T16:16:15Z | 10m 30s |
| verify | 2026-02-25T16:16:15Z | 2026-02-25T16:16:59Z | 44s |
| review | 2026-02-25T16:16:59Z | 2026-02-25T16:18:29Z | 1m 30s |
| finish | 2026-02-25T16:18:29Z | - | - |

## SM Assessment
Story claimed (MSSCI-15647), session created, branch `feat/132-11-pf-dashboard` ready in pennyfarthing/. TDD workflow, 3pts — routing to TEA for RED phase. Context file at `sprint/context/context-132-11.md` has full technical approach and data source mapping. New `pf.dashboard` subpackage with collector pattern.

## TEA Assessment

**Tests Required:** Yes
**Reason:** New CLI command with 7 distinct ACs covering output formatting, JSON mode, graceful degradation, registration, performance, multi-context support, and doctor integration.

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_dashboard.py` — 36 tests across 9 test classes

**Tests Written:** 36 tests covering 7 ACs
**Status:** RED (32 failing, 4 passing — structural tests that stubs satisfy)

**Stub Files Created:**
- `pf/dashboard/__init__.py` — package init
- `pf/dashboard/cli.py` — Click command stub (no-op)
- `pf/dashboard/collector.py` — collector function stubs (return empty dicts)

**Failure Modes:** All assertion-based (correct RED). No import or syntax errors.
- Registration: `dashboard` not in `_LAZY_COMMANDS`
- Output: empty string contains no expected fields
- Collectors: empty dicts missing `display`/`data` keys
- Health: mock target `run_doctor` not yet imported in collector

**Handoff:** To Korben Dallas (Dev) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/cli.py` — registered `dashboard` in `_LAZY_COMMANDS`
- `pennyfarthing-dist/src/pf/dashboard/cli.py` — Click command with `--json` flag, lazy imports for collector
- `pennyfarthing-dist/src/pf/dashboard/collector.py` — 8 data collectors (theme, workflow, sprint, story, hooks, tui, repos, health), format_dashboard, graceful degradation for all fields

**Tests:** 36/36 passing (GREEN)
**Branch:** feat/132-11-pf-dashboard (pushed)

**Notes:** Performance test causes module identity split by deleting `pf.dashboard.*` from sys.modules; collect_health resolves run_doctor through sys.modules to ensure test patches apply correctly.

**Handoff:** To next phase (review)

## TEA Verify Assessment

**Tests Verified:** 36/36 passing (GREEN confirmed)
**Duration:** 0.42s
**All ACs covered:** Registration, output format, JSON, graceful degradation, performance, multi-context, health integration
**Status:** GREEN verified — ready for review

**Handoff:** To Reviewer (Jean-Baptiste Emanuel Zorg) for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `pf dashboard` → lazy command → `get_project_root()` → `collect_all()` → 8 collectors → `format_dashboard()` (safe — read-only, no user input)
**Pattern observed:** Consistent collector pattern `{display, data}` across all 8 functions at `collector.py:103-281`
**Error handling:** Every collector wraps in try/except with graceful fallback — no uncaught paths
**Security:** Read-only. No injection vectors, no writes, no path traversal.
**Notes:** Two LOW findings (git clean fallback, HEAD file vs worktree) — neither blocking.
**Handoff:** To SM for finish-story

## Story Context

### Acceptance Criteria
- `pf dashboard` prints the formatted status block shown above with live data
- `pf dashboard --json` outputs the same data as a JSON object
- Every field degrades gracefully: missing config shows "not configured", missing sprint shows "no sprint loaded", git errors show "unavailable"
- Command is registered in `_LAZY_COMMANDS` and appears in `pf --help`
- Startup stays under 200ms (lazy imports only — no subsystem loaded until invoked)
- Works from the project root in both orchestrator and consumer contexts
- Doctor health field runs the same checks as `pf doctor` and summarizes the result

### Technical Approach
Create a new `pf.dashboard` subpackage following the existing pattern (lazy-loaded Click command with logic in a sibling module). The command collects data from multiple existing subsystems and formats a single aligned output block.

**New subpackage** at `pennyfarthing-dist/src/pf/dashboard/` with:
- `__init__.py`
- `cli.py` — Click command definition with `--json` flag
- `collector.py` — data collection functions, one per field

**Register** in `cli.py`'s `_LAZY_COMMANDS` dict as `"dashboard": ("pf.dashboard.cli", "dashboard")`

Each collector function returns a simple string (for display) or a dict (for `--json` mode).

### Output Format
```
Pennyfarthing Status
  Theme:     discworld (Tier A)
  Workflow:  none active
  Sprint:    132 — Developer Discovery & Onboarding
  Story:     none assigned
  Hooks:     11 active (session-start, session-stop, reflector-check, pre-edit-check, ...)
  TUI:       not running
  Repos:     orchestrator (main, clean) | pennyfarthing (develop, clean)
  Health:    all green
```

### Data Sources
| Field | Source | How |
|-------|--------|-----|
| Theme | `.pennyfarthing/config.local.yaml` → `theme` key | `load_pennyfarthing_config()` from `pf.common.config`, tier from `pf.common.themes.list_themes()` |
| Workflow | Active session file in `.session/` | `pf.workflow` check logic, or parse session file `Workflow:` line |
| Sprint | `sprint/current-sprint.yaml` (index + shards) | `pf.sprint.loader.get_sprint_info()` for sprint number and title |
| Story | Active session file in `.session/` | Parse session file for story ID, or check for `in_progress` stories in sprint data |
| Hooks | `.claude/settings.local.json` → `hooks` key | Parse JSON, count hook entries across all event types (SessionStart, Stop, PreToolUse, PostToolUse), extract command names |
| TUI | WheelHub PID file in `.pennyfarthing/` | `pf.bikerack.launcher.is_already_running()` or `get_status()` — checks PID file and port file |
| Repos | `.pennyfarthing/repos.yaml` + git commands | `pf.git.status_all.get_all_repo_status()` for branch name and clean/dirty state per repo |
| Health | Doctor check results | `pf.doctor.core.run_doctor()` — run all checks, summarize as "all green" / "N issues" |

### Dependencies
- `pf.common.config` — `get_project_root()`, `load_pennyfarthing_config()`
- `pf.common.themes` — `list_themes()` for tier lookup
- `pf.sprint.loader` — `get_sprint_info()`, `load_sprint()`
- `pf.doctor.core` — `run_doctor()` for health summary
- `pf.bikerack.launcher` — `get_status()` for TUI/WheelHub state
- `pf.git.status_all` — `get_all_repo_status()` for repo branch/clean info
- No new external dependencies required — everything is already in the pf CLI

### Key Files to Create/Modify
**Create:**
- `pennyfarthing/pennyfarthing-dist/src/pf/dashboard/__init__.py`
- `pennyfarthing/pennyfarthing-dist/src/pf/dashboard/cli.py` — Click command
- `pennyfarthing/pennyfarthing-dist/src/pf/dashboard/collector.py` — data collection logic

**Modify:**
- `pennyfarthing/pennyfarthing-dist/src/pf/cli.py` — add `"dashboard"` to `_LAZY_COMMANDS`