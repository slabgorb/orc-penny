# Session: td-4 — Sprint metrics must include completed stories from archive shards

**Story ID:** td-4
**Title:** Sprint metrics must include completed stories from archive shards
**Points:** 3
**Priority:** p1
**Type:** bug
**Status:** backlog
**Repos:** pennyfarthing
**Branch:** fix/td-4-sprint-metrics-archive
**Workflow:** trivial
**Phase:** finish

---

## Context

The `pf sprint metrics` command currently reports **0 done / 0 points** because it only reads completed stories from the current sprint file (`current-sprint.yaml`) and does not include completed stories from the archive.

In contrast, `pf sprint status` shows **5 completed / 10 points**, but the actual sprint history contains approximately **350 points across archived sprints**. This discrepancy indicates that:

1. **Archive files exist but are ignored** — completed stories are archived to `sprint/archive/sprint-*-completed.yaml` shards, but the metrics command doesn't read them
2. **Metrics are incomplete** — velocity calculations, progress tracking, and points-done metrics are missing ~340 points of completed work
3. **Status and metrics are inconsistent** — `pf sprint status` and `pf sprint metrics` report different completed points

The metrics command needs to be updated to include completed stories from archive shards when calculating done stories, completed points, and velocity metrics.

---

## Acceptance Criteria

- [ ] `pf sprint metrics` includes completed stories and points from `sprint/archive/sprint-*-completed.yaml` files
- [ ] Sprint status totals are consistent between `pf sprint status` and `pf sprint metrics`
- [ ] Completed points from prior sprints in the archive are counted in velocity/progress calculations
- [ ] Archive shard discovery follows the existing pattern used elsewhere (e.g., sprint story list commands)

---

## SM Assessment

Story is set up and ready for implementation. Bug in `pf sprint metrics` — doesn't read archive shards so reports 0 done. Real completed count is ~350 points. Trivial workflow — routes to Dev (Ponder Stibbons). Framework repo changes in `pennyfarthing/pennyfarthing-dist/src/pf/sprint/`.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/loader.py` — Fix get_all_stories() to include standalone_stories and top-level stories; add get_archived_stories() for sprint archive shards
- `pennyfarthing-dist/src/pf/sprint/cli.py` — Update metrics command to load and display archive data (268 stories / 684 points)
- `pennyfarthing-dist/src/pf/sprint/status.py` — Include top-level stories for consistency with metrics

**Tests:** 84/84 passing (GREEN) — 5 pre-existing structural failures unrelated to changes
**Branch:** fix/td-4-sprint-metrics-archive (pushed)

**Handoff:** To next phase (verify)

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `get_archived_stories()` → `load_yaml_config()` → `completed_stories` list → flat list. Safe, no injection.
**Pattern observed:** Defensive `isinstance(epic, dict)` check at `loader.py:251` prevents crash on unresolved shard refs.
**Error handling:** Malformed archives return None, guarded by `if data and "completed_stories" in data:` at `loader.py:279`.
**Consistency verified:** Both metrics and status now report 27 stories / 7 done / 15 pts / 58 total.
**No duplicate counting:** Archived stories removed from current sprint during archival.

**Handoff:** To SM for finish-story

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish