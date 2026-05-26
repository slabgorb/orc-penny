# Story 153-2 Context

## Title
Skip branch creation on orchestrator (main-only) repos during story setup and finish

## Type
bug (P2, 2 points, tdd workflow)

## Repo
`pennyfarthing/` (inlined framework source). Base branch: `develop`.

## Problem
The framework assumes every repo uses a feature-branch workflow. Orchestrator-type repos (e.g. `pennyfarthing-orchestrator` at `.`) are trunk-based with only a `main` branch. When `sm-setup` and `sm-finish` run against such a repo they attempt to create `feat/{STORY_ID}-{SLUG}` branches, polluting the repo with stray feature branches and confusing the git workflow.

Symptom (reported by downstream `oq-1`, `oq-2`): orchestrator repos accumulate `feat/*` branches that no PR flow ever consumes, because the repo never branches for story coordination.

Root cause: branch-creation logic does not consult the target repo's `branch_strategy` from `repos.yaml` before creating a branch.

## Scope

**In scope:**
1. Both `sm-setup` and `sm-finish` read the target repo's `branch_strategy` from `.pennyfarthing/repos.yaml` via existing `pf.git.repos.get_repo_config()`.
2. When `branch_strategy: trunk-based`, skip branch creation entirely (no `git checkout -b`, no `git branch`) and exit cleanly (exit 0).
3. The session file still records the branch-strategy decision (e.g. `**Branch Strategy:** trunk-based (branching skipped)` vs `gitflow (feat/{story}-{slug})`).
4. Repos with `branch_strategy: gitflow` (or `feature`) keep creating feature branches exactly as before.

**Out of scope:**
- Changing the `branch_strategy` field schema or values in `repos.yaml`.
- Altering stacked-PR behavior (ADR-0036) — it must remain unchanged for gitflow repos.
- Session-file location/format changes (that was story 153-1).
- Context-file creation behavior (that is story 153-6).

## Acceptance Criteria

1. **Read repo topology:** `sm-setup` and `sm-finish` read `branch_strategy` from `repos.yaml` for the target repo.
2. **Skip for trunk-based:** When `branch_strategy: trunk-based`, no branch is created and no git checkout occurs.
3. **Session tracking:** The session file documents the branch-strategy decision in both the skip and the create case.
4. **Preserve gitflow:** `gitflow`/`feature` repos still get `feat/{story-id}-{slug}` branches as before.
5. **Stacked repos unaffected:** Stacked-PR logic (ADR-0036) continues to work for gitflow repos.
6. **No errors:** Both setup and finish complete with exit code 0 when branching is skipped.

## Approach Hints (non-binding)

- `branch_strategy` already exists in `.pennyfarthing/repos.yaml` (`trunk-based` for orchestrator, `gitflow` for `pennyfarthing`) and is surfaced by `pf.git.repos.get_repo_config()` — no new infra required.
- Branch creation is triggered during sm-setup (story activation) and touched again during sm-finish (cleanup/checkout). Locate the branch-creation call site under `pennyfarthing-dist/src/pf/` (sprint/story flow) and/or the `sm-setup.md` / `sm-finish.md` agent templates.
- Default when `branch_strategy` is absent or repo config is missing: treat as `gitflow` (preserve current behavior) so the fix is purely additive for known repos.

## Test Strategy (RED targets)

1. sm-setup on a trunk-based repo → no branch created, session file written, exit 0.
2. sm-setup on a gitflow repo → `feat/{story}-{slug}` branch created as before (regression guard).
3. sm-finish on a trunk-based repo → no errors, session archived without branch operations.
4. Session file reflects the correct branch-strategy decision in both cases.
5. Stacked-PR path for gitflow repos is exercised and unaffected (guard test).

## Out-of-band notes

- Part of the epic 153 framework-reliability sweep sourced from downstream usage (`oq-1`, `oq-2`).
- Sibling stories: 153-1 (session-file location, done), 153-4 (shard-file command fixes, done), 153-6 (missing context-file creation, backlog — same setup pipeline as the gap that delayed this story's RED phase).
