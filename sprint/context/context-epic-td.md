# Epic td: Technical Debt & Maintenance - Context

## Overview
Epic td is a collection of internal refactoring and improvement tasks that enhance system robustness, maintainability, and architecture without directly delivering end-user features. The first story (td-4) focuses on eliminating the monolithic completed archive file in favor of a sharded index+shard pattern.

## Story: td-4 - Shard Completed Archive

### Current State
The completed archive at `sprint/archive/sprint-2606-completed.yaml` is a flat monolith that inlines all story records:

```yaml
sprint:
  name: "TO Sprint 2606"
  jira_sprint_id: 309
  ...

completed_epics:
  - MSSCI-14453
  - MSSCI-14465
  ...

completed_stories:
  - id: 83-1
    epic: MSSCI-14465
    title: "Python complexity module"
    points: 2
    completed: 2026-02-08
  # ... 100+ more inlined stories
```

**Problems:**
1. Data duplication — stories exist in active sprint AND archive
2. Merge conflicts — when multiple agents complete stories, both modify the same large file
3. Inconsistent state — changes to a story in active sprint don't propagate to archive
4. No clear separation — archive should be read-only reference, not a full copy

### Target State
Follow the active sprint pattern (index + shards):

**sprint/archive/sprint-2606-completed.yaml** (index only):
```yaml
sprint:
  name: "TO Sprint 2606"
  jira_sprint_id: 309
  goal: "..."

completed_epics:
  - MSSCI-14453       # References shard file: sprint/archive/epic-MSSCI-14453.yaml
  - MSSCI-14465
  - ...

completed_stories:
  # Only for orphan stories not belonging to any epic (empty in this sprint)
```

**sprint/archive/epic-MSSCI-14465.yaml** (shard):
```yaml
id: epic-MSSCI-14465
title: "Complexity + Dependencies Tools"
status: done
completed: 2026-02-09
stories:
  - id: 83-1
    epic: MSSCI-14465
    title: "Python complexity module"
    points: 2
    completed: 2026-02-08
  - id: 83-2
    ...
```

### Benefits
1. **No duplication** — archive shards are the source of truth for completed epics
2. **Merge-safe** — each epic shard is independent; concurrent completions don't conflict
3. **Consistent** — single story record, not duplicated across files
4. **Pattern consistency** — archive mirrors active sprint structure

## Implementation Tasks

### Task 1: Refactor archive_epic.py
**File:** `pennyfarthing/pennyfarthing_scripts/sprint/archive_epic.py`

The function `archive_epic()` (lines 219-372) already:
1. Moves the shard file to `sprint/archive/epic-{ref}.yaml`
2. Removes the epic from `current-sprint.yaml` index
3. Adds the epic ref to the archive index

**Current behavior (line 324-331):**
```python
archive_data = _load_archive_file(archive_path)
if epic_ref not in archive_data["completed_epics"]:
    archive_data["completed_epics"].append(epic_ref)
_write_archive_file(archive_path, archive_data)
```

**What needs to change:**
- The archive_epic.py already writes stories to the shard (lines 299-313)
- The `_load_archive_file()` and `_write_archive_file()` functions already handle the new format
- **No changes needed in archive_epic.py** — it already uses the correct pattern!

The issue is that the completed archive file was created **before** the shard pattern was implemented. Need to:
1. **Verify** that archive_epic.py writes completed stories to shards (CONFIRMED — it does at lines 299-313)
2. **Migrate** existing sprint-2606-completed.yaml to use the index+shard pattern
3. **Test** that new archival operations produce correct shard files

### Task 2: Migrate existing completed file
**File:** `sprint/archive/sprint-2606-completed.yaml`

**Migration steps:**
1. Extract all completed epics and their story lists
2. For each epic in `completed_epics`:
   - Extract all stories belonging to that epic
   - Write to `sprint/archive/epic-{ref}.yaml` (if not already present)
   - Keep only the epic ref in the index
3. Update the index file to reference shards only
4. Keep `completed_stories` list for orphan stories (if any)

### Task 3: Test and verify
**Test scenarios:**
1. Load archive with existing refactoring code
2. Archive a new epic and verify shard creation
3. Load entire archive (index + shards) and verify story count matches
4. Merge conflict test — concurrent completions should not conflict

**Expected outcomes:**
- `sprint/archive/sprint-2606-completed.yaml` contains only index (epics refs + orphan stories)
- Each epic has its own shard: `sprint/archive/epic-MSSCI-14465.yaml`, etc.
- Total story count in archive matches original file
- No data loss during migration
- Archive loading and archival operations work correctly

## Related Code

### Current Sprint Index Pattern
**sprint/current-sprint.yaml:**
```yaml
sprint:
  name: TO Sprint 2606
  ...

epics:
  - MSSCI-14510      # String refs to shard files
  - MSSCI-14951
  - ...              # Each epic has epic-MSSCI-14510.yaml, epic-MSSCI-14951.yaml, etc.
```

### Archive Reading
The archive is typically read via:
```python
from pennyfarthing_scripts.sprint.archive_epic import get_archive_path, _load_archive_file
archive_path = get_archive_path(project_root)
archive_data = _load_archive_file(archive_path)  # Returns dict with completed_epics and completed_stories
```

The `_load_archive_file()` function (lines 93-121) already handles the index format correctly.

## References
- **Issue:** Data duplication and merge conflicts in completed archive
- **Pattern source:** sprint/current-sprint.yaml + sprint/epic-*.yaml
- **Related epic:** MSSCI-14510 (reference validation pipeline) — includes sprint shard work
- **Related story:** 91-24 (Sprint shard write-time validation)
