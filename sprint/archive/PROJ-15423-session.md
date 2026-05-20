# Story 125-2: Replace Python CLI sprint resolution with SprintContext

**Status:** in-progress
**Jira:** PROJ-15423
**Workflow:** tdd
**Phase:** finish
**Branch:** feat/125-2-replace-python-cli-sprint-resolution
**Repos:** pennyfarthing
**Epic:** 125 (PROJ-15421) — Sprint State Engine Consolidation
**Started:** 2026-02-22

---

## Story Context

**Type:** refactor
**Points:** 2
**Priority:** p1

### Background

Story 125-1 introduced the SprintContext dataclass and resolve_sprint_context() function. This story replaces all hardcoded sprint path resolution in the Python CLI (loader.py, yaml_io.py, shard_merge.py) with calls to resolve_sprint_context(). This is a pure refactor — existing behavior must be preserved.

### Acceptance Criteria

- [ ] All Python sprint commands use SprintContext for path resolution
- [ ] No hardcoded sprint file paths remain in CLI code
- [ ] Existing tests still pass
- [ ] Focus switching (pf sprint use) works through SprintContext

### Dependencies

- 125-1 (SprintContext dataclass) — completed

---

## SM Assessment (Setup)

**Routing:** tdd workflow → TEA (Igor) for test design, then Dev (Ponder Stibbons)
**Branch:** `feat/125-2-replace-python-cli-sprint-resolution` on pennyfarthing/develop
**Jira:** PROJ-15423 claimed, In Progress

Pure refactor story. TEA should design tests that verify:
1. All Python CLI commands still resolve sprint paths correctly after the refactor
2. Focus switching (`pf sprint use`) works through SprintContext
3. No hardcoded sprint file paths remain in CLI code (loader.py, yaml_io.py, shard_merge.py)
4. Existing behavior preserved — regression tests for shard merging, epic resolution

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core path resolution refactor — must verify delegation and regression

**Test Files:**
- `tests/python/test_sprint_context_integration.py` — 14 tests across 5 classes

**Tests Written:** 14 tests covering all 4 ACs
- AC1 (SprintContext delegation): 3 tests — verify load_sprint() calls resolve_sprint_context()
- AC2 (No hardcoded paths): 3 tests — source inspection for removed hardcoded paths
- AC3 (Regression): 3 tests — shard merging, story access, default resolution
- AC4 (Focus switching): 5 tests — switch_sprint/load_sprint/resolver consistency

**Status:** RED (6 failing, 8 passing — ready for Dev)

**Failing tests (expected):**
- `test_load_sprint_calls_resolve_sprint_context` — loader doesn't import/call resolver yet
- `test_load_sprint_passes_project_root_to_resolver` — same
- `test_load_sprint_reads_from_context_sprint_file` — same
- `test_load_sprint_no_hardcoded_sprint_dir` — hardcoded paths still present
- `test_load_sprint_no_hardcoded_current_sprint_yaml` — hardcoded paths still present
- `test_loader_imports_resolve_sprint_context` — no import yet

**Handoff notes for Ponder Stibbons (Dev):**
- Refactor `load_sprint()` to call `resolve_sprint_context()` and use `ctx.sprint_file`
- Remove hardcoded `root / "sprint"` and `"current-sprint.yaml"` from load_sprint
- `_registry` metadata injection should use SprintContext fields
- `shard_merge.py` needs no changes — already generic via callable
- `yaml_io.py` may need no changes — it already takes explicit `path` arg
- Key risk: `load_sprint()` returns `None` on missing file but resolver raises — handle gracefully

**Handoff:** To Dev for implementation

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/pf/sprint/loader.py` — replaced load_sprint() path resolution with resolve_sprint_context() delegation

**Changes:**
- Added `from pf.core.resolver import resolve_sprint_context` import
- Rewrote `load_sprint()`: calls `resolve_sprint_context(str(root))`, reads from `ctx.sprint_file`, injects `_registry` from SprintContext fields for non-default contexts
- Graceful fallback: resolver exceptions (FileNotFoundError, ValueError) return None
- `shard_merge.py` and `yaml_io.py` unchanged — already generic
- Net: -31 lines, +19 lines (simpler)

**Tests:** 54/54 passing (GREEN)
- 14 story tests (test_sprint_context_integration.py)
- 14 sprint context tests (test_sprint_context.py)
- 26 sprint package tests (test_sprint_package.py)

**Branch:** feat/125-2-replace-python-cli-sprint-resolution (pushed)

**Handoff:** To Reviewer for code review

---

## TEA Verification Assessment

**GREEN State Confirmed:** Yes
**Independent Run:** 54/54 passing

**Test Suites Verified:**
- `tests/python/test_sprint_context_integration.py` — 14/14 PASSED (story-specific)
- `tests/python/test_sprint_context.py` — 14/14 PASSED (SprintContext dataclass)
- `pennyfarthing-dist/pf/tests/test_sprint_package.py` — 26/26 PASSED (sprint package regression)

**AC Coverage Review:**
- AC1 (SprintContext delegation): 4 tests — mock-verified resolver call, root forwarding, file reading, registry metadata injection. Thorough.
- AC2 (No hardcoded paths): 3 tests — AST-level source inspection for removed paths + import verification. Clever approach.
- AC3 (Regression): 3 tests — shard merging, story access, default resolution all preserved. Pre-existing sprint package tests (26) provide additional regression net.
- AC4 (Focus switching): 4 tests — focus load, default revert, resolver/loader consistency, round-trip switching. Solid.

**Test Quality:**
- Tests fail for the right reasons (assertion failures, not import errors)
- Mock usage is appropriate — isolates resolver delegation without over-mocking
- Fixtures create realistic project structures with tmp_path
- Source inspection tests are durable (grep source, not fragile line checks)

**Verdict:** Implementation is clean, tests are comprehensive, GREEN state holds. Ready for Granny Weatherwax.

**Handoff:** To Reviewer for code review

---

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `load_sprint(root)` → `resolve_sprint_context(str(root))` → SprintContext → `Path(ctx.sprint_file)` → `load_yaml_config()` → `_merge_epic_shards()` → return. Single clean delegation path. Safe — no unsanitized input, all paths from project config.

**Pattern observed:** Clean single-responsibility extraction at `loader.py:60-79`. Resolution logic consolidated in resolver, loader retains only data loading + shard merging + metadata injection. -31/+19 lines. Good.

**Error handling:** `try/except (FileNotFoundError, ValueError): return None` at `loader.py:60-63` — matches pre-refactor contract. Resolver wraps `yaml.YAMLError` as `ValueError` internally, so no exception escape.

**Observations:**
| # | Severity | Finding | Location |
|---|----------|---------|----------|
| 1 | [VERIFIED] | `_registry.docs` dropped — no consumer in Python/TS/shell | `loader.py:72-77` |
| 2 | [VERIFIED] | `context_root`/`session_root` defaults improved (no more None) | `resolver.py:86-89` |
| 3 | [VERIFIED] | `type` default "project" preserved | `resolver.py:92` |
| 4 | [VERIFIED] | `load_sprint_registry`/`get_active_sprint_name` not dead code | `cli.py:174,219` |
| 5 | [MEDIUM] | Source inspection tests (DEC-REV-003: acceptable) | `test:243-270` |
| 6 | [LOW] | Unused `ast` import in test file | `test:10` |

**Blocking issues:** None
**Tests:** 54/54 passing (independently verified by preflight)
**Forbidden patterns:** None detected

**Handoff:** To SM for finish-story

---