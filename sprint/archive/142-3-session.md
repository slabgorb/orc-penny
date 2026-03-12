# Story 142-3: Worktree cleanliness verification

**Status:** in-progress
**Phase:** finish
**Workflow:** trivial
**Repos:** orchestrator
**Jira:**
**Branch:** story/142-3-worktree-cleanliness-verification

## Context

No validation that a worktree is clean after context setup. Crashed runs can leave orphaned files that contaminate next runs. This story adds a gate between setup and phase execution.

**Key files:**
- `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` — new `verify_worktree()` after line 372, call in `run_pipeline()` after `setup_worktree_pf_context()` before OTEL collector

**Use `git status --porcelain`** (not `git diff HEAD`) to catch untracked files. Allowed: `.pennyfarthing`, `.claude/settings.json`, `.session/`, `sprint/context/` (pf-context only). Use `raise RuntimeError(...)` not `sys.exit()` — `finally` block needs to run.

**Critical pitfall:** If verify raises before OTEL collector starts, `collector.stop()` in `finally` crashes with NameError. Fix: `collector = None` before try, guard with `if collector:`.

## Acceptance Criteria

| AC | Detail |
|----|--------|
| Validates expected files only | Unexpected files in `git status --porcelain` → RuntimeError |
| HEAD matches base_commit | `git rev-parse HEAD` == `scenario.base_commit` |
| Called before phases | Order: setup → verify → OTEL → phases |
| Clear error message | Lists unexpected files, expected vs actual commit |

## Scope Boundaries

**In scope:** `verify_worktree()` checking files + HEAD commit, call site in `run_pipeline()`
**Out of scope:** Worktree lifecycle management

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` - Added `verify_worktree()` function and wired into `run_pipeline()`

**Changes:**
1. `verify_worktree(worktree_path, expected_commit)` — validates `git status --porcelain` against allowed paths, checks HEAD matches base_commit
2. Call site in `run_pipeline()` — after `setup_worktree_pf_context()`, before OTEL collector start
3. `collector` initialized to `None` before try block, guarded with `if collector:` in finally — prevents NameError if verify raises

**Tests:** 57/57 passing (GREEN)
**Branch:** fix/142-2-fix-save-result-nesting (pennyfarthing repo, pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `scenario.base_commit` → `verify_worktree(wt_path, scenario.base_commit)` → `subprocess.run(["git", "rev-parse", "HEAD"])` → string comparison. Safe — list-form subprocess, no shell injection.

**Pattern observed:** Guard-before-resource pattern at `pipeline_replay.py:988` — verify runs before OTEL collector starts, with `collector = None` + `if collector:` guard in finally block. Correct defensive pattern.

**Error handling:** All three failure modes raise `RuntimeError` with descriptive messages (git status failure, unexpected files listed, commit mismatch with expected vs actual). The `finally` block correctly guards `collector.stop()`.

**Specialist subagent findings:**

- [EDGE] `_ALLOWED_WORKTREE_PATHS` prefix matching: `.claude` with `startswith()` would match hypothetical `.claude-foo`. Low real-world risk — no such files exist in benchmark worktrees. **MEDIUM** (non-blocking).
- [EDGE] Empty `expected_commit` bypass: `"".startswith("")` is True. Mitigated by scenario loader requiring `base_commit`. **LOW.**
- [SILENT] `verify_worktree()` error propagation is correct — no swallowed errors. Pre-existing `run_phase()` silent failures (exit_code, JSONDecodeError) are out of scope. **VERIFIED.**
- [SILENT] Collector None guard structurally sound — handles verify-before-collector case. **VERIFIED.**
- [TEST] No unit tests — expected for trivial workflow. **LOW** (noted).
- [DOC] Allowed paths comment says "after context setup" but `.session/` and `sprint/context/` aren't created by setup. Minor clarity issue. **LOW.**
- [TYPE] Bidirectional `startswith()` for commit comparison is semantically loose but handles short-SHA scenarios correctly. **LOW.**
- [SEC] No command injection — all subprocess calls use list form, no `shell=True`. **VERIFIED.**
- [SIMPLE] Redundant entries in `_ALLOWED_WORKTREE_PATHS`: `.claude` already covers `.claude/` and `.claude/settings.json` via prefix match. **LOW.**

**AC verification:**
- Validates expected files only: YES — `git status --porcelain` parsed, unexpected files → RuntimeError
- HEAD matches base_commit: YES — `git rev-parse HEAD` compared
- Called before phases: YES — after `setup_worktree_pf_context()`, before OTEL collector
- Clear error message: YES — lists unexpected files, shows expected vs actual commit

**Handoff:** To SM for finish-story

## Delivery Findings

<!-- delivery-findings -->

### Dev (implementation)

- No upstream findings during implementation.

### Reviewer (code review)

- **Improvement** (non-blocking): `_ALLOWED_WORKTREE_PATHS` has redundant entries — `.claude` covers `.claude/` and `.claude/settings.json` via prefix match. Affects `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` (simplify allowed set to 4 entries). *Found by Reviewer during code review.*