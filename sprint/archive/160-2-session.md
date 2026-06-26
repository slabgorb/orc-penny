---
story_id: "160-2"
jira_key: "none"
epic: "160"
workflow: "tdd"
---
# Story 160-2: validator._validate_depends_on only validates epics[].stories, not standalone_stories/top-level — dangling deps there pass (from 156-3 review)

## Story Details
- **ID:** 160-2
- **Jira Key:** none
- **Workflow:** tdd
- **Stack Parent:** none
- **Type:** bug
- **Points:** 2
- **Repo:** pennyfarthing

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-10T19:32:43Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-10T19:22:52.145381+00:00 | 2026-06-10T19:24:04Z | 1m 11s |
| red | 2026-06-10T19:24:04Z | 2026-06-10T19:27:05Z | 3m 1s |
| green | 2026-06-10T19:27:05Z | 2026-06-10T19:29:15Z | 2m 10s |
| review | 2026-06-10T19:29:15Z | 2026-06-10T19:32:43Z | 3m 28s |
| finish | 2026-06-10T19:32:43Z | - | - |

## Sm Assessment

**Story:** 160-2 — `_validate_depends_on` only validates `epics[].stories`; stories under `standalone_stories` or the top-level `stories` list are never checked, so dangling depends_on references there pass silently. From 156-3 review.

**Scope:** Two-sided gap in pennyfarthing-dist/src/pf/sprint/validator.py: (a) depends_on fields on standalone/top-level stories are never validated, and (b) the known-ids set used to resolve references may also omit those locations, so a valid dep pointing AT a standalone story could false-fail (verify actual behavior in RED). Fix must cover all three story locations for both the walk and the resolution set.

**Acceptance criteria:**
1. A dangling depends_on on a story in `standalone_stories` fails validation.
2. A dangling depends_on on a story in the top-level `stories` list fails validation.
3. depends_on references pointing TO standalone/top-level stories (from any location) resolve correctly.
4. The archived-story allowance from 160-8 (deps on completed/archived stories don't fail whole-sprint validation) is preserved for all story locations.
5. Existing valid sprint fixtures pass (no regression).

**Technical approach:** Single story-iteration helper covering epics[].stories + standalone_stories + top-level stories (one truth), used for both the known-ids set and the depends_on walk. TEA writes failing tests for each location; mind that 160-8 just changed this area — read its archived-allowance logic before designing.

**Routing:** tdd (phased) — TEA (red) → Dev (green) → Reviewer (review). 2 points, repo pennyfarthing, branch `feat/160-2-depends-on-standalone-stories` off develop.

## Context Summary

In `pennyfarthing-dist/src/pf/sprint/validator.py`, the `_validate_depends_on` function only walks `epics[].stories` when checking that `depends_on` references resolve. Stories in `standalone_stories` or the top-level `stories` list are never validated, allowing dangling `depends_on` references to pass silently.

**Key Requirements:**
- depends_on validation must cover all story locations (epic stories, standalone_stories, top-level stories)
- The known-ids set used for resolution must likewise include all locations
- Must respect the archived-story allowance from story 160-8

**Finding Source:** Review deferred from story 156-3

## Delivery Findings

No upstream findings

## Design Deviations

No design deviations recorded

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_160_2_depends_on_standalone_stories.py` — 13 tests across 5 ACs

**Tests Written:** 13 tests, 7 RED (failing as designed), 6 PASS (anti-regression / vacuous-pass guards). Existing `test_sprint_validator.py`, `test_epic_shard_validation.py`, `test_160_8_archived_depends_on.py` all pass (114 passed total in targeted run).
**Status:** RED — ready for Dev.

## Empirical Gap Confirmation

Both sides of the claimed gap are REAL (confirmed in `pennyfarthing-dist/src/pf/sprint/validator.py`):
- `validate_full_sprint` (L463–481) collects `all_story_ids` ONLY from `epics[].stories`. `standalone_stories` and top-level `stories` are omitted from the known-ids set → side (b) confirmed.
- `_validate_depends_on` (L553–575) walks ONLY `epics[].stories` → side (a) confirmed.
- **Extra finding:** the `if all_story_ids:` guard at L480 short-circuits depends_on validation entirely when there are no *epic* stories — so a standalone-only or top-level-only sprint never runs the walk at all. Two tests (`test_standalone_only_sprint_dangling_dep_fails`, `test_top_level_only_sprint_dangling_dep_fails`) pin this. The fix must not gate the walk on epic stories alone.
- A canonical helper already exists: `pf.sprint.loader.get_all_stories()` (loader.py L239–257) iterates epics + standalone_stories + top-level stories. It calls `load_sprint()` (reads from disk) so it can't be reused as-is on an in-memory `data` dict — Dev should extract/parallel a pure `data -> stories` iterator and use it for BOTH the known-ids set and the walk (SM's "one truth").

## Tea Handoff

**Test file:** `pennyfarthing-dist/src/pf/tests/test_160_2_depends_on_standalone_stories.py`

**RED tests (must turn GREEN):**
- AC1: `TestDanglingDepOnStandaloneStoryFails::test_standalone_story_dangling_dep_fails`, `::test_standalone_only_sprint_dangling_dep_fails`
- AC2: `TestDanglingDepOnTopLevelStoryFails::test_top_level_story_dangling_dep_fails`, `::test_top_level_only_sprint_dangling_dep_fails`
- AC3: `TestDepsPointingAtStandaloneOrTopLevelResolve::test_epic_story_dep_on_standalone_story_resolves`, `::test_epic_story_dep_on_top_level_story_resolves`
- AC4: `TestArchivedAllowancePreservedForAllLocations::test_standalone_dep_on_neither_active_nor_archived_still_fails`

**Already-GREEN anti-regression guards (must stay GREEN):**
- AC3: `::test_standalone_story_dep_on_epic_story_resolves`, `::test_standalone_dep_on_top_level_story_resolves` (currently vacuous — pass only because the source story is never walked; will exercise the new walk once added)
- AC4: `::test_standalone_dep_on_archived_story_passes`, `::test_top_level_dep_on_archived_story_passes`
- AC5: `TestNoRegression::test_valid_multi_location_sprint_passes`, `::test_no_depends_on_anywhere_passes`

**Designed interface for Dev (exact expectations the tests assert):**
- `validate_full_sprint(data)` is the public entry point under test (signature unchanged).
- The depends_on WALK must cover stories from all three locations: `data["epics"][*]["stories"]` (dict epics only — string epic refs skipped), `data["standalone_stories"]`, `data["stories"]`.
- The known-ids RESOLUTION SET must include story IDs from all three locations, so a dep pointing AT a standalone/top-level story resolves with no error.
- depends_on validation must run even when there are NO epic stories (drop/relax the `if all_story_ids:` short-circuit so standalone-only / top-level-only sprints are walked).
- A dangling dep (target in neither active-sprint-any-location nor archive) must produce a hard `ValidationError`: severity `ValidationSeverity.ERROR`, `path == f"{sid}.depends_on"`, and `message` containing the substring `"non-existent"` AND the offending dep id (tests assert both substrings).
- The 160-8 archived allowance must apply to ALL locations: a dep resolving to a story in `sprint/archive/` (`_get_archived_story_ids()`) is satisfied — no error — regardless of which location the depending story lives in.
- Story id coercion stays `str(...)` as today (tests use string ids; mixed-type coercion already handled by existing code).
- No new public API required; the SM-suggested single story-iteration helper is internal.

**Failure snippet (representative, current behavior):**
```
test_standalone_dep_on_neither_active_nor_archived_still_fails:
  AssertionError: a standalone dep that is neither active nor archived must still fail, got errors: []
  assert not True  (ValidationResult(valid=True, errors=[]))

test_epic_story_dep_on_standalone_story_resolves:
  ValidationError(message="depends_on '160-2' references non-existent story...",
                  path='160-1.depends_on', severity=ERROR)
  → valid dep on a standalone story false-flagged as non-existent
```

**Handoff:** To Dev for GREEN.

## Dev Handoff

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/validator.py`
  - `validate_full_sprint` (L462–483): known-ids set now built from `_iter_all_stories(data)` instead of epic stories only; dropped the `if all_story_ids:` guard so `_validate_depends_on` always runs (standalone-only / top-level-only sprints).
  - New internal helper `_iter_all_stories(data)` (L486–501): pure `data -> stories` iterator over `epics[].stories` (dict epics only — string shard refs skipped), `standalone_stories`, and top-level `stories`. One truth for both the resolution set and the walk.
  - `_validate_depends_on` (L569–590): walk now iterates `_iter_all_stories(data)` instead of `data["epics"][*]["stories"]`; archived allowance (`_get_archived_story_ids`) unchanged, now applies to all locations.

**Approach:** Per SM/TEA interface — extracted single in-memory iteration helper (parallels `loader.get_all_stories()` but takes the `data` dict, no disk read) and used it for both the known-ids RESOLUTION SET and the depends_on WALK. Removed the epic-stories short-circuit guard.

**Tests:** 121 passed, 2 skipped (GREEN) — `test_160_2_depends_on_standalone_stories.py` (7 RED → GREEN, 6 guards stay GREEN) + `test_sprint_validator.py` + `test_epic_shard_validation.py` + `test_160_8_archived_depends_on.py`.

**Lint/Format:** `ruff check validator.py` passes. `ruff format --check` flags one pre-existing reformat in `is_epic_shard_document` (L513–519, not my lines) — left untouched per "fix your own lines only". My added lines are format-clean.

**Branch:** `feat/160-2-depends-on-standalone-stories`
**Commit:** `3e8cd6f4c` (GPG-signed, verified good)

**Design Deviations:** None.

**Handoff:** To Reviewer for review.

### Dev Handoff — Rework (post CHANGES-REQUESTED)

**Addresses Reviewer [HIGH]:** the original refactor moved `all_story_ids` population to a single loop after the epic loop, leaving the set empty for every `validate_epic` call and silently killing cross-epic duplicate story-ID detection (AC5 regression).

**Files Changed (rework commit `a426e39fd`):**
- `pennyfarthing-dist/src/pf/sprint/validator.py` — `validate_full_sprint` (L462–485): restored INCREMENTAL epic-story ID population inside the `for epic in data["epics"]` loop (right after each `validate_epic` call) so epic N sees epics 0..N-1's IDs and fires the duplicate error (L319-323). Standalone + top-level IDs are unioned in AFTER the loop (before `_validate_depends_on`) so deps pointing at them still resolve (160-2) without each epic flagging its own stories. The depends_on WALK still uses `_iter_all_stories(data)` (unchanged) so all three locations are validated; the `if all_story_ids:` guard stays dropped.
- `pennyfarthing-dist/src/pf/tests/test_sprint_validator.py` — added `TestFullSprintValidation::test_duplicate_story_id_across_epics_fails_via_full_sprint`: drives two epics sharing story `63-1` through `validate_full_sprint` (the existing `test_duplicate_story_ids_across_epics_fails` calls `validate_epic` directly with a pre-seeded set and never exercised this wiring).

**Regression test verified both ways:** new test FAILS against the buggy separate-loop variant, PASSES against the fix (confirmed empirically by temporarily reverting the validator).

**Tests:** 122 passed, 2 skipped (GREEN) — same targeted set (`test_160_2_*` + `test_sprint_validator.py` + `test_epic_shard_validation.py` + `test_160_8_archived_depends_on.py`).

**Lint/Format:** `ruff check` clean on both changed files. Test file is format-clean. validator.py still shows the one pre-existing `is_epic_shard_document` reformat (L523–528, not my lines) — left untouched.

**Commit:** `a426e39fd` (GPG-signed, verified good).

**Design Deviations:** None.

**Handoff:** To Reviewer for re-review.

## Subagent Results

Inline peloton mode: specialist analyses performed directly by the Reviewer (preflight + adversarial correctness/regression review), not spawned as background subagents.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight (inline) | Yes | clean | 121 passed/2 skipped targeted; `ruff check validator.py` clean | confirmed clean |
| 2 | reviewer-edge-hunter (inline) | Yes | finding | Cross-epic duplicate story-ID detection dead in `validate_full_sprint` (AC5 regression); empty/standalone-only sprints safe after guard drop | confirmed [HIGH] |
| 3 | reviewer-security (inline) | Yes | clean | No untrusted input, no auth/injection surface; pure in-memory dict validation of local sprint YAML | N/A |
| 4 | reviewer-silent-failure-hunter (inline) | Yes | clean | No swallowed errors; archive resolver's broad `except` is pre-existing and intentional (missing archive → empty set) | N/A |
| 5 | reviewer-test-analyzer (inline) | Yes | finding | Cross-epic-dup unit test bypasses `validate_full_sprint`; integration regression test absent | folded into [HIGH] |

All received: Yes

## Reviewer Assessment

**Verdict:** CHANGES-REQUESTED

**Story 160-2 goal (depends_on across all 3 locations) is correctly and cleanly implemented** — but the refactor of `validate_full_sprint` silently killed an *adjacent* validation: cross-epic duplicate story-ID detection. This violates AC5 ("no regression") and must be fixed before merge.

### Blocking findings

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | Cross-epic duplicate story-ID detection is now dead. The old code populated `all_story_ids` **incrementally inside** the `for epic in data["epics"]` loop (the deleted `if "stories" in epic:` block), so `validate_epic(epic, all_story_ids, idx)` for epic N saw epics 0..N-1's IDs and fired the "Duplicate story ID - already exists in another epic" error (validator.py L319-323). The diff moved population to a **separate loop after all `validate_epic` calls** (L474-477), so `all_story_ids` is empty for every `validate_epic` call. Two epics sharing a story ID now pass `validate_full_sprint` silently. | `validator.py` L462-477 | Restore incremental population of epic-story IDs **inside** the epic loop (before/around the `validate_epic` call so each epic sees prior epics' IDs), then union in `standalone_stories` + top-level `stories` afterward. Do NOT seed the full `_iter_all_stories` set before the epic loop — that would make each epic flag its own stories as cross-epic dupes. Add an integration regression test that drives the dup through `validate_full_sprint` (see note below). |

**Verification evidence (regression confirmed empirically):**
- New code: two epics both containing story `160-1` → `validate_full_sprint` returns `valid=True`, zero errors.
- Old-style incremental population (reproduced via `validate_epic` in a loop): returns `valid=False`, error `"Duplicate story ID '160-1' - already exists in another epic"`.
- Empty-sprint and standalone/top-level-only sprints behave correctly after the guard drop (no spurious errors) — that part of the change is sound.

**Why the suite stayed green (test gap):** `test_duplicate_story_ids_across_epics_fails` (test_sprint_validator.py L400) calls `validate_epic(epic, {"63-1"})` **directly** with a pre-seeded set — it bypasses `validate_full_sprint` entirely, so it never exercises the integration wiring that broke. The unit test gives false confidence. The fix should add a `validate_full_sprint`-level regression test for cross-epic dupes.

### Confirmed-good (spec fidelity — story 160-2 itself)
- **AC1/AC2 (dangling deps in standalone + top-level fail):** verified — walk now iterates `_iter_all_stories(data)` (L572); all four dangling-dep tests pass, including standalone-only / top-level-only sprints after the `if all_story_ids:` guard drop.
- **AC3 (cross-location resolution):** verified — known-ids set spans all locations (L474-477); deps pointing at standalone/top-level stories resolve, both directions.
- **AC4 (160-8 archived allowance preserved everywhere):** verified — archive resolution (`_get_archived_story_ids`) unchanged and now reached from every location; boundary test (archived ≠ excuse for truly-gone) passes.
- **`_iter_all_stories` correctness:** dict-vs-string epic handling correct (`isinstance(epic, dict)` skips string shard refs, L496); missing keys safe via `.get(..., [])`/`.get("epics", [])`; used consistently for BOTH the known-ids set (L474) and the walk (L572) — true "one truth." No remaining direct `epics[].stories` iteration in the depends_on path.
- **Guard drop (focus #3):** intended and safe — empty sprint produces no spurious errors (verified); only behavior change is that standalone/top-level-only sprints now get walked, which is the point.

### Test quality
13 tests are meaningful and pin real behavior (no vacuous assertions); the two previously-"vacuous-pass" AC3 guards now genuinely exercise the new walk. The gap is **absence**, not vacuity: no integration-level cross-epic-duplicate test guarding the refactored `validate_full_sprint` wiring (see blocking finding).

### Security `[SEC]`
- `[SEC]` No security surface. `validate_full_sprint` operates on an in-memory dict parsed from local, trusted sprint YAML — no untrusted/network input, no auth boundary, no injection, no path traversal (archive lookup uses `get_project_root()` with no user-controlled paths). Clean.

### Deferred / non-blocking
- *(none)* — `ruff format --check` reformat flagged by Dev in `is_epic_shard_document` (L513-519) is genuinely pre-existing and outside this diff; correctly left untouched.

### Verification evidence (mechanical)
- Targeted suite: `test_160_2_depends_on_standalone_stories.py` + `test_sprint_validator.py` + `test_epic_shard_validation.py` + `test_160_8_archived_depends_on.py` → **121 passed, 2 skipped** (full pytest deliberately avoided — branch-switch hazard).
- `ruff check validator.py` → All checks passed.

### Deviation audit
Dev recorded "Design Deviations: None." The cross-epic regression was an **undocumented** deviation (unintended side effect of the refactor), now logged below.

**Handoff:** Back to Dev (GREEN) to restore cross-epic duplicate detection + add a `validate_full_sprint`-level regression test. Story 160-2's own ACs are met; only the adjacent regression blocks.

### Reviewer (audit)
- **Undocumented deviation:** refactor of `validate_full_sprint` known-ids population dropped incremental in-loop collection, disabling cross-epic duplicate story-ID detection. Not noted in Dev Handoff.

---

## Reviewer Verification (rework — commit a426e39fd)

**Verdict:** APPROVED — blocking finding resolved, no new adjacency broken.

The rework matches the prescribed fix exactly: incremental epic-story ID population restored **inside** the epic loop (right after each `validate_epic` call, so epic N sees epics 0..N-1's IDs); standalone + top-level IDs unioned **after** the loop (so deps resolve without each epic flagging its own stories as dupes); depends_on walk still uses `_iter_all_stories(data)`; `if all_story_ids:` guard stays dropped.

**Empirical verification (all via `validate_full_sprint`):**
- **Cross-epic dup (the regression):** two epics sharing `160-1` → `valid=False`, "Duplicate story ID ... already exists in another epic" fires. **Resolved.**
- **AC3 (epic→standalone dep):** resolves, no false "non-existent". Intact.
- **AC1 (standalone-only dangling dep):** still `valid=False` with "non-existent". Intact.
- **AC5 (valid multi-location sprint):** `valid=True`, zero errors — no false self-duplicate from the unioned standalone/top-level IDs. Intact.

**Test gap closed:** new `TestFullSprintValidation::test_duplicate_story_id_across_epics_fails_via_full_sprint` drives two same-ID epics through `validate_full_sprint` (not the bypassing `validate_epic` unit path). Confirmed it exercises the previously-broken wiring.

**Mechanical evidence:**
- Targeted set (`test_160_2_*` + `test_sprint_validator.py` + `test_epic_shard_validation.py` + `test_160_8_archived_depends_on.py`): **122 passed, 2 skipped** (+1 from the new regression test; full pytest avoided — branch-switch hazard).
- `ruff check validator.py`: All checks passed.

**No new adjacency broken:** the standalone/top-level union is now order-independent of `validate_epic` (those locations aren't subject to the cross-epic dup check, by design), and the depends_on resolution set is identical in content to the pre-rework version. Clean.

**Status:** APPROVED for merge. No further rework required.

## Delivery Findings

### Reviewer (code review)
- **Gap** (blocking): cross-epic duplicate story-ID detection regressed in `validate_full_sprint`. Affects `pennyfarthing-dist/src/pf/sprint/validator.py` (restore incremental epic-story ID population inside the epic loop; add integration regression test). Existing unit test bypasses `validate_full_sprint` so the suite is falsely green. *Found by Reviewer during code review.*