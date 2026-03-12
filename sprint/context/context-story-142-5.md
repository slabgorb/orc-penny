---
parent: context-epic-142.md
workflow: trivial
---

# Story 142-5: Fix framework_version reliability

## Business Context

`_framework_version()` never produces a `tag` field and returns `None` when `project_dir` is missing. `compare --group-by framework_version` shows "unknown" for most runs. This story makes version tracking reliable.

## Technical Guardrails

**Key files:** `pipeline_replay.py` — `_framework_version()` (lines 99–130): add `git describe --tags --always`. `save_result()` (lines 1744–1749): warn not crash on missing `project_dir`. Line 119: hash only scenario phases, not hardcoded `["tea", "dev", "reviewer"]`.

**Use `warnings.warn()`** not `print()` for missing project_dir. `--always` ensures fallback to commit hash if no tags. Guard `pf_repo.exists()` before git commands.

## Scope Boundaries

**In scope:** Add `tag` field, phase-aware `agent_hashes`, warn on missing `project_dir`
**Out of scope:** Backfilling tag into existing runs

## AC Context

| AC | Detail |
|----|--------|
| `tag` field present | `_framework_version()` returns dict with non-empty `tag` |
| Phase-aware hashes | Only hashes agents for scenario's actual phases |
| Warns, doesn't crash | `save_result(project_dir=None)` emits warning, returns valid run_dir |
| Complete in pipeline.yaml | `framework_version: {commit, semver, tag, agent_hashes}` |
