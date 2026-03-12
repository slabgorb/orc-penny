---
story: 142-5
title: Fix framework_version reliability
workflow: trivial
phase: setup
repos: pennyfarthing
epic: 142
---

# Story 142-5: Fix framework_version reliability

**Workflow:** trivial
**Repos:** pennyfarthing
**Status:** setup

## Story Overview

`_framework_version()` never produces a `tag` field and returns `None` when `project_dir` is missing. `compare --group-by framework_version` shows "unknown" for most runs. This story makes version tracking reliable.

## Key Files to Modify

- `pipeline_replay.py` — `_framework_version()` (lines 99–130)
  - Add `git describe --tags --always` to capture tags
  - Use `--always` for fallback to commit hash if no tags
  - Guard `pf_repo.exists()` before git commands
- `save_result()` (lines 1744–1749)
  - Warn (not crash) on missing `project_dir`
  - Use `warnings.warn()` not `print()`
- Line 119: Hash only scenario phases, not hardcoded `["tea", "dev", "reviewer"]`

## Acceptance Criteria

| AC | Detail |
|----|--------|
| `tag` field present | `_framework_version()` returns dict with non-empty `tag` |
| Phase-aware hashes | Only hashes agents for scenario's actual phases |
| Warns, doesn't crash | `save_result(project_dir=None)` emits warning, returns valid run_dir |
| Complete in pipeline.yaml | `framework_version: {commit, semver, tag, agent_hashes}` |

## Scope Boundaries

**In scope:**
- Add `tag` field
- Phase-aware `agent_hashes`
- Warn on missing `project_dir`

**Out of scope:**
- Backfilling tag into existing runs

## SM Assessment

**Routing:** Trivial workflow (1pt bug fix) → straight to Dev, no TEA needed.
**Context:** Story has clear ACs, context doc exists, scope is tight — 3 targeted changes in pipeline_replay.py.
**Handoff:** White Rabbit (Dev) to implement. No Jira key to claim.
**Risk:** Low. Isolated to benchmark infrastructure, no production impact.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` — added `tag` field via `git describe --tags --always`, guarded `pf_repo.exists()`, made agent hashing phase-aware, added `warnings` import
- `pennyfarthing-dist/src/pf/benchmark/cli.py` — pass `scenario_phases` to `save_result()` at both call sites

**Tests:** 2614/2614 passing (GREEN), 57 benchmark-specific tests pass
**Branch:** feature/story-142-5-fix-framework-version-reliability (pushed)

**Handoff:** To Reviewer for code review

## Delivery Findings

<!-- delivery-findings -->
### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): `phases if phases` at `pipeline_replay.py:128` uses truthiness — an empty list `[]` falls back to the hardcoded default instead of hashing zero agents. Should be `phases if phases is not None`. Affects `pennyfarthing-dist/src/pf/benchmark/pipeline_replay.py` (change truthiness check to identity check). *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED

| # | Observation | Location |
|---|-------------|----------|
| 1 | [VERIFIED] `tag` field added via `git describe --tags --always` with proper `--always` fallback | `pipeline_replay.py:114-120` |
| 2 | [VERIFIED] `pf_repo.exists()` guard added before `.git` check — prevents `OSError` on missing dir | `pipeline_replay.py:106` |
| 3 | [MEDIUM] [EDGE] `phases if phases` is falsy for `[]` — falls back to hardcoded list. Should use `is not None`. No current scenario triggers this but semantically wrong | `pipeline_replay.py:128` |
| 4 | [VERIFIED] `warnings.warn()` with correct `stacklevel=2` — caller sees the warning, not internals | `pipeline_replay.py:1499-1504` |
| 5 | [VERIFIED] `scenario_phases` threaded through both `cli.py` call sites correctly | `cli.py:182,266` |
| 6 | [VERIFIED] Data flow: `scenario.phases` (list[str]) → `save_result(scenario_phases=)` → `_framework_version(phases=)` → `roles` iteration. Type-safe, no coercion. |
| 7 | [VERIFIED] Error handling: both subprocess calls catch `CalledProcessError`, defaults are "unknown" — graceful degradation |

**Data flow traced:** `scenario.phases` → `save_result()` → `_framework_version()` → agent hash loop. Safe — list of strings used as filesystem path components via `f"{role}.md"`, no injection risk since roles come from scenario YAML not user input.
**Pattern observed:** Follows existing `_bmad_version` pattern for git subprocess calls at `pipeline_replay.py:144-159`.
**Error handling:** Graceful — subprocess failures produce "unknown" defaults, missing project_dir emits warning.
**Medium finding:** Empty-list truthiness at line 128 is non-blocking — no scenario produces empty phases, and the fallback is the same default the loader uses.

**Handoff:** To The Mad Hatter (SM) for finish-story