---
parent: context-epic-142.md
workflow: trivial
---

# Story 142-1: Unified context resolution in load_scenario()

## Business Context

Two of four peloton scenarios (`proj-10836`, `pprof-cobra-15`) can't run because `load_scenario()` hardcodes `ctx["epic"]` and `ctx["story"]` — those scenarios use `context: {claude_md: CLAUDE.md}` which raises `KeyError`. This story makes all scenario types loadable through a single code path.

## Technical Guardrails

**Key files:**
- `pipeline_replay.py`: `Scenario` dataclass (lines 52–68), `load_scenario()` (lines 156–208, KeyError at line 198), `setup_worktree_pf_context()` (lines 304–372), `build_phase_claude_md()` (lines 499–548)
- `internal/results/pipeline-replay/scenarios/proj-10836.yaml` and `proj-15531-pprof.yaml`: add `roots:` block

**Patterns:** `roots:` paths resolve relative to `Path(scenario_path).parent`, NOT `project_dir`. Keep `context_epic_path`/`context_story_path` as empty strings (not None) for repo-context so `.exists()` checks still work. Still symlink `.pennyfarthing/` and write `.claude/settings.json` for repo-context — only skip sprint/context copy.

**Pitfall:** `build_phase_claude_md()` line 513 does `Path(scenario.context_epic_path).read_text()` unconditionally — guard for repo-context.

## Scope Boundaries

**In scope:** Extend `Scenario` with `context_type`/roots, handle both context schemas, update proj/pprof scenarios, update `peloton.md`
**Out of scope:** Changing dpgd-116/dpgd-117 scenario files

## AC Context

| AC | Detail |
|----|--------|
| Both schemas load without KeyError | `proj-10836.yaml` and `dpgd-116.yaml` both return valid `Scenario` |
| `roots:` resolves relative to scenario file | `roots: {repo: ../poller-cobra}` → scenario_dir parent, not project_dir |
| Backward compatible | dpgd-116.yaml (no `roots:`) produces identical Scenario |
| Skips epic/story for `context_type="repo"` | Worktree has `.pennyfarthing/` + `.claude/` but no `sprint/context/` |
| proj/pprof scenarios run | `pf benchmark replay run scenarios/proj-10836.yaml --skip-score --keep-worktree` succeeds |
