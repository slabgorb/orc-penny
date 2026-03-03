---
stepsCompleted:
  - step-01-initialization
  - step-02-discovery
  - step-03-success-criteria
  - step-04-user-journeys
  - step-05-domain-skipped
  - step-06-innovation-skipped
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
inputDocuments:
  - .pennyfarthing/repos.yaml
  - pennyfarthing/pennyfarthing-dist/guides/worktree-mode.md
  - pennyfarthing/pennyfarthing-dist/src/pf/git/worktree.py
documentCounts:
  briefs: 0
  research: 0
  projectDocs: 3
workflowType: 'prd'
classification:
  projectType: developer_tool
  domain: general
  complexity: medium
  projectContext: brownfield
---

# Product Requirements Document - Multi-Repo Worktree Support

**Author:** keithavery
**Date:** 2026-03-03

## Executive Summary

Pennyfarthing's orchestrator pattern manages multiple git repos under a single project root, configured via `repos.yaml`. Developers need to work on parallel tasks (bug fixes, PR reviews, concurrent stories) without cloning the entire project. Git worktrees solve this, but the current `pf git worktree` implementation lacks safe cleanup, clear status reporting, and Claude Code integration.

This PRD defines enhancements to the existing worktree commands to make multi-repo worktrees reliable for consumer developers and framework contributors. The primary audience is consumer developers using Pennyfarthing on their own projects. Secondary audiences are framework contributors and the dogfooding setup where `pennyfarthing/` is inlined with symlinks.

**Differentiator:** Single-command worktree management across multiple repos with safe-by-default cleanup that prevents silent work loss.

## Success Criteria

### User Success

- A consumer developer who has never used the feature creates a worktree, does work in it, and cleans it up without reading source code or asking for help
- No work is silently lost — cleanup warns about uncommitted changes and unmerged branches before removing anything
- The worktree feels like a normal checkout: `pf` commands work, sessions are isolated, tests run

### Business Success

- Lowers the barrier for contributors — someone helping with a bug fix doesn't need to clone a second copy of the repo
- Reduces context-switching friction when juggling parallel stories

### Technical Success

- Single `pf git worktree create` command handles all repos defined in `repos.yaml`
- Consumer projects: worktrees work without symlink rewiring (`.pennyfarthing/` is plain files)
- Dogfooding: worktrees rewire `.pennyfarthing/` symlinks to point at the worktree'd framework
- Cleanup is safe-by-default with dirty state warnings
- No orphaned git worktree references after removal

### Measurable Outcomes

- A new contributor can create, use, and clean up a worktree in under 5 minutes with no assistance
- Zero incidents of silent work loss from worktree cleanup
- All existing `pf` commands function correctly inside a worktree

## User Journeys

### Journey 1: Dana — Consumer Developer, Context Switch

Dana is building a feature in her project's API repo when a teammate pings her: "Can you review my PR? There's a merge conflict with your branch." She can't switch branches — she's mid-work with uncommitted changes.

She runs `pf git worktree create wt-review feat/teammate-fix`. A new worktree appears with both her API and UI repos checked out to the right branch. She `cd`s in, reviews the code, pushes a fix, and runs `pf git worktree remove wt-review`. Back to her feature branch in under 10 minutes. She never stashed, never cloned, never lost context.

**Reveals:** Create must be fast and obvious. Remove must confirm it's clean. `pf` commands must work inside the worktree without configuration.

### Journey 2: Chris — Contributor, Drive-By Fix

Chris saw a bug in Pennyfarthing's sprint validation and wants to help. He already has `pf-2` cloned from last month. Rather than figuring out what state his checkout is in, he creates a worktree: `pf git worktree create wt-bugfix fix/sprint-validation`.

He makes the fix, runs tests, commits, pushes, opens a PR. Then `pf git worktree remove wt-bugfix`. He didn't touch his main checkout. He didn't have to remember what branch he was on before.

**Reveals:** Worktree create must work even if the main checkout is dirty. The contributor shouldn't need to understand the orchestrator's internal topology — just which repo they're fixing.

### Journey 3: Keith — Dogfooding, Parallel Stories

Keith is mid-story on a workflow enhancement when a P0 bug comes in. He creates a worktree for the hotfix. In the worktree, `.pennyfarthing/` symlinks need to resolve to the worktree'd copy of `pennyfarthing/pennyfarthing-dist/`, not the original. He fixes the bug, the session file tracks that it's a worktree context, and his main story is untouched.

**Reveals:** Dogfooding requires symlink rewiring. Session isolation must be airtight — two stories, two sessions, no cross-contamination. This is Growth scope, not MVP.

### Journey 4: Dana, Two Weeks Later — The Returner

Dana created `wt-review` two weeks ago and forgot about it. She runs `pf git worktree list` and sees it. She tries `pf git worktree remove wt-review` and gets:

```
Warning: wt-review has uncommitted changes in api (2 files modified)
Warning: Branch feat/teammate-fix has not been merged
Remove anyway? [y/N]
```

She realizes she left debug logging in there. She goes in, cleans it up, pushes, and then removes. Her work wasn't silently destroyed.

**Reveals:** List and status must surface staleness. Remove must be safe-by-default. The warning needs to be specific enough to act on — not just "dirty," but what is dirty and where.

### Journey Requirements Summary

| Capability | Revealed By | Scope |
|---|---|---|
| Multi-repo worktree create from `repos.yaml` | Dana, Chris | MVP |
| Works with dirty main checkout | Chris | MVP |
| `pf` commands work inside worktrees | Dana | MVP |
| Safe remove with dirty/unmerged warnings | Dana (Returner) | MVP |
| Worktree list with status | Dana (Returner) | MVP |
| Session file worktree context | Dana, Keith | MVP |
| Symlink rewiring for dogfooding | Keith | Growth |
| Specific warnings (which files, which repo) | Dana (Returner) | MVP |

## Product Scope & Phased Development

### MVP Strategy

**Approach:** Problem-solving MVP — the minimum that makes a consumer developer say "this is useful" for parallel work across repos.
**Resource:** Solo developer, one sprint.

### Phase 1 — MVP

| Feature | Journey | Dependency |
|---|---|---|
| Enhanced `create` — multi-repo from `repos.yaml` | Dana, Chris | None (refine existing) |
| Safe `remove` — dirty/unmerged warnings, confirm prompt | Dana (Returner) | None (enhance existing) |
| Enhanced `list` — show branch, dirty state per repo | Dana (Returner) | None (enhance existing) |
| Session file worktree context block | Dana | Create must write it |
| Updated `worktree-mode.md` guide | All | After implementation |

**Core Journeys Supported:** Dana (context switch), Chris (drive-by fix), Dana (returner cleanup)

### Phase 2 — Growth

| Feature | Journey | Dependency |
|---|---|---|
| Claude Code hook integration (`WorktreeCreate`/`WorktreeRemove`) | Dana, Chris | MVP create/remove |
| Dogfooding symlink rewiring | Keith | MVP create |
| `status` with health/staleness indicators | Dana (Returner) | MVP list |

### Phase 3 — Vision

| Feature | Dependency |
|---|---|
| Auto-cleanup on `pf sprint story finish` | Phase 1 remove |
| Stale worktree pruning (age-based) | Phase 2 status |
| Shared `node_modules` | Only if pain emerges |

### Risk Mitigation

**Technical:** Symlink rewiring (Phase 2) is the hardest part — relative vs absolute paths, what happens when the framework worktree is removed but the orchestrator worktree remains. Mitigated by deferring to Growth.
**Market:** Low — solves a concrete workflow pain. No validation needed.
**Resource:** Solo developer. MVP scoped for one sprint. Growth is incremental.

## Developer Tool Specific Requirements

### Technical Architecture

- **Language:** Python (Click CLI), consistent with existing `pf git` command group
- **Installation:** Ships as part of `pf` — no additional dependencies beyond git 2.15+
- **Configuration:** Reads `repos.yaml` for repo topology — no new config files

### Claude Code Integration

- Implement `WorktreeCreate` and `WorktreeRemove` hooks in `.pennyfarthing/settings.yaml` template
- When Claude Code's `EnterWorktree` fires, delegate to `pf git worktree create` for multi-repo awareness
- Worktrees created by either mechanism visible to `pf git worktree list`
- Session file worktree context block written regardless of creation method

### CLI Surface

| Command | Behavior | Status |
|---|---|---|
| `pf git worktree create <name> <branch>` | Create worktrees for repos in `repos.yaml` | Exists, enhance |
| `pf git worktree remove <name>` | Safe remove with dirty/unmerged warnings | Exists, enhance |
| `pf git worktree list` | List all worktrees with status | Exists, enhance |
| `pf git worktree status` | Detailed health per worktree | Exists, keep |

### Documentation

- Update `worktree-mode.md` guide with multi-repo consumer workflow
- Add quick-start examples for common scenarios (context switch, drive-by fix)
- Document Claude Code hook integration

## Functional Requirements

### Worktree Creation

- **FR1:** Developer can create a named worktree that spans all repos defined in `repos.yaml` with a single command
- **FR2:** Developer can create a worktree targeting specific repos (filter by name or type) instead of all repos
- **FR3:** Developer can create a worktree from an existing branch or have a new branch created automatically
- **FR4:** Developer can create a worktree even when the main checkout has uncommitted changes
- **FR5:** Developer receives clear output showing which repos had worktrees created, the paths, and the branch name

### Worktree Removal

- **FR6:** Developer can remove a named worktree and all its repo checkouts with a single command
- **FR7:** Developer is warned before removal if any repo in the worktree has uncommitted changes, with specifics (which repo, how many files)
- **FR8:** Developer is warned before removal if any branch in the worktree has not been merged, with specifics (which repo, which branch)
- **FR9:** Developer must explicitly confirm removal when warnings are present
- **FR10:** Developer can force-remove a worktree to bypass warnings when intentional

### Worktree Discovery

- **FR11:** Developer can list all active worktrees with branch and dirty state per repo
- **FR12:** Developer can view detailed status of a specific worktree including per-repo branch, uncommitted file count, and merge state
- **FR13:** Developer can see which session file (if any) is associated with each worktree

### Session Integration

- **FR14:** When a worktree is created, the system can write a worktree context block to the active session file
- **FR15:** Agents can detect they are operating in a worktree context by reading the session file
- **FR16:** `pf` commands resolve correctly when run from within a worktree directory

### Claude Code Integration

- **FR17:** When Claude Code's `EnterWorktree` is triggered, the system delegates to multi-repo worktree creation
- **FR18:** Worktrees created via Claude Code hooks are visible to `pf git worktree list`
- **FR19:** When Claude Code cleans up a worktree, the system delegates to safe multi-repo removal

### Dogfooding Support

- **FR20:** In dogfooding topology, worktree creation rewires `.pennyfarthing/` symlinks to point at the worktree'd framework source
- **FR21:** The system detects whether the current project uses symlinked `.pennyfarthing/` (dogfooding) or plain files (consumer) and behaves accordingly
- **FR22:** Worktree removal in dogfooding mode restores no residual symlink state

### Documentation

- **FR23:** Developer can follow a guide to create, use, and clean up worktrees for common scenarios
- **FR24:** Guide covers both consumer and contributor workflows with quick-start examples

**Scope mapping:** FR1-16, FR23-24 = MVP. FR17-19 = Phase 2 (Claude Code integration). FR20-22 = Phase 2 (dogfooding).

## Non-Functional Requirements

### Reliability

- **NFR1:** Worktree removal never deletes uncommitted changes without explicit user confirmation
- **NFR2:** If worktree creation fails partway through (e.g., second repo fails), the system reports what succeeded and what failed — no silent partial state
- **NFR3:** `pf git worktree list` accurately reflects actual filesystem and git state — no stale entries showing worktrees that don't exist
- **NFR4:** After worktree removal, `git worktree prune` is run to prevent orphaned git references

### Integration

- **NFR5:** `pf git worktree` commands work with any valid `repos.yaml` configuration, not just known project layouts
- **NFR6:** Session file worktree context follows the existing session schema — no new file formats
- **NFR7:** Claude Code hooks (`WorktreeCreate`/`WorktreeRemove`) receive enough context to delegate to `pf git worktree` without additional user input
