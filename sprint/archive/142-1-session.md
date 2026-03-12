# Story 142-1: Unified context resolution in load_scenario()

**Status:** In Progress
**Epic:** 142 — Peloton Benchmark Simplification
**Points:** 2
**Priority:** P0
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** story/142-1-unified-context-resolution
**Context:** sprint/context/context-story-142-1.md
**Epic Context:** sprint/context/context-epic-142.md

## Acceptance Criteria

- Both schemas load without KeyError (`mssci-10836.yaml` and `dpgd-116.yaml` both return valid Scenario)
- `roots:` resolves relative to scenario file (not project_dir)
- Backward compatible — dpgd-116.yaml (no `roots:`) produces identical Scenario
- Skips epic/story for `context_type="repo"` — worktree has `.pennyfarthing/` + `.claude/` but no `sprint/context/`
- mssci/pprof scenarios run: `pf benchmark replay run scenarios/mssci-10836.yaml --skip-score --keep-worktree` succeeds

## SM Assessment

2-point trivial refactor. Single file change (`pipeline_replay.py`) plus two scenario YAML updates. Story context is excellent — line numbers, pitfalls, and patterns documented. Clear scope boundaries. Straight to Dev.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` — Extended `Scenario` with `context_type`, `claude_md_path`, `roots`; updated `load_scenario()` to detect sprint vs repo context; guarded `build_phase_claude_md()` and `_build_bmad_claude_md()` for repo-context
- `pennyfarthing-dist/guides/peloton.md` — Documented both context schemas in scenario YAML reference
- `internal/results/pipeline-replay/scenarios/mssci-10836.yaml` — Added `roots:` block
- `internal/results/pipeline-replay/scenarios/mssci-15531-pprof.yaml` — Added `roots:` block

**Tests:** 57/57 benchmark tests passing, 1874/1874 total passing (1 pre-existing pypi packaging error)
**Branch:** story/142-1-unified-context-resolution (pushed)

**Verification:**
- dpgd-116 (sprint-context): loads identically — backward compatible
- mssci-10836 (repo-context): loads without KeyError, resolves to `/Users/keithavery/Projects/poller-orc/poller-cobra`
- mssci-15531-pprof (repo-context): loads without KeyError, same repo resolution

**Handoff:** To Reviewer for code review

## Delivery Findings

<!-- delivery-findings-start -->
### Dev (implementation)
- No upstream findings during implementation.
### Reviewer (code review)
- **Improvement** (non-blocking): Peloton guide has markdown headers inside YAML code fence. Affects `pennyfarthing-dist/guides/peloton.md:231,237` (move context schema docs outside the code block). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `repo.get("path", "")` is more permissive than the original `repo["path"]` — silently resolves to project_dir when both `repo.path` and `roots.repo` are missing. Affects `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py:198` (consider restoring KeyError for missing repo.path). *Found by Reviewer during code review.*
<!-- delivery-findings-end -->

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Scenario YAML → `load_scenario()` → `Scenario` dataclass → `build_phase_claude_md()` → worktree CLAUDE.md (safe — context_type guards prevent reading empty paths)
**Pattern observed:** Clean detection via `"epic" in ctx` at `pipeline_replay.py:205` — simple, no ambiguity
**Error handling:** `_build_bmad_claude_md` guards empty paths with truthiness at `pipeline_replay.py:934-935`; `build_phase_claude_md` uses `context_type` check at `pipeline_replay.py:477`
**Tests:** 57/57 benchmark, 1874/1874 total — GREEN
**Non-blocking observations:** 2 MEDIUM/LOW items logged as delivery findings — no changes required for approval

**Handoff:** To SM for finish-story