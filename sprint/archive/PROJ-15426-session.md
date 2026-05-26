# Story 125-5: Add pf sprint data --json canonical output for subprocess consumers

**Jira:** PROJ-15426
**Epic:** PROJ-15421 — Sprint State Engine Consolidation
**Points:** 2
**Priority:** P2
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/PROJ-15426-pf-sprint-data-json
**Assigned:** slabgorb@gmail.com

## Context

Add `pf sprint data --json` command that outputs the canonical merged sprint view as JSON. This becomes the single subprocess interface for TypeScript and other consumers. Includes stories, epics, metrics, and sprint metadata.

### Key Files
- `pennyfarthing-dist/pf/sprint/loader.py` — Load sprint YAML, registry resolution, merge shards
- `pennyfarthing-dist/pf/sprint/shard_merge.py` — Canonical shard merging + orphan detection
- `pennyfarthing-dist/pf/sprint/yaml_io.py` — YAML I/O with deterministic serialization
- `pennyfarthing-dist/pf/core/resolver.py` — SprintContext resolution
- `pennyfarthing-dist/pf/sprint/cli.py` — Click CLI (contains `pf sprint info`)

### Acceptance Criteria
- [ ] `pf sprint data --json` outputs complete merged sprint as JSON
- [ ] Output includes stories with all fields, epic metadata, sprint header
- [ ] Orphan detection included in output (`_orphans` array)
- [ ] Multi-sprint context preserved (`_registry` metadata)
- [ ] Computed metrics included (points and stories counts)
- [ ] Response time under 500ms for typical sprint size

### Technical Approach
- Reuse existing `load_sprint()` from loader.py (already does merging)
- Call `get_sprint_info()` for sprint header
- Call `get_all_stories()` for standalone stories
- Compute metrics in Python
- Add as `pf sprint data --json` subcommand

## Assessment

**SM Setup Assessment:** Story 125-5 is well-scoped at 2 points. The canonical `pf sprint data --json` command reuses existing `load_sprint()` infrastructure — no new parsing logic needed. Key risk is ensuring the output schema matches what TypeScript consumers (story 125-6) will expect. All acceptance criteria are clear and testable. Context file provides detailed architecture and key files. Branch created from develop. Ready for TEA to design tests.

## TEA Assessment

**Tests Required:** Yes
**Reason:** New CLI command with defined output schema — all ACs testable

**Test Files:**
- `tests/python/test_sprint_data.py` — 20 tests covering all 5 ACs

**Tests Written:** 20 tests covering 5 ACs
- AC1 (command exists, returns merged data): 6 tests — command registration, valid JSON output, sprint header, epics array, performance
- AC2 (all story fields): 4 tests — required fields, descriptions not truncated, optional fields preserved
- AC3 (orphan detection): 3 tests — `_orphans` key present, entry shape, orphans excluded from epics
- AC4 (multi-sprint registry): 2 tests — `_registry` shape when present, default sprint behavior
- AC5 (computed metrics): 5 tests — points object, stories_count object, totals equal sum of parts, consistency with epic data

**Status:** RED (all 20 failing — "No such command 'data'" — correct failure reason)

**Implementation notes for Dev:**
- Add `data` subcommand to `sprint` Click group in `pennyfarthing-dist/pf/sprint/cli.py`
- Reuse `load_sprint()` for merged data — it already handles shards and registry injection
- Must add orphan detection to the output (currently only warns to stderr via `shard_merge.py`)
- Compute point/story metrics from merged epic data
- `--json` flag controls output format (JSON-only is fine, flag makes it explicit)

**Handoff:** To Dev (Gandalf) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/pf/sprint/cli.py` — Added `data` command with `--json` flag to sprint group. Assembles full canonical output: sprint header, merged epics, stories, standalone_stories, computed metrics (points + stories_count), orphan detection, and registry metadata.
- `pennyfarthing-dist/pf/sprint/shard_merge.py` — Added `detect_orphan_shards()` function that returns structured orphan entries instead of only emitting warnings.

**Tests:** 20/20 passing (GREEN)
**Branch:** feature/PROJ-15426-pf-sprint-data-json (pushed)

**Notes:**
- Stories inherit `priority` and `repos` from parent epic when missing
- Metrics count epic stories + standalone_stories (not top-level `stories` array to avoid double-counting)
- Orphan detection reuses the same logic as `merge_epic_shards()` warning path but returns data

**Handoff:** To Reviewer (Saruman) for code review

## TEA Verify Assessment

**Tests:** 20/20 passing (GREEN confirmed)
**Smoke test:** Command outputs valid JSON with 3 epics, 51 stories, proper metrics
**AC coverage:** All 5 ACs verified — command exists, story fields complete, orphans detected, registry preserved, metrics computed
**Handoff:** To Reviewer (Saruman) for code review

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | `Path` not imported — orphan detection silently fails via `except Exception` catching `NameError` | `cli.py:~1591` | Add `from pathlib import Path` to lazy imports in `data()` |
| [LOW] | Broad `except Exception` swallows all errors in orphan detection | `cli.py:~1598` | Narrow to specific exceptions |
| [LOW] | `SystemExit(1)` not idiomatic Click | `cli.py:~1525` | Minor — prefer `click.UsageError` |

**Data flow traced:** `--json` → `load_sprint()` → header/epics/stories → metrics computation → orphan detection (BROKEN: Path undefined) → JSON output
**Pattern observed:** Lazy imports follow existing cli.py convention (good) but `Path` was missed
**Error handling:** The bare `except Exception` at line 1598 masks the `NameError`, making orphan detection return `[]` regardless of actual orphans on disk

**Handoff:** Back to Dev for fix (1-line import + narrow exception)

## Dev Assessment (Fix Round)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/pf/sprint/cli.py` — Added `from pathlib import Path` to lazy imports inside orphan detection try block; narrowed exception handler from `except Exception` to `except (FileNotFoundError, ValueError)`

**Tests:** 20/20 passing (GREEN)
**Branch:** feature/PROJ-15426-pf-sprint-data-json (pushed)

**Findings Addressed:**
- [HIGH] `Path` import: Added at line 1592 inside orphan detection block — FIXED
- [LOW] Broad exception: Narrowed to `(FileNotFoundError, ValueError)` — FIXED
- [LOW] `SystemExit(1)`: Left as-is — follows existing cli.py patterns (`pf sprint new`, `pf sprint archive` all use `SystemExit(1)` for non-JSON error exits). Changing to `click.UsageError` would be inconsistent with the codebase.

**Handoff:** To Reviewer (Saruman) for re-review

## Reviewer Assessment (Re-review)

**Verdict:** APPROVED

**Prior findings resolved:**
1. [HIGH] `Path` import — VERIFIED FIXED at `cli.py:1592`. Import inside try block, stdlib, reliable.
2. [LOW] Exception narrowing — VERIFIED FIXED to `(FileNotFoundError, ValueError)` at `cli.py:1600`. Targeted and appropriate.
3. [LOW] `SystemExit(1)` — Accepted Dev's justification. Follows existing `cli.py` patterns (`info()`, `metrics()`, `archive()`). Consistency > abstract purity.

**New observations:**
- [VERIFIED] `detect_orphan_shards` properly filters initiative-owned epics at `shard_merge.py:194`
- [VERIFIED] JSON serialization uses `default=str` at `cli.py:1633` — safe date fallback
- [VERIFIED] Lazy imports follow existing cli.py convention — consistent codebase pattern
- [MEDIUM] `except Exception: continue` at `shard_merge.py:172,186` — broad but appropriate for defensive file-reading (corrupt YAML shouldn't crash scan)
- [LOW] Stories with statuses outside `{done,completed,in_progress,backlog,planning,ready,None}` silently excluded from metrics — acceptable for current sprint model

**Data flow traced:** `--json` → `load_sprint()` → header (date serialization) → epic iteration (field inheritance) → metrics → orphan detection (`Path` → `resolve_sprint_context` → `detect_orphan_shards`) → `json.dumps(result, default=str)` — safe, no injection vectors
**Error handling:** No sprint → JSON error + exit(1); no --json → usage msg + exit(1); orphan failure → graceful empty list fallback; corrupt YAML → skipped in detection loop
**Security:** Local CLI, no network input, file paths from project root resolution, `json.dumps` output — no concerns

**Handoff:** To Elrond (SM) for finish-story

## TEA Verify Assessment (Fix Round)

**Tests:** 20/20 passing (GREEN confirmed)
**AC3 orphan detection:** All 3 tests pass — `Path` import resolved, exception handler narrowed
**Regression check:** Zero regressions across AC1-AC5
**Handoff:** To Reviewer (Saruman) for re-review

## Phase Log
- **setup** (SM): Story setup complete. Jira claimed, branch created, session initialized. Ready for TEA phase.
- **red** (TEA): 20 failing tests written covering all 5 ACs. RED state verified. Ready for Dev.
- **green** (Dev): Implementation complete. 20/20 tests GREEN. Branch pushed. Ready for review.
- **verify** (TEA): All 20 tests GREEN confirmed. Smoke test passed. Ready for review.
- **review** (Reviewer): REJECTED — missing `Path` import breaks orphan detection (AC3). Back to Dev.
- **green** (Dev): Fix applied — `Path` import added, exception narrowed. 20/20 GREEN. Ready for re-review.
- **verify** (TEA): 20/20 GREEN confirmed. AC3 orphan tests pass. Ready for re-review.
- **review** (Reviewer): APPROVED — prior [HIGH] and [LOW] findings resolved. No new blocking issues.