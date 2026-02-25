# Context: 132-11 Build pf status dashboard command

## Goal

Give developers a single `pf dashboard` command that prints a concise, human-readable snapshot of the entire Pennyfarthing installation state: theme, workflow, sprint, active story, hooks, TUI/WheelHub, repo status, and health. This replaces the need to run 5-6 separate commands to understand where things stand. Came from party-mode brainstorm on developer onboarding.

## Technical Approach

Create a new `pf.dashboard` subpackage following the existing pattern (lazy-loaded Click command with logic in a sibling module). The command collects data from multiple existing subsystems and formats a single aligned output block.

1. **New subpackage** at `pennyfarthing-dist/src/pf/dashboard/` with:
   - `__init__.py`
   - `cli.py` — Click command definition with `--json` flag
   - `collector.py` — data collection functions, one per field
2. **Register** in `cli.py`'s `_LAZY_COMMANDS` dict as `"dashboard": ("pf.dashboard.cli", "dashboard")`
3. Each collector function returns a simple string (for display) or a dict (for `--json` mode)
4. All data collection must be non-fatal: if a subsystem is missing or broken, show a graceful fallback (e.g., "unavailable", "not configured") rather than crashing

## Output Format

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

When `--json` is passed, output a machine-readable JSON object with the same fields.

## Key Files

### Create

- `pennyfarthing/pennyfarthing-dist/src/pf/dashboard/__init__.py`
- `pennyfarthing/pennyfarthing-dist/src/pf/dashboard/cli.py` — Click command
- `pennyfarthing/pennyfarthing-dist/src/pf/dashboard/collector.py` — data collection logic

### Modify

- `pennyfarthing/pennyfarthing-dist/src/pf/cli.py` — add `"dashboard"` to `_LAZY_COMMANDS`

## Data Sources

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

## Dependencies

- `pf.common.config` — `get_project_root()`, `load_pennyfarthing_config()`
- `pf.common.themes` — `list_themes()` for tier lookup
- `pf.sprint.loader` — `get_sprint_info()`, `load_sprint()`
- `pf.doctor.core` — `run_doctor()` for health summary
- `pf.bikerack.launcher` — `get_status()` for TUI/WheelHub state
- `pf.git.status_all` — `get_all_repo_status()` for repo branch/clean info
- No new external dependencies required — everything is already in the pf CLI

## Acceptance Criteria

- `pf dashboard` prints the formatted status block shown above with live data
- `pf dashboard --json` outputs the same data as a JSON object
- Every field degrades gracefully: missing config shows "not configured", missing sprint shows "no sprint loaded", git errors show "unavailable"
- Command is registered in `_LAZY_COMMANDS` and appears in `pf --help`
- Startup stays under 200ms (lazy imports only — no subsystem loaded until invoked)
- Works from the project root in both orchestrator and consumer contexts
- Doctor health field runs the same checks as `pf doctor` and summarizes the result
