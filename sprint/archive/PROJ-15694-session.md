# Story 129-5: Integrate frontmatter hooks into pf init pipeline

**Jira:** PROJ-15694
**Epic:** PROJ-15680 — Context Validation & Visibility
**Points:** 2
**Type:** feature
**Repos:** pennyfarthing
**Workflow:** tdd
**Phase:** finish
**Assigned:** slabgorb@gmail.com
**Started:** 2026-02-25

## Context

The frontmatter hooks system (`pf/hooks/frontmatter.py`) is fully implemented and tested but not wired into the `pf init` pipeline. Currently `pf init` writes only 5 hardcoded infrastructure hooks to `.claude/settings.local.json` via `_MINIMAL_SETTINGS` in `init/core.py`.

Two functions exist and are tested:

1. `collect_all_frontmatter_hooks(dist_root)` — Scans `agents/*.md` and `skills/*/SKILL.md` for hook declarations in YAML frontmatter. Returns a dict keyed by event type (SessionStart, Stop, PreToolUse, PostToolUse) with lists of `HookDeclaration` objects.

2. `merge_with_infrastructure(infrastructure, frontmatter_hooks)` — Takes the minimal infrastructure settings dict and the collected frontmatter hooks, performs deduplication by command name, and returns a complete settings dict with both infrastructure and component-declared hooks.

The integration point is in `init/core.py::init_project()`. Currently at line 242-250, settings are written from `_MINIMAL_SETTINGS` (which is a dict with 5 infrastructure hooks). The frontmatter collection and merge must be called here before writing to create settings containing both infrastructure and agent/skill-declared hooks.

**Key files:**

- `pennyfarthing-dist/src/pf/hooks/frontmatter.py` — Fully implemented
- `pennyfarthing-dist/src/pf/init/core.py` — Integration point: line 242 (settings file write)
- `pennyfarthing-dist/src/pf/common/hooks.py` — INFRASTRUCTURE_HOOKS dict (5 canonical hooks)

## Acceptance Criteria

- [ ] `pf init` collects frontmatter hooks from all agents and skills
- [ ] Frontmatter hooks are merged with infrastructure hooks (no duplicates)
- [ ] `.claude/settings.local.json` contains both infrastructure and frontmatter hooks after init
- [ ] `pf init` is idempotent — running twice produces same result
- [ ] Existing tests continue to pass
- [ ] No manual edit of sprint YAML (use pf sprint story update if needed)

## Technical Approach

1. In `init/core.py::init_project()`, after validation and before writing settings (around line 242):
   - Import `collect_all_frontmatter_hooks` and `merge_with_infrastructure` from `pf.hooks.frontmatter`
   - Call `collect_all_frontmatter_hooks(dist_root)` to get frontmatter hooks dict
   - Call `merge_with_infrastructure(_MINIMAL_SETTINGS, frontmatter_hooks)` to get complete settings
   - Write the merged settings to `.claude/settings.local.json`

2. Test that:
   - Settings file contains all infrastructure hooks
   - Settings file contains all frontmatter hooks from agents/skills
   - Running init twice produces identical settings (idempotency)
   - No hooks are duplicated

3. Update `_upgrade_hooks()` if needed to handle frontmatter hooks when upgrading existing projects (likely no change needed, but verify the dedup logic aligns)

## Notes

- The frontmatter parsing is already robust and tested (story 126-6)
- Hooks are deduplicated by command name, so if the same hook appears in both infrastructure and frontmatter, only one entry is kept
- The hook format must match Claude Code settings.local.json schema exactly

## TEA Assessment

**Phase:** finish (complete)
**Test file:** `pennyfarthing-dist/src/pf/tests/test_init_frontmatter_integration.py`
**Tests:** 18 total — 9 passing, 9 failing (all AssertionError — correct RED state)
**Branch:** `feat/129-5-frontmatter-hooks-init`

### Test Coverage by AC

| AC | Class | Tests | Status |
|----|-------|-------|--------|
| AC1: Collects frontmatter hooks | `TestInitCollectsFrontmatterHooks` | 4 tests | 3 FAIL, 1 PASS |
| AC2: No duplicate hooks | `TestNoDuplicateHooks` | 3 tests | 3 FAIL |
| AC3: Both hook sets present | `TestSettingsContainsBothHookSets` | 5 tests | 3 FAIL, 2 PASS |
| AC4: Idempotent | `TestFrontmatterIdempotency` | 3 tests | PASS (trivially — no frontmatter yet) |
| AC5: Graceful fallback | `TestGracefulFallback` | 3 tests | PASS |

### Failing Tests (RED targets for GREEN)

1. `test_settings_contains_agent_pretooluse_hook` — schema-validation not in settings
2. `test_settings_contains_agent_stop_hook` — reflector-check not in settings
3. `test_settings_contains_skill_posttooluse_hook` — sprint-yaml not in settings
4. `test_schema_validation_appears_once` — 0 occurrences (not yet collected)
5. `test_reflector_check_appears_once` — 0 occurrences (not yet collected)
6. `test_infrastructure_hooks_not_duplicated` — infrastructure hooks not deduplicated
7. `test_has_more_than_five_hooks` — only 5 hooks (infrastructure only)
8. `test_all_frontmatter_hooks_present` — frontmatter hooks missing
9. `test_upgrade_path_adds_frontmatter_hooks` — stripped settings not restored

### Implementation Guidance for Dev

The fix is surgical — modify `init/core.py::init_project()` at the settings write point (line ~242):

1. Import `collect_all_frontmatter_hooks` and `merge_with_infrastructure` from `pf.hooks.frontmatter`
2. Before writing `_MINIMAL_SETTINGS`, call `collect_all_frontmatter_hooks(dist_root)` to get frontmatter hooks
3. Call `merge_with_infrastructure(_MINIMAL_SETTINGS, frontmatter_hooks)` to get merged settings
4. Write the merged settings instead of `_MINIMAL_SETTINGS`
5. In `_upgrade_hooks()`, also collect and merge frontmatter hooks when upgrading existing settings

### Existing Test Warning

`test_init_command.py::test_settings_has_exactly_five_hooks` asserts exactly 5 hooks. This test uses a mock dist without frontmatter agents, so it should still pass — but verify during GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/init/core.py` — Added import of `collect_all_frontmatter_hooks` and `merge_with_infrastructure`; wired frontmatter collection and merge into both new-init and upgrade paths (10 lines added, 1 removed)

**Tests:** 73/73 passing (GREEN)
- 18/18 integration tests (`test_init_frontmatter_integration.py`)
- 55/55 existing init tests (`test_init_command.py`) — zero regressions

**Branch:** `feat/129-5-frontmatter-hooks-init` (pushed)

**Handoff:** To Reviewer for code review

## TEA Verify Assessment

**Tests Verified:** 107 total across 3 suites
- 18/18 integration tests — all GREEN
- 55/55 init command tests — zero regressions
- 31/34 frontmatter tests — 3 pre-existing failures (unrelated to 129-5)

**Pre-existing failures:** `TestInfrastructureHooksReduction` (3 tests) — stale assertions from story 126-6 that weren't updated when PR #1125 added `agent-reload` to `INFRASTRUCTURE_HOOKS`. Not caused by 129-5.

**Verdict:** GREEN confirmed. Implementation is minimal and correct.

**Handoff:** To Reviewer

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `dist_root` → `collect_all_frontmatter_hooks` → YAML parse → `HookDeclaration` → `merge_with_infrastructure` → JSON settings file. No hook execution during init. Trusted input from dist directory.

**Pattern observed:** Deep copy mutation protection at `frontmatter.py:219`, deduplication by command name at `frontmatter.py:234`. Follows existing `core.py` read-transform-write pattern.

**Error handling:** Consistent with project — file ops not wrapped in try/except, matching every other operation in `core.py`. YAML parse errors caught in `parse_frontmatter`.

**Observations:**
1. `[VERIFIED]` _MINIMAL_SETTINGS protected from mutation via deepcopy
2. `[VERIFIED]` Idempotency — second run detects existing hooks, skips write
3. `[VERIFIED]` Upgrade path: _upgrade_hooks cleans deprecated → frontmatter merge adds component hooks
4. `[VERIFIED]` README.md exclusion prevents accidental hook injection
5. `[VERIFIED]` No execution of commands during init — purely declarative
6. `[LOW]` Double file I/O in upgrade path — acceptable for infrequent init
7. `[VERIFIED]` 3 pre-existing test failures in test_frontmatter_hooks.py unrelated to this change

**Handoff:** To SM for finish-story