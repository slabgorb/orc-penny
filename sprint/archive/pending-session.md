# Story: Migrate bash sprint scripts to Python (shard-aware)

**Story ID:** standalone-sprint-scripts
**Jira:** pending
**Workflow:** trivial
**Phase:** approved
**Branch:** chore/migrate-sprint-bash-to-python
**Repos:** pennyfarthing
**Assigned:** claude
**Points:** 3

## Context

Six bash sprint scripts still read the monolithic `current-sprint.yaml` directly and don't support the sharded epic format introduced in commit `8011eef`. The Python sprint module (`loader.py`) already handles shards transparently. These bash scripts need to delegate to Python CLI commands.

## Scripts to Migrate

| # | Bash Script | Python Command | Notes |
|---|---|---|---|
| 1 | `available-stories.sh` | `sprint backlog` | CLI exists, wire shell to python |
| 2 | `check-story.sh` | `sprint check` | New CLI command needed |
| 3 | `get-story-field.sh` | `sprint story field` | New CLI command needed |
| 4 | `get-epic-field.sh` | `sprint epic field` | New CLI command needed |
| 5 | `sprint-info.sh` | `sprint info` | New CLI command needed |
| 6 | `sprint-metrics.sh` | `sprint metrics` | New CLI command needed |

## Pattern

Each bash script becomes a thin shim:
```bash
#!/usr/bin/env bash
# Delegate to Python CLI
exec python3 -m pennyfarthing_scripts.cli sprint <command> "$@"
```

Business logic lives in Python using `loader.py`'s shard-aware functions.

## Key Files

- `pennyfarthing/pennyfarthing_scripts/sprint/cli.py` — Sprint CLI commands
- `pennyfarthing/pennyfarthing_scripts/sprint/loader.py` — Shard-aware YAML loading
- `pennyfarthing/pennyfarthing_scripts/sprint/status.py` — Status formatting
- `.pennyfarthing/scripts/sprint/` — Bash scripts to replace

## Acceptance Criteria

- [x] All 6 bash scripts delegate to Python CLI commands
- [x] Python commands produce same output format as original bash
- [x] Shard resolution works transparently via loader.py
- [x] `available-stories.sh` shows stories from epic shard files
- [x] `check-story.sh` returns proper JSON for story/epic/next queries
- [x] `get-story-field.sh` and `get-epic-field.sh` return correct field values from shards
- [x] `sprint-info.sh` returns JSON metrics including sharded stories
- [x] `sprint-metrics.sh` displays correct progress with sharded data

## Dev Assessment

All 6 bash scripts migrated to thin Python CLI shims. Work already merged to develop via PR #716 (commit `0a066d777`). All acceptance criteria met — scripts delegate to `pennyfarthing_scripts.cli sprint` commands using shard-aware `loader.py`.

## Reviewer Assessment

**Verdict:** APPROVED
**PR:** #716 (already merged to develop)
**Data flow traced:** bash shim → Click CLI → `load_sprint()` → shard-aware loader → JSON/table output. No injection risk.
**Pattern observed:** Consistent `available_statuses = {"backlog", "ready", "planning"}` across all commands and `get_backlog_count()`/`get_next_story()`.
**Error handling:** `check` command handles next/epic/story/not_found/canceled cases. Defensive `isinstance(epic, dict)` checks in iteration.
**Security:** Args parsed by Click, no shell interpolation. `set -euo pipefail` in all shims.
**End-to-end verified:** All 6 scripts produce correct output against live sprint data.
**Handoff:** To SM for finish-story
