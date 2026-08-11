---
story_id: "162-17"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-17: pf sprint archive --apply false-success: removal filters only epics[].stories (misses standalone_stories; no-op on sharded index where epics are ID strings) yet unconditionally reports 'removed from current-sprint.yaml'

## Story Details
- **ID:** 162-17
- **Jira Key:** (none — no Jira integration)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-17-archive-apply-standalone-removal
- **PR:** (none yet — recorded when the PR is created)

## SM Assessment

**Spec:** the story title is the full spec (bug story, no separate ACs).

**Defect (confirmed by SM during setup):** `pennyfarthing-dist/src/pf/sprint/archive.py`, the `if apply:` block at lines 109-118.
1. The removal loop only iterates `sprint_data.get("epics", [])` and filters each `epic["stories"]` — it never touches a top-level `standalone_stories` list, so a standalone story is archived but left in `current-sprint.yaml`.
2. On a **sharded** index, `epics` entries are ID strings (e.g. `"162"`), not dicts, so the `isinstance(epic, dict)` guard is False for every entry → the loop is a silent no-op; nothing is removed.
3. In every case the code unconditionally appends `" and removed from {sprint_file.name}"` to the success message → **false success**: it claims removal even when nothing was removed.

**Fix shape (for Dev, not TEA):** make removal cover `standalone_stories` and handle the sharded-index representation; report removal truthfully (only claim "removed" when a story was actually removed). Return `{success, data?, error?}` — don't throw.

**TEA (RED):** write failing tests that reproduce all three facets — (a) `--apply` on a standalone story removes it; (b) `--apply` against a sharded index actually removes (not no-op); (c) the reported message does not claim removal when nothing was removed. Use `tmp_path` sprint fixtures; pass explicit `project_root` (do not rely on `monkeypatch.chdir` — env-var root resolution). Scoped test runs only (`uv run pytest src/pf/tests/test_...py -q` from `pennyfarthing-dist/`); never the full suite. `ruff check` changed files.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (5 failing / 2 passing preservation guards)

**Test File:** `pennyfarthing-dist/src/pf/tests/test_162_17_archive_apply_removal.py`

Fixtures build a real mini-project at `tmp_path` and point the resolver at it via
`monkeypatch.setenv("PROJECT_ROOT", ...)` (highest-priority source in `get_project_root`;
`CLAUDE_PROJECT_DIR` is deleted so it can't shadow). All assertions are on the
`{success, error?, message}` result object — no exceptions expected. Reality is read back
through `load_sprint(root)` (the shard-merging loader), so a story "removed" from the
in-memory index but left in its shard still counts as present.

Truthful reporting is pinned as a biconditional invariant (`_assert_report_is_truthful`):
the message may contain "removed from" **iff** the story is actually gone. This leaves Dev
free to either remove or stay silent for representations the spec doesn't cover.

**Failing (RED) — facet → test → current failure:**

| Facet | Test | Failure on HEAD |
|-------|------|-----------------|
| 1 standalone removal | `test_apply_removes_standalone_story` | `AssertionError: assert '162-99' not in ['162-99']` |
| 1 standalone truthfulness | `test_apply_report_truthful_for_standalone_story` | `report/reality mismatch: message='... and removed from current-sprint.yaml' claims_removal=True actually_removed=False live_ids=['162-99']` |
| 2 sharded removal | `test_apply_removes_story_from_sharded_index` | `AssertionError: assert '162-99' not in ['162-99', '162-98']` |
| 2 sharded truthfulness | `test_apply_report_truthful_on_sharded_index` | `report/reality mismatch: ... claims_removal=True actually_removed=False live_ids=['162-99', '162-98']` |
| 3 general truthfulness | `test_apply_report_truthful_for_toplevel_stories_list` | `report/reality mismatch: ... claims_removal=True actually_removed=False live_ids=['162-99']` |

**Passing preservation guards (must stay green):**
- `test_apply_still_removes_inline_epic_story` — the already-working `epics[].stories` path
  plus its truthful "removed from" claim.
- `test_without_apply_nothing_is_removed_and_nothing_is_claimed` — no `--apply` → story stays,
  message makes no removal claim.

**Notes for Dev:**
- The sharded case needs shard-aware removal: `archive.py` reads the index with raw
  `yaml.safe_load`, so `epics` are ID strings. `write_sprint` is shard-aware but only writes
  shards for entries that are *mappings* — string refs are passed through untouched. Removal
  must therefore reach the merged/shard representation (e.g. read via
  `read_sprint`/`load_sprint` instead of `yaml.safe_load`), not just filter the index.
- Sibling story `162-98` in the same shard must survive (asserted).
- Scoped run: `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_162_17_archive_apply_removal.py -q`

**Handoff:** To Dev for implementation (GREEN).

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/archive.py` — three targeted changes:
  1. Sprint data is now read via `read_sprint()` (shard-merging, ruamel) instead of raw
     `yaml.safe_load`, so on a sharded index `epics` arrive as mappings rather than ID
     strings. `write_sprint` is already shard-aware, so mutated epics round-trip back to
     their shard files (index keeps string refs). Read failures return
     `{"success": False, "error": ...}` — no throw. `import yaml` dropped (now unused).
  2. The `--apply` removal filters inline/sharded `epics[].stories` **and** the top-level
     `standalone_stories` and `stories` lists (keys only touched if present).
  3. A `removed` flag records whether any list actually shrank; the
     `" and removed from {sprint_file.name}"` suffix is appended only when it did —
     the false-success claim is gone.

**Tests:** 7/7 passing (GREEN) — `src/pf/tests/test_162_17_archive_apply_removal.py`
(5 previously-failing facets + 2 preservation guards).
Regression batch: 148 passed / 1 skipped across the archive, get_archive_path, yaml_io,
sharded-update, and finish-archive sibling suites.
`ruff check src/pf/sprint/archive.py` — clean.

**Branch:** feat/162-17-archive-apply-standalone-removal (pushed)

**Handoff:** To Reviewer (review phase)

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 7/7 scoped pass; 590 pass / 3 skip on related suites; RED verified (5 failing on origin/develop); ruff clean; 0 TODO/FIXME/skips | N/A — corroborated by my own independent run |
| 2 | reviewer-rule-checker [RULE] | Yes | clean | 0 violations across 22 instances / 4 rules (result objects, dist-not-symlink, path literals, scoped tests) | ACCEPTED — matches my own rule pass |
| 3 | reviewer-security [SEC] | Yes | findings | 4: `pr_number` newline→YAML injection (archive.py:108), unescaped `title` (archive.py:103), unvalidated string refs in `write_sprint` unlink path (yaml_io.py:418/434), ruamel round-trip alias-expansion (yaml_io.py:78) | 2 CONFIRMED but **outside the diff** (archive.py:100-111 unchanged from develop) → pre-existing, non-blocking; 1 CONFIRMED as defense-in-depth gap in `yaml_io` (pre-existing); alias-expansion DISMISSED — local operator-owned files, no privilege boundary |
| 4 | reviewer-test-analyzer [TEST] | Yes | findings | 4: top-level `stories` test vacuous for removal (test:157), no `dry_run + apply` test, no multi-list story test, no `write_sprint` failure test | 1 CONFIRMED (independently found the same gap); 3 ACCEPTED as legitimate non-blocking coverage gaps |
| 5 | reviewer-type-design [TYPE] | Yes | findings | 3: `isinstance(epic, dict)` at :79 vs `Mapping` at :131 asymmetry, `_without_story` returns plain `list` into a ruamel doc, `nonlocal removed` as implicit out-param + `write_sprint` not gated on `removed` | Asymmetry + plain-list CONFIRMED as Minor (no live impact — `CommentedMap` IS-A `dict`, `_canonicalize` rebuilds sequences, real-repo round-trip byte-identical); **write-not-gated-on-`removed` CONFIRMED as the best cheap mitigation** for my shard-deletion finding |
| 6 | reviewer-silent-failure-hunter (extra) | Yes | findings | 4: unguarded `write_sprint` after archive append (double-archive on retry), `AttributeError` not caught at :65, non-transactional shard writes, shard-load failure demoted to `warnings.warn` | CONFIRMED; the shard-load-failure item led me to the empirically reproduced shard-deletion finding below |

**All received: Yes** — 6 of 6 spawned specialists returned (5 enabled + 1 extra); none errored or timed out.

## Reviewer Assessment

**Verdict:** APPROVED

All three spec facets are genuinely fixed. Verified independently: 7/7 scoped tests pass,
5 of them verified failing when `archive.py` is reverted to `origin/develop` (RED confirmed
by me, not taken from Dev's summary). `ruff check` clean on both changed files. Working tree
clean. No Critical/High regression attributable to this diff.

**Data flow traced:** CLI `pf sprint archive <id> --apply` → `archive_story()` →
`get_story_by_id()` (loader, shard-merged) → `read_sprint(sprint_file)` (archive.py:64,
shard-merged CommentedMap) → archive entry appended (archive.py:110) → `_without_story()`
applied to `epics[].stories` + `standalone_stories` + `stories` (archive.py:130-136) →
`write_sprint()` (archive.py:140, shard-aware: mutated epic mappings round-trip back to
their `epic-*.yaml` shards, index keeps string refs) → `removed` gates the
`" and removed from ..."` suffix (archive.py:141).

**Facet verification (evidence, not summary):**
1. **standalone_stories** — archive.py:134-136 filters the key only when present.
   `test_apply_removes_standalone_story` asserts absence via `load_sprint(root)`.
2. **Sharded index — real removal, no shard wipe.** `test_apply_removes_story_from_sharded_index`
   asserts `162-99` gone **and** sibling `162-98` still present, and reality is read back
   through `load_sprint` (the shard-merging loader), so an index-only edit that left the
   shard untouched could not pass. Not vacuous.
3. **Truthful reporting** — `removed` (archive.py:120-128) is set from actual list shrinkage
   inside `_without_story`, shared by all three branches; the suffix is appended only when it
   flipped. `_assert_report_is_truthful` pins it as a biconditional (claim iff really gone),
   so a fix that removed nothing but stayed silent would pass while a false claim fails.
   I found no surviving false-claim path in the covered branches.

**Round-trip safety on the real layout (Dev's flagged concern #1 — DISPROVEN):** I copied this
repo's actual `sprint/*.yaml` (sharded index + 20 shards) and ran
`read_sprint` → `write_sprint`. Result: **byte-identical**, zero files changed, added, or
deleted, zero warnings. `read_sprint` does **not** re-index orphan shards —
`merge_epic_shards` only `warnings.warn(...)`s about unindexed shards and skips them
(`shard_merge.py:158-161`). Dev's Delivery Finding on this is factually wrong; the misleading
source is the stale `read_sprint` docstring (`yaml_io.py:124-126`), which claims it "appends
them". No corruption in any realistic layout.

**Findings**

| Severity | Issue | Location | Note |
|----------|-------|----------|------|
| Important (non-blocking, pre-existing) | An **unreadable** indexed epic shard (malformed YAML, empty file, or git conflict markers) is dropped by `merge_epic_shards` (`shard_merge.py:88-98`), then **deleted from disk** by `write_sprint`'s stale-shard sweep (`yaml_io.py:447-449`) and dropped from the index — while `archive_story` returns `success: True` with the "removed from current-sprint.yaml" message. | `archive.py:64` + `archive.py:140` | **Empirically reproduced** in three variants (malformed / empty / conflict-markered `epic-999.yaml`): file gone, success reported. **Not a defect this diff invents** — `read_sprint` + `write_sprint` is the established pattern in ~30 call sites, and `pf sprint story update` (`story_update.py:144,244`), `story_add.py:169`, `story_remove.py:72`, `epic_update.py:118` all carry the identical hazard today. Filed as a follow-up against `shard_merge`/`yaml_io`, not a gate on this bugfix. |
| Minor | `write_sprint()` is called unguarded **after** the archive entry has already been appended. `OSError` / `TypeError` / `ValueError` (from `_get_epic_ref` → `validate_shard_filename`) propagate out of `archive_story`, violating project rule 6 (result objects, don't throw). Retry then appends a **second** archive entry. Asymmetric: Dev newly wrapped the *read* (archive.py:63-66) but left the *write* bare. | `archive.py:140` | Pre-existing on develop; ~4-line fix. Recommend a `try/except` returning `{"success": False, "error": "Archived to X but failed to remove from sprint: ..."}` so the caller knows the archive entry landed. |
| Minor | `except (OSError, ValueError)` misses `AttributeError`: if `current-sprint.yaml`'s top level is a valid-YAML list or scalar, `_read_yaml_file` returns it (it only rejects `None`) and `merge_epic_shards` raises `AttributeError` on `data.get`. | `archive.py:65` | Pre-existing shape (develop raised at the `sprint_data.get` on line 78). Cheapest real fix is a `Mapping` check in `_read_yaml_file`. |
| Minor | Dev's Delivery Finding "read_sprint also appends unindexed epic-*.yaml shards … re-indexes orphan shards as a side effect" is incorrect (see above). The `read_sprint` docstring that says so is stale. | `yaml_io.py:124-126` | Correct the docstring so future agents don't reason from a false premise. |
| Minor | `_without_story` returns a plain `list`, replacing the `CommentedSeq` in a ruamel document. | `archive.py:122-128` | Cosmetically benign — `canonical_dump` rebuilds sequences anyway, and the real-repo round-trip was byte-identical. No action. |
| Minor (test gap) [TEST] | Top-level `stories` list: only the truthfulness invariant is pinned, not removal — yet the implementation *does* remove from it. Because the invariant is a biconditional, deleting the `stories` key from the removal loop leaves `claimed=False, actually_removed=False` and the test still passes. Effectively vacuous for removal. Found independently by me and by `reviewer-test-analyzer`. | `test_162_17_archive_apply_removal.py:152-160` | Add `assert STORY_ID not in _live_story_ids(...)` to the existing test. |
| Minor (test gap) [TEST] | No test for `dry_run=True` + `apply=True` together: the `dry_run` early return (`archive.py:87-94`) precedes the apply block, so `--apply` is a silent no-op. Both flags are independently exposed by the CLI (`archive.py:167-168`) and the intended precedence is undefined. | `archive.py:87-94` | Pin the precedence (dry_run wins, nothing mutated, no removal claim). |
| Minor (test gap) [TEST] | No test for a story present in **multiple** representations at once (e.g. `standalone_stories` **and** an inline epic). The implementation handles it correctly (`_without_story` runs over every list, `removed` needs only one hit), but it is unpinned. | `archive.py:130-136` | Add a multi-list fixture asserting both copies are gone and siblings intact. |
| Minor (test gap) [TEST] | No test for the `write_sprint` failure path (pairs with the unguarded-write finding above). | `archive.py:140` | Monkeypatch `write_sprint` to raise `OSError` and assert a `{success: False}` result rather than a propagated exception. |
| Verified good | Untested positive side effect: the `epic_id` lookup (`archive.py:78-84`) also runs on merged data now, so on a sharded index the archive entry's `epic:` field is populated where it was previously always empty. | `archive.py:78-84` | Worth a pin; not required. |
| Minor [TYPE] | `write_sprint` is called unconditionally (`archive.py:140`) even when `removed` is False — every `--apply` atomically rewrites the index and all shards even on a pure no-op. Gating the write on `removed` is the cheapest mitigation for the shard-deletion finding above: a no-op archive would then touch nothing. | `archive.py:140` | Recommended follow-up; combine with the `try/except` fix. |
| Minor [TYPE] | Guard asymmetry: `isinstance(epic, dict)` at `archive.py:79` (epic-id lookup) vs `isinstance(epic, Mapping)` at `archive.py:131` (removal). Identical behaviour today (`CommentedMap` IS-A `dict`), but the same list is iterated with two different type guards. | `archive.py:79` vs `:131` | Use `Mapping` in both. |
| Minor [SEC] — pre-existing, outside the diff | `pr_number` (a raw CLI arg) and `title` are f-string-interpolated into the archive YAML with no escaping (`archive.py:101-108`), so a newline injects arbitrary archive entries and a `"` in a title breaks the quoted scalar. | `archive.py:103`, `archive.py:108` | **Unchanged by this diff** — byte-identical to develop. Local CLI, operator-supplied arg, no privilege boundary crossed → not a gate on this story. Real bug worth a follow-up: build the entry with a YAML serializer instead of string concatenation. |
| Minor [SEC] — pre-existing | Defense-in-depth gap: string epic refs read from the on-disk index are used to build `.unlink()` targets (`yaml_io.py:418-420`, `:434`, `:447-449`) without passing through `validate_shard_filename`, unlike the new-epic write path. | `yaml_io.py:418` | Apply the validator to passthrough refs too. Fold into the shard-safety follow-up. |
| Dismissed [SEC] | ruamel round-trip mode resolves YAML aliases without an expansion-depth limit (billion-laughs). | `yaml_io.py:79-86` | DISMISSED — round-trip mode registers no Python-object constructors (no RCE), and the inputs are the operator's own repo files. No threat model. |
| Verified good [RULE] | `reviewer-rule-checker` found 0 violations across 22 instances / 4 applicable rules; independently confirmed. All eight `archive_story` exit points return `{success, ...}`. | `archive.py:38-149` | — |
| Verified good | Test hygiene is sound: `tmp_path` mini-project, `PROJECT_ROOT` env with `CLAUDE_PROJECT_DIR` deleted (no `monkeypatch.chdir`), reality read back through the shard-merging `load_sprint`, sibling-survival assertion, biconditional truthfulness invariant, all assertions on the result object (no exceptions expected). No vacuous assertions found. | test file | — |

**Deviation audit:** `## Design Deviations` is empty; the diff matches the SM fix shape
(cover `standalone_stories`, cover the sharded case with real removal, report truthfully) with
no undocumented scope creep. Top-level `stories` coverage is an addition TEA explicitly invited
as free. **ACCEPTED — no deviations.**

**Project rules:** result objects used for all new branches (read failure returns
`{success, error}`); Python so the `.js` rule is N/A; edits are in `pennyfarthing-dist/`, not
symlinks; scoped test runs only (no full suite); `ruff` clean.

**Handoff:** To SM for finish-story

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-11T11:50:26Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-11T11:28:24Z | 2026-08-11T11:30:32Z | 2m 8s |
| red | 2026-08-11T11:30:32Z | 2026-08-11T11:33:30Z | 2m 58s |
| green | 2026-08-11T11:33:30Z | 2026-08-11T11:37:06Z | 3m 36s |
| review | 2026-08-11T11:37:06Z | 2026-08-11T11:50:26Z | 13m 20s |
| finish | 2026-08-11T11:50:26Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Question** (non-blocking): the spec names `standalone_stories` and the sharded index but is silent on the third representation, the top-level `stories:` list, which `get_all_stories()` also reads. Tests pin only the truthful-reporting invariant there, not removal. Affects `pennyfarthing-dist/src/pf/sprint/archive.py` (Dev may cover it for free by removing from all three lists). *Found by TEA during test design.*
- **Improvement** (non-blocking): `archive_story` resolves its root via `get_project_root()` with no `project_root` parameter, unlike `get_archive_path`/`load_sprint`. Testing requires the `PROJECT_ROOT` env override. Affects `pennyfarthing-dist/src/pf/sprint/archive.py` (add an optional `project_root` kwarg for symmetry). *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): `archive_story` builds `sprint_file` as
  `root / "sprint" / "current-sprint.yaml"` directly instead of going through
  `resolve_sprint_context()`, so `--apply` writes the default sprint even when a
  multi-sprint registry selects another context. Affects
  `pennyfarthing-dist/src/pf/sprint/archive.py` (resolve the sprint path the way
  `load_sprint` does). *Found by Dev during implementation.*
- **Improvement** (non-blocking): `read_sprint()` also appends unindexed `epic-*.yaml`
  shards it discovers on disk, so an `--apply` write now re-indexes orphan shards as a
  side effect. Benign (matches how the rest of the CLI reads sprint data) but worth a
  deliberate decision. Affects `pennyfarthing-dist/src/pf/sprint/yaml_io.py`.
  *Found by Dev during implementation.*
- **Improvement** (non-blocking): TEA's `project_root` kwarg suggestion for `archive_story`
  is still open — deferred as out of scope for this bug fix. *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (non-blocking): an *unreadable* indexed epic shard (malformed YAML, empty file, or git conflict markers) is silently dropped by `merge_epic_shards` and then **deleted from disk** by `write_sprint`'s stale-shard sweep, while the caller reports success. Reproduced empirically in three variants. Affects `pennyfarthing-dist/src/pf/sprint/shard_merge.py` (surface shard-load failures structurally instead of `warnings.warn`) and `pennyfarthing-dist/src/pf/sprint/yaml_io.py` (`write_sprint` must not unlink a shard it never successfully read). Framework-wide: also fires from `story_update.py:244`, `story_add.py:169`, `story_remove.py:72`, `epic_update.py:118`. Warrants its own story. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `write_sprint` is called unguarded after the archive entry is already appended, so `OSError`/`TypeError`/`ValueError` escape `archive_story` (violates result-object rule) and a retry double-appends the archive entry. Affects `pennyfarthing-dist/src/pf/sprint/archive.py:140` (wrap and return a distinct error naming the already-written archive entry). *Found by Reviewer during code review.*
- **Conflict** (non-blocking): the `read_sprint` docstring claims it "appends" unindexed shards; `merge_epic_shards` only warns and skips them. The stale docstring caused Dev to file an inaccurate orphan-re-index finding. Affects `pennyfarthing-dist/src/pf/sprint/yaml_io.py:124-126`. *Found by Reviewer during code review.*
- **Gap** (non-blocking): `_read_yaml_file` rejects only `None`, so a top-level list/scalar sprint file yields an `AttributeError` from `merge_epic_shards` that `archive.py`'s `except (OSError, ValueError)` does not catch. Affects `pennyfarthing-dist/src/pf/sprint/yaml_io.py` (add a `Mapping` check). *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** 4 findings (1 Gap, 0 Conflict, 1 Question, 2 Improvement)
**Blocking:** None

- **Question:** the spec names `standalone_stories` and the sharded index but is silent on the third representation, the top-level `stories:` list, which `get_all_stories()` also reads. Tests pin only the truthful-reporting invariant there, not removal. Affects `pennyfarthing-dist/src/pf/sprint/archive.py`.
- **Improvement:** `archive_story` resolves its root via `get_project_root()` with no `project_root` parameter, unlike `get_archive_path`/`load_sprint`. Testing requires the `PROJECT_ROOT` env override. Affects `pennyfarthing-dist/src/pf/sprint/archive.py`.
- **Improvement:** `write_sprint` is called unguarded after the archive entry is already appended, so `OSError`/`TypeError`/`ValueError` escape `archive_story` (violates result-object rule) and a retry double-appends the archive entry. Affects `pennyfarthing-dist/src/pf/sprint/archive.py:140`.
- **Gap:** `_read_yaml_file` rejects only `None`, so a top-level list/scalar sprint file yields an `AttributeError` from `merge_epic_shards` that `archive.py`'s `except (OSError, ValueError)` does not catch. Affects `pennyfarthing-dist/src/pf/sprint/yaml_io.py`.

### Downstream Effects

- **`pennyfarthing-dist/src/pf/sprint`** — 4 findings

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->