# ADR-0022: Sprint Shard Validation and Reference Integrity

## Status: Proposed

## Context

Epics 94-97 were created by the `epics-and-stories` stepped workflow, promoted to the current sprint, and synced to Jira. None of them appeared in the sprint panel. Investigation revealed six cascading failures:

1. **Double-prefix filenames.** `epic_promote()` wrote files as `epic-epic-94.yaml` because the epic ID was `epic-94` and the reference builder prepends `epic-`. Already manually fixed once by user; broke again on re-promote.

2. **No schema enforcement on write.** The import path (`import_epic.py`) and promote path (`cli.py:epic_promote`) write epic YAML without running the validator. Files were written with `stories:` before `id:`, missing `jira:` fields, and `id: epic-94` (prefix baked in).

3. **Loader silently drops unresolvable refs.** `_merge_epic_shards()` in `loader.py` skips refs that don't resolve to files without any warning. Sprint showed 29 stories when 51 existed — nearly half invisible.

4. **Jira sync created duplicates.** Epic 94 was synced to Jira twice (MSSCI-14659 and MSSCI-14662) because there was no idempotency check — the `jira:` field was absent, so each sync looked like a fresh create.

5. **Reference format inconsistency.** `current-sprint.yaml` had both `MSSCI-14510` (works) and `epic-94` (broken). No validator catches that `epic-94` resolves to `epic-epic-94.yaml`.

6. **Stale completed session.** The workflow session sat at 100% complete but wasn't archived, blocking SM from picking up new work.

### What Exists Today

| Component | What It Does | What It Misses |
|-----------|-------------|----------------|
| `validator.py` | Validates structure after loading | Not called on any write path; skips string refs in sharded format |
| `yaml_io.py:write_sprint()` | Atomic writes, key ordering, shard splitting | No validation before write; `_get_epic_ref()` silently falls back |
| `yaml_io.py:_get_epic_ref()` | Prefer Jira key, fall back to ID | Returns `epic-94` without stripping prefix, causing double-prefix files |
| `loader.py:_merge_epic_shards()` | Loads shard files by ref | Silent skip on missing files; no warning |
| `epic_add.py` | Creates epic shard + index ref | Checks file/ref duplicates but not schema |
| `cli.py:epic_promote()` | Moves future → current sprint | ID collision check only; no schema or ref format validation |
| `jira/create.py` | Creates Jira epic from YAML | Checks if epic has `jira:` key but not cross-epic uniqueness |
| `import_epic.py` | Parses markdown → future.yaml | String building, no yaml_io, no validator, no schema |

### Epic 91 Coverage

Epic 91 (Cross-File Reference & Schema Validation Pipeline) covers validation of `pennyfarthing-dist/` source files — agents, workflows, guides, skills. It does NOT cover sprint YAML shard validation:

- 91-10 (yamllint) scopes to `pennyfarthing-dist/**/*.yaml`, not `sprint/`
- 91-11 (workflow schema) validates workflow definitions, not sprint structure
- 91-12 (agent structural) validates agent files, not epic shards
- 91-15 (cross-entity refs) validates agent↔workflow↔skill refs, not sprint refs

Sprint YAML validation is a separate concern from framework source validation.

## Decision

Add validation gates at two levels: **write-time** (prevent bad data) and **load-time** (detect and report bad data).

### 1. Validate on Write (Defensive)

Add a `validate_epic_shard()` function to `validator.py` that enforces:

```python
REQUIRED_EPIC_SHARD_FIELDS = {"id", "title", "status", "stories"}
REQUIRED_SHARD_STORY_FIELDS = {"id", "title", "points", "status"}
```

Validations:
- `id` must NOT start with `epic-` (that's a reference prefix, not an ID value)
- `id` should be `epic-{N}` where N is numeric — but the value stored should be this full string (the `_get_epic_ref` strips it)
- If `jira` present, must match `MSSCI-\d{5}`
- `stories` must be a list
- Each story must have required fields
- No duplicate story IDs within the epic

Call this validator from:
- `epic_add.py:add_epic()` — before writing shard
- `cli.py:epic_promote()` — after transforming, before `write_sprint()`
- `jira/create.py:create_epic_in_jira()` — after writing back Jira keys
- `import_epic.py:import_epic()` — after generating YAML (validate parsed result)

### 2. Normalize Epic References (Single Function)

Replace the implicit `_get_epic_ref()` fallback with a normalizer that canonicalizes references:

```python
def normalize_epic_ref(epic: Mapping) -> str:
    """Canonical reference for shard filename and index.

    Priority: Jira key > numeric ID extracted from epic-N > raw ID

    Raises ValueError if ID format is ambiguous.
    """
```

Rules:
- If `jira:` present and valid → use Jira key (e.g., `MSSCI-14659`)
- If `id` is `epic-94` → extract `94`, return `94` (file becomes `epic-94.yaml`)
- If `id` is `94` → return `94`
- If `id` is `MSSCI-14659` → return `MSSCI-14659`
- Reject `id` values that would create double-prefix filenames

### 3. Loader Warnings (Detective)

In `_merge_epic_shards()`, emit warnings for unresolvable refs:

```python
import warnings

for ref in epics:
    epic_file = sprint_dir / f"epic-{ref}.yaml"
    if not epic_file.exists():
        warnings.warn(f"Sprint epic ref '{ref}' not found: {epic_file}")
        continue
```

Add a `--strict` mode to `validate_sprint_file()` that treats unresolvable refs as errors.

### 4. Jira Idempotency Guard

In `create_epic_in_jira()`, before creating:
- Check if any existing Jira epic has the same title (JQL search)
- If found, warn and require `--force` to create duplicate

### 5. Session Cleanup

Add a `validate_sessions()` helper that detects completed workflow sessions:
- Read `**Status:**` or completion percentage
- Warn if 100% complete sessions exist in `.session/`
- Call from `pf agent start` activation path

## Consequences

### Positive
- Write-time validation prevents malformed epic shards from reaching disk
- Reference normalization eliminates the double-prefix class of bugs entirely
- Loader warnings make missing epics visible immediately (not silently lost)
- Jira idempotency prevents duplicate ticket creation
- All four creation paths share the same validation logic

### Negative
- Existing malformed shards need a one-time migration (or rely on the manual fixes already applied)
- `--strict` mode may be noisy during development if shards are created incrementally
- Adding validation to write paths may slow down batch operations marginally

### Implementation Scope

This is a targeted fix to `pennyfarthing_scripts/sprint/`:
- `validator.py` — add `validate_epic_shard()`, extend `REQUIRED_EPIC_FIELDS`
- `yaml_io.py` — harden `_get_epic_ref()` with normalization
- `loader.py` — add warnings for missing refs
- `epic_add.py` — call validator before write
- `cli.py:epic_promote()` — call validator after transform
- `jira/create.py` — add idempotency check
- `import_epic.py` — validate generated YAML before write

Estimated: 3-5 point story. Fits naturally in epic 91 as a new story, or as a standalone story since it covers sprint infrastructure rather than `pennyfarthing-dist/` source validation.
