# Story 126-16: Epic promote fails for inline initiative epics — extract to shards on workflow finish

## Story Details
- **ID:** 126-16
- **Jira:** MSSCI-15612
- **Workflow:** trivial
- **Epic:** 126 (MSSCI-15488)
- **Assignee:** keith.avery@1898andco.io

## Description

Bug fix: `pf sprint epic promote` fails for epics defined inline in initiative YAML files because it expects separate shard files (`sprint/epic-{ref}.yaml`). The `_resolve_epic_ref` function looks for shard files but the `epics-and-stories` workflow writes epic data as sibling keys in the initiative file instead of extracting to shards.

### Acceptance Criteria

1. `pf sprint epic promote` works for epics defined inline in initiative files
2. OR the workflow that creates initiatives extracts epics to shard files automatically
3. Existing shard-based epics continue to work

### Key Files

- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/cli.py` — `epic_promote()`, `_resolve_epic_ref()`, `_epic_shard_path()`
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/shard_merge.py` — `merge_epic_shards()`
- `pennyfarthing/pennyfarthing-dist/workflows/epics-and-stories.yaml` — the stepped workflow that creates initiatives

## SM Assessment (setup)

Bug confirmed during sprint housekeeping. `_resolve_epic_ref()` in `cli.py:1909` only looks for shard files on disk — it doesn't check inline epic data in the initiative YAML. The `epics-and-stories` workflow writes epics as sibling YAML keys (e.g., `epic-132:` alongside `epics: [epic-132]`) but never extracts them to `sprint/epic-{ref}.yaml`.

**Recommended fix:** Modify `_resolve_epic_ref()` to fall back to reading inline epic data from initiative files when the shard file doesn't exist. This is the minimal fix — the workflow should also be updated to extract shards, but that's a separate concern.

**Repos:** pennyfarthing only.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/cli.py` — Added `init_data` fallback to `_resolve_epic_ref()` for inline initiative epics; updated all 3 callers

**Tests:** 110/112 passing (2 pre-existing JIRA key validation failures, unrelated)
**Branch:** `feat/126-16-fix-epic-promote-inline-initiatives` (pushed)

**AC Status:**
1. `pf sprint epic promote` works for inline initiative epics — DONE (fallback to sibling keys)
2. Existing shard-based epics continue to work — VERIFIED (epic-132 resolves via shard)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

| Severity | Observation | Location |
|----------|-------------|----------|
| [VERIFIED] | Shard files prioritized over inline — correct precedence | `cli.py:1922` |
| [VERIFIED] | `deepcopy` prevents mutation of source init_data | `cli.py:992` |
| [VERIFIED] | All 3 callers updated consistently | `cli.py:987,1886,1944` |
| [VERIFIED] | `write_sprint()` auto-creates shard for promoted inline epics | `yaml_io.py:384-390` |
| [MEDIUM] | Orphaned sibling key left in initiative after promote (dead YAML, non-blocking) | `cli.py:1080-1098` |

**Data flow traced:** String ref `"epic-132"` → `_resolve_epic_ref()` → shard miss → inline fallback → `init_data.get("epic-132")` → dict returned → `deepcopy` → promoted to sprint → `write_sprint()` creates shard file. Safe.

**Handoff:** To SM for finish-story

## Workflow Tracking

**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-02-24T18:45:34Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-24T18:39:28Z | 2026-02-24T18:40:17Z | 49s |
| implement | 2026-02-24T18:40:17Z | 2026-02-24T18:43:54Z | 3m 37s |
| review | 2026-02-24T18:43:54Z | 2026-02-24T18:45:34Z | 1m 40s |
| finish | 2026-02-24T18:45:34Z | - | - |