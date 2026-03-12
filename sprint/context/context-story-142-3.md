---
parent: context-epic-142.md
workflow: trivial
---

# Story 142-3: Worktree cleanliness verification

## Business Context

No validation that a worktree is clean after context setup. Crashed runs can leave orphaned files that contaminate next runs. This adds a gate between setup and phase execution.

## Technical Guardrails

**Key files:** `pipeline_replay.py` — new `verify_worktree()` after line 372, call in `run_pipeline()` after `setup_worktree_pf_context()` before OTEL collector.

**Use `git status --porcelain`** (not `git diff HEAD`) to catch untracked files. Allowed: `.pennyfarthing`, `.claude/settings.json`, `.session/`, `sprint/context/` (pf-context only). Use `raise RuntimeError(...)` not `sys.exit()` — `finally` block needs to run.

**Critical pitfall:** If verify raises before OTEL collector starts, `collector.stop()` in `finally` crashes with NameError. Fix: `collector = None` before try, guard with `if collector:`.

## Scope Boundaries

**In scope:** `verify_worktree()` checking files + HEAD commit, call site in `run_pipeline()`
**Out of scope:** Worktree lifecycle management

## AC Context

| AC | Detail |
|----|--------|
| Validates expected files only | Unexpected files in `git status --porcelain` → RuntimeError |
| HEAD matches base_commit | `git rev-parse HEAD` == `scenario.base_commit` |
| Called before phases | Order: setup → verify → OTEL → phases |
| Clear error message | Lists unexpected files, expected vs actual commit |
