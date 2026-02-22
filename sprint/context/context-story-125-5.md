# Context: Story 125-5 — Add pf sprint data --json canonical output for subprocess consumers

**Jira Issue:** MSSCI-15426
**Points:** 2
**Priority:** P2
**Epic:** 125 — Sprint State Engine Consolidation (MSSCI-15421)
**Workflow:** tdd

## Problem

Sprint data is currently read by 4 independent implementations across Python CLI, TypeScript/Cyclist, BikeRack TUI, and Jira sync tools. Each reimplements shard merging, orphan detection, and registry resolution independently, leading to divergence in how the merged sprint view is computed. TypeScript doesn't detect orphan shards; Python does. Future initiative resolution differs between implementations. This divergence creates correctness bugs and prevents reliable subprocess consumption.

The existing `pf sprint info` command outputs only basic sprint header JSON (name, jira_sprint_id, dates, goal, story point totals). This is insufficient for downstream consumers that need the complete merged sprint view — all stories with full fields, all epic metadata, orphan detection, and computed metrics.

The proposal recommends Option A (subprocess) as the single canonical data service: TypeScript and other consumers should call `pf sprint data --json` to get the authoritative merged view instead of reimplementing the merge logic themselves.

## Architecture

### Current Flow

```
Three paths currently exist for reading sprint data:

1. Python CLI (canonical):
   → load_sprint() in loader.py
   → resolve_sprint_context() via core/resolver.py
   → load_yaml_config(sprint_path)
   → _merge_epic_shards() via shard_merge.py
   → Returns: merged dict with full epics + orphan detection

2. TypeScript (partial, story 120-6):
   → sprint-data.ts file watcher
   → load sprint YAML + merge shards inline
   → Missing: orphan detection

3. pf sprint info command (existing, incomplete):
   → Returns: {name, jira_sprint_id, goal, dates, remaining, inProgress}
   → Missing: stories, epics, orphan list, full metadata
```

### Key Files

| File | Role |
|------|------|
| `pennyfarthing-dist/pf/sprint/loader.py` | Load sprint YAML, registry resolution, merge shards |
| `pennyfarthing-dist/pf/sprint/shard_merge.py` | Canonical shard merging + orphan detection |
| `pennyfarthing-dist/pf/sprint/yaml_io.py` | YAML I/O with deterministic serialization |
| `pennyfarthing-dist/pf/core/resolver.py` | SprintContext resolution (default vs. multi-sprint) |
| `pennyfarthing-dist/pf/sprint/cli.py` | Click CLI (contains `pf sprint info` at line 1471) |

### Merged Sprint Data Structure

The canonical merged output from `load_sprint()` contains:

```
{
  "sprint": {
    "name": "TO Sprint 2608",
    "jira_sprint_id": 310,
    "jira_sprint_name": "TO Sprint 2608",
    "goal": "...",
    "start_date": "2026-02-16",
    "end_date": "2026-03-01",
    "status": "active",
    "number": 2608
  },
  "epics": [
    {
      "id": "epic-125",
      "jira": "MSSCI-15421",
      "title": "...",
      "description": "...",
      "priority": "P2",
      "status": "in_progress",
      "repos": "pennyfarthing",
      "points": 13,
      "stories": [
        {
          "id": "125-5",
          "jira": "MSSCI-15426",
          "title": "Add pf sprint data --json canonical output...",
          "description": "...",
          "points": 2,
          "priority": "P2",
          "status": "todo",
          "assigned_to": "user@example.com",
          "workflow": "tdd",
          "repos": "pennyfarthing",
          "acceptance_criteria": [...],
          "started": "2026-02-21",
          ...
        }
      ]
    }
  ],
  "stories": [...],  // Standalone stories from current-sprint.yaml
  "standalone_stories": [...],  // Stories not in epics
  "_orphans": [  // NEW: detected orphaned epic shards
    {
      "id": "epic-117",
      "jira": "MSSCI-14999",
      "file": "epic-MSSCI-14999.yaml",
      "reason": "unindexed (not in current-sprint.yaml, not in initiative shards)"
    }
  ],
  "_registry": {  // Injected when using multi-sprint registry
    "name": "ocsf-rs1",
    "type": "spike",
    "context_root": "/path/to/spike/sprint/context/",
    "session_root": "/path/to/spike/.session/"
  }
}
```

**Metrics computed from merged view:**

```
points: {
  total: 127,
  completed: 45,
  in_progress: 32,
  backlog: 50
}
stories: {
  total: 31,
  done: 8,
  in_progress: 5,
  backlog: 18
}
```

### Shard Merge Logic (from shard_merge.py)

- Iterate through epics list in sprint YAML
- Each string ref (e.g., "MSSCI-15421" or "epic-125") → load `epic-{ref}.yaml` shard
- Replace string with full epic dict
- Detect and warn about:
  - Missing shard files (ref in index but file doesn't exist)
  - Orphaned shard files (file on disk but not in epics list or initiatives)
  - Silent errors during shard load (warn but continue)
- Return: merged epics list with all full dicts

### Orphan Detection (from shard_merge.py)

```python
# After merging indexed shards, scan remaining epic-*.yaml files on disk
for shard_file in sprint_dir.glob("epic-*.yaml"):
  if shard_file not in loaded_shard_files:
    if shard_file_id not in loaded_epic_ids:
      if shard_file_id not in initiative_refs:  # Skip initiative-owned shards
        warn(f"Unindexed shard {shard_file.name} not in epics list")
```

## Acceptance Criteria

### AC1: Command exists and returns merged data
- **Given** a sprint project with multiple epic shards
- **When** running `pf sprint data --json`
- **Then** output is valid JSON containing all merged epics, stories, and sprint metadata
- **And** response time is under 500ms for typical sprint size (10-15 epics, 50-100 stories)

### AC2: Output includes all story fields
- **Given** a story with all optional fields (acceptance_criteria, description, assigned_to, etc.)
- **When** running `pf sprint data --json`
- **Then** the output story object includes all fields from the merged view
- **And** no fields are truncated or simplified

### AC3: Orphan detection included in output
- **Given** an orphaned epic shard file (epic-*.yaml not referenced in current-sprint.yaml or initiatives)
- **When** running `pf sprint data --json`
- **Then** the output includes `_orphans` array with `{ id, jira, file, reason }`
- **And** orphans are not included in the main `epics` list (only reported in _orphans)

### AC4: Multi-sprint context preserved
- **Given** a user with an active sprint preference set (pf sprint use ocsf-rs1)
- **When** running `pf sprint data --json`
- **Then** the output includes `_registry` metadata showing active sprint name and type
- **And** all paths resolve to the focused sprint's files (sprint context applied)

### AC5: Computed metrics included
- **Given** a sprint with stories in various statuses
- **When** running `pf sprint data --json`
- **Then** output includes computed `points` object with total/completed/in_progress/backlog
- **And** output includes computed `stories` object with counts by status

## Implementation Notes

### Command Definition
- Add as `pf sprint data --json` subcommand (or replace existing `pf sprint info` with expanded version)
- Output format: `-o json` pattern like `pf sprint check` and `pf sprint status`
- No human-readable mode needed (this is subprocess interface only)

### Reuse Existing Components
- Call `load_sprint()` from loader.py (already does all the merging)
- Call `get_sprint_info()` for the sprint header
- Call `get_all_stories()` for standalone stories
- Compute metrics in Python (not TypeScript)

### Performance
- Single pass through loader.py (already optimized)
- Shard merge happens once during load_sprint() call
- Target: <500ms even with 15 epics × 100 stories = 1500 story objects
- Benchmark: measure on typical sprint (2608) before/after

### TypeScript Consumption (Story 125-6, next)
- Parse JSON output of `pf sprint data --json`
- Replace inline shard_merge logic in sprint-data.ts
- Call subprocess once per config change or polling cycle
- Cache result in memory between polls

### Error Handling
- If sprint file missing → return error JSON with `{error: "Sprint file not found"}`
- If shard load fails → include in warnings but continue with partial data
- Preserve shard_merge.py warnings as part of output (or stderr)

### Output Schema (TypeScript consumers should validate)
```typescript
interface SprintDataOutput {
  sprint: SprintHeader;
  epics: Epic[];
  stories: Story[];
  standalone_stories: Story[];
  points: {
    total: number;
    completed: number;
    in_progress: number;
    backlog: number;
  };
  stories_count: {
    total: number;
    done: number;
    in_progress: number;
    backlog: number;
  };
  _orphans?: Array<{
    id: string;
    jira?: string;
    file: string;
    reason: string;
  }>;
  _registry?: {
    name: string;
    type: string;
    context_root: string;
    session_root: string;
  };
}
```

### Testing
- Test with default sprint (current-sprint.yaml)
- Test with multi-sprint registry (pf sprint use <name>)
- Test with orphaned shard files (orphan detection)
- Test with missing shard files (warning handling)
- Test with empty sprint (minimal data)
- Measure response time
