---
story_id: "155-2"
jira_key: null
epic: "155"
workflow: "tdd"
---
# Story 155-2: Finish creates feat/ branch on orchestrator, breaking main-only topology (gh #15)

## Story Details
- **ID:** 155-2
- **Jira Key:** null (kanban-only)
- **Workflow:** tdd
- **Stack Parent:** none
- **Repo:** pennyfarthing
- **Type:** bug
- **Points:** 2
- **Priority:** p1

## Problem Statement

The FINISH ceremony (SM agent) creates a `feat/` branch when archiving stories, regardless of whether the target repo supports feature branching. The orchestrator repo (this repo's parent) uses a **trunk-based** branch strategy (main-only topology, per `.pennyfarthing/repos.yaml`):

```yaml
orchestrator:
  branch_strategy: trunk-based
  default_branch: main
```

**Root cause:** The finish flow (likely `finish_story` command or similar) does not check the repo's branch strategy before creating feature branches. It should:

1. Detect the repo's `branch_strategy` from `repos.yaml`
2. Only create `feat/` branches for `gitflow` repos
3. Skip branching entirely for `trunk-based` repos (record decision in session)
4. Stash any branch metadata (story branch name) for future reference if needed

**Manifest:** Stories with orchestrator as target produce stray `feat/` refs on main-only repos, polluting the git namespace and breaking git workflows that assume a single "default branch" rule.

## Technical Approach

### Phase: RED (TEA)
- Write tests exercising the finish flow against both repo types:
  - Gitflow repo (pennyfarthing): should create `feat/155-2-*` branch
  - Trunk-based repo (orchestrator): should skip branching, record decision in YAML
- Verify acceptance criteria capture the expected behavior

### Phase: GREEN (Dev)
- Locate the finish story command implementation (likely `pennyfarthing-dist/src/pf/*.py` or subcommand)
- Add branch strategy detection via `get_repo_config()` (see `pf.git.repos`)
- Modify the finish flow to:
  - Check `rc.branch_strategy` from the target repo config
  - Conditionally create branch only if `branch_strategy != "trunk-based"`
  - Record the strategy decision in the session file (already done by `sm-setup`)
- Ensure the archive YAML path logic doesn't depend on the branch name

### Phase: REVIEW
- Verify tests pass against both repo topologies
- Check that trunk-based finishes work end-to-end (no missing metadata)
- Ensure gitflow finishes still create the expected branch

## Scope
- **In scope:** Fix the finish command to respect `branch_strategy` in repos.yaml
- **Out of scope:** Refactoring the finish command architecture, other finish bugs (155-1, 155-3, 155-4)

## Acceptance Criteria
_(To be defined by TEA during RED phase.)_

Key behaviors the tests should verify:
- [ ] Gitflow repo (pennyfarthing): finish creates a `feat/` branch before archiving
- [ ] Trunk-based repo (orchestrator): finish skips branch creation and records strategy in session
- [ ] Archive path resolution works correctly regardless of branch strategy
- [ ] Story YAML archive contains correct metadata (no broken fields)

## Workflow Tracking
**Workflow:** tdd
**Phase:** red
**Phase Started:** 2026-06-05T06:40:23Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-05 | 2026-06-05T06:40:23Z | 6h 40m |
| red | 2026-06-05T06:40:23Z | - | - |

## Branch Strategy
**Repository:** pennyfarthing (gitflow)
**Branch Strategy:** gitflow (feat/155-2-finish-feat-branch-orchestrator)
**Stack Parent:** none (single story, not stacked)

## Sm Assessment

Story 155-2 is a well-scoped 2-point P1 bug in the finish ceremony. Setup complete:

- **Root cause identified:** the finish flow creates `feat/` branches unconditionally, ignoring the target repo's `branch_strategy` in `repos.yaml`. Trunk-based repos (orchestrator, main-only) get polluted with stray `feat/` refs.
- **Repo / workflow:** `pennyfarthing` (gitflow → PRs target `develop`); `tdd` phased workflow.
- **Branch:** `feat/155-2-finish-feat-branch-orchestrator` created.
- **Jira:** none — kanban-only project, claim explicitly skipped.
- **Scope is tight:** fix is conditional branch creation keyed on `branch_strategy`; refactoring the finish command and sibling finish bugs (155-1/3/4) are explicitly out of scope.

**Handoff to TEA (Igor):** Write failing tests that exercise the finish flow against both topologies — gitflow (`feat/` branch created) and trunk-based (branching skipped, decision recorded). The AC scaffold in this file lists the key behaviors to lock down. Read `pf.git.repos` (`get_repo_config`, `branch_strategy`) for the seam.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Conflict** (blocking): Story 155-2 (gh #15) is already fully delivered by story 153-2
  (commit `934ce2880`, "skip branch creation on trunk-based (main-only) repos in setup & finish").
  Affects nothing — no code change is needed. The entire gh #15 scope is implemented and tested:
  `should_create_branch` (trunk-based→False), `create_feature_branches` skips trunk-based (no stray
  `feat/*`), `story_finish._git_cleanup` skips `checkout`/`pull`/`branch -d` for trunk-based AND
  unresolved-root repos, and `agents/sm-setup.md` reads `branch_strategy` + records the skip.
  Existing test `src/pf/tests/test_153_2_skip_branch_creation.py` (11 tests) passes and covers
  every gh #15 checklist item. Verified no finish-side path (`story_finish.py`, `preflight/finish.py`,
  `sm-finish.md`) creates a branch. *Found by TEA during test design.*
  **Recommendation:** SM should close 155-2 as `delivered_in: 153-2` (duplicate). No RED tests
  written — see Design Deviation below.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **No RED tests written — AC already satisfied in source**
  - Spec source: context-story-155-2.md / gh #15 (skip feat/ branch creation on trunk-based orchestrator in finish)
  - Spec text: "Create the feature branch only on gitflow repos; never touch the orchestrator repo's branches"
  - Implementation: The literal ACs already hold in source (delivered by 153-2). Any AC-literal test
    would be green-on-arrival, violating DEC-TEA-001 (tests must fail before handoff) and the
    false-red gotcha. No meaningful failing test exists because there is no broken behavior to drive.
  - Rationale: Per the `ac-already-satisfied` TEA pattern, when literal ACs already hold I must not
    write vacuous green-on-arrival tests; I reframe to the genuinely-broken property — and here there
    is none. The correct resolution is an SM coordination call (mark duplicate / delivered_in), not a
    Dev implementation phase.
  - Severity: blocking (story should not proceed to Dev as written)
  - Forward impact: Recommend SM mark 155-2 `delivered_in: 153-2` and close. No Dev/Reviewer phases needed.

## TEA Assessment

**Tests Required:** No
**Reason:** Story 155-2 (gh #15) is already fully delivered by story 153-2 (commit `934ce2880`).
The entire scope — skip `feat/` branch creation on trunk-based repos in BOTH setup and finish — is
implemented and covered by 11 passing tests in `test_153_2_skip_branch_creation.py`. There is no
broken behavior left to drive with a failing test; writing one would be green-on-arrival (vacuous).

**Investigation performed:**
- Read `story_finish.py` — `_git_cleanup` already skips `checkout`/`pull`/`branch -d` for
  trunk-based and unresolved-root repos (lines 127–153).
- Read `repos.py` — `should_create_branch` returns False for trunk-based (line 173).
- Read `create_branches.py` — skips trunk-based repos (no stray `feat/*`).
- Confirmed no branch creation in `preflight/finish.py` or `sm-finish.md`.
- Ran `test_153_2_skip_branch_creation.py` → **11 passed** (fix is live).

**Status:** NOT RED — no failing test possible. Story is a duplicate of 153-2.

**Handoff:** Back to SM (Captain Carrot), not Dev. Recommend closing 155-2 as `delivered_in: 153-2`.