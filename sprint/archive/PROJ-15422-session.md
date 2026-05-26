# Story 125-1: Define SprintContext dataclass and resolve_sprint_context() function

**Jira:** [PROJ-15422](https://slabgorb.atlassian.net/browse/PROJ-15422)
**Epic:** 125 — Sprint State Engine Consolidation (PROJ-15421)
**Points:** 3
**Type:** story
**Priority:** P1
**Repos:** pennyfarthing
**Workflow:** tdd
**Phase:** finish
**Branch:** feature/125-1-sprint-context-dataclass
**Assigned:** slabgorb@gmail.com

---

## Context

This is the foundation story for epic 125 (Sprint State Engine Consolidation). The sprint state engine is currently scattered across multiple files with inconsistent path resolution logic. This story introduces a unified `SprintContext` dataclass and a single `resolve_sprint_context()` function that consolidates all sprint path resolution logic.

**Problem:** Sprint context (sprint file path, context root, session root, repos list, sprint name, type, and default status) are resolved in ad-hoc ways throughout the codebase. This leads to:
- Duplicated path logic
- Inconsistent behavior across commands
- Difficulty testing and maintaining sprint operations
- Poor separation of concerns

**Solution:** Create a dataclass that bundles all sprint context data, and a single resolution function that handles:
1. **Default case (90%):** Orchestrator's own sprint (no preference set)
2. **Focus case (10%):** Registry lookup via `sprints.yaml` + `config.local.yaml` preference

---

## Acceptance Criteria

1. **SprintContext dataclass defined** with all fields:
   - `sprint_file` — absolute path to sprint YAML file
   - `context_root` — root directory for sprint context
   - `session_root` — root directory for session files
   - `repos` — list of repository names in this sprint
   - `name` — human-readable sprint name
   - `type` — sprint type (orchestrator, focus, etc.)
   - `is_default` — boolean indicating if this is the default sprint

2. **resolve_sprint_context() returns correct context** for default case (no preference set)
   - Resolves to orchestrator's own sprint
   - Returns complete SprintContext with all fields populated

3. **resolve_sprint_context() returns correct context** for focus case (preference set, registry lookup)
   - Reads sprints.yaml registry
   - Checks config.local.yaml for preference
   - Performs registry lookup by name
   - Returns complete SprintContext for focused sprint

4. **Unit tests cover both paths and edge cases**
   - Happy path: default case
   - Happy path: focus case with valid preference
   - Edge case: missing registry file
   - Edge case: invalid preference (not in registry)
   - Edge case: malformed sprint YAML

---

## Technical Notes

**Files to create/modify:**
- `pennyfarthing-dist/pf/core/models.py` (or appropriate location) — SprintContext dataclass
- `pennyfarthing-dist/pf/core/resolver.py` (or appropriate location) — resolve_sprint_context() function
- `tests/python/test_sprint_context.py` — comprehensive unit tests

**Key functions:**
- `resolve_sprint_context(project_root: str) -> SprintContext` — main resolution function
- SprintContext should be importable for use throughout the sprint CLI

**Dependencies:**
- YAML parsing (already available)
- Path utilities (already available)
- Config file loading (already available)

**Design considerations:**
- Keep dataclass immutable (frozen=True recommended)
- Handle missing files gracefully with meaningful errors
- Support both local sprint (default) and registry lookups (focus)
- Centralize all path construction logic here

---

## Dev Notes

**Phase 1 (Dev):**
- Define SprintContext dataclass with type hints
- Implement resolve_sprint_context() for default case
- Write unit tests for default case
- Ensure all acceptance criteria for default path are met

**Phase 2 (Dev continuation or separate story):**
- Implement focus case (registry lookup)
- Add edge case handling
- Complete full unit test suite
- Integration tests with actual sprint files

**Testing strategy:**
- Mock YAML files for unit tests (don't depend on real sprint files)
- Test both happy paths and error conditions
- Verify return values match expected SprintContext structure
- Test with various project structures

**Review notes for later:**
- Verify dataclass is properly typed
- Check error messages are user-friendly
- Ensure no coupling to specific sprint implementations
- Confirm tests are isolated and repeatable

---

## SM Assessment (setup → red)

**Story setup complete.** Session file created, Jira claimed (PROJ-15422 → In Progress), feature branch `feature/125-1-sprint-context-dataclass` created from latest `develop`.

**Routing:** tdd workflow, 3pts → TEA (Deep Thought) for test design phase.

**Key context for TEA:**
- This is the keystone story for epic 125 — unblocks 5 downstream stories (9pts)
- Dataclass + resolver function in `pennyfarthing-dist/pf/core/`
- Two resolution paths: default (90%) and focus (10%)
- Tests should mock YAML files, not depend on real sprint files
- Existing sprint code lives in `pennyfarthing-dist/pf/sprint/` — study `loader.py` and `yaml_io.py` for current resolution patterns

**Risks:** None identified. Clear ACs, well-scoped, no external dependencies.

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core domain model + resolver function — both need comprehensive coverage.

**Test Files:**
- `tests/python/test_sprint_context.py` — 14 tests across 4 test classes (new)

**Stub Files:**
- `pennyfarthing-dist/pf/core/__init__.py` — package init (new)
- `pennyfarthing-dist/pf/core/models.py` — SprintContext dataclass (new, complete)
- `pennyfarthing-dist/pf/core/resolver.py` — resolve_sprint_context() stub (new, NotImplementedError)

**Tests Written:** 14 tests covering 4 ACs
- AC1 (4 tests): Dataclass fields, frozen immutability, type annotations, construction — all PASS
- AC2 (3 tests): Default case resolution, complete context, is_default flag — FAIL (NotImplementedError)
- AC3 (3 tests): Focus preference, registry lookup, complete context — FAIL (NotImplementedError)
- AC4 (4 tests): Missing registry, invalid preference, malformed YAML, missing file — FAIL (NotImplementedError)

**Status:** RED (10 failing, 4 passing — all failures on NotImplementedError, not imports)

**Design notes for Dev:**
- Tests use `tmp_path` fixtures with mock YAML files (no real sprint files)
- Default case expects `is_default=True`, focus case expects `is_default=False`
- Focus fixture sets up full registry + config.local.yaml + focus sprint file
- Edge cases expect graceful fallback to default or meaningful exceptions
- SprintContext dataclass is already complete — Dev only needs to implement `resolve_sprint_context()`
- Pattern reference: `pf/sprint/loader.py:load_sprint()` has the resolution logic to consolidate

**Handoff:** To Dev (Trillian) for GREEN implementation

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/pf/core/resolver.py` — resolve_sprint_context() with default/focus paths, helper functions for YAML loading, preference reading, and registry lookup

**Tests:** 14/14 passing (GREEN)
**Branch:** feature/125-1-sprint-context-dataclass (pushed)

**Implementation Notes:**
- Followed existing `loader.py:load_sprint()` resolution pattern
- Three private helpers: `_load_yaml()`, `_get_active_preference()`, `_load_registry()`
- `_collect_repos()` extracts unique repos from epic data
- Focus path reads registry metadata (context_root, session_root, repos, type) from sprints.yaml entry
- Default path infers repos from epic data, sets type="orchestrator"
- Edge cases: missing registry → fallback to default, invalid preference → fallback, malformed YAML → ValueError, missing file → FileNotFoundError

**Handoff:** To Reviewer (Arthur Dent) for code review

---

## TEA Verify Assessment

**Tests:** 14/14 passing (GREEN confirmed)
**Execution Time:** 0.04s
**Verification:** All ACs covered, all tests pass on correct assertions (not vacuous passes)

**Handoff:** To Reviewer (Arthur Dent) for code review

---

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `project_root` → Path → config.local.yaml → (optional) sprints.yaml registry → sprint YAML file → SprintContext. All paths terminate with valid context or exception.

**Observations:**
| Severity | Observation | Location |
|----------|-------------|----------|
| `[VERIFIED]` | frozen=True enforced on dataclass | `models.py:10` |
| `[VERIFIED]` | yaml.safe_load() used everywhere — no deserialization risk | `resolver.py:28,119,135` |
| `[VERIFIED]` | Resolution order matches existing loader.py pattern | `resolver.py:67-109` |
| `[VERIFIED]` | Graceful fallback in preference/registry helpers | `resolver.py:112-137` |
| `[VERIFIED]` | Tests use tmp_path — isolated, deterministic | `test_sprint_context.py` |
| `[LOW]` | repos field is mutable list in frozen dataclass | `models.py:28` |

**Error handling:** Three failure modes in `_load_yaml()`, graceful None returns in helpers, exceptions propagated at last resort. Solid.

**Security:** safe_load only, paths rooted at project_root. No concerns.

**Handoff:** To SM (Slartibartfast) for finish-story