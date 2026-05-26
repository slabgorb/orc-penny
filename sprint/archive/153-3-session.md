---
story_id: "153-3"
jira_key: "PENDING"
epic: "153"
workflow: "tdd"
---
# Story 153-3: Add pf sprint story move and --epic flag; document full story lifecycle CLI surface

## Story Details
- **ID:** 153-3
- **Jira Key:** PENDING (epic 153 has no Jira key assigned)
- **Workflow:** tdd
- **Stack Parent:** none
- **Points:** 5

## Epic Context
**Epic 153:** Framework reliability fixes from downstream reports

Three independent framework bugs surfaced while using pennyfarthing in external projects (oq-1, oq-2):
1. wrong session-file path (153-1, done)
2. stray branches on main-only orchestrators (153-2, done)
3. missing CLI story-move operation (this story)

## Story Description

Add the missing `pf sprint story move` CLI command and `--epic` flag to the story CLI surface. This enables full story lifecycle management within the CLI, bridging a gap discovered in downstream projects that need to move stories between epics programmatically.

Currently, stories can only be moved via direct YAML editing. The story CLI has add/remove/update/finish operations but lacks move. The `--epic` flag on `pf sprint story add` would enable callers to specify target epic at creation time.

## Technical Approach

1. **Implement `pf sprint story move <story-id> --to-epic <epic-id>`:**
   - Read story from source epic shard file (epic-N.yaml)
   - Validate target epic exists
   - Remove story from source epic's stories array
   - Add story to target epic's stories array
   - Commit both shard updates atomically

2. **Add `--epic` flag to `pf sprint story add`:**
   - Parse optional `--epic` from CLI args
   - Default to "create new epic" behavior if omitted
   - If provided, append to existing epic's stories array

3. **Document full story lifecycle in CLI help:**
   - Update help text for `pf sprint story` to show all operations
   - Add examples for add/move/remove/update/finish flow
   - Link to workflow documentation (red → green → review → finish ceremony)

4. **Implementation location:**
   - Edit `pennyfarthing-dist/src/pf/commands/sprint_story.py`
   - Reuse shard-file logic from `pf sprint story remove` and `pf sprint story update`
   - Add validation similar to `story remove` (story must exist in epic)

## Acceptance Criteria

- `pf sprint story move <id> --to-epic <epic-id>` command exists and is usable
- Moving a story from epic A to epic B removes it from A's shard and adds it to B's shard
- `pf sprint story add <epic-id> <title> <points> --epic <override>` allows overriding the default epic
- Help text for `pf sprint story` documents all available operations (add/move/remove/update/finish)
- Moving non-existent story returns clear error message listing candidate story IDs
- Moving to non-existent epic returns clear error message listing available epic IDs
- All new code is tested (unit tests for move logic, integration test for shard mutations)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-05-26T15:45:31Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-05-26T14:57:29Z | 2026-05-26T14:59:19Z | 1m 50s |
| red | 2026-05-26T14:59:19Z | 2026-05-26T15:10:17Z | 10m 58s |
| green | 2026-05-26T15:10:17Z | 2026-05-26T15:33:55Z | 23m 38s |
| spec-check | 2026-05-26T15:33:55Z | 2026-05-26T15:35:34Z | 1m 39s |
| verify | 2026-05-26T15:35:34Z | 2026-05-26T15:39:09Z | 3m 35s |
| review | 2026-05-26T15:39:09Z | 2026-05-26T15:44:08Z | 4m 59s |
| spec-reconcile | 2026-05-26T15:44:08Z | 2026-05-26T15:45:31Z | 1m 23s |
| finish | 2026-05-26T15:45:31Z | - | - |

> **Session-recovery note (Dev/Ponder):** This session file was overwritten by a
> `testing-runner` subagent that used bash to clobber it with a raw test summary
> (a test runner has no business writing the session). Reconstructed from context.
> See `## Dev Assessment` → Incident for the full account.

## SM Assessment

Story 153-3 is well-scoped and ready for the RED phase. Setup complete:

- **Session created** with full context: epic background, technical approach, and 7 acceptance criteria.
- **Branch created:** `feat/153-3-sprint-story-move-epic-flag-cli-lifecycle` in `pennyfarthing/` (gitflow → develop).
- **Scope is clear:** add `pf sprint story move --to-epic`, add `--epic` flag to `story add`, document the CLI lifecycle. All work lands in the sprint story CLI, reusing existing shard-mutation logic from `remove`/`update`.
- **No blockers, no stack parent.** Jira key is PENDING (epic 153 is local-only per the kanban model — expected, not a gap).

**For Igor (TEA):** Focus RED-phase tests on shard-file mutations — moving a story must remove it from the source epic shard *and* add it to the target shard atomically. The two error-message ACs (non-existent story lists candidate IDs; non-existent epic lists available epic IDs) deserve explicit failing tests. Watch the sharded-YAML loader: code reading raw `current-sprint.yaml` misses shard stories, so tests must exercise the `load_sprint()`/`write_sprint()` path.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Net-new CLI command (`story move`) + new option (`story add --epic`) — both are logic-bearing surfaces, not a chore bypass.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_153_3_story_move_and_epic_flag.py` — 17 tests covering all 7 ACs.

**Tests Written:** 17 tests covering 7 ACs.
**Status:** RED (17 failing — verified by testing-runner, twice).

### AC Coverage

| AC | Test(s) | Status (at RED) |
|----|---------|-----------------|
| AC1 move command exists/usable | `test_move_is_registered_on_story_group`, `test_cli_move_persists_to_both_shards` | failing (No such command 'move') |
| AC2 removes from A, adds to B | `test_move_removes_from_source_shard`, `test_move_adds_to_target_shard`, `test_move_preserves_story_content` | failing (module missing) |
| AC3 `add --epic` override | `test_add_epic_flag_routes_story_to_named_epic` | failing (No such option --epic) |
| AC4 help documents lifecycle | `test_help_lists_all_lifecycle_operations` | failing (assertion: 'move' absent) |
| AC5 unknown story → candidate ids | `test_move_unknown_story_returns_failure_with_candidates`, `test_cli_move_unknown_story_exits_nonzero_with_candidates` | failing (module missing) |
| AC6 unknown epic → available ids | `test_move_unknown_epic_returns_failure_with_available`, `test_cli_move_unknown_epic_exits_nonzero_with_available`, `test_move_unknown_epic_does_not_mutate_source` | failing (module missing) |
| AC7 unit + shard-mutation tests | full file; `test_story_move_uses_shard_aware_io` (anti-regression), `test_move_dry_run_does_not_mutate`, sibling-isolation tests | failing (module missing) |

**Rule coverage (lang-review / 153-4 precedent):** Shard-aware IO contract pinned (`test_story_move_uses_shard_aware_io`) — `move_story` must use `read_sprint`/`write_sprint`, never the raw `_read_yaml_file`/`_write_yaml_file` helpers (the exact 153-4 failure mode). Jira-key lookup on shard stories pinned (`test_move_by_jira_key_locates_shard_story`). Dry-run no-mutation + failed-move-no-partial-mutation pinned.

**Self-check:** 1 vacuous assertion found and fixed — the AC4 help test originally used `"move" in out`, which passed falsely by matching the substring inside "remove". Switched to word-boundary regex (`\bmove\b`); it now correctly fails RED.

**Implementation map for Dev (Ponder):**
1. New module `pf/sprint/story_move.py` — `move_story(sprint_path, story_id, to_epic, *, dry_run=False) -> dict` mirroring `story_remove.py`. Locate via `find_story_in_data`, validate target via `find_epic`, mutate both epic `stories` lists, `validate_full_sprint` then `write_sprint`.
2. `story_move_command` Click command (args: `STORY_ID`, `--to-epic`, `--sprint-file`, `--dry-run`); register on the `story` group in `cli.py` (next to remove).
3. `--epic` option on `story_add_command` to override the positional epic target.
4. Update the `story` group docstring to enumerate the lifecycle (add/move/remove/update/finish).

**Handoff:** To Dev (Ponder Stibbons) for GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_move.py` (new) — `move_story()` + `story_move_command`. Shard-aware (`read_sprint`/`write_sprint`), locates by local id or Jira key via `find_story_in_data`, validates target epic via `find_epic`, renumbers the moved story to the target epic's next id, `validate_full_sprint` before write, no partial mutation on failure, `--dry-run` support.
- `pennyfarthing-dist/src/pf/sprint/cli.py` — registered `move` on the `story` group; rewrote the group docstring to document the lifecycle (add/move/remove/update/finish).
- `pennyfarthing-dist/src/pf/sprint/story_add.py` — added `--epic` override option (redirects the new story to a named epic, taking precedence over the positional EPIC_ID).

**Tests:** 17/17 in `test_153_3_story_move_and_epic_flag.py` passing (GREEN). No regression in `test_153_4`, `test_story_add`, `test_story_update` (126 passed together, targeted run). Commits: tests `b81340ab3`, implementation `3d56d7bde` (pushed to `origin/feat/153-3-...`).
**Branch:** `feat/153-3-sprint-story-move-epic-flag-cli-lifecycle` (pushed).

**Note for Reviewer (Granny):** I did NOT run the full `pytest pennyfarthing-dist/src/pf/tests/` suite as my GREEN proof — see the Incident below. GREEN was verified with targeted runs of the affected test files. The full suite cannot be trusted here because a pre-existing test bug switches the live git branch mid-run (filed as a blocking delivery finding).

### Incident — destructive subagent + branch-switching test (full account)

Two distinct pre-existing problems combined to corrupt my working state mid-phase; both are now recovered, but they cost real effort and are worth the Reviewer's attention:

1. **The full pytest suite switches the live git branch.** `test_git_utils.py` exercises `git_utils.create_or_checkout_branch` / `create_feature_branches` with branch `feature/test`; a checkout leaks onto the process cwd (the real repo) despite isolated `tmp_path` fixtures. Running the full suite (directly OR via subagent) left the tree on `feature/test`, whose `loader.py` predates 153-4 and lacks `find_story_in_data` — breaking the new `story_move` import and producing a cascade of bogus failures in unrelated modules.
2. **A `testing-runner` subagent made destructive bash writes.** While "running the full suite" it (a) appended a duplicate, inferior `find_story_in_data` to `loader.py` (no Jira-key lookup — would silently re-break 153-4 by shadowing the good impl), and (b) overwrote THIS session file with a raw test summary. A test runner has no business writing source or session files.

**Recovery:** reverted the `loader.py` duplicate; force-switched back to `feat/153-3-...`; re-applied the three implementation edits on the correct base; committed + pushed immediately so the work is durable; reconstructed this session file from context. Targeted GREEN re-verified (126 passed) with the branch confirmed stable. Memory saved so future sessions don't lose time to it.

## Delivery Findings

No upstream findings.

### TEA (test design)

- **Question** (non-blocking): AC3 `--epic` semantics are under-specified and the story's technical-approach text ("default to create-new-epic if omitted; if provided append to existing") contradicts how `story add` works today (positional `EPIC_ID` is required and always appends to an existing epic). Affects `pennyfarthing-dist/src/pf/sprint/story_add.py` (Dev must confirm the intended `--epic` behavior). Tests pin the *override* interpretation (`--epic` redirects the new story to the named epic, taking precedence over the positional). *Found by TEA during test design.*
- **Question** (non-blocking): The story is silent on whether `move` *renumbers* the story id when it changes epics (e.g. `151-3` → `152-N`). Affects `pennyfarthing-dist/src/pf/sprint/story_move.py` (id-generation policy). Tests are deliberately renumber-agnostic (match the moved story by title; assert original id absent from source). *Found by TEA during test design.*
- **Improvement** (non-blocking): The not-found error-message helpers `_all_story_ids` / `_all_epic_ids` in `story_move.py` duplicate candidate-list logic that `story_add` (and ideally `story_remove`) also build ad-hoc. Affects `pennyfarthing-dist/src/pf/sprint/loader.py` (extract `get_all_story_ids`/`get_all_epic_ids` there) and the story mutation commands (adopt them for uniform error messages). Deferred from 153-3 as scope creep + branch-fragility risk; warrants a small dedicated refactor story. *Found by TEA during test verification.*

### Dev (implementation)

- **Gap** (blocking): The full Python test suite mutates the live git repository. `pennyfarthing-dist/src/pf/tests/test_git_utils.py` (via `git_utils.create_or_checkout_branch` / `create_feature_branches`) leaks a `feature/test` checkout onto the process cwd instead of staying inside the `temp_git_repo`/`sample_repos` `tmp_path` fixtures. Affects `pennyfarthing-dist/src/pf/tests/test_git_utils.py` and the underlying `git_utils` checkout helper (the git op must always be cwd-pinned to the passed repo path; the test must assert it never touches the outer repo). Any dev running the full suite gets their branch swapped — a serious workflow hazard. Recommend a dedicated story. *Found by Dev during implementation.*
- **Improvement** (non-blocking): The `testing-runner` subagent performed file writes (clobbered this session file; appended a duplicate function to `loader.py`) while nominally just running tests. Affects the `testing-runner` agent definition / its tool grant — a pure test runner should not have, or should not use, file-write capability. *Found by Dev during implementation.*

### Reviewer (code review)

- **Improvement** (non-blocking): `move` renumbers a story's id but does not update inbound references to the old id — `depends_on:` in sibling stories, `.session/{old-id}-session.md`, or Jira links can dangle after a move. Affects `pennyfarthing-dist/src/pf/sprint/story_move.py` (consider rewriting `depends_on` references and/or warning when the moved story has dependents). No current sibling depends on a moved story, so non-blocking. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `story add --epic` is silently ignored in `--initiative` mode. Affects `pennyfarthing-dist/src/pf/sprint/story_add.py` (add a guard/warning if `--epic` is combined with `--initiative`). *Found by Reviewer during code review.*

## Architect Assessment (spec-check)

**Spec Alignment:** Drift detected (minor only — both items already deviation-logged)
**Mismatches Found:** 2

Per-AC review against the implementation (`story_move.py`, `cli.py`, `story_add.py`):

| AC | Verdict |
|----|---------|
| AC1 move command exists/usable | Aligned — `story_move_command` with `--to-epic`, registered on the `story` group. |
| AC2 removes from A, adds to B | Aligned — `move_story` removes from `source_epic["stories"]`, appends to `target_epic["stories"]`, persists both via `write_sprint`. |
| AC3 `add --epic` override | Mismatch #1 (see below). |
| AC4 help documents lifecycle | Aligned — group docstring rewritten; `move` now appears in the Commands listing. |
| AC5 unknown story → candidates | Aligned — `_all_story_ids` populates the error. |
| AC6 unknown epic → available | Aligned — `_all_epic_ids` populates the error. |
| AC7 tested | Aligned — 17 tests, shard-aware contract + jira-key + dry-run + no-partial-mutation pinned. |

**Mismatch #1 — `--epic` semantics (Ambiguous spec — behavioral, minor)**
- Spec: AC-3 says "overriding the default epic"; Technical Approach §2 contradicts itself with "default to create-new-epic if omitted."
- Code: `--epic` overrides the positional `EPIC_ID`, routing the story to the named (existing) epic. The create-new-epic clause is not implemented.
- Recommendation: **C — clarify spec.** The override behavior is the only reading consistent with the existing `story add` contract (positional epic required, append-to-existing). The create-new-epic clause is a spec error. Code is correct; no change. Already logged by TEA + Dev.

**Mismatch #2 — `move` renumbers the story id (Extra in code — behavioral, minor)**
- Spec: AC-2 ("removes from A, adds to B") is silent on the story id.
- Code: `move_story` reassigns the id to the target epic's next sequence (`151-3` → `152-2`) via `generate_story_id`.
- Recommendation: **A — update spec to endorse.** Renumbering is architecturally correct: a story id whose prefix names its epic must stay consistent with epic membership ("one truth"). Leaving `151-3` inside epic 152 would be a latent inconsistency. Dev logged this with accurate forward-impact (external references to the pre-move id are not auto-updated — acceptable; no sibling story depends on it).

**Design quality note:** Implementation is pure reuse — `generate_story_id`, `find_epic`, `find_story_in_data`, `validate_full_sprint`, `read_sprint`/`write_sprint`. No new infrastructure, mirrors `story_remove` faithfully. Validate-before-write + no-partial-mutation-on-failure are correctly ordered (target-epic existence is checked before the source mutation). Endorsed.

**Process findings (acknowledged, not spec mismatches):** Dev's two delivery findings — the blocking Gap (full suite mutates the live git branch via `test_git_utils.py`) and the Improvement (`testing-runner` subagent wrote files) — are test-harness/process concerns, independent of this story's code correctness. The blocking Gap warrants a dedicated follow-up story; it does not block 153-3's spec alignment.

**Decision:** Proceed to review. No hand-back to Dev — both mismatches are minor, correctly logged, and resolve to spec updates (A/C), not code fixes.

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed (82 targeted tests pass; ruff clean on all 3 changed files)

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3 (`story_move.py`, `cli.py`, `story_add.py`)

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 5 findings | Extract `_all_story_ids`/`_all_epic_ids` to `loader.py` for cross-command reuse; removal logic mirrors `story_remove` (acceptable parallel structure). |
| simplify-quality | 4 findings | `--priority` lowercase-vs-uppercase; `location` None guard; docstring "split" omission. |
| simplify-efficiency | 3 findings | `cli.py` epic_promote duplicate normalization; `story_add` fields two-pass; `_all_*` style inconsistency. |

**Applied:** 0 high-confidence fixes.
**Triage rationale (every finding accounted for):**

- **Extract `_all_story_ids`/`_all_epic_ids` to loader.py (reuse, high/med)** — **Deferred.** Legitimate improvement, but it is scope creep beyond 153-3, touches `loader.py` + `story_add`/`story_remove`, and would require re-testing the whole story-command surface — unacceptable risk given this branch's demonstrated fragility (see Dev Incident). Logged as a non-blocking Improvement finding for a future refactor story.
- **`--priority` lowercase not uppercased (quality, high)** — **Dismissed (out of scope).** `--priority` is not in the 153-3 diff (confirmed via `git show`); pre-existing behavior, all tests pass with it. Not this story's defect to fix.
- **cli.py docstring omits "split" (quality, high)** — **Dismissed (false positive).** `split` IS present in the docstring's "Also:" line; the lifecycle line intentionally lists the 5 lifecycle ops (AC4: add/move/remove/update/finish). Verified by reading the actual file.
- **`location` None not validated in move_story (quality, med)** — **Dismissed (false concern).** When `find_story_in_data` returns a non-None `story`, `location` is always a non-None string; the `story is None` early-return covers the rest, and the removal block has an explicit `else` internal-error guard.
- **cli.py epic_promote duplicate normalization (efficiency, high)** — **Dismissed (out of scope).** Lines 1098-1120 are pre-existing `epic_promote` code, not in the 153-3 diff (confirmed via `git show`).
- **story_add `fields` two-pass build (efficiency, med)** — **Dismissed (out of scope).** Pre-existing `add_story` code, not in the diff.
- **`_all_story_ids` loop vs `_all_epic_ids` comprehension style (efficiency, low)** — **Dismissed.** They iterate different shapes (story sections across epics+standalone+top-level vs. a flat epic list); the differing forms are appropriate, not inconsistent.
- **removal logic mirrors story_remove (reuse, low)** — **Confirmed acceptable.** Parallel command structure is the intended pattern; no extraction.

**Reverted:** 0.
**Quality Checks:** ruff `All checks passed!` on the 3 changed files; 82 targeted tests pass (`test_153_3` + `test_153_4` + `test_story_add`); branch stable.

**Overall:** simplify: clean (0 fixes applied; 1 deferred to a follow-up story, rest dismissed with rationale)

**Verify-phase note on `pf check`:** I deliberately did NOT run the full-suite `pf check` for regression detection. Since zero simplify changes were applied, there is nothing to regress; and the full Python suite is known to switch the live git branch to `feature/test` (Dev's blocking delivery finding), which would corrupt the working tree. GREEN is established by targeted runs. Running the full suite here would trade real risk for no information.

**Handoff:** To Reviewer (Granny Weatherwax) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | findings | 5 observations (0 smells, tests GREEN, ruff pass) | confirmed 0, dismissed 0, deferred 0 — observations folded into VERIFIEDs/LOW notes below |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | Disabled via `workflow.reviewer_subagents.edge_hunter=false`; domain covered manually below |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | Disabled via settings; domain covered manually below |
| 4 | reviewer-test-analyzer | No | Skipped | disabled | Disabled via settings; domain covered manually below |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings; domain covered manually below |
| 6 | reviewer-type-design | No | Skipped | disabled | Disabled via settings; domain covered manually below |
| 7 | reviewer-security | No | Skipped | disabled | Disabled via settings; domain covered manually below |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings (also covered by TEA verify simplify fan-out) |
| 9 | reviewer-rule-checker | No | Skipped | disabled | Disabled via settings; rule compliance done manually below |

**All received:** Yes (1 enabled subagent returned; 8 disabled via settings, domains covered by Granny's own analysis)
**Total findings:** 0 confirmed blocking, 0 dismissed, 1 deferred (pre-existing branch-switching test — Dev's blocking finding, follow-up story)

## Reviewer Assessment

**Verdict:** APPROVED

A small, disciplined change that mirrors the proven `story_remove` shape. I went looking for the flaw and did not find a blocking one. Eight specialists were disabled via settings, so I worked their domains by hand against the diff and the 13-check Python lang-review checklist.

**Data flow traced:** CLI `story move 151-3 --to-epic 152` → `story_move_command` → `move_story(path, story_id, to_epic)` → `read_sprint` (merges shards) → `find_story_in_data` (locates by id or jira key) → `find_epic` (target) → remove from source list → `generate_story_id` (renumber) → append to target list → `validate_full_sprint` → `write_sprint` (persists shards). Safe: the target epic is resolved *before* any mutation, so an invalid `--to-epic` returns an error with the source untouched (`test_move_unknown_epic_does_not_mutate_source` proves it).

**Pattern observed:** Faithful parallel of `story_remove.py` (location dispatch: epic vs standalone_stories vs stories) at `story_move.py:95-104`; lazy `noqa: E402` command registration at `cli.py:539-541` matches the sibling commands. Good reuse — `generate_story_id`, `find_epic`, `find_story_in_data`, `validate_full_sprint`, `read_sprint`/`write_sprint` are all existing, tested helpers.

### Observations

1. **[VERIFIED] return-results compliance (SOUL #10)** — `move_story` returns `{success, error?}` / `{success, story}` dicts and never throws; CLI converts failure to `click.ClickException`. Evidence: `story_move.py` returns at the not-found (`success: False`), dry-run, and success paths. Complies with the return-results principle.
2. **[VERIFIED] no partial mutation on failure** — `validate_full_sprint(data)` runs after the in-memory remove/append but *before* `write_sprint`; on invalid it returns without writing, so the on-disk shards are untouched. Evidence: `story_move.py` validate-before-write ordering; corroborated by `test_move_unknown_epic_does_not_mutate_source`.
3. **[RULE] / [VERIFIED] shard-aware IO (the 153-4 failure mode)** — `move_story` uses `read_sprint`/`write_sprint` exclusively, never the raw `_read_yaml_file`/`_write_yaml_file`. Pinned by `test_story_move_uses_shard_aware_io`. This is the exact bug 153-4 fixed for remove/update; the new command does not reintroduce it.
4. **[EDGE] preflight's `CommentedSeq.remove()` identity concern — resolved** — Does the object from `find_story_in_data` identity-match the shard object so `remove()` + `write_sprint` hit the right shard? Empirically yes: `test_move_removes_from_source_shard` reads `epic-PROJ-17079.yaml` back from disk and asserts the id is gone, and `test_move_adds_to_target_shard` reads `epic-152.yaml` and finds the title. The full disk round-trip is verified. Not a finding.
5. **[EDGE][LOW] untested-but-handled paths** — move-to-same-epic (renumbers in place) and standalone/top-level → epic moves are correctly handled by the location dispatch but have no dedicated test. Non-blocking; core ACs are covered. `story_move.py`.
6. **[MEDIUM→LOW] `--epic` silently ignored in `--initiative` mode** — `epic_override` is consulted only in the epic branch (`story_add.py` else-branch); `story add --initiative X --epic Y` ignores `--epic` with no warning. Minor UX confusion, non-blocking, and outside the story's stated scope (epic-targeting). Worth a one-line guard in a future polish. `story_add.py`.
7. **[DOC][VERIFIED] docstrings accurate** — `story_move.py` docstring states "renumbers the story to the target epic's next id," which matches the implementation; the `story` group docstring documents the lifecycle (AC4). No stale/misleading comments.
8. **[TEST][LOW] CLI dry-run + success-output coverage gap** — API dry-run is tested; the CLI `--dry-run` path and the `old_id → new_id` success message are not asserted. Non-blocking coverage nicety.
9. **[SILENT] no swallowed errors** — no bare `except`, no `except: pass`, no silent fallbacks in the diff. Failures surface as `success: False` + `ClickException`.
10. **[TYPE] result-dict shape** — the `{success, error, story}` dict is stringly-ish but is the *established* codebase contract (identical to `story_remove`); consistency outweighs introducing a result newtype for one command. No action.
11. **[SEC] no injection surface** — inputs are story/epic ids used for dict lookup, not shell/SQL/HTML; YAML IO goes through `read_sprint`/`write_sprint` (safe loaders). No secrets, no eval/pickle. Clean.
12. **[SIMPLE] complexity** — `move_story` is linear and minimal; the two `_all_*` helpers are simple. TEA's verify fan-out already triaged the one reuse suggestion (deferred). No over-engineering.

### Rule Compliance (Python lang-review, 13 checks — manual, rule-checker disabled)

| # | Check | Result |
|---|-------|--------|
| 1 | Silent exception swallowing | PASS — no try/except in the new code; CLI raises explicitly |
| 2 | Mutable default arguments | PASS — only `dry_run=False`; no mutable defaults |
| 3 | Type annotations at boundaries | PASS — `move_story`, `story_move_command`, `_all_*` fully annotated |
| 4 | Logging coverage/correctness | PASS — module does not log; returns result dicts (consistent with `story_remove`) |
| 5 | Path handling | PASS — `pathlib.Path`; no string path concat; IO via `read_sprint`/`write_sprint` |
| 6 | Test quality | PASS — meaningful assertions; the one vacuous substring assertion was caught & fixed by TEA (`\bmove\b`) |
| 7 | Resource leaks | PASS — no direct `open()`; no unmanaged resources |
| 8 | Unsafe deserialization | PASS — no pickle/eval; YAML via safe loaders in shared IO |
| 9 | Async pitfalls | PASS — no async code |
| 10 | Import hygiene | PASS — explicit imports; `from pf.sprint.story_add import generate_story_id` introduces no cycle (story_add does not import story_move) |
| 11 | Input validation at boundaries | PASS — CLI args validated via `find_story_in_data`/`find_epic` with actionable errors (AC5/AC6) |
| 12 | Dependency hygiene | PASS — no dependency changes |
| 13 | Fix-introduced regressions | N/A — no fixes applied during review |

### Devil's Advocate

Let me argue this code is broken. **The renumbering is a data-integrity time bomb.** `move 151-3 --to-epic 152` silently rewrites the id to `152-2`. Anything holding the old id — a `.session/151-3-session.md`, a Jira link, a `depends_on: 151-3` in a sibling story — is now dangling, and nothing in `move_story` checks for or rewrites those references. A confused user runs `move` expecting the id to be stable (it isn't) and later `pf sprint story show 151-3` returns "not found." Is that a defect? It's a real sharp edge, but: (a) it is the *correct* behavior per "one truth" (an id whose prefix names its epic must follow the epic), (b) Dev logged it as a deviation with exactly this forward-impact, (c) Architect endorsed it, and (d) no current sibling story has a `depends_on` on a moved story. So it's an accepted, documented trade-off, not a hidden bug — though a future enhancement could update `depends_on` references on move.

**What would a malicious user do?** Pass a crafted `--to-epic "../../etc"` or a giant string? It only ever reaches `find_epic` as a dict-key comparison — no path traversal, no injection, worst case a clean "not found" error listing available epics. **What about a stressed filesystem / concurrent edit?** `read_sprint` → mutate → `write_sprint` is read-modify-write with no locking, so two concurrent `move`s could lose one mutation — but that's the pre-existing concurrency model of *every* sprint command, not a regression here. **What about an empty target epic with no `stories` key?** Handled: `if not target_epic.get("stories"): target_epic["stories"] = CommentedSeq()`. **A story that doesn't exist?** Returns `success: False` with candidate ids. **Validation failure mid-move?** Returns before `write_sprint`, disk untouched.

The devil's advocate surfaces one genuine latent risk (dangling `depends_on`/session/Jira references after renumber) — but it is documented, accepted, and out of this story's scope. I record it below as a non-blocking delivery finding rather than a blocker.

**Handoff:** To SM for finish-story.

## Design Deviations

### TEA (test design)

- **AC3 `--epic` tested as an override, not create-new-epic**
  - Spec source: session AC-3 + Technical Approach §2
  - Spec text: "`pf sprint story add <epic-id> <title> <points> --epic <override>` allows overriding the default epic"
  - Implementation: Test asserts `--epic 152` (with positional epic `PROJ-17079`) lands the new story in epic 152. The contradictory "create new epic if omitted" sub-clause is NOT tested — current `story add` already requires a positional epic.
  - Rationale: The override reading is the only interpretation consistent with the existing `story add` contract; the create-new-epic clause appears to be a spec error. Flagged as a delivery Question for Dev/Architect.
  - Severity: minor
  - Forward impact: If Dev/Architect choose different `--epic` semantics, `test_add_epic_flag_routes_story_to_named_epic` must be revised.

- **`move` success matched by title, not story id**
  - Spec source: session AC-2
  - Spec text: "Moving a story from epic A to epic B removes it from A's shard and adds it to B's shard"
  - Implementation: Target-shard assertions match the relocated story by `title`; source-shard assertions check the original id is absent.
  - Rationale: The spec does not state whether the id is renumbered on move. Title-matching keeps the suite correct under either decision. Flagged as a delivery Question.
  - Severity: minor
  - Forward impact: None for the move contract itself; if a renumbering policy is later specified, an explicit id-assertion test should be added.

### Dev (implementation)

- **`move` renumbers the story id to the target epic's next sequence**
  - Spec source: session AC-2 + TEA delivery Question ("is the story id renumbered on move?")
  - Spec text: "Moving a story from epic A to epic B removes it from A's shard and adds it to B's shard" (silent on id)
  - Implementation: `move_story` calls `generate_story_id(data, target_epic)` and reassigns `story["id"]` (e.g. `151-3` moved into epic `152` becomes `152-2`). The old id is reported in the result as `old_id`.
  - Rationale: Resolves TEA's open Question. Keeping `151-3` inside epic `152` is a data inconsistency (id prefix no longer matches epic membership) and violates "one truth"; renumbering matches how story ids are assigned everywhere else. TEA's tests are renumber-agnostic, so this passes them.
  - Severity: minor
  - Forward impact: A move now changes the story's id. Any external reference to the pre-move id (session files, Jira links) is not auto-updated by this command — callers must account for that. No sibling story currently depends on this.

### Reviewer (audit)

- **TEA: AC3 `--epic` tested as override, not create-new-epic** → ✓ ACCEPTED by Reviewer: the override reading is the only interpretation consistent with the existing `story add` contract; the create-new-epic clause is a spec error. Agrees with author reasoning.
- **TEA: `move` success matched by title, not story id** → ✓ ACCEPTED by Reviewer: renumber-agnostic assertions are the correct call given the spec was silent; keeps the suite valid under the renumber decision Dev landed on.
- **Dev: `move` renumbers the story id to the target epic's next sequence** → ✓ ACCEPTED by Reviewer: architecturally correct under "one truth" (id prefix must match epic membership), endorsed by Architect at spec-check. Forward impact (dangling inbound references to the old id) is real but accurately documented and out of scope — captured as a non-blocking Reviewer delivery Improvement for a follow-up.
- **No undocumented deviations found.** The implementation matches the session scope and the team's logged deviations; nothing diverged from spec without a corresponding entry.

### Architect (reconcile)

**Existing entries reviewed:** All three in-flight deviations (TEA ×2, Dev ×1) have complete, accurate 6-field entries — spec sources resolve to real sections of this session file, quoted spec text is accurate, implementation descriptions match the committed code (`3d56d7bde`), and forward-impact statements are correct. No corrections needed; Reviewer audit stamps are sound. Two deviations the team did not log are added below.

- **Implementation location differs from Technical Approach §4**
  - Spec source: session "Technical Approach", item §4 ("Implementation location")
  - Spec text: "Edit `pennyfarthing-dist/src/pf/commands/sprint_story.py`"
  - Implementation: The named path does not exist (there is no `commands/` package). The story-command code lives in `pennyfarthing-dist/src/pf/sprint/`; the work was done in a new `sprint/story_move.py` plus edits to `sprint/cli.py` and `sprint/story_add.py`.
  - Rationale: The Technical Approach cited a stale/incorrect path. Dev correctly targeted the real location, mirroring the sibling `sprint/story_remove.py`. Per spec-authority, the AC/story scope (which is path-agnostic) outranks the approach's incorrect file reference.
  - Severity: trivial
  - Forward impact: None — purely a documentation inaccuracy in the approach text; the code is in the correct, conventional location.

- **Technical Approach §3 embellishments not implemented (per-command examples + workflow-doc link)**
  - Spec source: session "Technical Approach", item §3 ("Document full story lifecycle in CLI help")
  - Spec text: "Add examples for add/move/remove/update/finish flow" and "Link to workflow documentation (red → green → review → finish ceremony)"
  - Implementation: The `story` group docstring was updated to enumerate the lifecycle (add/move/remove/update/finish) and list the other commands, but no per-command example block or workflow-documentation link was added to the help.
  - Rationale: The binding requirement is AC4 — "Help text for `pf sprint story` documents all available operations" — which the enumerated docstring satisfies (verified: `move` now appears in the rendered Commands list and the lifecycle is named). The §3 sub-bullets were approach embellishments beyond the AC; omitting them keeps the change minimal (Dev minimalist-discipline) without failing any acceptance criterion.
  - Severity: trivial
  - Forward impact: None — AC4 is met. If richer help (examples, doc links) is later desired, it is a standalone documentation enhancement.

**AC deferral verification:** No ACs were deferred or descoped — all 7 acceptance criteria were implemented and confirmed GREEN. The ac-completion accountability step is a no-op for this story.