# ADR-0033: Multi-Repo Worktree Safety and Session Integration

**Status:** Proposed
**Date:** 2026-03-03
**Author:** architect
**PRD:** `sprint/planning/worktree-prd.md`

## Context

Pennyfarthing's orchestrator manages multiple git repos under a single project root, configured via `repos.yaml`. The existing `pf git worktree` commands (`create`, `remove`, `list`, `status`) in `pf/git/worktree.py` provide basic multi-repo worktree management but have three critical gaps:

1. **Unsafe removal** — `remove_worktree()` force-removes without checking for uncommitted changes or unmerged branches. Silent work loss is the worst failure mode for a developer tool.
2. **No session integration** — Worktree creation doesn't write context to the session file, so agents can't detect they're operating in a worktree. The `show_worktree_status()` function searches for `worktree: {name}` in session files, but nothing ever writes it.
3. **Raw output** — `list_worktrees()` dumps `git worktree list` output without per-repo dirty state or branch info.

The PRD defines 24 functional requirements across 3 phases (MVP, Growth, Vision). This ADR covers **MVP scope** (FR1-16, FR23-24) — the minimum that makes multi-repo worktrees reliable for consumer developers.

## Decision Drivers

1. **Safety first** — A developer tool that silently destroys work is worse than no tool at all
2. **Single module** — All worktree logic in one file (`worktree.py`) for discoverability
3. **No new dependencies** — stdlib only (subprocess, pathlib, shutil)
4. **repos.yaml driven** — Works with any valid topology, not just this project's layout
5. **Session is optional** — Worktrees work without an active session; session write is best-effort
6. **Phase 2 deferral** — Claude Code hooks and dogfooding symlink rewiring are explicitly out of scope

## Considered Options

### Option 1: Pre-flight safety checks (selected)

Before `git worktree remove`, collect dirty state and merge state for each repo. Present warnings with specifics (which repo, how many files, which branch). Require confirmation unless `--force`.

- **Pro:** Simple, composable, prevents the worst failure mode
- **Pro:** Matches user expectation from `rm -i` / `git clean -i` patterns
- **Con:** Adds latency to remove (must query each repo)

### Option 2: Rollback on partial create failure (rejected)

If creating repo 2's worktree fails, automatically clean up repo 1's worktree.

- **Con:** Complex, fragile — what if cleanup also fails?
- **Con:** Unnecessary — repo 1's worktree is still valid and useful
- **Decision:** Report partial state clearly instead

### Option 3: State database for worktree tracking (rejected)

Track worktrees in a JSON/YAML state file rather than querying git.

- **Con:** State file can drift from reality (orphaned entries, missing entries)
- **Con:** Git already tracks worktrees natively
- **Decision:** Filesystem and git are the source of truth

## Decision Outcome

Enhance `pf/git/worktree.py` with three patterns:

### 1. Pre-flight Safety Checks

New internal functions for read-only state inspection:

```python
def _check_dirty(repo_wt: Path) -> list[str]:
    """Modified/untracked files via git status --porcelain."""

def _check_unmerged(repo_wt: Path, branch: str, main_repo: Path) -> bool:
    """True if branch has NOT been merged into default_branch."""

def _collect_warnings(wt_path: Path, repos: dict) -> list[tuple[str, list[str], bool]]:
    """Aggregate warnings: [(repo_name, dirty_files, is_unmerged), ...]"""
```

`remove_worktree(name, force=False)` calls `_collect_warnings()` first. If warnings exist and `force=False`, display them and prompt with `[y/N]`. Non-interactive (`not sys.stdin.isatty()`) requires `--force`.

### 2. Collector Pattern for Multi-Repo Operations

Both `create` and `remove` collect results as `list[tuple[str, str, str]]` — `(repo_name, "ok"|"fail"|"skip", detail)`. Print structured summary after completion instead of line-by-line. Enables future `--json` output.

### 3. Session Context Write-on-Create

After successful creation, append to active session file:

```markdown
## Worktree Context
worktree: {name}
path: {absolute_path}
repos: {comma-separated repo names}
```

Best-effort: skip silently if no active session. Format matches existing `worktree-mode.md` guide.

### Component Structure

```
pf/git/worktree.py (single module, enhanced)
├── _git()                    # existing — subprocess wrapper
├── _get_worktree_root()      # existing — worktree directory
├── _filter_repos()           # existing — repo filtering
├── _check_dirty()            # NEW — dirty file detection
├── _check_unmerged()         # NEW — merge state check
├── _collect_warnings()       # NEW — aggregate warnings
├── _write_session_context()  # NEW — session integration
├── _find_active_session()    # NEW — find current session
├── detect_worktree()         # MOVED from create_branches.py
├── create_worktree()         # ENHANCED — collector, session write
├── remove_worktree()         # ENHANCED — safety checks, force flag
├── list_worktrees()          # ENHANCED — per-repo branch + dirty state
└── show_worktree_status()    # existing — minor tweaks
```

### CLI Changes

| Command | Change |
|---------|--------|
| `pf git worktree remove <name>` | Add `--force` flag |
| `pf git worktree create <name> <branch>` | Enhanced output format |
| `pf git worktree list` | Enhanced output with dirty state |

### Key Contracts

1. `_check_dirty()` uses `git status --porcelain` — machine-parseable, stable across git versions
2. `_check_unmerged()` checks against `RepoConfig.default_branch`, never hardcoded "main"
3. Confirmation prompt: `input()` with `[y/N]`, default No
4. Session context format matches `worktree-mode.md` exactly
5. Exit codes: 0=success, 1=error, 2=user cancelled

## Consequences

### Positive

- Zero incidents of silent work loss from worktree cleanup
- Consumer developers can create, use, and clean up worktrees without reading source code
- Agents can detect worktree context from session files
- Clear partial-failure reporting when multi-repo operations partially succeed

### Negative

- `remove` is slower (queries each repo for dirty/unmerged state)
- `input()` prompt doesn't work in non-interactive contexts without `--force`
- Session write couples worktree module to session file format (mitigated: best-effort, optional)

### Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| `_check_unmerged()` false positive on squash-merged branches | Document limitation; check `git log` for commits, not just `--merged` |
| `input()` blocks in non-interactive (CI, hooks) | Detect `sys.stdin.isatty()`; require `--force` if non-interactive |
| Path traversal in worktree name | Validate: reject names containing `/`, `..`, or null bytes |
| Partial create leaves orphaned worktrees | Clear reporting of what succeeded/failed; no auto-rollback |

## Implementation Consistency Rules

> For AI agents implementing this ADR:

1. **All logic in `pf/git/worktree.py`** — no new files
2. **Safety checks return data, don't print** — caller decides output
3. **Collector is `list[tuple[str, str, str]]`** — not a class
4. **Session context is plain markdown** — no YAML frontmatter, no XML
5. **`--force` bypasses warnings entirely** — no partial force
6. **No rollback on partial create** — report clearly instead
7. **No new dependencies** — stdlib only

## MVP Scope Mapping

| FR | Covered | How |
|----|---------|-----|
| FR1-5: Create | Yes | Enhanced output, collector pattern |
| FR6-10: Safe remove | Yes | Pre-flight checks, `--force`, confirm prompt |
| FR11-13: List/status | Yes | Enhanced output with dirty state |
| FR14-16: Session | Yes | Write-on-create, detection util |
| FR17-19: Claude Code hooks | No | Phase 2 |
| FR20-22: Dogfooding symlinks | No | Phase 2 |
| FR23-24: Documentation | Yes | Update worktree-mode.md guide |

## Related Decisions

- [ADR-0005: Single Source of Truth via Symlinks](0005-single-source-of-truth-symlinks.md) — symlink topology affects Phase 2 dogfooding
- [ADR-0009: Session File Coordination](0009-session-file-coordination.md) — session format for worktree context block
- [ADR-0028: Python-First Installation](0028-python-first-installation.md) — `pf` CLI is the entry point
