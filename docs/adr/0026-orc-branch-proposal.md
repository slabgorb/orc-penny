# Proposal: Trunk-Based Development for Orchestrator Pattern Repositories

**Status:** Accepted
**Date:** 2026-02-15
**Author:** Michael Pursifull
**Scope:** All `*-orc*` / `*-orchestrator` repositories

---

## Thesis

Orchestrator pattern repositories — repos that coordinate work across multiple child
repositories through planning documents, sprint tracking, and session artifacts — should
adopt trunk-based development (single `main` branch) rather than gitflow (long-lived
`develop` + `main`).

**Orchestrator repos are infrastructure, not software.** Like infrastructure-as-code, they
declare the current desired state of a system — what the team is working on, what's done,
what's planned. The team executing the work is the same team consuming the artifacts.
There is no separate audience running on a stable, infrequently-updated branch who
receives batched changes at release intervals.

Plans and coordination documents benefit from rapid convergence around a single source of
truth — **one reality, not a multiverse of parallel, divergent plans.** We do not live in
a world where one group of people needs last week's sprint status while another needs
today's. Everyone needs the current state, immediately. A second long-lived branch for
planning documents creates a parallel reality that no one inhabits and no one consults.

The two long-lived branches in gitflow exist to serve **two different sets of users with
different needs**: developers who want a moving target (`develop`), and consumers/operators
who want stability and receive curated releases (`main`). Orchestrator repos have **one
set of users: the team doing the work.** There is no separate consumer running on a
stable, batched version of planning documents. There are no releases. There is no
publication. The work *is* the consumption. Consolidation and convergence — not isolation
and staging — is what serves this audience.

After this change, the `develop` branch will be **deleted, not merely abandoned.** A stale
`develop` branch is a trap for both humans and LLM agents. If the branch exists, tools
will find it, offer it as a target, and push to it — silently fragmenting the project's
single source of truth. Removing it entirely ensures that any attempt to reference it
produces an immediate, obvious error that forces correction in real time rather than
allowing silent drift to accumulate unnoticed.

Child repositories (frameworks, applications, libraries) retain whatever branching strategy
suits their content and audience.

---

## Orchestrator Repository Inventory

### Branch Status Across All Orchestrator Repos

| Repository | Org | GitHub Default | Has `main` | Has `develop` | Most-Used Branch | Proposed Default | Change Required |
|---|---|---|---|---|---|---|---|
| **pennyfarthing-orchestrator** | slabgorb | `develop` | Yes | Yes | `main` (direct pushes + PRs) | `main` | Set default to `main`, delete `develop` |
| **conductor-orchestrator** | slabgorb | `develop` | Yes | Yes | `develop` (direct pushes + PRs) | `main` | FF `main` to `develop`, set default, delete `develop` |
| **clip-orchestrator** | slabgorb | `develop` | **No** | Yes | `develop` (only branch) | `main` | Rename `develop` → `main`, set default |
| **poller-orchestrator** | slabgorb | `main` | Yes | No | `main` | `main` | None |
| **bmad-orc** | collaborator | `main` | Yes | No | `main` | `main` | None |
| **i-orc** | collaborator | `main` | Yes | No | `main` | `main` | None |

> `i-orc-before` (local only, not a git repo) is excluded — it is a backup directory, not
> an orchestrator repo.

**4 of 6 orchestrator repos are already trunk-based or have no `develop` branch.** The two
that do (`pennyfarthing-orchestrator` and `conductor-orchestrator`) have both organically
abandoned one of their two branches. `clip-orchestrator` has only `develop` and no `main`
at all — it just needs a rename.

---

## Supporting Statistics

### pennyfarthing-orchestrator (slabgorb)

| Metric | Value |
|--------|-------|
| GitHub default branch | `develop` |
| Total commits on `main` | 519 |
| Total commits on `develop` | 338 |
| Commits on `main` not on `develop` | **181** |
| Commits on `develop` not on `main` | **0** |
| Last commit on `main` | 2026-02-14 |
| Last commit on `develop` | 2026-02-09 (5 days stale) |
| Direct pushes to `main` (bypassing `develop`) | ~90 |
| PRs targeting `develop` | 16 |
| PRs targeting `main` | 5 |
| Contributors on divergent commits | Keith: 174, Mike: 7 |

`develop` contains zero unique commits. All 181 divergent commits are on `main`. The
GitHub default points to a branch that is 181 commits behind the actual working branch.

**Content of the 181 divergent commits on `main`:**

| Type | Count | % |
|------|-------|---|
| Sprint tracking (`chore(sprint):`) | ~140 | 77% |
| Documentation (ADRs, PRDs, planning) | ~15 | 8% |
| Features (orchestrator-level) | ~10 | 6% |
| Merge commits from PRs | 7 | 4% |
| Fixes and housekeeping | ~9 | 5% |

**How work actually flows:**
```
Sprint tracking:  pushed directly to main → develop never updated
Feature work:     branch → PR → develop → merged to main → develop never synced back
```

### conductor-orchestrator (slabgorb)

| Metric | Value |
|--------|-------|
| GitHub default branch | `develop` |
| Total commits on `develop` | 551 |
| Total commits on `main` | 288 |
| Commits on `develop` not on `main` | **263** |
| Commits on `main` not on `develop` | **0** |
| Last commit on `develop` | 2026-02-08 |
| Last commit on `main` | 2025-12-14 (**2 months stale**) |
| `main` is strict ancestor of `develop` | Yes (clean fast-forward) |
| Direct pushes to `develop` (non-merge) | 239 |
| PRs targeting `develop` | 29 |
| PRs targeting `main` | 2 |
| Contributors on divergent commits | Keith: 224, Mike: 15 |

The mirror image of pennyfarthing: here `develop` is active and `main` has not been
touched in two months. 263 commits sit on `develop` that have never been promoted. The
develop→main promotion step simply isn't happening because there is no meaningful gate
for sprint tracking content.

### clip-orchestrator (slabgorb)

| Metric | Value |
|--------|-------|
| GitHub default branch | `develop` |
| Has `main` branch | **No** |
| Total commits on `develop` | 23 |
| PRs targeting `develop` | 1 |
| Total branches | 2 (`develop`, `chore/trigger-publish`) |

Small repo, only `develop` exists. No `main` at all. Needs a rename rather than a merge.

### poller-orchestrator (slabgorb) — already compliant

| Metric | Value |
|--------|-------|
| GitHub default branch | `main` |
| Has `develop` | No |
| Total commits on `main` | 28 |
| PRs targeting `main` | 11 |

Already trunk-based. No changes needed.

### bmad-orc (collaborator) — already compliant

| Metric | Value |
|--------|-------|
| GitHub default branch | `main` |
| Has `develop` | No |
| Total commits on `main` | 34 |
| PRs targeting `main` | 5 |

Already trunk-based. No changes needed.

### i-orc (collaborator) — already compliant

| Metric | Value |
|--------|-------|
| GitHub default branch | `main` |
| Has `develop` | No |
| Total commits on `main` | 1 |
| PRs | 0 |

Already trunk-based. No changes needed.

### Aggregate Statistics

| Metric | Value |
|--------|-------|
| Total orchestrator repos audited | 6 |
| Already trunk-based (`main` only) | 3 (50%) |
| Have `develop` but abandoned one branch | 2 (33%) |
| Have `develop` with no `main` at all | 1 (17%) |
| Repos achieving functioning gitflow | **0 (0%)** |
| Total commits stranded on non-default branches | **444** (181 + 263) |
| Total direct pushes bypassing the PR branch | **~329** (~90 + 239) |
| Repos where `develop` → `main` promotion is current | **0** |

No orchestrator repo in the inventory has ever maintained a functioning two-branch
workflow. Every repo that has both branches has abandoned one of them. The two-branch
model is not failing occasionally — it is failing universally across this repo type.

---

## Rationale

### 1. One team, one truth — not two audiences

Gitflow separates `develop` from `main` because different groups need different things
from the same repository. A development team iterates rapidly on `develop`; end users
receive curated, tested releases on `main`. The two branches exist because the two
audiences have fundamentally different tolerances for change frequency and stability.

Orchestrator repos have **one group**: the team executing the sprint. Every consumer of
sprint YAML, session files, and planning docs needs the same thing — the current state,
right now. Nobody is running on a stable, long-lived set of planning documents that should
only change at release boundaries. There is no release. There is no publication audience.
A second long-lived branch creates a parallel version of reality that no one lives in.

### 2. Rapid convergence, like infrastructure-as-code

Infrastructure-as-code repos use trunk-based development because infrastructure describes
**what is**, not **what might be released someday**. You don't stage a Terraform plan on
`develop` for weeks before promoting it to `main`. You converge on the desired state as
fast as possible because the whole point is that the repo reflects reality.

Sprint tracking and coordination documents have the same property. A story marked
complete, an epic archived, a session recorded — these describe what happened and what's
planned. Staging them on a secondary branch before "releasing" them adds latency with zero
benefit. Like infrastructure, we do not live in a multiverse of parallel, long-lived but
divergent plans. Plans and project tracking benefit from feature branches and rapid
convergence around one reality — not two long-lived branches.

### 3. The evidence: gitflow has 0% adoption across orchestrator repos

Across all six orchestrator repos:
- **0** maintain a functioning develop→main promotion cadence
- **3** have already organically adopted trunk-based (main-only)
- **2** have both branches but abandoned one (444 stranded commits between them)
- **1** has only `develop` and never created `main`
- **329+** commits were pushed directly to the active branch, bypassing the PR target

The team has converged on single-branch development in every case. The proposal formalizes
what is already happening universally.

### 4. Stale branches are traps for LLM agents and humans

Claude Code, Cursor, and other AI coding assistants read branch lists and configuration
to determine where to push. A `develop` branch that exists but is stale will be offered
as a target, selected by default (especially when configured as the GitHub default), and
pushed to — silently creating drift that nobody notices until a merge conflict surfaces
or someone wonders why their changes aren't visible.

The fix is not documentation or convention — it is **branch deletion**. If `develop`
does not exist, any attempt to push to it produces an immediate, loud error. Both humans
and LLM agents can act on "branch not found." Neither can act on "branch exists but you
shouldn't use it."

### 5. Child repos are different (and stay different)

Framework and application repos like `pennyfarthing/` have builds, tests, npm publishing,
and external consumers. They serve two audiences: developers iterating on features, and
users installing a published package. Gitflow or a similar two-branch strategy is
appropriate there because the branch separation serves real, distinct audiences with
different needs. This proposal applies only to the orchestrator layer.

---

## Changes if Accepted

### pennyfarthing-orchestrator

| # | Action | Detail | Safety |
|---|--------|--------|--------|
| 1 | Set `main` as GitHub default | `gh repo edit --default-branch main` | No data loss |
| 2 | Move branch protection to `main` | Via GitHub settings (if any exist on `develop`) | No data loss |
| 3 | Delete `develop` (remote) | `git push origin --delete develop` | 0 unique commits on `develop` — verified safe |
| 4 | Delete `develop` (local) | `git branch -d develop` | Local only |
| 5 | Update pennyfarthing config | Change gitStatus `Main branch` from `develop` to `main` | Config update |
| 6 | Update CLAUDE.md | Document trunk-based policy | Documentation |

### conductor-orchestrator

| # | Action | Detail | Safety |
|---|--------|--------|--------|
| 1 | Fast-forward `main` to `develop` | `git checkout main && git merge --ff-only develop` | `main` is strict ancestor — no conflicts |
| 2 | Push updated `main` | `git push origin main` | Fast-forward only |
| 3 | Set `main` as GitHub default | `gh repo edit --default-branch main` | No data loss |
| 4 | Move branch protection to `main` | Via GitHub settings | No data loss |
| 5 | Delete `develop` (remote) | `git push origin --delete develop` | All commits preserved on `main` after FF |
| 6 | Delete `develop` (local) | `git branch -d develop` | Local only |
| 7 | Update CLAUDE.md / configs | Document trunk-based policy | Documentation |

### clip-orchestrator

| # | Action | Detail | Safety |
|---|--------|--------|--------|
| 1 | Rename `develop` → `main` | `gh repo rename-branch develop main` (or via GitHub UI) | Rename preserves all history |
| 2 | Set `main` as GitHub default | Automatic with rename | No data loss |
| 3 | Update any local clones | `git fetch --prune && git checkout main` | Local only |

### poller-orchestrator, bmad-orc, i-orc

**No changes required.** Already trunk-based on `main` with no `develop` branch.

---

## General Policy (All Future Orchestrator-Pattern Repos)

| # | Policy |
|---|--------|
| 1 | Orchestrator-pattern repos use `main` only — no long-lived `develop` branch |
| 2 | Feature branches for multi-commit work remain encouraged and are the normal workflow |
| 3 | PRs target `main` directly |
| 4 | `develop` must not exist — not as a stale branch, not as a convention. Its absence is the enforcement mechanism |
| 5 | Child/submodule repos choose their own branching strategy independently |
| 6 | Document the convention in each orchestrator repo's CLAUDE.md |

---

## What This Does NOT Change

- Child repo branching strategies (unchanged — gitflow or similar where appropriate)
- Use of feature branches for non-trivial work (still encouraged)
- PR review requirements (still enforced where configured)
- CI/CD pipelines in child repos (unaffected)
- Any repo that is not an orchestrator-pattern repo

---

## Inline ADR

### ADR-0026: Trunk-Based Development for Orchestrator Repos

**Status:** Accepted
**Date:** 2026-02-15
**Deciders:** Michael Pursifull

#### Context

The slabgorb organization operates several orchestrator-pattern repositories that
coordinate work across child software repos. These orchestrator repos contain sprint
tracking YAML, planning documents, session artifacts, and coordination configuration —
not compiled software.

Several of these repos were initialized with a gitflow branching model (`develop` +
`main`), matching the child software repos they orchestrate. Over time, every orchestrator
repo that had both branches abandoned one of them. Across the inventory:

- 444 commits are stranded on non-default branches
- 329+ commits were pushed directly to the working branch, bypassing the designated PR
  target
- 0 of 6 repos maintain a functioning develop→main promotion cadence

The two-branch model has a 0% success rate for this repository type.

#### Decision

Orchestrator-pattern repos adopt trunk-based development:

- **Single long-lived branch:** `main`
- **`develop` is deleted**, not abandoned. Branch absence is the enforcement mechanism.
- **Feature branches** remain the normal workflow for multi-commit changes
- **PRs target `main`** directly
- **Child repos are unaffected** and retain their own branching strategy

#### Consequences

**Positive:**
- Aligns policy with observed practice across all 6 repos
- Eliminates 444-commit class of silent drift
- Prevents LLM agents from targeting stale branches
- Matches established IaC branching convention
- Reduces cognitive overhead (one branch to think about)

**Negative:**
- Requires one-time migration for 3 repos (pennyfarthing, conductor, clip)
- Teams must use feature branches for any work they want reviewed before merge (this is
  already the practice)

**Neutral:**
- No impact on child repo workflows
- No impact on CI/CD (orchestrator repos have no build pipelines)

#### Alternatives Considered

1. **Keep gitflow, enforce discipline:** Rejected. Six repos, zero successes. The model
   doesn't fit the content type.
2. **Keep `develop` but sync it regularly:** Rejected. Adds maintenance burden for a
   branch nobody consults. A synced `develop` that mirrors `main` has no purpose.
3. **Use `develop` as trunk, delete `main`:** Rejected. `main` is the conventional default
   for trunk-based development and matches the 3 repos already in compliance.
