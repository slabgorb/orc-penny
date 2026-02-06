# Story Context: MSSCI-14256

## Sprint Story Add Command

**Epic:** MSSCI-14253 (Sprint Data Management System)
**Points:** 3 | **Workflow:** tdd | **Priority:** P0

## Overview

Create `/sprint story add` command that programmatically inserts new stories into the sprint YAML file under a specified epic.

## Technical Approach

This story implements the `/sprint story add` command, which programmatically inserts new stories into the sprint YAML file under a specified epic. The implementation builds directly on the infrastructure from stories 76-1 and 76-2: `yaml_io.py` provides atomic read/write with comment preservation via ruamel.yaml's `CommentedMap`/`CommentedSeq`, and `validate_cmd.py` plus `validator.py` provide post-insertion validation to ensure the file remains structurally sound.

The core logic lives in a new `story_add.py` module that handles story ID generation, field population with correct key ordering, epic lookup, and insertion. The function constructs a `CommentedMap` for the new story with keys ordered per `STORY_KEY_ORDER`, inserts it at the end of the target epic's stories list (a `CommentedSeq`), validates the entire sprint file post-insertion using `validate_full_sprint`, and writes atomically via `write_sprint`. This separation keeps the business logic testable independently of the CLI layer.

The Click command in `cli.py` serves as a thin adapter: it parses arguments and options, calls into `story_add.py` for the actual operation, and uses `output.py` helpers for colored console feedback. This follows the existing pattern where CLI commands delegate to dedicated modules, keeping `cli.py` focused on argument parsing and registration.

## Files to Create

| File | Purpose |
|------|---------|
| `pennyfarthing/pennyfarthing_scripts/sprint/story_add.py` | Core logic: story ID generation, CommentedMap construction, epic lookup, insertion, validation, and atomic write |
| `pennyfarthing/pennyfarthing_scripts/tests/test_story_add.py` | Tests covering all acceptance criteria, edge cases, and CLI integration |

## Files to Modify

| File | Change |
|------|--------|
| `pennyfarthing/pennyfarthing_scripts/sprint/cli.py` | Register `story add` subcommand via lazy import pattern |

## Key Implementation Details

- Construct the new story as a `ruamel.yaml.comments.CommentedMap`, not a plain dict, to preserve round-trip compatibility with `yaml_io.write_sprint`.
- Populate keys in the canonical order defined by `STORY_KEY_ORDER`: `id`, `jira`, `title`, `description`, `points`, `priority`, `status`, `in_sprint`, `assigned_to`, `started`, `repos`, `workflow`, `acceptance_criteria`, `completed`, `pr`, `delivered_in`, `notes`.
- Only include keys that have values. Required fields (`id`, `title`, `status`, `points`) are always present. Optional fields are included only when provided.
- Default `status` to `"backlog"`, `priority` to `"P1"`, `workflow` to `"tdd"`.
- Use `loader.find_epic(sprint_data, epic_num)` to locate the target epic; raise clear error if not found.
- After insertion, call `validator.validate_full_sprint(data)` on the in-memory data before writing.
- Use `yaml_io.write_sprint(path, data)` for atomic file write.
- Follow the lazy import pattern in `cli.py`.

## ID Generation Logic

Story IDs follow the pattern `<epic_number>-<sequence_number>` (e.g., `76-3`):

1. Extract the epic's numeric identifier (e.g., `76` from `epic-76`).
2. Iterate through all existing stories in that epic's `stories` list.
3. Parse each story's `id` to extract the sequence number (part after the hyphen).
4. Find the maximum sequence number. If stories list is empty, treat max as `0`.
5. New story ID = `<epic_number>-<max + 1>`.
6. Safety check: verify generated ID doesn't exist anywhere in sprint data.

## CLI Interface

```python
@story.command("add")
@click.argument("epic_id", type=str)
@click.argument("title", type=str)
@click.argument("points", type=int)
@click.option("--type", "story_type", type=click.Choice(["feature", "bug", "chore", "refactor"]), default="feature")
@click.option("--priority", type=click.Choice(["P0", "P1", "P2", "P3"]), default="P1")
@click.option("--workflow", type=click.Choice(["tdd", "trivial", "bdd"]), default="tdd")
@click.option("--jira", "jira_id", type=str, default=None)
```

## Test Strategy

- **`TestStoryAddRequiredFields`** — Required fields populated, defaults correct
- **`TestEpicValidation`** — Epic exists check, format variations
- **`TestStoryPositioning`** — Appended at end, key ordering correct
- **`TestFileValidation`** — Entire file validates after insertion
- **`TestAtomicWrite`** — Atomic write, no partial corruption
- **`TestIDGeneration`** — Sequence numbering, gaps, empty list
- **`TestCLIIntegration`** — CliRunner end-to-end tests

## Dependencies

- **76-1:** `read_sprint`, `write_sprint`, `STORY_KEY_ORDER`
- **76-2:** `validate_full_sprint` (post-insertion validation)
- **Existing:** `loader.find_epic`, `config.get_project_root`, `output.py`

## Edge Cases

- Empty stories list / no stories key on epic
- First story in a new epic (sequence starts at 1)
- Non-sequential existing IDs (gaps from deletions) — use max+1, don't gap-fill
- Epic not found — clear error listing available epic IDs
- Title with YAML-special characters (colons, quotes)
- Validation failure after insertion — abort write, preserve original
- Epic ID format variations (`"76"` vs `"epic-76"`)
