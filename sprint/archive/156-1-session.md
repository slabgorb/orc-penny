---
story_id: "156-1"
jira_key: ""
epic: "156"
workflow: "tdd"
---
# Story 156-1: story update fails for stories in epic-*.yaml shards (no sprint wrapper) (gh #10)

## Story Details
- **ID:** 156-1
- **Jira Key:** (kanban-only — no Jira)
- **Workflow:** tdd
- **Repo:** pennyfarthing
- **Branch:** feat/156-1-story-update-epic-shards
- **Branch Strategy:** gitflow (PR → develop)
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** review
**Phase Started:** 2026-06-04T05:14:00Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-04T04:57:44Z | 2026-06-04T04:58:30Z | ~1m |
| red   | 2026-06-04T04:58:30Z | 2026-06-04T05:05:00Z | ~6m |
| green | 2026-06-04T05:05:00Z | 2026-06-04T05:14:00Z | ~9m |
| review| 2026-06-04T05:14:00Z | 2026-06-04T05:30:00Z | ~16m |
| finish| 2026-06-04T05:30:00Z | - | - |

**RED result:** 7 failed / 2 passed (regression guards) — commit `34be1a7`.
**GREEN result:** 9/9 pass — commit `99d9ed7`. Fix: new `validate_sprint_document` dispatcher (`validator.py`) routes raw epic shards → `validate_epic_shard`; wired through story_update/story_remove/story_move. 958 passed in regression scope; 2 failures pre-existing (agent-validator, unrelated — confirmed on HEAD).

## Context (from gh #10)

**Problem:** `pf sprint story update <ID> --<field>` fails for stories living in
`sprint/epic-*.yaml` shards instead of `current-sprint.yaml`. Two distinct bugs:

1. **Lookup gap** — `story update` only searches `current-sprint.yaml`; it doesn't
   fan out across `epic-*.yaml` / `standalone-*.yaml` shards the way `story show`
   already does. Result: `Error: Story 'X' not found in epics, standalone_stories, or stories`.
2. **Validator mismatch** — even when handed the right file via `--sprint-file`,
   post-update validation rejects epic shards because they have no top-level
   `sprint:` wrapper (`Missing required 'sprint' section`).

**Downstream impact:** `pf sprint story finish` prints `yaml_update (warning: ... not
found)` and continues — stories ship + archive while their epic YAML stays
`backlog`/`in_progress`. Progress reports silently lie (OQ-1 Epic 31 was stale for days).

**Suggested fixes (from issue):**
1. Teach `story update` to search all `sprint/epic-*.yaml` + `sprint/standalone-*.yaml`
   when not found in `current-sprint.yaml` (mirror `story show`).
2. Relax/route post-update validation to the epic schema (not sprint schema) when
   the loaded file is an epic shard.
3. (Stretch / related to epic 155) make `story finish` fail loudly on yaml_update miss.

**Likely code locations (TEA/Dev to confirm):**
- `pennyfarthing-dist/src/pf/sprint/` — story update command + `yaml_io` loader/writer
  (`load_sprint`/`write_sprint` already handle shards; `story show` finds shard stories;
  the `_update_story_in_sprint` / raw-YAML path is the divergence — see SM sidecar
  `sprint-yaml-sharded` pattern).

## Acceptance Criteria (TEA to finalize in RED)
- AC1: `pf sprint story update <ID> --<field> <val>` succeeds for a story that lives
  only in a `sprint/epic-*.yaml` shard (no `--sprint-file` needed).
- AC2: The update persists to the correct shard file and re-validates cleanly
  (no spurious `Missing required 'sprint' section` error on epic shards).
- AC3: Existing `current-sprint.yaml` story updates still work (no regression).
- AC4: Round-trip — `story show` reflects the updated field after `story update`.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): The issue's first symptom — `Story 'X' not found` — only
  reproduces today for *unindexed* shards (epic file on disk but not in
  `current-sprint.yaml`'s `epics:` list). For *indexed* shards 151-3 already fixed
  lookup. And `shard_merge.merge_epic_shards` *deliberately* skips unindexed shards
  (warning, no merge), so `story update` on a truly orphan-shard story still returns
  "not found" by design. Net: the live remaining bug for 156-1 is the **validator
  mismatch** (bullet 2), not lookup. Confirm with PM whether unindexed-shard mutation
  is in scope for epic 156 or intentionally unsupported. *Found by TEA during test design.*
- **Improvement** (non-blocking): `update_story` always calls `validate_full_sprint`,
  which assumes a top-level `sprint:` wrapper. The same mismatch will bite any sibling
  command that accepts `--sprint-file <epic>.yaml` (remove/transition). Suggest Dev add
  a single document-type dispatcher (`validate_full_sprint` vs `validate_epic_shard`)
  reused across mutation paths so the fix doesn't have to be re-applied per command.
  *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): Pre-existing unrelated test failures in
  `test_141_20_agent_validator.py` (`test_on_activation_after_line_100_warns`,
  `test_file_over_500_lines_errors`) fail on HEAD `34be1a7` with 156-1 changes
  stashed — i.e. they are red independent of this story (agent file-length / on-
  activation validation, a different module). Flagging so they aren't attributed to
  156-1; worth a separate triage story. *Found by Dev during GREEN regression run.*

## Review (Granny Weatherwax) — APPROVE-WITH-NITS @ 99d9ed7
Verified: RED reproduces (revert → 7 fail), GREEN 9/9, 190 regression tests pass across swapped paths, shard-detection byte-identical to write path. No Blocking/High. All 4 ACs covered.
- **M1 (Medium):** `story_add.py:142` still calls `validate_full_sprint` directly — same sibling `--sprint-file <epic>.yaml` bug the refactor claimed to cover. → FIX NOW.
- **L1 (Nit):** `is_epic_shard_document` not defensive vs `None`/non-mapping. → FIX NOW (same file).
- **M2 (Medium):** `validate_epic_shard` skips status-enum/points-numeric value checks (pre-existing gap exposed; harmless for update/remove/move). → FILE as epic 155/156 follow-up.
- **L2 (Nit):** `runtime/` not gitignored in framework repo. → FILE (housekeeping, out of scope).

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Adopted TEA's shared-dispatcher refactor (not scoped to update_story):** Plan
  allowed scoping the fix to `update_story` alone, but TEA's Improvement finding
  recommended a single document-type validation dispatcher reused across mutation
  paths. Implemented `validate_sprint_document(data)` + `is_epic_shard_document(data)`
  in `sprint/validator.py` and routed `update_story`, `remove_story`, and `move_story`
  through it. Reason: the swap is strictly safe — the dispatcher returns
  `validate_full_sprint` unchanged for any sprint-wrapped doc (zero behavior change on
  the existing path); it only changes behavior for raw epic shards, which previously
  *always* failed with the spurious `Missing required 'sprint' section`. Prevents the
  same bug resurfacing in sibling `--sprint-file <epic>.yaml` paths (remove/move).
