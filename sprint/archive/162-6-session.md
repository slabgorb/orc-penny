---
story_id: "162-6"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-6: finish_story runs gh pr merge/view from orchestrator root, cannot merge/verify PRs in the inlined pennyfarthing sub-repo (repo-context bug)

## Story Details
- **ID:** 162-6
- **Jira Key:** (none — Jira disabled for this story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-6-finish-repo-context
- **PR:** #173

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-05T11:22:19Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-05T10:43:29.321532+00:00 | 2026-08-05T10:44:56Z | 1m 26s |
| red | 2026-08-05T10:44:56Z | 2026-08-05T10:55:12Z | 10m 16s |
| green | 2026-08-05T10:55:12Z | 2026-08-05T11:06:24Z | 11m 12s |
| review | 2026-08-05T11:06:24Z | 2026-08-05T11:22:19Z | 15m 55s |
| finish | 2026-08-05T11:22:19Z | - | - |

## Sm Assessment

**Scope:** 3-pt p2 bug story, TDD. `finish_story` in `pennyfarthing-dist/src/pf/sprint/story_finish.py` runs its `gh pr view`/`gh pr merge` subprocesses (and the 162-4/155-34 `_branch_merge_state` git probe) with cwd = orchestrator project_root. In a workspace where the story's code lives in an inlined sub-repo (pennyfarthing/ inside the orchestrator), gh resolves the WRONG repo — the operator must remember to run finish from inside the sub-repo (live workaround memorialized in team memory). The story's `repos:` field names the code repo; `repos.yaml` gives its path.

**Technical approach for TEA:**
1. Failing tests: finish resolves the story's repo path from repos.yaml (via the `repos:` field) and passes it as cwd to EVERY gh/git subprocess in the finish path — `_pr_view`, `gh pr merge`, `_branch_merge_state` probes, and any post-merge verification. Running finish from orchestrator root must behave identically to running it from inside the sub-repo.
2. Multi-repo stories (`repos:` = both/multi): finish verifies EVERY repo's PR merged before done. One merged + one open → loud abort, story left `in_review`, no archive, session intact.
3. Single-repo behavior on a same-root workspace must not regress (the common case where project_root IS the code repo).

**Acceptance criteria (from story YAML):**
1. Route the 155-34 git merge-state probe to the story's code repo alongside the gh calls — probing project_root makes multi-repo no-PR finishes read unknown and abort.
2. Multi-repo stories: finish verifies EVERY repo's PR is merged before marking done — one merged + one open aborts loudly and leaves the story in_review.
3. (implied) Same-root single-repo workspaces unchanged; suite exit 0 maintained (162-5 just retired the baseline — do not add unmarked failures).

**Recent context in this file (all merged, build on develop HEAD 301e5c619):** 162-1 gate ordering, 162-3 strict MERGED comparison, 162-4 ref-prefixed probes, 162-5 baseline triage (suite now exits 0 with 7 loud xfails — keep it that way).

**Run mode:** Peloton-inline — agents spawned as subagents by SM, no relay markers, SM owns PR create/merge/finish.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (9 failing for the right reasons; 5 green-on-arrival guards)

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_6_finish_repo_context.py` — 14 tests, real-git fixtures + cwd-keyed gh fake

**Suite state:** baseline before = 5565 passed / 4 skipped / 7 xfailed / exit 0. After: only the 9 new reds; all 310 finish-family and epic-162 tests still pass. `ruff check` clean (repo does not enforce `ruff format` — story_finish.py itself is unformatted).

### Failure map on HEAD (every subprocess call site and its current cwd)

| Call site | line | current cwd | required cwd |
|---|---|---|---|
| `gh pr list --head` (branch to PR fallback) | 545 | none (process cwd = orchestrator) | story repo |
| `_pr_view` (pre-merge gate + dry-run preview) | 247 | none | story repo |
| `gh pr merge --squash --delete-branch` | 707 | none | story repo |
| `_pr_is_merged` post-merge verification | 291 → 247 | none | story repo |
| `_branch_merge_state` rev-parse / rev-list probes | 403/416/427 | `project_root` | story repo (AC1) |
| `_resolve_base_branch` | 351 | reads the `path: "."` repo's `default_branch` | the story repo's own `default_branch` |
| `_git_cleanup` checkout/pull/branch -d | 467-471 | `project_root`, keyed off root RepoConfig | story repo + that repo's config |
| step 5 `pf.cli sprint epic archive` | 1061 | `project_root` | unchanged — orchestrator owns `sprint/` |

### Designed interface for Dev (seams; any shape that satisfies the tests is fine)

1. `_resolve_story_repos(project_root, story) -> list[RepoConfig]` — parse the story's `repos:` field (bare string, comma-separated string, or YAML list; reuse the shape parse in `sprint/staleness.py::_resolve_repo_path`) and map each name through `pf.git.repos.load_repos_config(project_root)` (local import, same circular-layering reason as steps 6 and `_resolve_base_branch`). Absolute path = `project_root / rc.path`; `path: "."` IS the project root. An unresolvable or absent `repos:` value must degrade to the project root — that is today's behavior and a green guard pins it.
2. Thread the path through the gh helpers: `_pr_view(pr_number, cwd=...)`, `_pr_is_merged(pr_number, cwd=...)`, the `gh pr list --head` fallback, `gh pr merge`. Keep everything inside `_run` — the 155-34 module-convention test forbids direct `subprocess` calls elsewhere in the module.
3. `_branch_merge_state(repo_path, branch)` probes the code repo, and its base comes from THAT repo's `default_branch`. The fixtures make orchestrator trunk-based `main` and every code repo gitflow `develop`, so a root-scoped base resolution still reads unknown after the cwd is fixed.
4. Multi-repo: resolve each repo's PR by running the branch probe in that repo, and require ALL resolved PRs to be MERGED before the done transition. The abort must name the PR that did not land.
5. Step 6 cleanup: the feature branch lives in the code repo — route the git commands and the gitflow/trunk-based decision to the story's repo config.

### Exact test list

RED (9):
1. `TestGhCallsRouteToStoryRepo::test_pre_merge_view_merge_and_verification_all_use_story_repo`
2. `TestGhCallsRouteToStoryRepo::test_no_gh_call_runs_against_the_orchestrator_repo`
3. `TestGhCallsRouteToStoryRepo::test_branch_to_pr_resolution_probe_uses_story_repo`
4. `TestNoPrProbesRunInStoryRepo::test_branch_merged_in_sub_repo_finishes` (AC1 verbatim)
5. `TestMultiRepoVerifiesEveryPr::test_all_repos_merged_finishes` (AC2 positive)
6. `TestMultiRepoVerifiesEveryPr::test_one_merged_one_open_aborts_loudly` (AC2 verbatim)
7. `TestMultiRepoNoPrProbes::test_no_pr_all_repos_merged_finishes` (AC1 x AC2)
8. `TestOrchestratorStepsStayAtProjectRoot::test_epic_archive_step_is_not_routed_into_the_code_repo` (red only because HEAD aborts at step 2 and never reaches step 5)
9. `TestGitCleanupRunsInStoryRepo::test_feature_branch_is_deleted_in_the_repo_that_has_it`

Green-on-arrival over-reach guards (5):
10. `TestGhCallsRouteToStoryRepo::test_no_op_merge_in_story_repo_still_aborts` (gh #71 verification not weakened)
11. `TestNoPrProbesRunInStoryRepo::test_unmerged_in_sub_repo_still_aborts` (155-34 preserved)
12. `TestMultiRepoNoPrProbes::test_no_pr_one_repo_unmerged_aborts` (fan-out must not stop at the first merged answer)
13. `TestSameRootWorkspaceUnchanged::test_single_root_repo_pr_finish_unchanged`
14. `TestSameRootWorkspaceUnchanged::test_story_without_repos_field_falls_back_to_project_root`

Guards 11 and 12 pass on HEAD for the WRONG reason (finish aborts because it cannot see the branch at all); their message assertions pin the right one.

**Handoff:** To Dev for implementation (GREEN).

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py` — repo-scoped routing for every gh/git subprocess in the finish path, plus multi-repo PR fan-out

**What landed, against TEA's call-site map:**

| Call site | now runs in |
|---|---|
| `gh pr list --head` (branch to PR) | each story repo (per-repo resolution loop) |
| `_pr_view(pr, cwd=...)` pre-merge gate + dry-run preview | story repo |
| `gh pr merge` | story repo |
| `_pr_is_merged(pr, cwd=...)` post-merge verification | story repo |
| `_branch_merge_state(repo_path, branch, base=...)` | story repo, base from THAT repo's `default_branch` |
| `_git_cleanup(repo_path, branch, repo_config)` | each story repo, keyed off its own `branch_strategy` |
| step 5 `pf.cli sprint epic archive` | project root — unchanged, by design |

**New seams:**
- `_resolve_story_repos(project_root, story) -> list[tuple[Path, RepoConfig | None]]` — parses all three `repos:` shapes (bare name, comma-separated, YAML list) through `load_repos_config` (local import, circular-layering). Unresolvable/absent degrades to `(project_root, root RepoConfig)`.
- `_cwd_kwargs(cwd)` — supplies `cwd` when a repo is known, omits the kwarg otherwise, so the pre-162-6 direct callers of `_pr_view`/`_pr_is_merged` (162-3, 155-32 tests) keep their signatures.
- `_branch_merge_state` gained an optional third `base` argument; the 162-4 two-arg positional contract is untouched.

**PR-field semantics decision (TEA's open question):** the session's single `**PR:** #N` line is honored ONLY when the story resolves to exactly one repo. A multi-repo story ignores it and resolves each repo's PR by probing `gh pr list --head <branch>` in that repo. Rationale: one field cannot truthfully describe two PRs, and silently applying it to whichever repo comes first is precisely the wrong-repo-number failure this story kills. A per-repo session syntax is the schema follow-up (see Delivery Findings).

**Multi-repo ordering:** every repo's PR passes the conflict gate BEFORE any repo is merged. A multi-repo finish cannot be atomic, but this keeps gh #113's promise that no irreversible merge runs while a known-conflicting PR is in the set.

**Tests:** 14/14 on `test_162_6_finish_repo_context.py` (GREEN). Full suite 5579 passed / 4 skipped / 7 xfailed / exit 0 — baseline 5565 plus the 14 new, only the 7 loud 162-5 xfails, zero new failures. Finish-family + epic-162 + 153-2 + staleness selection: 335 passed. `ruff check` clean on both changed/added files.

**Branch:** `feat/162-6-finish-repo-context` (pushed, 2 commits: TEA 95311c65e, Dev 28132d5c4, both GPG signed)

**Handoff:** To Reviewer

## Delivery Findings

### Dev (implementation)
- **Gap** (non-blocking): the multi-repo PR field has no session syntax. Finish now resolves per-repo PRs by branch probe and ignores a single `**PR:**` line for multi-repo stories, so a multi-repo story whose PRs cannot be found by branch (squash-renamed head, PR opened from a fork) has no way to record them. Affects `schemas/session-schema.md` and `agents/sm-setup.md` (add a per-repo PR field shape, e.g. `**PR (api):** #11`), then `pennyfarthing-dist/src/pf/sprint/story_finish.py` to read it. *Found by Dev during implementation.*
- **Improvement** (non-blocking): `_resolve_base_branch` remains root-scoped and is now only the fallback for callers with no repo config. Any other place that substitutes the root repo's `default_branch` for a code repo's has the same latent bug. Affects `pennyfarthing-dist/src/pf/sprint/` broadly — worth a sweep story. *Found by Dev during implementation.*
- **Improvement** (non-blocking): multi-repo finish is sequential and non-atomic — repo A's merge lands before repo B's post-merge verification can fail. The abort is loud and names the PR, but the operator is left with a half-landed story to reconcile by hand. A recovery note in the abort message (or a `pf sprint story finish --resume` that skips already-merged repos) would close it; the existing 155-29 already-merged short-circuit already makes a plain re-run safe. *Found by Dev during implementation.*

### TEA (test design)
- **Question** (non-blocking): a multi-repo story whose session carries a single `**PR:** #N` line cannot describe two repos. The multi-repo tests deliberately use branch-only sessions so the answer stays Dev's; if Dev picks a rule (primary repo wins / per-repo suffix syntax), it should be recorded in `schemas/session-schema.md` and the sm-setup template. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` and `agents/sm-setup.md`.
- **Gap** (non-blocking): `_resolve_base_branch` is root-scoped by construction, so any repo-scoped caller needs a repo argument. Same latent bug exists wherever else the root repo's `default_branch` stands in for a code repo's. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`.
- **Improvement** (non-blocking): the live workaround for this bug (run finish from inside the sub-repo) is memorialized in team memory. Once GREEN lands, that memory entry should be retired or the memory will keep teaching an unnecessary ritual. Affects the orchestrator memory file, not the framework repo.

## Design Deviations

### TEA (test design)
- **Step 6 cleanup routing:** ACs name the gh calls and the merge-state probe; tests also pin `_git_cleanup` to the story's repo. Reason: the feature branch only exists in the code repo, so cleanup keyed off the root repo is the same bug — in the dogfood topology it silently skips as trunk-based and strands every merged branch.
- **Step 5 pinned to the project root:** not an AC, added as an over-reach guard. Reason: `pf.cli sprint epic archive` reads the orchestrator's `sprint/` tree; a blanket re-route would make the epic archive a silent no-op.
- **Multi-repo PR resolution shape:** tests require per-repo resolution via the branch probe rather than any particular session syntax, so Dev is free on the session-field question above.

### Dev (implementation)
- **No-PR verified-merged step record no longer says `skipped: True`**
  - Spec source: `test_162_6_finish_repo_context.py`, `_assert_abort_invariants` (the 155-34 silent-skip guard, replicated)
  - Spec text: "the abort's step record still carries silent-skip wording" — asserts no step has `action == merge_pr` with `skipped is True` and no `error`
  - Implementation: the branch-verified-merged arm now emits `"skipped": "branch-verified-merged"` (a descriptive string) instead of `"skipped": True`; the adjacent `branch_verified_merged_into` key is unchanged
  - Rationale: with multi-repo fan-out, an abort's report retains the step records of repos that already verified clean. A bare `skipped: True` among them reads as exactly the silent skip epic 155 exists to kill, and trips the guard. No existing test asserted `skipped is True` for this arm.
  - Severity: minor
  - Forward impact: minor — any consumer keying off `steps[].skipped is True` for the no-PR arm must accept a truthy string; the affirmative no-branch sentinel arm still emits `skipped: True`.
- **`_git_cleanup` runs once per story repo, not once per finish**
  - Spec source: TEA call-site map, designed interface note 5
  - Spec text: "route the git commands and the gitflow/trunk-based decision to the story's repo config"
  - Implementation: step 6 loops `story_repos` and appends one step-6 entry per repo
  - Rationale: the branch exists in every code repo a multi-repo story touched, so cleaning only one strands the rest. Single-repo stories are byte-identical to before.
  - Severity: minor
  - Forward impact: none for single-repo; a multi-repo finish report now carries N step-6 entries.
- **Multi-repo stories ignore the session's single `**PR:**` field**
  - Spec source: TEA Delivery Finding (deliberately unpinned) / designed interface note 4
  - Spec text: "what a single session `**PR:** #N` line means for a two-repo story — the multi-repo tests below use branch-only sessions so the answer stays Dev's"
  - Implementation: the field is adopted only when `len(story_repos) == 1`; multi-repo resolves each PR by probing `gh pr list --head` in that repo
  - Rationale: applying one number to the first repo in the list is the wrong-repo-number bug this story fixes, wearing a different hat. Fail to a per-repo probe instead.
  - Severity: minor
  - Forward impact: a multi-repo story whose PRs are not discoverable by branch will abort on the no-PR gate until the schema gains a per-repo PR field (logged as a Delivery Finding).
## Subagent Results

| # | Subagent | Received | Findings | Confirmed | Decision |
|---|----------|----------|----------|-----------|----------|
| 1 | reviewer-preflight | Yes | 0 blocking | 0 | N/A — 14/14 target, 245 finish-family, 5631 passed / 4 skipped / 7 xfailed, zero XPASS, ruff clean. Reported 3 failures + 1 error in bmad/test_parser.py and session/test_cache.py, verified identical on develop → pre-existing, recorded as L4 |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings (workflow.reviewer_subagents.edge_hunter=false) — boundary analysis performed by me, see M2/M3/M5 |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — swallowed-error sweep performed by me, see L1 |
| 4 | reviewer-test-analyzer | Yes | 6 | 5 | confirmed 5 (M1, M2, M3, M4, L2), deferred 1 (multi-repo cleanup coverage → L5) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — docstring accuracy audit performed by me, see M6 |
| 6 | reviewer-type-design | Yes | 7 | 3 | confirmed 3 (M1, M2, L3), dismissed 2 with rationale (skipped union, _cwd_kwargs sentinel), deferred 2 (dataclass carrier, shared parser → L3) |
| 7 | reviewer-security | Yes | 4 | 1 | confirmed 1 (M1), dismissed 3 with rationale (path traversal, checkout `--` guard, PR-number flag injection — the last disproven empirically) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — complexity read performed by me; the loop restructure is a faithful lift of the pre-existing if/elif chain, no over-engineering found |
| 9 | reviewer-rule-checker | Yes | 1 | 0 | Challenged and folded into M1 — its stated mechanism (load_repos_config raises on a missing repos file) is factually wrong; see Challenged note |

**All received: Yes** (5 enabled returned; 4 disabled via settings, pre-filled)

## Reviewer Assessment

**Verdict:** APPROVED

**Scope reviewed:** 477 changed lines in the finish flow plus 1110 lines of new tests, at 28132d5c4 on top of 301e5c619. This is the largest diff of epic 162 and it rewires an irreversible operation, so I inventoried every subprocess site in the module rather than reading the diff alone.

**Data flow traced (story field to irreversible merge):** story YAML `repos:` value → _resolve_story_repos parses the three shapes → **allowlist lookup** (a name is used only if it is a key in the repos config; an unknown name can never become a path) → project root joined with that entry's declared path, resolved → cwd for the branch-to-PR probe → resolved PR string → conflict-gate view → gh pr merge squash/delete-branch → post-merge MERGED re-probe in the same cwd → cleanup in the same cwd. Safe because the operator-supplied name is allowlisted rather than used as a path, and every value reaches argv as a list element (no shell), with the flag guard on the branch delete. The one unsafe input is a repos entry whose declared path is not on disk — M1.

**Routing completeness (the story's central claim) — VERIFIED:** every subprocess site in the module is accounted for: PR view (line 264, cwd via the helper), the three merge-state git probes (480/493/504), the three cleanup git commands (550/551/554), the branch-to-PR probe (646), the merge (846), and the epic archive (1215, deliberately pinned to the project root). There is no residual site without a repo-scoped cwd, and the finish path never takes the no-cwd arm. Checked against the module-convention rule that all subprocesses route through the single seam — compliant, all ten sites go through it. TEA's call-site map missed nothing.

**No external blast radius — VERIFIED:** I grepped the whole package for callers of the four changed helpers. There are zero production callers outside this module; the only external callers are the 162-4, 162-3, 155-32, 155-29, 155-12, 155-15, 155-31, 155-1 test files, and every changed signature is additive with a default. Checked against the "match model to task / single source of truth" convention — no distributed-file duplication introduced. Complies.

**Degradation path — VERIFIED with one caveat:** with no repos config present the loader returns an empty mapping (verified at git/repos.py lines 109-110, it does not raise), so resolution yields the project root paired with no config; the merge-state base then falls back exactly as before, and cleanup records the same unresolved skip that test_153_2 pins. Byte-identical for the git probes. **Caveat:** not identical for the gh probes — see M6. No applicable project rule governs this; it is a behavioural-fidelity finding.

**Multi-repo abort semantics — VERIFIED:** the abort invariants helper is real, not a substring check. It asserts session file still present, archive directory empty, no done transition requested, story status in review, and no silently-skipped merge step. The one-merged-one-open test drives that helper. Checked against the "unknown is never merged, no irreversible step before verification" rule — compliant: the conflict gate loops every repo before the merge loop begins, and an unreadable view degrades to not-merged and falls through to a real attempt rather than a skip.

**Non-atomicity window:** if the second merge fails after the first landed, the flow returns failure with the first repo's merged step record still in the report, story left in review, session kept. The state is truthful but the operator gets no recovery guidance and the already-landed repo is not named — M4. Untested — M3/M4.

### Rule Compliance

**Rule: return result objects, do not throw (project rule 6; restated as the no-throw contract in a comment at line 993 of the changed file)**
- _resolve_story_repos, path construction (line 435) — **VIOLATION**: no existence check before the path becomes a subprocess cwd; I confirmed empirically that a run with a missing cwd raises. The correct precedent is in the same package at git/repos.py line 141, which filters on existence. → M1
- _resolve_story_repos, config load (line 420) — compliant on the missing-file case (loader returns an empty mapping); the malformed-file raise is pre-existing and this diff moves it earlier, before any irreversible step, which is strictly safer. → Challenged, folded into M1
- Branch-to-PR probe (646), merge (846), post-merge verify (872) — compliant: all failures handled by return-code checks, no new raise
- Cleanup loop (1225) — compliant in itself; unreachable with a bad path because the earlier probe raises first
- Archive step OSError guard (1009) — compliant, unchanged

**Rule: all subprocesses route through the module seam (155-34 module convention)**
- All ten sites (264, 480, 493, 504, 550, 551, 554, 646, 846, 1215) — compliant, zero direct subprocess calls added to the module

**Rule: unknown state is never treated as merged; no irreversible step before verification (epic 155 rule 1)**
- Strict MERGED comparison on a None view (line 294) — compliant
- Per-repo already-merged short-circuit reading the pre-merge snapshot (811) — compliant: a missing snapshot entry reads as not-merged
- Merge-state unknown arm (939) — compliant, aborts
- Post-merge re-probe (872) — compliant, fresh snapshot in the correct repo
- Conflict gate over all repos before the merge loop (750-773) — compliant for repos that have PRs; **gap** for a repo routed to the no-PR arm, whose read-only verification is not hoisted → M3

**Rule: flag guard on git arguments that could be read as options**
- Branch delete (554) — compliant, guarded
- Merge-state ref probes (480/493/504) — compliant, fully qualified refs
- Checkout and pull base (550/551) — unguarded; **dismissed**, see Challenged (the suggested guard inverts the command's meaning)

**Rule: never edit symlinked runtime dirs; modify the dist source of truth**
- Both changed files are under the dist source tree — compliant

**Rule: type annotations at module boundaries**
- Four new/changed helper signatures fully annotated — compliant; the unparameterized story mapping annotation is a nit → L3

### Findings

| Severity | Tag | Issue | Location |
|----------|-----|-------|----------|
| [MEDIUM] | [SEC] [TYPE] [RULE] | M1 — a repos entry whose declared path is absent on disk becomes a subprocess cwd, raising out of the flow instead of returning a result | story_finish.py:435 |
| [MEDIUM] | [EDGE] [TYPE] | M2 — no dedup on the `repos:` value; a duplicated name merges the same PR twice and the second attempt's non-zero exit produces a false abort on work that landed | story_finish.py:425-435 |
| [MEDIUM] | [EDGE] [TEST] | M3 — mixed multi-repo (one repo with a PR, one without) escapes the gate-all-before-merging-any invariant: the read-only no-PR branch verification sits inside the merge loop, so repo A can land before repo B is refused | story_finish.py:895-916 |
| [MEDIUM] | [TEST] | M4 — second-merge failure after the first landed is untested and the abort names neither the landed repo nor a recovery path | story_finish.py:846-891 |
| [MEDIUM] | [EDGE] | M5 — dry-run preview pairs the first *resolved* PR with the first *repo*; for a mixed multi-repo story that probes the wrong repo — the story's own bug class, surviving in the preview path only | story_finish.py:665-666, 700 |
| [MEDIUM] | [DOC] | M6 — the gh calls' degradation is not the pre-162-6 behaviour the docstring claims: they previously inherited the operator's process cwd and are now pinned to the project root, which silently retires the documented run-from-inside-the-sub-repo workaround for any story that omits `repos:`. Epic-level `repos:` is never consulted as a fallback | story_finish.py:414, 646 |
| [LOW] | [SILENT] | L1 — cleanup discards all three git return codes and still reports a clean step; 162-6 makes this newly reachable in the dogfood topology (root is trunk-based so cleanup always skipped before; the code repo is gitflow so it now runs and moves the operator's working tree) | story_finish.py:550-555 |
| [LOW] | [TEST] | L2 — the status-in-review assertion in the abort helper cannot fail while the transition is mocked; the transition-not-requested assertion is the load-bearing one | test file, abort helper |
| [LOW] | [TYPE] [SIMPLE] | L3 — unparameterized story mapping annotation; positional 2-tuple widening to a 3-tuple with index-zero-index-zero access; the `repos:` parser is duplicated in the staleness module with divergent empty-value and multi-value semantics | story_finish.py:400-435 |
| [LOW] | [TEST] | L4 — the clean-suite baseline is scoped to the tests directory; a full-package collection also picks up 3 failures and 1 error in co-located bmad and session test files, verified identical on develop | out of scope |
| [LOW] | [TEST] | L5 — cleanup is only tested for a single repo; a loop that stopped after the first repo would still pass | test file |

**Nothing Critical or High.** No finding produces a wrong-repo merge, a false done, a stray archive, or data loss on the shipped path. M1, M2 and M5 all fail closed before any irreversible step; M3 and M4 are inherent to a non-atomic multi-repo finish that has no live consumers yet (every story in the sprint tree resolves to exactly one repo); M6 has no live impact for the same reason.

### Challenged / dismissed subagent findings

- **[RULE] rule-checker's sole finding — CHALLENGED.** Its mechanism is factually wrong: the config loader returns an empty mapping when the file is absent (git/repos.py:109-110), it does not raise. The residual malformed-file raise is pre-existing (cleanup called the same loader unguarded on develop) and the diff moves it earlier, before any irreversible step. The real gap is the missing existence check, folded into M1 rather than dismissed.
- **[SEC] PR-number flag injection from the branch-to-PR probe — DISMISSED with evidence.** I had independently suspected the jq filter leaks a literal null for an empty result (bare jq does emit null, which would have made the whole no-PR verification arm unreachable in production — a High). Disproven: I ran the real probe against this repo with a nonexistent head branch and got exit 0 with empty output, so the emptiness check holds and nothing bogus propagates. The session-field path is anchored to digits.
- **[SEC] flag guard on checkout and pull — DISMISSED.** The suggested form inverts the command: a guard there makes git treat the base name as a path to restore, not a branch to switch to. The value comes from operator-authored topology config in the same trust domain as the code being merged, and both lines are unchanged by this diff.
- **[SEC] path traversal via a relative-escape path in the topology config — DISMISSED as a finding, noted as informational.** The config is operator-authored and trusted; the same unconstrained join already exists in the package's own path helper. The user-controllable input, the story's `repos:` value, is allowlisted against config keys and never used as a path.
- **[TYPE] the `skipped` field's mixed boolean/string union — DISMISSED, deviation accepted.** String-valued values are already this module's convention for that key (cleanup emits an unresolved-root reason string, pinned by test_153_2 line 254). I grepped every consumer in the package: no production code reads step records' `skipped` at all, and the only identity comparisons are in tests that exercise the boolean arms.
- **[TYPE] the cwd sentinel preserves a latent wrong-repo path — CHALLENGED.** I inventoried all ten subprocess sites: every finish-path caller supplies a repo. The no-cwd arm is reachable only from the pre-162-6 direct-helper tests, and there are zero production callers of those helpers outside this module. Not a live wrong-repo path.

### Deviation audit

- **TEA — cleanup routing pinned though not an AC: ACCEPTED.** The feature branch only exists in the code repo; keying cleanup off the root repo is the same bug wearing a different hat. Note it makes cleanup newly reachable, which surfaces L1.
- **TEA — epic archive pinned to the project root: ACCEPTED.** Verified at line 1215 with the project root cwd and a guard test; re-routing it would make the archive a no-op.
- **TEA — multi-repo PR resolution shape left unpinned: ACCEPTED.**
- **Dev — the no-PR verified-merged step record carries a descriptive string instead of a bare true: ACCEPTED.** Grep-verified no consumer, and it matches the module's existing convention for that key. Strictly more informative.
- **Dev — cleanup once per repo: ACCEPTED.** Single-repo is a loop of one, byte-identical. Untested for the multi-repo case (L5).
- **Dev — multi-repo ignores the single session PR field: ACCEPTED, and it is the right call.** Applying one number to whichever repo sorts first would reintroduce exactly the wrong-repo-number failure this story exists to kill. Correctly logged as a schema follow-up.

**Undocumented deviations (Reviewer audit):**
- The reported PR variable is silently redefined at line 665 from "the story's PR" to "the first PR resolved across all repos", and is then used only for the dry-run preview and the reported value. Not listed as a deviation; it is the mechanism behind M5.
- The gh calls' degradation cwd change (M6) is presented as preserving pre-162-6 behaviour, which holds for the git probes but not for the gh probes.

### Reviewer (audit) — undocumented behaviour change worth a release note

Finishing a story in this workspace will now run a checkout and pull in the inlined framework repo and delete the local feature branch there. Before this change cleanup always skipped (the root repo is trunk-based). Operators will see their sub-repo working tree move. Correct per intent, but it is a first-time visible effect and the return codes are discarded (L1).

**Handoff:** To SM for finish-story. M1 and M2 should be filed as a single p2 follow-up (both are guards in the same resolver) before any further topology-driven routing lands; M3/M4/M5/M6 belong with the multi-repo schema follow-up Dev and TEA already logged.

## Delivery Findings

### Reviewer (code review)
- **Gap** (non-blocking): the story-repo resolver neither checks that a resolved path exists nor de-duplicates the `repos:` value. A topology entry pointing at an uncloned directory makes a subprocess raise out of the flow instead of returning a result object (project rule 6), and a duplicated name merges the same PR twice, whose second non-zero exit produces a false abort on work that landed. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (add an existence guard modelled on the package's own path helper at `pennyfarthing-dist/src/pf/git/repos.py` line 141, plus order-preserving dedup, with tests for both). *Found by Reviewer during code review.*
- **Gap** (non-blocking): the gate-all-before-merging-any invariant covers only repos that resolve a PR. A repo routed to the no-PR branch-verification arm is checked inside the merge loop, so a mixed multi-repo story can land one PR and then be refused — an avoidable half-shipped state, since that verification is read-only and could be hoisted into the pre-merge gate. Also untested, as is a second-merge failure after the first landed. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` and its test file. *Found by Reviewer during code review.*
- **Gap** (non-blocking): the dry-run preview pairs the first resolved PR number with the first repo in the list, so a mixed multi-repo story previews against the wrong repo — the story's own bug class surviving in the preview path. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by Reviewer during code review.*
- **Question** (non-blocking): the gh calls' unresolvable-repos degradation now pins the project root where it previously inherited the operator's process cwd, which retires the documented run-from-inside-the-sub-repo workaround for any story that omits `repos:`; and epic-level `repos:` is never consulted as a fallback even though the epic shards carry it. Should resolution inherit the epic's value before degrading? Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` and the schema docs. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): step 6 discards the return codes of all three git commands and still reports a clean cleanup step. This story makes cleanup reachable for the first time in an inlined topology, so a failed checkout on a dirty sub-repo tree will now be reported as success. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the epic's clean-suite baseline is scoped to the tests directory; a full-package collection also surfaces 3 failures and 1 error in co-located bmad and session test files, identical on develop. Either widen the baseline or record the scope so future stories do not read "suite exits 0" as covering the whole package. Affects `pennyfarthing-dist/src/pf/bmad/test_parser.py` and `pennyfarthing-dist/src/pf/session/test_cache.py`. *Found by Reviewer during code review.*