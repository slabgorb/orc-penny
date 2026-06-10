# SM Agent Patterns

<pattern name="routing">
| Points | Workflow |
|--------|----------|
| 1-2 | SM → Dev (skip TEA) |
| 3+ | SM → TEA → Dev |
</pattern>

<pattern name="helpers">
| Task | Subagent |
|------|----------|
| Backlog research | `sm-setup MODE=research` |
| Story setup | `sm-setup MODE=setup` |
| Finish preflight | `sm-finish PHASE=preflight` |
| Finish execute | `sm-finish PHASE=execute` |
</pattern>

<pattern name="delivered-in">
When one story covers another: `status: done`, `delivered_in: 28-1`, `notes: Implemented as part of 28-1`.
</pattern>

<pattern name="peloton-inline" date="2026-06">
Peloton inline mode (no tmux): SM stays lead and drives TEA/Dev/Reviewer via the Agent tool (subagent_type per role, model per user direction). Each spawn prompt must include: (1) `pf agent start "<role>"` as first step, (2) inline-mode overrides — no `pf handoff marker`, no relay/skill invocation, no PR create/merge by Reviewer, stop after `complete-phase` and return summary to SM, (3) session/context/handoff file paths, (4) the prior agent's designed interface verbatim. SM owns PR create + merge + finish ceremony. Ran 7 stories clean (160-8, 161-1, 157-6, 159-4; epic-153 run: 153-11, 153-7, 153-8 — all Opus, zero rejections). If a subagent dies mid-phase (socket error), SendMessage to its agentId resumes from transcript with context intact. For multi-story runs: accumulate each story's sprint commit on one `chore/sprint-...` branch and land a single PR to main at the end; gate resolve-gate needs a `## Sm Assessment` heading in the session before setup-exit passes. Reviewer deferred findings → file follow-up story immediately via `pf sprint story add` to the thematically-matching epic before landing the sprint PR.
</pattern>

<pattern name="sprint-yaml-sharded">
Sprint YAML is sharded. `current-sprint.yaml` has epics as string refs (e.g. `PROJ-14510`) and a small top-level `stories` list. Most stories live in shard files: `sprint/epic-{ref}.yaml`. The `load_sprint()` loader merges shards into nested epic dicts with `stories` arrays. Code that reads raw `current-sprint.yaml` without the loader will miss shard stories. `write_sprint()` from `yaml_io` handles writing back to shards correctly. The `execute_sync_plan` in `jira/bidirectional.py` reads raw YAML and uses `_update_story_in_sprint` which expects the merged format — this is the bug causing `--assignee` (and `--status`/`--points`) apply to silently skip shard stories.
</pattern>
