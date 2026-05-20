---
story_id: "PROJ-16347"
jira_key: "PROJ-16347"
epic: null
workflow: "trivial"
---

# Story PROJ-16347: Implement stacked PR depends_on field and Graphite health check

## Story Details
- **ID:** PROJ-16347
- **Jira Key:** PROJ-16347
- **Workflow:** trivial
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-12T01:08:41Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-12T01:01:50Z | 2026-03-12T01:02:59Z | 1m 9s |
| implement | 2026-03-12T01:02:59Z | 2026-03-12T01:06:34Z | 3m 35s |
| review | 2026-03-12T01:06:34Z | 2026-03-12T01:08:41Z | 2m 7s |
| finish | 2026-03-12T01:08:41Z | - | - |

## Context

This story implements the remaining items from ADR-0036 (stacked PR support via Graphite):
- ADR and agent changes already landed
- This covers Python/CLI implementation

### Scope
1. Add `depends_on` field to sprint YAML story schema + loader
2. Add `--depends-on` flag to `pf sprint story add`
3. Cycle detection in sprint validator
4. `gt` health check when repos declare `pr_strategy: stacked`

### Key Files
- `pf/git/repos.py`
- `pf/sprint/story_add.py`
- `pf/sprint/validate_cmd.py`

### Target Repo
- `pennyfarthing/` (develop branch)

## Delivery Findings

No upstream findings.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No upstream findings during implementation.

## Design Deviations

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Health check simplified:** ADR-0036 spec included gt auth check, implemented presence-only check via `shutil.which`. Reason: `gt auth --token check` is undocumented and unreliable; presence is sufficient for health gate. → ✓ ACCEPTED by Reviewer: agrees with author reasoning, undocumented CLI flags are unstable

### Reviewer (code review)
- No upstream findings during code review.

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `--depends-on` CLI → `add_story()` → YAML field → `_validate_depends_on()` cycle check (safe)
**Pattern observed:** Result dict pattern consistently used at `repos.py:check_stack_tool_health`
**Error handling:** Non-existent depends_on target caught with actionable fix message at `validator.py:_validate_depends_on`
**Observations:**
- [VERIFIED] STORY_KEY_ORDER placement correct
- [VERIFIED] CLI threading through epic mode only (initiatives excluded)
- [VERIFIED] Reference validation with str() coercion for YAML integers
- [MEDIUM] Cycle detection reports duplicates for multi-node cycles (cosmetic, not blocking)
- [LOW] Unused `subprocess` import in repos.py (cosmetic)

**Handoff:** To Stilgar (SM) for finish-story

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pf/sprint/yaml_io.py` - Added depends_on to STORY_KEY_ORDER
- `pf/sprint/story_add.py` - Added --depends-on CLI flag and pass-through
- `pf/sprint/validator.py` - Added depends_on reference validation + cycle detection
- `pf/git/repos.py` - Added check_stack_tool_health() for Graphite CLI

**Tests:** Imports verified, no regressions
**Branch:** feat/PROJ-16347-stacked-pr-depends-on (pushed)

**Handoff:** To Leto II (Reviewer) for code review

## SM Assessment

**Story:** PROJ-16347 — Implement stacked PR depends_on field and Graphite health check
**Workflow:** trivial (setup → implement → review → finish)
**Routing:** Dev (Reverend Mother) for implementation

**Context:** ADR-0036 accepted and agent docs already updated. This story covers the Python/CLI plumbing — sprint YAML schema, CLI flags, validation, and health check. Well-scoped, 4 discrete deliverables. No blockers.