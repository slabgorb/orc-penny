# Story 153-4 Context

## Title
`pf sprint story remove/update/finish` all fail to locate stories in epic shard files — same root cause (BLOCKING: breaks SM finish ceremony)

## Type
bug (P1, 5 points, tdd workflow)

## Repo
`pennyfarthing/` (inlined framework source). Base branch: `develop`.

## Problem

The sprint YAML is sharded: `current-sprint.yaml` holds the sprint header plus epic refs (e.g. `PROJ-14510`), while individual stories live in `sprint/epic-{ref}.yaml` shard files. A shared `load_sprint()` loader merges the shards into the in-memory dict structure expected by the rest of the code.

`pf sprint story add` and `pf sprint epic show` work — they go through the shared loader. Three other story-mutation commands fail:

- `pf sprint story remove <id>`
- `pf sprint story update <id> --<field> <value>`
- `pf sprint story finish <id>` — BLOCKING — kills the entire SM finish ceremony (no Jira move, no PR merge step, no session archival)

All three fail with: `Story 'X' not found in epics, standalone_stories, or stories`.

Most likely cause (per SM sidecar pattern `sprint-yaml-sharded`): these command paths read raw `current-sprint.yaml` directly (or via a non-merging loader) and call `_update_story_in_sprint` (or a sibling helper) that only walks the top-level `stories`/`standalone_stories` lists — never the merged epic stories.

## Repro (from story description)

```bash
mkdir /tmp/pf-bug && cd /tmp/pf-bug
mkdir sprint && cat > sprint/current-sprint.yaml <<'EOF'
sprint: {number: 1, goal: test, start_date: 2026-01-01, end_date: 2026-01-14, status: active}
epics: []
EOF
pf sprint epic add E "Test epic" --priority p1
pf sprint story add E "Story one" 1
pf sprint story remove E-1                  # → "not found"
pf sprint story update E-1 --status done    # → "not found"
pf sprint story finish E-1                  # → "not found in sprint YAML"
pf sprint epic show E                       # → works fine
```

## Scope

**In scope:**
1. Fix shard-story lookup in `pf sprint story remove`
2. Fix shard-story lookup in `pf sprint story update` (all `--field` variants)
3. Fix shard-story lookup in `pf sprint story finish` (and the underlying `_update_story_in_sprint` / yaml-update finish step)
4. Route all three through the shared `load_sprint()` + `write_sprint()` helpers from `yaml_io` (or whichever module provides the merging loader)
5. Verify shard-only sprints (no top-level `stories`, no `standalone_stories`) work end-to-end

**Out of scope:**
- Sprint YAML schema migration
- Reworking `pf sprint story add` (already works)
- Jira-side reconciliation behavior (separate concern)
- New story fields

## Acceptance Criteria

1. `pf sprint story remove <story_id>` succeeds against a shard-stored story; the story disappears from the shard file.
2. `pf sprint story update <story_id> --status done` (and other `--field` variants the CLI accepts) succeeds against a shard-stored story and the field is written back to the shard file, not lost.
3. `pf sprint story finish <story_id>` succeeds against a shard-stored story and completes the full finish ceremony (yaml-update step does not error).
4. The full repro from the story description runs to completion without `not found` errors.
5. All three commands resolve stories via the same shared loader path — no per-command ad-hoc YAML reads remain in the mutation code paths.
6. Regression: existing tests for `pf sprint story add` and `pf sprint epic show` still pass; behavior for non-sharded sprint YAML (legacy fixtures, if any) is unchanged.

## Approach Hints (non-binding)

- The shared loader lives in `pennyfarthing-dist/src/pf/sprint/yaml_io.py` (or close — search for `load_sprint`, `write_sprint`).
- Likely offenders to audit: `pennyfarthing-dist/src/pf/sprint/*.py` (especially modules that handle `remove`, `update`, `finish`) and `pennyfarthing-dist/src/pf/jira/bidirectional.py` (`execute_sync_plan`, `_update_story_in_sprint`).
- The SM sidecar pattern `sprint-yaml-sharded` documents the root cause — the code reading raw YAML doesn't see merged shard stories.
- Tests should pin behavior against a sprint fixture that contains *only* shard stories (no top-level `stories`) — the current bug hides when both forms are present.

## Out-of-band notes

- Story 153-1 (session file path) is already merged.
- Story 153-6 covers missing `sprint/context/context-story-{ID}.md` creation — separate fix, but explains why this context file had to be created by hand.
- Story 153-3 adds `pf sprint story move` + `--epic` flag. If it lands first, the shared loader should already be plumbed; if not, 153-4 lays the groundwork.
- This is the BLOCKING fix in epic 153 — every other story's SM finish ceremony depends on it.
