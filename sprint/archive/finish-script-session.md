# Story: Rewrite finish-story as Python module

**Jira:** N/A (infra fix)
**Epic:** N/A (sprint tooling)
**Points:** 2
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** fix/finish-story-python

---

## Problem

`finish-story.sh` step 4 (YAML update) is broken. It targets `sprint/current-sprint.yaml` with yq path `.epics[].stories[]`, but the sprint now uses **epic shard files** (`sprint/epic-PROJ-14465.yaml`) with a flat `stories:` array at root. The yq updates silently do nothing.

The Python CLI `pf sprint story finish` just shells out to the broken bash script.

## Task

Replace the bash `finish-story.sh` with a native Python implementation in `pennyfarthing_scripts/sprint/`. The Python CLI `story_finish()` at `pennyfarthing_scripts/sprint/cli.py:278-305` should call this new module directly instead of shelling out.

## Requirements

1. **New module:** `pennyfarthing_scripts/sprint/story_finish.py`
2. **Replicate all 7 steps** from finish-story.sh:
   - Step 1: Archive session file to `sprint/archive/{jira-key}-session.md`
   - Step 2: Squash merge PR via `gh pr merge` (handle already-merged)
   - Step 3: Transition Jira to Done via `jira issue move`
   - Step 4: **Update sprint YAML** — use `read_sprint()` / `find_epic()` / `find_story()` / `write_sprint()` from `yaml_io.py` and `loader.py`. Set `status: done`, `completed: {today}`, remove `assigned_to`
   - Step 5: Archive completed epics via `pf sprint epic archive`
   - Step 6: Git cleanup (checkout develop, pull, delete local branch)
   - Step 7: Remove session file
3. **Wire into CLI:** Replace the subprocess call in `cli.py:story_finish()` with a direct call to the new module
4. **Support `--dry-run`** flag
5. **Return result objects** `{success, data?, error?}` per ADR-0008
6. **Tests:** Add tests in `pennyfarthing_scripts/sprint/tests/` or `tests/python/`

## Existing Utilities to Use

All in `pennyfarthing_scripts/sprint/`:

| Function | File | Purpose |
|----------|------|---------|
| `read_sprint(path)` | `yaml_io.py:87` | Reads sprint YAML, auto-loads shards |
| `write_sprint(path, data)` | `yaml_io.py:324` | Writes back with shard support, atomic |
| `find_epic(data, epic_num)` | `loader.py:84` | Finds epic by number/jira key |
| `find_story(epic, story_id)` | `loader.py` | Finds story within epic |
| `canonical_dump(data)` | `yaml_io.py:239` | Deterministic YAML output |
| `get_project_root()` | `common/config.py:14` | Project root detection |

Story ID format: `{epic-num}-{sequence}` (e.g., "83-2"). Split on "-", first part is epic number.

## Key Bug Detail

The bash script does:
```bash
SPRINT_FILE="$PROJECT_ROOT/sprint/current-sprint.yaml"
yq eval -i "(.epics[].stories[] | select(.id == \"$STORY_ID\")).status = \"done\"" "$SPRINT_FILE"
```

But `current-sprint.yaml` has `epics:` as a list of string refs (e.g., `- PROJ-14465`), NOT nested epic objects with stories. Stories live in shard files like `sprint/epic-PROJ-14465.yaml`. The `read_sprint()` function already handles loading and merging shards — use it.

## SM Assessment

Straightforward port. All utilities exist. The bug is a path mismatch — the Python YAML I/O layer already handles shards correctly. Wire it up and the YAML updates will work.

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/sprint/story_finish.py` — new module: `finish_story()` with 7-step workflow, session parsing, result objects
- `pennyfarthing_scripts/sprint/cli.py` — rewired `story_finish` CLI command to call Python module directly
- `tests/python/test_story_finish.py` — 21 tests covering parsing, YAML shard updates, dry-run, errors, CLI

**Bug Fix:** Step 4 now uses `read_sprint()` → `find_epic()` → `find_story()` → mutate → `write_sprint()` which correctly handles sharded epic files. The old bash script used yq paths against the index file which has no story data.

**Tests:** 21/21 passing (GREEN)
**PR:** #751 — fix(sprint): rewrite finish-story as Python module
**Branch:** fix/finish-story-python (pushed)

**Handoff:** To Reviewer for code review

---

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `story_id` → Path construction (`session_path`) → `_parse_session` regex extraction → `_extract_jira_key` validates `^PROJ-\d+$` → safe for file paths and subprocess args. No shell injection: `_run` uses list-based `subprocess.run` (no `shell=True`).

**Pattern observed:** Follows `story_update.py` result pattern exactly — `read_sprint()` → `find_epic()` → `find_story()` → mutate in-place → `write_sprint()`. Shard-aware writes work correctly because `write_sprint` detects `_is_sharded_on_disk` and splits to `epic-{ref}.yaml` files.

**Error handling:** Steps 1-7 are non-transactional (same as bash script). Each step logs to `steps[]` with `warning` or `error` keys. Function never raises — always returns result dict. Step 4 wrapped in try/except at `story_finish.py:167-185`.

| Severity | Observation | Location |
|----------|-------------|----------|
| [MEDIUM] | Hardcoded `"python"` instead of `sys.executable` — may fail on systems where `python` != `python3` | `story_finish.py:189` |
| [LOW] | Standalone stories (ID format `PROJ-XXXXX`) won't match epic split — step 4 emits warning, doesn't crash | `story_finish.py:169-170` |
| [VERIFIED] | No shell injection: `_run` uses list args, Jira key validated via regex before reaching subprocess | `story_finish.py:71-73, 53` |
| [VERIFIED] | Session regex handles all observed session formats (with/without bullet prefix, optional space after colon, multi-word keys) | `story_finish.py:27` |
| [VERIFIED] | `dry_run=True` has zero side effects — tested in `TestFinishStoryDryRun` | `story_finish.py:131-142` |
| [VERIFIED] | YAML shard update works correctly — `test_updates_story_status_to_done` reads back shard file and confirms mutation | `test_story_finish.py:163-178` |

**Tests:** 21/21 passing, no forbidden patterns, imports clean
**Handoff:** To SM for finish-story
