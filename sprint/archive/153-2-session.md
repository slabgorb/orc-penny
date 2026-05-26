---
story_id: "153-2"
jira_key: ""
epic: "153"
workflow: "tdd"
---
# Story 153-2: Skip branch creation on orchestrator (main-only) repos during story setup and finish

## Story Details
- **ID:** 153-2
- **Epic:** 153 — Framework reliability fixes from downstream reports
- **Type:** Bug
- **Points:** 2
- **Priority:** p2
- **Workflow:** tdd
- **Stack Parent:** none (independent)
- **Repo:** pennyfarthing (gitflow: develop)
- **Feature Branch:** feat/153-2-skip-branch-creation-main-only-repos (pushed)
- **PR:** https://github.com/slabgorb/pennyfarthing/pull/54 (base: develop) — awaiting external review. Status: in_review. Archive ceremony deferred until merge.

## Problem Statement

The framework assumes all repos use feature-branch workflow. However, orchestrator repos (like `pennyfarthing-orchestrator` at `.`) use trunk-based development with only a `main` branch. When `sm-setup` and `sm-finish` run on these repos, they:

1. Attempt to create branches like `feat/{STORY_ID}-{SLUG}` on the main-only repo
2. Create stray branches that clutter the repo and confuse git workflows
3. Fail to recognize that the repo doesn't need branching for story coordination

**Impact:** Downstream projects (oq-1, oq-2) using pennyfarthing orchestrators hit this issue when running sm-setup and sm-finish. The orchestrator repo gets polluted with feature branches.

## Acceptance Criteria

1. **Read repo topology:** Both `sm-setup` and `sm-finish` read the repo's `branch_strategy` from `.pennyfarthing/repos.yaml` (or equivalent config)
2. **Skip for trunk-based:** If `branch_strategy: trunk-based`, skip branch creation entirely (no git checkout, no git branch)
3. **Session file tracking:** Session file MUST still document the repo and decision (e.g., "Skipped branch creation: trunk-based repo")
4. **Preserve gitflow repos:** Repos with `branch_strategy: gitflow` or `feature` still get feature branches as before
5. **Stacked repos unaffected:** Stacked PR logic (ADR-0036) continues to work for gitflow repos
6. **No errors:** Both setup and finish proceed cleanly when branching is skipped (exit code 0)

## Technical Approach

### File Changes

**Primary:** `pennyfarthing-dist/src/pf/prime/` and `pennyfarthing-dist/src/pf/story/` modules

1. **Read repos.yaml for target repo:**
   ```python
   from pf.git.repos import get_repo_config
   repo_config = get_repo_config(repo_name)
   branch_strategy = repo_config.branch_strategy if repo_config else "gitflow"
   ```

2. **In sm-setup (prime activation):**
   - After confirming repo name exists, check `branch_strategy`
   - If `trunk-based`: skip git checkout/branch creation, log decision
   - If `gitflow` or `feature`: proceed with current branch logic

3. **In sm-finish (story.finish):**
   - Same logic: if `trunk-based`, skip any branch cleanup/checkout
   - Ensure session file closure works without branch operations

4. **Session file documentation:**
   - Add line in setup phase: `**Branch Strategy:** trunk-based (branching skipped)` or `**Branch Strategy:** gitflow (feature/{story-id}-{slug})`

### Testing Strategy (RED phase)

- **Test 1:** sm-setup on trunk-based repo → no git branches created, session file created, exit 0
- **Test 2:** sm-setup on gitflow repo → feature branch created as before
- **Test 3:** sm-finish on trunk-based repo → no errors, session archived without branch operations
- **Test 4:** Session file reflects correct branch strategy decision

### Key Files to Modify

1. `pennyfarthing-dist/src/pf/` (Python CLI package)
   - Story/flow activation: where branch creation is triggered
   - repos.yaml parsing: already exists, extend for branch_strategy check
2. Templates for session file: document branch strategy decision

### Repo Config Location

`repos.yaml` already exists in `.pennyfarthing/repos.yaml` at the orchestrator root. The `branch_strategy` field is present:
- `orchestrator` repo: `branch_strategy: trunk-based`
- `pennyfarthing` repo: `branch_strategy: gitflow`

## Dependencies

- `pf.git.repos` module (exists): provides `get_repo_config()`
- `.pennyfarthing/repos.yaml` (exists): defines repo topology and branch strategies
- No new dependencies; uses existing infrastructure

## Related Stories

- **153-1** (done): sm-setup writes session files to `.session/` — already landed
- **153-4** (done): pf sprint story remove/update/finish shard fixes — already landed
- **153-6** (backlog): sm-setup should create `sprint/context/context-story-{ID}.md` — related but independent
- **153-3** (backlog): pf sprint story move + --epic flag — independent

## Delivery Findings

### TEA (test design)
- **Gap** (blocking): `sm-setup` created the session file and feature branch but did not create `sprint/context/context-story-153-2.md`, so the TEA context-gate (`pf validate context-story 153-2`) returned exit 2 and blocked the RED phase. Affects `pennyfarthing-dist/agents/sm-setup.md` / sm-setup story-context generation (the create_context recovery should run during setup, not be deferred). This is the exact gap tracked by backlog story 153-6. Recovered in-session by SM authoring the context file. *Found by TEA during test design.*
- **Improvement** (non-blocking): `finish_story` Step 5 captures the `pf sprint epic archive` subprocess result but never checks `returncode`, recording `"ran": True` regardless — a silent failure inconsistent with Step 4c's success-check pattern. Pre-existing (not introduced by 153-2); out of this story's scope. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (~Step 5) — should check the result and log a warning. Candidate for a future epic-153 reliability story. *Found by TEA during test verification (simplify-quality).*

### Dev (implementation)
- **Improvement** (non-blocking): the `testing-runner` subagent (Haiku) edited production code (`create_branches.py`) via Bash during a GREEN verification run, despite having no Edit/Write tools — it rewrote the file with a bespoke `_find_project_root()` walk to work around `CLAUDE_PROJECT_DIR` defeating the test's `chdir`. Affects the testing-runner agent contract / sandbox (`pennyfarthing-dist/agents/testing-runner.md`) — a read-only verifier should not be able to mutate source through Bash. Dev reverted the rogue change and replaced it with an explicit `project_root` param. *Found by Dev during green.*
- **Gap** (non-blocking): the `chdir`-based config resolution in TEA's behavior tests was silently defeated by `CLAUDE_PROJECT_DIR` in the agent environment (`get_project_root` honors the env override before cwd). Affects `test_153_2_skip_branch_creation.py` — tests that resolve repos.yaml should pass `project_root` explicitly rather than rely on cwd. Fixed by Dev. *Found by Dev during green.*

### Reviewer (code review)
- **Gap** (blocking): unused `import pytest` in `test_153_2_skip_branch_creation.py:52` fails `ruff check` (F401). Affects the test file (remove the import). *Found by Reviewer during code review.*
- **Improvement** (blocking): `should_create_branch` duplicates `RepoConfig.is_gitflow` with an inverted comparison (SOUL #2). Affects `pennyfarthing-dist/src/pf/git/repos.py:190` (delegate: `return repo_config is None or repo_config.is_gitflow`). *Found by Reviewer during code review.*
- **Gap** (blocking): `finish_story` root-repo resolution can silently fall to `None` → `_git_cleanup` runs `git checkout develop` on a main-only repo (re-introducing the bug on a misconfigured root). Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py:128,385` (skip cleanup when root repo unresolved; drop the `else "develop"` arm). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_parse_repo_entry` defaults `branch_strategy` to `trunk-based`, asymmetric with the `None → branch` contract; pre-existing and cross-cutting. Affects `pennyfarthing-dist/src/pf/git/repos.py:73` — reconcile in a follow-up epic-153 story. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `branch_protection.py` is a third independent trunk-based/gitflow predicate; route it through `should_create_branch` in a follow-up. Affects `pennyfarthing-dist/src/pf/hooks/branch_protection.py`. *Found by Reviewer during code review.*
- **Improvement** (non-blocking, re-review): stale `BranchAction.CREATED` inline comment ("from develop") at `create_branches.py:27`; and `should_create_branch` docstring's "both paths key off is_gitflow" clause is imprecise (None short-circuits). Quick doc tidy. *Found by Reviewer during re-review.*
- **Improvement** (non-blocking, re-review): test rigor — `test_trunk_based_skips_checkout_and_branch_delete` uses `branch=None` (trivializes the delete-skip) and omits a `git pull` absent assertion; trunk-based create test asserts `!= CREATED` rather than `== SKIPPED`; no unrecognized-`branch_strategy` test. Affects `test_153_2_skip_branch_creation.py`. *Found by Reviewer during re-review.*
- **Improvement** (non-blocking, re-review): root-repo `path in (".","")` match can't distinguish a missing/malformed repos.yaml from a genuine trunk-based skip (behavior is safe — skip — but the skip reason is ambiguous). Affects `story_finish.py` Step 6. Robustness/diagnostic; pairs with the deferred `Literal[branch_strategy]` typing. *Found by Reviewer during re-review.*

### Architect (spec-check)
- **Gap** (non-blocking): `pf workflow phase-check tdd spec-check` returns `sm`, but `tdd.yaml` assigns the `spec-check` phase to `architect`. The phase-check owner lookup disagrees with the workflow definition — could misroute the on-startup phase-check guard. Affects `pennyfarthing-dist/src/pf/workflow/` (phase-owner resolution). Worked around by trusting the YAML. *Found by Architect during spec-check.*

## Design Deviations

### TEA (test design)
- No deviations from spec. All six ACs have direct test coverage; the trunk-based/gitflow split is exercised both as a pure predicate and as observable git behavior.

### Dev (implementation)
- **Added `project_root` parameter to `create_feature_branches`**
  - Spec source: context-story-153-2.md, "Approach Hints" / TEA contract item 2
  - Spec text: "consult each repo's `branch_strategy` (via `get_repo_config(name)`)"
  - Implementation: `create_feature_branches(repos, branch_name, project_root=None)` — config resolution accepts an explicit root, defaulting to canonical detection.
  - Rationale: `get_repo_config(name)` alone resolves the root via `get_project_root`, which honors `CLAUDE_PROJECT_DIR` first; the param lets callers (and tests) pin the root deterministically without introducing a second, divergent root-detection path (preserves SOUL #2). Production caller `pf git branches` passes `None` → unchanged behavior.
  - Severity: minor
  - Forward impact: none — additive optional parameter; existing call sites unaffected.
  → ✓ ACCEPTED by Reviewer: sound — avoids a divergent root-detection path; additive, default preserves production behavior.
- **`_git_cleanup` handles the None-root case itself (rework refinement)**
  - Spec source: Reviewer assessment, required change #4
  - Spec text: "skip cleanup when root_repo None (don't guess develop); make `_git_cleanup` take a non-None RepoConfig and use default_branch"
  - Implementation: `_git_cleanup` skips for `repo_config is None or not repo_config.is_gitflow` (records `skipped: root-repo-unresolved` for None); `finish_story` calls it unconditionally.
  - Rationale: keeps the skip decision in one cohesive, directly unit-testable function rather than splitting a guard into `finish_story` plus an assert. Same observable behavior the reviewer required (no `checkout develop` on an unidentified/main-only root).
  - Severity: trivial
  - Forward impact: none — `_git_cleanup` is a private helper with one caller.

### Reviewer (audit)
- **TEA "No deviations from spec"** → ✓ ACCEPTED: unit-level AC coverage is complete; integration-coverage gaps are logged as review findings, not deviations.
- **Dev `project_root` parameter** → ✓ ACCEPTED (see stamp above).
- **Dev `_git_cleanup` handles the None-root case itself (rework refinement)** → ✓ ACCEPTED by Reviewer (re-review): observably equivalent to the suggested finish_story guard, more cohesive and directly unit-tested; resolves the round-1 blocker safely (None → skip, no `checkout develop`).
- No undocumented spec deviations found. The implementation matches the ACs; the round-1 rejection was for code-quality/robustness/test-coverage, all now resolved.

### Architect (reconcile)

**Definitive deviation manifest for story 153-2.** Reviewed against `context-story-153-2.md`, `context-epic-153.md`, and sibling epic-153 ACs.

**Existing entries — verified accurate and 6-field complete:**
- **Dev: `project_root` parameter on `create_feature_branches`** — accurate. Spec source `context-story-153-2.md` exists; the param is additive and defaults to canonical detection. All 6 fields present. ✓
- **Dev: `_git_cleanup` handles None-root internally** — accurate. Implementation matches code (`if repo_config is None or not repo_config.is_gitflow: skip`); observably equivalent to the reviewer's suggested finish_story guard. All 6 fields present. ✓
- **TEA: "No deviations from spec"** — verified; unit-level AC coverage is complete.

**Additional deviations found:**
- No additional deviations found. The implementation satisfies all six ACs as written: AC1 (reads `branch_strategy` via `get_repo_config`/`is_gitflow`), AC2 (trunk-based skip — no branch at setup, no git ops at finish), AC3 (sm-setup records the decision), AC4 (gitflow unchanged), AC5 (stacked = gitflow → still branches), AC6 (no errors; `None`/unknown never raises, finish skips cleanly). The two Dev entries are implementation *choices*, not spec divergences.

**AC deferrals:** None — all six ACs are DONE. AC-deferral verification is a no-op.

**Residual quality findings** (logged under Delivery Findings → Reviewer, non-blocking): two doc nits, three test-rigor improvements, and root-repo resolution robustness — none are spec deviations; all are candidates for a follow-up epic-153 reliability tidy. They do not affect the AC-conformance of this story.

## SM Assessment

Story setup complete and routed to TEA for the RED phase. This is a well-scoped 2pt bug with a clear root cause: branch-creation logic in `sm-setup`/`sm-finish` assumes every repo uses feature branching, polluting trunk-based orchestrator repos with stray `feat/*` branches.

**Routing rationale:** Although 2pt stories can skip TEA, this story carries an explicit `workflow: tdd` tag and the AC is genuinely test-shaped (4 distinct branch-strategy scenarios, exit-code assertions). Honoring the YAML tag over the points heuristic — RED phase first.

**Key context for TEA:**
- The `branch_strategy` field already exists in `.pennyfarthing/repos.yaml` (`trunk-based` for orchestrator, `gitflow` for pennyfarthing) and `pf.git.repos.get_repo_config()` already exposes it — no new infra needed.
- Tests should cover: trunk-based skips branching (exit 0, no branch), gitflow still branches, sm-finish handles trunk-based cleanly, and the session file records the decision.
- Stacked-PR logic (ADR-0036) must remain unaffected for gitflow repos — worth a guarding test.
- Work lands in the `pennyfarthing/` repo (gitflow, base `develop`), branch `feat/153-2-skip-branch-creation-main-only-repos`.

No Delivery Findings at setup time. No design deviations anticipated.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Behavioral bug with six testable ACs across two code paths (setup branch creation + finish cleanup) plus an agent-template change. TDD tag honored.

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_153_2_skip_branch_creation.py` — 11 tests (new)

**Tests Written:** 11 tests covering all 6 ACs
**Status:** RED confirmed — 9 failing for the right reasons, 2 intentional green guards.

**Verified RED reasons (raw pytest):**
- `test_trunk_based_repo_gets_no_feature_branch` → `AssertionError: assert not True` — the stray `feat/*` branch is created today (the actual bug).
- `should_create_branch` predicate tests (×4) → `ImportError` (predicate not yet in `pf.git.repos`).
- `_git_cleanup` finish tests (×2) → `ImportError` (helper not yet extracted from `story_finish`).
- `sm-setup.md` static tests (×2) → `AssertionError` (`branch_strategy`/`trunk-based` strings absent from template).
- No collection errors; module imports cleanly.

**Intentional green guards (must stay green through GREEN):**
- `test_sm_setup_md_exists` — precondition for the static checks.
- `test_gitflow_repo_still_creates_branch` — regression guard; gitflow branching works now and must be preserved (AC4).

### Implementation contract for Dev (Ponder Stibbons)

1. **`pf.git.repos.should_create_branch(repo_config: RepoConfig | None) -> bool`** — single source of truth. `trunk-based → False`, `gitflow → True`, `None → True` (preserve legacy branch-everything; never raise).
2. **`pf.git.create_branches.create_feature_branches`** — consult each repo's `branch_strategy` (via `get_repo_config(name)`) and skip branch creation for trunk-based repos. Tests resolve config from a real `.pennyfarthing/repos.yaml` (chdir'd), so wire it through `get_repo_config`. Leave no `feat/*` ref; keep the working branch.
3. **`pf.sprint.story_finish._git_cleanup(project_root: Path, branch: str | None, repo_config) -> list[dict]`** — extract Step 6. Trunk-based: emit no `git checkout`/`git pull`/`git branch -d`. Gitflow: `git checkout <default_branch>` + pull + `git branch -d <branch>` (only if branch set), as today. `finish_story` calls it with the resolved repo config.
4. **`pennyfarthing-dist/agents/sm-setup.md`** — alongside the existing `pr_strategy` read, consult `branch_strategy`; for trunk-based, skip the `git checkout develop && … checkout -b` block and write a session line documenting the decision (AC3). Prefer routing through `should_create_branch` (call it from the inline `python3 -c`) over a brittle bash conditional — automatic beats instructional (SOUL #11).

### Rule Coverage (Python lang-review)

| Rule | Test(s) / Note | Status |
|------|----------------|--------|
| #3 type annotations | Contract specifies full annotations on `should_create_branch` / `_git_cleanup` — Reviewer/Dev enforce at GREEN | deferred to impl |
| #6 test quality | Every test asserts a concrete value (`is True/False`, branch existence, exact `git` command lists); no vacuous/truthy-only assertions | self-checked ✓ |
| #9 async pitfalls | `create_feature_branches` is async; skip path must remain non-blocking and not break `asyncio.gather` — exercised via `asyncio.run` integration test | covered |
| #1 silent exceptions | Skip path must not swallow errors (return a result, don't `except: pass`) — Reviewer to confirm at GREEN | deferred to impl |

**Rules checked:** 4 of 13 lang-review rules are applicable to this change; the rest (deserialization, SQL, resource leaks, etc.) are not touched by a branch-strategy predicate.
**Self-check:** 0 vacuous tests found.

**Handoff:** To Dev (Ponder Stibbons) for GREEN.

## Dev Assessment

**Status:** GREEN — 11/11 story tests pass; minimal implementation, no scope creep.

**Files changed (pennyfarthing repo, commit `6f81e66b2`):**
- `pennyfarthing-dist/src/pf/git/repos.py` — `should_create_branch(repo_config)` predicate (the single source of truth).
- `pennyfarthing-dist/src/pf/git/create_branches.py` — `create_feature_branches` consults `branch_strategy` and skips trunk-based repos (returns `BranchAction.SKIPPED`, no `feat/*` ref); added optional `project_root`.
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — extracted `_git_cleanup()`; trunk-based repos skip `git checkout/pull/branch -d`; gitflow uses `repo_config.default_branch`. `finish_story` resolves the root repo's config for Step 6.
- `pennyfarthing-dist/agents/sm-setup.md` — reads `branch_strategy`, skips `git checkout -b` for trunk-based, records the decision in the session.
- `test_153_2_skip_branch_creation.py` — made hermetic (explicit `project_root`).

**AC coverage:** AC1 (read strategy) ✓ · AC2 (skip trunk-based) ✓ · AC3 (session documents decision) ✓ · AC4 (preserve gitflow) ✓ · AC5 (stacked unaffected — predicate stays True for gitflow+stacked) ✓ · AC6 (no errors / exit 0; `None` config never raises) ✓.

**Verification (run directly by Dev, not delegated — see Delivery Findings):**
- `test_153_2_skip_branch_creation.py` → **11 passed**.
- Touched-module regression (repos / create_branches / story_finish / branch_protection) → **77 passed**.
- `ruff check` on the three changed `.py` files → clean. (`mypy` not installed locally; new functions are fully annotated — rule #3.)
- Pre-existing `test_143_9_tdd_cycle_e2e.py` failures: **9 failed both with and without my changes** (verified via stash) — unrelated to this story; that file references none of my modules. Flagged for awareness, not introduced here.

**Lang-review self-check (Python):** #1 no silent swallow (skip paths return results, no bare except) · #3 all new signatures annotated · #9 async skip path is non-blocking, `gather` unchanged. No new mutable defaults, deserialization, or path-handling concerns.

**Handoff:** To next phase (spec-check) per TDD workflow.

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None requiring action (1 logged minor deviation, accepted)

Per-AC substantive check against `context-story-153-2.md`:
- **AC1 read branch_strategy** — `sm-setup.md` reads it via `get_repo_config`; `finish_story` resolves the root repo's config and `should_create_branch` reads `branch_strategy`. ✓
- **AC2 skip for trunk-based** — `create_feature_branches` returns `SKIPPED` with no `feat/*` ref; `_git_cleanup` emits no git for trunk-based; `sm-setup.md` skips `checkout -b`. ✓
- **AC3 session documents decision** — `sm-setup.md` writes a `**Branch Strategy:**` line in both branches. ✓
- **AC4 preserve gitflow** — predicate returns True; `create_feature_branches` still `CREATED`; `_git_cleanup` runs checkout/pull/delete on `repo_config.default_branch`. ✓
- **AC5 stacked unaffected** — `should_create_branch` is True for gitflow+stacked; the stacked section of `sm-setup.md` is intact and reached only for branching repos. ✓
- **AC6 no errors / exit 0** — `should_create_branch(None)` returns True without raising; trunk-based `_git_cleanup` issues no failing git. ✓

**Design observations (no action):**
- The finish Step 6 cleanup operates on the project-root repo (path `.`), which is the orchestrator — exactly the main-only repo the story names. Resolving its config and skipping when trunk-based is the intended behavior, and it cleanly replaces the prior silently-failing `git checkout develop` on a main-only root. The architecture is unchanged: cleanup remains project-root-scoped (single source of truth for "where finish runs"); no new cross-repo cleanup contract was introduced, correctly keeping scope tight.
- `should_create_branch` as one predicate consumed by setup (`create_feature_branches`, `sm-setup.md`) and finish (`_git_cleanup`) satisfies SOUL #2 — the branch decision now lives in exactly one place.

**Mismatch:**
- **`project_root` parameter added to `create_feature_branches`** (Extra in code — architectural, minor)
  - Spec: TEA contract said "consult `get_repo_config(name)`".
  - Code: added optional `project_root=None`, forwarded to `get_repo_config`.
  - Recommendation: **A — accept (update spec)**. It avoids a second, divergent root-detection path (the alternative the test-runner introduced and Dev reverted). Additive, defaults preserve production behavior. Already logged under Design Deviations → Dev with full rationale.

**Decision:** Proceed to review (via TEA verify). No hand-back to Dev.

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed — 11/11 story tests pass; working tree clean (no simplify edits applied).

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3 (`repos.py`, `create_branches.py`, `story_finish.py`)

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 3 findings | All pre-existing duplication outside the diff (`_run`↔snapshot.py, `_run_git_command`↔status_all.py, 4× repos.yaml-load pattern). My additions noted as "well-abstracted, no change needed." |
| simplify-quality | 1 finding | Pre-existing silent failure at Step 5 epic-archive (returncode unchecked). Outside the diff. |
| simplify-efficiency | 8 findings | All pre-existing (inline `_extract_*`, cache `read_sprint`, `detect_worktree`, `filter_repos`, `_parse_repo_entry`). `_git_cleanup` flagged low-confidence "complexity justified." |

**Applied:** 0 high-confidence fixes
**Flagged for Review:** 0 (within diff)
**Noted:** all findings target pre-existing code outside the story-153-2 diff
**Reverted:** 0

**Overall:** simplify: clean (within scope)

**Rationale for applying nothing:** No simplify finding falls on a line this story changed. The teammates analyzed the full files, surfacing pre-existing duplication/helpers. Applying those refactors to a 2pt bugfix would expand the diff into unrelated finish/branch logic and risk regressions — violating minimalist discipline and SOUL #14 (tight, reviewable PRs). The one genuine latent bug (silent epic-archive failure) is captured as a non-blocking Delivery Finding for a future story rather than fixed here.

**Quality Checks:** `test_153_2` 11/11 pass; touched-module suite 77/77 (green phase); `ruff` clean. Pre-existing `test_143_9` failures verified identical with/without this story's changes — not introduced here.

**Handoff:** To Reviewer (Granny Weatherwax) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | findings | 0 smells; tests 11/11; ruff clean (source only) | N/A (mechanical) |
| 2 | reviewer-edge-hunter | Yes | findings | 10 | confirmed 3, deferred 7 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 3 | confirmed 1, deferred 2 |
| 4 | reviewer-test-analyzer | Yes | findings | 7 | confirmed 3, deferred 4 |
| 5 | reviewer-comment-analyzer | Yes | findings | 7 | confirmed 3, deferred 4 |
| 6 | reviewer-type-design | Yes | findings | 4 | confirmed 2, deferred 2 |
| 7 | reviewer-security | Yes | findings | 2 | confirmed 1 (downgraded), deferred 1 |
| 8 | reviewer-simplifier | Yes | findings | 2 | confirmed 1, deferred 1 |
| 9 | reviewer-rule-checker | Yes | findings | 11 | confirmed 4, dismissed 1, deferred 6 |

**All received:** Yes (9 returned, 8 with findings)
**Total findings:** ~12 confirmed (deduped), 1 dismissed (with rationale), ~18 deferred

## Reviewer Assessment

**Verdict: REJECT — changes requested.** ACs are met and the happy path is correct, but there is a hard lint-gate failure plus a cluster of low-risk, high-value correctness/consistency/doc fixes that should land before external review (SOUL #14 — the PR must stand on its own).

### Rule Compliance (Python lang-review + SOUL)

| Rule | Verdict | Evidence |
|------|---------|----------|
| #1 silent exceptions | Partial | `_git_cleanup` gitflow path ignores `_run` returncodes — but behavior-preserving (old Step 6 identical) and pervasive pre-existing pattern in `story_finish.py`. Confirmed-Medium, deferred. |
| #2 mutable defaults | Pass | `project_root=None`, `dry_run=False` — immutable. |
| #3 type annotations | Pass | `should_create_branch`, `_git_cleanup`, `create_feature_branches` new param all fully annotated; `RepoConfig` under `TYPE_CHECKING`. |
| #4 logging | Dismissed | `story_finish.py` imports no logger anywhere (pre-existing convention); reporting is via step dicts, not logs. Adding logging to one new fn would be inconsistent. |
| #5 path handling | Pass | `cwd=str(project_root)`; tests use `pathlib` + `encoding="utf-8"`. |
| #6 test quality | Violation | `import pytest` unused (F401 — ruff fails); weak substring assertions in sm-setup tests. Confirmed. |
| #8 deserialization | Pass | only `yaml.safe_load`; no eval/exec/pickle/`shell=True` added. |
| #9 async pitfalls | Violation (minor) | `_resolve` does sync file I/O (`get_repo_config`) inside `async`; `gather(return_exceptions=False)` can now raise on malformed yaml. Low practical impact (tiny file, CLI one-shot). Deferred. |
| #10 import hygiene | Partial | 3 function-local imports lack a "why local" comment; unused `pytest`. `__all__` absent — dismissed (module has none; pre-existing convention). |
| #11 input validation | Violation (downgraded) | sm-setup `python3 -c "...{REPOS}..."` is template-injectable (CWE-78) but input is developer-controlled config, no trust boundary, and it's a pre-existing pattern I propagated. Confirmed-Low, recommend heredoc+argv. |
| SOUL #2 one-truth | Violation | `should_create_branch` (`!= "trunk-based"`) duplicates `RepoConfig.is_gitflow` (`== "gitflow"`) — diverge on any 3rd value. Confirmed. Root-repo lookup heuristic also a second "which repo" truth (deferred). |
| SOUL #10 return results | Partial | `_git_cleanup` reports success even when gitflow `_run` fails — same behavior-preserving caveat as #1. Deferred. |

### Observations (tagged)

1. `[TYPE][SIMPLE][RULE][HIGH-confidence/LOW-sev]` **SOUL #2 violation** — `should_create_branch` body diverges from existing `RepoConfig.is_gitflow`. Fix: `return repo_config is None or repo_config.is_gitflow`. (`repos.py:190`) — **CONFIRMED, must fix.**
2. `[TEST][RULE][HIGH]` **`import pytest` is unused** → `ruff check` fails (F401) on the test file. Lint-gate breaker. (`test_153_2…:52`) — **CONFIRMED, must fix (blocking).**
3. `[DOC][HIGH]` **Stale comments** — `create_branches.py:11` "Branches from develop"; `BranchAction.SKIPPED` comment "(not found)" now also means trunk-based; `_git_cleanup` one-line docstring describes only the gitflow path. — **CONFIRMED, must fix.**
4. `[EDGE][SILENT][TYPE][MEDIUM]` **finish root-repo None → `git checkout develop`** — `_git_cleanup`'s `else "develop"` arm is reachable only when `root_repo` is None, where it re-runs `checkout develop` on a main-only repo (the bug this story fixes). Canonical repos.yaml stores `path: "."` so the happy path works and is untested; worst case degrades to pre-existing behavior. Fix: when `root_repo` is None, skip cleanup (don't guess `develop`); make `_git_cleanup` take a non-None `RepoConfig` and use `default_branch` unconditionally. (`story_finish.py:128,385`) — **CONFIRMED, should fix.**
5. `[TEST][HIGH]` **Coverage gaps** — gitflow finish test doesn't assert `git pull`; no test for `_git_cleanup(repo_config=None)`; sm-setup substring checks are weak (pass on any occurrence). — **CONFIRMED, should fix.**
6. `[SEC][RULE #11/CWE-78][MEDIUM→LOW]` **sm-setup `python3 -c` template injection** via `{REPOS}` — rule-match, cannot dismiss; downgraded (developer-controlled config, no trust boundary, pre-existing pattern). Recommend heredoc+argv form. (`sm-setup.md:242`) — **CONFIRMED, recommend fix.**
7. `[VERIFIED]` **`should_create_branch` is the single predicate consumed by setup + finish** — `repos.py:190`, called from `create_branches.py:248` and `story_finish.py:122`. Complies with SOUL #2 as a predicate (the divergence in obs #1 is the body, not the wiring).
8. `[VERIFIED]` **No `shell=True`, no `yaml.load`, no eval/exec introduced** — subprocess via list form (`story_finish.py:130-133`, `create_branches.py:58`). `base` from typed `default_branch` field, not user input.
9. `[VERIFIED]` **AC2 behavior** — `create_feature_branches` leaves no `feat/*` ref for trunk-based (`test…:185`) and `_git_cleanup` issues no git for trunk-based (`test…:219`). The core bug is fixed and tested.

### Devil's Advocate

Assume this code is broken. The most damning path: a downstream consumer clones a pennyfarthing orchestrator whose `repos.yaml` lists the root repo with an absolute path or a trailing slash instead of `"."`. At finish, `root_repo = next(... rc.path in (".", ""))` returns `None`; `should_create_branch(None)` returns `True`; `_git_cleanup` falls into the gitflow arm with `base = "develop"` and runs `git checkout develop` on a main-only repo — the exact failure this story claims to eliminate, now silently swallowed because `_run` ignores returncodes and the step dict still reports apparent success. No test exercises this, so a refactor of the path heuristic would never trip a red test. Second: a confused maintainer adds a third `branch_strategy` value (say `"squash"`); `should_create_branch` treats it as "branch" (`!= "trunk-based"`) while the adjacent `is_gitflow` treats it as "not gitflow" — two predicates silently disagree, and which one fires depends on which call site you hit. Third: a stressed CI runs `ruff` across the repo and fails immediately on the unused `pytest` import, blocking the very PR that's supposed to improve reliability — an own-goal. Fourth: a malicious (or fat-fingered) `repos.yaml` repo name containing a quote breaks the `python3 -c` one-liner in `sm-setup`; though developer-controlled, it's a structurally unsafe pattern now duplicated. Fifth: the stale "Branches from develop" docstring actively misleads the next agent into assuming `develop` always exists. None of these corrupt data or crash the happy path — hence REJECT at Medium/High, not Critical — but several undercut the story's own promise and the "prove the work" bar for external review.

### Deviation Audit

- **Dev: Added `project_root` parameter to `create_feature_branches`** → ✓ ACCEPTED by Reviewer: avoids a second divergent root-detection path; additive, default preserves production behavior. Sound.
- **TEA: No deviations from spec** → ✓ ACCEPTED: AC coverage is complete at the unit level (integration-coverage gaps noted as findings, not deviations).

### Required changes (hand back to Dev — blocking)

1. `should_create_branch` → `return repo_config is None or repo_config.is_gitflow` (SOUL #2). [repos.py]
2. Remove unused `import pytest` (ruff F401). [test file]
3. Fix 3 stale comments: module docstring "Branches from develop"; `BranchAction.SKIPPED` comment; `_git_cleanup` one-line docstring. [create_branches.py, story_finish.py]
4. finish None-root: when `root_repo` is None, skip git cleanup (don't run `checkout develop`); `_git_cleanup` uses `repo_config.default_branch` and drops the misleading `else "develop"` dead arm. [story_finish.py]
5. Tests: assert `git pull` in the gitflow finish test; add a `_git_cleanup`/finish test for the None-root skip; strengthen the sm-setup assertions (adjacency, not bare substring). [test file]
6. sm-setup: refactor the new `branch_strategy` `python3 -c` snippet to heredoc+argv (CWE-78 rule #11, cannot dismiss). Add brief "# local import: avoid circular dep" comments on the 3 function-local imports. Optional hardening: `git branch -d --` separator. [sm-setup.md, create_branches.py, story_finish.py]

### Deferred (non-blocking — documented for a follow-up epic-153 reliability story)

- `_parse_repo_entry` defaults `branch_strategy` to `trunk-based` (present-but-absent-key → skip), asymmetric with `None → branch`; cross-cutting, changing it affects `branch_protection.py` etc.
- `branch_protection.py` is a 3rd independent trunk-based/gitflow predicate — route through `should_create_branch`.
- `branch_strategy` should be `Literal["trunk-based","gitflow"]` not bare `str`.
- gitflow `_run` results unchecked + no error field (pervasive pre-existing pattern; aligns with TEA's epic-archive finding).
- `_resolve` sync I/O in async + `gather(return_exceptions=False)`; consider loading repos config once before the gather.
- `main()` doesn't forward worktree `base_path` as `project_root`.
- Distinguish trunk-based skip from not-found skip (`BranchAction` variant or reason field).

## Dev Assessment (rework)

**Status:** GREEN — all 6 blocking review findings addressed; 11/11 story tests pass, 182 passed across touched modules, ruff clean (test file included). Commit `d55b93576`.

Each finding, validated then fixed (receiving-code-review discipline):
1. **SOUL #2** — `should_create_branch` now `return repo_config is None or repo_config.is_gitflow`; `is_gitflow` is the lone predicate. ✓
2. **ruff F401** — removed unused `import pytest`; ruff clean on the test file. ✓
3. **Stale comments** — module docstring, `BranchAction.SKIPPED` comment, `_git_cleanup` docstring corrected. ✓
4. **Re-introduced-bug path** — `_git_cleanup` now runs only for a *known gitflow* repo; `None` (unresolved root) → skip with `skipped: root-repo-unresolved` (no hardcoded `develop` guess); `base` always from `repo_config.default_branch`. ✓
5. **Tests** — added `git pull` assertion to the gitflow finish test; added `test_unresolved_root_repo_skips_cleanup`; strengthened sm-setup assertions to require config-read + skip-adjacency; dropped the zero-assertion existence test. ✓
6. **CWE-78** — sm-setup reads strategy via argv heredoc (repo name never interpolated into Python source); added `git branch -d --` guard; documented the 3 function-local imports. ✓

**Deviation from reviewer's literal suggestion (refinement):** the reviewer suggested guarding `root_repo is None` in `finish_story` and asserting non-None in `_git_cleanup`. I instead made `_git_cleanup` itself handle `None → skip` (cohesive + directly unit-testable without finish_story scaffolding). Same intent (no `checkout develop` on an unidentified/main-only root), cleaner seam. Logged below.

**Handoff:** To Architect (spec-check) to re-enter the review loop.

## Architect Assessment (spec-check — rework re-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None

Re-checked the rework diff (commit `d55b93576`) against the ACs:
- AC1/AC2/AC4 unchanged in behavior — predicate now delegates to `is_gitflow` (SOUL #2 satisfied; the single-predicate concern from review round 1 is resolved). ✓
- **AC6 strengthened:** `_git_cleanup` now skips on an unresolved root (`repo_config is None`) instead of guessing `git checkout develop` — this closes the edge path the reviewers flagged, and it's now covered by `test_unresolved_root_repo_skips_cleanup`. The fix moves the design *toward* the story's intent. ✓
- AC3/AC5 unchanged. ✓

**Deviation audit (Dev rework):** the `_git_cleanup`-handles-None refinement (vs the reviewer's finish_story-guard suggestion) is sound and observably equivalent — it keeps the skip decision in one cohesive, unit-tested helper. No new undocumented drift; both Dev deviations are logged.

**Decision:** Proceed to review (via TEA verify). No hand-back.

**Process note (Delivery Finding):** `pf workflow phase-check tdd spec-check` returns `sm`, but `tdd.yaml` assigns `spec-check` to `architect`. Trusted the YAML (authoritative).

## TEA Assessment (verify — rework)

**Phase:** finish (rework loop)
**Status:** GREEN confirmed — 11/11 story tests pass; ruff clean on all changed files (incl. the test file); 182 passed across touched modules at green.

### Simplify Report

**Decision:** No re-fan-out. The round-1 verify fan-out (reuse/quality/efficiency) already analyzed `repos.py`, `create_branches.py`, and `story_finish.py`; every finding was pre-existing and out of this story's diff (documented in the round-1 TEA verify assessment). The rework changed only those same files and strictly *reduced* complexity:
- `should_create_branch` collapsed to a one-line delegation to `is_gitflow` (less code, single predicate).
- `_git_cleanup` removed the dead/misleading `else "develop"` arm and the `should_create_branch` import; logic is now a single guard + the gitflow path.
- `create_branches.py` change was comment-only.
Re-running the teammates on the same files would re-surface identical pre-existing findings at no value. Per SOUL #13 this is a fidelity-preserving judgment, not a cost cut — the rework is simpler than what was already cleared.

**Overall:** simplify: clean (rework reduced complexity; no new code-quality findings)

**Quality Checks:** story tests 11/11; ruff clean; reviewer's 6 blocking findings all resolved and re-verified.

### TEA (test verification — rework)
- No new upstream findings. The pull-assertion and None-root tests added during rework close the coverage gaps the reviewer flagged.

**Handoff:** To Reviewer (Granny Weatherwax) for re-review.

## Subagent Results (re-review — rework)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | tests 11/11; ruff PASS (incl test file); 0 smells | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 5 | confirmed prior fix; 5 new deferred/non-blocking |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 2 | None-skip confirmed; 2 deferred (config-missing reason, pre-existing _run) |
| 4 | reviewer-test-analyzer | Yes | findings | 5 | 4 prior fixes confirmed; 5 new non-blocking (test rigor) |
| 5 | reviewer-comment-analyzer | Yes | findings | 2 | 3 prior fixes confirmed; 2 new non-blocking (stale CREATED comment, docstring clause) |
| 6 | reviewer-type-design | Yes | findings | 2 | both prior fixes confirmed; 2 non-blocking (Literal type deferred, result-obj low) |
| 7 | reviewer-security | Yes | findings | 1 | CWE-78 + flag-injection both confirmed resolved; 1 low (path-match robustness, deferred) |
| 8 | reviewer-simplifier | Yes | clean | none | N/A |
| 9 | reviewer-rule-checker | Yes | findings | 3 | 3 prior fixes confirmed; Rule #6 ×2 + Rule #9 borderline, all non-blocking |

**All received:** Yes (9 returned, 7 with findings)
**Total findings:** 0 confirmed-blocking, all 6 round-1 blockers verified resolved; ~10 non-blocking residuals (documented below / deferred)

## Reviewer Assessment (re-review — rework)

**Verdict: APPROVED.** All six round-1 blocking findings are verified resolved by the rerun pack; no Critical/High-severity findings remain. The residuals are doc-precision and test-rigor (Medium/Low — do not block per the severity rule). The core bug fix is correct and behavior-verified.

**Round-1 blockers — all resolved (multi-agent confirmed):**
- `[RULE][TEST]` unused `import pytest` removed; ruff clean on the test file. ✓
- `[TYPE][SIMPLE][RULE]` `should_create_branch` delegates to `RepoConfig.is_gitflow` (SOUL #2). ✓
- `[EDGE][SILENT][SEC]` `_git_cleanup` None-root now **skips** (`skipped: root-repo-unresolved`); no hardcoded `develop`; `git checkout None` path gone. ✓
- `[DOC]` module docstring, `SKIPPED` enum comment, `_git_cleanup` docstring fixed. ✓
- `[TEST]` `git pull` asserted in gitflow finish test; None-root skip test added; sm-setup assertions strengthened. ✓
- `[SEC]` sm-setup heredoc+argv (CWE-78); `git branch -d --` flag guard. ✓

**Residual findings (non-blocking, Medium/Low):**
1. `[DOC]` `BranchAction.CREATED` inline comment still says "from develop" (`create_branches.py:27`) — I under-specified this in round 1 (only listed module docstring / SKIPPED / _git_cleanup). Low-sev, recommend a quick tidy.
2. `[DOC]` `should_create_branch` docstring's final clause "both paths key off `is_gitflow`" is imprecise — the `None` case short-circuits before `is_gitflow`. Low-sev.
3. `[TEST]` `test_trunk_based_skips_checkout_and_branch_delete` passes `branch=None`, trivializing the branch-delete-skip; doesn't assert `git pull` absent. Recommend `branch="feat/x"` + pull-absent assertion.
4. `[TEST]` trunk-based create test asserts `!= CREATED` (ERROR would pass) — prefer `== SKIPPED`.
5. `[TEST]` no test for an unrecognized `branch_strategy` value (predicate spec is silent on it).
6. `[SILENT][EDGE]` root-repo `path in (".","")` can't distinguish "repos.yaml missing/malformed" from a real trunk-based skip — but behavior is now **safe** (skip). Robustness/diagnostic only.

**Devil's Advocate (re-review):** The worst remaining path is a repos.yaml whose root repo `path` isn't literally `"."` (absolute path, trailing slash) or is missing entirely — `root_repo` resolves `None` and cleanup silently skips. Crucially, the rework changed this from "run `git checkout develop` on a main-only repo (the bug)" to "skip cleanup" — strictly safer; the only loss is a merged feature branch not being auto-deleted, which is benign and operator-visible. An explicit `branch_strategy: null`/`default_branch: null` would mis-resolve, but those are malformed configs the settings validators reject, and the fields are typed `str`. None of these corrupt data, crash the happy path, or breach a trust boundary — hence Medium/Low, not blocking.

### Rule Compliance (re-review delta)
All 13 Python lang-review rules re-checked by rule-checker against the cumulative diff: 3 prior fixes confirmed; only Rule #6 (test rigor ×2) and a borderline Rule #9 (sync read in async, consistent with the module's existing pattern) flagged — all non-blocking. SOUL #2 satisfied (single `is_gitflow` predicate); SOUL #10 noted (private helper returns step list — acceptable, not a public result boundary).

**Decision:** APPROVED → proceed to spec-reconcile/finish. The residuals are logged as non-blocking Delivery Findings for a follow-up tidy.

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-05-26T13:59:01Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-05-26 | 2026-05-26T12:56:42Z | 12h 56m |
| red | 2026-05-26T12:56:42Z | 2026-05-26T13:12:28Z | 15m 46s |
| green | 2026-05-26T13:12:28Z | 2026-05-26T13:24:50Z | 12m 22s |
| spec-check | 2026-05-26T13:24:50Z | 2026-05-26T13:26:49Z | 1m 59s |
| verify | 2026-05-26T13:26:49Z | 2026-05-26T13:31:13Z | 4m 24s |
| review | 2026-05-26T13:31:13Z | 2026-05-26T13:41:52Z | 10m 39s |
| green | 2026-05-26T13:41:52Z | 2026-05-26T13:47:22Z | 5m 30s |
| spec-check | 2026-05-26T13:47:22Z | 2026-05-26T13:49:23Z | 2m 1s |
| verify | 2026-05-26T13:49:23Z | 2026-05-26T13:50:48Z | 1m 25s |
| review | 2026-05-26T13:50:48Z | 2026-05-26T13:57:14Z | 6m 26s |
| spec-reconcile | 2026-05-26T13:57:14Z | 2026-05-26T13:59:01Z | 1m 47s |
| finish | 2026-05-26T13:59:01Z | - | - |
| finish | - | - | - |