# Story 145-1: Signal collector — gather ACs, PR diff, commits, session, review findings

## Story Details
- **ID:** 145-1
- **Workflow:** tdd
- **Points:** 3
- **Priority:** P0
- **Epic:** 145 — Demo Artifact Generator — Core Pipeline
- **Repos:** pennyfarthing
- **Branch:** feat/145-1-signal-collector

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-13T00:26:07Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-12T00:00:00Z | 2026-03-13T00:12:01Z | 24h 12m |
| red | 2026-03-13T00:12:01Z | 2026-03-13T00:15:26Z | 3m 25s |
| green | 2026-03-13T00:15:26Z | 2026-03-13T00:18:05Z | 2m 39s |
| verify | 2026-03-13T00:18:05Z | 2026-03-13T00:20:30Z | 2m 25s |
| review | 2026-03-13T00:20:30Z | 2026-03-13T00:23:25Z | 2m 55s |
| green | 2026-03-13T00:23:25Z | 2026-03-13T00:24:44Z | 1m 19s |
| review | 2026-03-13T00:24:44Z | 2026-03-13T00:26:07Z | 1m 23s |
| finish | 2026-03-13T00:26:07Z | - | - |

## Context
The Signal Collector is the foundational stage of the Demo Artifact Generator pipeline (epic 145). It gathers all raw signals from a completed story before session archival, producing a `SignalBundle` dataclass that feeds downstream pipeline stages (Classifier, Generator, Assembler).

**Module location:** `pennyfarthing-dist/src/pf/demo/collector.py`

**Technical approach:**
- Collect signals from 6 sources: sprint YAML (ACs, story metadata), session file (markdown field parsing), PR diff (via `gh` CLI with git fallback), commit messages, review findings, file extensions
- Return `SignalBundle` dataclass with all collected data
- Follow ADR-0008: all functions return `{success, data?, error?}` result objects
- Reuse session parsing regex from `story_finish.py` (lines 60-75)
- Must run BEFORE session archival in `story_finish.py` (session file deleted after finish)
- Non-fatal fallbacks for optional signals (session, PR, findings); story validation is hard-fail

**Key references:**
- Epic tech context: `sprint/context/context-epic-145.md`
- ADR-0038: `docs/adr/0038-demo-artifact-generator.md`
- PRD: `sprint/planning/demo-prd.md`
- Pattern reuse: `pennyfarthing-dist/src/pf/sprint/story_finish.py`

## Acceptance Criteria
- AC1: `collect_signals(story_id)` returns a `SignalBundle` dataclass with all required fields
- AC2: Collects acceptance criteria from sprint YAML via `pf.sprint.loader`
- AC3: Parses session file fields using `**Key:** Value` markdown pattern
- AC4: Retrieves PR diff via `gh` CLI, falls back to `git diff` if unavailable
- AC5: Gathers commit messages from the story branch
- AC6: Collects review findings if present in session/sprint data
- AC7: Extracts file extensions from PR diff for downstream classification hints
- AC8: Returns proper error result object when story_id is invalid (hard fail)

## Design Deviations

### TEA (test design)
- **Helper function granularity:** Spec describes a single `collect_signals()` function. Tests also cover granular helpers (`parse_session_fields`, `get_pr_diff`, `get_commit_messages`, `extract_file_extensions`, `get_review_findings`) as separate test classes. Reason: each AC maps cleanly to a distinct data source with its own failure modes; testing at the helper level catches bugs that integration-only tests would miss.
- **Mock placement:** Tests mock `pf.sprint.loader.load_sprint` and `subprocess.run` rather than hitting real sprint YAML or git. Reason: RED phase tests must be deterministic and fast; real file I/O and CLI calls would make tests flaky and environment-dependent.

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- **TEA helper function granularity** → ACCEPTED: testing helpers individually is sound engineering.
- **TEA mock placement** → ACCEPTED: deterministic tests require mocks for subprocess/IO.
- **Simplify regression on extract_file_extensions:** Verify phase changed `if ext and _:` to `if ext:`, breaking extensionless file handling. `rpartition(".")` on `Dockerfile` returns `("","","Dockerfile")` — the `_` check was load-bearing. Severity: HIGH.

## Delivery Findings

### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): SESSION_FIELD_RE and parse_session_fields are duplicated across collector.py, story_finish.py, and aggregate.py. Affects `pennyfarthing-dist/src/pf/demo/collector.py` (extract to shared module in future story). *Found by Reviewer during code review.*

## TEA Assessment

**Tests Required:** Yes
**Reason:** 3pt story with 8 distinct ACs covering data collection, parsing, CLI interaction, and error handling.

**Test Files:**
- `tests/python/test_demo_collector.py` — 32 tests across 9 test classes

**Tests Written:** 32 tests covering 8 ACs
**Status:** RED (failing — all 32 fail with NotImplementedError from stubs)

**AC Coverage:**
| AC | Tests | Class |
|----|-------|-------|
| AC1 | 3 | TestCollectSignalsReturnsSignalBundle |
| AC2 | 2 | TestCollectAcceptanceCriteria |
| AC3 | 6 | TestParseSessionFields |
| AC4 | 4 | TestGetPrDiff |
| AC5 | 3 | TestGetCommitMessages |
| AC6 | 3 | TestGetReviewFindings |
| AC7 | 5 | TestExtractFileExtensions |
| AC8 | 3 | TestInvalidStoryId |
| Edge | 3 | TestEdgeCases |

**Stubs Created:**
- `pennyfarthing-dist/src/pf/demo/__init__.py` — package init
- `pennyfarthing-dist/src/pf/demo/models.py` — `SignalBundle` dataclass
- `pennyfarthing-dist/src/pf/demo/collector.py` — 6 stub functions (all raise NotImplementedError)

**Handoff:** To Dev (The White Rabbit) for implementation

## TEA Assessment (Verify)

**Phase:** finish
**Status:** GREEN confirmed

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 3

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 5 findings | SESSION_FIELD_RE + parse_session_fields duplicated across 3 modules; project_root pattern; subprocess boilerplate |
| simplify-quality | 1 finding | Redundant underscore check in extract_file_extensions |
| simplify-efficiency | 1 finding | Same underscore check as quality |

**Applied:** 1 high-confidence fix (simplified `if ext and _:` → `if ext:`)
**Flagged for Review:** 2 medium-confidence (project_root helper, subprocess boilerplate)
**Noted:** 2 high-confidence cross-module reuse opportunities (SESSION_FIELD_RE + parse_session_fields shared across story_finish.py, aggregate.py, collector.py — defer to future story)
**Reverted:** 0

**Overall:** simplify: applied 1 fix

**Quality Checks:** 32/32 tests passing
**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | `extract_file_extensions` adds spurious `.Dockerfile`, `.Makefile` etc for extensionless files. Simplify phase changed `if ext and _:` to `if ext:` but `_` (before-dot part from rpartition) was load-bearing — empty string means no dot separator exists. | `collector.py:204` | Restore `if ext and _:` or use `before, sep, ext = filepath.rpartition(".")` and check `if sep:` |
| [MEDIUM] | `gh pr diff --name-only` returns file names not diff content. `pr_diff` field would contain file list, not unified diff. Acceptable for MVP extension extraction but misleading. | `collector.py:137` | Future story — document limitation |
| [VERIFIED] | ADR-0008 result objects correct across all functions | | |
| [VERIFIED] | Non-fatal fallbacks for session, PR, findings all correct | | |
| [VERIFIED] | Hard fail on invalid story_id, missing sprint data | | |

**Handoff:** Back to Dev for fix (restore extensionless file guard)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/demo/collector.py` — Full implementation of 6 functions

**Tests:** 32/32 passing (GREEN)
**Branch:** feat/145-1-signal-collector (pushed)

**Handoff:** To TEA for verify phase

## SM Assessment
Story 145-1 is the foundation of the Demo Artifact Generator pipeline. Session created with full technical context, 8 acceptance criteria, and branch `feat/145-1-signal-collector` on pennyfarthing develop. No Jira key (internal epic). Epic tech context at `sprint/context/context-epic-145.md` covers architecture, dataclass contracts, and integration points. Key risk: timing constraint — collector must run before session archival in `story_finish.py`. TEA should focus RED tests on the `SignalBundle` contract, result object patterns, and fallback behavior for missing optional signals.
## Reviewer Assessment (Re-review)

**Verdict:** APPROVED
**Fix verified:** `extract_file_extensions` now uses `if sep and ext:` — extensionless files return empty set correctly.
**Tests:** 32/32 passing
**Data flow traced:** story_id → sprint loader → story dict → SignalBundle (safe, all .get() with defaults)
**Error handling:** Invalid story_id, missing sprint, missing session all return proper result objects
**Pattern observed:** ADR-0008 result objects consistently applied across all functions

**Handoff:** To SM for finish