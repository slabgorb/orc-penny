# Story Context: PROJ-14257

## Sprint Story Update Command

**Epic:** PROJ-14253 (Sprint Data Management System)
**Points:** 2 | **Workflow:** tdd | **Priority:** P1

## Overview

Create `/sprint story update` command that updates story fields by ID with auto-cleanup rules for status transitions.

## Technical Approach

The story update command uses `yaml_io.read_sprint()` to load the sprint YAML as a `CommentedMap`, locates the target story by parsing the story ID to extract the epic number (e.g., "76-4" yields epic "76"), then uses `loader.find_epic()` and `loader.find_story()` to navigate to the correct story. Once found, the command applies field updates directly to the `CommentedMap` object. After mutation, the updated data is written back via `yaml_io.write_sprint()`, which handles canonical key ordering, block scalar conversion, and atomic file writes.

The command implements auto-cleanup rules for status transitions. When a story is marked as `done`, `completed` is auto-populated with today's date (if not provided) and `assigned_to` is removed. When transitioning to `in_progress`, `started` is auto-set if not already present. These rules prevent stale metadata.

Validation is performed after mutation using `validator.validate_story()`. The entire operation is transactional: read, mutate, validate, write atomically. If validation fails, the write is aborted and the original file remains untouched.

## Files to Create

| File | Purpose |
|------|---------|
| `pennyfarthing/pennyfarthing_scripts/sprint/story_update.py` | Core update logic: field mutation, auto-cleanup rules, validation |
| `pennyfarthing/pennyfarthing_scripts/tests/test_story_update.py` | TDD tests organized by acceptance criteria |

## Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing/pennyfarthing_scripts/sprint/cli.py` | Register `update` subcommand |

## Key Implementation Details

- **Use `yaml_io.read_sprint(path)` not `loader.load_sprint()`** — need CommentedMap for round-trip fidelity
- Story field mutation is direct dict assignment on CommentedMap: `story["status"] = "done"`, `del story["assigned_to"]`
- Key ordering is automatically enforced by `write_sprint()` — no manual reordering needed
- Sprint file path: `config.get_project_root() / "sprint" / "current-sprint.yaml"` as default
- Field value types: `points` must remain `int`, dates as ISO `str`, status from `VALID_STORY_STATUSES`
- Lazy imports in cli.py

## Story Lookup Strategy

1. Parse story ID: split on `-` to get epic number (e.g., `"76-4"` → epic `"76"`)
2. `loader.find_epic(sprint_data, epic_num)` to locate epic (handles format variations)
3. `loader.find_story(epic, story_id)` to find story within epic
4. If either returns `None`, raise `click.ClickException`
5. Fallback: if ID has no `-`, search all epics linearly

## Auto-Cleanup Rules

- **status=done:** Auto-set `completed` to today if not provided, remove `assigned_to`
- **status=in_progress:** Auto-set `started` to today if not present
- **status=backlog/ready:** No automatic field changes
- Status values validated against `VALID_STORY_STATUSES`: `{backlog, ready, in_progress, done, canceled}`

## CLI Interface

```python
@sprint.command("update")
@click.argument("story_id")
@click.option("--status", type=click.Choice(["backlog", "ready", "in_progress", "done", "canceled"]))
@click.option("--completed", "completed_date", default=None)
@click.option("--assigned-to", default=None)
@click.option("--points", type=int, default=None)
@click.option("--priority", default=None)
@click.option("--started", "started_date", default=None)
@click.option("--dry-run", is_flag=True)
```

## Test Strategy

- **`TestUpdateStoryFields`** (AC1) — Update individual and multiple fields, preserve untouched fields
- **`TestFindStoryAcrossEpics`** (AC2) — Find in first/second epic, not found error, invalid format
- **`TestAutoCleanup`** (AC3) — Done removes assigned_to, auto-sets completed; in_progress auto-sets started
- **`TestValidateAndAtomicWrite`** (AC4) — Valid updates write, invalid rejected, file unchanged on failure, dry-run
- **`TestCLIIntegration`** — Command registered, CliRunner invocation, error exits

## Dependencies

- **76-1:** `read_sprint`, `write_sprint`, `STORY_KEY_ORDER`
- **Existing:** `loader.find_epic`, `loader.find_story`, `validator.VALID_STORY_STATUSES`, `validator.ISO_DATE_PATTERN`, `config.get_project_root`

## Edge Cases

- Story not found / epic not found — clear error messages
- No updates provided — noop or informational message
- Updating a completed story — allow (e.g., fixing completed date)
- Invalid status/date values — rejected before write
- Concurrent writes — atomic write handles partial corruption, last writer wins
- CommentedMap compatibility with find_epic/find_story (works via duck typing)
