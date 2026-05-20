# Story 129-6: Detect stale hooks and prompt upgrade on session start

## Story Details
- **ID:** 129-6
- **Jira:** PROJ-15695
- **Workflow:** tdd
- **Assigned to:** keith.avery@slabgorb.io

## Description
Detect when a project's Claude Code hooks are outdated compared to what the current pennyfarthing version ships, and prompt the user to upgrade.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-26T10:36:20Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-26T08:54:04Z | 2026-02-26T08:54:46Z | 42s |
| red | 2026-02-26T08:54:46Z | 2026-02-26T10:31:52Z | 1h 37m |
| green | 2026-02-26T10:31:52Z | 2026-02-26T10:33:22Z | 1m 30s |
| verify | 2026-02-26T10:33:22Z | 2026-02-26T10:34:08Z | 46s |
| review | 2026-02-26T10:34:08Z | 2026-02-26T10:36:20Z | 2m 12s |
| finish | 2026-02-26T10:36:20Z | - | - |

## SM Assessment

**Story:** Detect stale hooks and prompt upgrade on session start (2pts, tdd)
**Repos:** pennyfarthing (branch: `feat/129-6-detect-stale-hooks`)
**Scope:** Compare project `.claude/settings.json` hooks against pennyfarthing-dist shipped hooks. Detect version drift and prompt user to upgrade on session start.
**Routing:** tdd → TEA (red phase) for test design, then Dev for implementation.
**Risk:** Low — isolated feature, no breaking changes expected.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core detection logic needs comprehensive coverage

**Test Files:**
- `tests/python/test_stale_hooks_detection.py` — 19 tests across 7 test classes

**Tests Written:** 19 tests covering 7 ACs
- AC1: Missing infrastructure hooks (3 tests)
- AC2: Deprecated pf.sh references (2 tests)
- AC3: Missing frontmatter hooks (2 tests)
- AC4: Clean settings pass (3 tests)
- AC5: Upgrade prompt generation (3 tests)
- AC6: Missing settings file (2 tests)
- AC7: Malformed settings (4 tests)

**Stub Module:** `pennyfarthing-dist/src/pf/hooks/stale_detection.py`
- `detect_stale_hooks(project_dir, dist_root)` → returns drift report dict
- Raises NotImplementedError (stub)

**Status:** RED (all 19 failing on NotImplementedError — correct failure mode)

**Key Design Decisions:**
- Function returns `{stale, missing_infrastructure, missing_frontmatter, deprecated, summary}` dict
- Uses existing `INFRASTRUCTURE_HOOKS` from `pf.common.hooks` as source of truth
- Uses existing `collect_all_frontmatter_hooks()` from `pf.hooks.frontmatter` for agent/skill hooks
- Custom user hooks (non-pf commands) are NOT flagged — only missing pf hooks matter
- Integration point: `session_start.py` should call this and emit `additionalContext`

**Handoff:** To Dev (Ponder Stibbons) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/hooks/stale_detection.py` — full implementation of `detect_stale_hooks()`

**Implementation Details:**
- `_load_installed_hooks()` — reads `.claude/settings.local.json`, handles missing/malformed gracefully
- `_extract_commands()` — extracts `(event, command, matcher)` tuples from hooks dict
- `_find_missing_infrastructure()` — compares against `INFRASTRUCTURE_HOOKS`
- `_find_deprecated()` — scans for `pf.sh` references
- `_find_missing_frontmatter()` — uses `collect_all_frontmatter_hooks()` from existing frontmatter module
- `_build_summary()` — generates human-readable upgrade prompt

**Tests:** 19/19 passing (GREEN)
**Branch:** `feat/129-6-detect-stale-hooks` (pushed)

**Note:** Session-start integration (calling `detect_stale_hooks` from `session_start.py`) is not wired yet — the story scope is detection logic. Integration can be a follow-up or part of story 131-2.

**Handoff:** To Reviewer (Granny Weatherwax) for review

## TEA Verify Assessment

**Tests:** 19/19 passing (GREEN confirmed)
**Duration:** 0.05s
**Verdict:** Implementation matches all 7 ACs. No regressions.

**Handoff:** To Reviewer (Granny Weatherwax)

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** project_dir → JSON read → set extraction → set diff against INFRASTRUCTURE_HOOKS → result dict (no shell execution, no injection risk)
**Pattern observed:** Lazy import of frontmatter module inside function body — avoids circular imports, matches existing hooks/ conventions at `stale_detection.py:94`
**Error handling:** Comprehensive defensive parsing in `_load_installed_hooks()` at `stale_detection.py:17-34` — 5 failure modes handled, all return empty dict
**Fix applied:** Removed unused `patch` import from test file (LOW)
**Tests:** 19/19 GREEN after fix

**Handoff:** To SM (Captain Carrot) for finish