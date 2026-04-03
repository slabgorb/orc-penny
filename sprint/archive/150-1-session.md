---
story_id: "150-1"
jira_key: null
epic: "150"
workflow: "tdd"
---

# Story 150-1: Add agents-local/ directory with loader support

## Story Details

- **ID:** 150-1
- **Epic:** 150 (Custom Agent Creation System)
- **Title:** Add agents-local/ directory with loader priority over agents/
- **Points:** 2
- **Workflow:** tdd
- **Repos:** pennyfarthing
- **Stack Parent:** none

## Acceptance Criteria

1. Create `.pennyfarthing/agents-local/` directory structure as a protected location (like `gates-local/`)
2. Update `pf init` to preserve existing `agents-local/` files without overwriting
3. Modify `load_agent_definition()` in `pennyfarthing-dist/src/pf/prime/loader.py` to check `agents-local/{name}.md` **before** `agents/{name}.md`
4. Loader fallback: `agents-local/{name}.md` → `agents/{name}.md` → not found
5. All agent loading operations respect the new priority order
6. Custom agents in `agents-local/` receive full priming treatment (persona, sidecars, skills)

## Story Context

This story is the foundation for the Custom Agent Creation System epic (150). It enables consumer repos to override or extend built-in agents with custom versions in a protected directory structure.

The key technical challenge is maintaining backward compatibility while introducing priority-based lookup. Existing code assumes agents live in `agents/` (symlinked to `pennyfarthing-dist/agents/`). The loader must be transparent about checking the local directory first.

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-04-03T10:01:19Z

### Phase History

| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-04-03T09:41:00Z | 2026-04-03T09:42:00Z | 1m |
| red | 2026-04-03T09:42:00Z | 2026-04-03T09:47:16Z | 5m 16s |
| green | 2026-04-03T09:47:16Z | 2026-04-03T09:49:50Z | 2m 34s |
| spec-check | 2026-04-03T09:49:50Z | 2026-04-03T09:51:16Z | 1m 26s |
| verify | 2026-04-03T09:51:16Z | 2026-04-03T09:56:40Z | 5m 24s |
| review | 2026-04-03T09:56:40Z | 2026-04-03T10:00:20Z | 3m 40s |
| spec-reconcile | 2026-04-03T10:00:20Z | 2026-04-03T10:01:19Z | 59s |
| finish | 2026-04-03T10:01:19Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- No upstream findings during implementation.

### Architect (spec-check)
- No upstream findings during spec-check.

### TEA (test verification)
- **Improvement** (non-blocking): Loader fallback pattern is duplicated across 4 functions in `loader.py` (`load_agent_definition`, `load_behavior_guide`, `load_team_mode_guide`, `load_gate_recovery_guide`). A shared helper could consolidate ~60 lines. Affects `pennyfarthing-dist/src/pf/prime/loader.py` (candidate for future extraction). *Found by TEA during test verification.*

### Reviewer (code review)
- **Improvement** (non-blocking): `load_agent_definition()` does not sanitize `agent_name` before path construction — pre-existing pattern (same in `agents/` and `dist_root` lookups). Low risk since callers pass hardcoded names from CLI, but a future story adding user-derived agent names should add `re.fullmatch(r'[\w.-]+', agent_name)` validation. Affects `pennyfarthing-dist/src/pf/prime/loader.py` (boundary validation). *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** 2 findings (0 Gap, 0 Conflict, 0 Question, 2 Improvement)
**Blocking:** None

- **Improvement:** Loader fallback pattern is duplicated across 4 functions in `loader.py` (`load_agent_definition`, `load_behavior_guide`, `load_team_mode_guide`, `load_gate_recovery_guide`). A shared helper could consolidate ~60 lines. Affects `pennyfarthing-dist/src/pf/prime/loader.py`.
- **Improvement:** `load_agent_definition()` does not sanitize `agent_name` before path construction — pre-existing pattern (same in `agents/` and `dist_root` lookups). Low risk since callers pass hardcoded names from CLI, but a future story adding user-derived agent names should add `re.fullmatch(r'[\w.-]+', agent_name)` validation. Affects `pennyfarthing-dist/src/pf/prime/loader.py`.

### Downstream Effects

- **`pennyfarthing-dist/src/pf/prime`** — 2 findings

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No deviations from spec.

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- No undocumented deviations found. TEA and Dev both reported no deviations — confirmed accurate. The implementation follows the `gates-local/` precedent exactly.

### Architect (reconcile)
- No additional deviations found. TEA and Dev entries verified — both accurately report no spec deviations. Implementation matches all 6 ACs exactly. No AC deferrals to audit.

## Sm Assessment

**Story 150-1** is ready for the RED phase. Foundation story for epic 150 — adds `agents-local/` directory support to the agent loader with priority over the built-in `agents/` directory.

**Routing:** TDD workflow → TEA (Caterpillar) for RED phase. 2-point story but TDD workflow per epic config — tests first.

**Key risks:**
- Loader changes touch the critical path for all agent activation — tests must verify backward compatibility
- `pf init` must preserve local agents (not overwrite) — same pattern as `gates-local/`

**Branch:** `feat/150-1-agents-local-directory` in pennyfarthing repo (targets `develop`)

**Handoff to:** TEA (RED phase) — write failing tests for the 6 acceptance criteria.

## Tea Assessment

**Tests Required:** Yes
**Reason:** Core loader change — must verify priority chain and backward compatibility

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_agents_local.py` — 22 tests covering all 6 ACs

**Tests Written:** 22 tests covering 6 ACs
**Status:** RED (10 failing, 12 passing — ready for Dev)

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #3 type annotations | `test_load_agent_definition_has_type_annotations` | passing |
| #5 path handling | `test_loader_uses_pathlib_not_string_paths` | passing |
| #6 test quality | Self-check: all 22 tests have meaningful assertions | passing |

**Rules checked:** 3 of 13 applicable Python lang-review rules have test coverage
**Self-check:** 0 vacuous tests found

**Handoff:** To Dev (White Rabbit) for GREEN phase

## Dev Assessment

**Status:** GREEN — all 22 tests passing
**Regression check:** 52/52 existing test_prime.py tests still passing

**Changes made:**
1. `pennyfarthing-dist/src/pf/prime/loader.py` (lines 31-36) — Added `agents-local/{name}.md` check before `agents/{name}.md` in `load_agent_definition()`. Three-tier fallback: agents-local → agents → dist_root.
2. `pennyfarthing-dist/src/pf/init/core.py` (line 62) — Added `".pennyfarthing/agents-local"` to `_PENNYFARTHING_DIRS` so `pf init` creates the directory.

**Diff size:** +9 lines, -2 lines across 2 files. Minimal, surgical change.

**AC coverage:**
- AC 1 (directory structure): `agents-local/` added to `_PENNYFARTHING_DIRS` ✓
- AC 2 (init preservation): `agents-local/` NOT in `_CONTENT_DIRS` or `_DOGFOODING_SYMLINKS` — init never overwrites ✓
- AC 3 (loader priority): `agents-local/` checked before `agents/` ✓
- AC 4 (fallback chain): agents-local → agents → dist_root → None ✓
- AC 5 (all operations): single code path, all callers inherit ✓
- AC 6 (full priming): custom agents load identically to built-in — persona, sidecars already work by agent name ✓

**Handoff:** To TEA (Caterpillar) for verify phase

## Tea Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 3 findings | Loader fallback duplication (pre-existing), test fixture duplication |
| simplify-quality | 1 finding | Vacuous assertion on line 81 (dead code) |
| simplify-efficiency | 3 findings | Pre-existing O(n²) in session parser, test overlap |

**Applied:** 1 high-confidence fix (vacuous assertion → proper negative check)
**Flagged for Review:** 2 medium-confidence findings (test fixture consolidation, loader abstraction)
**Noted:** 3 low/out-of-scope observations (pre-existing code, test redundancy acceptable)
**Reverted:** 0

**Overall:** simplify: applied 1 fix

**Quality Checks:** 131/131 tests passing (prime + agents-local + init)
**Handoff:** To Queen of Hearts (Reviewer) for code review

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None

All 6 ACs verified against the code diff:

| AC | Spec | Code | Status |
|----|------|------|--------|
| 1 | Protected directory like `gates-local/` | In `_PENNYFARTHING_DIRS`, not in `_CONTENT_DIRS` or `_DOGFOODING_SYMLINKS` | Aligned |
| 2 | `pf init` preserves existing files | Dir created but no content copied (not in `_CONTENT_DIRS`) | Aligned |
| 3 | Check `agents-local/` before `agents/` | Lines 33-36 check local first | Aligned |
| 4 | Fallback: local → built-in → not found | Three-tier chain: local → agents → dist_root → None | Aligned |
| 5 | All operations respect priority | Single function entry point, all callers inherit | Aligned |
| 6 | Full priming treatment | Loader returns same string type; persona/sidecars/skills already work by agent name | Aligned |

**Architectural notes:**
- Pattern follows established `gates-local/` precedent — consistent with SOUL principle #2 (One Truth, One Place)
- No coupling between file source path and priming behavior — clean separation
- Diff is +9/-2 lines across 2 files — appropriately minimal for a 2-point foundation story

**Decision:** Proceed to verify phase

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 131/131 tests pass, 0 smells |
| 2 | reviewer-edge-hunter | Yes | Skipped | disabled | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Yes | Skipped | disabled | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | Skipped | disabled | Disabled via settings |
| 5 | reviewer-comment-analyzer | Yes | Skipped | disabled | Disabled via settings |
| 6 | reviewer-type-design | Yes | Skipped | disabled | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 3 | confirmed 0, dismissed 2, deferred 1 |
| 8 | reviewer-simplifier | Yes | Skipped | disabled | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | Skipped | disabled | Disabled via settings |

**All received:** Yes (2 enabled returned, 7 disabled pre-filled)
**Total findings:** 0 confirmed, 2 dismissed (with rationale), 1 deferred

### Security Subagent Finding Triage

1. **[SEC] CWE-22 path traversal via agent_name** (high confidence) → **Dismissed (severity: LOW)**. Pre-existing pattern — the `agents/` and `dist_root` lookups have the identical unsanitized interpolation. Not introduced by this PR. All production callers pass hardcoded CLI args ("dev", "tea", "sm"), not user-derived input. Deferred as improvement for a future story if user-derived agent names are ever accepted.

2. **[SEC] CWE-59 symlink traversal in agents-local/** (high confidence) → **Dismissed (severity: LOW)**. The user who can write symlinks to `agents-local/` already has full filesystem access to the project. This is a local-only dev tool, not a multi-tenant server. Same exposure exists for `gates-local/`, `.claude/`, and every other writable project directory.

3. **[SEC] Agent injection via priority override** (medium confidence) → **Deferred**. This IS the feature — `agents-local/` is explicitly designed to override built-in agents. The concern about untrusted content is valid for future plugin/marketplace scenarios but not for the current single-developer use case. Logged as delivery finding for future consideration.

## Reviewer Assessment

**Verdict:** APPROVED

### Observations

1. [VERIFIED] Three-tier fallback chain is correct — `loader.py:33-48` checks agents-local → agents → dist_root in order. Each tier returns early on `.exists()`. Evidence: lines 34-36 (local), 39-41 (builtin), 44-48 (dist_root). Complies with AC 3, 4, 5.

2. [VERIFIED] `agents-local/` is NOT in `_CONTENT_DIRS` (line 76-86 of init/core.py) and NOT in `_DOGFOODING_SYMLINKS` (lines 92-108). This means `pf init` will never copy framework content into it or symlink it. Complies with AC 1, 2. Evidence: `_CONTENT_DIRS` list at core.py:76, `_DOGFOODING_SYMLINKS` dict at core.py:92.

3. [VERIFIED] `agents-local/` IS in `_PENNYFARTHING_DIRS` at `core.py:61` — `pf init` creates the directory. Existing files are preserved because `_copy_tree` only runs on `_CONTENT_DIRS` entries, not `_PENNYFARTHING_DIRS` entries. `mkdir(exist_ok=True)` is safe. Complies with AC 1, 2.

4. [VERIFIED] Custom agents get full priming treatment — `load_agent_definition()` returns the same `str | None` regardless of source path. Persona loads by agent name from theme YAML (`persona.py`), sidecars load from `sidecars/{name}/` (`loader.py:256-284`). No source-path coupling. Complies with AC 6.

5. [LOW] `read_text()` without `encoding=` parameter — Python lang-review rule #5. Pre-existing across all 3 tiers of the loader (not introduced by this PR). Platform-dependent encoding defaults. Non-blocking for this story but worth a cleanup pass.

### Rule Compliance

| Rule | Applicable Code | Status |
|------|----------------|--------|
| #3 Type annotations | `load_agent_definition(agent_name: str, project_root: Path \| None = None) -> str \| None` | Compliant |
| #5 Path handling (pathlib) | Uses `Path / "..."` operator throughout, no string concat | Compliant |
| #5 Path handling (encoding) | `read_text()` without encoding — pre-existing across all tiers | Pre-existing LOW |
| #5 Path handling (resolve) | No `.resolve()` before reads — pre-existing across all tiers | Pre-existing LOW |
| #6 Test quality | 22 tests, all with meaningful assertions, vacuous assertion fixed in verify phase | Compliant |
| #10 Import hygiene | No new imports added, uses existing `Path`, `get_project_root`, `get_dist_root` | Compliant |
| #11 Input validation | `agent_name` unsanitized — pre-existing, callers pass hardcoded values | Pre-existing LOW |

[EDGE] No findings (disabled). [SILENT] No findings (disabled). [TEST] No findings (disabled). [DOC] No findings (disabled). [TYPE] No findings (disabled). [SEC] 3 findings — 2 dismissed (pre-existing pattern), 1 deferred (by-design feature). [SIMPLE] No findings (disabled). [RULE] No findings (disabled).

### Devil's Advocate

What if this code is broken? Let me argue against approval.

The most concerning aspect is that `agents-local/` is now the HIGHEST priority lookup — higher than the framework's own agent definitions. A consumer who accidentally creates `.pennyfarthing/agents-local/dev.md` with a malformed or empty file would silently break their dev agent with no obvious error. The empty-file test proves it returns `""` (not None), which means downstream code receives an empty agent definition and would likely produce a broken prime output. There's no warning, no fallback, no "hey, your local override is empty — did you mean that?"

However: this is the same behavior as `gates-local/` overriding `gates/`. The pattern is established. And returning empty string for an empty file is correct — the file EXISTS, so the lookup succeeds. The consumer explicitly placed it there. If they want the built-in, they delete the local file.

What about a race condition? Could `pf init` run concurrently with an agent activation, creating `agents-local/` mid-lookup? Pathlib's `.exists()` is atomic at the syscall level, and `mkdir(exist_ok=True)` is safe. The worst case is a directory appearing between the local check and the builtin check — which just means the builtin wins, which is correct.

What about the `agent_name` containing OS-reserved characters? On Windows, names like `CON`, `PRN`, `AUX` are reserved. Python's pathlib handles these gracefully on POSIX (our target). Not a concern.

The devil's advocate uncovered one genuine observation: no warning for empty local override files. This is minor (LOW) and consistent with the existing pattern — not worth blocking.

### Data Flow

Input: `agent_name` (string, e.g., "dev") from CLI → `load_agent_definition()` → constructs `Path` → `.exists()` check → `.read_text()` → returns content string to `prime()` → output to stdout. Safe because: no shell interpolation, no SQL, no HTML rendering. Content is markdown passed to Claude's context window.

### Wiring

`pf agent start <name>` → `cli.py:prime()` → `tiers.py:load_tier()` → `loader.load_agent_definition()` → file content returned and formatted into prime output. The new `agents-local/` path is transparent to all upstream callers. No wiring changes needed.

### Error Handling

- `agents-local/` doesn't exist → `local_file.exists()` returns False → falls through to `agents/`. Safe.
- `agents-local/` exists but is unreadable (permissions) → `read_text()` raises `PermissionError`. Pre-existing — no error handling on any tier. Consistent.
- Agent file is empty → returns `""`. Downstream handles this (or doesn't — pre-existing behavior).

**Data flow traced:** agent_name → Path construction → exists check → read_text → string return (safe, no injection vectors)
**Pattern observed:** Three-tier priority lookup following `gates-local/` precedent at `loader.py:33-48`
**Error handling:** Consistent with existing tiers — no try/except, relies on pathlib exceptions
**Handoff:** To Mad Hatter (SM) for finish-story