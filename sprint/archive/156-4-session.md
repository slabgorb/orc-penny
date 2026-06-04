---
story_id: "156-4"
jira_key: ""
epic: "156"
workflow: "tdd"
---
# Story 156-4: TUI sprint panel silently drops inline-dict epics — fetch_sprint shard-only (gh #50)

## Story Details
- **ID:** 156-4
- **Jira Key:** (kanban-only — no Jira)
- **Workflow:** tdd
- **Repo:** pennyfarthing
- **Branch:** feat/156-4-tui-fetch-sprint-inline-epics
- **Branch Strategy:** gitflow (PR → develop)

## Workflow Tracking
**Workflow:** tdd
**Phase:** green
**Phase Started:** 2026-06-04T07:05:00Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-04T06:55:00Z | 2026-06-04T06:56:00Z | ~1m |
| red   | 2026-06-04T06:56:00Z | 2026-06-04T07:05:00Z | ~9m |
| green | 2026-06-04T07:05:00Z | 2026-06-04T07:14:00Z | ~9m |
| review| 2026-06-04T07:14:00Z | - | - |

**GREEN result:** 4/4 — commit `6c25dce`. Fix: `merge_epic_shards(data, sprint_dir, load_file=...)` replaces shard-only loop; entries built from merged dicts; `jiraKey` from epic `jira` field. Scoped regression 295 passed. AC4 satisfied by loader's warn-on-missing.

**RED result:** 2 failed (AC1/AC2 inline epics dropped) / 2 passed (AC3 shard, AC5 standalone) — commit `f35588b`. Contract: `fetch_sprint()` takes NO args (resolves FRAME_PROJECT_DIR); returns `completedEpics` (camelCase) + entries `{id,title,jiraKey,status,stories}`. Fix: route through `load_sprint`/`merge_epic_shards`, build entries from merged dicts, preserve done→completedEpics split.

## Context (from gh #50)

**Symptom:** The Frame TUI Sprint panel renders an EMPTY active-epics section for projects
whose `current-sprint.yaml` uses the legacy monolithic format (epics as INLINE DICTS),
while Completed renders fine. `pf sprint status` (CLI) shows all epics — data is reachable,
just not via the TUI.

**Root cause:** `pf/frame/ws_push.py` `fetch_sprint()` (~lines 154-179) is **shard-only**.
It iterates `data["epics"]`, computes `jira_key = ref if str else ref.get("jira","")`, and
reads `epic-{jira_key}.yaml`; if the shard file isn't found it `continue`s silently. Inline-
dict epics keyed by `id` (not `jira`) → `jira_key=""` → looks for `epic-.yaml` → not found →
silent drop. This is a silent fallback (violates Gates-Over-Goodwill / fail-loud).

The CLI works because `sprint/loader.py:load_sprint()` → `shard_merge.merge_epic_shards()`
handles inline-dict epics correctly (returns data unchanged when `epics[0]` is a dict).
The two code paths disagree on the schema contract.

**Approved fix — Option A (issue's recommendation: smaller, matches CLI):**
Replace the bespoke shard-only loop in `fetch_sprint()` with the canonical loader — call
`merge_epic_shards(data, sprint_dir)` (or `load_sprint(project_root)`) so epics arrive as
fully-merged dicts (inline OR shard), then build the panel entries from those merged epic
dicts (each already has `id`/`title`/`status`/`stories`) instead of re-reading shard files.
No silent drops. (Option B — fail-loud + migration tooling — is REJECTED: no migration
tooling per project policy.)

**Code pointers:**
- `pennyfarthing-dist/src/pf/frame/ws_push.py` — `fetch_sprint()` (silent-drop loop).
- `pennyfarthing-dist/src/pf/sprint/loader.py:42` — `load_sprint(project_root)`.
- `pennyfarthing-dist/src/pf/sprint/shard_merge.py:17` — `merge_epic_shards(...)`.
- Mind the param: `fetch_sprint(project_dir)` vs `load_sprint(project_root)` — confirm path semantics.

## Acceptance Criteria (TEA to finalize in RED)
- AC1: `fetch_sprint()` against a `current-sprint.yaml` with INLINE-DICT epics returns those
  active epics in the `epics` list (non-empty), with id/title/status/stories populated.
- AC2: completed/done inline-dict epics are still routed to `completed_epics`.
- AC3: no regression — SHARD-format epics (string/jira refs + `epic-*.yaml`) still render.
- AC4: a referenced epic that genuinely cannot be resolved is NOT silently dropped — surfaced
  per the canonical loader's behavior (warn/merge), not a silent `continue`. (TEA: assert the
  loader path is used / no silent empty result for inline epics.)
- AC5: standalone_stories pseudo-epic behavior preserved.

## Delivery Findings
**Types:** Gap, Conflict, Question, Improvement | **Urgency:** blocking, non-blocking
<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): Return-key drift. `fetch_sprint()` returns `completedEpics` (camelCase), not `completed_epics`. Dev should preserve `completedEpics` when routing through the canonical loader to avoid breaking the SprintPanel contract. Affects `pf/frame/ws_push.py:fetch_sprint`. *Found by TEA during test design.*
- **Question** (non-blocking): AC4 ("genuinely unresolvable ref not silently dropped — warn/merge") is not directly assertable at the `fetch_sprint` boundary without coupling to `warnings`. The canonical `merge_epic_shards` already emits a `warnings.warn` for missing shard refs; routing through it satisfies AC4 by construction. I covered AC1/AC2/AC3/AC5 with behavioral assertions and rely on the loader path for AC4 rather than asserting on warning text. Dev/Reviewer: confirm this is acceptable, or add an explicit `pytest.warns` assertion in GREEN once the loader path is wired. *Found by TEA during test design.*

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/ws_push.py` — replaced shard-only epic loop in `fetch_sprint()` with `merge_epic_shards(data, sprint_dir, load_file=...)`; build panel entries from merged epic dicts.

**Tests:** 4/4 passing (GREEN) — AC1/AC2 now pass; AC3 shard + AC5 standalone regression guards stayed green. Scoped regression: 295 passed.
**Branch:** feat/156-4-tui-fetch-sprint-inline-epics (commit `6c25dced6`, GPG-signed)

**Loader choice:** Used `merge_epic_shards` (not `load_sprint`). `load_sprint` routes through `resolve_sprint_context`/`get_project_root` which require `.pennyfarthing/` discovery + config; the Frame already parsed `current-sprint.yaml` and resolves its dir via `_get_project_dir()` (FRAME_PROJECT_DIR). `merge_epic_shards` takes the already-parsed `data` + `sprint_dir` + a `load_file` callable cleanly, returns inline dicts unchanged and resolves shard refs, and emits the warn-on-missing-ref behavior that satisfies AC4 by construction.

**Contract preserved:** `fetch_sprint()` still takes NO args; return keys `type`/`sprint`/`epics`/`completedEpics` (camelCase) intact; entries keep `{id,title,jiraKey,status,stories}`; `jiraKey` now sourced from epic `jira` field (else "") so inline epics don't crash; standalone pseudo-epic preserved.

**Handoff:** To review phase.

## Review (Granny Weatherwax) — CHANGES-REQUIRED @ 6c25dce
Core fix verified good (inline epics render AC1/AC2, loader args correct, routing/contract/standalone preserved, summary now counts inline epics). But:
- **B1 (Blocking):** `jiraKey` regression. `ws_push.py:177` sources `epic_data.get("jira","")`; string-ref shards (incl. real Jira projects `epics:['PROJ-14298']`) have no `jira:` field in the shard → `jiraKey=""` → TUI Jira column blanks. Live-verified on orchestrator (`153..159`→"") and Jira-key case. Fix: precedence `epic.jira` → original ref string → `""` (never silently empty a string ref). → TEA assert + Dev fix.
- **B2 (Blocking, test gap):** AC3 never asserts `jiraKey`, so B1 slipped green. → TEA add `jiraKey` assertion + a ref≠id Jira-key fixture (RED), Dev makes green.
- **M1 (Medium):** malformed-but-present shard silently dropped (`_load_file` catches Exception → None → silent continue) — parity with old, against #50 spirit. → FILE follow-up (or optional).
- **L1 (Nit):** AC4 (warn-on-missing) holds empirically but untested. → optional `pytest.warns`.

## B1/B2 fix (post-review loop)
- TEA RED: `test_b1_jirakey_preserves_ref_when_ref_differs_from_id` + strengthened AC3 jiraKey asserts + `test_b2` inline→"" pin — commit `b29b6cc` (2 failed / 4 passed).
- Dev GREEN: `jiraKey` precedence `shard.jira → original index ref → ""` via id-correlation `ref_by_id` map built before merge (gap-safe vs positional zip) — commit `3ee1f77`. 6/6 green, scoped 297 passed.
- Pending: Granny delta re-review of `3ee1f77`.

## Design Deviations
<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->
### Dev (implementation)
- **jiraKey source:** Old code set `jiraKey` to the loop `ref` string (the shard filename key). Now sourced from the merged epic dict's `jira` field (`epic_data.get("jira","")`). Reason: merged dicts no longer carry the original ref; the epic's own `jira` field is the correct value, and inline epics with no `jira` correctly get `""`. AC3 (shard) still green.
- **jiraKey precedence fix (Reviewer B1, blocking) @ 3ee1f77:** The above over-corrected — string-ref shards (`epics:['PROJ-14298']`/`['157']`) have no `jira:` field, so `jiraKey` silently blanked to `""`, killing the TUI Jira column for Jira-backed/shard projects. Fixed: before merge, capture original string refs and map resolved-shard `id` -> ref (`ref_by_id`); `jiraKey` precedence is now shard's own `jira` -> original index ref -> `""`. Used id-correlation (not positional zip) so a missing-shard ref dropped by `merge_epic_shards` can't misalign the mapping. Inline epics (no jira, no ref) still yield `""` (test_b2 green). 6/6 targeted + 297 scoped.
