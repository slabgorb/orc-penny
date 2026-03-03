# Workflow Session: architecture

**Workflow:** architecture
**Type:** stepped
**Agent:** architect
**Started:** 2026-03-03T09:24:48Z

## Workflow State
- **Workflow Name:** architecture
- **Type:** stepped
- **Mode:** create
- **Started:** 2026-03-03T09:24:48Z
- **Last Updated:** 2026-03-03T09:31:37Z
- **Current Step:** 9
- **Steps Completed:** [1, 2, 3, 4, 5, 6, 7, 8]
- **Status:** completed
- **Notes:** Session created via pf workflow start

## Progress
- Total Steps: 8
- Completion: 100%

---

## Architecture Session: Multi-Repo Worktree Support

### Inputs Gathered
- PRD: `sprint/planning/worktree-prd.md` (complete — 24 FRs, 7 NFRs, 3 phases)
- Existing Code: `pennyfarthing/pennyfarthing-dist/src/pf/git/worktree.py` (303 lines — create, remove, list, status)
- Existing Guide: `pennyfarthing/pennyfarthing-dist/guides/worktree-mode.md`
- repos.yaml: 2 repos (orchestrator: trunk-based/main, pennyfarthing: gitflow/develop)
- Relevant ADRs:
  - ADR-0005: Single source of truth via symlinks (`.pennyfarthing/` → `pennyfarthing-dist/`)
  - ADR-0009: Session file coordination protocol
  - ADR-0027/0028: Installation architecture (Python-first, `pf` CLI)

### Stakeholders
- Decision maker: keithavery (solo developer)
- Reviewers: N/A (solo project)

### Constraints
- Solo developer, one sprint for MVP
- Python Click CLI, consistent with existing `pf git` group
- Must work with any valid `repos.yaml`, not just this project's layout
- Dogfooding symlink rewiring deferred to Phase 2

## Architecture Context

### Technical Constraints

- **Language:** Python (Click CLI) — all `pf git` commands are Python, no shell scripts
- **Git version:** 2.15+ (worktree improvements landed there)
- **Configuration:** `repos.yaml` is the single source of repo topology — no new config files
- **Session format:** Markdown with YAML-ish inline fields (ADR-0009) — worktree context is plain markdown, not XML
- **Path resolution:** `find-root.sh` walks up looking for `.pennyfarthing/` — worktrees must preserve this discovery
- **Symlinks:** `.pennyfarthing/` symlinks → `pennyfarthing-dist/` (ADR-0005) — Phase 2 concern for dogfooding

### Current Landscape

| Component | Status | Location |
|-----------|--------|----------|
| `create_worktree()` | Exists, basic | `pf/git/worktree.py:69-165` |
| `remove_worktree()` | Exists, unsafe (force-removes, no warnings) | `pf/git/worktree.py:168-211` |
| `list_worktrees()` | Exists, minimal (git output only) | `pf/git/worktree.py:214-244` |
| `show_worktree_status()` | Exists, shows branch + uncommitted count | `pf/git/worktree.py:247-302` |
| `detect_worktree()` | Exists in `create_branches.py:252-286` | Path-based: checks `/worktrees/` in cwd |
| `RepoConfig` + `load_repos_config()` | Stable | `pf/git/repos.py` |
| CLI routing | Complete | `pf/git_group/cli.py` Click group |
| Session worktree detection | Partial — `status` greps for `worktree: {name}` | No schema, no write-on-create |
| Claude Code hooks | Not implemented | Planned Phase 2 |

### Patterns In Use

1. **Result-code returns** — worktree functions return `int` (0/1), not result objects. Inconsistent with framework convention (`{success, data?, error?}`), but matches other `pf git` commands.
2. **`_git()` helper** — thin subprocess wrapper returning `(stdout, returncode)`. Adequate for current use.
3. **Repo iteration** — `load_repos_config()` → iterate `dict[str, RepoConfig]` → per-repo git operations. This pattern is correct and should be preserved.
4. **Worktree root** — `WORKTREE_ROOT` env var or `project_root/worktrees/`. Simple, works.

### Key Concerns

1. **Safety gap in `remove_worktree()`** — Currently `--force` removes without checking dirty state or unmerged branches. This is the highest-priority fix per PRD (FR6-FR10, NFR1). Silent work loss is the worst failure mode.

2. **Partial failure on `create_worktree()`** — If repo 2 of 3 fails, repo 1 is already created. The function prints "FAIL" but doesn't roll back. PRD NFR2 requires clear reporting of partial state. Rollback is overkill — clear reporting is sufficient.

3. **No session write on create** — `create_worktree()` doesn't write a worktree context block to the session file. `show_worktree_status()` searches for it but it's never written programmatically. This is the integration gap between worktrees and agents (FR14-FR15).

4. **`list` output is raw `git worktree list`** — No per-repo dirty state, no branch info in a structured way. PRD FR11 wants branch + dirty state per repo in the list output.

5. **`detect_worktree()` lives in wrong module** — It's in `create_branches.py`, not `worktree.py`. Should be consolidated for discoverability, but this is a cleanup concern, not architectural.

### Gap Analysis (PRD vs Current)

| PRD Requirement | Current State | Work Needed |
|-----------------|--------------|-------------|
| FR1: Multi-repo create | ✅ Works | Minor enhancements |
| FR2: Repo filtering | ✅ `--repos` flag | Already implemented |
| FR3: Existing/new branch | ✅ Auto-detects | Works |
| FR4: Dirty main checkout | ✅ Doesn't check main | Works by omission |
| FR5: Clear create output | ⚠️ Basic print | Enhance with structured summary |
| FR6-10: Safe remove | ❌ Force-removes | **Major work** — dirty/unmerged checks, confirm prompt, force flag |
| FR11-13: Enhanced list/status | ⚠️ Partial | Add dirty state to list, session association |
| FR14-16: Session integration | ❌ Not implemented | Write worktree context on create, detection util |
| FR23-24: Documentation | ⚠️ Guide exists | Update guide with multi-repo consumer workflow |

## Pattern Analysis

### Technology Versions

| Technology | Version | Notes |
|------------|---------|-------|
| Python | 3.11+ | Click CLI, already in use |
| Git | 2.15+ | Worktree features stable since 2.15 |
| Click | 8.x | Already the CLI framework |

### Candidate Patterns

| Pattern | Addresses | Trade-offs | Fit |
|---------|-----------|------------|-----|
| **Pre-flight safety checks** | Concern #1 (unsafe remove) | Simple, composable; adds latency to remove | 5/5 |
| **Collector/reporter for multi-repo ops** | Concern #2 (partial failure) | Clear output; slight code growth | 4/5 |
| **Session integration via write-on-create** | Concern #3 (no session write) | Couples worktree to session format; but session is the coordination layer (ADR-0009) | 4/5 |
| **Structured output for list/status** | Concern #4 (raw git output) | More code; but matches `pf` CLI convention | 4/5 |
| **Rollback on partial create failure** | Concern #2 alternative | Complex, fragile, unnecessary — clear reporting is sufficient | 2/5 |

### Selected Patterns

1. **Pre-flight safety checks before remove** — Before any `git worktree remove`, collect dirty state (uncommitted files) and merge state (unmerged branch) for each repo. Present warnings. Require confirmation unless `--force`. This is the core safety pattern that prevents work loss.

2. **Collector pattern for multi-repo operations** — Both `create` and `remove` iterate over repos. Instead of printing line-by-line, collect results into a list of `(repo_name, status, details)` tuples, then print a structured summary at the end. This gives clear partial-failure reporting (NFR2) and enables future `--json` output.

3. **Session context write-on-create** — After successful worktree creation, append a `## Worktree Context` block to the active session file (if one exists). This closes the integration gap with agents. Detection is already implemented in `show_worktree_status()`.

### Rejected Alternatives

- **Rollback on partial create** — Over-engineered. If repo 2 fails, repo 1's worktree is still valid and useful. Just report clearly.
- **Database/state file for worktree tracking** — Unnecessary. Git itself tracks worktrees (`git worktree list`). Filesystem is the source of truth.
- **Abstract worktree provider interface** — YAGNI. There's only one backend (git). No need for abstraction.

## Component Design

### Component Diagram

```
┌─────────────────────────────────────────────────────┐
│                  CLI Layer (Click)                   │
│  pf/git_group/cli.py — worktree command group       │
│  create | remove | list | status                    │
└─────────┬───────────┬───────────┬───────────┬───────┘
          │           │           │           │
          ▼           ▼           ▼           ▼
┌─────────────────────────────────────────────────────┐
│              Worktree Operations Module              │
│  pf/git/worktree.py — all worktree logic lives here │
│                                                     │
│  ┌──────────────┐  ┌──────────────┐                 │
│  │ Safety       │  │ Collector    │                 │
│  │ Checks       │  │ (results)    │                 │
│  └──────────────┘  └──────────────┘                 │
└──────┬──────────────────┬───────────────────────────┘
       │                  │
       ▼                  ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Git Backend  │   │ Repo Config  │   │ Session      │
│ _git() calls │   │ repos.py     │   │ Integration  │
│ subprocess   │   │ RepoConfig   │   │ .session/    │
└──────────────┘   └──────────────┘   └──────────────┘
```

### Component Responsibilities

| Component | Responsibility | Data Owned | Dependencies |
|-----------|---------------|------------|--------------|
| **CLI Layer** | Parse args, call operations, format output | CLI flags (`--force`, `--repos`, `--json`) | worktree.py |
| **Worktree Operations** | Create/remove/list/status logic, safety checks, result collection | Worktree state (via git + filesystem) | Git Backend, Repo Config, Session Integration |
| **Safety Checks** | Pre-remove: dirty files, unmerged branches, confirm prompt | None (reads git state) | Git Backend |
| **Collector** | Aggregate per-repo results for structured summary | Operation results list | None |
| **Git Backend** | `_git()` subprocess wrapper | None (passes through) | git binary |
| **Repo Config** | Load `repos.yaml`, provide `RepoConfig` objects | `repos.yaml` schema | Filesystem |
| **Session Integration** | Write/read worktree context in session files | Worktree context block in `.session/*.md` | Session file format (ADR-0009) |

### Boundary Decisions

- **CLI ↔ Operations:** CLI passes parsed args, operations return `int` (exit code). No result objects — matches existing `pf git` convention. `--json` flag passed through for future structured output.
- **Operations ↔ Git Backend:** `_git()` stays as-is — thin wrapper, returns `(stdout, returncode)`. No abstraction needed.
- **Operations ↔ Session:** Session write is best-effort. If no active session exists, skip silently. Session is an optional integration, not a hard dependency.
- **Safety Checks are internal to Operations:** Not a separate module/file — just functions within `worktree.py`. They're called by `remove_worktree()` before executing removal.

### Implementation Consistency Rules

> These rules prevent agents from making conflicting choices during implementation.

1. **All worktree logic stays in `pf/git/worktree.py`** — no new files. Move `detect_worktree()` from `create_branches.py` here. One module, one place to look.

2. **Safety checks return data, don't print** — `_check_dirty_state(repo_path)` returns `list[str]` of modified files. `_check_unmerged(repo_path, branch)` returns `bool`. The caller (remove) decides what to print and whether to prompt.

3. **Collector is a plain list, not a class** — `results: list[tuple[str, str, str]]` where tuple is `(repo_name, "ok"|"fail"|"skip", detail_message)`. Printed as a summary table after the operation.

4. **Session context block format is fixed:**
   ```markdown
   ## Worktree Context
   worktree: {name}
   path: {absolute_path}
   repos: {comma-separated repo names}
   ```
   No YAML frontmatter, no XML. Plain markdown matching existing guide format.

5. **`--force` bypasses warnings, not confirmation** — With warnings present and no `--force`, prompt for confirmation. With `--force`, skip the prompt entirely. Without warnings, no prompt needed.

6. **Exit codes:** 0 = success, 1 = error, 2 = user cancelled (declined confirmation). Matches POSIX convention.

7. **`remove` runs `git worktree prune` after removal** — already implemented, keep it. Prevents orphaned references (NFR4).

8. **No new dependencies** — stdlib only (subprocess, pathlib, shutil). No external packages.

## Interface Definitions

### CLI Interface (External)

| Command | Signature | New/Changed |
|---------|-----------|-------------|
| `pf git worktree create <name> <branch>` | `--repos TEXT` (default "all") | Enhance output |
| `pf git worktree remove <name>` | `--force` flag (new) | **Major change** — safety checks |
| `pf git worktree list` | (no args) | Enhance output format |
| `pf git worktree status` | `<name>` optional positional | Minor — already works |

### Internal Function Signatures

```python
# --- Safety checks (new) ---

def _check_dirty(repo_wt: Path) -> list[str]:
    """Return list of modified/untracked files in worktree repo.
    Empty list = clean."""

def _check_unmerged(repo_wt: Path, branch: str, main_repo: Path) -> bool:
    """Return True if branch has NOT been merged into default branch.
    Uses: git branch --merged <default> | grep <branch>"""

def _collect_warnings(wt_path: Path, repos: dict) -> list[tuple[str, list[str], bool]]:
    """Collect all warnings for a worktree.
    Returns: [(repo_name, dirty_files, is_unmerged), ...]
    Only includes repos with warnings."""

# --- Enhanced operations (modified) ---

def create_worktree(name: str, branch: str, repos_filter: str = "all") -> int:
    """Enhanced: structured summary output, session context write."""

def remove_worktree(name: str, force: bool = False) -> int:
    """Enhanced: safety checks before removal, confirm prompt.
    Returns 0=success, 1=error, 2=cancelled."""

def list_worktrees() -> int:
    """Enhanced: per-repo branch + dirty state in output."""

# --- Session integration (new) ---

def _write_session_context(wt_name: str, wt_path: Path, repo_names: list[str]) -> None:
    """Append worktree context block to active session file.
    Best-effort: silently skips if no active session."""

def _find_active_session() -> Path | None:
    """Find current active session file in .session/.
    Returns None if no active session."""

# --- Consolidated from create_branches.py ---

def detect_worktree(current_dir: Path | None = None) -> tuple[bool, str | None, Path]:
    """Detect if cwd is inside a worktree.
    Returns (is_worktree, worktree_name, base_path)."""
```

### Output Contracts

**`remove` with warnings (no `--force`):**
```
Warning: wt-review has issues:
  orchestrator: 2 uncommitted files (M api/handler.py, M tests/test_api.py)
  pennyfarthing: branch feat/fix not merged into develop

Remove anyway? [y/N]
```

**`remove` with `--force`:**
```
Force removing wt-review...
  orchestrator: removed
  pennyfarthing: removed
Worktree 'wt-review' removed.
```

**`list` enhanced output:**
```
=== Active Worktrees ===

wt-review
  orchestrator: feat/teammate-fix (clean)
  pennyfarthing: feat/teammate-fix (2 uncommitted)

wt-hotfix
  orchestrator: fix/sprint-validation (clean)
  pennyfarthing: fix/sprint-validation (clean)
```

**`create` structured summary:**
```
Creating worktree: wt-review
  Branch: feat/teammate-fix

  orchestrator: OK (worktrees/wt-review/orchestrator)
  pennyfarthing: OK (worktrees/wt-review/pennyfarthing)

Worktree 'wt-review' created (2/2 repos).
```

### Conventions

- **Naming:** snake_case for functions, UPPER_CASE for constants — matches existing `worktree.py`
- **Errors:** Print to stdout (not stderr) — matches existing `pf git` convention
- **Private functions:** Prefixed with `_` — matches existing pattern in module
- **Type hints:** Full annotations on all new functions — matches existing code

### Contract Enforcement

1. **`_check_dirty()` must use `git status --porcelain`** — machine-parseable, won't change across git versions
2. **`_check_unmerged()` must check against the repo's `default_branch`** from `RepoConfig`, not hardcoded "main"
3. **Confirmation prompt must use `input()` with `[y/N]`** — default is No (safe default)
4. **Session context write must match the format in worktree-mode.md** — `worktree:`, `path:`, `repos:` keys on separate lines under `## Worktree Context`

## Risk Assessment

### Technical Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `git worktree remove` fails mid-operation (e.g., locked files) | Med — orphaned worktree references | Low | Already runs `git worktree prune` after. Report which repos succeeded/failed. |
| `_check_unmerged()` false positive — branch merged via squash/rebase | Med — user warned about "unmerged" branch that was actually merged | Med | Check `git log --oneline <default>..<branch>` for commits, not just `--merged`. Document limitation. |
| `input()` prompt blocks non-interactive use (CI, hooks) | High — breaks Claude Code hook integration | Med | Detect `sys.stdin.isatty()`. If not interactive, refuse removal (require `--force`). |
| Session file write races with agent reading it | Low — cosmetic, block appears mid-session | Low | Best-effort write. Agents tolerate extra markdown sections. |
| Consumer project has no `repos.yaml` | Med — all commands fail | Low | Already handled: `load_repos_config()` returns empty dict, commands report "no repos configured." |

### Failure Modes

| Component | Failure Mode | Detection | Recovery |
|-----------|--------------|-----------|----------|
| `create_worktree()` | Partial success (1 of N repos) | Print summary with OK/FAIL per repo | User creates missing repos manually or retries |
| `remove_worktree()` | `git worktree remove` fails (locked) | Non-zero return from `_git()` | Report failure, suggest `git worktree remove --force` manually |
| `_check_dirty()` | `git status --porcelain` fails in corrupt repo | Non-zero return code | Treat as "unknown state" — warn user, don't auto-remove |
| Session write | No active session file found | `_find_active_session()` returns None | Skip silently — session integration is optional |

### Security Considerations

- **No elevated privileges** — all operations are user-level git commands
- **No network access** — worktree operations are local-only
- **Path traversal** — worktree names are used in paths. Validate: no `/`, `..`, or null bytes in name argument. Existing code doesn't validate this.
- **Symlink following** — `shutil.rmtree` follows symlinks by default in older Python. Use `shutil.rmtree(wt_path, onerror=...)` carefully. Already mitigated by `git worktree remove` handling the git-tracked parts first.

### AI Implementation Risks

| Risk | Could Cause | Prevention |
|------|-------------|------------|
| Agent adds rollback logic to `create` | Complexity, fragile cleanup | Consistency Rule: no rollback — report partial state |
| Agent uses `git branch -d` to check merge state | Destructive — deletes the branch | Contract: `_check_unmerged` is read-only, uses `--merged` query |
| Agent hardcodes "main" as default branch | Wrong for gitflow repos (should be "develop") | Contract: always read `RepoConfig.default_branch` |
| Agent adds YAML/XML to session context block | Breaks existing grep-based detection | Contract: plain markdown format, matching worktree-mode.md |
| Agent creates separate files for safety checks | Module sprawl, harder to maintain | Consistency Rule: all logic in `worktree.py` |

## Decision Document

**ADR written:** `docs/adr/0033-multi-repo-worktree-safety.md`

Sections compiled:
- [x] Context analysis (Step 2)
- [x] Pattern selection with rationale (Step 3)
- [x] Component design with boundaries (Step 4)
- [x] Interface definitions with contracts (Step 5)
- [x] Risk assessment with mitigations (Step 6)
- [x] Implementation consistency rules
- [x] MVP scope mapping against PRD

