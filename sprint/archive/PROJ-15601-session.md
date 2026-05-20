# Story 126-13: Extract shared hook constants and fix onboarding rough edges

## Story Details
- **ID:** 126-13
- **Jira Key:** PROJ-15601
- **Workflow:** trivial

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-02-24T19:09:01Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-24T18:50:34Z | - | - |

## Story Summary

This is housekeeping debt extracting hook constant duplication and fixing four rough edges in the Python CLI:

1. **Extract shared hook constants**: `_MINIMAL_SETTINGS` in `init/core.py` and `_PYTHON_HOOKS` in `upgrade/core.py` define the same 5 hooks independently. Create a single `_INFRASTRUCTURE_HOOKS` constant imported by both.

2. **Fix verify_pf_cli() install hint**: Currently shows dev path instead of user-facing pip install command.

3. **Remove or wire up dead code**: `run_auto_setup()` in `setup.py` is never called.

4. **Fix _copy_tree() safety**: Currently does `rmtree` before `copytree`, which nukes user files in skill dirs. Add pre-flight check or preservation logic.

### Acceptance Criteria
- Single `_INFRASTRUCTURE_HOOKS` constant imported by both `init/core.py` and `upgrade/core.py`
- `verify_pf_cli()` install_hint shows user-facing pip install command
- `run_auto_setup()` either removed or wired to a code path
- `_copy_tree()` preserves non-pf user files or warns before overwriting
- Existing tests still pass after refactor

### Key Files
- `pennyfarthing/pennyfarthing-dist/src/pf/init/core.py`
- `pennyfarthing/pennyfarthing-dist/src/pf/upgrade/core.py`
- `pennyfarthing/pennyfarthing-dist/src/pf/setup.py`

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/common/hooks.py` - new shared INFRASTRUCTURE_HOOKS constant
- `pennyfarthing-dist/src/pf/init/core.py` - import shared hooks, fix install_hint, fix _copy_tree
- `pennyfarthing-dist/src/pf/upgrade/core.py` - import shared hooks instead of local duplicate
- `pennyfarthing-dist/src/pf/init/setup.py` - removed dead run_auto_setup()
- `tests/python/test_init_auto_setup.py` - removed tests for deleted function

**Tests:** 18/18 passing (5 pre-existing failures unchanged)
**Branch:** feat/126-13-extract-shared-hook-constants (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `INFRASTRUCTURE_HOOKS` → `_MINIMAL_SETTINGS["hooks"]` → `json.dumps()` → `settings.local.json` (safe — serialization creates fresh copy)
**Pattern observed:** Single source of truth extraction at `pf/common/hooks.py:11` — both consumers import from one canonical location
**Error handling:** No new error paths. Existing error handling preserved in `verify_pf_cli()`.
**Medium findings (non-blocking):**
- Name collision: `INFRASTRUCTURE_HOOKS` exists as dict (`common/hooks.py`) and set (`hooks/frontmatter.py`) — pre-existing, track for future cleanup
- Shared mutable reference: `_PYTHON_HOOKS = INFRASTRUCTURE_HOOKS` — mitigated by JSON boundary
- Stale file accumulation in merge-based `_copy_tree()` — correct trade-off per AC
**Tests:** 18/18 init + 34/34 frontmatter = 52 tests passing, no regressions
**Handoff:** To SM for finish-story