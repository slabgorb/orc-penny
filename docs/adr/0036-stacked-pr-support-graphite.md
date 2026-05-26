# ADR-0036: Stacked PR Support via Graphite for Consumer Repos

**Status:** Accepted
**Date:** 2026-03-11
**Author:** Architect Agent (Paul Atreides)
**Context:** Consumer repos (orc-ax) need inter-story dependency chains where Story B builds on Story A's code

## Context

Consumer repos like orc-ax develop features across multiple stories that form dependency chains. Story 5-1 (core types) must land before Story 5-2 (query parser) which must land before Story 5-3 (detection engine). Each story produces a PR.

Currently PF creates one branch per story targeting `develop`, with no awareness of ordering. This forces teams to either:

1. **Wait serially** — don't start Story B until Story A merges (slow, wastes developer time)
2. **Branch manually** — create Story B's branch from Story A's branch, manually retarget when A merges (error-prone, no PF tracking, painful rebase chains)

Stacked PRs solve this by letting multiple PRs form an ordered chain where each PR targets its parent's branch. When the bottom PR merges, children automatically retarget to the integration branch.

### Tools Evaluated

| Tool | Model | Retarget | Rebase chain | Vendor dependency |
|------|-------|----------|--------------|-------------------|
| `gh` (raw) | Manual | Manual | Manual | None |
| Graphite (`gt`) | Branch-per-PR | Automatic | One command | Account + CLI |
| `spr` | Commit-per-PR | Automatic | Automatic | None |

**spr** maps poorly to PF's model (one story = one branch, not one commit). **Graphite** maps directly: each story gets a branch, branches form a chain, `gt sync` handles the mechanics.

## Decision

**Require Graphite CLI (`gt`) for repos that declare `pr_strategy: stacked`.** PF orchestrates the workflow (story ordering, session tracking, gates). Graphite handles the git mechanics (retargeting, rebasing chains, merge ordering).

Standard repos are unaffected — `pr_strategy: standard` remains the default.

## Design

### 1. repos.yaml Schema Extension

```yaml
repos:
  consumer-project:
    path: consumer-project
    type: platform
    pr_strategy: stacked        # "standard" (default) or "stacked"
    stack_tool: graphite         # Tool managing the stack (only "graphite" supported)
    branch_strategy: gitflow
    default_branch: develop
```

New fields on `RepoConfig`:
- `pr_strategy: str` — `"standard"` (default) or `"stacked"`
- `stack_tool: str` — `"graphite"` (only supported value for now)

### 2. Story Dependency in Sprint YAML

```yaml
stories:
  - id: 5-1
    title: Core types crate
    status: in_progress
    branch: feat/DPGD-100-core-types

  - id: 5-2
    title: Query parser crate
    depends_on: 5-1              # Stacks on 5-1
    branch: feat/DPGD-101-query-parser

  - id: 5-3
    title: Detection engine
    depends_on: 5-2              # Chains: 5-1 -> 5-2 -> 5-3
    branch: feat/DPGD-102-detection
```

`depends_on` is a single story ID (not a list). PF validates that the dependency exists and is in the same epic. Circular dependencies are rejected at validation time.

### 3. Workflow Integration

#### SM Setup (branch creation)

| Condition | Action |
|-----------|--------|
| `pr_strategy: standard` | `git checkout -b feat/STORY develop` (unchanged) |
| `pr_strategy: stacked`, no `depends_on` | `gt create feat/STORY` (stack root, from trunk) |
| `pr_strategy: stacked`, has `depends_on` | Checkout parent branch, then `gt create feat/STORY` |

```bash
# Stacked setup with dependency
PARENT_BRANCH=$(pf sprint story field "$PARENT_ID" branch)
git checkout "$PARENT_BRANCH"
gt create "feat/${JIRA_KEY}-${SLUG}"
```

Session file records the stack position:
```markdown
**Stack Parent:** 5-1 (feat/DPGD-100-core-types)
```

#### SM Finish (PR creation and merge)

| Condition | Action |
|-----------|--------|
| `pr_strategy: standard` | `gh pr create --base develop` (unchanged) |
| `pr_strategy: stacked` | `gt submit` (Graphite sets base from stack metadata) |

Post-merge cleanup:
```bash
# After any stack PR merges
gt sync    # Rebases and retargets all children
```

SM-finish runs `gt sync` after merge regardless of position in stack, to keep dependents current.

### 4. New Gate: `stack-ready`

Blocks merge of a stacked PR if its parent story's PR is not yet merged. Prevents out-of-order merges that create broken intermediate states.

```yaml
GATE_RESULT:
  status: fail
  gate: stack-ready
  message: "Parent story 5-1 PR not yet merged"
  recovery:
    - "Merge parent PR first, or remove depends_on if no longer needed"
```

Auto-pass conditions:
- Story has no `depends_on` (stack root)
- Parent story status is `done`
- Repo `pr_strategy` is not `stacked`

### 5. Health Check

`pf health-check` adds a check when any repo declares `pr_strategy: stacked`:

```
[stacked-pr] gt CLI installed: yes/no
[stacked-pr] gt authenticated: yes/no
[stacked-pr] gt repo initialized: yes/no (checks .graphite_info)
```

Fail loudly if `gt` is missing — don't silently fall back to `gh`.

### 6. Validation

Sprint YAML validator gains:
- `depends_on` must reference an existing story ID in the same sprint
- No circular dependencies (topological sort check)
- If repo has `pr_strategy: stacked`, warn on stories without `depends_on` that aren't explicitly stack roots

## Implementation

| Component | Change | File |
|-----------|--------|------|
| `RepoConfig` dataclass | Add `pr_strategy`, `stack_tool` | `pf/git/repos.py` |
| `_parse_repo_entry` | Parse new fields | `pf/git/repos.py` |
| SM setup agent | Stacked branch creation flow | `agents/sm-setup.md` |
| SM finish agent | Stacked PR submission flow | `agents/sm-finish.md` |
| Sprint YAML schema | `depends_on` field on stories | `schemas/session-schema.md` |
| `story_add.py` | `--depends-on` flag | `pf/sprint/story_add.py` |
| Sprint validator | Dependency cycle detection | `pf/sprint/validate_cmd.py` |
| `stack-ready` gate | New gate file | `gates/stack-ready.md` |
| Health check | `gt` presence verification | `pf/health/` |

## What PF Does NOT Do

- **No reimplementing retarget/rebase** — Graphite owns all git chain mechanics
- **No Graphite cloud API integration** — CLI-only interaction via `gt` commands
- **No forcing stacked on all repos** — opt-in per repo via `pr_strategy`
- **No multi-parent dependencies** — one parent per story (linear chains, not DAGs)

## Consequences

### Positive

- Stories in a dependency chain can proceed in parallel
- Graphite handles painful git mechanics (retarget, rebase, ordering)
- Opt-in — zero impact on repos using standard PRs
- Stack position visible in session files for agent awareness
- Gate prevents out-of-order merges

### Negative

- External tool dependency (Graphite CLI + free account)
- All team members working on stacked repos need Graphite access
- `gt sync` adds a post-merge step (SM-finish handles automatically)
- Graphite's branch metadata (`.graphite_info`) added to repos

## Alternatives Considered

### Build our own with `gh`

Reimplement retarget + rebase chain logic using raw `gh` and `git` commands. Rejected: significant complexity for something Graphite already handles reliably. Would need to track parent-child state ourselves, handle rebase conflicts in chains, and retarget on merge — all solved problems.

### Use `spr`

spr's one-commit-per-PR model doesn't map to PF's one-branch-per-story model. Would require rethinking how stories map to git artifacts. Rejected: too much impedance mismatch.

### Abstract behind pluggable backend

Support both Graphite and spr behind an interface. Rejected for now: YAGNI. Only Graphite fits. Can add a second backend later if needed — the `stack_tool` field in repos.yaml provides the extension point.
